local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

return {
  id = "forgery_hybrid_activations",
  tags = { "forgery", "activation", "prestige", "replay" },
  description = "Verifies Borrowed Name III and Forged Signature III enhance the genuine family immediately left with bounded activations.",

  setup = function()
    return {
      runOptions = {
        seed = 131,
        handSize = 3,
        maxFlipSlots = 3,
        starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin" },
        ownedTrickIds = {
          "encore",
          "curtain_call_ii",
          "impossible_finale_iii",
          "borrowed_name_iii",
          "forged_signature_iii",
        },
      },
      initialLoadout = {
        [1] = "copper_bent_coin",
        [2] = "copper_blank_coin",
        [3] = "copper_weighted_coin",
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "queue_forced_results", results = { "heads", "heads", "heads" } },
    { op = "resolve_batch", call = "heads", selectedDealtIndexes = { 1, 3, 2 }, label = "first_batch" },
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 4 },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local batch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local activations = batch.trace.forgedActivations or {}
    local borrowed = 0
    local signatures = 0
    local signatureTarget
    for _, activation in ipairs(activations) do
      A.equal(activation.family, "prestige", "forged family")
      A.equal(activation.coinId, "copper_blank_coin", "Forgery activation body")
      A.equal(activation.genuineSourceCoinId, "copper_bent_coin", "genuine left source")
      A.equal(activation.chainDepth, 1, "forged depth")
      if activation.kind == "borrowed_name" then
        borrowed = borrowed + 1
      elseif activation.kind == "forged_signature" then
        signatures = signatures + 1
        signatureTarget = activation.trickId
      end
    end
    A.equal(borrowed, 3, "Borrowed Name III activation count")
    A.equal(signatures, 1, "Forged Signature activation count")
    A.equal(signatureTarget, "impossible_finale_iii", "Signature III target")
    A.equal(#activations, 4, "bounded forged activation count")
    local assignment = A.truthy((batch.trace.forgeryAssignments or {})[1], "locked Forgery assignment")
    A.equal(assignment.direction, "left", "Forgery direction")
    A.equal(assignment.sourceFamily, "prestige", "locked source family")
    A.equal(assignment.actingFamily, "prestige", "acting family")
    A.replayOk(env.replay, "Forgery hybrid replay should succeed")

    local tampered = Utils.clone(env.transcript)
    tampered.expected.batchSignatures[1].forgedActivations[4].trickId = "encore"
    A.falsy(ReplaySystem.replayTranscript(tampered).ok, "tampered forged target should fail replay")

    local assignmentTamper = Utils.clone(env.transcript)
    assignmentTamper.expected.batchSignatures[1].forgeryAssignments[1].sourceFamily = "weighted"
    A.falsy(ReplaySystem.replayTranscript(assignmentTamper).ok, "tampered Forgery assignment should fail replay")
  end,
}
