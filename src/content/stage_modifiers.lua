local definitions = {
  {
    id = "crosswind_table",
    name = "Crosswind Table",
    description = "Each equipped coin gains +0.05 Tails weight before rolling.",
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
    description = "Each equipped coin gains +0.05 Heads weight before rolling.",
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
    id = "echo_chamber",
    name = "Echo Chamber",
    description = "Repeated calls are worth 15% less score in this stage.",
    tags = { "stage", "anti_streak" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          repeated_call = true,
        },
        effects = {
          { op = "apply_score_multiplier", value = 0.85 },
        },
      },
    },
  },
  {
    id = "side_pot",
    name = "Side Pot",
    description = "+1 shop point after each scored batch in this stage.",
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
