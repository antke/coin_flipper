local EncounterSystem = require("src.systems.encounter_system")
local FlipResolver = require("src.systems.flip_resolver")
local Loadout = require("src.domain.loadout")
local LoadoutSystem = require("src.systems.loadout_system")
local MetaState = require("src.domain.meta_state")
local PurseHookSystem = require("src.systems.purse_hook_system")
local PurseSystem = require("src.systems.purse_system")
local ProgressionSystem = require("src.systems.progression_system")
local RNG = require("src.core.rng")
local RewardSystem = require("src.systems.reward_system")
local RunHistorySystem = require("src.systems.run_history_system")
local RunInitializer = require("src.systems.run_initializer")
local ShopFlowSystem = require("src.systems.shop_flow_system")
local ShopSystem = require("src.systems.shop_system")
local SummarySystem = require("src.systems.summary_system")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local ReplaySystem = {
  TRANSCRIPT_VERSION = 2,
  TRANSCRIPT_ARTIFACT_TYPE = "replay_transcript",
}

local function copyBatchCall(batch)
  return {
    batchId = batch.batchId,
    roundIndex = batch.roundIndex,
    stageId = batch.stageId,
    call = batch.call,
    dealtHand = Utils.clone(batch.dealtHand or {}),
    selectedSlots = Utils.clone(batch.selectedSlots or {}),
    boardSlots = Utils.clone(batch.boardSlots or {}),
    replacements = Utils.clone(batch.replacements or {}),
    resolutionEntries = Utils.clone(batch.resolutionEntries or {}),
    forcedResults = Utils.clone(batch.forcedResults or {}),
    refillEvent = Utils.clone(batch.refillEvent or {}),
  }
end

local function canonicalSourceType(sourceType)
  if sourceType == "run upgrade" then
    return "trick"
  end

  return sourceType
end

local function canonicalActionOp(op)
  if op == "apply_score_multiplier" then
    return "apply_score_scaling"
  end

  if op == "grant_upgrade" then
    return "grant_trick"
  end

  if op == "add_shop_points" then
    return "add_influence"
  end

  return op
end

local function canonicalContentType(contentType)
  return contentType == "upgrade" and "trick" or contentType
end

local function buildTriggeredSourceSignature(source)
  return {
    phase = source and source.phase or nil,
    sourceId = source and source.sourceId or nil,
    sourceType = canonicalSourceType(source and source.sourceType or nil),
    coinId = source and source.coinId or nil,
    instanceId = source and source.instanceId or nil,
    slotIndex = source and source.slotIndex or nil,
    resolutionIndex = source and source.resolutionIndex or nil,
  }
end

local function buildActionSignature(action)
  return {
    op = canonicalActionOp(action.op),
    amount = action.amount,
    value = action.value,
    chance = action.chance,
    rngRoll = action.rngRoll,
    headsChance = action.headsChance,
    side = action.side,
    appliedSide = action.appliedSide,
    target = action.target,
    flag = action.flag,
    coinId = action.coinId,
    instanceId = action.instanceId,
    trickId = action.trickId or action.upgradeId,
    upgradeId = action.upgradeId,
    contentId = action.contentId,
    offerType = canonicalContentType(action.offerType),
    effectId = action.effectId,
    phase = action.phase,
    note = action.note,
    reason = action.reason,
    delta = action.delta,
    applyMultiplier = action.applyMultiplier,
    persistent = action.persistent,
    slotIndex = action.slotIndex,
    selectedSlotIndex = action.selectedSlotIndex,
    dealtIndex = action.dealtIndex,
    boardSlotIndex = action.boardSlotIndex,
    overloadSlotIndex = action.overloadSlotIndex,
    anchorSelectedSlotIndex = action.anchorSelectedSlotIndex,
    anchorInstanceId = action.anchorInstanceId,
    anchorCoinId = action.anchorCoinId,
    anchorOverloadIndex = action.anchorOverloadIndex,
    resolutionIndex = action.resolutionIndex,
    smuggled = action.smuggled,
    smuggledBy = action.smuggledBy,
    smuggledInstanceId = action.smuggledInstanceId,
    smuggledCoinId = action.smuggledCoinId,
    contrabandCopy = action.contrabandCopy,
    copiedFromCoinId = action.copiedFromCoinId,
    copiedFromInstanceId = action.copiedFromInstanceId,
    forged = action.forged,
    forgedBy = action.forgedBy,
    forgeMode = action.forgeMode,
    forgeScope = action.forgeScope,
    forgedCoinId = action.forgedCoinId,
    scoringCoinId = action.scoringCoinId,
    effectiveIdentityIds = Utils.clone(action.effectiveIdentityIds or nil),
    forgedPayout = action.forgedPayout,
    forgedOutcomeCopy = action.forgedOutcomeCopy,
    forgedOutcomeCopyBy = action.forgedOutcomeCopyBy,
    forgedFamily = action.forgedFamily,
    forgedTrickIds = Utils.clone(action.forgedTrickIds or nil),
    forgedActivationCount = action.forgedActivationCount,
    forgeryEffectiveness = action.forgeryEffectiveness,
    forgeryDirection = action.forgeryDirection,
    targetTrickIds = Utils.clone(action.targetTrickIds or nil),
    maxTier = action.maxTier,
    maxTricks = action.maxTricks,
    sourceCoinId = action.sourceCoinId,
    sourceCoinIds = Utils.clone(action.sourceCoinIds or nil),
    sourceInstanceId = action.sourceInstanceId,
    sourceInstanceIds = Utils.clone(action.sourceInstanceIds or nil),
    sourceSlotIndex = action.sourceSlotIndex,
    sourceResolutionIndex = action.sourceResolutionIndex,
    sourceResolutionIndices = Utils.clone(action.sourceResolutionIndices or nil),
    affectedCoinIds = Utils.clone(action.affectedCoinIds or nil),
    affectedInstanceIds = Utils.clone(action.affectedInstanceIds or nil),
    affectedResolutionIndices = Utils.clone(action.affectedResolutionIndices or nil),
    sourceSacrificed = action.sourceSacrificed,
    targetCoinId = action.targetCoinId,
    targetInstanceId = action.targetInstanceId,
    targetSlotIndex = action.targetSlotIndex,
    targetSelectedSlotIndex = action.targetSelectedSlotIndex,
    targetResolutionIndex = action.targetResolutionIndex,
    savedCoinId = action.savedCoinId,
    savedInstanceId = action.savedInstanceId,
    savedMaterialRank = action.savedMaterialRank,
    replacementCoinId = action.replacementCoinId,
    replacementInstanceId = action.replacementInstanceId,
    replacementMaterialRank = action.replacementMaterialRank,
    replacementDealtIndex = action.replacementDealtIndex,
    targetDealtIndex = action.targetDealtIndex,
    targetMode = action.targetMode,
    mode = action.mode,
    palmed = action.palmed,
    beforeScore = action.beforeScore,
    afterScore = action.afterScore,
    moves = Utils.clone(action.moves or nil),
    packetId = action.packetId,
    packetIds = Utils.clone(action.packetIds or nil),
    packetCoinId = action.packetCoinId,
    packetCoinIds = Utils.clone(action.packetCoinIds or nil),
    packetInstanceId = action.packetInstanceId,
    packetInstanceIds = Utils.clone(action.packetInstanceIds or nil),
    packetSlotIndex = action.packetSlotIndex,
    packetSlotIndices = Utils.clone(action.packetSlotIndices or nil),
    packetSelectedSlotIndex = action.packetSelectedSlotIndex,
    packetSelectedSlotIndices = Utils.clone(action.packetSelectedSlotIndices or nil),
    packetResolutionIndex = action.packetResolutionIndex,
    packetResolutionIndices = Utils.clone(action.packetResolutionIndices or nil),
    packetFinalScoreContribution = action.packetFinalScoreContribution,
    packetFinalScoreContributions = Utils.clone(action.packetFinalScoreContributions or nil),
    prestigeReplay = action.prestigeReplay,
    prestigeReplayBy = action.prestigeReplayBy,
    prestigeScale = action.prestigeScale,
    prestigeScales = Utils.clone(action.prestigeScales or nil),
    rawReplayedScore = action.rawReplayedScore,
    rawReplayedScores = Utils.clone(action.rawReplayedScores or nil),
    replayedScore = action.replayedScore,
    replayedScores = Utils.clone(action.replayedScores or nil),
    replayedPacketCount = action.replayedPacketCount,
    replayMode = action.replayMode,
    replayScope = action.replayScope,
    chosenPacketIndex = action.chosenPacketIndex,
    chosenPacketIndices = Utils.clone(action.chosenPacketIndices or nil),
    scale = action.scale,
    selectionMode = action.selectionMode,
    selection = action.selection,
    count = action.count,
    preferFamily = action.preferFamily,
    preferArchetype = action.preferArchetype,
    chainChance = action.chainChance,
    continuationChance = action.continuationChance,
    direction = action.direction,
    directions = Utils.clone(action.directions or nil),
    maxChainDepth = action.maxChainDepth,
    maxTriggers = action.maxTriggers,
    chainTriggered = action.chainTriggered,
    chainLinkCount = action.chainLinkCount,
    chainDepth = action.chainDepth,
    chainRolls = Utils.clone(action.chainRolls or nil),
    chained = action.chained,
    chainedBy = action.chainedBy,
    chainedCoinId = action.chainedCoinId,
    chainedInstanceId = action.chainedInstanceId,
    chainedSlotIndex = action.chainedSlotIndex,
    chainedResolutionIndex = action.chainedResolutionIndex,
    chainDepthBonus = action.chainDepthBonus,
    momentumDepthBonus = action.momentumDepthBonus,
    appliedChainDepth = action.appliedChainDepth,
    appliedMomentumDepth = action.appliedMomentumDepth,
    appliedValue = action.appliedValue,
    identitySourceCoinId = action.identitySourceCoinId,
    identitySourceInstanceId = action.identitySourceInstanceId,
    failedSlotIndex = action.failedSlotIndex,
    successSlotIndex = action.successSlotIndex,
    failedResolutionIndex = action.failedResolutionIndex,
    successResolutionIndex = action.successResolutionIndex,
    failedInstanceId = action.failedInstanceId,
    successInstanceId = action.successInstanceId,
    failedCoinId = action.failedCoinId,
    successCoinId = action.successCoinId,
    failedBaseScore = action.failedBaseScore,
    successBaseScore = action.successBaseScore,
    requireSourceBaseScoreGreaterThanTarget = action.requireSourceBaseScoreGreaterThanTarget,
    targetBaseScore = action.targetBaseScore,
    replacementBaseScore = action.replacementBaseScore,
    replacementCoinId = action.replacementCoinId,
    replacementInstanceId = action.replacementInstanceId,
    replacementSlotIndex = action.replacementSlotIndex,
    replacementDealtIndex = action.replacementDealtIndex,
    requireReplacementBaseScoreGreaterThanTarget = action.requireReplacementBaseScoreGreaterThanTarget,
    skipped = action.skipped,
    skipReason = action.skipReason,
    foretoldResult = action.foretoldResult,
    foretoldRngRoll = action.foretoldRngRoll,
    trace = action._trace and buildTriggeredSourceSignature(action._trace) or nil,
  }
end

local function buildShopTraceSignature(trace)
  local signature = {
    mode = trace and trace.mode or nil,
    triggeredSources = {},
    actions = {},
    warnings = Utils.copyArray(trace and trace.warnings or {}),
    messages = Utils.copyArray(trace and trace.messages or {}),
    notes = Utils.copyArray(trace and trace.notes or {}),
    extortionEffects = Utils.clone(trace and trace.extortionEffects or nil),
    resolvedShopRules = Utils.clone(trace and trace.resolvedShopRules or nil),
    finalPrice = trace and trace.finalPrice or nil,
    offerCount = trace and trace.offerCount or nil,
  }

  for _, source in ipairs(trace and trace.triggeredSources or {}) do
    table.insert(signature.triggeredSources, buildTriggeredSourceSignature(source))
  end

  for _, action in ipairs(trace and trace.actions or {}) do
    table.insert(signature.actions, buildActionSignature(action))
  end

  return signature
end

local function buildBatchSignature(batch)
  local results = {}
  local coinRolls = {}
  local triggeredSources = {}
  local actions = {}

  for _, coinState in ipairs(batch.resolvedCoinResults or {}) do
    table.insert(results, string.format("%s:%s", coinState.coinId or "?", coinState.result or "?"))
  end

  for _, coinRoll in ipairs(batch.trace and batch.trace.coinRolls or {}) do
    table.insert(coinRolls, {
      coinId = coinRoll.coinId,
      slotIndex = coinRoll.slotIndex,
      selectedSlotIndex = coinRoll.selectedSlotIndex,
      dealtIndex = coinRoll.dealtIndex,
      boardSlotIndex = coinRoll.boardSlotIndex,
      overloadSlotIndex = coinRoll.overloadSlotIndex,
      anchorSelectedSlotIndex = coinRoll.anchorSelectedSlotIndex,
      anchorInstanceId = coinRoll.anchorInstanceId,
      anchorCoinId = coinRoll.anchorCoinId,
      anchorOverloadIndex = coinRoll.anchorOverloadIndex,
      palmed = coinRoll.palmed,
      sleightSaved = coinRoll.sleightSaved,
      smuggled = coinRoll.smuggled,
      smuggledBy = coinRoll.smuggledBy,
      resolutionIndex = coinRoll.resolutionIndex,
      headsWeight = coinRoll.headsWeight,
      tailsWeight = coinRoll.tailsWeight,
      rngRoll = coinRoll.rngRoll,
      result = coinRoll.result,
      foretold = coinRoll.foretold,
      foretoldResult = coinRoll.foretoldResult,
      foretoldBy = coinRoll.foretoldBy,
      foretoldRngRoll = coinRoll.foretoldRngRoll,
      predictionSlotForced = coinRoll.predictionSlotForced,
      predictionSlotIndex = coinRoll.predictionSlotIndex,
      bossForcedResult = coinRoll.bossForcedResult,
      bossForcedReason = coinRoll.bossForcedReason,
      writtenSlotIndex = coinRoll.writtenSlotIndex,
      actingFamily = coinRoll.actingFamily,
      forgeryDirection = coinRoll.forgeryDirection,
      forgerySourceCoinId = coinRoll.forgerySourceCoinId,
      forgerySourceInstanceId = coinRoll.forgerySourceInstanceId,
      forgerySourceResolutionIndex = coinRoll.forgerySourceResolutionIndex,
      forged = coinRoll.forged,
      forgedBy = coinRoll.forgedBy,
      forgedCoinId = coinRoll.forgedCoinId,
      scoringCoinId = coinRoll.scoringCoinId,
      effectiveIdentityIds = Utils.clone(coinRoll.effectiveIdentityIds or nil),
      forgedPayout = coinRoll.forgedPayout,
      identitySourceCoinId = coinRoll.identitySourceCoinId,
      identitySourceInstanceId = coinRoll.identitySourceInstanceId,
      sourceCoinIds = Utils.clone(coinRoll.sourceCoinIds or nil),
      sourceInstanceIds = Utils.clone(coinRoll.sourceInstanceIds or nil),
      sourceResolutionIndices = Utils.clone(coinRoll.sourceResolutionIndices or nil),
      chained = coinRoll.chained,
      chainedBy = coinRoll.chainedBy,
      chainDepth = coinRoll.chainDepth,
      chainLinkIndex = coinRoll.chainLinkIndex,
      chainSourceCoinId = coinRoll.chainSourceCoinId,
      chainSourceInstanceId = coinRoll.chainSourceInstanceId,
      chainSourceSlotIndex = coinRoll.chainSourceSlotIndex,
      chainSourceResolutionIndex = coinRoll.chainSourceResolutionIndex,
      chainRootCoinId = coinRoll.chainRootCoinId,
      chainRootInstanceId = coinRoll.chainRootInstanceId,
    })
  end

  for _, source in ipairs(batch.trace and batch.trace.triggeredSources or {}) do
    table.insert(triggeredSources, buildTriggeredSourceSignature(source))
  end

  for _, action in ipairs(batch.trace and batch.trace.actions or {}) do
    table.insert(actions, buildActionSignature(action))
  end

  return {
    batchId = batch.batchId,
    roundIndex = batch.roundIndex,
    stageId = batch.stageId,
    call = batch.call,
    dealtHand = Utils.clone(batch.dealtHand or {}),
    selectedSlots = Utils.clone(batch.selectedSlots or {}),
    boardSlots = Utils.clone(batch.boardSlots or {}),
    replacements = Utils.clone(batch.replacements or {}),
    refillEvent = Utils.clone(batch.refillEvent or {}),
    results = table.concat(results, "|"),
    status = batch.trace and batch.trace.stageStatusAfter or nil,
    scoreAppliedToHpAfter = batch.trace and (batch.trace.scoreAppliedToHpAfter or batch.trace.stageScoreAfter) or nil,
    runScoreAfter = batch.trace and batch.trace.runScoreAfter or nil,
    influenceAfter = batch.trace and (batch.trace.influenceAfter or batch.trace.shopPointsAfter) or nil,
    flipsRemainingAfter = batch.trace and batch.trace.flipsRemainingAfter or nil,
    coinRolls = coinRolls,
    triggeredSources = triggeredSources,
    actions = actions,
    luck = Utils.clone(batch.trace and batch.trace.luck or {}),
    sleightMoves = Utils.clone(batch.trace and batch.trace.sleightMoves or {}),
    smugglingMoves = Utils.clone(batch.trace and batch.trace.smugglingMoves or {}),
    smugglingExtractions = Utils.clone(batch.trace and batch.trace.smugglingExtractions or {}),
    forgedIdentities = Utils.clone(batch.trace and batch.trace.forgedIdentities or {}),
    forgedOutcomeCopies = Utils.clone(batch.trace and batch.trace.forgedOutcomeCopies or {}),
    forgedActivations = Utils.clone(batch.trace and batch.trace.forgedActivations or {}),
    forgeryAssignments = Utils.clone(batch.trace and batch.trace.forgeryAssignments or {}),
    prestigeReplays = Utils.clone(batch.trace and batch.trace.prestigeReplays or {}),
    chainLinks = Utils.clone(batch.trace and batch.trace.chainLinks or {}),
    purseHookHistory = Utils.clone(batch.trace and batch.trace.purseHookHistory or {}),
    foretoldResults = Utils.clone(batch.trace and batch.trace.foretoldResults or {}),
    queuedActions = Utils.clone(batch.trace and batch.trace.queuedActions or {}),
    forcedResults = Utils.clone(batch.trace and batch.trace.forcedResults or {}),
    activationLedger = Utils.clone(batch.trace and batch.trace.activationLedger or {}),
    activationRolls = Utils.clone(batch.trace and batch.trace.activationRolls or {}),
    activationEventsResolved = batch.trace and batch.trace.activationEventsResolved or 0,
    activationStopReason = batch.trace and batch.trace.activationStopReason or nil,
    trickBoardSnapshot = Utils.clone(batch.trace and batch.trace.trickBoardSnapshot or {}),
    enemySkillSnapshot = Utils.clone(batch.trace and batch.trace.enemySkillSnapshot or {}),
    enemySkillEffects = Utils.clone(batch.trace and batch.trace.enemySkillEffects or {}),
    bossTrickSnapshot = Utils.clone(batch.trace and batch.trace.bossTrickSnapshot or {}),
    bossTrickEffects = Utils.clone(batch.trace and batch.trace.bossTrickEffects or {}),
    threeCups = Utils.clone(batch.trace and batch.trace.threeCups or {}),
    predictionSlot = Utils.clone(batch.trace and batch.trace.predictionSlot or {}),
    preventedActivations = Utils.clone(batch.trace and batch.trace.preventedActivations or {}),
    temporaryEffectsGranted = Utils.clone(batch.trace and batch.trace.temporaryEffectsGranted or {}),
    temporaryEffectsConsumed = Utils.clone(batch.trace and batch.trace.temporaryEffectsConsumed or {}),
    warnings = Utils.copyArray(batch.trace and batch.trace.warnings or {}),
  }
end

local function buildOutcomeSignature(runState)
  local summary = SummarySystem.buildRunSummary(runState, nil)
  local signature = {
    runStatus = runState.runStatus,
    runTotalScore = runState.runTotalScore,
    influence = runState.influence,
    shopPoints = runState.influence,
    collectionCoinIds = Utils.copyArray(runState.collectionCoinIds),
    ownedTrickIds = Utils.copyArray(runState.ownedTrickIds or runState.ownedUpgradeIds),
    counters = Utils.clone(runState.counters),
    summary = {
      runStatus = summary.runStatus,
      runTotalScore = summary.runTotalScore,
      totalFlips = summary.totalFlips,
      totalMatches = summary.totalMatches,
      totalMisses = summary.totalMisses,
      stagesCleared = summary.stagesCleared,
      stagesFailed = summary.stagesFailed,
      metaRewardEarned = summary.metaRewardEarned,
    },
    stageResults = {},
    loadoutKeys = {},
    purchases = {},
    batchSignatures = {},
    shopActions = {},
    luck = Utils.clone(runState.luck or {}),
  }

  for _, stageRecord in ipairs(runState.history.stageResults or {}) do
    table.insert(signature.stageResults, {
      roundIndex = stageRecord.roundIndex,
      stageId = stageRecord.stageId,
      variantId = stageRecord.variantId,
      status = stageRecord.status,
      scoreAppliedToHp = stageRecord.scoreAppliedToHp or stageRecord.stageScore,
      opponentHp = stageRecord.opponentHp or stageRecord.targetScore,
      stageScore = stageRecord.scoreAppliedToHp or stageRecord.stageScore,
      targetScore = stageRecord.opponentHp or stageRecord.targetScore,
      runStatus = stageRecord.runStatus,
      metaRewardEarned = stageRecord.metaRewardEarned,
      rewardChoice = Utils.clone(stageRecord.rewardChoice or nil),
    })
  end

  for _, commit in ipairs(runState.history.loadoutCommits or {}) do
    table.insert(signature.loadoutKeys, {
      roundIndex = commit.roundIndex,
      stageId = commit.stageId,
      canonicalKey = commit.canonicalKey,
    })
  end

  for _, purchase in ipairs(runState.history.purchases or {}) do
    table.insert(signature.purchases, Utils.clone(purchase))
  end

  for _, batch in ipairs(runState.history.flipBatches or {}) do
    table.insert(signature.batchSignatures, buildBatchSignature(batch))
  end

  for _, visit in ipairs(runState.history.shopVisits or {}) do
    table.insert(signature.shopActions, {
      roundIndex = visit.roundIndex,
      sourceStageId = visit.sourceStageId,
      actions = Utils.clone(visit.actions or {}),
      offerSets = Utils.clone(visit.offerSets or {}),
      generationTraces = (function()
        local traces = {}
        for _, trace in ipairs(visit.generationTraces or {}) do
          table.insert(traces, buildShopTraceSignature(trace))
        end
        return traces
      end)(),
      purchaseTraces = (function()
        local traces = {}
        for _, trace in ipairs(visit.purchaseTraces or {}) do
          table.insert(traces, buildShopTraceSignature(trace))
        end
        return traces
      end)(),
    })
  end

  return signature
end

local function valuesEqual(left, right)
  if type(left) ~= type(right) then
    return false
  end

  if type(left) ~= "table" then
    return left == right
  end

  local checked = {}

  for key, leftValue in pairs(left) do
    if not valuesEqual(leftValue, right[key]) then
      return false
    end

    checked[key] = true
  end

  for key in pairs(right) do
    if not checked[key] then
      return false
    end
  end

  return true
end

local function compareValues(path, expected, actual, mismatches, limit)
  if #mismatches >= limit then
    return
  end

  if type(expected) ~= type(actual) then
    table.insert(mismatches, string.format("%s type mismatch: expected %s got %s", path, type(expected), type(actual)))
    return
  end

  if type(expected) ~= "table" then
    if string.match(path, "%.sourceType$") or path == "sourceType" then
      expected = canonicalSourceType(expected)
      actual = canonicalSourceType(actual)
    elseif string.match(path, "%.op$") or path == "op" then
      expected = canonicalActionOp(expected)
      actual = canonicalActionOp(actual)
    elseif string.match(path, "%.type$") or path == "type" or string.match(path, "%.offerType$") or path == "offerType" or string.match(path, "%.purchaseType$") or path == "purchaseType" then
      expected = canonicalContentType(expected)
      actual = canonicalContentType(actual)
    end

    if expected ~= actual then
      table.insert(mismatches, string.format("%s mismatch: expected %s got %s", path, tostring(expected), tostring(actual)))
    end
    return
  end

  local seen = {}

  for key, expectedValue in pairs(expected) do
    compareValues(string.format("%s.%s", path, tostring(key)), expectedValue, actual[key], mismatches, limit)
    seen[key] = true

    if #mismatches >= limit then
      return
    end
  end

  for key, actualValue in pairs(actual) do
    if not seen[key] then
      table.insert(mismatches, string.format("%s.%s unexpected value %s", path, tostring(key), tostring(actualValue)))
      if #mismatches >= limit then
        return
      end
    end
  end
end

local function cloneBootstrapMetaState(bootstrap)
  if bootstrap and bootstrap.metaState then
    return MetaState.new(Utils.clone(bootstrap.metaState))
  end

  return MetaState.new()
end

local function buildStageTranscript(runState, stageRecord, batchPointer, shopPointer, loadoutPointer)
  local stageEntry = {
    roundIndex = stageRecord.roundIndex,
    stageId = stageRecord.stageId,
    stageType = stageRecord.stageType,
    variantId = stageRecord.variantId,
    variantName = stageRecord.variantName,
    loadout = nil,
    batches = {},
    reward = nil,
    encounter = nil,
    shop = nil,
  }

  local loadoutCommits = runState.history.loadoutCommits or {}
  local loadoutCommit = loadoutCommits[loadoutPointer]

  if loadoutCommit and loadoutCommit.stageId == stageRecord.stageId and loadoutCommit.roundIndex == stageRecord.roundIndex then
    stageEntry.loadout = {
      slots = Loadout.cloneSlots(loadoutCommit.slots, runState.maxFlipSlots),
      canonicalKey = loadoutCommit.canonicalKey,
    }
    loadoutPointer = loadoutPointer + 1
  end

  local flipBatches = runState.history.flipBatches or {}
  while true do
    local batch = flipBatches[batchPointer]

    if not batch or batch.stageId ~= stageRecord.stageId or batch.roundIndex ~= stageRecord.roundIndex then
      break
    end

    table.insert(stageEntry.batches, copyBatchCall(batch))
    batchPointer = batchPointer + 1
  end

  local shopVisits = runState.history.shopVisits or {}
  local shopVisit = shopVisits[shopPointer]

  if shopVisit
    and shopVisit.sourceStageId == stageRecord.stageId
    and shopVisit.roundIndex == stageRecord.roundIndex
    and stageRecord.runStatus == "active"
    and stageRecord.status == "cleared" then
    stageEntry.shop = {
      roundIndex = shopVisit.roundIndex,
      sourceStageId = shopVisit.sourceStageId,
      actions = Utils.clone(shopVisit.actions or {}),
      offerSets = Utils.clone(shopVisit.offerSets or {}),
      generationTraces = (function()
        local traces = {}
        for _, trace in ipairs(shopVisit.generationTraces or {}) do
          table.insert(traces, buildShopTraceSignature(trace))
        end
        return traces
      end)(),
      purchaseTraces = (function()
        local traces = {}
        for _, trace in ipairs(shopVisit.purchaseTraces or {}) do
          table.insert(traces, buildShopTraceSignature(trace))
        end
        return traces
      end)(),
    }
    shopPointer = shopPointer + 1
  end

  if stageRecord.rewardOptions ~= nil or stageRecord.rewardChoice ~= nil then
    stageEntry.reward = {
      options = Utils.clone(stageRecord.rewardOptions or {}),
      choice = Utils.clone(stageRecord.rewardChoice or nil),
      generation = Utils.clone(stageRecord.rewardGeneration or nil),
    }
  end

  if stageRecord.encounter ~= nil or stageRecord.encounterChoice ~= nil then
    stageEntry.encounter = {
      id = stageRecord.encounter and stageRecord.encounter.id or nil,
      name = stageRecord.encounter and stageRecord.encounter.name or nil,
      description = stageRecord.encounter and stageRecord.encounter.description or nil,
      choices = Utils.clone(stageRecord.encounter and stageRecord.encounter.choices or {}),
      choice = Utils.clone(stageRecord.encounterChoice or nil),
    }
  end

  return stageEntry, batchPointer, shopPointer, loadoutPointer
end

function ReplaySystem.buildTranscript(runState)
  local history = runState and runState.history or nil

  if not history or not history.bootstrap then
    return nil, "missing_bootstrap_history"
  end

  local transcript = {
    artifactType = ReplaySystem.TRANSCRIPT_ARTIFACT_TYPE,
    version = ReplaySystem.TRANSCRIPT_VERSION,
    bootstrap = Utils.clone(history.bootstrap),
    stages = {},
    expected = buildOutcomeSignature(runState),
  }

  local batchPointer = 1
  local shopPointer = 1
  local loadoutPointer = 1

  for _, stageRecord in ipairs(history.stageResults or {}) do
    local stageEntry
    stageEntry, batchPointer, shopPointer, loadoutPointer = buildStageTranscript(runState, stageRecord, batchPointer, shopPointer, loadoutPointer)
    table.insert(transcript.stages, stageEntry)
  end

  local ok, errorMessage = Validator.validateReplayTranscriptPayload(transcript)

  if not ok then
    return nil, errorMessage
  end

  return transcript
end

local function migrateTranscriptArtifact(transcript)
  if type(transcript) ~= "table" then
    return nil, "invalid_transcript"
  end

  if transcript.artifactType ~= nil then
    if transcript.artifactType ~= ReplaySystem.TRANSCRIPT_ARTIFACT_TYPE then
      return nil, string.format("unsupported_transcript_artifact_type:%s", tostring(transcript.artifactType))
    end

    if transcript.version ~= ReplaySystem.TRANSCRIPT_VERSION then
      return nil, string.format("unsupported_transcript_version:%s", tostring(transcript.version))
    end

    return transcript
  end

  if transcript.version == 1 and transcript.bootstrap and transcript.stages and transcript.expected then
    local migrated = Utils.clone(transcript)
    migrated.artifactType = ReplaySystem.TRANSCRIPT_ARTIFACT_TYPE
    migrated.version = ReplaySystem.TRANSCRIPT_VERSION
    return migrated
  end

  if transcript.version ~= nil then
    return nil, string.format("unsupported_transcript_version:%s", tostring(transcript.version))
  end

  return nil, "invalid_transcript"
end

local function verifyOfferSet(expectedSnapshot, offers, reason)
  local actualSnapshot = {
    reason = reason,
    offers = {},
  }

  for _, offer in ipairs(offers or {}) do
    table.insert(actualSnapshot.offers, RunHistorySystem.serializeShopOffer(offer))
  end

  return valuesEqual(expectedSnapshot, actualSnapshot)
end

local function verifyShopTrace(expectedTrace, actualTrace)
  if not expectedTrace then
    return false
  end

  return valuesEqual(expectedTrace, buildShopTraceSignature(actualTrace))
end

local function replayShopVisit(runState, stageState, stageRecord, metaProjection, rng, shopTranscript)
  if not shopTranscript then
    return true
  end

  local shopFlow = ShopFlowSystem.createVisit(runState, stageState, metaProjection, rng, {
    sourceStageId = stageRecord.stageId,
    roundIndex = stageRecord.roundIndex,
  })
  local offerSetIndex = 1
  local generationTraceIndex = 1
  local purchaseTraceIndex = 1

  local function verifyCurrentRefresh(reason)
    local expectedOfferSet = (shopTranscript.offerSets or {})[offerSetIndex]
    local expectedTrace = (shopTranscript.generationTraces or {})[generationTraceIndex]

    if not expectedOfferSet then
      return false, string.format("missing_expected_offer_set:%s", tostring(reason))
    end

    if not expectedTrace then
      return false, string.format("missing_expected_generation_trace:%s", tostring(reason))
    end

    if not verifyOfferSet(expectedOfferSet, shopFlow.offers, reason) then
      return false, string.format("shop_offer_set_mismatch:%s", tostring(reason))
    end

    if not verifyShopTrace(expectedTrace, shopFlow.lastGenerationTrace) then
      return false, string.format("shop_generation_trace_mismatch:%s", tostring(reason))
    end

    offerSetIndex = offerSetIndex + 1
    generationTraceIndex = generationTraceIndex + 1
    return true
  end

  local function refreshOffers(reason)
    ShopFlowSystem.refreshOffers(shopFlow, reason)

    return verifyCurrentRefresh(reason)
  end

  local ok, errorMessage = refreshOffers("initial")
  if not ok then
    return false, errorMessage
  end

  for _, action in ipairs(shopTranscript.actions or {}) do
    if action.type == "reroll" then
      local rerollMode, rerollError = ShopFlowSystem.reroll(shopFlow)

      if not rerollMode then
        return false, rerollError or "reroll_failed"
      end

      if action.mode and rerollMode ~= action.mode then
        return false, string.format("reroll_mode_mismatch:%s:%s", tostring(action.mode), tostring(rerollMode))
      end

      ok, errorMessage = verifyCurrentRefresh("reroll_" .. rerollMode)
      if not ok then
        return false, errorMessage
      end
    elseif action.type == "purchase" then
      local offerIndex = ShopFlowSystem.findOfferIndex(shopFlow, action.offerType, action.contentId)

      if not offerIndex then
        return false, string.format("missing_offer:%s:%s", tostring(action.offerType), tostring(action.contentId))
      end

      if action.replacePosition ~= nil then
        shopFlow.offers[offerIndex].replacePosition = action.replacePosition
      end

      local purchased, result, offer = ShopFlowSystem.purchase(shopFlow, offerIndex)
      local expectedPurchaseTrace = (shopTranscript.purchaseTraces or {})[purchaseTraceIndex]

      if not expectedPurchaseTrace then
        return false, string.format("missing_expected_purchase_trace:%s:%s", tostring(action.offerType), tostring(action.contentId))
      end

      if action.outcome == "success" then
        if not purchased then
          return false, string.format("unexpected_purchase_failure:%s", tostring(result and result.reason or "unknown"))
        end

        if action.finalPrice and result.finalPrice ~= action.finalPrice then
          return false, string.format("purchase_price_mismatch:%s:%s", tostring(action.finalPrice), tostring(result.finalPrice))
        end
      else
        if purchased then
          return false, "unexpected_purchase_success"
        end

        if action.reason and action.reason ~= (result and result.reason) then
          return false, string.format("purchase_reason_mismatch:%s:%s", tostring(action.reason), tostring(result and result.reason))
        end
      end

      if not verifyShopTrace(expectedPurchaseTrace, shopFlow.lastPurchaseTrace) then
        return false, string.format("shop_purchase_trace_mismatch:%s:%s", tostring(action.offerType), tostring(action.contentId))
      end

      purchaseTraceIndex = purchaseTraceIndex + 1
    else
      return false, string.format("unknown_shop_action:%s", tostring(action.type))
    end
  end

  if (offerSetIndex - 1) ~= #(shopTranscript.offerSets or {}) then
    return false, string.format("shop_offer_set_count_mismatch:%s:%s", tostring(offerSetIndex - 1), tostring(#(shopTranscript.offerSets or {})))
  end

  if (generationTraceIndex - 1) ~= #(shopTranscript.generationTraces or {}) then
    return false, string.format("shop_generation_trace_count_mismatch:%s:%s", tostring(generationTraceIndex - 1), tostring(#(shopTranscript.generationTraces or {})))
  end

  if (purchaseTraceIndex - 1) ~= #(shopTranscript.purchaseTraces or {}) then
    return false, string.format("shop_purchase_trace_count_mismatch:%s:%s", tostring(purchaseTraceIndex - 1), tostring(#(shopTranscript.purchaseTraces or {})))
  end

  Validator.assertRuntimeInvariants("replay_system.replayShopVisit", runState, stageState, { history = true })
  return true
end

local function replayRewardChoice(runState, stageRecord, rng, rewardTranscript, hasShopTranscript)
  local rewardEligible = (
    stageRecord.stageType == "normal"
    and stageRecord.status == "cleared"
    and (runState.runStatus == "active" or runState.runStatus == "won")
  ) or (
    stageRecord.stageType == "boss"
    and stageRecord.status == "cleared"
    and runState.runStatus == "won"
  )

  if not rewardEligible then
    if rewardTranscript ~= nil then
      return false, "unexpected_reward_for_stage"
    end

    return true
  end

  if not rewardTranscript then
    return true
  end

  local session = RewardSystem.buildPreviewForStage(runState, stageRecord)
  RunHistorySystem.recordStageRewardPreview(stageRecord, session)

  if not valuesEqual(rewardTranscript.options or {}, stageRecord.rewardOptions or {}) then
    return false, "reward_options_mismatch"
  end

  if rewardTranscript.generation ~= nil and not valuesEqual(rewardTranscript.generation, stageRecord.rewardGeneration or {}) then
    return false, "reward_generation_mismatch"
  end

  if rewardTranscript.choice == nil then
    if #(session.options or {}) > 0 then
      return false, "missing_reward_choice"
    end

    local ok, claimError = RewardSystem.claimSelection(runState, session)
    if not ok then
      return false, claimError or "reward_claim_failed"
    end

    return true
  end

  if rewardTranscript.choice.type == "currency"
    and rewardTranscript.choice.contentId == "skip_influence" then
    local ok, choiceOrError = RewardSystem.claimSkip(runState, session)
    if not ok then
      return false, choiceOrError or "reward_skip_failed"
    end
    RunHistorySystem.recordStageRewardChoice(stageRecord, choiceOrError)
    if not valuesEqual(rewardTranscript.choice, stageRecord.rewardChoice) then
      return false, "reward_choice_mismatch"
    end
    return true
  end

  local choiceIndex = nil
  for index, option in ipairs(session.options or {}) do
    if option.type == rewardTranscript.choice.type and option.contentId == rewardTranscript.choice.contentId then
      choiceIndex = index
      break
    end
  end

  if not choiceIndex then
    return false, string.format(
      "missing_reward_option:%s:%s",
      tostring(rewardTranscript.choice.type),
      tostring(rewardTranscript.choice.contentId)
    )
  end

  RewardSystem.selectOption(session, choiceIndex)
  if rewardTranscript.choice.replacedTrickPosition ~= nil then
    session.replacementRequired = true
    session.replacePosition = rewardTranscript.choice.replacedTrickPosition
  end
  local ok, choiceOrError = RewardSystem.claimSelection(runState, session)

  if not ok then
    return false, choiceOrError or "reward_claim_failed"
  end

  RunHistorySystem.recordStageRewardChoice(stageRecord, choiceOrError)

  if not valuesEqual(rewardTranscript.choice, stageRecord.rewardChoice) then
    return false, "reward_choice_mismatch"
  end

  return true
end

local function replayEncounterChoice(runState, stageRecord, encounterTranscript, hasShopTranscript)
  local encounterEligible = stageRecord.stageType == "normal"
    and stageRecord.status == "cleared"
    and runState.runStatus == "active"

  if not encounterEligible then
    if encounterTranscript ~= nil then
      return false, "unexpected_encounter_for_stage"
    end

    return true
  end

  if not encounterTranscript then
    if not hasShopTranscript then
      return true
    end

    return false, "missing_encounter_choice"
  end

  local session = EncounterSystem.buildSession(runState)
  RunHistorySystem.recordStageEncounterPreview(stageRecord, session)

  local expectedEncounter = {
    id = encounterTranscript.id,
    name = encounterTranscript.name,
    description = encounterTranscript.description,
    choices = Utils.clone(encounterTranscript.choices or {}),
  }

  if not valuesEqual(expectedEncounter, stageRecord.encounter or {}) then
    return false, "encounter_options_mismatch"
  end

  if encounterTranscript.choice == nil then
    if #(session.choices or {}) > 0 then
      return false, "missing_encounter_choice"
    end

    local ok, claimError = EncounterSystem.claimChoice(runState, session)
    if not ok then
      return false, claimError or "encounter_claim_failed"
    end

    return true
  end

  local choiceIndex = nil
  for index, choice in ipairs(session.choices or {}) do
    if choice.id == encounterTranscript.choice.id then
      choiceIndex = index
      break
    end
  end

  if not choiceIndex then
    return false, string.format("missing_encounter_option:%s", tostring(encounterTranscript.choice.id))
  end

  EncounterSystem.selectChoice(session, choiceIndex, runState)
  if session.replacementRequired then
    session.replacePosition = encounterTranscript.choice.replacedTrickPosition
  end
  local ok, choiceOrError = EncounterSystem.claimChoice(runState, session)
  if not ok then
    return false, choiceOrError or "encounter_claim_failed"
  end

  RunHistorySystem.recordStageEncounterChoice(stageRecord, choiceOrError)

  if not valuesEqual(encounterTranscript.choice, stageRecord.encounterChoice) then
    return false, "encounter_choice_mismatch"
  end

  return true
end

local function getBootstrapResolvedValue(resolvedValues, canonicalKey, legacyKey)
  if type(resolvedValues) ~= "table" then
    return nil
  end

  if resolvedValues[canonicalKey] ~= nil then
    return resolvedValues[canonicalKey]
  end

  if legacyKey ~= nil then
    return resolvedValues[legacyKey]
  end

  return nil
end

function ReplaySystem.replayTranscript(transcript)
  local normalizedTranscript, migrationError = migrateTranscriptArtifact(transcript)

  if not normalizedTranscript then
    return {
      ok = false,
      error = migrationError or "invalid_transcript",
      mismatches = { tostring(migrationError or "Transcript is invalid.") },
    }
  end

  local ok, validationError = Validator.validateReplayTranscriptPayload(normalizedTranscript)

  if not ok then
    return {
      ok = false,
      error = "invalid_transcript_schema",
      mismatches = { tostring(validationError) },
    }
  end

  local metaState = cloneBootstrapMetaState(normalizedTranscript.bootstrap)
  local resolvedBootstrapValues = normalizedTranscript.bootstrap.resolvedValues or {}
  local startingCollectionSize = normalizedTranscript.bootstrap.startingCollectionSize

  if startingCollectionSize == nil then
    startingCollectionSize = getBootstrapResolvedValue(resolvedBootstrapValues, "run.startingCollectionSize", "startingCollectionSize")
  end

  local runState, metaProjection = RunInitializer.createNewRun(metaState, {
    seed = normalizedTranscript.bootstrap.seed,
    startingCollectionSize = startingCollectionSize,
    starterCollection = normalizedTranscript.bootstrap.starterCollection,
    starterPurse = normalizedTranscript.bootstrap.starterPurse,
    flipSlots = normalizedTranscript.bootstrap.flipSlots or normalizedTranscript.bootstrap.equippedCoinSlots,
    persistedFlipSlots = normalizedTranscript.bootstrap.persistedFlipSlots or normalizedTranscript.bootstrap.persistedLoadoutSlots,
    ownedTrickIds = normalizedTranscript.bootstrap.ownedTrickIds or normalizedTranscript.bootstrap.ownedUpgradeIds,
    resolvedValues = resolvedBootstrapValues,
    maxFlipSlots = getBootstrapResolvedValue(resolvedBootstrapValues, "run.maxFlipSlots", "maxFlipSlots")
      or getBootstrapResolvedValue(resolvedBootstrapValues, "run.maxActiveCoinSlots", "maxActiveCoinSlots"),
    baseFlipsPerStage = getBootstrapResolvedValue(resolvedBootstrapValues, "stage.flipsPerStage", "baseFlipsPerStage"),
    startingInfluence = getBootstrapResolvedValue(resolvedBootstrapValues, "run.startingInfluence", "startingInfluence")
      or getBootstrapResolvedValue(resolvedBootstrapValues, "run.startingShopPoints", "startingShopPoints"),
    startingShopRerolls = getBootstrapResolvedValue(resolvedBootstrapValues, "run.startingShopRerolls", "startingShopRerolls"),
  })
  local rng = RNG.new(runState.seed)
  local consumedStageCount = 0

  for _, stageInput in ipairs(normalizedTranscript.stages or {}) do
    if runState.runStatus ~= "active" then
      break
    end

    consumedStageCount = consumedStageCount + 1

    local stageState, stageDefinition = RunInitializer.createStageForCurrentRound(runState)

    if stageDefinition.id ~= stageInput.stageId then
      return {
        ok = false,
        error = "stage_id_mismatch",
        mismatches = { string.format("Expected stage %s but replay reached %s", tostring(stageInput.stageId), tostring(stageDefinition.id)) },
      }
    end

    if stageInput.stageType and stageDefinition.stageType ~= stageInput.stageType then
      return {
        ok = false,
        error = "stage_type_mismatch",
        mismatches = { string.format("Expected stage type %s but replay reached %s", tostring(stageInput.stageType), tostring(stageDefinition.stageType)) },
      }
    end

    if stageInput.variantId ~= nil and stageDefinition.variantId ~= stageInput.variantId then
      return {
        ok = false,
        error = "stage_variant_mismatch",
        mismatches = { string.format("Expected stage variant %s but replay reached %s", tostring(stageInput.variantId), tostring(stageDefinition.variantId)) },
      }
    end

    local committedSelection, commitError = LoadoutSystem.commitLoadout(runState, stageInput.loadout and stageInput.loadout.slots or {})

    if not committedSelection then
      return {
        ok = false,
        error = commitError or "loadout_commit_failed",
        mismatches = { tostring(commitError or "loadout_commit_failed") },
      }
    end

    if stageInput.loadout and stageInput.loadout.canonicalKey then
      local actualCanonicalKey = Loadout.toCanonicalKey(committedSelection, runState.maxFlipSlots)

      if actualCanonicalKey ~= stageInput.loadout.canonicalKey then
        return {
          ok = false,
          error = "loadout_canonical_key_mismatch",
          mismatches = {
            string.format(
              "Expected loadout canonicalKey %s but replay committed %s",
              tostring(stageInput.loadout.canonicalKey),
              tostring(actualCanonicalKey)
            ),
          },
        }
      end
    end

    for _, batchInput in ipairs(stageInput.batches or {}) do
      if batchInput.stageId and batchInput.stageId ~= stageState.stageId then
        return {
          ok = false,
          error = "batch_stage_mismatch",
          mismatches = { string.format("Batch expected stage %s but replay stage is %s", tostring(batchInput.stageId), tostring(stageState.stageId)) },
        }
      end

      if batchInput.roundIndex and batchInput.roundIndex ~= runState.roundIndex then
        return {
          ok = false,
          error = "batch_round_mismatch",
          mismatches = { string.format("Batch expected round %s but replay round is %s", tostring(batchInput.roundIndex), tostring(runState.roundIndex)) },
        }
      end

      local expectedBatchId = stageState.batchIndex + 1
      if batchInput.batchId and batchInput.batchId ~= expectedBatchId then
        return {
          ok = false,
          error = "batch_id_mismatch",
          mismatches = { string.format("Batch expected id %s but replay batch would be %s", tostring(batchInput.batchId), tostring(expectedBatchId)) },
        }
      end

      runState.pendingForcedCoinResults = {}

      for _, forcedEntry in ipairs(batchInput.forcedResults or {}) do
        if forcedEntry.reason == nil or forcedEntry.reason == "pending_forced_result" then
          table.insert(runState.pendingForcedCoinResults, forcedEntry.result)
        end
      end

      local _, dealWarning = PurseSystem.dealHand(runState, stageState, rng)
      PurseHookSystem.runAfterDealBeforeSelection(runState, stageState, metaProjection, { call = batchInput.call, rng = rng })

      if dealWarning ~= "purse_empty" then
        for _, replacement in ipairs(batchInput.replacements or {}) do
          local replaceOk, replaceError = PurseSystem.replaceHeldCoin(
            runState,
            stageState,
            replacement.spentInstanceId or replacement.handPosition,
            rng
          )
          if not replaceOk then
            return {
              ok = false,
              error = replaceError or "batch_replacement_failed",
              mismatches = { tostring(replaceError or "batch_replacement_failed") },
            }
          end
        end
        local selectedOk, selectedError = PurseSystem.setSelectedSlotsFromEntries(runState, stageState, batchInput.selectedSlots or {}, {
          rule = "replay_transcript_selection",
        })

        if not selectedOk then
          return {
            ok = false,
            error = selectedError or "batch_selection_failed",
            mismatches = { tostring(selectedError or "batch_selection_failed") },
          }
        end
      end

      local batchResult, batchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, batchInput.call, rng)

      if not batchResult then
        return {
          ok = false,
          error = batchError or "batch_failed",
          mismatches = { tostring(batchError or "batch_failed") },
        }
      end

      if batchInput.batchId and batchResult.batchId ~= batchInput.batchId then
        return {
          ok = false,
          error = "resolved_batch_id_mismatch",
          mismatches = { string.format("Resolved batch id %s but transcript recorded %s", tostring(batchResult.batchId), tostring(batchInput.batchId)) },
      }
      end

      if batchInput.resolutionEntries ~= nil and not valuesEqual(batchInput.resolutionEntries, batchResult.batch.resolutionEntries or {}) then
        return {
          ok = false,
          error = "batch_resolution_entries_mismatch",
          mismatches = {
            string.format(
              "Resolved batch %s slot metadata did not match transcript for stage %s round %s",
              tostring(batchResult.batchId),
              tostring(stageState.stageId),
              tostring(runState.roundIndex)
            ),
          },
        }
      end

      if batchInput.dealtHand ~= nil and not valuesEqual(batchInput.dealtHand, batchResult.batch.dealtHand or {}) then
        return {
          ok = false,
          error = "batch_dealt_hand_mismatch",
          mismatches = {
            string.format(
              "Resolved batch %s dealt-hand metadata did not match transcript for stage %s round %s",
              tostring(batchResult.batchId),
              tostring(stageState.stageId),
              tostring(runState.roundIndex)
            ),
          },
        }
      end

      if batchInput.selectedSlots ~= nil and not valuesEqual(batchInput.selectedSlots, batchResult.batch.selectedSlots or {}) then
        return {
          ok = false,
          error = "batch_selected_slots_mismatch",
          mismatches = {
            string.format(
              "Resolved batch %s selected-slot metadata did not match transcript for stage %s round %s",
              tostring(batchResult.batchId),
              tostring(stageState.stageId),
              tostring(runState.roundIndex)
            ),
          },
        }
      end

      if batchInput.boardSlots ~= nil and not valuesEqual(batchInput.boardSlots, batchResult.batch.boardSlots or {}) then
        return {
          ok = false,
          error = "batch_board_slots_mismatch",
          mismatches = {
            string.format(
              "Resolved batch %s board-slot metadata did not match transcript for stage %s round %s",
              tostring(batchResult.batchId),
              tostring(stageState.stageId),
              tostring(runState.roundIndex)
            ),
          },
        }
      end

      if batchInput.refillEvent ~= nil and not valuesEqual(batchInput.refillEvent, batchResult.batch.refillEvent or {}) then
        return {
          ok = false,
          error = "batch_refill_event_mismatch",
          mismatches = {
            string.format(
              "Resolved batch %s refill metadata did not match transcript for stage %s round %s",
              tostring(batchResult.batchId),
              tostring(stageState.stageId),
              tostring(runState.roundIndex)
            ),
          },
        }
      end

      if batchInput.forcedResults ~= nil and not valuesEqual(batchInput.forcedResults, batchResult.batch.forcedResults or {}) then
        return {
          ok = false,
          error = "batch_forced_results_mismatch",
          mismatches = {
            string.format(
              "Resolved batch %s forced result metadata did not match transcript for stage %s round %s",
              tostring(batchResult.batchId),
              tostring(stageState.stageId),
              tostring(runState.roundIndex)
            ),
          },
        }
      end

      table.insert(runState.history.flipBatches, Utils.clone(batchResult.batch))
    end

    local stageRecord = RunHistorySystem.finalizeStage(runState, stageState, metaState)

    local okReward, rewardError = replayRewardChoice(runState, stageRecord, rng, stageInput.reward, stageInput.shop ~= nil)
    if not okReward then
      return {
        ok = false,
        error = rewardError or "reward_replay_failed",
        mismatches = { tostring(rewardError or "reward_replay_failed") },
      }
    end

    local okEncounter, encounterError = replayEncounterChoice(runState, stageRecord, stageInput.encounter, stageInput.shop ~= nil)
    if not okEncounter then
      return {
        ok = false,
        error = encounterError or "encounter_replay_failed",
        mismatches = { tostring(encounterError or "encounter_replay_failed") },
      }
    end

    if stageInput.shop and (stageRecord.status ~= "cleared" or runState.runStatus ~= "active") then
      return {
        ok = false,
        error = "unexpected_shop_for_stage",
        mismatches = {
          string.format(
            "Transcript recorded shop for stage %s round %s, but replay stage ended with status=%s runStatus=%s",
            tostring(stageRecord.stageId),
            tostring(stageRecord.roundIndex),
            tostring(stageRecord.status),
            tostring(runState.runStatus)
          ),
        },
      }
    end

    if runState.runStatus ~= "active" then
      break
    end

    if stageRecord.status == "cleared" then
      if stageInput.shop and stageInput.shop.roundIndex and stageInput.shop.roundIndex ~= stageRecord.roundIndex then
        return {
          ok = false,
          error = "shop_round_mismatch",
          mismatches = { string.format("Shop visit expected round %s but replay round is %s", tostring(stageInput.shop.roundIndex), tostring(stageRecord.roundIndex)) },
        }
      end

      if stageInput.shop and stageInput.shop.sourceStageId and stageInput.shop.sourceStageId ~= stageRecord.stageId then
        return {
          ok = false,
          error = "shop_stage_mismatch",
          mismatches = { string.format("Shop visit expected stage %s but replay stage is %s", tostring(stageInput.shop.sourceStageId), tostring(stageRecord.stageId)) },
        }
      end

      local okShop, shopError = replayShopVisit(runState, stageState, stageRecord, metaProjection, rng, stageInput.shop)

      if not okShop then
        return {
          ok = false,
          error = shopError or "shop_replay_failed",
          mismatches = { tostring(shopError or "shop_replay_failed") },
        }
      end

      ProgressionSystem.advanceToNextRound(runState)
    end
  end

  if consumedStageCount < #(normalizedTranscript.stages or {}) then
    return {
      ok = false,
      error = "trailing_transcript_stages",
      mismatches = {
        string.format(
          "Replay consumed %s stages but transcript contained %s",
          tostring(consumedStageCount),
          tostring(#(normalizedTranscript.stages or {}))
        ),
      },
    }
  end

  local actualSignature = buildOutcomeSignature(runState)
  local mismatches = {}
  compareValues("expected", normalizedTranscript.expected or {}, actualSignature, mismatches, 12)
  Validator.assertRuntimeInvariants("replay_system.replayTranscript", runState, nil, { history = true })

  return {
    ok = #mismatches == 0,
    mismatches = mismatches,
    actual = actualSignature,
    expected = normalizedTranscript.expected,
    runState = Utils.clone(runState),
    metaState = Utils.clone(metaState),
    summary = SummarySystem.buildRunSummary(runState, nil),
  }
end

return ReplaySystem
