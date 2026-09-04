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
  id = "prestige_impossible_finale_top_outcomes",
  tags = { "prestige", "replay" },
  description = "Verifies Impossible Finale II replays the two highest-value completed Outcomes.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_hollow_coin" },
        ownedTrickIds = { "steady_hand", "impossible_finale_ii" },
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
    local replays = trace.prestigeReplays or {}

    A.equal(#replays, 2, "Impossible Finale II should replay two Outcomes")
    A.equal(replays[1].packetCoinId, "copper_bent_coin", "Impossible Finale should replay the highest-value Bent Outcome first")
    A.truthy((replays[1].packetFinalScoreContribution or 0) >= (replays[2].packetFinalScoreContribution or 0), "Impossible Finale should order Outcomes by value")
    A.truthy(replays[1].packetId ~= replays[2].packetId, "Impossible Finale should not replay the same Outcome twice")

    local replayAction, actionIndex = findPrestigeAction(trace.actions)
    replayAction = A.truthy(replayAction, "Impossible Finale should trace replay_resolution_packet")
    A.equal(replayAction.selectionMode, "highest_value", "Impossible Finale should use highest-value Outcome selection")
    A.equal(replayAction.count, 2, "Impossible Finale II action count")
    A.equal(replayAction.replayedPacketCount, 2, "Impossible Finale II replay count")
    A.replayOk(env.replay, "Impossible Finale transcript should succeed")

    local replayTamper = Utils.clone(env.transcript)
    replayTamper.expected.batchSignatures[1].prestigeReplays[1].packetId = replays[2].packetId
    local replayResult = ReplaySystem.replayTranscript(replayTamper)
    A.falsy(replayResult.ok, "tampered Impossible Finale replay order should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].selectionMode = "random"
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Impossible Finale action metadata should fail replay")
  end,
}
