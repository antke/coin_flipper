local EffectiveValueSystem = require("src.systems.effective_value_system")
local MetaState = require("src.domain.meta_state")
local ReplaySystem = require("src.systems.replay_system")
local RunInitializer = require("src.systems.run_initializer")
local Utils = require("src.core.utils")

local function findLuckDeltaIndex(deltas, matcher)
  for index, delta in ipairs(deltas or {}) do
    local matched = true

    for key, value in pairs(matcher or {}) do
      if delta[key] ~= value then
        matched = false
        break
      end
    end

    if matched then
      return index, delta
    end
  end

  return nil, nil
end

local function getMultiplierForTricks(ownedTrickIds)
  local runState, metaProjection = RunInitializer.createNewRun(MetaState.new({}), {
    seed = 1,
    ownedTrickIds = ownedTrickIds,
  })

  return EffectiveValueSystem.getEffectiveValue("luck.generationMultiplier", runState, nil, {
    metaProjection = metaProjection,
  })
end

return {
  id = "fate_fountain_pact_luck_multiplier",
  tags = { "fate", "replay" },
  description = "Verifies Fountain Pact globally multiplies positive Luck generation and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedTrickIds = { "fountain_pact_iii" },
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
    A.equal(getMultiplierForTricks({ "fountain_pact" }), 1.5, "Fountain Pact I multiplier")
    A.equal(getMultiplierForTricks({ "fountain_pact_ii" }), 1.75, "Fountain Pact II multiplier")
    A.equal(getMultiplierForTricks({ "fountain_pact_iii" }), 2.0, "Fountain Pact III multiplier")
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local luckTrace = A.truthy(trace.luck, "missing first batch Luck trace")
    local _, luckyDelta = findLuckDeltaIndex(luckTrace.deltas, {
      source = "action",
      reason = "lucky_coin_match",
      baseAmount = 2,
      amount = 4.0,
      appliedAmount = 4.0,
      generationMultiplier = 2.0,
      positive = true,
    })

    A.truthy(luckyDelta, "Lucky Coin Luck gain should be doubled by highest Fountain Pact tier")
    A.traceHasAction(trace, {
      op = "add_luck",
      amount = 2,
      reason = "lucky_coin_match",
    }, "Lucky Coin should keep its base add_luck action amount")
    A.replayOk(env.replay, "Fountain Pact replay should succeed")

    local luckTamper = Utils.clone(env.transcript)
    local tamperIndex = A.truthy(findLuckDeltaIndex(luckTamper.expected.batchSignatures[1].luck.deltas, {
      source = "action",
      reason = "lucky_coin_match",
    }), "expected Lucky Coin Luck delta signature")
    luckTamper.expected.batchSignatures[1].luck.deltas[tamperIndex].generationMultiplier = 1.25
    local luckReplay = ReplaySystem.replayTranscript(luckTamper)
    A.falsy(luckReplay.ok, "tampered Fountain Pact multiplier should fail replay")
  end,
}
