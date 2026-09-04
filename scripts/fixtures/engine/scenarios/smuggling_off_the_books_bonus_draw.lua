return {
  id = "smuggling_off_the_books_bonus_draw",
  tags = { "smuggling", "replay" },
  description = "Verifies Off the Books banks +1 draw for the next hand after a flip with smuggling.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        handSize = 3,
        maxFlipSlots = 1,
        starterCollection = {
          "copper_weighted_coin",
          "copper_marked_coin",
          "copper_lucky_coin",
          "copper_hollow_coin",
          "copper_blank_coin",
          "copper_bent_coin",
        },
        ownedTrickIds = { "hidden_in_plain_sight", "off_the_books" },
      },
      initialLoadout = {
        [1] = "copper_weighted_coin",
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "resolve_batch", call = "heads", label = "first_batch" },
    { op = "resolve_batch", call = "heads", label = "second_batch" },
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 6, label = "remaining_batches" },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local secondBatch = A.truthy(A.getResult("second_batch"), "missing second batch")
    local firstTrace = A.truthy(firstBatch.trace, "missing first batch trace")
    local firstDraw = A.truthy(env.stageState.purse.drawHistory[1], "missing first draw history")
    local secondDraw = A.truthy(env.stageState.purse.drawHistory[2], "missing second draw history")

    A.equal(#(firstBatch.batch.boardSlots or {}), 1, "first batch should smuggle one coin")
    A.traceHasAction(firstTrace, {
      op = "add_next_hand_draws",
      amount = 1,
      reason = "off_the_books",
      nextHandBonusDraws = 1,
    }, "Off the Books should bank the next-hand draw")
    A.equal(firstDraw.bonusDrawCount, 0, "first hand should not have a bonus draw yet")
    A.equal(secondDraw.bonusDrawCount, 1, "second hand should consume the Off the Books bonus draw")
    A.equal(#(secondBatch.batch.dealtHand or {}), #(firstBatch.batch.dealtHand or {}) + 1, "second hand should draw one extra coin")
    A.replayOk(env.replay, "Off the Books replay should succeed")
  end,
}
