local definitions = {
  {
    id = "regular_dollar",
    name = "$ Coin",
    rarity = "common",
    description = "A familiar casino token with two honest faces.",
    tags = { "regular", "filler" },
    typeTags = { "basic" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "heads_loaded_penny",
    name = "Heads-Loaded Penny",
    rarity = "common",
    description = "A crooked coin coin rigged for Heads.",
    tags = { "starter", "cheat", "heads" },
    typeTags = { "odds", "heads" },
    isStarter = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.35 },
        },
      },
    },
  },
  {
    id = "tails_loaded_penny",
    name = "Tails-Loaded Penny",
    rarity = "common",
    description = "A crooked coin rigged for Tails.",
    tags = { "starter", "cheat", "tails" },
    typeTags = { "odds", "tails" },
    isStarter = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.35 },
        },
      },
    },
  },
  {
    id = "lucky_miss",
    name = "Lucky Miss",
    rarity = "common",
    description = "A scuffed fallback piece that pays off bad guesses.",
    effectDescription = "+1 extra Chip when this coin misses your call.",
    tags = { "starter", "economy", "miss" },
    typeTags = { "economy", "safety" },
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
    id = "streak_drill",
    name = "Streak Drill",
    rarity = "uncommon",
    unlockedByDefault = false,
    description = "A grooved coin that bites harder into a steady rhythm.",
    effectDescription = "Repeated successful calls apply a 1.25x score multiplier.",
    tags = { "streak", "multiplier" },
    typeTags = { "combo" },
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
    id = "cross_catch",
    name = "Cross Catch",
    rarity = "common",
    description = "A cross-marked catcher's coin for Heads-side gambits.",
    effectDescription = "On a Heads call, if this coin lands Tails, gain +2 extra Chips.",
    tags = { "economy", "heads", "counter" },
    typeTags = { "safety", "economy" },
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
    id = "heads_cache",
    name = "Heads Cache",
    rarity = "common",
    description = "A warm pocket cache keyed to Heads.",
    effectDescription = "+2 extra Chips when this coin matches a Heads call.",
    tags = { "heads", "economy", "match" },
    typeTags = { "economy", "heads" },
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
    description = "A cool pocket cache keyed to Tails.",
    effectDescription = "+2 extra Chips when this coin matches a Tails call.",
    tags = { "tails", "economy", "match" },
    typeTags = { "economy", "tails" },
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
    description = "A resonant penny that favors repeated patterns.",
    effectDescription = "Repeated calls are worth 1.10x score.",
    tags = { "streak", "multiplier" },
    typeTags = { "combo" },
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
    id = "heads_anchor",
    name = "Heads Anchor",
    rarity = "common",
    description = "A heavy anchor coin that drifts toward Heads over time.",
    effectDescription = "On each Heads match, permanently gains +5% Heads chance.",
    tags = { "heads", "weight", "attunement" },
    typeTags = { "attunement", "heads" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "heads", result = "heads" },
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.05, persistent = true },
        },
      },
    },
  },
  {
    id = "tails_anchor",
    name = "Tails Anchor",
    rarity = "common",
    description = "A heavy anchor coin that drifts toward Tails over time.",
    effectDescription = "On each Tails match, permanently gains +5% Tails chance.",
    tags = { "tails", "weight", "attunement" },
    typeTags = { "attunement", "tails" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { call = "tails", result = "tails" },
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.05, persistent = true },
        },
      },
    },
  },
  {
    id = "pocket_refund",
    name = "Pocket Refund",
    rarity = "common",
    description = "A quick-return coin with a hidden rebate notch.",
    effectDescription = "When this coin is returned to the pouch by Sleight, gain +1 extra Chip.",
    tags = { "sleight", "economy" },
    typeTags = { "economy", "motion" },
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
    id = "opening_penny",
    name = "Opening Penny",
    rarity = "common",
    description = "A bright opener kept ready at the top of the pouch.",
    effectDescription = "When this coin is drawn into a new hand, gain +1 extra Chip.",
    tags = { "draw", "economy" },
    typeTags = { "economy", "motion" },
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
    description = "A slick cent that rewards deft repositioning.",
    effectDescription = "When this coin is moved by hand reordering, gain +1 extra Chip.",
    tags = { "reorder", "economy" },
    typeTags = { "economy", "motion" },
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
    description = "A weighty chip made for decisive hands.",
    effectDescription = "Before flipping the hand, apply a 1.10x score multiplier.",
    tags = { "flip", "multiplier" },
    typeTags = { "combo", "motion" },
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
    description = "A tilted coin that pulls fortune from the left.",
    effectDescription = "Before rolling, the coin to the left gains +20% Heads chance.",
    tags = { "neighbor", "heads", "weight" },
    typeTags = { "odds", "neighbor", "heads" },
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
    description = "A drifting coin that tugs fate to the right.",
    effectDescription = "Before rolling, the coin to the right gains +20% Tails chance.",
    tags = { "neighbor", "tails", "weight" },
    typeTags = { "odds", "neighbor", "tails" },
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
    id = "glass_nickel",
    name = "Glass Nickel",
    rarity = "rare",
    description = "A brittle nickel that flashes brightest under pressure.",
    effectDescription = "Each match primes a 1.15x score multiplier before base scoring.",
    tags = { "match", "multiplier", "score" },
    typeTags = { "combo" },
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
    description = "A pale mint struck for the Tails side of the moon.",
    effectDescription = "On a Tails match, gain +1 extra Chip.",
    tags = { "tails", "weight", "economy" },
    typeTags = { "odds", "economy", "tails" },
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
    id = "fate_token",
    name = "Fate Token",
    rarity = "uncommon",
    description = "An omen-stamped token that feeds the Luck Meter.",
    effectDescription = "On a match, add +2 extra Luck Meter progress.",
    tags = { "luck", "match" },
    typeTags = { "luck", "combo" },
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = true },
        effects = {
          { op = "add_luck", amount = 2, reason = "fate_token_match" },
        },
      },
    },
  },
}

local visualIdentities = {
  regular_dollar = { face = "regular_dollar", rim = "score" },
  heads_loaded_penny = { face = "heads", rim = "weight" },
  tails_loaded_penny = { face = "tails", rim = "weight" },
  lucky_miss = { face = "lucky_miss", rim = "safety" },
  streak_drill = { face = "streak_drill", rim = "combo" },
  cross_catch = { face = "cross_catch", rim = "safety" },
  heads_cache = { face = "heads_cache", rim = "economy" },
  tails_cache = { face = "tails_cache", rim = "economy" },
  echo_penny = { face = "echo_penny", rim = "combo" },
  heads_anchor = { face = "heads_anchor", rim = "weight" },
  tails_anchor = { face = "tails_anchor", rim = "weight" },
  pocket_refund = { face = "pocket_refund", rim = "motion" },
  opening_penny = { face = "opening_penny", rim = "motion" },
  slider_cent = { face = "slider_cent", rim = "motion" },
  commitment_chip = { face = "commitment_chip", rim = "motion" },
  left_lift = { face = "left_lift", rim = "motion" },
  right_drift = { face = "right_drift", rim = "motion" },
  glass_nickel = { face = "glass_nickel", rim = "combo" },
  moon_mint = { face = "moon_mint", rim = "weight" },
  fate_token = { face = "lucky_miss", rim = "combo" },
}

local function coinHasTag(definition, tag)
  for _, value in ipairs(definition.tags or {}) do
    if value == tag then
      return true
    end
  end

  return false
end

local function effectsAddScore(effects)
  for _, effect in ipairs(effects or {}) do
    if effect.op == "add_stage_score" or effect.op == "add_run_score" then
      return true
    end

    if effect.op == "queue_actions" and effectsAddScore(effect.actions) then
      return true
    end
  end

  return false
end

local function coinAddsScore(definition)
  if definition.neighbor and (definition.neighbor.stageScore or definition.neighbor.runScore) then
    return true
  end

  if definition.combo and (definition.combo.stageScore or definition.combo.runScore) then
    return true
  end

  for _, trigger in ipairs(definition.triggers or {}) do
    if effectsAddScore(trigger.effects) then
      return true
    end
  end

  return false
end

local activeDefinitions = {}

for _, definition in ipairs(definitions) do
  if not coinHasTag(definition, "boss") and not coinAddsScore(definition) then
    table.insert(activeDefinitions, definition)
  end
end

definitions = activeDefinitions

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
