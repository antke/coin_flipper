local Coins = require("src.content.coins")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local Loadout = require("src.domain.loadout")
local ScoreBreakdown = require("src.domain.score_breakdown")
local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local ActionQueue = {}

local PurseSystem = require("src.systems.purse_system")

ActionQueue.ACQUISITION_SAFE_OPS = {
  add_shop_points = true,
  add_shop_rerolls = true,
  increase_coin_slots = true,
  grant_coin = true,
  grant_upgrade = true,
  queue_trace_note = true,
  set_run_flag = true,
}

ActionQueue.KNOWN_OPS = {
  add_stage_score = true,
  add_run_score = true,
  add_shop_points = true,
  add_luck = true,
  add_weight = true,
  set_call_match_chance = true,
  foretell_coin_result = true,
  forge_identity = true,
  redirect_score_credit = true,
  swap_coins = true,
  smuggle_coin_from_hand = true,
  replay_resolution_packet = true,
  trigger_random_neighbor = true,
  modify_coin_weight = true,
  apply_score_multiplier = true,
  set_batch_flag = true,
  set_shop_flag = true,
  set_stage_flag = true,
  set_run_flag = true,
  queue_trace_note = true,
  grant_upgrade = true,
  grant_coin = true,
  increase_coin_slots = true,
  add_shop_rerolls = true,
  set_flips_remaining = true,
  consume_effect = true,
  add_shop_offer = true,
  adjust_shop_price = true,
  block_purchase = true,
  add_shop_message = true,
  mark_shop_offer_purchased = true,
  record_purchase = true,
  grant_temporary_effect = true,
  queue_actions = true,
}

local function ensureTrace(context)
  context.trace = context.trace or {}
  context.trace.actions = context.trace.actions or {}
  context.trace.notes = context.trace.notes or {}
  context.trace.warnings = context.trace.warnings or {}
  context.trace.queuedActions = context.trace.queuedActions or {}
  context.trace.temporaryEffectsGranted = context.trace.temporaryEffectsGranted or {}
  context.trace.temporaryEffectsConsumed = context.trace.temporaryEffectsConsumed or {}
end

local function requireStageState(stageState, op)
  if not stageState then
    error(string.format("%s requires an active stageState", op))
  end
end

local function ensureScoreBreakdown(context)
  context.scoreBreakdown = context.scoreBreakdown or ScoreBreakdown.new()
end

local function ensureShopContext(context)
  context.shopOffers = context.shopOffers or {}
  context.shopMessages = context.shopMessages or {}
end

local function ensurePendingActionContext(context)
  context.pendingActions = context.pendingActions or {}
end

local function recordWarning(context, message)
  ensureTrace(context)
  table.insert(context.trace.warnings, message)
  table.insert(context.trace.notes, message)
end

local function cloneActionForTrace(action)
  local tracedAction = Utils.clone(action)
  tracedAction._trace = tracedAction._trace or nil
  return tracedAction
end

local function addScoreBreakdownEntry(targetList, action, extraFields)
  local entry = {
    op = action.op,
    amount = action.amount,
    value = action.value,
    category = action.category,
    label = action.label,
    trace = Utils.clone(action._trace),
  }

  for key, value in pairs(extraFields or {}) do
    entry[key] = value
  end

  table.insert(targetList, entry)
end

function ActionQueue.createContext(mode, overrides)
  local context = {
    runState = nil,
    stageState = nil,
    metaProjection = {
      modifiers = {},
    },
    batchFlags = {},
    shopFlags = {},
    shopOffers = {},
    currentOffer = nil,
    purchase = nil,
    shopMessages = {},
    activeSources = {},
    pendingActions = {},
    currentPhase = nil,
    currentChainDepth = 0,
    actionMetrics = nil,
    trace = {
      mode = mode or "generic",
      actions = {},
      notes = {},
      messages = {},
    },
  }

  for key, value in pairs(overrides or {}) do
    if key == "trace" and type(value) == "table" then
      for traceKey, traceValue in pairs(value) do
        context.trace[traceKey] = traceValue
      end
    else
      context[key] = value
    end
  end

  context.metaProjection = context.metaProjection or { modifiers = {} }
  context.batchFlags = context.batchFlags or {}
  context.shopFlags = context.shopFlags or {}
  context.shopOffers = context.shopOffers or {}
  context.shopMessages = context.shopMessages or {}
  context.activeSources = context.activeSources or {}
  context.pendingActions = context.pendingActions or {}
  ensureTrace(context)

  return context
end

function ActionQueue.isAcquisitionSafeAction(action)
  return action and ActionQueue.ACQUISITION_SAFE_OPS[action.op] == true
end

local function cloneOnAcquireActions(actionList)
  local cloned = {}

  for _, action in ipairs(actionList or {}) do
    local nextAction = Utils.clone(action)

    if nextAction.op == "add_shop_points" and nextAction.applyMultiplier == nil then
      nextAction.applyMultiplier = false
    end

    table.insert(cloned, nextAction)
  end

  return cloned
end

local function cloneQueuedActions(actionList)
  local cloned = {}

  for _, queuedAction in ipairs(actionList or {}) do
    table.insert(cloned, Utils.clone(queuedAction))
  end

  return cloned
end

local function getCoinWeightTargets(context, action)
  if action.target == "first_weighted_or_leftmost" then
    local fallback = nil

    for _, coinState in ipairs(context.perCoin or {}) do
      fallback = fallback or coinState
      local definition = Coins.getById(coinState.coinId)

      if definition and definition.archetype == "weighted" then
        return { coinState }
      end

      for _, tag in ipairs(definition and definition.tags or {}) do
        if tag == "loaded" or tag == "reliable" then
          return { coinState }
        end
      end
    end

    return fallback and { fallback } or {}
  end

  if action.target == "left_neighbor"
    or action.target == "right_neighbor"
    or action.target == "neighbors"
    or action.target == "self_and_left_neighbor"
    or action.target == "self_and_right_neighbor"
    or action.target == "self_and_neighbors" then
    local targets = {}
    local sourceIndex = action.resolutionIndex or action.slotIndex or (context.currentCoin and (context.currentCoin.resolutionIndex or context.currentCoin.slotIndex))

    if not sourceIndex then
      return targets
    end

    for _, coinState in ipairs(context.perCoin or {}) do
      local coinIndex = coinState.resolutionIndex or coinState.slotIndex
      local targetsSelf = action.target == "self_and_left_neighbor" or action.target == "self_and_right_neighbor" or action.target == "self_and_neighbors"
      local targetsLeft = action.target == "left_neighbor" or action.target == "neighbors" or action.target == "self_and_left_neighbor" or action.target == "self_and_neighbors"
      local targetsRight = action.target == "right_neighbor" or action.target == "neighbors" or action.target == "self_and_right_neighbor" or action.target == "self_and_neighbors"
      local isSelf = targetsSelf and coinIndex == sourceIndex
      local isLeftNeighbor = targetsLeft and coinIndex == sourceIndex - 1
      local isRightNeighbor = targetsRight and coinIndex == sourceIndex + 1

      if isSelf or isLeftNeighbor or isRightNeighbor then
        table.insert(targets, coinState)
      end
    end

    return targets
  end

  if context.currentCoin then
    return { context.currentCoin }
  end

  if action.instanceId ~= nil or action.resolutionIndex ~= nil or action.slotIndex ~= nil then
    local targets = {}

    for _, coinState in ipairs(context.perCoin or {}) do
      local matchesInstance = action.instanceId == nil or coinState.instanceId == action.instanceId
      local matchesResolution = action.resolutionIndex == nil or coinState.resolutionIndex == action.resolutionIndex
      local matchesSlot = action.slotIndex == nil or coinState.slotIndex == action.slotIndex

      if matchesInstance and matchesResolution and matchesSlot then
        table.insert(targets, coinState)
      end
    end

    if #targets > 0 then
      return targets
    end
  end

  if action.coinId then
    local targets = {}

    for _, coinState in ipairs(context.perCoin or {}) do
      if coinState.coinId == action.coinId then
        table.insert(targets, coinState)
      end
    end

    return targets
  end

  return context.perCoin or {}
end

local function clampChance(value)
  return math.max(0, math.min(1, value or 0))
end

local function applyCoinChanceDelta(coinState, side, amount)
  local sideField = side .. "Weight"
  local otherField = side == "heads" and "tailsWeight" or "headsWeight"
  local sideChance = clampChance((coinState[sideField] or 0) + amount)

  coinState[sideField] = sideChance
  coinState[otherField] = 1 - sideChance
end

local function setCoinCallMatchChance(coinState, call, chance)
  local matchChance = clampChance(chance)

  if call == "heads" then
    coinState.headsWeight = matchChance
    coinState.tailsWeight = 1 - matchChance
  elseif call == "tails" then
    coinState.tailsWeight = matchChance
    coinState.headsWeight = 1 - matchChance
  end
end

local function isCoinWeightTarget(target)
  return target == "left_neighbor"
    or target == "right_neighbor"
    or target == "neighbors"
    or target == "self_and_left_neighbor"
    or target == "self_and_right_neighbor"
    or target == "self_and_neighbors"
    or target == "first_weighted_or_leftmost"
end

local function resolveWeightSide(context, action)
  if action.side == nil or action.side == "call" then
    return context.call
  end

  return action.side
end

local function isCoinResult(value)
  return value == "heads" or value == "tails"
end

local function findDealtSlot(stageState, instanceId)
  for _, slot in ipairs(stageState and stageState.purse and stageState.purse.dealtHandSlots or {}) do
    if slot and slot.instanceId == instanceId then
      return slot
    end
  end

  return nil
end

local function getForetellCandidates(stageState)
  local candidates = {}

  for _, slot in ipairs(stageState and stageState.purse and stageState.purse.dealtHandSlots or {}) do
    if slot and slot.instanceId and slot.foretold ~= true then
      table.insert(candidates, slot)
    end
  end

  return candidates
end

local function chooseForetellTarget(stageState, context, action)
  if action.target == "current_dealt_coin" then
    return context.currentCoin and findDealtSlot(stageState, context.currentCoin.instanceId) or nil
  end

  local candidates = getForetellCandidates(stageState)

  if #candidates == 0 then
    return nil
  end

  if action.target == "random_dealt_coin" then
    if not context.rng or type(context.rng.choose) ~= "function" then
      return nil, "foretell_coin_result requires rng for random target"
    end

    return context.rng:choose(candidates)
  end

  if action.instanceId then
    local slot = findDealtSlot(stageState, action.instanceId)

    if slot and slot.foretold ~= true then
      return slot
    end
  end

  return context.currentCoin and findDealtSlot(stageState, context.currentCoin.instanceId) or candidates[1]
end

local function applyForetellCoinResult(runState, stageState, context, action)
  requireStageState(stageState, action.op)

  local targetSlot, targetError = chooseForetellTarget(stageState, context, action)

  if not targetSlot then
    recordWarning(context, targetError or "foretell_coin_result had no eligible dealt coin.")
    return
  end

  if not context.rng or type(context.rng.nextFloat) ~= "function" then
    recordWarning(context, "foretell_coin_result requires rng.")
    return
  end

  local headsChance = clampChance(action.headsChance or 0.5)
  local roll = context.rng:nextFloat()
  local result = roll <= headsChance and "heads" or "tails"
  local sourceId = action._trace and action._trace.sourceId or nil

  targetSlot.foretold = true
  targetSlot.foretoldResult = result
  targetSlot.foretoldBy = sourceId
  targetSlot.foretoldRngRoll = roll

  action.instanceId = targetSlot.instanceId
  action.coinId = targetSlot.definitionId or PurseSystem.getDefinitionId(runState, targetSlot.instanceId)
  action.dealtIndex = targetSlot.dealtIndex or targetSlot.originalDrawIndex
  action.selectedSlotIndex = targetSlot.selectedSlotIndex
  action.slotIndex = targetSlot.selectedSlotIndex
  action.resolutionIndex = targetSlot.selectedSlotIndex
  action.foretoldResult = result
  action.foretoldRngRoll = roll

  context.trace.foretoldResults = context.trace.foretoldResults or {}
  table.insert(context.trace.foretoldResults, {
    coinId = action.coinId,
    instanceId = action.instanceId,
    dealtIndex = action.dealtIndex,
    selectedSlotIndex = action.selectedSlotIndex,
    result = result,
    rngRoll = roll,
    sourceId = sourceId,
  })
end

local function getCoinBaseScore(coinId)
  local definition = Coins.getById(coinId)

  return definition and tonumber(definition.base_score) or 1
end

local function findByResolutionIndex(entries, resolutionIndex)
  for _, entry in ipairs(entries or {}) do
    if entry.resolutionIndex == resolutionIndex then
      return entry
    end
  end

  return nil
end

local function findSlotOneSource(context)
  if context.currentCoin and context.currentCoin.selectedSlotIndex == 1 then
    return context.currentCoin
  end

  for _, coinState in ipairs(context.perCoin or {}) do
    if coinState.selectedSlotIndex == 1 then
      return coinState
    end
  end

  return context.currentCoin
end

local function chooseBorrowedNameTarget(context, source)
  local target = nil
  local targetScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local isSource = source and coinState.instanceId == source.instanceId
    local isSelected = coinState.selectedSlotIndex ~= nil
    local isFailure = coinState.result ~= context.call

    if isSelected and isFailure and not isSource then
      local baseScore = getCoinBaseScore(coinState.coinId)

      if target == nil or baseScore < targetScore then
        target = coinState
        targetScore = baseScore
      end
    end
  end

  return target
end

local function applyForgeIdentity(context, action)
  local source = findSlotOneSource(context)

  if not source then
    recordWarning(context, "forge_identity ignored without a slot 1 source coin.")
    return
  end

  local target = chooseBorrowedNameTarget(context, source)

  if not target then
    recordWarning(context, "forge_identity had no eligible failed selected coin.")
    return
  end

  local sourceId = action._trace and action._trace.sourceId or nil
  local originalCoinId = target.coinId
  local overlay = {
    mode = "replace_identity",
    scope = "one_payout_only",
    sourceId = sourceId,
    sourceCoinId = source.coinId,
    sourceInstanceId = source.instanceId,
    sourceSlotIndex = source.slotIndex,
    sourceResolutionIndex = source.resolutionIndex,
    targetCoinId = originalCoinId,
    targetInstanceId = target.instanceId,
    targetSlotIndex = target.slotIndex,
    targetResolutionIndex = target.resolutionIndex,
    forgedCoinId = source.coinId,
  }

  target.forged = true
  target.forgedBy = sourceId
  target.forgedIdentity = Utils.clone(overlay)
  target.forgedCoinId = source.coinId
  target.identitySourceCoinId = source.coinId
  target.identitySourceInstanceId = source.instanceId
  target.scoringCoinId = source.coinId

  local targetRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, target.resolutionIndex)
  if targetRoll then
    targetRoll.forged = true
    targetRoll.forgedBy = sourceId
    targetRoll.forgedCoinId = source.coinId
    targetRoll.identitySourceCoinId = source.coinId
    targetRoll.identitySourceInstanceId = source.instanceId
  end

  action.coinId = target.coinId
  action.instanceId = target.instanceId
  action.slotIndex = target.slotIndex
  action.selectedSlotIndex = target.selectedSlotIndex
  action.dealtIndex = target.dealtIndex
  action.boardSlotIndex = target.boardSlotIndex
  action.overloadSlotIndex = target.overloadSlotIndex
  action.resolutionIndex = target.resolutionIndex
  action.targetCoinId = target.coinId
  action.targetInstanceId = target.instanceId
  action.targetSlotIndex = target.slotIndex
  action.targetResolutionIndex = target.resolutionIndex
  action.sourceCoinId = source.coinId
  action.sourceInstanceId = source.instanceId
  action.sourceSlotIndex = source.slotIndex
  action.sourceResolutionIndex = source.resolutionIndex
  action.forged = true
  action.forgedBy = sourceId
  action.forgedCoinId = source.coinId
  action.identitySourceCoinId = source.coinId
  action.identitySourceInstanceId = source.instanceId
  action.forgeMode = overlay.mode
  action.forgeScope = overlay.scope

  context.trace.forgedIdentities = context.trace.forgedIdentities or {}
  table.insert(context.trace.forgedIdentities, overlay)
end

local function chooseCrookedSpotlightPair(context)
  local spotlight = nil
  local spotlightScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local isSelected = coinState.selectedSlotIndex ~= nil
    local didMatch = coinState.result == context.call

    if isSelected and didMatch then
      local baseScore = getCoinBaseScore(coinState.scoringCoinId or coinState.forgedCoinId or coinState.coinId)

      if spotlight == nil or baseScore > spotlightScore then
        spotlight = coinState
        spotlightScore = baseScore
      end
    end
  end

  if not spotlight then
    return nil, nil
  end

  local source = nil
  local sourceScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local isSelected = coinState.selectedSlotIndex ~= nil
    local didMatch = coinState.result == context.call
    local isSpotlight = coinState.resolutionIndex == spotlight.resolutionIndex

    if isSelected and didMatch and not isSpotlight and coinState.redirectedCredit ~= true then
      local baseScore = getCoinBaseScore(coinState.scoringCoinId or coinState.forgedCoinId or coinState.coinId)

      if source == nil or baseScore < sourceScore then
        source = coinState
        sourceScore = baseScore
      end
    end
  end

  return source, spotlight
end

local function applyScoreCreditRedirectToRoll(roll, source, spotlight, sourceId)
  if not roll then
    return
  end

  if roll.resolutionIndex == spotlight.resolutionIndex then
    roll.spotlight = true
    roll.spotlightBy = sourceId
  end

  if roll.resolutionIndex == source.resolutionIndex then
    roll.redirectedCredit = true
    roll.redirectedCreditBy = sourceId
    roll.redirectedCreditTargetCoinId = spotlight.coinId
    roll.redirectedCreditTargetInstanceId = spotlight.instanceId
    roll.redirectedCreditTargetSlotIndex = spotlight.slotIndex
    roll.redirectedCreditTargetResolutionIndex = spotlight.resolutionIndex
    roll.spotlightCoinId = spotlight.coinId
    roll.spotlightInstanceId = spotlight.instanceId
  end
end

local function applyRedirectScoreCredit(context, action)
  if context.redirectScoreCreditApplied == true then
    recordWarning(context, "redirect_score_credit ignored because a redirect already resolved this flip.")
    return
  end

  local source, spotlight = chooseCrookedSpotlightPair(context)

  if not spotlight or not source then
    recordWarning(context, "redirect_score_credit had no eligible successful source and Spotlight pair.")
    return
  end

  local sourceId = action._trace and action._trace.sourceId or nil

  context.redirectScoreCreditApplied = true

  spotlight.spotlight = true
  spotlight.spotlightBy = sourceId
  spotlight.spotlightRedirectCount = (spotlight.spotlightRedirectCount or 0) + 1

  source.redirectedCredit = true
  source.redirectedCreditBy = sourceId
  source.redirectedCreditTargetCoinId = spotlight.coinId
  source.redirectedCreditTargetInstanceId = spotlight.instanceId
  source.redirectedCreditTargetSlotIndex = spotlight.slotIndex
  source.redirectedCreditTargetSelectedSlotIndex = spotlight.selectedSlotIndex
  source.redirectedCreditTargetDealtIndex = spotlight.dealtIndex
  source.redirectedCreditTargetBoardSlotIndex = spotlight.boardSlotIndex
  source.redirectedCreditTargetOverloadSlotIndex = spotlight.overloadSlotIndex
  source.redirectedCreditTargetResolutionIndex = spotlight.resolutionIndex
  source.scoreCreditCoinId = spotlight.coinId
  source.scoreCreditInstanceId = spotlight.instanceId
  source.scoreCreditSlotIndex = spotlight.slotIndex
  source.scoreCreditSelectedSlotIndex = spotlight.selectedSlotIndex
  source.scoreCreditDealtIndex = spotlight.dealtIndex
  source.scoreCreditBoardSlotIndex = spotlight.boardSlotIndex
  source.scoreCreditOverloadSlotIndex = spotlight.overloadSlotIndex
  source.scoreCreditResolutionIndex = spotlight.resolutionIndex

  local sourceRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, source.resolutionIndex)
  local spotlightRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, spotlight.resolutionIndex)
  applyScoreCreditRedirectToRoll(sourceRoll, source, spotlight, sourceId)
  applyScoreCreditRedirectToRoll(spotlightRoll, source, spotlight, sourceId)

  action.coinId = source.coinId
  action.instanceId = source.instanceId
  action.slotIndex = source.slotIndex
  action.selectedSlotIndex = source.selectedSlotIndex
  action.dealtIndex = source.dealtIndex
  action.boardSlotIndex = source.boardSlotIndex
  action.overloadSlotIndex = source.overloadSlotIndex
  action.resolutionIndex = source.resolutionIndex
  action.sourceCoinId = source.coinId
  action.sourceInstanceId = source.instanceId
  action.sourceSlotIndex = source.slotIndex
  action.sourceResolutionIndex = source.resolutionIndex
  action.targetCoinId = spotlight.coinId
  action.targetInstanceId = spotlight.instanceId
  action.targetSlotIndex = spotlight.slotIndex
  action.targetResolutionIndex = spotlight.resolutionIndex
  action.spotlightCoinId = spotlight.coinId
  action.spotlightInstanceId = spotlight.instanceId
  action.spotlightSlotIndex = spotlight.slotIndex
  action.spotlightResolutionIndex = spotlight.resolutionIndex
  action.scoreCreditCoinId = spotlight.coinId
  action.scoreCreditInstanceId = spotlight.instanceId
  action.scoreCreditSlotIndex = spotlight.slotIndex
  action.scoreCreditResolutionIndex = spotlight.resolutionIndex
  action.redirectedCredit = true
  action.redirectedCreditBy = sourceId
  action.redirectMode = "score_credit"
  action.redirectScope = "one_redirect_only"

  local redirect = {
    mode = "score_credit",
    scope = "one_redirect_only",
    sourceId = sourceId,
    sourceCoinId = source.coinId,
    sourceInstanceId = source.instanceId,
    sourceSlotIndex = source.slotIndex,
    sourceResolutionIndex = source.resolutionIndex,
    spotlightCoinId = spotlight.coinId,
    spotlightInstanceId = spotlight.instanceId,
    spotlightSlotIndex = spotlight.slotIndex,
    spotlightResolutionIndex = spotlight.resolutionIndex,
    redirectedCredit = true,
  }

  context.trace.redirectedScoreCredits = context.trace.redirectedScoreCredits or {}
  table.insert(context.trace.redirectedScoreCredits, redirect)

  if context.scoreBreakdown then
    context.scoreBreakdown.redirectedScoreCredits = context.scoreBreakdown.redirectedScoreCredits or {}
    table.insert(context.scoreBreakdown.redirectedScoreCredits, Utils.clone(redirect))
  end
end

local SWAPPED_BODY_FIELDS = {
  "coinId",
  "instanceId",
  "originalDrawIndex",
  "dealtIndex",
  "foretold",
  "foretoldResult",
  "foretoldBy",
  "foretoldRngRoll",
}

local function swapBodyFields(left, right)
  if not left or not right then
    return
  end

  for _, field in ipairs(SWAPPED_BODY_FIELDS) do
    left[field], right[field] = right[field], left[field]
  end
end

local function chooseSwitcherooPair(context)
  local failed = nil
  local failedScore = nil
  local successful = nil
  local successfulScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local baseScore = getCoinBaseScore(coinState.coinId)
    local didMatch = coinState.result == context.call

    if didMatch then
      if successful == nil or baseScore < successfulScore then
        successful = coinState
        successfulScore = baseScore
      end
    else
      if failed == nil or baseScore > failedScore then
        failed = coinState
        failedScore = baseScore
      end
    end
  end

  if not failed or not successful then
    return nil, nil
  end

  return failed, successful
end

local function applySwitcherooSwap(context, action)
  if not context.perCoin or #context.perCoin == 0 then
    recordWarning(context, "swap_coins ignored without resolved coins.")
    return
  end

  local failed, successful = chooseSwitcherooPair(context)

  if not failed or not successful then
    recordWarning(context, "swap_coins had no failed/successful slot pair.")
    return
  end

  local failedBefore = Utils.clone(failed)
  local successfulBefore = Utils.clone(successful)
  local failedEntry = findByResolutionIndex(context.resolutionOrder, failed.resolutionIndex)
  local successfulEntry = findByResolutionIndex(context.resolutionOrder, successful.resolutionIndex)
  local failedRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, failed.resolutionIndex)
  local successfulRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, successful.resolutionIndex)

  swapBodyFields(failed, successful)
  swapBodyFields(failedEntry, successfulEntry)
  swapBodyFields(failedRoll, successfulRoll)

  action.failedSlotIndex = failedBefore.slotIndex
  action.successSlotIndex = successfulBefore.slotIndex
  action.failedResolutionIndex = failedBefore.resolutionIndex
  action.successResolutionIndex = successfulBefore.resolutionIndex
  action.failedInstanceId = failedBefore.instanceId
  action.successInstanceId = successfulBefore.instanceId
  action.failedCoinId = failedBefore.coinId
  action.successCoinId = successfulBefore.coinId

  context.trace.sleightMoves = context.trace.sleightMoves or {}
  table.insert(context.trace.sleightMoves, {
    op = "swap_coins",
    sourceId = action._trace and action._trace.sourceId or nil,
    failedSlotIndex = failedBefore.slotIndex,
    successSlotIndex = successfulBefore.slotIndex,
    failedResolutionIndex = failedBefore.resolutionIndex,
    successResolutionIndex = successfulBefore.resolutionIndex,
    failedResult = failedBefore.result,
    successResult = successfulBefore.result,
    failedInstanceId = failedBefore.instanceId,
    successInstanceId = successfulBefore.instanceId,
    failedCoinId = failedBefore.coinId,
    successCoinId = successfulBefore.coinId,
  })
end

local function applySmuggleCoinFromHand(runState, stageState, context, action)
  requireStageState(stageState, action.op)

  local entry, errorMessage = PurseSystem.smuggleCoinFromHand(runState, stageState, {
    sourceId = action._trace and action._trace.sourceId or nil,
    maxOverloadSlots = action.maxOverloadSlots,
  })

  if not entry then
    recordWarning(context, errorMessage or "smuggle_coin_from_hand had no eligible unselected dealt coin.")
    return
  end

  action.coinId = entry.coinId
  action.instanceId = entry.instanceId
  action.slotIndex = entry.slotIndex
  action.selectedSlotIndex = entry.selectedSlotIndex
  action.dealtIndex = entry.dealtIndex
  action.boardSlotIndex = entry.boardSlotIndex
  action.overloadSlotIndex = entry.overloadSlotIndex
  action.resolutionIndex = entry.boardSlotIndex
  action.smuggled = entry.smuggled == true
  action.smuggledBy = entry.smuggledBy
  action.smuggledCoinId = entry.coinId
  action.smuggledInstanceId = entry.instanceId

  context.trace.smugglingMoves = context.trace.smugglingMoves or {}
  table.insert(context.trace.smugglingMoves, {
    op = "smuggle_coin_from_hand",
    sourceId = action._trace and action._trace.sourceId or nil,
    coinId = entry.coinId,
    instanceId = entry.instanceId,
    dealtIndex = entry.dealtIndex,
    boardSlotIndex = entry.boardSlotIndex,
    overloadSlotIndex = entry.overloadSlotIndex,
    resolutionIndex = entry.boardSlotIndex,
    smuggled = true,
  })
end

local function packetHasBentCoin(packet)
  local definition = Coins.getById(packet and packet.coinId)

  if definition and definition.archetype == "bent" then
    return true
  end

  for _, tag in ipairs(definition and definition.tags or {}) do
    if tag == "bent" or tag == "prestige" then
      return true
    end
  end

  return false
end

local function getPacketScore(packet)
  return tonumber(packet and packet.finalScoreContribution) or tonumber(packet and packet.seed and packet.seed.finalScoreContribution) or 0
end

local function chooseEncorePacket(context)
  local eligible = {}
  local bent = {}

  for _, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
    local isSelected = packet.selectedSlotIndex ~= nil
    local hasOutput = getPacketScore(packet) > 0
    local isReplay = packet.prestigeReplay == true

    if isSelected and hasOutput and not isReplay then
      table.insert(eligible, packet)

      if packetHasBentCoin(packet) then
        table.insert(bent, packet)
      end
    end
  end

  local pool = #bent > 0 and bent or eligible

  if #pool == 0 then
    return nil, nil
  end

  if context.rng and context.rng.choose then
    return context.rng:choose(pool)
  end

  return pool[1], 1
end

local function applyReplayResolutionPacket(runState, stageState, context, action)
  requireStageState(stageState, action.op)
  ensureScoreBreakdown(context)

  if context.prestigeReplayApplied == true then
    recordWarning(context, "replay_resolution_packet ignored because a Prestige replay already resolved this flip.")
    return
  end

  local packet, chosenIndex = chooseEncorePacket(context)

  if not packet then
    recordWarning(context, "replay_resolution_packet had no eligible completed selected packet.")
    return
  end

  local scale = tonumber(action.scale) or 0.2
  local originalScore = getPacketScore(packet)
  local rawReplayedScore = originalScore * scale
  local replayedScore = originalScore > 0 and math.max(1, math.floor(rawReplayedScore + 0.00001)) or 0
  local sourceId = action._trace and action._trace.sourceId or nil

  context.prestigeReplayApplied = true

  action.packetId = packet.packetId
  action.packetCoinId = packet.coinId
  action.packetInstanceId = packet.instanceId
  action.packetSlotIndex = packet.slotIndex
  action.packetSelectedSlotIndex = packet.selectedSlotIndex
  action.packetResolutionIndex = packet.resolutionIndex
  action.packetFinalScoreContribution = originalScore
  action.prestigeReplay = true
  action.prestigeReplayBy = sourceId
  action.prestigeScale = scale
  action.rawReplayedScore = rawReplayedScore
  action.replayedScore = replayedScore
  action.amount = replayedScore
  action.chosenPacketIndex = chosenIndex
  action.replayMode = "packet_replay_only"
  action.replayScope = "no_recursive_prestige"

  local replay = {
    op = "replay_resolution_packet",
    mode = "packet_replay_only",
    scope = "no_recursive_prestige",
    sourceId = sourceId,
    packetId = packet.packetId,
    packetCoinId = packet.coinId,
    packetInstanceId = packet.instanceId,
    packetSlotIndex = packet.slotIndex,
    packetSelectedSlotIndex = packet.selectedSlotIndex,
    packetResolutionIndex = packet.resolutionIndex,
    packetFinalScoreContribution = originalScore,
    scale = scale,
    rawReplayedScore = rawReplayedScore,
    replayedScore = replayedScore,
    prestigeReplay = true,
  }

  context.trace.prestigeReplays = context.trace.prestigeReplays or {}
  table.insert(context.trace.prestigeReplays, replay)
  context.scoreBreakdown.prestigeReplays = context.scoreBreakdown.prestigeReplays or {}
  table.insert(context.scoreBreakdown.prestigeReplays, Utils.clone(replay))

  if replayedScore > 0 then
    stageState.stageScore = stageState.stageScore + replayedScore
    runState.runTotalScore = runState.runTotalScore + replayedScore
    context.scoreBreakdown.totalStageScoreDelta = context.scoreBreakdown.totalStageScoreDelta + replayedScore
    context.scoreBreakdown.totalRunScoreDelta = context.scoreBreakdown.totalRunScoreDelta + replayedScore
    addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, {
      scoreTarget = "stage",
      prestigeReplay = true,
      packetId = packet.packetId,
    })
  end
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

local function chooseChainNeighbor(context, source, usedResolutionIndices)
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

  if #candidates == 1 or not (context.rng and context.rng.choose) then
    return candidates[1], 1
  end

  return context.rng:choose(candidates)
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

local function applyTriggerRandomNeighbor(context, action)
  ensureScoreBreakdown(context)

  if context.chainPropagationApplied == true then
    recordWarning(context, "trigger_random_neighbor ignored because a Chain already propagated this flip.")
    return
  end

  local source = context.currentCoin

  if not source then
    recordWarning(context, "trigger_random_neighbor ignored without a source coin.")
    return
  end

  local chance = tonumber(action.chainChance) or 0.5
  local maxDepth = tonumber(action.maxChainDepth) or 2
  local maxTriggers = tonumber(action.maxTriggers) or maxDepth
  local sourceId = action._trace and action._trace.sourceId or nil
  local usedResolutionIndices = {}
  local currentSource = source
  local links = {}

  context.chainPropagationApplied = true
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

    local target, chosenNeighborIndex = chooseChainNeighbor(context, currentSource, usedResolutionIndices)

    if not target then
      recordWarning(context, "trigger_random_neighbor had no eligible unused neighbour.")
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

local function applyPersistentCoinChanceDelta(runState, coinState, side, amount)
  local instance = coinState and coinState.instanceId and PurseSystem.getInstance(runState, coinState.instanceId) or nil

  if not instance then
    return
  end

  instance.state = instance.state or {}
  instance.state.coinWeightBonuses = instance.state.coinWeightBonuses or { heads = 0, tails = 0 }
  instance.state.coinWeightBonuses[side] = (instance.state.coinWeightBonuses[side] or 0) + amount
end

local function validateQueuedActions(actionList)
  if type(actionList) ~= "table" then
    return false, "queue_actions requires actions table"
  end

  for _, queuedAction in ipairs(actionList) do
    local ok, errorMessage = ActionQueue.validateAction(queuedAction)

    if not ok then
      return false, errorMessage
    end
  end

  return true
end

local function collectConditionFlagKeysFromActions(actionList, flagKeys)
  for _, action in ipairs(actionList or {}) do
    if (action.op == "set_batch_flag" or action.op == "set_shop_flag") and type(action.flag) == "string" and action.flag ~= "" then
      flagKeys[action.flag] = true
    elseif action.op == "queue_actions" then
      collectConditionFlagKeysFromActions(action.actions, flagKeys)
    elseif action.op == "grant_temporary_effect" and type(action.effect) == "table" then
      for _, trigger in ipairs(action.effect.triggers or {}) do
        collectConditionFlagKeysFromActions(trigger.effects, flagKeys)
      end
    end
  end
end

local function validateTemporaryEffectDefinition(effect)
  if type(effect) ~= "table" then
    return false, "grant_temporary_effect requires effect table"
  end

  if type(effect.id) ~= "string" or effect.id == "" then
    return false, "temporary effect requires id"
  end

  if type(effect.name) ~= "string" or effect.name == "" then
    return false, "temporary effect requires name"
  end

  if effect.priorityLayer ~= nil and type(effect.priorityLayer) ~= "number" then
    return false, "temporary effect priorityLayer must be numeric"
  end

  if effect.customResolver ~= nil then
    if type(effect.customResolver) ~= "string" or effect.customResolver == "" then
      return false, "temporary effect customResolver must be non-empty string"
    end

    local ok, resolverModule = pcall(require, effect.customResolver)

    if not ok then
      return false, string.format("temporary effect customResolver %s could not be required", effect.customResolver)
    end

    if type(resolverModule) ~= "table" or type(resolverModule.resolve) ~= "function" then
      return false, string.format("temporary effect customResolver %s must export resolve", effect.customResolver)
    end
  end

  local ok, errorMessage = EffectiveValueSystem.validateEffectiveValuesTable(effect.effectiveValues)

  if not ok then
    return false, string.format("temporary effect %s has invalid effectiveValues: %s", effect.id, errorMessage)
  end

  local allowedFlagKeys = HookRegistry.getSystemConditionFlagKeys()
  for _, trigger in ipairs(effect.triggers or {}) do
    collectConditionFlagKeysFromActions(trigger.effects, allowedFlagKeys)
  end

  for _, trigger in ipairs(effect.triggers or {}) do
    if not HookRegistry.isValidPhase(trigger.hook) then
      return false, string.format("temporary effect %s uses invalid hook %s", effect.id, tostring(trigger.hook))
    end

    ok, errorMessage = HookRegistry.validateCondition(trigger.condition, allowedFlagKeys, trigger.hook)

    if not ok then
      return false, string.format("temporary effect %s has invalid condition: %s", effect.id, errorMessage)
    end

    ok, errorMessage = validateQueuedActions(trigger.effects or {})

    if not ok then
      return false, string.format("temporary effect %s has invalid effect: %s", effect.id, errorMessage)
    end

    for _, nestedAction in ipairs(trigger.effects or {}) do
      if nestedAction.op == "queue_actions" then
        local triggerOrder = HookRegistry.getPhaseOrder(trigger.hook)
        local targetOrder = HookRegistry.getPhaseOrder(nestedAction.phase)

        if triggerOrder and targetOrder and targetOrder < triggerOrder then
          return false, string.format(
            "temporary effect %s queues phase %s before enclosing phase %s",
            effect.id,
            tostring(nestedAction.phase),
            tostring(trigger.hook)
          )
        end
      end
    end
  end

  return true
end

local function canApplyAnotherAction(context)
  ensureTrace(context)

  if not context.actionMetrics then
    return true
  end

  if context.actionMetrics.appliedCount >= context.actionMetrics.maxAppliedCount then
    if not context.actionMetrics.limitHit then
      context.actionMetrics.limitHit = true
      recordWarning(context, string.format("Action limit hit at %d applications; skipping remaining actions.", context.actionMetrics.maxAppliedCount))
    end

    return false
  end

  return true
end

local function buildTemporaryEffectInstance(runState, context, effectDefinition, trace)
  runState.counters.temporaryEffectInstances = (runState.counters.temporaryEffectInstances or 0) + 1

  local instance = Utils.clone(effectDefinition)
  local baseId = effectDefinition.id
  local instanceId = string.format("%s__%d", baseId, runState.counters.temporaryEffectInstances)

  instance.id = instanceId
  instance.baseEffectId = baseId
  instance.grantedAtBatchId = context.batchId
  instance.grantedAtPhase = context.currentPhase
  instance.grantedBy = Utils.clone(trace)

  return instance
end

local function grantCoinFromAction(runState, action)
  local definition = Coins.getById(action.coinId)

  if not definition then
    error("unknown_coin")
  end

  PurseSystem.createInstance(runState, action.coinId)

  return definition
end

local function grantUpgradeFromAction(runState, stageState, context, action)
  local definition = Upgrades.getById(action.upgradeId)

  if not definition then
    error("unknown_upgrade")
  end

  if not Utils.contains(runState.ownedUpgradeIds, action.upgradeId) then
    table.insert(runState.ownedUpgradeIds, action.upgradeId)
    ActionQueue.applyAll(runState, stageState, context, cloneOnAcquireActions(definition.onAcquire))
  end

  return definition
end

function ActionQueue.validateAction(action)
  if type(action) ~= "table" then
    return false, "action must be a table"
  end

  if not ActionQueue.KNOWN_OPS[action.op] then
    return false, string.format("unknown op: %s", tostring(action.op))
  end

  if action.op == "add_stage_score" or action.op == "add_run_score" or action.op == "add_shop_points" or action.op == "add_luck" then
    if type(action.amount) ~= "number" then
      return false, string.format("%s requires numeric amount", action.op)
    end
  end

  if action.op == "add_stage_score" or action.op == "add_run_score" or action.op == "add_shop_points" then
    if action.applyMultiplier ~= nil and type(action.applyMultiplier) ~= "boolean" then
      return false, string.format("%s applyMultiplier must be boolean", action.op)
    end
  end

  if action.op == "modify_coin_weight" then
    if (action.side ~= "heads") and (action.side ~= "tails") then
      return false, "modify_coin_weight requires side=heads|tails"
    end

    if type(action.amount) ~= "number" then
      return false, "modify_coin_weight requires numeric amount"
    end

    if action.persistent ~= nil and type(action.persistent) ~= "boolean" then
      return false, "modify_coin_weight persistent must be boolean"
    end

    if action.target ~= nil
      and action.target ~= "left_neighbor"
      and action.target ~= "right_neighbor"
      and action.target ~= "neighbors"
      and action.target ~= "self_and_left_neighbor"
      and action.target ~= "self_and_right_neighbor"
      and action.target ~= "self_and_neighbors" then
      return false, "modify_coin_weight target must be left_neighbor|right_neighbor|neighbors|self_and_left_neighbor|self_and_right_neighbor|self_and_neighbors"
    end
  end

  if action.op == "add_weight" then
    if action.side ~= nil and action.side ~= "heads" and action.side ~= "tails" and action.side ~= "call" then
      return false, "add_weight side must be heads|tails|call when present"
    end

    if type(action.amount) ~= "number" then
      return false, "add_weight requires numeric amount"
    end

    if action.target ~= nil and not isCoinWeightTarget(action.target) then
      return false, "add_weight target must be left_neighbor|right_neighbor|neighbors|self_and_left_neighbor|self_and_right_neighbor|self_and_neighbors|first_weighted_or_leftmost"
    end
  end

  if action.op == "set_call_match_chance" then
    if type(action.chance) ~= "number" then
      return false, "set_call_match_chance requires numeric chance"
    end

    if action.chance < 0 or action.chance > 1 then
      return false, "set_call_match_chance chance must be between 0 and 1"
    end

    if action.target ~= nil and not isCoinWeightTarget(action.target) then
      return false, "set_call_match_chance target must be left_neighbor|right_neighbor|neighbors|self_and_left_neighbor|self_and_right_neighbor|self_and_neighbors|first_weighted_or_leftmost"
    end
  end

  if action.op == "foretell_coin_result" then
    if action.target ~= nil and action.target ~= "random_dealt_coin" and action.target ~= "current_dealt_coin" then
      return false, "foretell_coin_result target must be random_dealt_coin|current_dealt_coin when present"
    end

    if action.headsChance ~= nil and (type(action.headsChance) ~= "number" or action.headsChance < 0 or action.headsChance > 1) then
      return false, "foretell_coin_result headsChance must be between 0 and 1 when present"
    end

    if action.foretoldResult ~= nil and not isCoinResult(action.foretoldResult) then
      return false, "foretell_coin_result foretoldResult must be heads|tails when present"
    end
  end

  if action.op == "forge_identity" then
    if action.target ~= nil and action.target ~= "slot_1_to_lowest_failed_selected_coin" then
      return false, "forge_identity target must be slot_1_to_lowest_failed_selected_coin when present"
    end
  end

  if action.op == "redirect_score_credit" then
    if action.target ~= nil and action.target ~= "crooked_spotlight_lowest_success_to_highest_success" then
      return false, "redirect_score_credit target must be crooked_spotlight_lowest_success_to_highest_success when present"
    end
  end

  if action.op == "swap_coins" then
    if action.target ~= nil and action.target ~= "switcheroo_failed_success" then
      return false, "swap_coins target must be switcheroo_failed_success when present"
    end
  end

  if action.op == "smuggle_coin_from_hand" then
    if action.target ~= nil and action.target ~= "hollow_or_leftmost_unselected_hand_coin" then
      return false, "smuggle_coin_from_hand target must be hollow_or_leftmost_unselected_hand_coin when present"
    end

    if action.maxOverloadSlots ~= nil and (type(action.maxOverloadSlots) ~= "number" or math.floor(action.maxOverloadSlots) ~= action.maxOverloadSlots or action.maxOverloadSlots < 1) then
      return false, "smuggle_coin_from_hand maxOverloadSlots must be a positive integer when present"
    end
  end

  if action.op == "replay_resolution_packet" then
    if action.target ~= nil and action.target ~= "encore_bent_or_random_selected_packet" then
      return false, "replay_resolution_packet target must be encore_bent_or_random_selected_packet when present"
    end

    if action.scale ~= nil and (type(action.scale) ~= "number" or action.scale < 0 or action.scale > 1) then
      return false, "replay_resolution_packet scale must be between 0 and 1 when present"
    end
  end

  if action.op == "trigger_random_neighbor" then
    if action.target ~= nil and action.target ~= "random_neighbor" then
      return false, "trigger_random_neighbor target must be random_neighbor when present"
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
  end

  if action.op == "apply_score_multiplier" then
    if type(action.value) ~= "number" then
      return false, "apply_score_multiplier requires numeric value"
    end

    if action.target ~= nil and action.target ~= "current_coin_score" then
      return false, "apply_score_multiplier target must be current_coin_score when present"
    end
  end

  if (action.op == "set_batch_flag" or action.op == "set_shop_flag" or action.op == "set_stage_flag" or action.op == "set_run_flag")
    and (type(action.flag) ~= "string" or action.flag == "") then
    return false, string.format("%s requires flag", action.op)
  end

  if (action.op == "set_batch_flag" or action.op == "set_shop_flag" or action.op == "set_stage_flag" or action.op == "set_run_flag")
    and action.value ~= nil and type(action.value) ~= "boolean" then
    return false, string.format("%s value must be boolean when present", action.op)
  end

  if action.op == "queue_trace_note" and action.note ~= nil and type(action.note) ~= "string" then
    return false, "queue_trace_note note must be a string"
  end

  if action.op == "grant_upgrade" and (type(action.upgradeId) ~= "string" or action.upgradeId == "") then
    return false, "grant_upgrade requires upgradeId"
  end

  if action.op == "grant_upgrade" and not Upgrades.getById(action.upgradeId) then
    return false, string.format("grant_upgrade references unknown upgrade %s", tostring(action.upgradeId))
  end

  if action.op == "grant_coin" and (type(action.coinId) ~= "string" or action.coinId == "") then
    return false, "grant_coin requires coinId"
  end

  if action.op == "grant_coin" and not Coins.getById(action.coinId) then
    return false, string.format("grant_coin references unknown coin %s", tostring(action.coinId))
  end

  if action.op == "grant_temporary_effect" then
    local ok, errorMessage = validateTemporaryEffectDefinition(action.effect)

    if not ok then
      return false, errorMessage
    end
  end

  if action.op == "queue_actions" then
    if type(action.phase) ~= "string" or action.phase == "" then
      return false, "queue_actions requires phase"
    end

    if not HookRegistry.isValidPhase(action.phase) then
      return false, string.format("queue_actions uses invalid phase %s", tostring(action.phase))
    end

    local ok, errorMessage = validateQueuedActions(action.actions)

    if not ok then
      return false, errorMessage
    end
  end

  if action.op == "add_shop_offer" then
    if action.offerType ~= "coin" and action.offerType ~= "upgrade" then
      return false, "add_shop_offer requires offerType=coin|upgrade"
    end

    if type(action.contentId) ~= "string" or action.contentId == "" then
      return false, "add_shop_offer requires contentId"
    end

    if action.price ~= nil and type(action.price) ~= "number" then
      return false, "add_shop_offer price must be numeric"
    end

    if action.price ~= nil and action.price < 0 then
      return false, "add_shop_offer price must be non-negative"
    end

    local definition = action.offerType == "coin" and Coins.getById(action.contentId) or Upgrades.getById(action.contentId)

    if not definition then
      return false, string.format("add_shop_offer references unknown %s %s", action.offerType, tostring(action.contentId))
    end
  end

  if action.op == "adjust_shop_price" then
    if type(action.delta) ~= "number" then
      return false, "adjust_shop_price requires numeric delta"
    end

    if action.offerType ~= nil and action.offerType ~= "coin" and action.offerType ~= "upgrade" then
      return false, "adjust_shop_price offerType must be coin|upgrade"
    end

    if action.contentId ~= nil and (type(action.contentId) ~= "string" or action.contentId == "") then
      return false, "adjust_shop_price contentId must be non-empty string"
    end

    if action.rarity ~= nil and (type(action.rarity) ~= "string" or action.rarity == "") then
      return false, "adjust_shop_price rarity must be non-empty string"
    end
  end

  if action.op == "block_purchase" and action.reason ~= nil and type(action.reason) ~= "string" then
    return false, "block_purchase reason must be a string"
  end

  if action.op == "add_shop_message" and type(action.message) ~= "string" then
    return false, "add_shop_message requires a message"
  end

   if action.op == "record_purchase" then
    if action.purchaseType ~= "coin" and action.purchaseType ~= "upgrade" then
      return false, "record_purchase requires purchaseType=coin|upgrade"
    end

    if type(action.contentId) ~= "string" or action.contentId == "" then
      return false, "record_purchase requires contentId"
    end

      if type(action.price) ~= "number" then
      return false, "record_purchase requires numeric price"
    end

    if action.price < 0 then
      return false, "record_purchase price must be non-negative"
    end

    if action.purchaseType == "coin" and not Coins.getById(action.contentId) then
      return false, string.format("record_purchase references unknown coin %s", tostring(action.contentId))
    end

    if action.purchaseType == "upgrade" and not Upgrades.getById(action.contentId) then
      return false, string.format("record_purchase references unknown upgrade %s", tostring(action.contentId))
    end
  end

  if action.op == "increase_coin_slots" and not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
    return false, "increase_coin_slots requires integer amount"
  end

  if action.op == "add_shop_rerolls" and not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
    return false, "add_shop_rerolls requires integer amount"
  end

  if action.op == "set_flips_remaining" and not (type(action.value) == "number" and math.floor(action.value) == action.value) then
    return false, "set_flips_remaining requires integer value"
  end

  if action.op == "set_flips_remaining" and action.value < 0 then
    return false, "set_flips_remaining requires non-negative value"
  end

  if action.op == "consume_effect" and action.effectId ~= nil and (type(action.effectId) ~= "string" or action.effectId == "") then
    return false, "consume_effect requires effectId"
  end

  return true
end

function ActionQueue.apply(runState, stageState, context, action)
  ensureTrace(context)

  if action.op == "add_stage_score" then
    ensureScoreBreakdown(context)
    requireStageState(stageState, action.op)
    stageState.stageScore = stageState.stageScore + action.amount
    runState.runTotalScore = runState.runTotalScore + action.amount
    context.scoreBreakdown.totalStageScoreDelta = context.scoreBreakdown.totalStageScoreDelta + action.amount
    context.scoreBreakdown.totalRunScoreDelta = context.scoreBreakdown.totalRunScoreDelta + action.amount

    if action.category ~= "base_score" then
      addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, {
        scoreTarget = "stage",
      })
    end
  elseif action.op == "add_run_score" then
    ensureScoreBreakdown(context)
    runState.runTotalScore = runState.runTotalScore + action.amount
    context.scoreBreakdown.totalRunScoreDelta = context.scoreBreakdown.totalRunScoreDelta + action.amount

    if action.category ~= "base_score" then
      addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, {
        scoreTarget = "run",
      })
    end
  elseif action.op == "add_shop_points" then
    ensureScoreBreakdown(context)
    local multiplier = 1.0

    if action.applyMultiplier ~= false then
      multiplier = EffectiveValueSystem.getEffectiveValue("economy.shopPointMultiplier", runState, stageState, {
        metaProjection = context.metaProjection,
        activeSources = context.activeSources,
      })
    end

    local scaledAmount = action.amount

    if multiplier ~= 1.0 and action.amount ~= 0 then
      local scaledRawAmount = action.amount * multiplier

      if scaledRawAmount >= 0 then
        scaledAmount = math.max(1, math.floor(scaledRawAmount + 0.00001))
      else
        scaledAmount = math.min(-1, math.ceil(scaledRawAmount - 0.00001))
      end
    end

    runState.shopPoints = runState.shopPoints + scaledAmount
    context.scoreBreakdown.totalShopPointDelta = context.scoreBreakdown.totalShopPointDelta + scaledAmount

    local appliedAction = Utils.clone(action)
    appliedAction.appliedAmount = scaledAmount
    table.insert(context.scoreBreakdown.shopPointChanges, appliedAction)
  elseif action.op == "add_luck" then
    local LuckSystem = require("src.systems.luck_system")
    LuckSystem.addLuck(runState, context, action.amount, {
      source = "action",
      reason = action.reason,
      action = action,
      ignoreFatedSuppression = action.ignoreFatedSuppression == true,
    })
  elseif action.op == "add_weight" then
    local side = resolveWeightSide(context, action)

    if side ~= "heads" and side ~= "tails" then
      recordWarning(context, "add_weight ignored without an active call.")
    else
      local targets = getCoinWeightTargets(context, action)

      for _, coinState in ipairs(targets) do
        applyCoinChanceDelta(coinState, side, action.amount)
        coinState.weightChanges = coinState.weightChanges or {}
        table.insert(coinState.weightChanges, cloneActionForTrace(action))
      end
    end
  elseif action.op == "set_call_match_chance" then
    if context.call ~= "heads" and context.call ~= "tails" then
      recordWarning(context, "set_call_match_chance ignored without an active call.")
    else
      local targets = getCoinWeightTargets(context, action)

      for _, coinState in ipairs(targets) do
        setCoinCallMatchChance(coinState, context.call, action.chance)
        coinState.weightChanges = coinState.weightChanges or {}
        table.insert(coinState.weightChanges, cloneActionForTrace(action))
      end
    end
  elseif action.op == "foretell_coin_result" then
    applyForetellCoinResult(runState, stageState, context, action)
  elseif action.op == "forge_identity" then
    applyForgeIdentity(context, action)
  elseif action.op == "redirect_score_credit" then
    applyRedirectScoreCredit(context, action)
  elseif action.op == "swap_coins" then
    applySwitcherooSwap(context, action)
  elseif action.op == "smuggle_coin_from_hand" then
    applySmuggleCoinFromHand(runState, stageState, context, action)
  elseif action.op == "replay_resolution_packet" then
    applyReplayResolutionPacket(runState, stageState, context, action)
  elseif action.op == "trigger_random_neighbor" then
    applyTriggerRandomNeighbor(context, action)
  elseif action.op == "modify_coin_weight" then
    local targets = getCoinWeightTargets(context, action)

    for _, coinState in ipairs(targets) do
      if action.persistent == true then
        applyPersistentCoinChanceDelta(runState, coinState, action.side, action.amount)
      else
        applyCoinChanceDelta(coinState, action.side, action.amount)
      end

      coinState.weightChanges = coinState.weightChanges or {}
      table.insert(coinState.weightChanges, cloneActionForTrace(action))
    end
  elseif action.op == "apply_score_multiplier" then
    ensureScoreBreakdown(context)
    if action.target == "current_coin_score" then
      if context.currentScoreEvent then
        context.currentScoreEvent.multiplier = (context.currentScoreEvent.multiplier or 1.0) * action.value
        addScoreBreakdownEntry(context.scoreBreakdown.multipliers, action, {
          scope = "current_coin_score",
          scoreEventId = context.currentScoreEvent.eventId,
          coinId = context.currentScoreEvent.coinId,
          instanceId = context.currentScoreEvent.instanceId,
          slotIndex = context.currentScoreEvent.slotIndex,
          resolutionIndex = context.currentScoreEvent.resolutionIndex,
        })
      else
        recordWarning(context, "current_coin_score score scaling ignored outside coin scoring.")
      end
    else
      context.pendingScoreMultiplier = (context.pendingScoreMultiplier or 1.0) * action.value
      table.insert(context.scoreBreakdown.multipliers, cloneActionForTrace(action))
    end
  elseif action.op == "set_batch_flag" then
    context.batchFlags[action.flag] = action.value ~= false
  elseif action.op == "set_shop_flag" then
    context.shopFlags = context.shopFlags or {}
    context.shopFlags[action.flag] = action.value ~= false
  elseif action.op == "set_stage_flag" then
    requireStageState(stageState, action.op)
    stageState.flags[action.flag] = action.value ~= false
  elseif action.op == "set_run_flag" then
    runState.flags[action.flag] = action.value ~= false
  elseif action.op == "queue_trace_note" then
    ensureScoreBreakdown(context)
    table.insert(context.trace.notes, action.note or "(empty note)")
    table.insert(context.scoreBreakdown.notes, action.note or "(empty note)")
  elseif action.op == "grant_upgrade" then
    grantUpgradeFromAction(runState, stageState, context, action)
  elseif action.op == "grant_coin" then
    grantCoinFromAction(runState, action)
  elseif action.op == "increase_coin_slots" then
    runState.maxActiveCoinSlots = math.max(1, runState.maxActiveCoinSlots + action.amount)
    runState.equippedCoinSlots = Loadout.normalizeSlots(runState.equippedCoinSlots, runState.maxActiveCoinSlots)
    runState.persistedLoadoutSlots = Loadout.normalizeSlots(runState.persistedLoadoutSlots, runState.maxActiveCoinSlots)
  elseif action.op == "add_shop_rerolls" then
    runState.shopRerollsRemaining = math.max(0, (runState.shopRerollsRemaining or 0) + action.amount)
  elseif action.op == "set_flips_remaining" then
    requireStageState(stageState, action.op)
    stageState.flipsRemaining = math.max(0, action.value)
  elseif action.op == "consume_effect" then
    if not action.effectId then
      error("consume_effect requires effectId")
    end

    for index, effect in ipairs(runState.temporaryRunEffects) do
      if effect.id == action.effectId then
        table.remove(runState.temporaryRunEffects, index)
        break
      end
    end

    if context.activeSources then
      HookRegistry.removeSourceById(context.activeSources, action.effectId)
    end

    table.insert(context.trace.temporaryEffectsConsumed, action.effectId)
  elseif action.op == "grant_temporary_effect" then
    local instance = buildTemporaryEffectInstance(runState, context, action.effect, action._trace)
    runState.temporaryRunEffects = runState.temporaryRunEffects or {}
    table.insert(runState.temporaryRunEffects, instance)

    -- Outside batch resolution, temporary effects are still stored for later batches,
    -- but only batch resolution currently reuses the evolving active source list mid-transaction.
    if context.activeSources then
      HookRegistry.insertSource(context.activeSources, HookRegistry.buildSource("temporary effect", instance.id, instance))
    end

    table.insert(context.trace.temporaryEffectsGranted, {
      id = instance.id,
      baseEffectId = instance.baseEffectId,
      name = instance.name,
      phase = context.currentPhase,
    })
  elseif action.op == "queue_actions" then
    ensurePendingActionContext(context)
    local canQueue = true

    if context.trace and context.trace.mode ~= "batch" then
      recordWarning(context, string.format("queue_actions ignored in non-batch context (%s).", tostring(context.trace.mode)))
      canQueue = false
    end

    local nextDepth = (context.currentChainDepth or 0) + 1
    local maxDepth = context.actionMetrics and context.actionMetrics.maxPendingActionDepth or GameConfig.get("engine.maxPendingActionDepth")
    local currentPhaseOrder = HookRegistry.getPhaseOrder(context.currentPhase)
    local targetPhaseOrder = HookRegistry.getPhaseOrder(action.phase)

    if canQueue and currentPhaseOrder and targetPhaseOrder and targetPhaseOrder < currentPhaseOrder then
      recordWarning(context, string.format("Queued action for already-passed phase %s was dropped.", action.phase))
      canQueue = false
    elseif canQueue and nextDepth > maxDepth then
      recordWarning(context, string.format("Queued action chain dropped at depth %d for phase %s.", nextDepth, action.phase))
      canQueue = false
    end

    if canQueue then
      context.pendingActions[action.phase] = context.pendingActions[action.phase] or {}
      table.insert(context.pendingActions[action.phase], {
        phase = action.phase,
        chainDepth = nextDepth,
        actions = cloneQueuedActions(action.actions),
        queuedBy = Utils.clone(action._trace),
      })

      table.insert(context.trace.queuedActions, {
        phase = action.phase,
        chainDepth = nextDepth,
        actionCount = #(action.actions or {}),
      })
    end
  elseif action.op == "add_shop_offer" then
    ensureShopContext(context)

    local definition = action.offerType == "coin" and Coins.getById(action.contentId) or Upgrades.getById(action.contentId)

    if definition then
      local ownedList = action.offerType == "coin" and runState.collectionCoinIds or runState.ownedUpgradeIds
      local alreadyOffered = false

      for _, offer in ipairs(context.shopOffers) do
        if offer.contentId == action.contentId then
          alreadyOffered = true
          break
        end
      end

      if not Utils.contains(ownedList, action.contentId) and not alreadyOffered then
        table.insert(context.shopOffers, {
          type = action.offerType,
          contentId = action.contentId,
          name = definition.name,
          rarity = definition.rarity,
          price = action.price or ShopContent.resolvePrice(action.offerType, definition),
          purchased = false,
          injectedBy = Utils.clone(action._trace),
          tags = Utils.copyArray(definition.tags or {}),
        })
      end
    end
  elseif action.op == "adjust_shop_price" then
    ensureShopContext(context)

    local targets = {}

    if context.currentOffer then
      targets = { context.currentOffer }
    else
      targets = context.shopOffers
    end

    for _, offer in ipairs(targets) do
      local matchesType = action.offerType == nil or offer.type == action.offerType
      local matchesContent = action.contentId == nil or offer.contentId == action.contentId
      local matchesRarity = action.rarity == nil or offer.rarity == action.rarity

      if matchesType and matchesContent and matchesRarity then
        offer.price = math.max(0, (offer.price or 0) + action.delta)
        offer.priceAdjustments = offer.priceAdjustments or {}
        table.insert(offer.priceAdjustments, cloneActionForTrace(action))
      end
    end
  elseif action.op == "block_purchase" then
    context.purchaseBlocked = true
    context.purchaseBlockReason = action.reason or "purchase_blocked"
  elseif action.op == "add_shop_message" then
    ensureShopContext(context)
    table.insert(context.shopMessages, action.message)
  elseif action.op == "mark_shop_offer_purchased" then
    if context.currentOffer then
      context.currentOffer.purchased = true
    end
  elseif action.op == "record_purchase" then
    table.insert(runState.history.purchases, {
      type = action.purchaseType,
      contentId = action.contentId,
      price = action.price,
    })
  end

  table.insert(context.trace.actions, cloneActionForTrace(action))
end

function ActionQueue.applyAll(runState, stageState, context, actionList)
  for _, action in ipairs(actionList or {}) do
    if not canApplyAnotherAction(context) then
      break
    end

    local ok, errorMessage = ActionQueue.validateAction(action)

    if not ok then
      error(errorMessage)
    end

    if context.actionMetrics then
      context.actionMetrics.appliedCount = context.actionMetrics.appliedCount + 1
    end

    ActionQueue.apply(runState, stageState, context, action)
  end
end

return ActionQueue
