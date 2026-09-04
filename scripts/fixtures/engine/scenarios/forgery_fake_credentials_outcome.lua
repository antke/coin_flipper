local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

return {
  id = "forgery_fake_credentials_outcome",
  tags = { "forgery", "outcome", "replay" },
  description = "Verifies Fake Credentials III copies the genuine left neighbour's completed Outcome without changing results.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        handSize = 3,
        maxFlipSlots = 3,
        starterCollection = { "copper_weighted_coin", "copper_blank_coin", "copper_bent_coin" },
        ownedTrickIds = { "fake_credentials_iii" },
      },
      initialLoadout = {
        [1] = "copper_weighted_coin",
        [2] = "copper_blank_coin",
        [3] = "copper_bent_coin",
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "queue_forced_results", results = { "heads", "tails", "heads" } },
    { op = "resolve_batch", call = "heads", label = "first_batch" },
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 4 },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local batch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local copies = batch.trace.forgedOutcomeCopies or {}
    local copied = A.truthy(copies[1], "Fake Credentials should copy one Outcome")
    A.equal(#copies, 1, "Fake Credentials copy count")
    A.equal(copied.packetCoinId, "copper_weighted_coin", "copied genuine source")
    A.equal(copied.packetResolutionIndex, 1, "copied left position")
    A.equal(copied.scale, 1.0, "the opening encounter should not apply Enemy Trick pressure")
    A.equal(copied.forgedOutcomeCopy, true, "forged Outcome marker")
    A.equal(batch.perCoin[2].result, "tails", "Forgery Coin should remain a miss")
    A.replayOk(env.replay, "Fake Credentials replay should succeed")

    local tampered = Utils.clone(env.transcript)
    tampered.expected.batchSignatures[1].forgedOutcomeCopies[1].scale = 0.25
    A.falsy(ReplaySystem.replayTranscript(tampered).ok, "tampered copied Outcome should fail replay")
  end,
}
