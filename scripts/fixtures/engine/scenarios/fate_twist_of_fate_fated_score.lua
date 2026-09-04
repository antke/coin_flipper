local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findActionIndex(actions, matcher)
  for index, action in ipairs(actions or {}) do
    local matched = true

    for key, value in pairs(matcher or {}) do
      if action[key] ~= value then
        matched = false
        break
      end
    end

    if matched then
      return index, action
    end
  end

  return nil, nil
end

return {
  id = "fate_twist_of_fate_fated_score",
  tags = { "fate", "replay" },
  description = "Verifies Twist of Fate scales naturally charged Fated Flip score and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 4,
        handSize = 5,
        maxFlipSlots = 5,
        starterCollection = {
          "copper_bent_coin",
          "copper_blank_coin",
          "copper_hollow_coin",
          "copper_marked_coin",
          "copper_lucky_coin",
        },
        ownedTrickIds = { "omen_engine", "fountain_pact_iii", "twist_of_fate" },
      },
      initialLoadout = {
        [1] = "copper_bent_coin",
        [2] = "copper_blank_coin",
        [3] = "copper_hollow_coin",
        [4] = "copper_marked_coin",
        [5] = "copper_lucky_coin",
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "resolve_batch", call = "heads", label = "charging_batch" },
    { op = "resolve_batch", call = "heads", label = "fated_batch" },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local chargingBatch = A.truthy(A.getResult("charging_batch"), "missing charging batch")
    local chargingLuckTrace = A.truthy(chargingBatch.trace and chargingBatch.trace.luck, "missing charging Luck trace")
    A.equal(chargingLuckTrace.after.fatedFlipActive, true, "charging batch should prepare the next Fated Flip")

    local fatedBatch = A.truthy(A.getResult("fated_batch"), "missing Fated Flip batch")
    local trace = A.truthy(fatedBatch.trace, "missing Fated Flip trace")
    local luckTrace = A.truthy(trace.luck, "missing Fated Flip Luck trace")
    local scoreBreakdown = A.truthy(fatedBatch.scoreBreakdown, "missing Fated Flip score breakdown")

    A.equal(luckTrace.wasFatedFlip, true, "batch should consume an active Fated Flip")
    A.equal(scoreBreakdown.preScoreScalingScore, 50, "Fated Flip pre-scaling score")
    A.equal(scoreBreakdown.finalBaseScore, 75, "Twist of Fate should apply 1.5x")
    A.equal(scoreBreakdown.totalStageScoreDelta, 75, "Twist of Fate stage score delta")
    A.contains(scoreBreakdown.scoreScalings, {
      op = "apply_score_scaling",
      value = 1.5,
      reason = "twist_of_fate",
    }, "score breakdown should include Twist of Fate scaling")
    A.traceHasTriggeredSource(trace, {
      phase = "before_scoring",
      sourceId = "twist_of_fate",
      sourceType = "trick",
    }, "Twist of Fate should trigger before scoring")
    A.traceHasAction(trace, {
      op = "apply_score_scaling",
      value = 1.5,
      reason = "twist_of_fate",
    }, "Twist of Fate should trace its score scaling action")

    for _, coinState in ipairs(fatedBatch.perCoin or {}) do
      A.equal(coinState.result, fatedBatch.call, "Fated Flip should force every result to match the call")
    end

    A.replayOk(env.replay, "Twist of Fate replay should succeed")

    local actionTamper = Utils.clone(env.transcript)
    local twistActionIndex = A.truthy(findActionIndex(actionTamper.expected.batchSignatures[2].actions, {
      op = "apply_score_scaling",
      reason = "twist_of_fate",
    }), "expected Twist action signature")
    actionTamper.expected.batchSignatures[2].actions[twistActionIndex].value = 1.25
    local actionReplay = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionReplay.ok, "tampered Twist score scaling should fail replay")
  end,
}
