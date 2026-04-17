local ScoringSystem = {}

function ScoringSystem.buildScoreActions(context)
  local actions = {}
  local matchCount = 0

  for _, coinState in ipairs(context.perCoin or {}) do
    local didMatch = coinState.result == context.call

    table.insert(context.scoreBreakdown.perCoin, {
      coinId = coinState.coinId,
      result = coinState.result,
      call = context.call,
      matched = didMatch,
      baseScoreContribution = didMatch and 1 or 0,
      headsWeight = coinState.headsWeight,
      tailsWeight = coinState.tailsWeight,
      rngRoll = coinState.rngRoll,
    })

    if coinState.result == context.call then
      matchCount = matchCount + 1
    end
  end

  local multiplier = context.pendingScoreMultiplier or 1.0
  local baseScore = matchCount
  local finalScore = math.floor(baseScore * multiplier + 0.00001)
  local coinCount = #(context.perCoin or {})

  context.batchFlags.all_matched = coinCount > 0 and matchCount == coinCount
  context.batchFlags.any_matched = matchCount > 0
  context.batchFlags.no_matches = coinCount > 0 and matchCount == 0

  context.scoreBreakdown.baseScore = baseScore
  context.scoreBreakdown.preMultiplierScore = baseScore
  context.scoreBreakdown.finalBaseScore = finalScore

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
    table.insert(actions, {
      op = "add_run_score",
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
