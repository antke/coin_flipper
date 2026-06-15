return {
  id = "enemy_class_trick_reward_pool",
  tags = { "reward", "shop" },
  description = "Verifies defeated enemy class metadata weights Trick reward offers with bounded wildcards.",

  setup = function()
    return {
      runOptions = {
        seed = 2,
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
    { op = "force_stage_clear" },
    { op = "finalize_stage" },
    { op = "build_reward_preview", label = "reward_preview" },
  },

  assert = function(env, A)
    local preview = A.truthy(A.getResult("reward_preview"), "reward preview missing")
    local generation = A.truthy(preview.generation, "reward generation metadata missing")
    local pool = {}

    for _, category in ipairs(generation.rewardPoolCategories or {}) do
      pool[category] = true
    end

    A.equal(env.stageRecord.enemyClass, "card_shark", "round 1 opponent should expose enemy class")
    A.equal(generation.enemyClass, "card_shark", "reward generation should record enemy class")
    A.equal(generation.enemyClassLabel, "Card Shark", "reward generation should record enemy class label")
    A.truthy(pool.prediction, "Card Shark pool should include Prediction")
    A.truthy(pool.weighted, "Card Shark pool should include Weighted")
    A.truthy(#(preview.options or {}) > 0, "enemy class should produce Trick offers")
    A.truthy((generation.wildcardOfferCount or 0) <= (generation.wildcardCap or 0), "wildcard offers should stay within cap")

    local classOfferCount = 0

    for _, option in ipairs(preview.options or {}) do
      A.equal(option.type, "trick", "enemy reward options should be Tricks")
      A.equal(option.enemyClass, "card_shark", "reward option should carry enemy class")
      A.equal(option.enemyClassLabel, "Card Shark", "reward option should carry enemy class label")
      A.equal(option.wildcardChance, generation.wildcardChance, "reward option should carry wildcard chance")
      A.equal(option.wildcardCap, generation.wildcardCap, "reward option should carry wildcard cap")

      if option.wildcard then
        A.equal(option.rewardSource, "wildcard", "wildcard option should mark reward source")
      else
        A.equal(option.rewardSource, "enemy_class", "class option should mark reward source")
        A.truthy(pool[option.trickCategory], "non-wildcard Trick should match enemy class pool")
        classOfferCount = classOfferCount + 1
      end
    end

    A.truthy(classOfferCount > 0, "reward preview should include at least one class-pool Trick")
    A.equal(generation.classOfferCount, classOfferCount, "generation metadata should count class offers")
  end,
}
