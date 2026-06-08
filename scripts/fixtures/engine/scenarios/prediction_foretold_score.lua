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

local function opposite(result)
  return result == "heads" and "tails" or "heads"
end

return {
  id = "prediction_foretold_score",
  tags = { "prediction", "replay" },
  description = "Verifies Prediction foretelling, selected-slot propagation, scoped score payoff, and replay tamper checks.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedUpgradeIds = { "see_behind_the_veil", "fulfilled_fate" },
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
    { op = "resolve_batch", call = "tails", label = "first_batch" },
    { op = "resolve_until_stage_end", call = "tails", maxBatches = 4, label = "remaining_batches" },
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
    local resolutionEntries = batch.resolutionEntries or {}
    local foretoldDealt = nil

    for _, entry in ipairs(dealtHand) do
      if entry.foretold == true then
        A.falsy(foretoldDealt, "only one dealt coin should be Foretold")
        foretoldDealt = entry
      end
    end

    foretoldDealt = A.truthy(foretoldDealt, "See Behind the Veil should foretell one dealt coin")
    A.equal(foretoldDealt.foretoldResult, "tails", "seeded Foretold result")
    A.truthy(type(foretoldDealt.foretoldRngRoll) == "number", "Foretold RNG roll should be recorded")

    local selected = A.truthy(findByInstance(selectedSlots, foretoldDealt.instanceId), "Foretold coin should be selected by this fixture seed")
    local resolution = A.truthy(findByInstance(resolutionEntries, foretoldDealt.instanceId), "Foretold coin should resolve")
    local roll = A.truthy(findByInstance(trace.coinRolls, foretoldDealt.instanceId), "Foretold coin roll should be traced")

    A.equal(selected.foretold, true, "selected slot should carry Foretold state")
    A.equal(selected.foretoldResult, foretoldDealt.foretoldResult, "selected Foretold result")
    A.equal(resolution.foretold, true, "resolution entry should carry Foretold state")
    A.equal(resolution.foretoldResult, foretoldDealt.foretoldResult, "resolution Foretold result")
    A.equal(roll.foretold, true, "coin roll should carry Foretold state")
    A.equal(roll.foretoldResult, foretoldDealt.foretoldResult, "coin roll Foretold result")
    A.equal(roll.result, foretoldDealt.foretoldResult, "Foretold result should become the coin result")

    local purseHooks = trace.purseHookHistory or {}
    local foretellAction = nil
    for _, hookTrace in ipairs(purseHooks) do
      for _, action in ipairs(hookTrace.actions or {}) do
        if action.op == "foretell_coin_result" then
          foretellAction = action
          break
        end
      end
    end

    foretellAction = A.truthy(foretellAction, "See Behind the Veil should trace foretell_coin_result")
    A.equal(foretellAction.instanceId, foretoldDealt.instanceId, "Foretell action target instance")
    A.equal(foretellAction.foretoldResult, foretoldDealt.foretoldResult, "Foretell action result metadata")
    A.equal(foretellAction.dealtIndex, foretoldDealt.dealtIndex, "Foretell action dealt index")

    local scopedMultiplier = nil
    for _, multiplier in ipairs(firstBatch.scoreBreakdown and firstBatch.scoreBreakdown.multipliers or {}) do
      if multiplier.scope == "current_coin_score" and multiplier.instanceId == foretoldDealt.instanceId then
        scopedMultiplier = multiplier
        break
      end
    end

    scopedMultiplier = A.truthy(scopedMultiplier, "Fulfilled Fate should apply scoped score multiplier")
    A.equal(scopedMultiplier.value, 2.0, "Fulfilled Fate multiplier value")
    A.traceHasAction(trace, {
      op = "apply_score_multiplier",
      value = 2.0,
      target = "current_coin_score",
      instanceId = foretoldDealt.instanceId,
    }, "Fulfilled Fate should trace current-coin score multiplier")
    A.replayOk(env.replay, "Prediction replay should succeed")

    local resolutionTamper = Utils.clone(env.transcript)
    resolutionTamper.stages[1].batches[1].resolutionEntries[resolution.resolutionIndex].foretoldResult = opposite(foretoldDealt.foretoldResult)
    local resolutionReplay = ReplaySystem.replayTranscript(resolutionTamper)
    A.falsy(resolutionReplay.ok, "tampered Foretold resolution metadata should fail replay")
    A.equal(resolutionReplay.error, "batch_resolution_entries_mismatch", "Foretold resolution tamper error")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].purseHookHistory[1].actions[1].foretoldResult = opposite(foretoldDealt.foretoldResult)
    local actionReplay = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionReplay.ok, "tampered Foretold action metadata should fail replay")
  end,
}
