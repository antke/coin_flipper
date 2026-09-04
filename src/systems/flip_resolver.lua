local ActionQueue = require("src.core.action_queue")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local BossTrickSystem = require("src.systems.boss_trick_system")
local FlipBatch = require("src.domain.flip_batch")
local HookRegistry = require("src.core.hook_registry")
local LuckSystem = require("src.systems.luck_system")
local PurseHookSystem = require("src.systems.purse_hook_system")
local PurseSystem = require("src.systems.purse_system")
local PredictionSlotSystem = require("src.systems.prediction_slot_system")
local ScoreBreakdown = require("src.domain.score_breakdown")
local ScoringSystem = require("src.systems.scoring_system")
local Validator = require("src.core.validator")
local GameConfig = require("src.app.config")
local RNG = require("src.core.rng")
local Utils = require("src.core.utils")
local TrickBoardSystem = require("src.systems.trick_board_system")
local TrickActivationSystem = require("src.systems.trick_activation_system")

local FlipResolver = {}

local function clampChance(value)
  return math.max(0, math.min(1, value or 0))
end

local function applyCoinWeightBonuses(headsWeight, tailsWeight, instance)
  local bonuses = instance and instance.state and instance.state.coinWeightBonuses or nil

  if not bonuses then
    return headsWeight, tailsWeight
  end

  local headsChance = clampChance((headsWeight or 0) + (bonuses.heads or 0) - (bonuses.tails or 0))
  return headsChance, 1 - headsChance
end

function FlipResolver.buildResolutionContext(runState, stageState, metaProjection, call, rng)
  LuckSystem.normalize(runState)

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
    pendingScoreScaling = 1.0,
    scoreAppliedToHpBefore = stageState.scoreAppliedToHp or 0,
    runScoreBefore = runState.runTotalScore or 0,
    actionMetrics = {
      appliedCount = 0,
      maxAppliedCount = GameConfig.get("engine.maxAppliedActionsPerBatch"),
      maxPendingActionDepth = GameConfig.get("engine.maxPendingActionDepth"),
      limitHit = false,
    },
    luck = {
      wasFatedFlip = LuckSystem.isFatedFlipActive(runState),
      fatedFlipGeneratesLuck = LuckSystem.getFatedFlipGeneratesLuck(runState),
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
  })

  LuckSystem.ensureTrace(context)
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
    local instance = PurseSystem.getInstance(runState, resolutionEntry.instanceId)
    local coinHeadsWeight, coinTailsWeight = applyCoinWeightBonuses(headsWeight, tailsWeight, instance)

    table.insert(perCoin, {
      coinId = resolutionEntry.coinId,
      instanceId = resolutionEntry.instanceId,
      slotIndex = resolutionEntry.slotIndex,
      selectedSlotIndex = resolutionEntry.selectedSlotIndex,
      dealtIndex = resolutionEntry.dealtIndex,
      boardSlotIndex = resolutionEntry.boardSlotIndex,
      overloadSlotIndex = resolutionEntry.overloadSlotIndex,
      anchorSelectedSlotIndex = resolutionEntry.anchorSelectedSlotIndex,
      anchorInstanceId = resolutionEntry.anchorInstanceId,
      anchorCoinId = resolutionEntry.anchorCoinId,
      anchorOverloadIndex = resolutionEntry.anchorOverloadIndex,
      palmed = resolutionEntry.palmed == true,
      sleightSaved = resolutionEntry.sleightSaved == true,
      smuggled = resolutionEntry.smuggled == true,
      smuggledBy = resolutionEntry.smuggledBy,
      contrabandCopy = resolutionEntry.contrabandCopy == true,
      copiedFromCoinId = resolutionEntry.copiedFromCoinId,
      copiedFromInstanceId = resolutionEntry.copiedFromInstanceId,
      originalDrawIndex = resolutionEntry.originalDrawIndex,
      resolutionIndex = resolutionEntry.resolutionIndex,
      foretold = resolutionEntry.foretold == true,
      foretoldResult = resolutionEntry.foretoldResult,
      foretoldBy = resolutionEntry.foretoldBy,
      foretoldRngRoll = resolutionEntry.foretoldRngRoll,
      baseHeadsWeight = coinHeadsWeight,
      baseTailsWeight = coinTailsWeight,
      headsWeight = coinHeadsWeight,
      tailsWeight = coinTailsWeight,
      result = nil,
      rngRoll = nil,
      flags = {},
    })
    TrickActivationSystem.applyForgeryAssignment(context, perCoin[#perCoin])
    PredictionSlotSystem.applyToCoin(runState, stageState, perCoin[#perCoin])
  end

  return perCoin, resolutionEntries
end

function FlipResolver.resolveCoinOutcome(coinRollState, context)
  local hasForetoldResult = coinRollState.foretoldResult == "heads" or coinRollState.foretoldResult == "tails"
  local roll = hasForetoldResult and coinRollState.foretoldRngRoll or context.rng:nextFloat()
  local headsChance = clampChance(coinRollState.headsWeight)
  local forcedResult = nil
  local forcedReason = nil

  if context.luck and context.luck.wasFatedFlip == true then
    forcedResult = context.call
    forcedReason = "fated_flip"
  elseif context.runState and type(context.runState.pendingForcedCoinResults) == "table" and #context.runState.pendingForcedCoinResults > 0 then
    forcedResult = table.remove(context.runState.pendingForcedCoinResults, 1)
    forcedReason = "pending_forced_result"
  elseif coinRollState.bossForcedResult == "heads" or coinRollState.bossForcedResult == "tails" then
    forcedResult = coinRollState.bossForcedResult
    forcedReason = coinRollState.bossForcedReason or "boss_trick"
  elseif coinRollState.predictionSlotForced == true then
    forcedResult = coinRollState.foretoldResult
    forcedReason = "prediction_slot"
  end

  coinRollState.rngRoll = roll
  coinRollState.forcedResult = forcedResult
  coinRollState.forcedReason = forcedReason
  coinRollState.result = forcedResult or (hasForetoldResult and coinRollState.foretoldResult) or (roll <= headsChance and "heads" or "tails")

  table.insert(context.trace.coinRolls, {
    coinId = coinRollState.coinId,
    instanceId = coinRollState.instanceId,
    slotIndex = coinRollState.slotIndex,
    selectedSlotIndex = coinRollState.selectedSlotIndex,
    dealtIndex = coinRollState.dealtIndex,
    boardSlotIndex = coinRollState.boardSlotIndex,
    overloadSlotIndex = coinRollState.overloadSlotIndex,
    anchorSelectedSlotIndex = coinRollState.anchorSelectedSlotIndex,
    anchorInstanceId = coinRollState.anchorInstanceId,
    anchorCoinId = coinRollState.anchorCoinId,
    anchorOverloadIndex = coinRollState.anchorOverloadIndex,
    palmed = coinRollState.palmed == true,
    sleightSaved = coinRollState.sleightSaved == true,
    smuggled = coinRollState.smuggled == true,
    smuggledBy = coinRollState.smuggledBy,
    contrabandCopy = coinRollState.contrabandCopy == true,
    copiedFromCoinId = coinRollState.copiedFromCoinId,
    copiedFromInstanceId = coinRollState.copiedFromInstanceId,
    resolutionIndex = coinRollState.resolutionIndex,
    baseHeadsWeight = coinRollState.baseHeadsWeight,
    baseTailsWeight = coinRollState.baseTailsWeight,
    headsWeight = coinRollState.headsWeight,
    tailsWeight = coinRollState.tailsWeight,
    rngRoll = roll,
    result = coinRollState.result,
    foretold = coinRollState.foretold == true,
    foretoldResult = coinRollState.foretoldResult,
    foretoldBy = coinRollState.foretoldBy,
    foretoldRngRoll = coinRollState.foretoldRngRoll,
    predictionSlotForced = coinRollState.predictionSlotForced == true,
    predictionSlotIndex = coinRollState.predictionSlotIndex,
    bossForcedResult = coinRollState.bossForcedResult,
    bossForcedReason = coinRollState.bossForcedReason,
    writtenSlotIndex = coinRollState.writtenSlotIndex,
    actingFamily = coinRollState.actingFamily,
    bossActivationFamily = coinRollState.bossActivationFamily,
    originalActivationFamily = coinRollState.originalActivationFamily,
    stolenIdentity = coinRollState.stolenIdentity == true,
    stolenFromSlotIndex = coinRollState.stolenFromSlotIndex,
    forgeryDirection = coinRollState.forgeryDirection,
    forgerySourceCoinId = coinRollState.forgerySourceCoinId,
    forgerySourceInstanceId = coinRollState.forgerySourceInstanceId,
    forgerySourceResolutionIndex = coinRollState.forgerySourceResolutionIndex,
    forcedResult = forcedResult,
    forcedReason = forcedReason,
  })

  if forcedResult then
    table.insert(context.trace.forcedResults, {
      result = forcedResult,
      coinId = coinRollState.coinId,
      instanceId = coinRollState.instanceId,
      slotIndex = coinRollState.slotIndex,
      resolutionIndex = coinRollState.resolutionIndex,
      rngRoll = roll,
      reason = forcedReason,
    })
  end

  return coinRollState.result
end

function FlipResolver.updateCounters(runState, stageState, context)
  runState.counters.totalFlips = runState.counters.totalFlips + 1

  if context.call == "heads" then
    runState.counters.headsCalls = runState.counters.headsCalls + 1
  else
    runState.counters.tailsCalls = runState.counters.tailsCalls + 1
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

  stageState.lastCall = context.call
end

function FlipResolver.evaluateStageEnd(stageState, context)
  stageState.batchIndex = context.batchId
  stageState.flipsRemaining = math.max(stageState.flipsRemaining - 1, 0)

  if stageState.scoreAppliedToHp >= stageState.opponentHp then
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
  context.trace.scoreAppliedToHpAfter = stageState.scoreAppliedToHp
  context.trace.stageScoreAfter = stageState.scoreAppliedToHp
  context.trace.runScoreAfter = context.runState.runTotalScore
  context.trace.influenceAfter = context.runState.influence
  context.trace.shopPointsAfter = context.runState.influence
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
  batch.dealtHand = Utils.clone(context.trace.dealtHand or {})
  batch.selectedSlots = Utils.clone(context.trace.selectedSlots or {})
  batch.boardSlots = Utils.clone(context.trace.boardSlots or {})
  batch.replacements = Utils.clone(context.trace.replacements or {})
  batch.refillEvent = Utils.clone(context.trace.refillEvent or nil)
  batch.actions = context.trace.actions
  batch.trace = context.trace
  batch.scoreBreakdown = context.scoreBreakdown

  return {
    batch = batch,
    batchId = context.batchId,
    call = context.call,
    perCoin = context.perCoin,
    batchFlags = Utils.clone(context.batchFlags or {}),
    scoreBreakdown = context.scoreBreakdown,
    trace = context.trace,
    status = stageState.stageStatus,
    scoreAppliedToHp = stageState.scoreAppliedToHp,
    opponentHp = stageState.opponentHp,
    stageScore = stageState.scoreAppliedToHp,
    targetScore = stageState.opponentHp,
    runTotalScore = runState.runTotalScore,
    influence = runState.influence,
    shopPoints = runState.influence,
    flipsRemaining = stageState.flipsRemaining,
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
  context.activeSources = HookRegistry.collectGlobalSources(runState, stageState, metaProjection)
  TrickActivationSystem.initialize(context, runState, stageState)
  context.trickBoardSnapshot = TrickBoardSystem.snapshot(runState, stageState)
  context.trace.trickBoardSnapshot = Utils.clone(context.trickBoardSnapshot)
  context.enemySkillSnapshot = EnemySkillSystem.snapshot(stageState)
  context.trace.enemySkillSnapshot = Utils.clone(context.enemySkillSnapshot)
  context.bossTrickSnapshot = BossTrickSystem.snapshot(stageState)
  context.trace.bossTrickSnapshot = Utils.clone(context.bossTrickSnapshot)
  context.trace.predictionSlot = PredictionSlotSystem.snapshot(runState, stageState)

  FlipResolver.runPhase(runState, stageState, context, "on_batch_start")
  FlipResolver.runPhase(runState, stageState, context, "before_batch_validation")

  context.purseEventCoins = PurseHookSystem.buildHandCoinStates(runState, stageState)
  FlipResolver.runPhase(runState, stageState, context, "after_call_before_flip")
  context.purseEventCoins = nil

  context.perCoin = PurseHookSystem.buildHandCoinStates(runState, stageState)
  context.perCoin = BossTrickSystem.applyPreFlipCoinMovement(context, context.perCoin)
  BossTrickSystem.applyPreFlipCoinIdentities(context)
  TrickActivationSystem.lockForgeryAssignments(context)
  TrickActivationSystem.buildRootActivations(context)
  FlipResolver.runRootTrickPhase(runState, stageState, context, "after_call_before_flip")

  context.activeSources = HookRegistry.collectGlobalSources(runState, stageState, metaProjection)

  context.perCoin, context.resolutionOrder = FlipResolver.prepareCoinRollState(runState, stageState, metaProjection, context)
  context.perCoin, context.resolutionOrder = BossTrickSystem.applyPreFlipCoinMovement(
    context,
    context.perCoin,
    context.resolutionOrder
  )
  BossTrickSystem.applyPreFlipCoinIdentities(context)
  TrickActivationSystem.buildRootActivations(context)
  context.purseEventCoins = context.perCoin
  FlipResolver.runPhase(runState, stageState, context, "before_hand_flip")
  context.purseEventCoins = nil
  FlipResolver.runPhase(runState, stageState, context, "before_coin_roll")

  for index, activation in ipairs(context.rootActivations or {}) do
    TrickActivationSystem.runTrickPhase(
      runState,
      stageState,
      context,
      activation,
      context.perCoin[index],
      "before_coin_roll"
    )
  end

  ActionQueue.applyAll(runState, stageState, context,
    BossTrickSystem.buildBeforeRollActions(context))
  BossTrickSystem.applyPreFlipForcedOutcomes(context)

  return context
end

function FlipResolver.drainActivationQueue(runState, stageState, context)
  local resolved = 0
  while #(context.activationQueue or {}) > 0 and resolved < (context.maxActivationEvents or 24) do
    local activation = table.remove(context.activationQueue, 1)
    local coinState = TrickActivationSystem.getCoin(context, activation)
    if coinState and (activation.chainDepth or 0) <= 3 then
      resolved = resolved + 1
      if activation.kind == "repeat" then
        TrickActivationSystem.runRepeatedTrick(runState, stageState, context, activation, coinState)
      else
        local actions = ScoringSystem.buildCoinActivationScoreActions(context, coinState, activation, {
          runCoinScorePhase = function(phaseName, scoreEvent)
            local previousCoin = context.currentCoin
            local previousScoreEvent = context.currentScoreEvent
            local previousActivation = context.currentActivation
            context.currentCoin = coinState
            context.currentScoreEvent = scoreEvent
            context.currentActivation = activation
            if phaseName == "before_coin_score" then
              ActionQueue.applyAll(runState, stageState, context,
                BossTrickSystem.buildCoinScoreActions(context, coinState))
              ActionQueue.applyAll(runState, stageState, context,
                EnemySkillSystem.buildCoinScoreActions(context, coinState))
            end
            FlipResolver.runPhase(runState, stageState, context, phaseName)
            TrickActivationSystem.runTrickPhase(runState, stageState, context, activation, coinState, phaseName)
            context.currentCoin = previousCoin
            context.currentScoreEvent = previousScoreEvent
            context.currentActivation = previousActivation
          end,
        })
        FlipResolver.applyPhaseActions(runState, stageState, context, "reactivation_score", actions, activation.chainDepth)
        TrickActivationSystem.runTrickPhase(runState, stageState, context, activation, coinState, "after_all_effects")
      end
    end
  end

  if #(context.activationQueue or {}) > 0 then
    context.trace.activationStopReason = "activation_event_limit"
    context.activationQueue = {}
  end
  context.trace.activationEventsResolved = resolved
end

function FlipResolver.runRootTrickPhase(runState, stageState, context, phaseName)
  for index, activation in ipairs(context.rootActivations or {}) do
    TrickActivationSystem.runTrickPhase(runState, stageState, context, activation, context.perCoin[index], phaseName)
  end
end

function FlipResolver.resolveBatch(runState, stageState, metaProjection, call, rng)
  local context

  local _, drawWarning = PurseSystem.dealHand(runState, stageState, rng)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  PurseHookSystem.runAfterDealBeforeSelection(runState, stageState, metaProjection, { call = call, rng = rng })

  if stageState.stageStatus ~= "active" then
    return nil, drawWarning or "stage_not_active"
  end

  if not purse or not purse.handSlots or #purse.handSlots == 0 then
    return nil, drawWarning or "select at least one coin before flipping"
  end

  PurseHookSystem.runAfterHandDraw(runState, stageState, metaProjection, { call = call, rng = rng })

  local preValidationRunState = Utils.clone(runState)
  local preValidationStageState = Utils.clone(stageState)
  local preValidationContext = FlipResolver.buildResolutionContext(
    preValidationRunState,
    preValidationStageState,
    metaProjection,
    call,
    RNG.new(rng:getSeed())
  )
  preValidationContext.activeSources = HookRegistry.collectGlobalSources(preValidationRunState, preValidationStageState, metaProjection)

  FlipResolver.runPhase(preValidationRunState, preValidationStageState, preValidationContext, "on_batch_start")
  FlipResolver.runPhase(preValidationRunState, preValidationStageState, preValidationContext, "before_batch_validation")

  local ok, validationResult = Validator.validateBatchInput(preValidationRunState, preValidationStageState, call)

  if not ok then
    return nil, validationResult
  end

  TrickBoardSystem.setPhase(stageState, "locked")

  context = FlipResolver.projectBatchBeforeRoll(runState, stageState, metaProjection, call, rng)
  TrickBoardSystem.setPhase(stageState, "resolving")
  context.trace.dealtHand = PurseSystem.getDealtHandEntries(runState, stageState)
  context.trace.selectedSlots = context.trace.threeCups
    and Utils.clone(context.trace.threeCups.originalCoins)
    or PurseSystem.getSelectedSlotEntries(runState, stageState)
  context.trace.boardSlots = PurseSystem.getBoardSlotEntries(runState, stageState)
  context.trace.drawnInstanceIds = PurseSystem.getDealtInstanceIds(stageState)
  context.trace.sleightHistory = Utils.clone(stageState.purse and stageState.purse.sleightHistory or {})
  context.trace.reorderHistory = Utils.clone(stageState.purse and stageState.purse.reorderHistory or {})
  context.trace.purseHookHistory = Utils.clone(stageState.purse and stageState.purse.hookHistory or {})
  context.trace.replacements = {}
  for _, replacement in ipairs(stageState.purse and stageState.purse.replacementHistory or {}) do
    if replacement.batchIndex == context.batchId then
      table.insert(context.trace.replacements, Utils.clone(replacement))
    end
  end

  if drawWarning then
    table.insert(context.trace.warnings, drawWarning)
  end

  for _, coinRollState in ipairs(context.perCoin) do
    FlipResolver.resolveCoinOutcome(coinRollState, context)
  end

  FlipResolver.runPhase(runState, stageState, context, "after_coin_roll")
  FlipResolver.runRootTrickPhase(runState, stageState, context, "after_coin_roll")
  FlipResolver.runPhase(runState, stageState, context, "after_flip_before_score")
  FlipResolver.runRootTrickPhase(runState, stageState, context, "after_flip_before_score")
  FlipResolver.runPhase(runState, stageState, context, "before_scoring")
  FlipResolver.runRootTrickPhase(runState, stageState, context, "before_scoring")

  local scoringActions = ScoringSystem.buildScoreActions(context, {
    runCoinScorePhase = function(phaseName, scoreEvent, coinState)
      local previousCoin = context.currentCoin
      local previousScoreEvent = context.currentScoreEvent

      context.currentCoin = coinState
      context.currentScoreEvent = scoreEvent
      if phaseName == "before_coin_score" then
        ActionQueue.applyAll(runState, stageState, context,
          BossTrickSystem.buildCoinScoreActions(context, coinState))
        ActionQueue.applyAll(runState, stageState, context,
          EnemySkillSystem.buildCoinScoreActions(context, coinState))
      end
      FlipResolver.runPhase(runState, stageState, context, phaseName)
      if phaseName == "before_coin_score"
        and coinState.smuggled == true
        and context.batchFlags.contraband_riches == true then
        ActionQueue.applyAll(runState, stageState, context, {
          { op = "apply_score_scaling", value = 1.5, target = "current_coin_score",
            _trace = { phase = phaseName, sourceId = "embarrassment_of_riches", sourceType = "trick" } },
        })
      end
      local activation = context.rootActivations and context.rootActivations[coinState.resolutionIndex]
      TrickActivationSystem.runTrickPhase(runState, stageState, context, activation, coinState, phaseName)
      context.currentCoin = previousCoin
      context.currentScoreEvent = previousScoreEvent
    end,
  })
  FlipResolver.applyPhaseActions(runState, stageState, context, "score_assembly", scoringActions, 0)

  FlipResolver.runPhase(runState, stageState, context, "after_scoring")
  FlipResolver.runRootTrickPhase(runState, stageState, context, "after_scoring")
  LuckSystem.applyBaseMatchLuck(runState, context)
  FlipResolver.runPhase(runState, stageState, context, "after_all_effects")
  FlipResolver.runRootTrickPhase(runState, stageState, context, "after_all_effects")
  FlipResolver.drainActivationQueue(runState, stageState, context)
  FlipResolver.applyPhaseActions(runState, stageState, context, "boss_trick_resolution",
    BossTrickSystem.buildAfterEffectsActions(context), 0)
  FlipResolver.applyPhaseActions(runState, stageState, context, "enemy_skill_resolution",
    EnemySkillSystem.buildAfterEffectsActions(context, stageState), 0)
  FlipResolver.updateCounters(runState, stageState, context)
  FlipResolver.runPhase(runState, stageState, context, "before_stage_end_check")
  FlipResolver.evaluateStageEnd(stageState, context)
  FlipResolver.runPhase(runState, stageState, context, "on_batch_end")
  FlipResolver.runRootTrickPhase(runState, stageState, context, "on_batch_end")
  LuckSystem.consumeFatedFlip(runState, context)

  if GameConfig.get("scoring.clearOnThresholdAtBatchEnd", true) == true and stageState.scoreAppliedToHp >= stageState.opponentHp then
    stageState.stageStatus = "cleared"
  end

  FlipResolver.updateTraceTerminalState(stageState, context)
  context.trace.refillEvent = PurseSystem.refillHand(stageState, runState, rng)
  context.trace.exhaustedInstanceIds = Utils.copyArray(context.trace.refillEvent.exhaustedInstanceIds or {})
  if stageState.stageStatus == "active" then
    TrickBoardSystem.applyOpponentPressure(runState, stageState)
    BossTrickSystem.prepareIntent(runState, stageState)
  end
  TrickBoardSystem.setPhase(stageState, stageState.stageStatus == "active" and "setup" or "complete")

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
