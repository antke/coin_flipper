local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findChainAction(actions)
  for index, action in ipairs(actions or {}) do
    if action.op == "trigger_random_neighbor" then
      return action, index
    end
  end

  return nil, nil
end

return {
  id = "momentum_keep_it_rolling_propagation",
  tags = { "momentum", "replay" },
  description = "Verifies Keep It Rolling creates capped Momentum links with source metadata and replay checks.",

  setup = function()
    return {
      runOptions = {
        seed = 6,
        starterCollection = { "copper_weighted_coin", "copper_flywheel_coin", "copper_lucky_coin" },
        ownedTrickIds = { "keep_it_rolling", "follow_through" },
      },
      initialLoadout = {
        [1] = "copper_weighted_coin",
        [2] = "copper_flywheel_coin",
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
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local breakdown = A.truthy(firstBatch.scoreBreakdown, "missing first batch score breakdown")
    local momentumLink = A.truthy((trace.chainLinks or {})[1], "Keep It Rolling should record one Momentum link")

    A.equal(momentumLink.sourceResolutionIndex, 1, "seeded Momentum source resolution index")
    A.equal(momentumLink.targetResolutionIndex, 2, "seeded Momentum target resolution index")
    A.equal(momentumLink.chainDepth, 1, "first Momentum link depth")
    A.equal(momentumLink.chainChance, 0.5, "Keep It Rolling Momentum chance")
    A.equal(momentumLink.chained, true, "Momentum link should mark target In Motion")
    A.equal(momentumLink.triggeredScore, 12, "Follow Through should make the triggered base-10 coin score at 1.25x")
    A.equal(momentumLink.triggeredScoreMultiplier, 1.25, "first Momentum link trigger multiplier")

    local targetScoreEvent = A.truthy((breakdown.scoreEvents or {})[momentumLink.targetResolutionIndex], "missing In Motion target score event")
    A.equal(targetScoreEvent.chained, true, "target score event should carry In Motion flag")
    A.equal(targetScoreEvent.chainDepth, momentumLink.chainDepth, "target score event Momentum depth")
    A.equal(targetScoreEvent.chainSourceInstanceId, momentumLink.sourceInstanceId, "target score event Momentum source")

    if targetScoreEvent.matched == true then
      A.equal(targetScoreEvent.scoreScaling, 1.0, "Momentum trigger score is added separately from the coin's original score")
    end

    local targetRoll = A.truthy((trace.coinRolls or {})[momentumLink.targetResolutionIndex], "missing In Motion target coin roll")
    A.equal(targetRoll.chained, true, "target coin roll should carry In Motion flag")
    A.equal(targetRoll.chainSourceInstanceId, momentumLink.sourceInstanceId, "target coin roll Momentum source")

    local chainAction, actionIndex = findChainAction(trace.actions)
    chainAction = A.truthy(chainAction, "Keep It Rolling should trace trigger_random_neighbor")
    A.equal(chainAction.chainTriggered, true, "Keep It Rolling action should mark a Momentum trigger")
    A.equal(chainAction.chainLinkCount, #(trace.chainLinks or {}), "Keep It Rolling action link count")
    A.equal(chainAction.chainedInstanceId, momentumLink.targetInstanceId, "Keep It Rolling action target instance")
    A.traceHasAction(trace, {
      op = "trigger_random_neighbor",
      target = {
        zone = "selected_coins",
        filters = {
          { op = "neighbor_of_current" },
          { op = "not_used_resolution_index" },
        },
        prefer = {
          { op = "family", value = "momentum" },
        },
        orderBy = "material_rank_desc",
        pick = { op = "slot_at_position", value = 1 },
      },
      chainTriggered = true,
      chainedInstanceId = momentumLink.targetInstanceId,
    }, "Keep It Rolling action should be traced with Momentum metadata")
    A.contains(breakdown.additiveBonuses or {}, {
      amount = 12,
      category = "momentum",
      label = "Momentum trigger",
    }, "Keep It Rolling should add a deferred Momentum score")
    A.replayOk(env.replay, "Momentum transcript should succeed")

    local chainTamper = Utils.clone(env.transcript)
    chainTamper.expected.batchSignatures[1].chainLinks[1].targetInstanceId = "tampered_instance"
    local chainResult = ReplaySystem.replayTranscript(chainTamper)
    A.falsy(chainResult.ok, "tampered Momentum link metadata should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].chainLinkCount = chainAction.chainLinkCount + 1
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Momentum action metadata should fail replay")
  end,
}
