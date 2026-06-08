local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findLuckDelta(deltas, matcher)
  for _, delta in ipairs(deltas or {}) do
    local matched = true

    for key, value in pairs(matcher or {}) do
      if delta[key] ~= value then
        matched = false
        break
      end
    end

    if matched then
      return delta
    end
  end

  return nil
end

return {
  id = "fate_omen_engine_luck_gain",
  tags = { "fate", "replay" },
  description = "Verifies Omen Engine adds bounded Luck progress from a positive Luck gain event and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedUpgradeIds = { "omen_engine" },
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
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local luckTrace = A.truthy(trace.luck, "missing first batch Luck trace")
    local deltas = luckTrace.deltas or {}

    local luckyDelta = A.truthy(findLuckDelta(deltas, {
      amount = 1,
      appliedAmount = 1,
      source = "action",
      reason = "lucky_coin_match",
      positive = true,
    }), "Lucky Coin should create the first positive Luck gain event")

    local omenDelta = A.truthy(findLuckDelta(deltas, {
      amount = 1,
      appliedAmount = 1,
      source = "action",
      reason = "omen_engine",
      positive = true,
    }), "Omen Engine should add exactly one extra Luck")

    A.equal(luckyDelta.eventId, "luck_01", "seeded first Luck event id")
    A.equal(omenDelta.eventId, "luck_02", "Omen Engine Luck event id")
    A.traceHasTriggeredSource(trace, {
      phase = "luck_gain",
      sourceId = "omen_engine",
      sourceType = "run upgrade",
    }, "Omen Engine should trigger from luck_gain")
    A.traceHasAction(trace, {
      op = "add_luck",
      amount = 1,
      reason = "omen_engine",
    }, "Omen Engine should trace its add_luck action")
    A.equal(luckTrace.after.value, 5, "seeded first batch Luck Meter total")
    A.replayOk(env.replay, "Fate replay should succeed")

    local luckTamper = Utils.clone(env.transcript)
    luckTamper.expected.batchSignatures[1].luck.deltas[2].appliedAmount = 0
    local luckReplay = ReplaySystem.replayTranscript(luckTamper)
    A.falsy(luckReplay.ok, "tampered Omen Luck trace should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    local omenActionIndex = nil
    for index, action in ipairs(actionTamper.expected.batchSignatures[1].actions or {}) do
      if action.op == "add_luck" and action.reason == "omen_engine" then
        omenActionIndex = index
        break
      end
    end

    omenActionIndex = A.truthy(omenActionIndex, "expected Omen action signature")
    actionTamper.expected.batchSignatures[1].actions[omenActionIndex].amount = 2
    local actionReplay = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionReplay.ok, "tampered Omen action should fail replay")
  end,
}
