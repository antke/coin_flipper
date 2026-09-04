local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

return {
  id = "smuggling_sleight_body_exclusivity",
  tags = { "smuggling", "sleight", "replay" },
  description = "Verifies False Bottom cannot reuse a Vanishing Coin already moved onto the board by Smuggling.",

  setup = function()
    return {
      runOptions = {
        seed = 4,
        starterCollection = {
          "copper_blank_coin",
          "copper_marked_coin",
          "copper_lucky_coin",
          "copper_vanishing_coin",
        },
        ownedTrickIds = { "hidden_in_plain_sight", "false_bottom" },
      },
      initialLoadout = {
        [1] = "copper_blank_coin",
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
    local smuggledMove = A.truthy((trace.smugglingMoves or {})[1], "Hidden in Plain Sight should smuggle a coin")

    A.equal(smuggledMove.coinId, "copper_vanishing_coin", "fixture should smuggle the unselected Vanishing Coin")
    A.equal(#(trace.sleightMoves or {}), 0, "False Bottom should not reuse a body already present on the board")

    local seenInstances = {}
    for _, coinState in ipairs(firstBatch.perCoin or {}) do
      A.falsy(seenInstances[coinState.instanceId], "resolved board should not duplicate instance " .. tostring(coinState.instanceId))
      seenInstances[coinState.instanceId] = true
    end

    A.replayOk(env.replay, "Smuggling/Sleight body exclusivity replay should succeed")

    local tamperedTranscript = Utils.clone(env.transcript)
    local firstSignature = tamperedTranscript.expected.batchSignatures[1]
    firstSignature.smugglingMoves[1].instanceId = firstSignature.selectedSlots[1].instanceId
    local tamperedReplay = ReplaySystem.replayTranscript(tamperedTranscript)
    A.falsy(tamperedReplay.ok, "tampered Smuggling body identity should fail replay")
  end,
}
