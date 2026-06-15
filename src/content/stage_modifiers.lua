local definitions = {
  {
    id = "crosswind_table",
    name = "Crosswind Table",
    description = "Each coin in the flip gains +5% Tails chance before rolling.",
    tags = { "stage", "weight", "tails" },
    enemyTrick = { category = "weighted", tags = { "weighted", "weight", "tails" }, timing = "before_flip" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.05 },
        },
      },
    },
  },
  {
    id = "bright_lights",
    name = "Bright Lights",
    description = "Each coin in the flip gains +5% Heads chance before rolling.",
    tags = { "stage", "weight", "heads" },
    enemyTrick = { category = "weighted", tags = { "weighted", "weight", "heads" }, timing = "before_flip" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.05 },
        },
      },
    },
  },
  {
    id = "side_pot",
    name = "Side Pot",
    description = "+1 extra Influence after each scoring flip in this stage.",
    tags = { "stage", "payout", "influence" },
    enemyTrick = { category = "misdirection", tags = { "misdirection", "payout" }, timing = "after_score" },
    triggers = {
      {
        hook = "after_scoring",
        effects = {
          { op = "add_influence", amount = 1 },
        },
      },
    },
  },
  {
    id = "crowd_favorite",
    name = "Crowd Favorite",
    description = "Heads calls are worth 10% more score in this stage.",
    tags = { "stage", "heads", "score" },
    enemyTrick = { category = "fate", tags = { "fate", "heads", "score_scaling" }, timing = "before_score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { call = "heads" },
        effects = {
          { op = "apply_score_scaling", value = 1.10 },
        },
      },
    },
  },
}

local byId = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local StageModifiers = {}

function StageModifiers.getAll()
  return definitions
end

function StageModifiers.getById(id)
  return byId[id]
end

return StageModifiers
