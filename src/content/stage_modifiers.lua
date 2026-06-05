local definitions = {
  {
    id = "crosswind_table",
    name = "Crosswind Table",
    description = "Each equipped coin gains +5% Tails chance before rolling.",
    tags = { "stage", "weight", "tails" },
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
    description = "Each equipped coin gains +5% Heads chance before rolling.",
    tags = { "stage", "weight", "heads" },
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
    description = "+1 extra Chip after each scored batch in this stage.",
    tags = { "stage", "economy" },
    triggers = {
      {
        hook = "after_scoring",
        effects = {
          { op = "add_shop_points", amount = 1 },
        },
      },
    },
  },
  {
    id = "crowd_favorite",
    name = "Crowd Favorite",
    description = "Heads calls are worth 10% more score in this stage.",
    tags = { "stage", "heads", "score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { call = "heads" },
        effects = {
          { op = "apply_score_multiplier", value = 1.10 },
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
