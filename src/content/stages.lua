local Utils = require("src.core.utils")
local RNG = require("src.core.rng")

local definitions = {
  {
    id = "round_1",
    name = "Opening Toss",
    roundIndex = 1,
    label = "Round 1 — Opening Toss",
    stageType = "normal",
    opponentHp = 40,
    opponent = {
      id = "bright_lights_dealer",
      name = "Bright-Lights Dealer",
      enemyClass = "card_shark",
      description = "A house dealer trying to rattle your opening call.",
      hp = 40,
    },
    activeStageModifierIds = { "bright_lights" },
  },
  {
    id = "round_2",
    name = "Mid Table",
    roundIndex = 2,
    label = "Round 2 — Mid Table",
    stageType = "normal",
    opponentHp = 55,
    opponent = {
      id = "mid_table_sharp",
      name = "Mid-Table Sharp",
      enemyClass = "forger",
      description = "A patient gambler with just enough tricks to test your pouch.",
      hp = 55,
    },
    activeStageModifierIds = { "crosswind_table" },
    variants = {
      {
        id = "round_2_crosswind",
        name = "Crosswind Table",
        label = "Round 2 — Crosswind Table",
        opponent = {
          id = "crosswind_sharp",
          name = "Crosswind Sharp",
          enemyClass = "card_shark",
          description = "A sideways-smiling gambler leaning on the table draft.",
        },
        activeStageModifierIds = { "crosswind_table" },
      },
      {
        id = "round_2_side_pot",
        name = "Side Pot",
        label = "Round 2 — Side Pot",
        opponent = {
          id = "side_pot_bruiser",
          name = "Side-Pot Bruiser",
          enemyClass = "pit_boss",
          description = "A loud bettor who turns every good hit into more heat.",
        },
        activeStageModifierIds = { "side_pot" },
      },
      {
        id = "round_2_crowd_favorite",
        name = "Crowd Favorite",
        label = "Round 2 — Crowd Favorite",
        opponent = {
          id = "crowd_favorite",
          name = "Crowd Favorite",
          enemyClass = "fortune_teller",
          description = "A smiling regular with the room on their side.",
        },
        activeStageModifierIds = { "crowd_favorite" },
      },
    },
  },
  {
    id = "round_3",
    name = "Build Check",
    roundIndex = 3,
    label = "Round 3 — Build Check",
    stageType = "normal",
    opponentHp = 65,
    opponent = {
      id = "build_check_hustler",
      name = "Build-Check Hustler",
      enemyClass = "smuggler",
      description = "A harder mark who punishes loose coin choices.",
      hp = 65,
    },
    activeStageModifierIds = { "side_pot" },
    variants = {
      {
        id = "round_3_house_lights",
        name = "House Lights",
        label = "Round 3 — House Lights",
        opponent = {
          id = "house_lights_hustler",
          name = "House-Lights Hustler",
          enemyClass = "magician",
          description = "A polished opponent who thrives under bright pressure.",
        },
        activeStageModifierIds = { "bright_lights", "side_pot" },
      },
      {
        id = "round_3_long_game",
        name = "Long Game",
        label = "Round 3 — Long Game",
        opponent = {
          id = "long_game_grinder",
          name = "Long-Game Grinder",
          enemyClass = "showman",
          description = "A stubborn table fixture built to survive one more flip.",
        },
        activeStageModifierIds = { "crosswind_table", "side_pot" },
      },
    },
  },
  {
    id = "boss_round",
    name = "Boss Round",
    roundIndex = 4,
    label = "Boss Round",
    stageType = "boss",
    opponentHp = 80,
    opponent = {
      id = "boss_opponent",
      name = "Boss",
      enemyClass = "card_shark",
      description = "Boss Trick",
      hp = 80,
    },
    bossVariants = {
      {
        id = "boss_betting_betty",
        name = "Betting Betty",
        label = "Boss — Betting Betty",
        opponent = {
          id = "betting_betty",
          name = "Betting Betty",
          enemyClass = "card_shark",
          description = "The Favourite",
        },
        bossModifierIds = { "betting_betty" },
      },
      {
        id = "boss_washed_up_magician",
        name = "Washed-up Magician",
        label = "Boss — Washed-up Magician",
        opponent = {
          id = "washed_up_magician",
          name = "Washed-up Magician",
          enemyClass = "magician",
          description = "Centre Stage",
        },
        bossModifierIds = { "washed_up_magician" },
      },
      {
        id = "boss_madcap_lunatic",
        name = "Madcap Lunatic",
        label = "Boss — Madcap Lunatic",
        opponent = {
          id = "madcap_lunatic",
          name = "Madcap Lunatic",
          enemyClass = "showman",
          description = "Full Throttle",
        },
        bossModifierIds = { "madcap_lunatic" },
      },
      {
        id = "boss_the_impostor",
        name = "The Impostor",
        label = "Boss — The Impostor",
        opponent = {
          id = "the_impostor",
          name = "The Impostor",
          enemyClass = "forger",
          description = "Stolen Identity",
        },
        bossModifierIds = { "the_impostor" },
      },
      {
        id = "boss_the_quickhand",
        name = "The Quickhand",
        label = "Boss — The Quickhand",
        opponentHp = 60,
        opponent = {
          id = "the_quickhand",
          name = "The Quickhand",
          enemyClass = "card_shark",
          description = "Three Cups",
          hp = 60,
        },
        bossModifierIds = { "the_quickhand" },
      },
      {
        id = "boss_the_taxman",
        name = "The Taxman",
        label = "Boss — The Taxman",
        opponent = {
          id = "the_taxman",
          name = "The Taxman",
          enemyClass = "pit_boss",
          description = "Nothing to Declare",
        },
        bossModifierIds = { "the_taxman" },
      },
      {
        id = "boss_blind_prophet",
        name = "Blind Prophet",
        label = "Boss — Blind Prophet",
        opponent = {
          id = "blind_prophet",
          name = "Blind Prophet",
          enemyClass = "seer",
          description = "Written in Stone",
        },
        bossModifierIds = { "blind_prophet" },
      },
    },
  },
}

local byId = {}
local byRound = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
  byRound[definition.roundIndex] = definition

  for _, variant in ipairs(definition.variants or {}) do
    byId[variant.id] = variant
  end

  for _, variant in ipairs(definition.bossVariants or {}) do
    byId[variant.id] = variant
  end
end

local Stages = {}

local function extractSeed(source)
  if type(source) == "number" then
    return source
  end

  if type(source) == "table" then
    return source.seed
  end

  return nil
end

local function resolveVariant(definition, variants, source)
  variants = variants or nil

  if not variants or #variants == 0 then
    return definition
  end

  local seed = extractSeed(source) or 1
  local orderedVariants = {}

  for _, variant in ipairs(variants) do
    table.insert(orderedVariants, variant)
  end

  table.sort(orderedVariants, function(left, right)
    return (left.id or "") < (right.id or "")
  end)

  local decisionKey = table.concat({
    tostring(seed),
    "stage_variant",
    tostring(definition.roundIndex or 1),
    tostring(definition.id or "unknown_stage"),
  }, ":")
  local variant = RNG.newFromText(decisionKey):choose(orderedVariants)

  if not variant then
    return definition
  end
  local resolved = Utils.clone(definition)

  resolved.variants = nil
  resolved.bossVariants = nil
  resolved.variantId = variant.id
  resolved.variantName = variant.name or variant.id
  resolved.name = variant.name or resolved.name
  resolved.label = variant.label or resolved.label
  resolved.opponentHp = variant.opponentHp or variant.targetScore or resolved.opponentHp or resolved.targetScore
  resolved.targetScore = resolved.opponentHp
  resolved.opponent = Utils.clone(resolved.opponent or {})
  for key, value in pairs(variant.opponent or {}) do
    resolved.opponent[key] = Utils.clone(value)
  end
  resolved.opponent.hp = resolved.opponent.hp or resolved.opponentHp or resolved.targetScore
  resolved.activeStageModifierIds = Utils.copyArray(variant.activeStageModifierIds or resolved.activeStageModifierIds or {})
  resolved.bossModifierIds = Utils.copyArray(variant.bossModifierIds or resolved.bossModifierIds or {})

  return resolved
end

function Stages.getAll()
  return definitions
end

function Stages.getById(id)
  return byId[id]
end

function Stages.getForRound(roundIndex, source)
  local definition = byRound[roundIndex]

  if not definition then
    return nil
  end

  if definition.stageType == "boss" then
    return resolveVariant(definition, definition.bossVariants, source)
  end

  return resolveVariant(definition, definition.variants, source)
end

return Stages
