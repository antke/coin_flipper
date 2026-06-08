local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findByInstance(entries, instanceId)
  for _, entry in ipairs(entries or {}) do
    if entry.instanceId == instanceId then
      return entry
    end
  end

  return nil
end

local function findForgeAction(actions)
  for index, action in ipairs(actions or {}) do
    if action.op == "forge_identity" then
      return action, index
    end
  end

  return nil, nil
end

return {
  id = "forgery_borrowed_name_identity",
  tags = { "forgery", "replay" },
  description = "Verifies Borrowed Name applies a one-payout forged identity overlay and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 2,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedUpgradeIds = { "borrowed_name" },
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
    local resolutionEntries = batch.resolutionEntries or {}
    local scoreEvents = firstBatch.scoreBreakdown and firstBatch.scoreBreakdown.scoreEvents or {}
    local forged = A.truthy((trace.forgedIdentities or {})[1], "Borrowed Name should record one forged identity")

    A.equal(forged.mode, "replace_identity", "Borrowed Name forge mode")
    A.equal(forged.scope, "one_payout_only", "Borrowed Name forge scope")
    A.equal(forged.sourceResolutionIndex, 1, "slot 1 should be the identity source")
    A.equal(forged.sourceCoinId, "copper_weighted_coin", "seeded slot 1 source coin")
    A.equal(forged.targetResolutionIndex, 3, "seeded failed target slot")
    A.equal(forged.forgedCoinId, forged.sourceCoinId, "target should borrow source identity")

    local targetEntry = A.truthy(findByInstance(resolutionEntries, forged.targetInstanceId), "forged target should resolve")
    A.equal(targetEntry.coinId, forged.targetCoinId, "resolution keeps real target identity")
    A.equal(targetEntry.coinId, "copper_marked_coin", "seeded real target coin")

    local scoreEvent = A.truthy(scoreEvents[forged.targetResolutionIndex], "forged target should have a score event")
    A.equal(scoreEvent.instanceId, forged.targetInstanceId, "score event target instance")
    A.equal(scoreEvent.forged, true, "score event should carry forged flag")
    A.equal(scoreEvent.forgedCoinId, forged.sourceCoinId, "score event forged identity")
    A.equal(scoreEvent.scoringCoinId, forged.sourceCoinId, "score event scoring identity")
    A.equal(scoreEvent.coinId, forged.targetCoinId, "score event keeps real coin body")
    A.equal(scoreEvent.matched, false, "Borrowed Name should not change the result")

    local roll = A.truthy((trace.coinRolls or {})[forged.targetResolutionIndex], "forged target roll should be traced")
    A.equal(roll.forged, true, "coin roll trace should carry forged flag")
    A.equal(roll.forgedCoinId, forged.sourceCoinId, "coin roll forged identity")

    local forgeAction, actionIndex = findForgeAction(trace.actions)
    forgeAction = A.truthy(forgeAction, "Borrowed Name should trace forge_identity")
    A.equal(forgeAction.targetInstanceId, forged.targetInstanceId, "forge action target instance")
    A.equal(forgeAction.sourceInstanceId, forged.sourceInstanceId, "forge action source instance")
    A.equal(forgeAction.forgedCoinId, forged.sourceCoinId, "forge action source identity")
    A.traceHasAction(trace, {
      op = "forge_identity",
      target = "slot_1_to_lowest_failed_selected_coin",
      targetInstanceId = forged.targetInstanceId,
      forgedCoinId = forged.sourceCoinId,
    }, "Borrowed Name action should be traced with forged metadata")
    A.replayOk(env.replay, "Forgery replay should succeed")

    local forgedTamper = Utils.clone(env.transcript)
    forgedTamper.expected.batchSignatures[1].forgedIdentities[1].targetInstanceId = forged.sourceInstanceId
    local forgedReplay = ReplaySystem.replayTranscript(forgedTamper)
    A.falsy(forgedReplay.ok, "tampered forged identity metadata should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].forgedCoinId = forged.targetCoinId
    local actionReplay = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionReplay.ok, "tampered forge action metadata should fail replay")
  end,
}
