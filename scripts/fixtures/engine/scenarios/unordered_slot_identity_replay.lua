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
    local resolutionEntries = firstBatch.batch.resolutionEntries or {}
    local selectedSlots = firstBatch.batch.selectedSlots or {}

    for index, selected in ipairs(selectedSlots) do
      local resolution = A.truthy(resolutionEntries[index], string.format("missing resolution entry %d", index))
      A.equal(resolution.coinId, selected.coinId, string.format("resolution entry %d coin", index))
      A.equal(resolution.instanceId, selected.instanceId, string.format("resolution entry %d instance", index))
      A.equal(resolution.slotIndex, index, string.format("resolution entry %d slot", index))
      A.equal(resolution.resolutionIndex, index, string.format("resolution entry %d index", index))
    end

    A.equal(#resolutionEntries, 3, "only selected Flip Slots should resolve")
    A.equal(env.runState.history.loadoutCommits[1].canonicalKey, "copper_lucky_coin|copper_marked_coin|copper_weighted_coin", "canonical key remains sorted")
    A.truthy(#(env.transcript.expected.batchSignatures or {}) > 0, "batch signatures should exist")
    A.replayOk(env.replay, "unordered slot replay should succeed")

    local tamperedTranscript = Utils.clone(env.transcript)
    tamperedTranscript.stages[1].batches[1].resolutionEntries[1].slotIndex = 2
    local tamperedReplay = ReplaySystem.replayTranscript(tamperedTranscript)
    A.falsy(tamperedReplay.ok, "tampered slot metadata should fail replay")

    local mismatchText = Utils.joinNonNil(tamperedReplay.mismatches or {}, " | ")
    local signalText = string.format("%s | %s", tostring(tamperedReplay.error), mismatchText)
    A.truthy(signalText:find("resolution", 1, true) or signalText:find("slot", 1, true), "tampered replay should mention slot/resolution mismatch")
  end,
}
