return {
  id = "batch_queue_effect_stage_clear",
  tags = { "batch", "temporary_effect", "replay" },
  description = "Deterministically verifies temporary effect lifecycle and stage clear timing.",

  setup = function()
    return {
      runOptions = {
        seed = 4,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedTrickIds = { "heads_varnish", "echo_cache" },
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
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 4, label = "batch_results" },
    { op = "finalize_stage" },
    { op = "build_reward_preview" },
    { op = "claim_reward_choice" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local batchResults = A.truthy(A.getResult("batch_results"), "batch results missing")
    A.truthy(#batchResults > 0, "expected at least one batch")
    A.equal(env.stageRecord.status, "cleared", "stage should clear")
    local sawGrant = false
    local sawConsume = false

    for _, batchResult in ipairs(batchResults) do
      sawGrant = sawGrant or #(batchResult.trace.temporaryEffectsGranted or {}) > 0
      sawConsume = sawConsume or #(batchResult.trace.temporaryEffectsConsumed or {}) > 0
    end

    A.truthy(sawGrant, "stage should grant a temporary effect")
    A.truthy(sawConsume, "stage should consume a temporary effect")
    A.equal(#(env.runState.temporaryRunEffects or {}), 0, "temporary effects should be cleared after stage")
    A.replayOk(env.replay, "queue/effect replay should succeed")
  end,
}
