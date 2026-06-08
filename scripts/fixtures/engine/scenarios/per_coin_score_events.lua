return {
  id = "per_coin_score_events",
  tags = { "score", "replay" },
  description = "Verifies per-coin score events preserve aggregate score and replay metadata.",

  setup = function()
    return {
      runOptions = {
        seed = 5,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
      },
      initialLoadout = {
        [1] = "copper_weighted_coin",
        [2] = "copper_marked_coin",
        [3] = "copper_lucky_coin",
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "resolve_batch", call = "heads", label = "first_batch" },
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 4, label = "remaining_batches" },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local breakdown = A.truthy(firstBatch.scoreBreakdown, "missing score breakdown")
    local scoreEvents = breakdown.scoreEvents or {}
    local perCoin = firstBatch.perCoin or {}

    A.equal(#scoreEvents, #perCoin, "score event count should match resolved coins")
    A.equal(#(breakdown.resolutionPackets or {}), #perCoin, "resolution packet seeds should match resolved coins")

    local matchedCount = 0
    local finalContributionTotal = 0

    for index, coinState in ipairs(perCoin) do
      local scoreEvent = A.truthy(scoreEvents[index], string.format("missing score event %d", index))
      local didMatch = coinState.result == firstBatch.call

      if didMatch then
        matchedCount = matchedCount + 1
      end

      A.equal(scoreEvent.coinId, coinState.coinId, "score event coin id")
      A.equal(scoreEvent.instanceId, coinState.instanceId, "score event instance id")
      A.equal(scoreEvent.resultSlot.result, coinState.result, "score event result slot result")
      A.equal(scoreEvent.resultSlot.call, firstBatch.call, "score event result slot call")
      A.equal(scoreEvent.resultSlot.matched, didMatch, "score event match flag")
      A.equal(scoreEvent.scoreCredit.coinId, coinState.coinId, "score credit coin id")
      A.equal(scoreEvent.packetSeed.eventId, scoreEvent.eventId, "packet seed event id")

      finalContributionTotal = finalContributionTotal + (scoreEvent.finalScoreContribution or 0)
    end

    A.equal(breakdown.baseScore, matchedCount, "base score should equal matched coins")
    A.equal(math.floor(finalContributionTotal + 0.00001), breakdown.finalBaseScore, "score event contributions should total final base score")
    A.equal(breakdown.totalStageScoreDelta, breakdown.finalBaseScore, "ordinary flip aggregate score should be preserved")
    A.replayOk(env.replay, "per-coin score event replay should succeed")
  end,
}
