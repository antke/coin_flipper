local AcquisitionSystem = require("src.systems.acquisition_system")
local ActionQueue = require("src.core.action_queue")
local Coins = require("src.content.coins")
local CrumbleSystem = require("src.systems.crumble_system")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local ShopSystem = {}

local MAX_BLACK_MARKET_TRICK_OFFERS = 1
local UNCOMMON_OR_BETTER = {
  uncommon = true,
  rare = true,
}

local function isTrickType(offerType)
  return offerType == "trick" or offerType == "upgrade"
end

local function buildUnownedPool(runState, definitions, offerType)
  local pool = {}
  local ownedIndex = {}
  local isUnlocked = offerType == "coin" and Coins.isUnlocked or Upgrades.isUnlocked
  local unlockedIds = offerType == "coin" and runState.unlockedCoinIds or (runState.unlockedTrickIds or runState.unlockedUpgradeIds)

  local ownedList = offerType == "coin" and {} or (runState.ownedTrickIds or runState.ownedUpgradeIds)

  for _, ownedId in ipairs(ownedList or {}) do
    ownedIndex[ownedId] = true
  end

  for _, definition in ipairs(definitions) do
    local offerEligible = not isTrickType(offerType) or definition.shopEligible == true
    local grantable = true

    if isTrickType(offerType) then
      grantable = Upgrades.canGrantUpgrade(ownedList, definition.id)
    else
      grantable = not ownedIndex[definition.id]
    end

    if offerEligible and isUnlocked(definition, unlockedIds) and grantable then
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

local function ensureExtortionTrace(context)
  context.trace.extortionEffects = context.trace.extortionEffects or {}
  return context.trace.extortionEffects
end

local function recordExtortionEffect(context, effect)
  table.insert(ensureExtortionTrace(context), effect)
end

local function isInitialGeneration(options)
  return options == nil or options.reason == nil or options.reason == "initial"
end

local function isRerollGeneration(options)
  return type(options and options.reason) == "string" and string.sub(options.reason, 1, 7) == "reroll_"
end

local function getRerollCount(options)
  local sessionCount = options and options.shopSession and options.shopSession.rerollsUsed or nil
  return math.max(0, math.floor(tonumber(options and options.rerollCount or sessionCount) or 0))
end

local function getUsedOfferIds(offers)
  local usedIds = {}

  for _, offer in ipairs(offers or {}) do
    usedIds[offer.contentId] = true
  end

  return usedIds
end

local function cloneOffer(offer)
  return offer and Utils.clone(offer) or nil
end

local function chooseUncommonOrBetterCoin(runState, rng, usedIds, rarityWeights)
  local candidates = {}

  for _, offer in ipairs(buildUnownedPool(runState, Coins.getAll(), "coin")) do
    if UNCOMMON_OR_BETTER[offer.rarity] and not usedIds[offer.contentId] then
      table.insert(candidates, offer)
    end
  end

  return takeRandomOffer(candidates, rng, usedIds, rarityWeights)
end

local function findCheapestCoinOffer(offers)
  local bestOffer = nil

  for _, offer in ipairs(offers or {}) do
    if offer.type == "coin" and offer.purchased ~= true then
      if not bestOffer
        or (offer.price or 0) < (bestOffer.price or 0) then
        bestOffer = offer
      end
    end
  end

  return bestOffer
end

local function consumeExtortionUse(runState, source, reason)
  if not source or not source.trickId then
    return nil
  end

  local crumble = CrumbleSystem.consumeUse(runState, source.trickId, reason)
  return crumble
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
      extorted = currentOffer.extorted == true,
      stolen = currentOffer.stolen == true,
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
      op = "add_influence",
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
    table.insert(actions, 2, { op = "grant_trick", trickId = offer.contentId, replacePosition = offer.replacePosition })
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

  local neededCoinOffers = math.max(0, shopRules.guaranteedCoinOffers - countOffersByType(offers, "coin"))

  for _ = 1, neededCoinOffers do
    local offer = takeRandomOffer(coinPool, rng, usedIds, shopRules.rarityWeights)

    if offer then
      table.insert(offers, offer)
    end
  end

  while #offers < (shopRules.offerCount + bonusOfferCount) do
    local mixedPool = {}
    Utils.appendAll(mixedPool, coinPool)

    local offer = takeRandomOffer(mixedPool, rng, usedIds, shopRules.rarityWeights)

    if not offer then
      break
    end

    table.insert(offers, offer)
  end

  return shopRules
end

local function applyLoadedShelves(runState, context, rng, shopRules, options)
  if not isInitialGeneration(options) then
    return
  end

  local source = CrumbleSystem.findOwnedEffectSource(runState, "guarantee_uncommon_coin")
  if not source then
    return
  end

  for _, offer in ipairs(context.shopOffers or {}) do
    if offer.type == "coin" and UNCOMMON_OR_BETTER[offer.rarity] then
      recordExtortionEffect(context, {
        effect = "guarantee_uncommon_coin",
        sourceId = source.trickId,
        natural = true,
        crumble = consumeExtortionUse(runState, source, "black_market_visit"),
      })
      return
    end
  end

  local usedIds = getUsedOfferIds(context.shopOffers)
  local guaranteedOffer = chooseUncommonOrBetterCoin(runState, rng, usedIds, shopRules and shopRules.rarityWeights or nil)

  if not guaranteedOffer then
    recordExtortionEffect(context, {
      effect = "guarantee_uncommon_coin",
      sourceId = source.trickId,
      skipped = true,
      skipReason = "no_uncommon_coin_available",
    })
    return
  end

  local replacedOffer = nil
  local replacedIndex = nil

  for index, offer in ipairs(context.shopOffers or {}) do
    if offer.type == "coin" and not UNCOMMON_OR_BETTER[offer.rarity] then
      replacedOffer = offer
      replacedIndex = index
      break
    end
  end

  if replacedIndex then
    context.shopOffers[replacedIndex] = guaranteedOffer
  else
    table.insert(context.shopOffers, guaranteedOffer)
  end

  guaranteedOffer.guaranteedByExtortion = true
  guaranteedOffer.extortionSourceId = source.trickId

  recordExtortionEffect(context, {
    effect = "guarantee_uncommon_coin",
    sourceId = source.trickId,
    contentId = guaranteedOffer.contentId,
    rarity = guaranteedOffer.rarity,
    replacedContentId = replacedOffer and replacedOffer.contentId or nil,
    crumble = consumeExtortionUse(runState, source, "black_market_visit"),
  })
end

local function applyFiveFingerDiscount(runState, context, options)
  if not isInitialGeneration(options) then
    return
  end

  local source = CrumbleSystem.findOwnedEffectSource(runState, "extort_cheapest_coin")
  local offer = source and findCheapestCoinOffer(context.shopOffers) or nil

  if not source or not offer then
    return
  end

  local previousPrice = offer.price or 0
  offer.extorted = true
  offer.stolen = true
  offer.priceBeforeExtortion = previousPrice
  offer.extortionSourceId = source.trickId
  offer.extortionEffect = "extort_cheapest_coin"
  offer.price = 0

  recordExtortionEffect(context, {
    effect = "extort_cheapest_coin",
    sourceId = source.trickId,
    contentId = offer.contentId,
    priceBefore = previousPrice,
    priceAfter = offer.price,
    crumble = consumeExtortionUse(runState, source, "black_market_visit"),
  })
end

local function applyPressureSale(runState, context, options)
  if not isRerollGeneration(options) then
    return
  end

  local source = CrumbleSystem.findOwnedEffectSource(runState, "pressure_reroll_discount")
  local rerollCount = getRerollCount(options)
  local discount = math.max(1, rerollCount)
  local adjustedOffers = {}

  if not source then
    return
  end

  for _, offer in ipairs(context.shopOffers or {}) do
    if offer.type == "coin" and offer.purchased ~= true then
      local priceBefore = offer.price or 0
      offer.priceBeforePressureSale = priceBefore
      offer.pressureSaleDiscount = discount
      offer.pressureSaleSourceId = source.trickId
      offer.price = math.max(0, priceBefore - discount)
      table.insert(adjustedOffers, {
        contentId = offer.contentId,
        priceBefore = priceBefore,
        priceAfter = offer.price,
      })
    end
  end

  if #adjustedOffers == 0 then
    return
  end

  recordExtortionEffect(context, {
    effect = "pressure_reroll_discount",
    sourceId = source.trickId,
    rerollCount = rerollCount,
    discount = discount,
    offers = adjustedOffers,
    crumble = consumeExtortionUse(runState, source, "black_market_reroll"),
  })
end

local function applyNoQuestionsAsked(runState, stageState, context, offer)
  if not (offer and offer.type == "coin" and offer.extorted == true) then
    return
  end

  local source = CrumbleSystem.findOwnedEffectSource(runState, "extorted_coin_reroll")

  if not source then
    return
  end

  ActionQueue.applyAll(runState, stageState, context, {
    { op = "add_shop_rerolls", amount = 1, reason = "no_questions_asked", trickId = source.trickId },
  })

  recordExtortionEffect(context, {
    effect = "extorted_coin_reroll",
    sourceId = source.trickId,
    contentId = offer.contentId,
    amount = 1,
    shopRerollsAfter = runState.shopRerollsRemaining or 0,
    crumble = consumeExtortionUse(runState, source, "extorted_coin_taken"),
  })
end

function ShopSystem.generateOffers(runState, stageState, metaProjection, rng, options)
  options = options or {}
  local sources = HookRegistry.collectSources(runState, stageState, metaProjection)
  local context = createShopContext(runState, stageState, metaProjection, {}, nil, "generation")
  context.activeSources = sources

  runHookPhase("before_shop_generation", sources, context)
  local shopRules = buildBaseOffers(runState, stageState, metaProjection, rng, context.shopOffers, context)
  applyLoadedShelves(runState, context, rng, shopRules, options)
  normalizeOffers(context.shopOffers)
  runHookPhase("after_shop_generation", sources, context)
  applyFiveFingerDiscount(runState, context, options)
  applyPressureSale(runState, context, options)
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

  if runState.influence < offer.price then
    return failPurchase("not_enough_shop_points", context)
  end

  local chargedPrice = offer.price
  local grantOk, grantResult, grantMetadata = AcquisitionSystem.canGrantByType(runState, offer.type, offer.contentId)

  if not grantOk then
    return failPurchase(grantResult, context)
  end
  if type(grantMetadata) == "table" and grantMetadata.code == "trick_board_full"
    and offer.replacePosition == nil then
    return failPurchase("trick_board_full", context)
  end

  ActionQueue.applyAll(runState, stageState, context, buildPurchaseActions(offer, chargedPrice))
  applyNoQuestionsAsked(runState, stageState, context, offer)

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

  if runState.influence < rerollCost then
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

  runState.influence = runState.influence - rerollCost
  Validator.assertRuntimeInvariants("shop_system.consumeReroll", runState, stageState)
  return "paid"
end

function ShopSystem.grantUpgrade(runState, upgradeId, options)
  return AcquisitionSystem.grantUpgrade(runState, upgradeId, nil, options)
end

function ShopSystem.grantCoin(runState, coinId)
  return AcquisitionSystem.grantCoin(runState, coinId)
end

return ShopSystem
