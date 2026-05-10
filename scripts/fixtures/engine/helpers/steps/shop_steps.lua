local Coins = require("src.content.coins")
local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")
local RunHistorySystem = require("src.systems.run_history_system")
local ShopFlowSystem = require("src.systems.shop_flow_system")
local Utils = require("src.core.utils")

local Common = require("scripts.fixtures.engine.helpers.steps.common")

local ShopSteps = {}
local handlers = {}

local function normalizeInjectedOffer(rawOffer, index)
  local definition = rawOffer.type == "coin" and Coins.getById(rawOffer.contentId) or Upgrades.getById(rawOffer.contentId)
  assert(definition, string.format("unknown injected offer content %s:%s", tostring(rawOffer.type), tostring(rawOffer.contentId)))

  return {
    id = rawOffer.id or string.format("fixture_offer_%02d", index),
    type = rawOffer.type,
    contentId = rawOffer.contentId,
    name = rawOffer.name or definition.name,
    rarity = rawOffer.rarity or definition.rarity,
    price = rawOffer.price ~= nil and rawOffer.price or ShopContent.resolvePrice(rawOffer.type, definition),
    purchased = rawOffer.purchased == true,
    injectedBy = rawOffer.injectedBy,
    priceAdjustments = Utils.clone(rawOffer.priceAdjustments or {}),
  }
end

local function injectOffersIntoVisit(env, step, shopFlow)
  local offers = {}

  for index, offer in ipairs(step.offers or {}) do
    table.insert(offers, normalizeInjectedOffer(offer, index))
  end

  local trace = Utils.clone(step.generationTrace or {
    mode = step.reason or "fixture_injected",
    triggeredSources = {},
    actions = {},
    warnings = {},
    messages = Utils.copyArray(step.messages or {}),
    notes = {},
    offerCount = #offers,
  })

  shopFlow.offers = offers
  shopFlow.lastGenerationTrace = trace
  RunHistorySystem.recordShopOfferRefresh(shopFlow.shopSession, offers, trace, step.reason or "fixture_injected")
  env:syncShopFlow(shopFlow)
  Common.assertRuntime(env, "fixtures.create_shop_visit.injected", { shopOffers = shopFlow.offers, history = true })
  return offers
end

local function createShopVisit(env, step)
  local sourceStageId = step.sourceStageId or (env.stageRecord and env.stageRecord.stageId) or (env.stageState and env.stageState.stageId)
  local roundIndex = step.roundIndex or (env.stageRecord and env.stageRecord.roundIndex) or env.runState.roundIndex

  if env.stageRecord
    and env.stageRecord.stageType == "normal"
    and env.stageRecord.status == "cleared"
    and env.runState.runStatus == "active"
    and env.stageRecord.rewardOptions == nil then
    RunHistorySystem.recordStageRewardPreview(env.stageRecord, { options = {}, choice = nil })
  end

  if env.stageRecord
    and env.stageRecord.stageType == "normal"
    and env.stageRecord.status == "cleared"
    and env.runState.runStatus == "active"
    and env.stageRecord.encounter == nil then
    RunHistorySystem.recordStageEncounterPreview(env.stageRecord, {
      encounterId = "quiet_hallway",
      name = "Quiet Hallway",
      description = "No encounter is active for this stop.",
      choices = {},
      choice = nil,
      claimed = false,
    })
  end

  local shopFlow = ShopFlowSystem.createVisit(env.runState, env.stageState, env.metaProjection, env:ensureRng(), {
    sourceStageId = sourceStageId,
    roundIndex = roundIndex,
  })
  env:syncShopFlow(shopFlow)

  if step.offers then
    injectOffersIntoVisit(env, step, shopFlow)
  else
    Common.assertRuntime(env, "fixtures.create_shop_visit", {})
  end

  return shopFlow
end

local function ensureShopOffers(env)
  local offers = ShopFlowSystem.ensureOffers(env.shopFlow)
  env:syncShopFlow(env.shopFlow)
  Common.assertRuntime(env, "fixtures.ensure_shop_offers", { shopOffers = env.shopFlow.offers, history = true })
  return offers
end

local function setShopPoints(env, step)
  env.runState.shopPoints = step.value
  Common.assertRuntime(env, "fixtures.set_shop_points", { history = true })
  return env.runState.shopPoints
end

local function setShopRerolls(env, step)
  env.runState.shopRerollsRemaining = step.value
  Common.assertRuntime(env, "fixtures.set_shop_rerolls", { history = true })
  return env.runState.shopRerollsRemaining
end

local function purchase(env, step)
  local offerIndex = step.offerIndex

  if offerIndex == nil and step.offerType and step.contentId then
    offerIndex = ShopFlowSystem.findOfferIndex(env.shopFlow, step.offerType, step.contentId)
  end

  local purchased, result, offer = ShopFlowSystem.purchase(env.shopFlow, offerIndex)
  env:syncShopFlow(env.shopFlow)

  if step.expectSuccess == false then
    assert(not purchased, "expected purchase failure")
  else
    assert(purchased, result and result.reason or "purchase_failed")
  end

  Common.assertRuntime(env, "fixtures.purchase", { shopOffers = env.shopFlow.offers, history = true })

  return {
    ok = purchased,
    result = result,
    offer = Utils.clone(offer),
    offerIndex = offerIndex,
  }
end

local function reroll(env, step)
  local mode, errorMessage = ShopFlowSystem.reroll(env.shopFlow)
  env:syncShopFlow(env.shopFlow)

  if step.expectSuccess == false then
    assert(not mode, "expected reroll failure")
  else
    assert(mode, errorMessage or "reroll_failed")
  end

  Common.assertRuntime(env, "fixtures.reroll", { shopOffers = env.shopFlow.offers, history = true })

  return {
    ok = mode ~= nil,
    mode = mode,
    error = errorMessage,
  }
end

handlers.create_shop_visit = createShopVisit
handlers.ensure_shop_offers = ensureShopOffers
handlers.set_shop_points = setShopPoints
handlers.set_shop_rerolls = setShopRerolls
handlers.purchase = purchase
handlers.reroll = reroll

ShopSteps.handlers = handlers

return ShopSteps
