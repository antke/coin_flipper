local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

return {
  id = "sleight_switcheroo_swap",
  tags = { "sleight", "replay" },
  description = "Verifies Switcheroo swaps coin bodies through resolved result slots and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 2,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedTrickIds = { "switcheroo" },
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
    local batch = A.truthy(firstBatch.batch, "missing first batch snapshot")
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local selectedSlots = batch.selectedSlots or {}
    local resolutionEntries = batch.resolutionEntries or {}
    local coinRolls = trace.coinRolls or {}
    local scoreEvents = firstBatch.scoreBreakdown and firstBatch.scoreBreakdown.scoreEvents or {}

    local move = A.truthy((trace.sleightMoves or {})[1], "Switcheroo should record one sleight move")
    A.equal(move.op, "swap_coins", "Switcheroo move op")
    A.truthy(move.failedSlotIndex ~= move.successSlotIndex, "Switcheroo should swap different slots")
    A.truthy(move.failedSlotIndex >= 1 and move.failedSlotIndex <= #selectedSlots, "failed slot should be selected")
    A.truthy(move.successSlotIndex >= 1 and move.successSlotIndex <= #selectedSlots, "success slot should be selected")

    A.equal(selectedSlots[move.successSlotIndex].instanceId, move.successInstanceId, "selected success slot starts with success body")
    A.equal(selectedSlots[move.failedSlotIndex].instanceId, move.failedInstanceId, "selected failed slot starts with failed body")
    A.equal(resolutionEntries[move.successResolutionIndex].instanceId, move.failedInstanceId, "failed body should move into success result slot")
    A.equal(resolutionEntries[move.failedResolutionIndex].instanceId, move.successInstanceId, "success body should move into failed result slot")

    A.equal(coinRolls[move.successResolutionIndex].instanceId, move.failedInstanceId, "coin roll success slot body after swap")
    A.equal(coinRolls[move.successResolutionIndex].result, "heads", "success result slot should preserve result")
    A.equal(coinRolls[move.failedResolutionIndex].instanceId, move.successInstanceId, "coin roll failed slot body after swap")
    A.equal(coinRolls[move.failedResolutionIndex].result, "tails", "failed result slot should preserve result")

    A.equal(scoreEvents[move.successResolutionIndex].instanceId, move.failedInstanceId, "score event should credit swapped-in failed body")
    A.equal(scoreEvents[move.successResolutionIndex].matched, true, "swapped-in failed body should score in success slot")
    A.equal(scoreEvents[move.failedResolutionIndex].instanceId, move.successInstanceId, "score event should move success body out")
    A.equal(scoreEvents[move.failedResolutionIndex].matched, false, "moved-out success body should inherit failed slot result")

    A.traceHasAction(trace, {
      op = "swap_coins",
      target = "switcheroo_failed_success",
      failedInstanceId = move.failedInstanceId,
      successInstanceId = move.successInstanceId,
    }, "Switcheroo action should be traced with swap metadata")
    A.replayOk(env.replay, "Sleight replay should succeed")

    local resolutionTamper = Utils.clone(env.transcript)
    resolutionTamper.stages[1].batches[1].resolutionEntries[move.successResolutionIndex].instanceId = move.successInstanceId
    local resolutionReplay = ReplaySystem.replayTranscript(resolutionTamper)
    A.falsy(resolutionReplay.ok, "tampered Switcheroo resolution metadata should fail replay")

    local moveTamper = Utils.clone(env.transcript)
    moveTamper.expected.batchSignatures[1].sleightMoves[1].failedInstanceId = move.successInstanceId
    local moveReplay = ReplaySystem.replayTranscript(moveTamper)
    A.falsy(moveReplay.ok, "tampered Switcheroo move metadata should fail replay")
  end,
}
