local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function indexById(values)
  local index = {}

  for _, value in ipairs(values or {}) do
    index[value] = true
  end

  return index
end

return {
  id = "deal_select_refill_round_flow",
  tags = { "pouch_zones", "replay" },
  description = "Verifies deal/select/refill pouch zones and replay tamper checks.",

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
    local batch = A.truthy(firstBatch.batch, "missing first batch snapshot")
    local dealtHand = batch.dealtHand or {}
    local selectedSlots = batch.selectedSlots or {}
    local resolutionEntries = batch.resolutionEntries or {}
    local refillEvent = A.truthy(batch.refillEvent, "missing refill event")

    A.truthy(#dealtHand > #selectedSlots, "dealt hand should be larger than legal Flip Slots")
    A.equal(#selectedSlots, env.runState.maxFlipSlots, "selected Flip Slot count")
    A.equal(#resolutionEntries, #selectedSlots, "resolution entries should match selected slots")

    for index, selected in ipairs(selectedSlots) do
      local dealt = A.truthy(dealtHand[index], string.format("missing dealt coin %d", index))
      local resolution = A.truthy(resolutionEntries[index], string.format("missing resolution entry %d", index))

      A.equal(selected.instanceId, dealt.instanceId, "default selection should use dealt order")
      A.equal(selected.dealtIndex, dealt.dealtIndex, "selected dealt index")
      A.equal(selected.selectedSlotIndex, index, "selected slot index")
      A.equal(resolution.instanceId, selected.instanceId, "resolution instance should match selected slot")
      A.equal(resolution.selectedSlotIndex, index, "resolution selected slot index")
      A.equal(resolution.dealtIndex, selected.dealtIndex, "resolution dealt index")
    end

    A.equal(refillEvent.refillRule, "selected_spend_unselected_hold", "refill rule")

    local exhausted = indexById(refillEvent.exhaustedInstanceIds)
    local held = indexById(refillEvent.heldInstanceIds)

    for _, selected in ipairs(selectedSlots) do
      A.truthy(exhausted[selected.instanceId], "selected coins should exhaust")
      A.falsy(held[selected.instanceId], "selected coins should not remain held")
    end

    for index = #selectedSlots + 1, #dealtHand do
      local dealt = dealtHand[index]
      A.truthy(held[dealt.instanceId], "unselected dealt coins should remain held")
      A.falsy(exhausted[dealt.instanceId], "unselected dealt coins should not exhaust")
    end

    A.replayOk(env.replay, "deal/select/refill replay should succeed")

    local dealtTamper = Utils.clone(env.transcript)
    dealtTamper.stages[1].batches[1].dealtHand[1].instanceId = "tampered_dealt_coin"
    local dealtReplay = ReplaySystem.replayTranscript(dealtTamper)
    A.falsy(dealtReplay.ok, "tampered dealt hand should fail replay")
    A.equal(dealtReplay.error, "batch_dealt_hand_mismatch", "dealt tamper error")

    local selectedTamper = Utils.clone(env.transcript)
    selectedTamper.stages[1].batches[1].selectedSlots[1].selectedSlotIndex = 2
    local selectedReplay = ReplaySystem.replayTranscript(selectedTamper)
    A.falsy(selectedReplay.ok, "tampered selected slot should fail replay")
    A.equal(selectedReplay.error, "batch_selected_slots_mismatch", "selected tamper error")

    local refillTamper = Utils.clone(env.transcript)
    refillTamper.stages[1].batches[1].refillEvent.heldInstanceIds[1] = "tampered_held_coin"
    local refillReplay = ReplaySystem.replayTranscript(refillTamper)
    A.falsy(refillReplay.ok, "tampered refill event should fail replay")
    A.equal(refillReplay.error, "batch_refill_event_mismatch", "refill tamper error")
  end,
}
