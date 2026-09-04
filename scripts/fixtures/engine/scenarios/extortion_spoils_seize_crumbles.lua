return {
  id = "extortion_spoils_seize_crumbles",
  tags = { "extortion", "reward" },
  description = "Verifies Spoils Extortion adds Charm options, applies Seize discounts, and Crumbles after use.",

  setup = function()
    return {
      runOptions = {
        seed = 2,
        ownedTrickIds = {
          "strong_arm_deal",
          "take_whats_owed",
          "protection_racket",
          "forced_confession",
        },
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
    { op = "set_shop_points", value = 20 },
    { op = "build_reward_preview", label = "spoils" },
    { op = "claim_reward_choice", index = 1, label = "seized" },
  },

  assert = function(env, A)
    local preview = A.truthy(A.getResult("spoils"), "Spoils preview missing")
    local choice = A.truthy(A.getResult("seized"), "Seized choice missing")
    local generation = A.truthy(preview.generation, "Spoils generation missing")
    local effects = generation.extortionEffects or {}

    A.truthy(#(preview.options or {}) >= 4, "Extortion should add extra Spoils options")
    A.contains(effects, { effect = "extra_spoils_option", sourceId = "strong_arm_deal" }, "Strong-Arm Deal effect missing")
    A.contains(effects, { effect = "extra_enemy_family_spoils", sourceId = "protection_racket" }, "Protection Racket effect missing")
    A.contains(effects, { effect = "reveal_higher_tier_spoils", sourceId = "forced_confession" }, "Forced Confession effect missing")

    for _, option in ipairs(preview.options or {}) do
      A.equal(option.type, "trick", "Spoils should offer Charms, not Coins")
      A.truthy(option.baseSeizeCost ~= nil, "Spoils option should record base Seize cost")
      A.truthy(option.seizeCost ~= nil, "Spoils option should record Seize cost")
      A.equal(option.seizeDiscount, 2, "Take What's Owed should discount each Seize option")
      A.equal(option.seizeDiscountSourceId, "take_whats_owed", "Seize discount source")
      A.equal(option.seizeCost, math.max(0, option.baseSeizeCost - 2), "discounted Seize cost")
    end

    A.notContains(env.runState.ownedTrickIds or {}, "strong_arm_deal", "Strong-Arm Deal should Crumble after Spoils screen")
    A.notContains(env.runState.ownedTrickIds or {}, "protection_racket", "Protection Racket should Crumble after Spoils screen")
    A.notContains(env.runState.ownedTrickIds or {}, "forced_confession", "Forced Confession should Crumble after Spoils screen")

    A.equal(choice.seizeDiscountSourceId, "take_whats_owed", "choice should record Take What's Owed source")
    A.truthy(choice.seizeDiscountCrumble and choice.seizeDiscountCrumble.crumbled == true, "Take What's Owed should Crumble after Seize")
    A.notContains(env.runState.ownedTrickIds or {}, "take_whats_owed", "Take What's Owed should be removed after Seize")
    A.equal(env.runState.influence, 20 - (choice.seizeCost or 0), "Seize should spend discounted Influence")
  end,
}
