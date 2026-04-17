local Utils = require("src.core.utils")

local definitions = {
  {
    id = "round_1",
    name = "Opening Toss",
    roundIndex = 1,
    label = "Round 1 — Opening Toss",
    stageType = "normal",
    targetScore = 8,
    activeStageModifierIds = { "bright_lights" },
  },
  {
    id = "round_2",
    name = "Mid Table",
    roundIndex = 2,
    label = "Round 2 — Mid Table",
    stageType = "normal",
    targetScore = 11,
    activeStageModifierIds = { "crosswind_table" },
    variants = {
      {
        id = "round_2_crosswind",
        name = "Crosswind Table",
        label = "Round 2 — Crosswind Table",
        activeStageModifierIds = { "crosswind_table" },
      },
      {
        id = "round_2_side_pot",
        name = "Side Pot",
        label = "Round 2 — Side Pot",
        activeStageModifierIds = { "side_pot" },
      },
    },
  },
  {
    id = "round_3",
    name = "Build Check",
    roundIndex = 3,
    label = "Round 3 — Build Check",
    stageType = "normal",
    targetScore = 14,
    activeStageModifierIds = { "echo_chamber", "side_pot" },
    variants = {
      {
        id = "round_3_echo",
        name = "Echo Chamber",
        label = "Round 3 — Echo Chamber",
        activeStageModifierIds = { "echo_chamber", "side_pot" },
      },
      {
        id = "round_3_house_lights",
        name = "House Lights",
        label = "Round 3 — House Lights",
        activeStageModifierIds = { "bright_lights", "echo_chamber" },
      },
    },
  },
  {
    id = "boss_round",
    name = "Final Table",
    roundIndex = 4,
    label = "Boss — Final Table",
    stageType = "boss",
    targetScore = 18,
    bossModifierIds = { "anti_streak_warden", "loaded_ledger" },
    bossVariants = {
      {
        id = "boss_variant_warden",
        name = "Anti-Streak Warden",
        label = "Boss — Anti-Streak Warden",
        bossModifierIds = { "anti_streak_warden", "loaded_ledger" },
      },
      {
        id = "boss_variant_embargo",
        name = "Heads Embargo",
        label = "Boss — Heads Embargo",
        bossModifierIds = { "heads_embargo", "loaded_ledger" },
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
  local variantIndex = ((seed + (definition.roundIndex or 1) - 2) % #variants) + 1
  local variant = variants[variantIndex]
  local resolved = Utils.clone(definition)

  resolved.variants = nil
  resolved.bossVariants = nil
  resolved.variantId = variant.id
  resolved.variantName = variant.name or variant.id
  resolved.name = variant.name or resolved.name
  resolved.label = variant.label or resolved.label
  resolved.targetScore = variant.targetScore or resolved.targetScore
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
