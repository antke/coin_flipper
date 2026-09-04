local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findPrestigeAction(actions)
  for index, action in ipairs(actions or {}) do
    if action.op == "replay_resolution_packet" then
      return action, index
    end
  end

  return nil, nil
end

return {
  id = "prestige_curtain_call_multi_outcome",
  tags = { "prestige", "replay" },
  description = "Verifies Curtain Call II replays two random completed Outcomes without duplicates and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_hollow_coin" },
        ownedTrickIds = { "curtain_call_ii" },
      },
      initialLoadout = {
        [1] = "copper_bent_coin",
        [2] = "copper_blank_coin",
        [3] = "copper_hollow_coin",
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
    local replays = trace.prestigeReplays or {}

    A.equal(#replays, 2, "Curtain Call II should replay two Outcomes")
    A.equal(replays[1].packetCoinId, "copper_bent_coin", "Curtain Call should prefer a Bent Coin Outcome first")
    A.truthy(replays[1].packetId ~= replays[2].packetId, "Curtain Call should not replay the same Outcome twice")
    A.equal(replays[1].scale, 0.2, "Curtain Call replay scale")
    A.equal(replays[2].scale, 0.2, "Curtain Call replay scale")

    local replayAction, actionIndex = findPrestigeAction(trace.actions)
    replayAction = A.truthy(replayAction, "Curtain Call should trace replay_resolution_packet")
    A.equal(replayAction.selectionMode, "random", "Curtain Call should use random Outcome selection")
    A.equal(replayAction.replayedPacketCount, 2, "Curtain Call action replay count")
    A.equal(#(replayAction.packetIds or {}), 2, "Curtain Call action packet id count")
    A.equal(replayAction.replayedScore, replays[1].replayedScore + replays[2].replayedScore, "Curtain Call action total replay score")
    A.equal(breakdown.totalStageScoreDelta, (breakdown.finalBaseScore or 0) + replayAction.replayedScore, "Curtain Call replay should add to batch score delta")
    A.replayOk(env.replay, "Curtain Call transcript should succeed")

    local replayTamper = Utils.clone(env.transcript)
    replayTamper.expected.batchSignatures[1].prestigeReplays[1].packetInstanceId = "tampered_instance"
    local replayResult = ReplaySystem.replayTranscript(replayTamper)
    A.falsy(replayResult.ok, "tampered Curtain Call replay metadata should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].replayedPacketCount = 1
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Curtain Call action metadata should fail replay")
  end,
}
