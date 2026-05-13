local ActionQueue = require("src.core.action_queue")
local BetSystem = require("src.systems.bet_system")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local FlipBatch = require("src.domain.flip_batch")
local HookRegistry = require("src.core.hook_registry")
local PurseSystem = require("src.systems.purse_system")
local ScoreBreakdown = require("src.domain.score_breakdown")
local ScoringSystem = require("src.systems.scoring_system")
local Validator = require("src.core.validator")
local GameConfig = require("src.app.config")
local RNG = require("src.core.rng")
local Utils = require("src.core.utils")

local FlipResolver = {}

function FlipResolver.buildResolutionContext(runState, stageState, metaProjection, call, rng)
  local context = ActionQueue.createContext("batch", {
    batchId = stageState.batchIndex + 1,
    call = call,
    runState = runState,
    stageState = stageState,
    metaProjection = metaProjection,
    activeSources = {},
    perCoin = {},
    batchFlags = {},
    scoreBreakdown = ScoreBreakdown.new(),
    pendingScoreMultiplier = 1.0,
    actionMetrics = {
      appliedCount = 0,
      maxAppliedCount = GameConfig.get("engine.maxAppliedActionsPerBatch"),
      maxPendingActionDepth = GameConfig.get("engine.maxPendingActionDepth"),
      limitHit = false,
    },
    trace = {
      batchId = stageState.batchIndex + 1,
      call = call,
      coinRolls = {},
      forcedResults = {},
      triggeredSources = {},
      actions = {},
      notes = {},
      warnings = {},
      queuedActions = {},
      temporaryEffectsGranted = {},
      temporaryEffectsConsumed = {},
    },
    rng = rng,
    betResult = nil,
  })

  return context
end

function FlipResolver.prepareCoinRollState(runState, stageState, metaProjection, context)
  local resolutionEntries = PurseSystem.getResolutionOrder(runState, stageState)
  local perCoin = {}
  local headsWeight, tailsWeight = EffectiveValueSystem.getBaseCoinWeights(runState, stageState, {
    metaProjection = metaProjection or runState.metaProjection,
    activeSources = context and context.activeSources or nil,
  })

  for _, resolutionEntry in ipairs(resolutionEntries) do
    table.insert(perCoin, {
      coinId = resolutionEntry.coinId,
      instanceId = resolutionEntry.instanceId,
      slotIndex = resolutionEntry.slotIndex,
      originalDrawIndex = resolutionEntry.originalDrawIndex,
      resolutionIndex = resolutionEntry.resolutionIndex,
      baseHeadsWeight = headsWeight,
      baseTailsWeight = tailsWeight,
      headsWeight = headsWeight,
      tailsWeight = tailsWeight,
      result = nil,
      rngRoll = nil,
      flags = {},
    })
  end

  return perCoin, resolutionEntries
end

function FlipResolver.resolveCoinOutcome(coinRollState, context)
  local totalWeight = math.max(coinRollState.headsWeight + coinRollState.tailsWeight, 0.00001)
  local roll = context.rng:nextFloat()
  local normalizedHeadsWeight = coinRollState.headsWeight / totalWeight
  local forcedResult = nil

  if context.runState and type(context.runState.pendingForcedCoinResults) == "table" and #context.runState.pendingForcedCoinResults > 0 then
    forcedResult = table.remove(context.runState.pendingForcedCoinResults, 1)
  end

  coinRollState.rngRoll = roll
  coinRollState.forcedResult = forcedResult
  coinRollState.result = forcedResult or (roll <= normalizedHeadsWeight and "heads" or "tails")

  table.insert(context.trace.coinRolls, {
    coinId = coinRollState.coinId,
    instanceId = coinRollState.instanceId,
    slotIndex = coinRollState.slotIndex,
    resolutionIndex = coinRollState.resolutionIndex,
    baseHeadsWeight = coinRollState.baseHeadsWeight,
    baseTailsWeight = coinRollState.baseTailsWeight,
    headsWeight = coinRollState.headsWeight,
    tailsWeight = coinRollState.tailsWeight,
    rngRoll = roll,
    result = coinRollState.result,
    forcedResult = forcedResult,
  })

  if forcedResult then
    table.insert(context.trace.forcedResults, {
      result = forcedResult,
      coinId = coinRollState.coinId,
      instanceId = coinRollState.instanceId,
      slotIndex = coinRollState.slotIndex,
      resolutionIndex = coinRollState.resolutionIndex,
      rngRoll = roll,
    })
  end

  return coinRollState.result
end

function FlipResolver.updateCounters(runState, stageState, context)
  runState.counters.totalFlips = runState.counters.totalFlips + 1

  if context.call == "heads" then
    runState.counters.headsCalls = runState.counters.headsCalls + 1
    if stageState.lastCall == "heads" then
      stageState.streak.consecutiveHeadsCalls = stageState.streak.consecutiveHeadsCalls + 1
    else
      stageState.streak.consecutiveHeadsCalls = 1
    end
    stageState.streak.consecutiveTailsCalls = 0
  else
    runState.counters.tailsCalls = runState.counters.tailsCalls + 1
    if stageState.lastCall == "tails" then
      stageState.streak.consecutiveTailsCalls = stageState.streak.consecutiveTailsCalls + 1
    else
      stageState.streak.consecutiveTailsCalls = 1
    end
    stageState.streak.consecutiveHeadsCalls = 0
  end

  local batchMatches = 0
  local batchMisses = 0

  for _, coinState in ipairs(context.perCoin or {}) do
    if coinState.result == context.call then
      batchMatches = batchMatches + 1
    else
      batchMisses = batchMisses + 1
    end
  end

  runState.counters.totalMatches = runState.counters.totalMatches + batchMatches
  runState.counters.totalMisses = runState.counters.totalMisses + batchMisses

  if batchMatches > 0 then
    stageState.streak.consecutiveMatches = stageState.streak.consecutiveMatches + 1
    stageState.streak.consecutiveMisses = 0
  else
    stageState.streak.consecutiveMisses = stageState.streak.consecutiveMisses + 1
    stageState.streak.consecutiveMatches = 0
  end

  stageState.lastCall = context.call
end

function FlipResolver.evaluateStageEnd(stageState, context)
  stageState.batchIndex = context.batchId
  stageState.flipsRemaining = math.max(stageState.flipsRemaining - 1, 0)

  if stageState.stageScore >= stageState.targetScore then
    stageState.stageStatus = "cleared"
  elseif stageState.flipsRemaining == 0 then
    stageState.stageStatus = "failed"
  else
    stageState.stageStatus = "active"
  end

  FlipResolver.updateTraceTerminalState(stageState, context)
end

function FlipResolver.updateTraceTerminalState(stageState, context)
  context.trace.stageStatusAfter = stageState.stageStatus
  context.trace.stageScoreAfter = stageState.stageScore
  context.trace.runScoreAfter = context.runState.runTotalScore
  context.trace.shopPointsAfter = context.runState.shopPoints
  context.trace.flipsRemainingAfter = stageState.flipsRemaining
end

function FlipResolver.buildBatchResult(runState, stageState, context, resolutionEntries)
  context.trace.scoreBreakdown = context.scoreBreakdown

  local batch = FlipBatch.new(context.batchId, context.call, {}, resolutionEntries, PurseSystem.getHandSize(runState))
  batch.roundIndex = runState.roundIndex
  batch.stageId = stageState.stageId
  batch.stageLabel = stageState.stageLabel
  batch.stageType = stageState.stageType
  batch.resolvedCoinResults = context.perCoin
  batch.forcedResults = Utils.clone(context.trace.forcedResults or {})
  batch.actions = context.trace.actions
  batch.trace = context.trace
  batch.scoreBreakdown = context.scoreBreakdown
  batch.betResult = Utils.clone(context.betResult)

  return {
    batch = batch,
    batchId = context.batchId,
    call = context.call,
    perCoin = context.perCoin,
    scoreBreakdown = context.scoreBreakdown,
    trace = context.trace,
    status = stageState.stageStatus,
    stageScore = stageState.stageScore,
    targetScore = stageState.targetScore,
    runTotalScore = runState.runTotalScore,
    shopPoints = runState.shopPoints,
    flipsRemaining = stageState.flipsRemaining,
    betResult = Utils.clone(context.betResult),
  }
end

function FlipResolver.applyPhaseActions(runState, stageState, context, phaseName, actions, chainDepth)
  local previousPhase = context.currentPhase
  local previousDepth = context.currentChainDepth

  context.currentPhase = phaseName
  context.currentChainDepth = chainDepth or 0
  ActionQueue.applyAll(runState, stageState, context, actions)
  context.currentPhase = previousPhase
  context.currentChainDepth = previousDepth
end

function FlipResolver.drainPendingActions(runState, stageState, context, phaseName)
  while true do
    local queuedEntries = context.pendingActions and context.pendingActions[phaseName] or nil

    if not queuedEntries or #queuedEntries == 0 then
      break
    end

    context.pendingActions[phaseName] = nil

    for _, entry in ipairs(queuedEntries) do
      FlipResolver.applyPhaseActions(runState, stageState, context, phaseName, entry.actions, entry.chainDepth)

      if context.actionMetrics and context.actionMetrics.limitHit then
        return
      end
    end
  end
end

function FlipResolver.runPhase(runState, stageState, context, phaseName)
  local actions = HookRegistry.runPhase(phaseName, context.activeSources, context)
  FlipResolver.applyPhaseActions(runState, stageState, context, phaseName, actions, 0)
  FlipResolver.drainPendingActions(runState, stageState, context, phaseName)
end

function FlipResolver.projectBatchBeforeRoll(runState, stageState, metaProjection, call, rng)
  local context = FlipResolver.buildResolutionContext(runState, stageState, metaProjection, call, rng)
  context.activeSources = HookRegistry.collectSources(runState, stageState, metaProjection)

  FlipResolver.runPhase(runState, stageState, context, "on_batch_start")
  FlipResolver.runPhase(runState, stageState, context, "before_batch_validation")

  context.perCoin, context.resolutionOrder = FlipResolver.prepareCoinRollState(runState, stageState, metaProjection, context)
  FlipResolver.runPhase(runState, stageState, context, "before_coin_roll")

  return context
end

function FlipResolver.resolveBatch(runState, stageState, metaProjection, call, rng)
  local context

  local handSlots, drawWarning = PurseSystem.drawHand(runState, stageState, rng)

  if stageState.stageStatus ~= "active" then
    return nil, drawWarning or "stage_not_active"
  end

  if not handSlots or #handSlots == 0 then
    return nil, drawWarning or "hand_empty"
  end

  local preValidationRunState = Utils.clone(runState)
  local preValidationStageState = Utils.clone(stageState)
  local preValidationContext = FlipResolver.buildResolutionContext(
    preValidationRunState,
    preValidationStageState,
    metaProjection,
    call,
    RNG.new(rng:getSeed())
  )
  preValidationContext.activeSources = HookRegistry.collectSources(preValidationRunState, preValidationStageState, metaProjection)

  FlipResolver.runPhase(preValidationRunState, preValidationStageState, preValidationContext, "on_batch_start")
  FlipResolver.runPhase(preValidationRunState, preValidationStageState, preValidationContext, "before_batch_validation")

  local ok, validationResult = Validator.validateBatchInput(preValidationRunState, preValidationStageState, call)

  if not ok then
    return nil, validationResult
  end

  ok, validationResult = BetSystem.validateSelectedBet(runState)

  if not ok then
    return nil, validationResult
  end

  context = FlipResolver.projectBatchBeforeRoll(runState, stageState, metaProjection, call, rng)
  context.trace.drawnInstanceIds = PurseSystem.getHandInstanceIds(stageState)
  context.trace.sleightHistory = Utils.clone(stageState.purse and stageState.purse.sleightHistory or {})
  context.trace.reorderHistory = Utils.clone(stageState.purse and stageState.purse.reorderHistory or {})

  if drawWarning then
    table.insert(context.trace.warnings, drawWarning)
  end

  for _, coinRollState in ipairs(context.perCoin) do
    FlipResolver.resolveCoinOutcome(coinRollState, context)
  end

  FlipResolver.runPhase(runState, stageState, context, "after_coin_roll")
  FlipResolver.runPhase(runState, stageState, context, "before_scoring")

  local scoringActions = ScoringSystem.buildScoreActions(context)
  FlipResolver.applyPhaseActions(runState, stageState, context, "score_assembly", scoringActions, 0)

  FlipResolver.runPhase(runState, stageState, context, "after_scoring")
  local betResult, betError = BetSystem.resolveSelectedBet(runState, stageState, context)

  if not betResult then
    return nil, betError
  end

  FlipResolver.updateCounters(runState, stageState, context)
  FlipResolver.runPhase(runState, stageState, context, "before_stage_end_check")
  FlipResolver.evaluateStageEnd(stageState, context)
  FlipResolver.runPhase(runState, stageState, context, "on_batch_end")

  if GameConfig.get("scoring.clearOnThresholdAtBatchEnd", true) == true and stageState.stageScore >= stageState.targetScore then
    stageState.stageStatus = "cleared"
  end

  FlipResolver.updateTraceTerminalState(stageState, context)
  context.trace.exhaustedInstanceIds = PurseSystem.exhaustHand(stageState)

  local undrainedPendingPhases = {}

  for phaseName, queuedEntries in pairs(context.pendingActions or {}) do
    if queuedEntries and #queuedEntries > 0 then
      table.insert(undrainedPendingPhases, string.format("%s(%d)", phaseName, #queuedEntries))
    end
  end

  if #undrainedPendingPhases > 0 then
    table.sort(undrainedPendingPhases)
    local warning = "Undrained queued actions: " .. table.concat(undrainedPendingPhases, ", ")
    table.insert(context.trace.warnings, warning)
    table.insert(context.trace.notes, warning)
  end

  stageState.lastBatchResults = context.trace
  local batchResult = FlipResolver.buildBatchResult(runState, stageState, context, context.resolutionOrder)

  Validator.assertRuntimeInvariants("flip_resolver.resolveBatch", runState, stageState, {
    batchResult = batchResult,
    history = true,
  })

  return batchResult
end

return FlipResolver
