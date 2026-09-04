local definitions = {
  {
    id = "meta_shop_efficiency_1",
    name = "Favor Ink I",
    description = "When equipped, +10% Influence gain in runs.",
    cost = 2,
    tags = { "tattoo", "influence", "payout" },
    tattoo = {
      category = "influence",
      tags = { "influence", "payout" },
      tier = 1,
    },
    effectiveValues = {
      ["economy.influenceMultiplier"] = 1.10,
    },
  },
  {
    id = "meta_bonus_slot_1",
    name = "Wide Pouch Tattoo",
    description = "When equipped, +1 max Flip Slot in runs.",
    cost = 4,
    tags = { "tattoo", "flip_slot", "pouch" },
    tattoo = {
      category = "pouch",
      tags = { "pouch", "flip_slot" },
      tier = 1,
    },
    effectiveValues = {
      ["run.maxFlipSlots"] = 1,
    },
  },
  {
    id = "meta_bonus_points_1",
    name = "Traveler's Mark",
    description = "When equipped, +2 extra starting Influence in runs.",
    cost = 2,
    tags = { "tattoo", "influence", "opening" },
    tattoo = {
      category = "opening",
      tags = { "opening", "influence" },
      tier = 1,
    },
    effectiveValues = {
      ["run.startingInfluence"] = 2,
    },
  },
  {
    id = "meta_bonus_reroll_1",
    name = "Spare Voucher Ink",
    description = "When equipped, +1 Free Reroll per run.",
    cost = 3,
    tags = { "tattoo", "black_market", "reroll" },
    tattoo = {
      category = "black_market",
      tags = { "black_market", "reroll" },
      tier = 1,
    },
    effectiveValues = {
      ["run.startingShopRerolls"] = 1,
    },
  },
  {
    id = "meta_unlock_tactical_notes",
    name = "Tactical Notes Tattoo",
    description = "Unlock Echo Wager and Rainy Day Voucher for future runs and Black Markets.",
    cost = 5,
    tags = { "tattoo", "unlock", "strategy" },
    tattoo = {
      category = "unlock",
      tags = { "unlock", "strategy" },
      tier = 1,
    },
    unlockUpgradeIds = { "echo_cache", "rainy_day_fund" },
  },
  {
    id = "meta_shop_quality_1",
    name = "Curated Stock Tattoo",
    description = "When equipped, future Black Markets favor uncommon and rare offers.",
    cost = 4,
    tags = { "tattoo", "black_market", "quality" },
    tattoo = {
      category = "black_market",
      tags = { "black_market", "quality" },
      tier = 1,
    },
    effectiveValues = {
      ["shop.rarityWeight.uncommon"] = 1.35,
      ["shop.rarityWeight.rare"] = 1.20,
    },
  },
  {
    id = "meta_bonus_starter_1",
    name = "Expanded Roll Case Tattoo",
    description = "When equipped, +1 starting coin in future runs.",
    cost = 4,
    tags = { "tattoo", "opening", "collection" },
    tattoo = {
      category = "opening",
      tags = { "opening", "collection" },
      tier = 1,
    },
    effectiveValues = {
      ["run.startingCollectionSize"] = 1,
    },
  },
}

local byId = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local MetaUpgrades = {}
local TATTOO_EQUIP_LIMIT = 3

function MetaUpgrades.getAll()
  return definitions
end

function MetaUpgrades.getById(id)
  return byId[id]
end

function MetaUpgrades.getEquipLimit()
  return TATTOO_EQUIP_LIMIT
end

function MetaUpgrades.isEquipEligible(definition)
  return definition ~= nil and (definition.effectiveValues ~= nil or definition.runModifiers ~= nil)
end

return MetaUpgrades
