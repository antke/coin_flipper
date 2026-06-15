local CoinTraits = require("src.core.coin_traits")
local ScoreBreakdown = require("src.domain.score_breakdown")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local ChainActions = {}

local CHAIN_OPS = {
  trigger_random_neighbor = true,
}

local function ensureScoreBreakdown(context)
  context.scoreBreakdown = context.scoreBreakdown or ScoreBreakdown.new()

  local scoreScalings = context.scoreBreakdown.scoreScalings or context.scoreBreakdown.multipliers or {}
  context.scoreBreakdown.scoreScalings = scoreScalings
  context.scoreBreakdown.multipliers = scoreScalings
end

local function recordWarning(options, context, message)
  if options and options.recordWarning then
    options.recordWarning(context, message)
  end
end

local function claimOnce(options, context, action, defaultKey, warning)
  if options and options.claimOnce then
    local key = defaultKey

    if options.getOnceKey then
      key = options.getOnceKey(action, defaultKey)
    elseif type(action.onceKey) == "string" and action.onceKey ~= "" then
      key = action.onceKey
    end

    return options.claimOnce(context, key, warning)
  end

  return true
end

local function contextWithFields(context, fields)
  return setmetatable(fields or {}, { __index = context })
end

local function findCoinRollByResolutionIndex(context, resolutionIndex)
  if not resolutionIndex then
    return nil
  end

  for _, coinRoll in ipairs(context.trace and context.trace.coinRolls or {}) do
    if coinRoll.resolutionIndex == resolutionIndex then
      return coinRoll
    end
  end

  return nil
end

local function getSpecializedCandidates(candidates, family)
  return CoinTraits.filterByFamily(candidates, family)
end

local function chooseChainNeighbor(context, source, usedResolutionIndices, family, selector)
  if type(selector) == "table" then
    return TargetSelectors.resolveSlot(nil, nil, selector, contextWithFields(context, {
      currentCoin = source,
      usedResolutionIndices = usedResolutionIndices,
    }))
  end

  local sourceResolutionIndex = source and source.resolutionIndex
  local candidates = {}

  if not sourceResolutionIndex then
    return nil, nil
  end

  for _, coinState in ipairs(context.perCoin or {}) do
    local resolutionIndex = coinState.resolutionIndex

    if resolutionIndex
      and math.abs(resolutionIndex - sourceResolutionIndex) == 1
      and not usedResolutionIndices[resolutionIndex]
      and coinState.instanceId ~= source.instanceId then
      table.insert(candidates, coinState)
    end
  end

  if #candidates == 0 then
    return nil, nil
  end

  local specialized = getSpecializedCandidates(candidates, family)
  local pool = #specialized > 0 and specialized or candidates

  if #pool == 1 or not (context.rng and context.rng.choose) then
    return pool[1], 1
  end

  return context.rng:choose(pool)
end

local function annotateChainRoll(coinRoll, target, source, sourceId, depth, linkIndex)
  if not coinRoll then
    return
  end

  coinRoll.chained = true
  coinRoll.chainedBy = sourceId
  coinRoll.chainDepth = depth
  coinRoll.chainLinkIndex = linkIndex
  coinRoll.chainSourceCoinId = source.coinId
  coinRoll.chainSourceInstanceId = source.instanceId
  coinRoll.chainSourceSlotIndex = source.slotIndex
  coinRoll.chainSourceResolutionIndex = source.resolutionIndex
  coinRoll.chainRootInstanceId = source.chainRootInstanceId or source.instanceId
  coinRoll.chainRootCoinId = source.chainRootCoinId or source.coinId
end

local function markChainedCoin(context, source, target, sourceId, depth, linkIndex)
  target.chained = true
  target.chainedBy = sourceId
  target.chainDepth = depth
  target.chainLinkIndex = linkIndex
  target.chainSourceCoinId = source.coinId
  target.chainSourceInstanceId = source.instanceId
  target.chainSourceSlotIndex = source.slotIndex
  target.chainSourceResolutionIndex = source.resolutionIndex
  target.chainRootInstanceId = source.chainRootInstanceId or source.instanceId
  target.chainRootCoinId = source.chainRootCoinId or source.coinId

  annotateChainRoll(findCoinRollByResolutionIndex(context, target.resolutionIndex), target, source, sourceId, depth, linkIndex)
end

local function applyTriggerRandomNeighbor(context, action, options)
  ensureScoreBreakdown(context)

  local source = context.currentCoin

  if not source then
    recordWarning(options, context, "trigger_random_neighbor ignored without a source coin.")
    return
  end

  if not claimOnce(
    options,
    context,
    action,
    "trigger_random_neighbor",
    "trigger_random_neighbor ignored because a Chain already propagated this flip."
  ) then
    return
  end

  local chance = tonumber(action.chainChance) or 0.5
  local maxDepth = tonumber(action.maxChainDepth) or 2
  local maxTriggers = tonumber(action.maxTriggers) or maxDepth
  local sourceId = action._trace and action._trace.sourceId or nil
  local usedResolutionIndices = {}
  local currentSource = source
  local links = {}

  context.trace.chainLinks = context.trace.chainLinks or {}
  context.scoreBreakdown.chainLinks = context.scoreBreakdown.chainLinks or {}
  action.chainRolls = {}
  action.sourceCoinId = source.coinId
  action.sourceInstanceId = source.instanceId
  action.sourceSlotIndex = source.slotIndex
  action.sourceResolutionIndex = source.resolutionIndex
  action.chainChance = chance
  action.maxChainDepth = maxDepth
  action.maxTriggers = maxTriggers
  usedResolutionIndices[source.resolutionIndex] = true

  for triggerIndex = 1, maxTriggers do
    local sourceDepth = tonumber(currentSource.chainDepth) or 0

    if sourceDepth >= maxDepth then
      break
    end

    local roll = context.rng and context.rng.nextFloat and context.rng:nextFloat() or 1
    local success = roll <= chance
    local rollEntry = {
      sourceCoinId = currentSource.coinId,
      sourceInstanceId = currentSource.instanceId,
      sourceSlotIndex = currentSource.slotIndex,
      sourceResolutionIndex = currentSource.resolutionIndex,
      chainDepth = sourceDepth,
      roll = roll,
      chance = chance,
      success = success,
    }
    table.insert(action.chainRolls, rollEntry)

    if not success then
      break
    end

    local target, chosenNeighborIndex = chooseChainNeighbor(context, currentSource, usedResolutionIndices, action.specializedFamily, action.target)

    if not target then
      recordWarning(options, context, "trigger_random_neighbor had no eligible unused neighbour.")
      break
    end

    local depth = sourceDepth + 1
    local linkIndex = #links + 1

    markChainedCoin(context, currentSource, target, sourceId, depth, linkIndex)
    usedResolutionIndices[target.resolutionIndex] = true

    local link = {
      op = "trigger_random_neighbor",
      sourceId = sourceId,
      sourceCoinId = currentSource.coinId,
      sourceInstanceId = currentSource.instanceId,
      sourceSlotIndex = currentSource.slotIndex,
      sourceResolutionIndex = currentSource.resolutionIndex,
      targetCoinId = target.coinId,
      targetInstanceId = target.instanceId,
      targetSlotIndex = target.slotIndex,
      targetResolutionIndex = target.resolutionIndex,
      chained = true,
      chainedBy = sourceId,
      chainDepth = depth,
      chainLinkIndex = linkIndex,
      chainChance = chance,
      chainRoll = roll,
      chosenNeighborIndex = chosenNeighborIndex,
      maxChainDepth = maxDepth,
    }

    table.insert(links, link)
    table.insert(context.trace.chainLinks, link)
    table.insert(context.scoreBreakdown.chainLinks, Utils.clone(link))
    currentSource = target
  end

  if #links > 0 then
    local firstLink = links[1]
    local lastLink = links[#links]

    action.chainTriggered = true
    action.chainLinkCount = #links
    action.chainDepth = lastLink.chainDepth
    action.targetCoinId = firstLink.targetCoinId
    action.targetInstanceId = firstLink.targetInstanceId
    action.targetSlotIndex = firstLink.targetSlotIndex
    action.targetResolutionIndex = firstLink.targetResolutionIndex
    action.chained = true
    action.chainedBy = sourceId
    action.chainedCoinId = firstLink.targetCoinId
    action.chainedInstanceId = firstLink.targetInstanceId
    action.chainedSlotIndex = firstLink.targetSlotIndex
    action.chainedResolutionIndex = firstLink.targetResolutionIndex
  else
    action.chainTriggered = false
    action.chainLinkCount = 0
  end
end

function ChainActions.isChainOp(op)
  return CHAIN_OPS[op] == true
end

function ChainActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.target ~= nil and type(action.target) ~= "table" then
    return false, "trigger_random_neighbor target must be selector when present"
  end

  if type(action.target) == "table" then
    local validSelector, selectorError = selectors.validateSlotSelector(action.target, { selected_coins = true })
    if not validSelector then
      return false, "trigger_random_neighbor " .. selectorError
    end
  end

  if action.chainChance ~= nil and (type(action.chainChance) ~= "number" or action.chainChance < 0 or action.chainChance > 1) then
    return false, "trigger_random_neighbor chainChance must be between 0 and 1 when present"
  end

  if action.maxChainDepth ~= nil and (type(action.maxChainDepth) ~= "number" or math.floor(action.maxChainDepth) ~= action.maxChainDepth or action.maxChainDepth < 1) then
    return false, "trigger_random_neighbor maxChainDepth must be a positive integer when present"
  end

  if action.maxTriggers ~= nil and (type(action.maxTriggers) ~= "number" or math.floor(action.maxTriggers) ~= action.maxTriggers or action.maxTriggers < 1) then
    return false, "trigger_random_neighbor maxTriggers must be a positive integer when present"
  end

  return true
end

function ChainActions.apply(context, action, options)
  if action.op == "trigger_random_neighbor" then
    applyTriggerRandomNeighbor(context, action, options)
    return true
  end

  return false
end

return ChainActions
