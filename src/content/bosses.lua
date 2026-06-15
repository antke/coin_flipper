local definitions = {
  {
    id = "weighted_ledger",
    name = "Weighted Ledger",
    description = "Each coin in the flip gains +6% Tails chance before rolling.",
    tags = { "boss", "weight", "tails" },
    enemyTrick = { category = "weighted", tags = { "weighted", "weight", "tails" }, timing = "before_flip" },
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
    enemyTrick = { category = "misdirection", tags = { "misdirection", "heads", "score_scaling" }, timing = "before_score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          call = "heads",
        },
        effects = {
          { op = "apply_score_scaling", value = 0.85 },
        },
      },
    },
  },
  {
    id = "tails_embargo",
    name = "Tails Embargo",
    description = "Tails calls are worth 15% less score during this boss fight.",
    tags = { "boss", "tails", "score" },
    enemyTrick = { category = "misdirection", tags = { "misdirection", "tails", "score_scaling" }, timing = "before_score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          call = "tails",
        },
        effects = {
          { op = "apply_score_scaling", value = 0.85 },
        },
      },
    },
  },
  {
    id = "stacked_deck",
    name = "Stacked Deck",
    description = "Each coin in the flip gains +6% Heads chance before rolling.",
    tags = { "boss", "weight", "heads" },
    enemyTrick = { category = "weighted", tags = { "weighted", "weight", "heads" }, timing = "before_flip" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.06 },
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
