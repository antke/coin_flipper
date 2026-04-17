local definitions = {
  {
    id = "anti_streak_warden",
    name = "Anti-Streak Warden",
    description = "Repeated calls are worth 20% less score this batch.",
    tags = { "boss", "anti_streak" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          repeated_call = true,
        },
        effects = {
          { op = "apply_score_multiplier", value = 0.80 },
        },
      },
    },
  },
  {
    id = "loaded_ledger",
    name = "Loaded Ledger",
    description = "Each equipped coin gains +0.06 Tails weight before rolling.",
    tags = { "boss", "weight", "tails" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.06 },
        },
      },
    },
  },
  {
    id = "heads_embargo",
    name = "Heads Embargo",
    description = "Heads calls are worth 15% less score during this boss fight.",
    tags = { "boss", "heads", "score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          call = "heads",
        },
        effects = {
          { op = "apply_score_multiplier", value = 0.85 },
        },
      },
    },
  },
}

local byId = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local Bosses = {}

function Bosses.getAll()
  return definitions
end

function Bosses.getById(id)
  return byId[id]
end

return Bosses
