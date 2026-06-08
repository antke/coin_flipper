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
  id = "chain_domino_line_propagation",
  tags = { "chain", "replay" },
  description = "Verifies Domino Line creates capped Chain links with source/depth metadata and replay checks.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedUpgradeIds = { "domino_line" },
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
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local breakdown = A.truthy(firstBatch.scoreBreakdown, "missing first batch score breakdown")
    local chainLink = A.truthy((trace.chainLinks or {})[1], "Domino Line should record one Chain link")

    A.equal(chainLink.sourceResolutionIndex, 1, "seeded Chain source resolution index")
    A.equal(chainLink.targetResolutionIndex, 2, "seeded Chain target resolution index")
    A.equal(chainLink.chainDepth, 1, "first Chain link depth")
    A.equal(chainLink.chainChance, 0.5, "Domino Line chain chance")
    A.equal(chainLink.chained, true, "Chain link should mark target Chained")

    local targetScoreEvent = A.truthy((breakdown.scoreEvents or {})[chainLink.targetResolutionIndex], "missing chained target score event")
    A.equal(targetScoreEvent.chained, true, "target score event should carry Chained flag")
    A.equal(targetScoreEvent.chainDepth, chainLink.chainDepth, "target score event Chain depth")
    A.equal(targetScoreEvent.chainSourceInstanceId, chainLink.sourceInstanceId, "target score event Chain source")

    local targetRoll = A.truthy((trace.coinRolls or {})[chainLink.targetResolutionIndex], "missing chained target coin roll")
    A.equal(targetRoll.chained, true, "target coin roll should carry Chained flag")
    A.equal(targetRoll.chainSourceInstanceId, chainLink.sourceInstanceId, "target coin roll Chain source")

    local chainAction, actionIndex = findChainAction(trace.actions)
    chainAction = A.truthy(chainAction, "Domino Line should trace trigger_random_neighbor")
    A.equal(chainAction.chainTriggered, true, "Domino Line action should mark a Chain trigger")
    A.equal(chainAction.chainLinkCount, #(trace.chainLinks or {}), "Domino Line action link count")
    A.equal(chainAction.chainedInstanceId, chainLink.targetInstanceId, "Domino Line action target instance")
    A.traceHasAction(trace, {
      op = "trigger_random_neighbor",
      target = "random_neighbor",
      chainTriggered = true,
      chainedInstanceId = chainLink.targetInstanceId,
    }, "Domino Line action should be traced with Chain metadata")
    A.replayOk(env.replay, "Chain transcript should succeed")

    local chainTamper = Utils.clone(env.transcript)
    chainTamper.expected.batchSignatures[1].chainLinks[1].targetInstanceId = "tampered_instance"
    local chainResult = ReplaySystem.replayTranscript(chainTamper)
    A.falsy(chainResult.ok, "tampered Chain link metadata should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].chainLinkCount = chainAction.chainLinkCount + 1
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Chain action metadata should fail replay")
  end,
}
