local Coins = require("src.content.coins")

local ScoringSystem = {}

local function getCoinBaseScore(coinId)
  local definition = Coins.getById(coinId)

  return definition and tonumber(definition.base_score) or 1
end

local function syncScoreCreditFields(scoreEvent, coinState)
  local redirectedCredit = coinState.redirectedCredit == true
  local creditCoinId = redirectedCredit and coinState.scoreCreditCoinId or coinState.coinId
  local creditInstanceId = redirectedCredit and coinState.scoreCreditInstanceId or coinState.instanceId
  local creditSlotIndex = redirectedCredit and coinState.scoreCreditSlotIndex or coinState.slotIndex
  local creditSelectedSlotIndex = redirectedCredit and coinState.scoreCreditSelectedSlotIndex or coinState.selectedSlotIndex
  local creditDealtIndex = redirectedCredit and coinState.scoreCreditDealtIndex or coinState.dealtIndex
  local creditBoardSlotIndex = redirectedCredit and coinState.scoreCreditBoardSlotIndex or coinState.boardSlotIndex
  local creditOverloadSlotIndex = redirectedCredit and coinState.scoreCreditOverloadSlotIndex or coinState.overloadSlotIndex
  local creditResolutionIndex = redirectedCredit and coinState.scoreCreditResolutionIndex or scoreEvent.resolutionIndex

  scoreEvent.spotlight = coinState.spotlight == true
  scoreEvent.spotlightBy = coinState.spotlightBy
  scoreEvent.redirectedCredit = redirectedCredit
  scoreEvent.redirectedCreditBy = coinState.redirectedCreditBy
  scoreEvent.redirectedCreditTargetCoinId = coinState.redirectedCreditTargetCoinId
  scoreEvent.redirectedCreditTargetInstanceId = coinState.redirectedCreditTargetInstanceId
  scoreEvent.redirectedCreditTargetSlotIndex = coinState.redirectedCreditTargetSlotIndex
  scoreEvent.redirectedCreditTargetResolutionIndex = coinState.redirectedCreditTargetResolutionIndex

  scoreEvent.scoreCredit.coinId = creditCoinId
  scoreEvent.scoreCredit.instanceId = creditInstanceId
  scoreEvent.scoreCredit.slotIndex = creditSlotIndex
  scoreEvent.scoreCredit.selectedSlotIndex = creditSelectedSlotIndex
  scoreEvent.scoreCredit.dealtIndex = creditDealtIndex
  scoreEvent.scoreCredit.boardSlotIndex = creditBoardSlotIndex
  scoreEvent.scoreCredit.overloadSlotIndex = creditOverloadSlotIndex
  scoreEvent.scoreCredit.resolutionIndex = creditResolutionIndex
  scoreEvent.scoreCredit.redirectedCredit = redirectedCredit
  scoreEvent.scoreCredit.redirectedCreditBy = coinState.redirectedCreditBy
  scoreEvent.scoreCredit.sourceCoinId = redirectedCredit and coinState.coinId or nil
  scoreEvent.scoreCredit.sourceInstanceId = redirectedCredit and coinState.instanceId or nil
  scoreEvent.scoreCredit.sourceSlotIndex = redirectedCredit and coinState.slotIndex or nil
  scoreEvent.scoreCredit.sourceResolutionIndex = redirectedCredit and scoreEvent.resolutionIndex or nil
  scoreEvent.scoreCredit.spotlightCoinId = coinState.redirectedCreditTargetCoinId
  scoreEvent.scoreCredit.spotlightInstanceId = coinState.redirectedCreditTargetInstanceId
  scoreEvent.scoreCredit.spotlightSlotIndex = coinState.redirectedCreditTargetSlotIndex
  scoreEvent.scoreCredit.spotlightResolutionIndex = coinState.redirectedCreditTargetResolutionIndex

  scoreEvent.packetSeed.scoreCreditCoinId = creditCoinId
  scoreEvent.packetSeed.scoreCreditInstanceId = creditInstanceId
  scoreEvent.packetSeed.scoreCreditSlotIndex = creditSlotIndex
  scoreEvent.packetSeed.scoreCreditResolutionIndex = creditResolutionIndex
  scoreEvent.packetSeed.redirectedCredit = redirectedCredit
end

local function buildScoreEvent(context, coinState, index, didMatch)
  local resolutionIndex = coinState.resolutionIndex or index
  local scoringCoinId = coinState.scoringCoinId or coinState.forgedCoinId or coinState.coinId
  local baseScoreContribution = didMatch and getCoinBaseScore(scoringCoinId) or 0

  return {
    eventId = string.format("score_%02d", resolutionIndex),
    coinId = coinState.coinId,
    instanceId = coinState.instanceId,
    slotIndex = coinState.slotIndex,
    selectedSlotIndex = coinState.selectedSlotIndex,
    dealtIndex = coinState.dealtIndex,
    boardSlotIndex = coinState.boardSlotIndex,
    overloadSlotIndex = coinState.overloadSlotIndex,
    smuggled = coinState.smuggled == true,
    smuggledBy = coinState.smuggledBy,
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
    baseScoreContribution = baseScoreContribution,
    scoreScaling = 1.0,
    multiplier = 1.0,
    scoreBeforeAggregateScaling = didMatch and 1 or 0,
    scoreBeforeAggregateMultiplier = didMatch and 1 or 0,
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
    identitySourceCoinId = coinState.identitySourceCoinId,
    identitySourceInstanceId = coinState.identitySourceInstanceId,
    forgedIdentity = coinState.forgedIdentity,
    resultSlot = {
      slotIndex = coinState.slotIndex,
      boardSlotIndex = coinState.boardSlotIndex,
      overloadSlotIndex = coinState.overloadSlotIndex,
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
      smuggled = coinState.smuggled == true,
      smuggledBy = coinState.smuggledBy,
      chained = coinState.chained == true,
      chainedBy = coinState.chainedBy,
      chainDepth = coinState.chainDepth,
      chainSourceCoinId = coinState.chainSourceCoinId,
      chainSourceInstanceId = coinState.chainSourceInstanceId,
      forged = coinState.forged == true,
      forgedCoinId = coinState.forgedCoinId,
      identitySourceCoinId = coinState.identitySourceCoinId,
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
      chained = coinState.chained == true,
      chainedBy = coinState.chainedBy,
      chainDepth = coinState.chainDepth,
      chainSourceCoinId = coinState.chainSourceCoinId,
      chainSourceInstanceId = coinState.chainSourceInstanceId,
      resolutionIndex = resolutionIndex,
      forged = coinState.forged == true,
      forgedCoinId = coinState.forgedCoinId,
      scoringCoinId = scoringCoinId,
      identitySourceCoinId = coinState.identitySourceCoinId,
      identitySourceInstanceId = coinState.identitySourceInstanceId,
    },
    packetSeed = {
      batchId = context.batchId,
      eventId = string.format("score_%02d", resolutionIndex),
      coinId = coinState.coinId,
      scoringCoinId = scoringCoinId,
      forgedCoinId = coinState.forgedCoinId,
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
    local scoreEvent = buildScoreEvent(context, coinState, index, didMatch)

    if runCoinScorePhase then
      runCoinScorePhase("before_coin_score", scoreEvent, coinState)
    end

    syncScoreCreditFields(scoreEvent, coinState)

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
      baseScoreContribution = scoreEvent.baseScoreContribution,
      scoreBeforeAggregateScaling = eventPreScoreScalingScore,
      scoreBeforeAggregateMultiplier = eventPreScoreScalingScore,
      finalScoreContribution = scoreEvent.finalScoreContribution,
      prestigeReplay = false,
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

return ScoringSystem
