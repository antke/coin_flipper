local definitions = {
  {
    id = "match_spark",
    name = "Match Spark",
    rarity = "common",
    description = "+1 stage score and +1 run score when this coin matches your call.",
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
    description = "+2 stage score and +2 run score when this coin matches a Heads call.",
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
    description = "+2 stage score and +2 run score when this coin matches a Tails call.",
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
    description = "+1 shop point when this coin misses your call.",
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
    description = "+2 stage score and +2 run score during boss stages.",
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
    id = "cross_bet",
    name = "Cross Bet",
    rarity = "common",
    description = "On a Heads call, if this coin lands Tails, gain +2 shop points.",
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
    description = "+1 stage score and +1 shop point when this coin matches a Heads call.",
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
    description = "+1 stage score and +1 shop point when this coin matches a Tails call.",
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
    description = "If no equipped coin matches this batch, gain +1 shop point and +1 run score.",
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
    description = "+1 stage score before the stage-end check if no equipped coin matches this batch.",
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
    description = "+1 run score and +1 shop point when this coin matches on a repeated Tails call.",
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
    description = "This coin gains +0.15 Tails weight. On a Tails match, gain +1 shop point.",
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
    description = "If every equipped coin matches this batch, add +3 stage score and +3 run score at batch end.",
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
    description = "If no equipped coin matches this batch, gain +2 shop points and +1 run score.",
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
}

local byId = {}

for _, definition in ipairs(definitions) do
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
  local addedIds = {}
  local unlockedIndex = buildUnlockedIndex(unlockedCoinIds)
  local extraCandidates = {}

  for _, definition in ipairs(definitions) do
    if definition.isStarter and Coins.isUnlocked(definition, unlockedIndex) then
      table.insert(starterIds, definition.id)
      addedIds[definition.id] = true
    end
  end

  if limit and #starterIds < limit then
    for _, definition in ipairs(definitions) do
      if not addedIds[definition.id] and Coins.isUnlocked(definition, unlockedIndex) then
        table.insert(extraCandidates, definition.id)
      end
    end

    local seed = extractSeed(source)

    for index = 1, math.min(limit - #starterIds, #extraCandidates) do
      local candidateIndex = ((seed + index - 2) % #extraCandidates) + 1
      local coinId = extraCandidates[candidateIndex]

      table.insert(starterIds, coinId)
      addedIds[coinId] = true
    end
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
