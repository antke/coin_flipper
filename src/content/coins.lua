local RNG = require("src.core.rng")

local definitions = {
  {
    id = "copper_bent_coin",
    name = "Bent Coin",
    rarity = "common",
    archetype = "bent",
    activationFamily = "prestige",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_bent_coin", materialRank = 1, base_score = 10 },
    },
    description = "A crooked coin that strengthens Prestige Tricks.",
    effectDescription = "Prestige Outcome replay bonuses that name Bent Coins apply to this coin.",
    tags = { "prestige", "bent", "unstable" },
    typeTags = { "prestige" },
    mechanic_terms = { "outcome", "prestige_replay" },
    trick_synergy = { "prestige" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_flywheel_coin",
    name = "Flywheel Coin",
    rarity = "common",
    archetype = "flywheel",
    activationFamily = "momentum",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_flywheel_coin", materialRank = 1, base_score = 10 },
    },
    description = "A heavy-rimmed coin that keeps motion moving through the flip.",
    effectDescription = "Momentum bonuses that name Flywheel Coins apply to this coin.",
    tags = { "momentum", "flywheel", "motion", "propagation" },
    typeTags = { "momentum", "motion" },
    mechanic_terms = { "in_motion", "momentum_link", "momentum_depth" },
    trick_synergy = { "momentum" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_blank_coin",
    name = "Blank Coin",
    rarity = "common",
    archetype = "blank",
    activationFamily = "forgery",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_blank_coin", materialRank = 1, base_score = 10 },
    },
    description = "An unstamped coin that strengthens Forgery Tricks.",
    effectDescription = "Forgery Trick bonuses that name Blank Coins apply to this coin.",
    tags = { "counterfeit", "blank", "forgery", "copyable" },
    typeTags = { "forgery", "copyable" },
    mechanic_terms = { "forgery_assignment", "acting_family", "copy_outcome", "forge_trick_activations", "forged_activation" },
    trick_synergy = { "forgery" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_hollow_coin",
    name = "Hollow Coin",
    rarity = "common",
    archetype = "hollow",
    activationFamily = "smuggle",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_hollow_coin", materialRank = 1, base_score = 10 },
    },
    description = "A hollow coin that strengthens Smuggling Tricks.",
    effectDescription = "Smuggling bonuses that name Hollow Coins apply to this coin.",
    tags = { "smuggle", "hollow", "contraband", "hand_overflow" },
    typeTags = { "smuggle", "contraband" },
    mechanic_terms = { "smuggle_coin_from_hand", "overloaded_board", "contraband_copy", "add_next_hand_draws" },
    trick_synergy = { "smuggle" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_vanishing_coin",
    name = "Vanishing Coin",
    rarity = "common",
    archetype = "vanishing",
    activationFamily = "sleight",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_vanishing_coin", materialRank = 1, base_score = 10 },
    },
    description = "A half-seen magician's coin that strengthens Sleight of Hand Tricks.",
    effectDescription = "Sleight bonuses that name Vanishing Coins apply to this coin.",
    tags = { "sleight", "vanishing", "palm", "substitution" },
    typeTags = { "sleight", "vanishing" },
    mechanic_terms = { "swap_coins", "palm_failed_coin", "monte_rearrange" },
    trick_synergy = { "sleight" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_marked_coin",
    name = "Marked Coin",
    rarity = "common",
    archetype = "marked",
    activationFamily = "prediction",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_marked_coin", materialRank = 1, base_score = 10 },
    },
    description = "A marked coin that can fulfill the table's visible Prediction.",
    effectDescription = "Commit it to the predicted slot to force that slot's shown Heads or Tails result.",
    tags = { "marked", "prediction", "predicted_slot", "forced_result" },
    typeTags = { "prediction", "read" },
    mechanic_terms = { "predicted_slot", "forced_result", "foretold_result" },
    trick_synergy = { "prediction", "foretold" },
    isStarter = true,
    triggers = {},
  },
  {
    id = "copper_lucky_coin",
    name = "Lucky Coin",
    rarity = "common",
    archetype = "lucky",
    activationFamily = "fate",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    material_variants = {
      copper = { id = "copper_lucky_coin", materialRank = 1, base_score = 10 },
    },
    description = "A fate-touched coin that builds the Luck Meter.",
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
    activationFamily = "weighted",
    material = "copper",
    materialRank = 1,
    base_score = 10,
    call_match_chance = 0.65,
    material_variants = {
      copper = { id = "copper_weighted_coin", materialRank = 1, base_score = 10, call_match_chance = 0.65 },
    },
    description = "A weighted coin that leans toward your declared call.",
    effectDescription = "65% chance to match your call. Counts as a Weighted Coin for Trick bonuses.",
    tags = { "weighted", "weight", "odds", "reliable" },
    typeTags = { "weighted", "reliable" },
    mechanic_terms = { "set_call_match_chance", "call_match_chance" },
    trick_synergy = { "weighted" },
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

local MATERIALS = {
  copper = {
    rank = 1,
    rarity = "common",
    namePrefix = nil,
    weightedMatchChance = 0.65,
    luckyMatchGain = 2,
  },
  silver = {
    rank = 2,
    rarity = "uncommon",
    namePrefix = "Silver",
    weightedMatchChance = 0.75,
    luckyMatchGain = 3,
  },
  gold = {
    rank = 3,
    rarity = "rare",
    namePrefix = "Gold",
    weightedMatchChance = 0.85,
    luckyMatchGain = 4,
  },
}

local MATERIAL_ORDER = { "copper", "silver", "gold" }

local function clone(value)
  if type(value) ~= "table" then
    return value
  end

  local copied = {}
  for key, child in pairs(value) do
    copied[clone(key)] = clone(child)
  end
  return copied
end

local function materialCoinId(copperId, material)
  return string.gsub(copperId, "^copper_", material .. "_", 1)
end

local function configureMaterialBehavior(definition, material)
  local materialDefinition = MATERIALS[material]

  if definition.archetype == "weighted" then
    definition.call_match_chance = materialDefinition.weightedMatchChance

    for _, trigger in ipairs(definition.triggers or {}) do
      for _, effect in ipairs(trigger.effects or {}) do
        if effect.op == "add_weight" and effect.side == "call" then
          effect.amount = materialDefinition.weightedMatchChance - 0.5
        end
      end
    end

    definition.effectDescription = string.format(
      "%d%% chance to match your call. Counts as a Weighted Coin for Trick bonuses.",
      math.floor(materialDefinition.weightedMatchChance * 100 + 0.5)
    )
  elseif definition.archetype == "lucky" then
    for _, trigger in ipairs(definition.triggers or {}) do
      for _, effect in ipairs(trigger.effects or {}) do
        if effect.op == "add_luck" then
          effect.amount = materialDefinition.luckyMatchGain
        end
      end
    end

    definition.effectDescription = string.format(
      "+%d Luck Meter progress when this coin matches your call.",
      materialDefinition.luckyMatchGain
    )
  end
end

local function expandMaterialVariants(copperDefinitions)
  local expanded = {}

  for _, copperDefinition in ipairs(copperDefinitions) do
    local variants = {}

    for _, material in ipairs(MATERIAL_ORDER) do
      local materialDefinition = MATERIALS[material]
      variants[material] = {
        id = materialCoinId(copperDefinition.id, material),
        materialRank = materialDefinition.rank,
        rarity = materialDefinition.rarity,
        base_score = 10,
      }

      if copperDefinition.archetype == "weighted" then
        variants[material].call_match_chance = materialDefinition.weightedMatchChance
      elseif copperDefinition.archetype == "lucky" then
        variants[material].luck_gain = materialDefinition.luckyMatchGain
      end
    end

    for _, material in ipairs(MATERIAL_ORDER) do
      local materialDefinition = MATERIALS[material]
      local definition = material == "copper" and copperDefinition or clone(copperDefinition)

      definition.id = materialCoinId(copperDefinition.id, material)
      definition.name = materialDefinition.namePrefix
        and string.format("%s %s", materialDefinition.namePrefix, copperDefinition.name)
        or copperDefinition.name
      definition.material = material
      definition.materialRank = materialDefinition.rank
      definition.rarity = materialDefinition.rarity
      definition.base_score = 10
      definition.material_variants = clone(variants)
      definition.isStarter = material == "copper" and copperDefinition.isStarter == true or false
      configureMaterialBehavior(definition, material)
      table.insert(expanded, definition)
    end
  end

  return expanded
end

definitions = expandMaterialVariants(definitions)

local visualIdentities = {
  copper_bent_coin = { face = "bent", rim = "combo" },
  copper_flywheel_coin = { face = "flywheel", rim = "motion" },
  copper_blank_coin = { face = "blank", rim = "score" },
  copper_hollow_coin = { face = "hollow", rim = "motion" },
  copper_vanishing_coin = { face = "vanishing", rim = "motion" },
  copper_marked_coin = { face = "marked", rim = "safety" },
  copper_lucky_coin = { face = "lucky", rim = "combo" },
  copper_weighted_coin = { face = "weighted", rim = "weight" },
}

local byId = {}

for _, definition in ipairs(definitions) do
  local copperVisualId = string.format("copper_%s_coin", definition.archetype)
  definition.art = definition.art or visualIdentities[definition.id] or visualIdentities[copperVisualId]
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
  local unlockedIndex = buildUnlockedIndex(unlockedCoinIds)
  local candidates = {}
  local fallbackCandidates = {}
  local seed = extractSeed(source)

  for _, definition in ipairs(definitions) do
    if Coins.isUnlocked(definition, unlockedIndex) then
      local entry = {
        id = definition.id,
      }

      if definition.rarity == "common" then
        table.insert(candidates, entry)
      else
        table.insert(fallbackCandidates, entry)
      end
    end
  end

  table.sort(candidates, function(left, right)
    return left.id < right.id
  end)

  table.sort(fallbackCandidates, function(left, right)
    return left.id < right.id
  end)

  RNG.newFromText(string.format("%s:starter_coins:common", tostring(seed))):shuffle(candidates)
  RNG.newFromText(string.format("%s:starter_coins:fallback", tostring(seed))):shuffle(fallbackCandidates)

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
