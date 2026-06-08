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
  id = "smuggling_sleeve_pocket_overload",
  tags = { "smuggling", "replay" },
  description = "Verifies Sleeve Pocket smuggles a real unselected dealt coin into an overload slot and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 8,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin", "copper_hollow_coin" },
        ownedUpgradeIds = { "sleeve_pocket" },
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
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 6, label = "remaining_batches" },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local batch = A.truthy(firstBatch.batch, "missing first batch snapshot")
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local dealtHand = batch.dealtHand or {}
    local selectedSlots = batch.selectedSlots or {}
    local boardSlots = batch.boardSlots or {}
    local resolutionEntries = batch.resolutionEntries or {}
    local refillEvent = A.truthy(batch.refillEvent, "missing refill event")
    local scoreEvents = firstBatch.scoreBreakdown and firstBatch.scoreBreakdown.scoreEvents or {}

    A.equal(#boardSlots, 1, "Sleeve Pocket should create one overload board slot")
    A.equal(#resolutionEntries, #selectedSlots + 1, "overload slot should resolve after selected Flip Slots")

    local board = A.truthy(boardSlots[1], "missing overload board slot")
    A.equal(board.coinId, "copper_hollow_coin", "Sleeve Pocket should prefer an unselected Hollow Coin")
    A.equal(board.smuggled, true, "board slot should be marked smuggled")
    A.equal(board.overloadSlotIndex, 1, "overload slot index")
    A.equal(board.boardSlotIndex, #selectedSlots + 1, "board slot index should follow legal Flip Slots")
    A.equal(board.selectedSlotIndex, nil, "smuggled coin should be outside legal selected slots")

    local dealt = A.truthy(dealtHand[board.dealtIndex], "missing dealt source for smuggled coin")
    A.equal(dealt.instanceId, board.instanceId, "board slot should use a real dealt coin body")
    A.equal(dealt.selectedSlotIndex, nil, "smuggled source should be unselected")
    A.equal(dealt.smuggled, true, "dealt source should carry smuggled metadata")

    local resolution = A.truthy(resolutionEntries[#resolutionEntries], "missing smuggled resolution entry")
    A.equal(resolution.instanceId, board.instanceId, "smuggled resolution should match board body")
    A.equal(resolution.boardSlotIndex, board.boardSlotIndex, "resolution board slot index")
    A.equal(resolution.overloadSlotIndex, board.overloadSlotIndex, "resolution overload slot index")
    A.equal(resolution.smuggled, true, "resolution should be marked smuggled")

    local coinRoll = A.truthy((trace.coinRolls or {})[resolution.resolutionIndex], "missing smuggled coin roll")
    A.equal(coinRoll.instanceId, board.instanceId, "coin roll should use smuggled body")
    A.equal(coinRoll.boardSlotIndex, board.boardSlotIndex, "coin roll board slot index")
    A.equal(coinRoll.overloadSlotIndex, board.overloadSlotIndex, "coin roll overload slot index")
    A.equal(coinRoll.smuggled, true, "coin roll should be marked smuggled")

    local scoreEvent = A.truthy(scoreEvents[resolution.resolutionIndex], "missing smuggled score event")
    A.equal(scoreEvent.instanceId, board.instanceId, "score event should credit smuggled body")
    A.equal(scoreEvent.boardSlotIndex, board.boardSlotIndex, "score event board slot index")
    A.equal(scoreEvent.overloadSlotIndex, board.overloadSlotIndex, "score event overload slot index")
    A.equal(scoreEvent.smuggled, true, "score event should be marked smuggled")

    local exhausted = indexById(refillEvent.exhaustedInstanceIds)
    local returned = indexById(refillEvent.returnedInstanceIds)
    local smuggled = indexById(refillEvent.smuggledInstanceIds)
    A.truthy(exhausted[board.instanceId], "smuggled real coin should exhaust after resolving")
    A.truthy(smuggled[board.instanceId], "refill event should list smuggled instance")
    A.falsy(returned[board.instanceId], "smuggled coin should not return as unselected dealt")
    A.equal(refillEvent.boardSlotCount, 1, "refill should record board slot count")

    local move = A.truthy((trace.smugglingMoves or {})[1], "Sleeve Pocket should record a smuggling move")
    A.equal(move.op, "smuggle_coin_from_hand", "smuggling move op")
    A.equal(move.instanceId, board.instanceId, "smuggling move instance")
    A.equal(move.boardSlotIndex, board.boardSlotIndex, "smuggling move board slot")
    A.traceHasAction(trace, {
      op = "smuggle_coin_from_hand",
      target = "hollow_or_leftmost_unselected_hand_coin",
      smuggledInstanceId = board.instanceId,
      boardSlotIndex = board.boardSlotIndex,
      overloadSlotIndex = board.overloadSlotIndex,
    }, "Sleeve Pocket action should be traced with smuggling metadata")

    A.replayOk(env.replay, "Smuggling replay should succeed")

    local boardTamper = Utils.clone(env.transcript)
    boardTamper.stages[1].batches[1].boardSlots[1].instanceId = selectedSlots[1].instanceId
    local boardReplay = ReplaySystem.replayTranscript(boardTamper)
    A.falsy(boardReplay.ok, "tampered board slot should fail replay")
    A.equal(boardReplay.error, "batch_board_slots_mismatch", "board tamper error")

    local moveTamper = Utils.clone(env.transcript)
    moveTamper.expected.batchSignatures[1].smugglingMoves[1].instanceId = selectedSlots[1].instanceId
    local moveReplay = ReplaySystem.replayTranscript(moveTamper)
    A.falsy(moveReplay.ok, "tampered smuggling move should fail replay")
  end,
}
