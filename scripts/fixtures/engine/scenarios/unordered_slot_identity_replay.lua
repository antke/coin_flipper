local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

return {
  id = "unordered_slot_identity_replay",
  tags = { "slot_identity", "unordered", "replay" },
  description = "Locks down unordered resolution with preserved slot metadata and replay enforcement.",

  setup = function()
    return {
      runOptions = {
        seed = 5,
        starterCollection = { "tails_chaser", "match_spark", "heads_hunter" },
      },
      initialLoadout = {
        [1] = "tails_chaser",
        [2] = "match_spark",
        [3] = "heads_hunter",
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
    { op = "build_reward_preview" },
    { op = "claim_reward_choice" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local resolutionEntries = firstBatch.batch.resolutionEntries or {}

    A.equal(resolutionEntries[1].coinId, "heads_hunter", "first resolution entry coin")
    A.equal(resolutionEntries[1].slotIndex, 3, "first resolution entry slot")
    A.equal(resolutionEntries[1].resolutionIndex, 1, "first resolution entry index")
    A.equal(resolutionEntries[2].coinId, "match_spark", "second resolution entry coin")
    A.equal(resolutionEntries[2].slotIndex, 2, "second resolution entry slot")
    A.equal(resolutionEntries[3].coinId, "tails_chaser", "third resolution entry coin")
    A.equal(resolutionEntries[3].slotIndex, 1, "third resolution entry slot")
    A.equal(env.runState.history.loadoutCommits[1].canonicalKey, "heads_hunter|match_spark|tails_chaser", "canonical key remains sorted")
    A.truthy(#(env.transcript.expected.batchSignatures or {}) > 0, "batch signatures should exist")
    A.replayOk(env.replay, "unordered slot replay should succeed")

    local tamperedTranscript = Utils.clone(env.transcript)
    tamperedTranscript.stages[1].batches[1].resolutionEntries[1].slotIndex = 1
    local tamperedReplay = ReplaySystem.replayTranscript(tamperedTranscript)
    A.falsy(tamperedReplay.ok, "tampered slot metadata should fail replay")

    local mismatchText = Utils.joinNonNil(tamperedReplay.mismatches or {}, " | ")
    local signalText = string.format("%s | %s", tostring(tamperedReplay.error), mismatchText)
    A.truthy(signalText:find("resolution", 1, true) or signalText:find("slot", 1, true), "tampered replay should mention slot/resolution mismatch")
  end,
}
