local definitions = {
  {
    id = "copper_bent_coin",
    name = "Bent Coin",
    rarity = "common",
    archetype = "bent",
    material = "copper",
    materialRank = 1,
    base_score = 1,
    material_variants = {
      copper = { id = "copper_bent_coin", materialRank = 1, base_score = 1 },
    },
    description = "A crooked build piece for Prestige and Chain Tricks.",
    effectDescription = "No direct flip effect. Synergizes with Prestige and Chain Tricks.",
    tags = { "prestige", "chain", "bent", "unstable" },
    typeTags = { "prestige", "chain" },
    mechanic_terms = { "resolution_packet", "prestige_replay", "chained_coin", "chain_depth" },
    trick_synergy = { "prestige", "chain" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_blank_coin",
    name = "Blank Coin",
    rarity = "common",
    archetype = "blank",
    material = "copper",
    materialRank = 1,
    base_score = 1,
    material_variants = {
      copper = { id = "copper_blank_coin", materialRank = 1, base_score = 1 },
    },
    description = "An unstamped build piece for Forgery Tricks.",
    effectDescription = "No direct flip effect. Synergizes with Forgery Tricks.",
    tags = { "counterfeit", "blank", "forgery", "copyable" },
    typeTags = { "forgery", "copyable" },
    mechanic_terms = { "forged_identity", "forge_identity", "add_forged_identity" },
    trick_synergy = { "forgery" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_hollow_coin",
    name = "Hollow Coin",
    rarity = "common",
    archetype = "hollow",
    material = "copper",
    materialRank = 1,
    base_score = 1,
    material_variants = {
      copper = { id = "copper_hollow_coin", materialRank = 1, base_score = 1 },
    },
    description = "A lightweight build piece for Smuggling Tricks.",
    effectDescription = "No direct flip effect. Synergizes with Smuggling Tricks.",
    tags = { "smuggle", "hollow", "contraband", "hand_overflow" },
    typeTags = { "smuggle", "contraband" },
    mechanic_terms = { "smuggle_coin_from_hand", "overloaded_board", "contraband_copy", "increase_refill_count" },
    trick_synergy = { "smuggle" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_marked_coin",
    name = "Marked Coin",
    rarity = "common",
    archetype = "marked",
    material = "copper",
    materialRank = 1,
    base_score = 1,
    material_variants = {
      copper = { id = "copper_marked_coin", materialRank = 1, base_score = 1 },
    },
    description = "A readable build piece for Prediction and Foretold Tricks.",
    effectDescription = "No direct flip effect. Synergizes with Foretold Tricks.",
    tags = { "marked", "foretold", "read" },
    typeTags = { "foretold", "read" },
    mechanic_terms = { "foretell_coin_result", "foretold_result" },
    trick_synergy = { "foretold", "prediction" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_lucky_coin",
    name = "Lucky Coin",
    rarity = "common",
    archetype = "lucky",
    material = "copper",
    materialRank = 1,
    base_score = 1,
    material_variants = {
      copper = { id = "copper_lucky_coin", materialRank = 1, base_score = 1 },
    },
    description = "A fate-touched build piece for Luck Meter Tricks.",
    effectDescription = "+1 Luck Meter progress when this coin matches your call.",
    tags = { "fate", "luck_meter", "fated_flip", "destiny" },
    typeTags = { "fate", "luck_meter" },
    mechanic_terms = { "luck_meter", "luck_gain", "fated_flip", "fated_flip_payoff" },
    trick_synergy = { "luck_meter", "fated_flip" },
    isStarter = true,
    triggers = {
      {
        hook = "after_coin_roll",
        condition = { match = true },
        effects = {
          { op = "add_luck", amount = 1, reason = "lucky_coin_match" },
        },
      },
    },
  },
  {
    id = "copper_weighted_coin",
    name = "Weighted Coin",
    rarity = "common",
    archetype = "weighted",
    material = "copper",
    materialRank = 1,
    base_score = 1,
    call_match_chance = 0.65,
    material_variants = {
      copper = { id = "copper_weighted_coin", materialRank = 1, base_score = 1, call_match_chance = 0.65 },
    },
    description = "A loaded build piece that leans toward your declared call.",
    effectDescription = "65% chance to match your call.",
    tags = { "loaded", "weight", "odds", "reliable" },
    typeTags = { "loaded", "reliable" },
    mechanic_terms = { "set_call_match_chance", "call_match_chance" },
    trick_synergy = { "loaded" },
    isStarter = true,
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "add_weight", side = "call", amount = 0.15 },
        },
      },
    },
  },
}

local visualIdentities = {
  copper_bent_coin = { face = "bent", rim = "combo" },
  copper_blank_coin = { face = "blank", rim = "score" },
  copper_hollow_coin = { face = "hollow", rim = "motion" },
  copper_marked_coin = { face = "marked", rim = "safety" },
  copper_lucky_coin = { face = "lucky", rim = "combo" },
  copper_weighted_coin = { face = "weighted", rim = "weight" },
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
