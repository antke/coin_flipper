local TriggerScope = {}

local PER_COIN_PHASES = {
  before_coin_roll = true,
  after_coin_roll = true,
  before_coin_score = true,
  after_coin_score = true,
}

local function sourceKey(source)
  return table.concat({
    tostring(source and source.sourceType or "source"),
    tostring(source and source.sourceId or "unknown"),
  }, ":")
end

local function triggerKey(phaseName, source, triggerIndex)
  return table.concat({
    sourceKey(source),
    tostring(phaseName),
    tostring(triggerIndex or 0),
  }, "|")
end

local function positiveInteger(value)
  return type(value) == "number" and math.floor(value) == value and value >= 1
end

local function countKey(baseKey, scopeName, identity)
  return table.concat({ baseKey, scopeName, tostring(identity or "global") }, "|")
end

local function currentCoinIdentity(context)
  local currentCoin = context and context.currentCoin or nil
  return currentCoin and (currentCoin.instanceId or currentCoin.resolutionIndex or currentCoin.slotIndex) or nil
end

local function currentOfferIdentity(context)
  local offer = context and context.currentOffer or nil
  return offer and (offer.offerId or offer.contentId or offer.id or offer.index) or nil
end

local function currentPurchaseIdentity(context)
  local purchase = context and context.purchase or nil
  return purchase and table.concat({
    tostring(purchase.type or "purchase"),
    tostring(purchase.contentId or purchase.id or "unknown"),
  }, ":") or nil
end

local function claim(context, key, limit)
  context.triggerScopeCounts = context.triggerScopeCounts or {}

  local count = context.triggerScopeCounts[key] or 0

  if count >= limit then
    return false
  end

  context.triggerScopeCounts[key] = count + 1
  return true
end

local function claimLimit(context, baseKey, scopeName, identity, limit)
  if not positiveInteger(limit) then
    return true
  end

  return claim(context, countKey(baseKey, scopeName, identity), limit)
end

function TriggerScope.shouldRun(phaseName, source, trigger, triggerIndex, context)
  local definition = source and source.definition or nil
  local scope = definition and ((definition.trick and definition.trick.scope) or definition.scope) or {}
  local baseKey = triggerKey(phaseName, source, triggerIndex)

  if scope.maxTriggersPerCoin ~= nil then
    local coinIdentity = currentCoinIdentity(context)

    if coinIdentity and not claimLimit(context, baseKey, "maxTriggersPerCoin", coinIdentity, scope.maxTriggersPerCoin) then
      return false
    end
  end

  if scope.maxTriggersPerOffer ~= nil then
    local offerIdentity = currentOfferIdentity(context)

    if offerIdentity and not claimLimit(context, baseKey, "maxTriggersPerOffer", offerIdentity, scope.maxTriggersPerOffer) then
      return false
    end
  end

  if scope.maxTriggersPerPurchase ~= nil then
    local purchaseIdentity = currentPurchaseIdentity(context)

    if purchaseIdentity and not claimLimit(context, baseKey, "maxTriggersPerPurchase", purchaseIdentity, scope.maxTriggersPerPurchase) then
      return false
    end
  end

  if scope.oncePerDeal == true then
    if not claimLimit(context, baseKey, "oncePerDeal", nil, 1) then
      return false
    end
  end

  if scope.maxTemporaryEffectsPerFlip ~= nil then
    if not claimLimit(context, baseKey, "maxTemporaryEffectsPerFlip", nil, scope.maxTemporaryEffectsPerFlip) then
      return false
    end
  end

  if scope.oncePerFlip == true then
    if not claimLimit(context, baseKey, "oncePerFlip", nil, 1) then
      return false
    end
  elseif scope.maxTriggersPerFlip ~= nil and not PER_COIN_PHASES[phaseName] then
    if not claimLimit(context, baseKey, "maxTriggersPerFlip", nil, scope.maxTriggersPerFlip) then
      return false
    end
  end

  return true
end

return TriggerScope
