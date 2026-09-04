local CoinTraits = require("src.core.coin_traits")
local Utils = require("src.core.utils")

local ScoringSystem = {}

local function buildScoreEvent(context, coinState, index, didMatch, includeRootBonuses)
  local resolutionIndex = coinState.resolutionIndex or index
  local scoringCoinId = coinState.scoringCoinId or coinState.forgedCoinId or coinState.coinId
  local didScore = coinState.palmed ~= true and (didMatch or coinState.forgedPayout == true)
  local baseScoreContribution = didScore and CoinTraits.baseScore(scoringCoinId) or 0

  return {
    eventId = string.format("score_%02d", resolutionIndex),
    coinId = coinState.coinId,
    instanceId = coinState.instanceId,
    slotIndex = coinState.slotIndex,
    selectedSlotIndex = coinState.selectedSlotIndex,
    dealtIndex = coinState.dealtIndex,
    boardSlotIndex = coinState.boardSlotIndex,
    overloadSlotIndex = coinState.overloadSlotIndex,
    anchorSelectedSlotIndex = coinState.anchorSelectedSlotIndex,
    anchorInstanceId = coinState.anchorInstanceId,
    anchorCoinId = coinState.anchorCoinId,
    anchorOverloadIndex = coinState.anchorOverloadIndex,
    palmed = coinState.palmed == true,
    sleightSaved = coinState.sleightSaved == true,
    smuggled = coinState.smuggled == true,
    smuggledBy = coinState.smuggledBy,
    contrabandCopy = coinState.contrabandCopy == true,
    copiedFromCoinId = coinState.copiedFromCoinId,
    copiedFromInstanceId = coinState.copiedFromInstanceId,
    chained = coinState.chained == true,
    chainedBy = coinState.chainedBy,
    chainDepth = coinState.chainDepth,
    chainLinkIndex = coinState.chainLinkIndex,
    chainSourceCoinId = coinState.chainSourceCoinId,
    chainSourceInstanceId = coinState.chainSourceInstanceId,
    chainSourceSlotIndex = coinState.chainSourceSlotIndex,
    chainSourceResolutionIndex = coinState.chainSourceResolutionIndex,
    chainRootCoinId = coinState.chainRootCoinId,
    chainRootInstanceId = coinState.chainRootInstanceId,
    resolutionIndex = resolutionIndex,
    result = coinState.result,
    call = context.call,
    matched = didMatch,
    forgedPayout = coinState.forgedPayout == true,
    baseScoreContribution = baseScoreContribution,
    scoreScaling = (tonumber(coinState.scoreScalingMultiplier) or 1.0)
      * (includeRootBonuses and (tonumber(coinState.rootScoreScalingMultiplier) or 1.0) or 1.0),
    multiplier = (tonumber(coinState.scoreScalingMultiplier) or 1.0)
      * (includeRootBonuses and (tonumber(coinState.rootScoreScalingMultiplier) or 1.0) or 1.0),
    scoreBeforeAggregateScaling = didScore and 1 or 0,
    scoreBeforeAggregateMultiplier = didScore and 1 or 0,
    finalScoreContribution = 0,
    baseHeadsWeight = coinState.baseHeadsWeight,
    baseTailsWeight = coinState.baseTailsWeight,
    headsWeight = coinState.headsWeight,
    tailsWeight = coinState.tailsWeight,
    rngRoll = coinState.rngRoll,
    forged = coinState.forged == true,
    forgedBy = coinState.forgedBy,
    forgedCoinId = coinState.forgedCoinId,
    scoringCoinId = scoringCoinId,
    effectiveIdentityIds = Utils.clone(coinState.effectiveIdentityIds or nil),
    identitySourceCoinId = coinState.identitySourceCoinId,
    identitySourceInstanceId = coinState.identitySourceInstanceId,
    sourceCoinIds = Utils.clone(coinState.sourceCoinIds or nil),
    sourceInstanceIds = Utils.clone(coinState.sourceInstanceIds or nil),
    sourceResolutionIndices = Utils.clone(coinState.sourceResolutionIndices or nil),
    forgedIdentity = coinState.forgedIdentity,
    resultSlot = {
      slotIndex = coinState.slotIndex,
      boardSlotIndex = coinState.boardSlotIndex,
      overloadSlotIndex = coinState.overloadSlotIndex,
      anchorSelectedSlotIndex = coinState.anchorSelectedSlotIndex,
      anchorInstanceId = coinState.anchorInstanceId,
      anchorCoinId = coinState.anchorCoinId,
      anchorOverloadIndex = coinState.anchorOverloadIndex,
      palmed = coinState.palmed == true,
      sleightSaved = coinState.sleightSaved == true,
      resolutionIndex = resolutionIndex,
      result = coinState.result,
      call = context.call,
      matched = didMatch,
    },
    coinBody = {
      coinId = coinState.coinId,
      instanceId = coinState.instanceId,
      dealtIndex = coinState.dealtIndex,
      boardSlotIndex = coinState.boardSlotIndex,
      overloadSlotIndex = coinState.overloadSlotIndex,
      anchorSelectedSlotIndex = coinState.anchorSelectedSlotIndex,
      anchorInstanceId = coinState.anchorInstanceId,
      anchorCoinId = coinState.anchorCoinId,
      anchorOverloadIndex = coinState.anchorOverloadIndex,
      palmed = coinState.palmed == true,
      sleightSaved = coinState.sleightSaved == true,
      smuggled = coinState.smuggled == true,
      smuggledBy = coinState.smuggledBy,
      contrabandCopy = coinState.contrabandCopy == true,
      copiedFromCoinId = coinState.copiedFromCoinId,
      copiedFromInstanceId = coinState.copiedFromInstanceId,
      chained = coinState.chained == true,
      chainedBy = coinState.chainedBy,
      chainDepth = coinState.chainDepth,
      chainSourceCoinId = coinState.chainSourceCoinId,
      chainSourceInstanceId = coinState.chainSourceInstanceId,
      forged = coinState.forged == true,
      forgedCoinId = coinState.forgedCoinId,
      scoringCoinId = scoringCoinId,
      effectiveIdentityIds = Utils.clone(coinState.effectiveIdentityIds or nil),
      identitySourceCoinId = coinState.identitySourceCoinId,
      identitySourceInstanceId = coinState.identitySourceInstanceId,
      forgedPayout = coinState.forgedPayout == true,
    },
    scoreCredit = {
      coinId = coinState.coinId,
      instanceId = coinState.instanceId,
      slotIndex = coinState.slotIndex,
      selectedSlotIndex = coinState.selectedSlotIndex,
      dealtIndex = coinState.dealtIndex,
      boardSlotIndex = coinState.boardSlotIndex,
      overloadSlotIndex = coinState.overloadSlotIndex,
      smuggled = coinState.smuggled == true,
      smuggledBy = coinState.smuggledBy,
      contrabandCopy = coinState.contrabandCopy == true,
      copiedFromCoinId = coinState.copiedFromCoinId,
      copiedFromInstanceId = coinState.copiedFromInstanceId,
      chained = coinState.chained == true,
      chainedBy = coinState.chainedBy,
      chainDepth = coinState.chainDepth,
      chainSourceCoinId = coinState.chainSourceCoinId,
      chainSourceInstanceId = coinState.chainSourceInstanceId,
      resolutionIndex = resolutionIndex,
      forged = coinState.forged == true,
      forgedCoinId = coinState.forgedCoinId,
      scoringCoinId = scoringCoinId,
      effectiveIdentityIds = Utils.clone(coinState.effectiveIdentityIds or nil),
      identitySourceCoinId = coinState.identitySourceCoinId,
      identitySourceInstanceId = coinState.identitySourceInstanceId,
      sourceCoinIds = Utils.clone(coinState.sourceCoinIds or nil),
      sourceInstanceIds = Utils.clone(coinState.sourceInstanceIds or nil),
      sourceResolutionIndices = Utils.clone(coinState.sourceResolutionIndices or nil),
      forgedPayout = coinState.forgedPayout == true,
    },
    packetSeed = {
      batchId = context.batchId,
      eventId = string.format("score_%02d", resolutionIndex),
      coinId = coinState.coinId,
      scoringCoinId = scoringCoinId,
      forgedCoinId = coinState.forgedCoinId,
      effectiveIdentityIds = Utils.clone(coinState.effectiveIdentityIds or nil),
      instanceId = coinState.instanceId,
      slotIndex = coinState.slotIndex,
      selectedSlotIndex = coinState.selectedSlotIndex,
      dealtIndex = coinState.dealtIndex,
      boardSlotIndex = coinState.boardSlotIndex,
      overloadSlotIndex = coinState.overloadSlotIndex,
      resolutionIndex = resolutionIndex,
      result = coinState.result,
      call = context.call,
      chained = coinState.chained == true,
      chainDepth = coinState.chainDepth,
      chainSourceCoinId = coinState.chainSourceCoinId,
      chainSourceInstanceId = coinState.chainSourceInstanceId,
      forged = coinState.forged == true,
      forgedPayout = coinState.forgedPayout == true,
      identitySourceCoinId = coinState.identitySourceCoinId,
      identitySourceInstanceId = coinState.identitySourceInstanceId,
    },
  }
end

function ScoringSystem.buildScoreActions(context, options)
  local actions = {}
  local matchCount = 0
  local scoreEvents = {}
  local runCoinScorePhase = options and options.runCoinScorePhase or nil

  context.scoreBreakdown.scoreEvents = context.scoreBreakdown.scoreEvents or {}
  context.scoreBreakdown.resolutionPackets = context.scoreBreakdown.resolutionPackets or {}

  for index, coinState in ipairs(context.perCoin or {}) do
    local didMatch = coinState.result == context.call
    local scoreEvent = buildScoreEvent(context, coinState, index, didMatch, true)

    if runCoinScorePhase then
      runCoinScorePhase("before_coin_score", scoreEvent, coinState)
    end

    scoreEvent.scoreScaling = tonumber(scoreEvent.scoreScaling or scoreEvent.multiplier) or 1.0
    scoreEvent.multiplier = scoreEvent.scoreScaling
    scoreEvent.scoreBeforeAggregateScaling = scoreEvent.baseScoreContribution * scoreEvent.scoreScaling
    scoreEvent.scoreBeforeAggregateMultiplier = scoreEvent.scoreBeforeAggregateScaling

    if runCoinScorePhase then
      runCoinScorePhase("after_coin_score", scoreEvent, coinState)
    end

    table.insert(scoreEvents, scoreEvent)

    if coinState.result == context.call then
      matchCount = matchCount + 1
    end
  end

  local scoreScaling = context.pendingScoreScaling or context.pendingScoreMultiplier or 1.0
  local baseScore = matchCount
  local preScoreScalingScore = 0

  for _, scoreEvent in ipairs(scoreEvents) do
    preScoreScalingScore = preScoreScalingScore + (scoreEvent.scoreBeforeAggregateScaling or scoreEvent.scoreBeforeAggregateMultiplier or 0)
  end

  local finalScore = math.floor(preScoreScalingScore * scoreScaling + 0.00001)
  local coinCount = #(context.perCoin or {})

  context.batchFlags.all_matched = coinCount > 0 and matchCount == coinCount
  context.batchFlags.any_matched = matchCount > 0
  context.batchFlags.no_matches = coinCount > 0 and matchCount == 0

  context.scoreBreakdown.baseScore = baseScore
  context.scoreBreakdown.preScoreScalingScore = preScoreScalingScore
  context.scoreBreakdown.preMultiplierScore = preScoreScalingScore
  context.scoreBreakdown.finalBaseScore = finalScore

  for _, scoreEvent in ipairs(scoreEvents) do
    local eventPreScoreScalingScore = scoreEvent.scoreBeforeAggregateScaling or scoreEvent.scoreBeforeAggregateMultiplier or 0
    scoreEvent.finalScoreContribution = preScoreScalingScore > 0 and (finalScore * eventPreScoreScalingScore / preScoreScalingScore) or 0
    scoreEvent.packetSeed.scoreBeforeAggregateScaling = eventPreScoreScalingScore
    scoreEvent.packetSeed.scoreBeforeAggregateMultiplier = eventPreScoreScalingScore
    scoreEvent.packetSeed.finalScoreContribution = scoreEvent.finalScoreContribution

    table.insert(context.scoreBreakdown.scoreEvents, scoreEvent)
    table.insert(context.scoreBreakdown.perCoin, scoreEvent)
    table.insert(context.scoreBreakdown.resolutionPackets, {
      packetId = string.format("packet_%s", scoreEvent.eventId),
      coinId = scoreEvent.coinId,
      instanceId = scoreEvent.instanceId,
      slotIndex = scoreEvent.slotIndex,
      selectedSlotIndex = scoreEvent.selectedSlotIndex,
      dealtIndex = scoreEvent.dealtIndex,
      boardSlotIndex = scoreEvent.boardSlotIndex,
      overloadSlotIndex = scoreEvent.overloadSlotIndex,
      resolutionIndex = scoreEvent.resolutionIndex,
      result = scoreEvent.result,
      call = scoreEvent.call,
      matched = scoreEvent.matched,
      forged = scoreEvent.forged == true,
      forgedBy = scoreEvent.forgedBy,
      forgedCoinId = scoreEvent.forgedCoinId,
      scoringCoinId = scoreEvent.scoringCoinId,
      effectiveIdentityIds = Utils.clone(scoreEvent.effectiveIdentityIds or nil),
      identitySourceCoinId = scoreEvent.identitySourceCoinId,
      identitySourceInstanceId = scoreEvent.identitySourceInstanceId,
      forgedPayout = scoreEvent.forgedPayout == true,
      baseScoreContribution = scoreEvent.baseScoreContribution,
      scoreBeforeAggregateScaling = eventPreScoreScalingScore,
      scoreBeforeAggregateMultiplier = eventPreScoreScalingScore,
      finalScoreContribution = scoreEvent.finalScoreContribution,
      prestigeReplay = false,
      rootOutcome = true,
      activationKind = "root",
      chained = scoreEvent.chained == true,
      chainDepth = scoreEvent.chainDepth,
      chainSourceCoinId = scoreEvent.chainSourceCoinId,
      chainSourceInstanceId = scoreEvent.chainSourceInstanceId,
      seed = scoreEvent.packetSeed,
      scoreCredit = scoreEvent.scoreCredit,
    })
  end

  if finalScore > 0 then
    table.insert(actions, {
      op = "add_stage_score",
      amount = finalScore,
      category = "base_score",
      label = string.format("Matched coin%s", baseScore == 1 and "" or "s"),
      _trace = {
        phase = "score_assembly",
        sourceId = "base_match_score",
        sourceType = "scoring_system",
      },
    })
  end

  return actions
end

function ScoringSystem.buildCoinActivationScoreActions(context, coinState, activation, options)
  local didMatch = coinState.result == context.call
  local event = buildScoreEvent(context, coinState, coinState.resolutionIndex or 1, didMatch, false)
  event.eventId = string.format("score_%s", activation.activationId)
  event.activationId = activation.activationId
  event.activationKind = activation.kind
  event.chainDepth = activation.chainDepth or 0
  event.packetSeed.eventId = event.eventId
  event.packetSeed.activationId = activation.activationId
  event.packetSeed.activationKind = activation.kind
  event.packetSeed.chainDepth = activation.chainDepth or 0

  if options and options.runCoinScorePhase then
    options.runCoinScorePhase("before_coin_score", event, coinState, activation)
  end
  event.scoreScaling = tonumber(event.scoreScaling or event.multiplier) or 1
  event.multiplier = event.scoreScaling
  event.scoreBeforeAggregateScaling = event.baseScoreContribution * event.scoreScaling
  event.scoreBeforeAggregateMultiplier = event.scoreBeforeAggregateScaling
  if options and options.runCoinScorePhase then
    options.runCoinScorePhase("after_coin_score", event, coinState, activation)
  end

  local finalScore = math.floor(event.scoreBeforeAggregateScaling * (context.pendingScoreScaling or 1) + 0.00001)
  event.finalScoreContribution = finalScore
  event.packetSeed.finalScoreContribution = finalScore
  event.packetSeed.scoreBeforeAggregateScaling = event.scoreBeforeAggregateScaling
  table.insert(context.scoreBreakdown.scoreEvents, event)
  table.insert(context.scoreBreakdown.perCoin, event)
  table.insert(context.scoreBreakdown.resolutionPackets, {
    packetId = string.format("packet_%s", event.eventId),
    coinId = event.coinId,
    instanceId = event.instanceId,
    slotIndex = event.slotIndex,
    selectedSlotIndex = event.selectedSlotIndex,
    resolutionIndex = event.resolutionIndex,
    result = event.result,
    call = event.call,
    matched = event.matched,
    baseScoreContribution = event.baseScoreContribution,
    scoreBeforeAggregateScaling = event.scoreBeforeAggregateScaling,
    finalScoreContribution = finalScore,
    activationId = activation.activationId,
    activationKind = activation.kind,
    rootOutcome = false,
    prestigeReplay = false,
    chainDepth = activation.chainDepth or 0,
    seed = event.packetSeed,
    scoreCredit = event.scoreCredit,
  })

  if finalScore <= 0 then return {} end
  return {
    {
      op = "add_stage_score",
      amount = finalScore,
      category = "reactivation",
      label = "Reactivated Outcome",
      _trace = {
        phase = "reactivation_score",
        sourceId = activation.parentTrickId,
        sourceType = "trick",
        activationId = activation.activationId,
      },
    },
  }
end

return ScoringSystem
