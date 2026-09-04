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
  id = "smuggling_planted_double_riches",
  tags = { "smuggling", "replay" },
  description = "Verifies Planted Double copies a random smuggled coin and Embarrassment of Riches boosts all unselected flipped coins.",

  setup = function()
    return {
      runOptions = {
        seed = 2,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin", "copper_hollow_coin" },
        ownedTrickIds = { "hidden_in_plain_sight", "planted_double", "embarrassment_of_riches" },
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
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local batch = A.truthy(firstBatch.batch, "missing first batch snapshot")
    local boardSlots = batch.boardSlots or {}
    local scoreEvents = firstBatch.scoreBreakdown and firstBatch.scoreBreakdown.scoreEvents or {}

    A.equal(#boardSlots, 2, "Hidden in Plain Sight plus Planted Double should create two overload slots")

    local smuggledMove = A.truthy((trace.smugglingMoves or {})[1], "missing real smuggling move")
    local copyMove = A.truthy((trace.smugglingMoves or {})[2], "missing Planted Double move")
    A.equal(smuggledMove.op, "smuggle_coin_from_hand", "first smuggling move should use the real hand coin")
    A.equal(copyMove.op, "copy_smuggled_coin", "second smuggling move should be the contraband copy")
    A.equal(copyMove.copiedFromInstanceId, smuggledMove.instanceId, "copy should record its random smuggled source")
    A.equal(copyMove.contrabandCopy, true, "copy move should mark temporary contraband")
    A.equal(copyMove.chance, 0.5, "Planted Double chance")
    A.truthy(copyMove.rngRoll and copyMove.rngRoll <= 0.5, "Planted Double fixture seed should pass the chance roll")

    local realEvent = A.contains(scoreEvents, {
      instanceId = smuggledMove.instanceId,
      smuggled = true,
      matched = true,
    }, "missing real smuggled score event")
    local copyEvent = A.contains(scoreEvents, {
      instanceId = copyMove.instanceId,
      smuggled = true,
      contrabandCopy = true,
      copiedFromInstanceId = smuggledMove.instanceId,
      matched = true,
    }, "missing copied smuggled score event")

    A.equal(realEvent.scoreScaling, 1.5, "real Copper Hollow should get Embarrassment 1.5x")
    A.equal(copyEvent.scoreScaling, 1.5, "copied smuggled coin should get Embarrassment 1.5x")
    A.equal(copyEvent.finalScoreContribution, 15, "copied smuggled coin should contribute boosted base-10 score")

    A.traceHasAction(trace, {
      op = "copy_smuggled_coin",
      chance = 0.5,
      instanceId = copyMove.instanceId,
      copiedFromInstanceId = smuggledMove.instanceId,
      contrabandCopy = true,
    }, "Planted Double action should be traced with copy metadata")
    A.traceHasAction(trace, {
      op = "apply_score_scaling",
      reason = "embarrassment_of_riches",
      value = 1.5,
      instanceId = smuggledMove.instanceId,
    }, "Embarrassment should scale the real smuggled coin")
    A.traceHasAction(trace, {
      op = "apply_score_scaling",
      reason = "embarrassment_of_riches",
      value = 1.5,
      instanceId = copyMove.instanceId,
    }, "Embarrassment should scale the copied smuggled coin")

    A.replayOk(env.replay, "Planted Double replay should succeed")

    local actionTamper = Utils.clone(env.transcript)
    local copyActionIndex = A.truthy(findActionIndex(actionTamper.expected.batchSignatures[1].actions, {
      op = "copy_smuggled_coin",
      reason = "planted_double",
    }), "expected Planted Double action signature")
    actionTamper.expected.batchSignatures[1].actions[copyActionIndex].rngRoll = 0.75
    local actionReplay = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionReplay.ok, "tampered Planted Double roll should fail replay")
  end,
}
