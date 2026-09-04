local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findSwapAction(actions)
  for index, action in ipairs(actions or {}) do
    if action.op == "swap_coins" then
      return action, index
    end
  end

  return nil, nil
end

return {
  id = "sleight_switcheroo_swap",
  tags = { "sleight", "replay" },
  description = "Verifies Switcheroo moves a missed Vanishing Coin into a matching result slot and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 2,
        starterCollection = { "copper_vanishing_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedTrickIds = { "switcheroo" },
      },
      initialLoadout = {
        [1] = "copper_vanishing_coin",
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
    local move = A.truthy((trace.sleightMoves or {})[1], "Switcheroo should move one missed Vanishing Coin")
    A.equal(move.failedCoinId, "copper_vanishing_coin", "Switcheroo source should be a Vanishing Coin")
    A.equal(move.failedResult, "tails", "Switcheroo should take a missed result body")
    A.equal(move.successResult, "heads", "Switcheroo should move it into a matching result slot")

    local swapAction, actionIndex = findSwapAction(trace.actions)
    swapAction = A.truthy(swapAction, "Switcheroo should trace swap action")
    A.equal(swapAction.appliedScoreMultiplier, 3.5, "Copper Vanishing Coin material payoff")
    A.equal(swapAction.appliedMaterialRank, 1, "Copper Vanishing Coin material rank")
    A.truthy(swapAction.failedInstanceId ~= swapAction.successInstanceId, "Switcheroo should compare different slots")

    A.traceHasAction(trace, {
      op = "swap_coins",
      target = {
        source = {
          zone = "selected_coins",
          filters = {
            { op = "failed_call" },
            { op = "real_family", value = "sleight" },
          },
          orderBy = "material_rank_desc",
          pick = { op = "slot_at_position", value = 1 },
        },
        target = {
          zone = "selected_coins",
          filters = {
            { op = "matched_call" },
            { op = "not_context_instance" },
          },
          orderBy = "base_score",
          pick = { op = "slot_at_position", value = 1 },
        },
      },
      failedInstanceId = swapAction.failedInstanceId,
      successInstanceId = swapAction.successInstanceId,
      appliedScoreMultiplier = 3.5,
    }, "Switcheroo action should be traced with movement and material metadata")
    A.replayOk(env.replay, "Sleight of Hand replay should succeed")

    local scoreTamper = Utils.clone(env.transcript)
    scoreTamper.expected.batchSignatures[1].actions[actionIndex].appliedScoreMultiplier = 1
    local scoreReplay = ReplaySystem.replayTranscript(scoreTamper)
    A.falsy(scoreReplay.ok, "tampered Switcheroo material payoff should fail replay")
  end,
}
