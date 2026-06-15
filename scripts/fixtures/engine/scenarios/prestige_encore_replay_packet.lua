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
  id = "prestige_encore_replay_packet",
  tags = { "prestige", "replay" },
  description = "Verifies Encore replays one completed resolution packet at specialized discounted value and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_hollow_coin" },
        ownedTrickIds = { "encore" },
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
    local replay = A.truthy((trace.prestigeReplays or {})[1], "Encore should record one Prestige replay")

    A.equal(replay.mode, "packet_replay_only", "Encore replay mode")
    A.equal(replay.scope, "no_recursive_prestige", "Encore replay scope")
    A.equal(replay.prestigeReplay, true, "Encore should mark Prestige replay")
    A.equal(replay.packetCoinId, "copper_bent_coin", "Encore should prefer a Bent Coin packet")
    A.equal(replay.packetResolutionIndex, 1, "seeded Encore packet resolution index")
    A.equal(replay.scale, 0.4, "Bent Coin should double Encore replay scale")
    A.equal(replay.replayedScore, 1, "Encore applies a minimum visible discounted score for a positive packet")
    A.equal(breakdown.totalStageScoreDelta, (breakdown.finalBaseScore or 0) + replay.replayedScore, "Prestige replay should add to batch score delta")

    local replayAction, actionIndex = findPrestigeAction(trace.actions)
    replayAction = A.truthy(replayAction, "Encore should trace replay_resolution_packet")
    A.equal(replayAction.packetId, replay.packetId, "Encore action packet id")
    A.equal(replayAction.packetInstanceId, replay.packetInstanceId, "Encore action packet instance")
    A.equal(replayAction.replayedScore, replay.replayedScore, "Encore action replayed score")
    A.equal(replayAction.prestigeReplay, true, "Encore action should be marked as Prestige replay")
    A.traceHasAction(trace, {
      op = "replay_resolution_packet",
      target = {
        zone = "resolution_packets",
        filters = {
          { op = "selected" },
          { op = "positive_score" },
          { op = "not_prestige_replay" },
        },
        prefer = {
          { op = "family", value = "prestige" },
          { op = "archetype", value = "bent" },
        },
        orderBy = "random",
        pick = { op = "slot_at_position", value = 1 },
      },
      packetId = replay.packetId,
      replayedScore = replay.replayedScore,
      prestigeReplay = true,
    }, "Encore action should be traced with replay metadata")
    A.replayOk(env.replay, "Prestige replay transcript should succeed")

    local replayTamper = Utils.clone(env.transcript)
    replayTamper.expected.batchSignatures[1].prestigeReplays[1].packetInstanceId = "tampered_instance"
    local replayResult = ReplaySystem.replayTranscript(replayTamper)
    A.falsy(replayResult.ok, "tampered Prestige replay metadata should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].replayedScore = replay.replayedScore + 1
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Prestige action metadata should fail replay")
  end,
}
