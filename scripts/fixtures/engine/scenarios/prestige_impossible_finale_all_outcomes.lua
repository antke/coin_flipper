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
  id = "prestige_impossible_finale_all_outcomes",
  tags = { "prestige", "replay" },
  description = "Verifies Impossible Finale III replays every completed Outcome at 75% recorded value.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_hollow_coin" },
        ownedTrickIds = { "impossible_finale_iii" },
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
    local positiveOutcomeCount = 0

    for _, packet in ipairs(breakdown.resolutionPackets or {}) do
      if (packet.finalScoreContribution or 0) > 0 and packet.prestigeReplay ~= true then
        positiveOutcomeCount = positiveOutcomeCount + 1
      end
    end

    local replays = trace.prestigeReplays or {}
    A.equal(#replays, positiveOutcomeCount, "Impossible Finale III should replay every positive Outcome")

    for index, replay in ipairs(replays) do
      A.equal(replay.scale, 0.75, "Impossible Finale III replay scale")
      A.equal(replay.packetResolutionIndex, index, "Impossible Finale III should replay Outcomes in resolution order")
    end

    local replayAction, actionIndex = findPrestigeAction(trace.actions)
    replayAction = A.truthy(replayAction, "Impossible Finale III should trace replay_resolution_packet")
    A.equal(replayAction.selectionMode, "all", "Impossible Finale III should use all Outcome selection")
    A.equal(replayAction.replayedPacketCount, positiveOutcomeCount, "Impossible Finale III replay count")
    A.equal(#(replayAction.replayedScores or {}), positiveOutcomeCount, "Impossible Finale III action replay score count")
    A.replayOk(env.replay, "Impossible Finale III transcript should succeed")

    local replayTamper = Utils.clone(env.transcript)
    replayTamper.expected.batchSignatures[1].prestigeReplays[1].scale = 0.2
    local replayResult = ReplaySystem.replayTranscript(replayTamper)
    A.falsy(replayResult.ok, "tampered Impossible Finale III replay scale should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].replayedPacketCount = positiveOutcomeCount - 1
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Impossible Finale III action metadata should fail replay")
  end,
}
