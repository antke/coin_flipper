local definitions = {
  {
    id = "weighted_tail_coating",
    name = "Weighted Tail Coating",
    rarity = "uncommon",
    description = "All equipped coins gain +0.15 Tails weight.",
    tags = { "tails", "weight" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.15 },
        },
      },
    },
  },
  {
    id = "merchant_notebook",
    name = "Merchant Notebook",
    rarity = "common",
    description = "+1 shop point after scoring each batch.",
    tags = { "economy" },
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
    id = "steady_hand",
    name = "Steady Hand",
    rarity = "common",
    description = "Applies a 1.10x score multiplier before scoring.",
    tags = { "multiplier" },
    triggers = {
      {
        hook = "before_scoring",
        effects = {
          { op = "apply_score_multiplier", value = 1.10 },
        },
      },
    },
  },
  {
    id = "roomy_bandolier",
    name = "Roomy Bandolier",
    rarity = "rare",
    description = "+1 max active coin slot for the run.",
    tags = { "slots" },
    onAcquire = {
      { op = "increase_coin_slots", amount = 1 },
    },
  },
  {
    id = "starter_grant",
    name = "Starter Grant",
    rarity = "common",
    description = "+2 shop points on acquire.",
    tags = { "economy" },
    onAcquire = {
      { op = "add_shop_points", amount = 2 },
    },
  },
  {
    id = "heads_varnish",
    name = "Heads Varnish",
    rarity = "common",
    description = "All equipped coins gain +0.12 Heads weight.",
    tags = { "heads", "weight" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.12 },
        },
      },
    },
  },
  {
    id = "boss_banner",
    name = "Boss Banner",
    rarity = "uncommon",
    unlockedByDefault = false,
    description = "Applies a 1.35x score multiplier during boss stages.",
    tags = { "boss", "multiplier" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { stage_type = "boss" },
        effects = {
          { op = "apply_score_multiplier", value = 1.35 },
        },
      },
    },
  },
  {
    id = "coupon_case",
    name = "Coupon Case",
    rarity = "common",
    description = "Gain 1 free shop reroll for the rest of the run.",
    tags = { "economy", "shop" },
    onAcquire = {
      { op = "add_shop_rerolls", amount = 1 },
    },
  },
  {
    id = "showcase_rack",
    name = "Showcase Rack",
    rarity = "uncommon",
    unlockedByDefault = false,
    rewardEligible = false,
    description = "Upgrade offers cost 1 less in future shops.",
    tags = { "shop", "discount" },
    triggers = {
      {
        hook = "after_shop_generation",
        condition = { offer_type = "upgrade" },
        effects = {
          { op = "adjust_shop_price", delta = -1 },
        },
      },
    },
  },
  {
    id = "contraband_case",
    name = "Contraband Case",
    rarity = "rare",
    unlockedByDefault = false,
    rewardEligible = false,
    description = "Future shops add an extra Boss Biter coin offer.",
    tags = { "shop", "offer" },
    triggers = {
      {
        hook = "before_shop_generation",
        effects = {
          { op = "add_shop_offer", offerType = "coin", contentId = "boss_biter" },
          { op = "add_shop_message", message = "Contraband Case smuggled in a bonus coin offer." },
        },
      },
    },
  },
  {
    id = "cashback_badge",
    name = "Cashback Badge",
    rarity = "common",
    unlockedByDefault = false,
    rewardEligible = false,
    description = "Buying upgrades refunds 1 shop point in future shops.",
    tags = { "shop", "economy" },
    triggers = {
      {
        hook = "after_purchase",
        condition = { purchase_type = "upgrade" },
        effects = {
          { op = "add_shop_points", amount = 1 },
          { op = "add_shop_message", message = "Cashback Badge refunded 1 shop point." },
        },
      },
    },
  },
  {
    id = "echo_cache",
    name = "Echo Cache",
    rarity = "uncommon",
    unlockedByDefault = false,
    description = "At batch start, create a temporary echo for this batch: if every equipped coin matches, gain +1 shop point.",
    tags = { "temporary", "shop", "all_match" },
    triggers = {
      {
        hook = "on_batch_start",
        effects = {
          {
            op = "grant_temporary_effect",
            effect = {
              id = "echo_cache_echo",
              name = "Echo Cache Echo",
              description = "This batch only: if every equipped coin matches, gain +1 shop point.",
              triggers = {
                {
                  hook = "after_scoring",
                  condition = { all_matched = true },
                  effects = {
                    { op = "add_shop_points", amount = 1 },
                    { op = "queue_trace_note", note = "Echo Cache paid out." },
                  },
                },
                {
                  hook = "on_batch_end",
                  effects = {
                    { op = "consume_effect" },
                  },
                },
              },
            },
          },
        },
      },
    },
  },
  {
    id = "tails_contract",
    name = "Tails Contract",
    rarity = "common",
    description = "Tails calls are worth 1.15x score.",
    tags = { "tails", "multiplier" },
    triggers = {
      {
        hook = "before_scoring",
        condition = { call = "tails" },
        effects = {
          { op = "apply_score_multiplier", value = 1.15 },
        },
      },
    },
  },
  {
    id = "insurance_ledger",
    name = "Insurance Ledger",
    rarity = "common",
    description = "If no coins match this batch, gain +2 shop points.",
    tags = { "economy", "safety" },
    triggers = {
      {
        hook = "on_batch_end",
        condition = { no_matches = true },
        effects = {
          { op = "add_shop_points", amount = 2 },
        },
      },
    },
  },
  {
    id = "recovery_coupon",
    name = "Recovery Coupon",
    rarity = "uncommon",
    unlockedByDefault = false,
    rewardEligible = false,
    description = "Buying a coin grants 1 free shop reroll.",
    tags = { "shop", "economy", "coin" },
    triggers = {
      {
        hook = "after_purchase",
        condition = { purchase_type = "coin" },
        effects = {
          { op = "add_shop_rerolls", amount = 1 },
          { op = "add_shop_message", message = "Recovery Coupon granted a free reroll." },
        },
      },
    },
  },
  {
    id = "reserve_fuse",
    name = "Reserve Fuse",
    rarity = "rare",
    unlockedByDefault = false,
    description = "If every equipped coin matches, queue +1 stage score and +1 run score before the stage-end check.",
    tags = { "chain", "threshold", "all_match" },
    triggers = {
      {
        hook = "after_scoring",
        condition = { all_matched = true },
        effects = {
          {
            op = "queue_actions",
            phase = "before_stage_end_check",
            actions = {
              { op = "add_stage_score", amount = 1, category = "chain_bonus", label = "Reserve Fuse" },
              { op = "add_run_score", amount = 1, category = "chain_bonus", label = "Reserve Fuse" },
              { op = "queue_trace_note", note = "Reserve Fuse fired before the stage-end check." },
            },
          },
        },
      },
    },
  },
}

local byId = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local Upgrades = {}

local function buildUnlockedIndex(unlockedUpgradeIds)
  local unlockedIndex = {}

  if type(unlockedUpgradeIds) ~= "table" then
    return unlockedIndex
  end

  for key, value in pairs(unlockedUpgradeIds) do
    if type(key) == "string" and value == true then
      unlockedIndex[key] = true
    elseif type(value) == "string" and value ~= "" then
      unlockedIndex[value] = true
    end
  end

  return unlockedIndex
end

function Upgrades.getAll()
  return definitions
end

function Upgrades.getById(id)
  return byId[id]
end

function Upgrades.isUnlocked(definition, unlockedUpgradeIds)
  if not definition then
    return false
  end

  if definition.unlockedByDefault ~= false then
    return true
  end

  local unlockedIndex = buildUnlockedIndex(unlockedUpgradeIds)
  return unlockedIndex[definition.id] == true
end

function Upgrades.getUnlockedIds(unlockedUpgradeIds)
  local unlockedIds = {}
  local unlockedIndex = buildUnlockedIndex(unlockedUpgradeIds)

  for _, definition in ipairs(definitions) do
    if definition.unlockedByDefault ~= false or unlockedIndex[definition.id] then
      table.insert(unlockedIds, definition.id)
    end
  end

  return unlockedIds
end

function Upgrades.getDefaultUnlockedIds()
  return Upgrades.getUnlockedIds({})
end

return Upgrades
