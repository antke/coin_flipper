return {
  id = "batch_queue_effect_stage_clear",
  tags = { "batch", "queue", "temporary_effect", "replay" },
  description = "Deterministically verifies queued action ordering, temporary effect lifecycle, and stage clear timing.",

  setup = function()
    return {
      runOptions = {
        seed = 4,
        starterCollection = { "weighted_shell", "match_spark" },
        ownedUpgradeIds = { "heads_varnish", "echo_cache", "reserve_fuse" },
      },
      initialLoadout = {
        [1] = "weighted_shell",
        [2] = "match_spark",
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
    A.equal(#batchResults, 2, "expected two batches")
    A.equal(env.stageRecord.status, "cleared", "stage should clear")
    A.equal(batchResults[1].stageScore, 4, "first batch stage score")
    A.equal(batchResults[2].stageScore, 8, "second batch stage score")
    A.truthy(#(batchResults[1].trace.queuedActions or {}) > 0, "first batch should queue actions")
    A.truthy(#(batchResults[1].trace.temporaryEffectsGranted or {}) > 0, "first batch should grant temporary effect")
    A.truthy(#(batchResults[1].trace.temporaryEffectsConsumed or {}) > 0, "first batch should consume temporary effect")
    A.notContains(batchResults[1].trace.warnings or {}, function(message)
      return tostring(message):find("pending", 1, true) ~= nil
    end, "queued actions should drain cleanly")
    A.equal(#(env.runState.temporaryRunEffects or {}), 0, "temporary effects should be cleared after stage")
    A.replayOk(env.replay, "queue/effect replay should succeed")
  end,
}
