local definitions = {
  {
    id = "weakened_charm",
    name = "Weakened Charm",
    description = "The marked Trick resolves at 75% effectiveness.",
    surface = "trick",
    difficultyRank = 1,
    minRound = 3,
    effect = {
      kind = "weakened",
      multiplier = 0.75,
    },
  },
  {
    id = "tarnished_slot",
    name = "Tarnished Slot",
    description = "Outcomes scored from the marked coin slot are worth 75%.",
    surface = "slot",
    difficultyRank = 1,
    minRound = 3,
    effect = {
      kind = "tarnished",
      multiplier = 0.75,
    },
  },
  {
    id = "jammed_charm",
    name = "Jammed Charm",
    description = "The marked Trick resolves for only its first activation each Flip.",
    surface = "trick",
    difficultyRank = 2,
    minRound = 4,
    effect = {
      kind = "jammed",
      maxActivations = 1,
    },
  },
  {
    id = "lifesteal_slot",
    name = "Leeching Slot",
    description = "Each matching coin in the marked slot heals 5% of the opponent's maximum health.",
    surface = "slot",
    difficultyRank = 2,
    minRound = 4,
    effect = {
      kind = "lifesteal",
      healMaxHpOnMatch = 0.05,
    },
  },
  {
    id = "blocked_charm",
    name = "Blocked Charm",
    description = "The marked Trick cannot resolve this Flip.",
    surface = "trick",
    difficultyRank = 3,
    minRound = 5,
    effect = {
      kind = "blocked",
    },
  },
  {
    id = "poisoned_charm",
    name = "Poisoned Charm",
    description = "Lose 10% of this Flip's Score for each activation of the marked Trick, up to 30%.",
    surface = "trick",
    difficultyRank = 3,
    minRound = 5,
    effect = {
      kind = "poisoned",
      scoreLossPerActivation = 0.10,
      maxStacks = 3,
    },
  },
}

local byId = {}
for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local EnemySkills = {}

function EnemySkills.getAll()
  return definitions
end

function EnemySkills.getById(id)
  return byId[id]
end

function EnemySkills.getEligible(roundIndex, options)
  options = options or {}
  local eligible = {}
  local round = math.max(1, tonumber(roundIndex) or 1)

  for _, definition in ipairs(definitions) do
    local surfaceAvailable = definition.surface ~= "trick" or options.hasActiveTricks ~= false
    if definition.minRound <= round and surfaceAvailable then
      table.insert(eligible, definition)
    end
  end

  return eligible
end

return EnemySkills
