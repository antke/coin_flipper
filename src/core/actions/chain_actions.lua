local CoinTraits = require("src.core.coin_traits")
local ScoreBreakdown = require("src.domain.score_breakdown")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local ChainActions = {}

local CHAIN_OPS = {
  trigger_random_neighbor = true,
}

local VALID_DIRECTIONS = {
  random = true,
  left = true,
  right = true,
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

local function directionMatches(sourceResolutionIndex, targetResolutionIndex, direction)
  if direction == "left" then
    return targetResolutionIndex == sourceResolutionIndex - 1
  end

  if direction == "right" then
    return targetResolutionIndex == sourceResolutionIndex + 1
  end

  return math.abs(targetResolutionIndex - sourceResolutionIndex) == 1
end

local function normalizeDirections(action)
  local directions = {}

  if type(action.directions) == "table" then
    for _, direction in ipairs(action.directions) do
      if VALID_DIRECTIONS[direction] then
        table.insert(directions, direction)
      end
    end
  elseif VALID_DIRECTIONS[action.direction] then
    table.insert(directions, action.direction)
  end

  if #directions == 0 then
    table.insert(directions, "random")
  end

  return directions
end

local function chooseChainNeighbor(context, source, usedResolutionIndices, family, selector, direction)
  if (direction == nil or direction == "random") and type(selector) == "table" then
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
      and directionMatches(sourceResolutionIndex, resolutionIndex, direction or "random")
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

local function queueTriggeredCoinScore(context, target, sourceId, depth)
  if not target then
    return 0, 1
  end

  local materialMultiplier = 1
  if CoinTraits.hasRealFamily(target, "momentum") then
    materialMultiplier = CoinTraits.materialPayoffMultiplier(target, 1, 0.25, true)
  end

  local followThroughMultiplier = context.batchFlags and context.batchFlags.momentum_follow_through == true
    and (1 + (0.25 * depth))
    or 1
  local scoreMultiplier = materialMultiplier * followThroughMultiplier
  local amount = math.max(1, math.floor((CoinTraits.baseScore(target) * scoreMultiplier) + 0.00001))
  local queuedAction = {
    op = "add_stage_score",
    amount = amount,
    category = "momentum",
    label = "Momentum trigger",
    _trace = {
      phase = "after_coin_score",
      sourceId = sourceId,
      sourceType = "trick",
      slotIndex = target.selectedSlotIndex or target.anchorSelectedSlotIndex,
      originSlotIndex = context.currentActivation and context.currentActivation.sourceSlotIndex,
    },
  }

  context.pendingActions = context.pendingActions or {}
  context.pendingActions.after_scoring = context.pendingActions.after_scoring or {}
  table.insert(context.pendingActions.after_scoring, {
    phase = "after_scoring",
    chainDepth = (context.currentChainDepth or 0) + 1,
    actions = { queuedAction },
    queuedBy = Utils.clone(queuedAction._trace),
  })

  context.trace.queuedActions = context.trace.queuedActions or {}
  table.insert(context.trace.queuedActions, {
    phase = "after_scoring",
    chainDepth = (context.currentChainDepth or 0) + 1,
    actionCount = 1,
  })

  return amount, scoreMultiplier
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
  local continuationChance = tonumber(action.continuationChance) or chance
  local maxDepth = tonumber(action.maxChainDepth) or 2
  local maxTriggers = tonumber(action.maxTriggers) or maxDepth
  local sourceId = action._trace and action._trace.sourceId or nil
  local usedResolutionIndices = {}
  local links = {}
  local directions = normalizeDirections(action)

  context.trace.chainLinks = context.trace.chainLinks or {}
  context.scoreBreakdown.chainLinks = context.scoreBreakdown.chainLinks or {}
  action.chainRolls = {}
  action.sourceCoinId = source.coinId
  action.sourceInstanceId = source.instanceId
  action.sourceSlotIndex = source.slotIndex
  action.sourceResolutionIndex = source.resolutionIndex
  action.chainChance = chance
  action.continuationChance = continuationChance
  action.maxChainDepth = maxDepth
  action.maxTriggers = maxTriggers
  usedResolutionIndices[source.resolutionIndex] = true

  for branchIndex, direction in ipairs(directions) do
    local currentSource = source
    local branchStep = 1

    while #links < maxTriggers do
      local sourceDepth = tonumber(currentSource.chainDepth) or 0

      if sourceDepth >= maxDepth then
        break
      end

      local rollChance = branchStep == 1 and chance or continuationChance
      local roll = context.rng and context.rng.nextFloat and context.rng:nextFloat() or 1
      local success = roll <= rollChance
      local rollEntry = {
        sourceCoinId = currentSource.coinId,
        sourceInstanceId = currentSource.instanceId,
        sourceSlotIndex = currentSource.slotIndex,
        sourceResolutionIndex = currentSource.resolutionIndex,
        chainDepth = sourceDepth,
        roll = roll,
        chance = rollChance,
        success = success,
        direction = direction,
        branchIndex = branchIndex,
        branchStep = branchStep,
      }
      table.insert(action.chainRolls, rollEntry)

      if not success then
        break
      end

      local target, chosenNeighborIndex = chooseChainNeighbor(context, currentSource, usedResolutionIndices, action.specializedFamily, action.target, direction)

      if not target then
        recordWarning(options, context, "trigger_random_neighbor had no eligible unused neighbour.")
        break
      end

      local depth = sourceDepth + 1
      local linkIndex = #links + 1

      markChainedCoin(context, currentSource, target, sourceId, depth, linkIndex)
      usedResolutionIndices[target.resolutionIndex] = true

      local triggeredScore, triggeredScoreMultiplier = queueTriggeredCoinScore(context, target, sourceId, depth)

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
        chainChance = rollChance,
        chainRoll = roll,
        chosenNeighborIndex = chosenNeighborIndex,
        maxChainDepth = maxDepth,
        direction = direction,
        branchIndex = branchIndex,
        branchStep = branchStep,
        triggeredScore = triggeredScore,
        triggeredScoreMultiplier = triggeredScoreMultiplier,
      }

      table.insert(links, link)
      table.insert(context.trace.chainLinks, link)
      table.insert(context.scoreBreakdown.chainLinks, Utils.clone(link))
      currentSource = target
      branchStep = branchStep + 1
    end
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

  if action.continuationChance ~= nil and (type(action.continuationChance) ~= "number" or action.continuationChance < 0 or action.continuationChance > 1) then
    return false, "trigger_random_neighbor continuationChance must be between 0 and 1 when present"
  end

  if action.direction ~= nil and not VALID_DIRECTIONS[action.direction] then
    return false, "trigger_random_neighbor direction must be random|left|right when present"
  end

  if action.directions ~= nil then
    if type(action.directions) ~= "table" then
      return false, "trigger_random_neighbor directions must be a list when present"
    end

    for _, direction in ipairs(action.directions) do
      if not VALID_DIRECTIONS[direction] then
        return false, "trigger_random_neighbor directions entries must be random|left|right"
      end
    end
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
