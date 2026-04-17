local AcquisitionSystem = require("src.systems.acquisition_system")
local ActionQueue = require("src.core.action_queue")
local Coins = require("src.content.coins")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local ShopSystem = {}

local function buildUnownedPool(runState, definitions, offerType)
  local pool = {}
  local ownedIndex = {}
  local isUnlocked = offerType == "coin" and Coins.isUnlocked or Upgrades.isUnlocked
  local unlockedIds = offerType == "coin" and runState.unlockedCoinIds or runState.unlockedUpgradeIds

  local ownedList = offerType == "coin" and runState.collectionCoinIds or runState.ownedUpgradeIds

  for _, ownedId in ipairs(ownedList or {}) do
    ownedIndex[ownedId] = true
  end

  for _, definition in ipairs(definitions) do
    if isUnlocked(definition, unlockedIds) and not ownedIndex[definition.id] then
      table.insert(pool, {
        type = offerType,
        contentId = definition.id,
        name = definition.name,
        rarity = definition.rarity,
        price = ShopContent.resolvePrice(offerType, definition),
      })
    end
  end

  return pool
end

local function getOfferWeight(offer, rarityWeights)
  local value = rarityWeights and rarityWeights[offer.rarity] or nil

  if type(value) ~= "number" then
    return 1.0
  end

  return math.max(0, value)
end

local function takeRandomOffer(pool, rng, usedIds, rarityWeights)
  local candidates = {}
  local totalWeight = 0

  for _, offer in ipairs(pool) do
    if not usedIds[offer.contentId] then
      table.insert(candidates, offer)
      totalWeight = totalWeight + getOfferWeight(offer, rarityWeights)
    end
  end

  local offer = nil

  if totalWeight > 0 then
    local targetWeight = rng:nextFloat() * totalWeight
    local runningWeight = 0

    for _, candidate in ipairs(candidates) do
      runningWeight = runningWeight + getOfferWeight(candidate, rarityWeights)

      if targetWeight <= runningWeight then
        offer = candidate
        break
      end
    end
  else
    offer = rng:choose(candidates)
  end

  if offer then
    usedIds[offer.contentId] = true
  end

  return offer
end

local function countOffersByType(offers, offerType)
  local count = 0

  for _, offer in ipairs(offers or {}) do
    if offer.type == offerType then
      count = count + 1
    end
  end

  return count
end

local function normalizeOffers(offers)
  for index, offer in ipairs(offers or {}) do
    offer.id = string.format("offer_%02d", index)
    offer.purchased = offer.purchased == true
  end
end

local function buildShopTrace(mode)
  return {
    mode = mode,
    triggeredSources = {},
    actions = {},
    notes = {},
    messages = {},
  }
end

local function createShopContext(runState, stageState, metaProjection, offers, currentOffer, mode)
  return ActionQueue.createContext(mode, {
    runState = runState,
    stageState = stageState,
    metaProjection = metaProjection,
    shopOffers = offers or {},
    currentOffer = currentOffer,
    purchase = currentOffer and {
      type = currentOffer.type,
      contentId = currentOffer.contentId,
      rarity = currentOffer.rarity,
    } or nil,
    shopMessages = {},
    trace = buildShopTrace(mode),
  })
end

local function runHookPhase(phaseName, sources, context)
  context.activeSources = sources or context.activeSources or {}
  local actions = HookRegistry.runPhase(phaseName, sources, context)
  ActionQueue.applyAll(context.runState, context.stageState, context, actions)
end

local function finalizeShopTrace(context)
  context.trace.messages = Utils.copyArray(context.shopMessages)
  return context.trace
end

local function failPurchase(reason, context)
  return false, {
    reason = reason,
    trace = finalizeShopTrace(context),
  }
end

local function buildPurchaseActions(offer, chargedPrice)
  local actions = {
    {
      op = "add_shop_points",
      amount = -chargedPrice,
      applyMultiplier = false,
      category = "purchase_cost",
      label = "shop_purchase",
    },
    {
      op = "mark_shop_offer_purchased",
    },
    {
      op = "record_purchase",
      purchaseType = offer.type,
      contentId = offer.contentId,
      price = chargedPrice,
    },
  }

  if offer.type == "coin" then
    table.insert(actions, 2, { op = "grant_coin", coinId = offer.contentId })
  else
    table.insert(actions, 2, { op = "grant_upgrade", upgradeId = offer.contentId })
  end

  return actions
end

local function buildBaseOffers(runState, stageState, metaProjection, rng, offers, context)
  local usedIds = {}
  local bonusOfferCount = #offers
  local shopRules = EffectiveValueSystem.getShopRules(runState, stageState, {
    metaProjection = metaProjection or runState.metaProjection,
    activeSources = context and context.activeSources or nil,
  })

  for _, offer in ipairs(offers or {}) do
    usedIds[offer.contentId] = true
  end

  local coinPool = buildUnownedPool(runState, Coins.getAll(), "coin")
  local upgradePool = buildUnownedPool(runState, Upgrades.getAll(), "upgrade")

  local neededCoinOffers = math.max(0, shopRules.guaranteedCoinOffers - countOffersByType(offers, "coin"))
  local neededUpgradeOffers = math.max(0, shopRules.guaranteedUpgradeOffers - countOffersByType(offers, "upgrade"))

  for _ = 1, neededCoinOffers do
    local offer = takeRandomOffer(coinPool, rng, usedIds, shopRules.rarityWeights)

    if offer then
      table.insert(offers, offer)
    end
  end

  for _ = 1, neededUpgradeOffers do
    local offer = takeRandomOffer(upgradePool, rng, usedIds, shopRules.rarityWeights)

    if offer then
      table.insert(offers, offer)
    end
  end

  local mixedPool = {}
  Utils.appendAll(mixedPool, coinPool)
  Utils.appendAll(mixedPool, upgradePool)

  while #offers < (shopRules.offerCount + bonusOfferCount) do
    local offer = takeRandomOffer(mixedPool, rng, usedIds, shopRules.rarityWeights)

    if not offer then
      break
    end

    table.insert(offers, offer)
  end

  return shopRules
end

function ShopSystem.generateOffers(runState, stageState, metaProjection, rng)
  local sources = HookRegistry.collectSources(runState, stageState, metaProjection)
  local context = createShopContext(runState, stageState, metaProjection, {}, nil, "generation")
  context.activeSources = sources

  runHookPhase("before_shop_generation", sources, context)
  local shopRules = buildBaseOffers(runState, stageState, metaProjection, rng, context.shopOffers, context)
  normalizeOffers(context.shopOffers)
  runHookPhase("after_shop_generation", sources, context)
  normalizeOffers(context.shopOffers)

  finalizeShopTrace(context)
  context.trace.offerCount = #context.shopOffers
  context.trace.resolvedShopRules = Utils.clone(shopRules)
  Validator.assertRuntimeInvariants("shop_system.generateOffers", runState, stageState, {
    shopOffers = context.shopOffers,
  })

  return context.shopOffers, context.trace
end

function ShopSystem.purchaseOffer(runState, offer, stageState, metaProjection)
  if not offer then
    return false, { reason = "offer_not_found", trace = nil }
  end

  if offer.purchased then
    return false, { reason = "offer_already_purchased", trace = nil }
  end

  local sources = HookRegistry.collectSources(runState, stageState, metaProjection)
  local context = createShopContext(runState, stageState, metaProjection, { offer }, offer, "purchase")
  context.activeSources = sources

  runHookPhase("before_purchase", sources, context)

  if context.purchaseBlocked then
    return failPurchase(context.purchaseBlockReason or "purchase_blocked", context)
  end

  if runState.shopPoints < offer.price then
    return failPurchase("not_enough_shop_points", context)
  end

  local chargedPrice = offer.price
  local grantOk, grantResult = AcquisitionSystem.canGrantByType(runState, offer.type, offer.contentId)

  if not grantOk then
    return failPurchase(grantResult, context)
  end

  ActionQueue.applyAll(runState, stageState, context, buildPurchaseActions(offer, chargedPrice))

  -- Intentionally reuse the pre-purchase source snapshot here so the newly acquired
  -- upgrade starts affecting later shop visits or purchases, not the transaction that bought it.
  runHookPhase("after_purchase", sources, context)

  finalizeShopTrace(context)
  context.trace.finalPrice = chargedPrice
  Validator.assertRuntimeInvariants("shop_system.purchaseOffer", runState, stageState)

  return true, {
    offer = offer,
    trace = context.trace,
    finalPrice = chargedPrice,
  }
end

function ShopSystem.canReroll(runState, stageState, metaProjection)
  if not runState then
    return false, "run_not_initialized"
  end

  local rerollCost = EffectiveValueSystem.getShopRules(runState, stageState, {
    metaProjection = metaProjection or runState.metaProjection,
  }).rerollCost

  if (runState.shopRerollsRemaining or 0) > 0 then
    return true
  end

  if runState.shopPoints < rerollCost then
    return false, "not_enough_shop_points"
  end

  return true
end

function ShopSystem.consumeReroll(runState, stageState, metaProjection)
  local rerollCost = EffectiveValueSystem.getShopRules(runState, stageState, {
    metaProjection = metaProjection or runState.metaProjection,
  }).rerollCost
  local ok, errorMessage = ShopSystem.canReroll(runState, stageState, metaProjection)

  if not ok then
    return nil, errorMessage
  end

  if (runState.shopRerollsRemaining or 0) > 0 then
    runState.shopRerollsRemaining = runState.shopRerollsRemaining - 1
    Validator.assertRuntimeInvariants("shop_system.consumeReroll", runState, stageState)
    return "free"
  end

  runState.shopPoints = runState.shopPoints - rerollCost
  Validator.assertRuntimeInvariants("shop_system.consumeReroll", runState, stageState)
  return "paid"
end

function ShopSystem.grantUpgrade(runState, upgradeId)
  return AcquisitionSystem.grantUpgrade(runState, upgradeId)
end

function ShopSystem.grantCoin(runState, coinId)
  return AcquisitionSystem.grantCoin(runState, coinId)
end

return ShopSystem
