local definitions = {
  {
    id = "regular_dollar",
    name = "$ Coin",
    rarity = "common",
    description = "A plain 50/50 coin with no special effect.",
    tags = { "regular", "filler" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "heads_loaded_penny",
    name = "Heads-Loaded Penny",
    rarity = "common",
    description = "A crooked coin rigged for Heads. 75% Heads chance.",
    tags = { "starter", "cheat", "heads" },
    isStarter = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 1.0 },
        },
      },
    },
  },
  {
    id = "tails_loaded_penny",
    name = "Tails-Loaded Penny",
    rarity = "common",
    description = "A crooked coin rigged for Tails. 75% Tails chance.",
    tags = { "starter", "cheat", "tails" },
    isStarter = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 1.0 },
        },
      },
    },
  },
  {
    id = "match_spark",
    name = "Match Spark",
    rarity = "common",
    description = "+1 damage and +1 run score when this coin matches your call.",
    tags = { "starter", "match", "score" },
    isStarter = true,
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = true },
        effects = {
          { op = "add_stage_score", amount = 1 },
          { op = "add_run_score", amount = 1 },
        },
      },
    },
  },
  {
    id = "heads_hunter",
    name = "Heads Hunter",
    rarity = "common",
    description = "+2 damage and +2 run score when this coin matches a Heads call.",
    tags = { "starter", "heads", "match" },
    isStarter = true,
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "heads", result = "heads" },
        effects = {
          { op = "add_stage_score", amount = 2 },
          { op = "add_run_score", amount = 2 },
        },
      },
    },
  },
  {
    id = "tails_chaser",
    name = "Tails Chaser",
    rarity = "common",
    description = "+2 damage and +2 run score when this coin matches a Tails call.",
    tags = { "starter", "tails", "match" },
    isStarter = true,
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "tails", result = "tails" },
        effects = {
          { op = "add_stage_score", amount = 2 },
          { op = "add_run_score", amount = 2 },
        },
      },
    },
  },
  {
    id = "lucky_miss",
    name = "Lucky Miss",
    rarity = "common",
    description = "+1 Chip when this coin misses your call.",
    tags = { "starter", "economy", "miss" },
    isStarter = true,
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = false },
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "weighted_shell",
    name = "Weighted Shell",
    rarity = "common",
    description = "This coin gains +0.10 Heads weight before rolling.",
    tags = { "starter", "weight", "heads" },
    isStarter = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.10 },
        },
      },
    },
  },
  {
    id = "streak_drill",
    name = "Streak Drill",
    rarity = "uncommon",
    unlockedByDefault = false,
    description = "Applies a 1.25x score multiplier on repeated successful calls.",
    tags = { "streak", "multiplier" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { repeated_call = true },
        effects = {
          { op = "apply_score_multiplier", value = 1.25 },
        },
      },
    },
  },
  {
    id = "boss_biter",
    name = "Boss Biter",
    rarity = "uncommon",
    description = "+2 damage and +2 run score during boss stages.",
    tags = { "boss", "score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { stage_type = "boss" },
        effects = {
          { op = "add_stage_score", amount = 2 },
          { op = "add_run_score", amount = 2 },
        },
      },
    },
  },
  {
    id = "cross_catch",
    name = "Cross Catch",
    rarity = "common",
    description = "On a Heads call, if this coin lands Tails, gain +2 Chips.",
    tags = { "economy", "heads", "counter" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "heads", result = "tails" },
        effects = {
          { op = "add_shop_points", amount = 2 },
        },
      },
    },
  },
  {
    id = "heads_banker",
    name = "Heads Banker",
    rarity = "common",
    description = "+1 damage and +1 Chip when this coin matches a Heads call.",
    tags = { "heads", "economy", "match" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "heads", result = "heads" },
        effects = {
          { op = "add_stage_score", amount = 1 },
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "tails_banker",
    name = "Tails Banker",
    rarity = "common",
    description = "+1 damage and +1 Chip when this coin matches a Tails call.",
    tags = { "tails", "economy", "match" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "tails", result = "tails" },
        effects = {
          { op = "add_stage_score", amount = 1 },
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "safety_net",
    name = "Safety Net",
    rarity = "uncommon",
    unlockedByDefault = false,
    description = "If no equipped coin matches this batch, gain +1 Chip and +1 run score.",
    tags = { "economy", "safety" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { no_matches = true },
        effects = {
          { op = "add_shop_points", amount = 1 },
          { op = "add_run_score", amount = 1 },
        },
      },
    },
  },
  {
    id = "reserve_token",
    name = "Reserve Token",
    rarity = "uncommon",
    unlockedByDefault = false,
    description = "If every equipped coin matches this batch, gain +1 free shop reroll.",
    tags = { "economy", "perfect", "shop" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { all_matched = true },
        effects = {
          { op = "add_shop_rerolls", amount = 1 },
        },
      },
    },
  },
  {
    id = "mirror_mark",
    name = "Mirror Mark",
    rarity = "common",
    description = "+1 run score when this coin matches on a repeated call batch.",
    tags = { "streak", "score" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = true, repeated_call = true },
        effects = {
          { op = "add_run_score", amount = 1 },
        },
      },
    },
  },
  {
    id = "parachute_pin",
    name = "Parachute Pin",
    rarity = "common",
    description = "+1 damage before the stage-end check if no equipped coin matches this batch.",
    tags = { "safety", "miss", "score" },
    triggers = {
      {
        hook = "before_stage_end_check",
        condition = { no_matches = true },
        effects = {
          { op = "add_stage_score", amount = 1 },
        },
      },
    },
  },
  {
    id = "tails_echo",
    name = "Tails Echo",
    rarity = "common",
    description = "+1 run score and +1 Chip when this coin matches on a repeated Tails call.",
    tags = { "tails", "streak", "economy" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "tails", result = "tails", repeated_call = true },
        effects = {
          { op = "add_run_score", amount = 1 },
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "heads_cache",
    name = "Heads Cache",
    rarity = "common",
    description = "+2 Chips when this coin matches a Heads call.",
    tags = { "heads", "economy", "match" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "heads", result = "heads" },
        effects = {
          { op = "add_shop_points", amount = 2 },
        },
      },
    },
  },
  {
    id = "tails_cache",
    name = "Tails Cache",
    rarity = "common",
    description = "+2 Chips when this coin matches a Tails call.",
    tags = { "tails", "economy", "match" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "tails", result = "tails" },
        effects = {
          { op = "add_shop_points", amount = 2 },
        },
      },
    },
  },
  {
    id = "echo_penny",
    name = "Echo Penny",
    rarity = "common",
    description = "Repeated calls are worth 1.10x score.",
    tags = { "streak", "multiplier" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { repeated_call = true },
        effects = {
          { op = "apply_score_multiplier", value = 1.10 },
        },
      },
    },
  },
  {
    id = "perfect_penny",
    name = "Perfect Penny",
    rarity = "common",
    description = "+2 damage and +2 run score if every equipped coin matches this batch.",
    tags = { "perfect", "score", "match" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { all_matched = true },
        effects = {
          { op = "add_stage_score", amount = 2 },
          { op = "add_run_score", amount = 2 },
        },
      },
    },
  },
  {
    id = "comeback_cent",
    name = "Comeback Cent",
    rarity = "common",
    description = "If no equipped coin matches this batch, gain +2 Chips.",
    tags = { "miss", "safety", "economy" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { no_matches = true },
        effects = {
          { op = "add_shop_points", amount = 2 },
        },
      },
    },
  },
  {
    id = "heads_anchor",
    name = "Heads Anchor",
    rarity = "common",
    description = "On Heads calls, this coin gains +0.10 Heads weight before rolling.",
    tags = { "heads", "weight" },
    triggers = {
      {
        hook = "before_coin_roll",
        condition = { call = "heads" },
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.10 },
        },
      },
    },
  },
  {
    id = "tails_anchor",
    name = "Tails Anchor",
    rarity = "common",
    description = "On Tails calls, this coin gains +0.10 Tails weight before rolling.",
    tags = { "tails", "weight" },
    triggers = {
      {
        hook = "before_coin_roll",
        condition = { call = "tails" },
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.10 },
        },
      },
    },
  },
  {
    id = "banked_spark",
    name = "Banked Spark",
    rarity = "common",
    description = "+1 Chip after scoring each batch.",
    tags = { "economy", "score" },
    triggers = {
      {
        hook = "after_scoring",
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "pocket_refund",
    name = "Pocket Refund",
    rarity = "common",
    description = "When this coin is returned to the purse by Sleight, gain +1 Chip.",
    tags = { "sleight", "economy" },
    triggers = {
      {
        hook = "after_sleight_return",
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "fresh_mint",
    name = "Fresh Mint",
    rarity = "common",
    description = "When this coin enters your hand as a Sleight replacement, deal +1 damage.",
    tags = { "sleight", "score" },
    triggers = {
      {
        hook = "after_replacement_draw",
        effects = {
          { op = "add_stage_score", amount = 1 },
        },
      },
    },
  },
  {
    id = "opening_penny",
    name = "Opening Penny",
    rarity = "common",
    description = "When this coin is drawn into a new hand, gain +1 Chip.",
    tags = { "draw", "economy" },
    triggers = {
      {
        hook = "after_hand_draw",
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "slider_cent",
    name = "Slider Cent",
    rarity = "uncommon",
    description = "When this coin is moved by hand reordering, gain +1 Chip.",
    tags = { "reorder", "economy" },
    triggers = {
      {
        hook = "after_hand_reorder",
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "commitment_chip",
    name = "Commitment Chip",
    rarity = "uncommon",
    description = "Before flipping the hand, apply a 1.10x score multiplier.",
    tags = { "flip", "multiplier" },
    triggers = {
      {
        hook = "before_hand_flip",
        effects = {
          { op = "apply_score_multiplier", value = 1.10 },
        },
      },
    },
  },
  {
    id = "left_lift",
    name = "Left Lift",
    rarity = "uncommon",
    description = "Before rolling, this coin and the coin to the left gain +0.20 Heads weight.",
    tags = { "neighbor", "heads", "weight" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.20, target = "self_and_left_neighbor" },
        },
      },
    },
  },
  {
    id = "right_drift",
    name = "Right Drift",
    rarity = "uncommon",
    description = "Before rolling, this coin and the coin to the right gain +0.20 Tails weight.",
    tags = { "neighbor", "tails", "weight" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.20, target = "self_and_right_neighbor" },
        },
      },
    },
  },
  {
    id = "right_hand_charm",
    name = "Right-Hand Charm",
    rarity = "uncommon",
    description = "If this coin and the coin to its right both match your call, deal +1 damage and gain +1 run score.",
    tags = { "neighbor", "match", "score" },
    customResolver = "src.systems.neighbor_resolver",
    neighbor = {
      kind = "right_match_bonus",
      stageScore = 1,
      runScore = 1,
      label = "Right-Hand Charm",
    },
    triggers = {},
  },
  {
    id = "edge_bet",
    name = "Edge Bet",
    rarity = "common",
    description = "If this coin is leftmost or rightmost and matches your call, deal +2 damage and gain +2 run score.",
    tags = { "neighbor", "edge", "match", "score" },
    customResolver = "src.systems.neighbor_resolver",
    neighbor = {
      kind = "edge_match_bonus",
      stageScore = 2,
      runScore = 2,
      label = "Edge Bet",
    },
    triggers = {},
  },
  {
    id = "glass_nickel",
    name = "Glass Nickel",
    rarity = "rare",
    description = "Each match primes a 1.15x score multiplier before base scoring. Fragile, but explosive with wide loadouts.",
    tags = { "match", "multiplier", "score" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = true },
        effects = {
          { op = "apply_score_multiplier", value = 1.15 },
        },
      },
    },
  },
  {
    id = "moon_mint",
    name = "Moon Mint",
    rarity = "uncommon",
    description = "This coin gains +0.15 Tails weight. On a Tails match, gain +1 Chip.",
    tags = { "tails", "weight", "economy" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.15 },
        },
      },
      {
        hook = "after_coin_roll",
        condition = { call = "tails", result = "tails" },
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "sun_stamp",
    name = "Sun Stamp",
    rarity = "uncommon",
    description = "If every equipped coin matches this batch, deal +3 damage and gain +3 run score at batch end.",
    tags = { "perfect", "score", "match" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { all_matched = true },
        effects = {
          { op = "add_stage_score", amount = 3 },
          { op = "add_run_score", amount = 3 },
        },
      },
    },
  },
  {
    id = "black_cat_cent",
    name = "Black Cat Cent",
    rarity = "rare",
    description = "If no equipped coin matches this batch, gain +2 Chips and +1 run score.",
    tags = { "miss", "safety", "economy" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { no_matches = true },
        effects = {
          { op = "add_shop_points", amount = 2 },
          { op = "add_run_score", amount = 1 },
        },
      },
    },
  },
  {
    id = "grave_taler",
    name = "Grave Taler",
    rarity = "cursed",
    price = 14,
    description = "Cursed. Cannot be Sleighted or reordered. When it matches your call, deal +5 damage and gain +5 run score.",
    tags = { "cursed", "locked", "match", "score" },
    cannotSleight = true,
    cannotReorder = true,
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = true },
        effects = {
          { op = "add_stage_score", amount = 5 },
          { op = "add_run_score", amount = 5 },
        },
      },
    },
  },
  {
    id = "blood_oracle",
    name = "Blood Oracle",
    rarity = "cursed",
    price = 16,
    description = "Cursed. Cannot be Sleighted or reordered. Gains +0.25 Heads weight before rolling. On a Heads match, deal +6 damage.",
    tags = { "cursed", "locked", "heads", "weight", "score" },
    cannotSleight = true,
    cannotReorder = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.25 },
        },
      },
      {
        hook = "after_coin_roll",
        condition = { call = "heads", result = "heads" },
        effects = {
          { op = "add_stage_score", amount = 6 },
        },
      },
    },
  },
  {
    id = "triple_crown",
    name = "Triple Crown",
    rarity = "uncommon",
    description = "COMBO: If any three adjacent coins land Heads, deal +4 damage and gain +4 run score.",
    tags = { "combo", "pattern", "heads", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "heads", "heads", "heads" },
      stageScore = 4,
      runScore = 4,
      label = "Triple Heads Combo",
    },
    triggers = {},
  },
  {
    id = "switchback_cent",
    name = "Switchback Cent",
    rarity = "uncommon",
    description = "COMBO: If any three adjacent coins land Heads-Tails-Heads, deal +3 damage and gain +2 Chips.",
    tags = { "combo", "pattern", "economy", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "heads", "tails", "heads" },
      stageScore = 3,
      shopPoints = 2,
      label = "Switchback Combo",
    },
    triggers = {},
  },
  {
    id = "tails_triad",
    name = "Tails Triad",
    rarity = "uncommon",
    description = "COMBO: If any three adjacent coins land Tails, deal +4 damage and gain +4 run score.",
    tags = { "combo", "pattern", "tails", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "tails", "tails", "tails" },
      stageScore = 4,
      runScore = 4,
      label = "Triple Tails Combo",
    },
    triggers = {},
  },
  {
    id = "turnabout_token",
    name = "Turnabout Token",
    rarity = "uncommon",
    description = "COMBO: If any three adjacent coins land Tails-Heads-Tails, deal +3 damage and gain +2 Chips.",
    tags = { "combo", "pattern", "economy", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "tails", "heads", "tails" },
      stageScore = 3,
      shopPoints = 2,
      label = "Turnabout Combo",
    },
    triggers = {},
  },
  {
    id = "rising_run",
    name = "Rising Run",
    rarity = "common",
    description = "COMBO: If any three adjacent coins land Heads-Heads-Tails, deal +2 damage and gain +2 run score.",
    tags = { "combo", "pattern", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "heads", "heads", "tails" },
      stageScore = 2,
      runScore = 2,
      label = "Rising Run Combo",
    },
    triggers = {},
  },
  {
    id = "falling_run",
    name = "Falling Run",
    rarity = "common",
    description = "COMBO: If any three adjacent coins land Tails-Tails-Heads, deal +2 damage and gain +2 run score.",
    tags = { "combo", "pattern", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "tails", "tails", "heads" },
      stageScore = 2,
      runScore = 2,
      label = "Falling Run Combo",
    },
    triggers = {},
  },
  {
    id = "heads_tail_gate",
    name = "Heads-Tail Gate",
    rarity = "common",
    description = "COMBO: If any three adjacent coins land Heads-Tails-Tails, deal +2 damage and gain +2 Chips.",
    tags = { "combo", "pattern", "economy", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "heads", "tails", "tails" },
      stageScore = 2,
      shopPoints = 2,
      label = "Heads-Tail Gate Combo",
    },
    triggers = {},
  },
  {
    id = "tails_head_gate",
    name = "Tails-Head Gate",
    rarity = "common",
    description = "COMBO: If any three adjacent coins land Tails-Heads-Heads, deal +2 damage and gain +2 Chips.",
    tags = { "combo", "pattern", "economy", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "adjacent_results",
      results = { "tails", "heads", "heads" },
      stageScore = 2,
      shopPoints = 2,
      label = "Tails-Head Gate Combo",
    },
    triggers = {},
  },
  {
    id = "edge_echo",
    name = "Edge Echo",
    rarity = "common",
    description = "COMBO: If the leftmost and rightmost coins land the same side, deal +2 damage and gain +2 run score.",
    tags = { "combo", "pattern", "score" },
    customResolver = "src.systems.combo_resolver",
    combo = {
      kind = "matching_edges",
      stageScore = 2,
      runScore = 2,
      label = "Edge Echo Combo",
    },
    triggers = {},
  },
}

local visualIdentities = {
  regular_dollar = { face = "regular_dollar", rim = "score" },
  heads_loaded_penny = { face = "heads", rim = "weight" },
  tails_loaded_penny = { face = "tails", rim = "weight" },
  match_spark = { face = "match_spark", rim = "score" },
  heads_hunter = { face = "heads_hunter", rim = "score" },
  tails_chaser = { face = "tails_chaser", rim = "score" },
  lucky_miss = { face = "lucky_miss", rim = "safety" },
  weighted_shell = { face = "weighted_shell", rim = "weight" },
  streak_drill = { face = "streak_drill", rim = "combo" },
  boss_biter = { face = "boss_biter", rim = "boss" },
  cross_catch = { face = "cross_catch", rim = "safety" },
  heads_banker = { face = "heads_banker", rim = "economy" },
  tails_banker = { face = "tails_banker", rim = "economy" },
  safety_net = { face = "safety_net", rim = "safety" },
  reserve_token = { face = "reserve_token", rim = "economy" },
  mirror_mark = { face = "mirror_mark", rim = "combo" },
  parachute_pin = { face = "parachute_pin", rim = "safety" },
  tails_echo = { face = "tails_echo", rim = "combo" },
  heads_cache = { face = "heads_cache", rim = "economy" },
  tails_cache = { face = "tails_cache", rim = "economy" },
  echo_penny = { face = "echo_penny", rim = "combo" },
  perfect_penny = { face = "perfect_penny", rim = "combo" },
  comeback_cent = { face = "comeback_cent", rim = "safety" },
  heads_anchor = { face = "heads_anchor", rim = "weight" },
  tails_anchor = { face = "tails_anchor", rim = "weight" },
  banked_spark = { face = "banked_spark", rim = "economy" },
  pocket_refund = { face = "pocket_refund", rim = "motion" },
  fresh_mint = { face = "fresh_mint", rim = "motion" },
  opening_penny = { face = "opening_penny", rim = "motion" },
  slider_cent = { face = "slider_cent", rim = "motion" },
  commitment_chip = { face = "commitment_chip", rim = "motion" },
  left_lift = { face = "left_lift", rim = "motion" },
  right_drift = { face = "right_drift", rim = "motion" },
  right_hand_charm = { face = "right_hand_charm", rim = "motion" },
  edge_bet = { face = "edge_bet", rim = "motion" },
  glass_nickel = { face = "glass_nickel", rim = "combo" },
  moon_mint = { face = "moon_mint", rim = "weight" },
  sun_stamp = { face = "sun_stamp", rim = "combo" },
  black_cat_cent = { face = "black_cat_cent", rim = "safety" },
  grave_taler = { face = "grave_taler", rim = "cursed" },
  blood_oracle = { face = "blood_oracle", rim = "cursed" },
  triple_crown = { face = "triple_crown", rim = "combo" },
  switchback_cent = { face = "switchback_cent", rim = "combo" },
  tails_triad = { face = "tails_triad", rim = "combo" },
  turnabout_token = { face = "turnabout_token", rim = "combo" },
  rising_run = { face = "rising_run", rim = "combo" },
  falling_run = { face = "falling_run", rim = "combo" },
  heads_tail_gate = { face = "heads_tail_gate", rim = "combo" },
  tails_head_gate = { face = "tails_head_gate", rim = "combo" },
  edge_echo = { face = "edge_echo", rim = "combo" },
}

local byId = {}

for _, definition in ipairs(definitions) do
  definition.art = definition.art or visualIdentities[definition.id]
  byId[definition.id] = definition
end

local Coins = {}

local function extractSeed(source)
  if type(source) == "number" then
    return source
  end

  if type(source) == "table" and type(source.seed) == "number" then
    return source.seed
  end

  return 1
end

local function hashText(text)
  local hash = 0

  for index = 1, #text do
    hash = (hash * 131 + string.byte(text, index)) % 2147483647
  end

  return hash
end

local function buildUnlockedIndex(unlockedCoinIds)
  local unlockedIndex = {}

  if type(unlockedCoinIds) ~= "table" then
    return unlockedIndex
  end

  for key, value in pairs(unlockedCoinIds) do
    if type(key) == "string" and value == true then
      unlockedIndex[key] = true
    elseif type(value) == "string" and value ~= "" then
      unlockedIndex[value] = true
    end
  end

  return unlockedIndex
end

function Coins.getAll()
  return definitions
end

function Coins.getById(id)
  return byId[id]
end

function Coins.isUnlocked(definition, unlockedCoinIds)
  if not definition then
    return false
  end

  if definition.unlockedByDefault ~= false then
    return true
  end

  local unlockedIndex = buildUnlockedIndex(unlockedCoinIds)
  return unlockedIndex[definition.id] == true
end

function Coins.getUnlockedIds(unlockedCoinIds)
  local unlockedIds = {}
  local unlockedIndex = buildUnlockedIndex(unlockedCoinIds)

  for _, definition in ipairs(definitions) do
    if definition.unlockedByDefault ~= false or unlockedIndex[definition.id] then
      table.insert(unlockedIds, definition.id)
    end
  end

  return unlockedIds
end

function Coins.getDefaultUnlockedIds()
  return Coins.getUnlockedIds({})
end

function Coins.getStarterCoinIds(limit, unlockedCoinIds, source)
  local starterIds = {}
  local unlockedIndex = buildUnlockedIndex(unlockedCoinIds)
  local candidates = {}
  local fallbackCandidates = {}
  local seed = extractSeed(source)

  for _, definition in ipairs(definitions) do
    if Coins.isUnlocked(definition, unlockedIndex) then
      local entry = {
        id = definition.id,
        hash = hashText(string.format("%s:%s", tostring(seed), definition.id)),
      }

      if definition.rarity == "common" then
        table.insert(candidates, entry)
      else
        table.insert(fallbackCandidates, entry)
      end
    end
  end

  table.sort(candidates, function(left, right)
    if left.hash == right.hash then
      return left.id < right.id
    end

    return left.hash < right.hash
  end)

  table.sort(fallbackCandidates, function(left, right)
    if left.hash == right.hash then
      return left.id < right.id
    end

    return left.hash < right.hash
  end)

  for _, candidate in ipairs(candidates) do
    table.insert(starterIds, candidate.id)
  end

  for _, candidate in ipairs(fallbackCandidates) do
    table.insert(starterIds, candidate.id)
  end

  if limit and #starterIds > limit then
    local trimmed = {}

    for index = 1, limit do
      trimmed[index] = starterIds[index]
    end

    return trimmed
  end

  return starterIds
end

return Coins
