local definitions = {
  {
    id = "meta_shop_efficiency_1",
    name = "Merchant's Favor I",
    description = "+10% shop point gain in runs.",
    cost = 2,
    tags = { "meta", "economy" },
    effectiveValues = {
      ["economy.shopPointMultiplier"] = 1.10,
    },
  },
  {
    id = "meta_bonus_slot_1",
    name = "Extra Pouch",
    description = "+1 max active coin slot in runs.",
    cost = 4,
    tags = { "meta", "slots" },
    effectiveValues = {
      ["run.maxActiveCoinSlots"] = 1,
    },
  },
  {
    id = "meta_bonus_points_1",
    name = "Traveler's Change",
    description = "+2 starting shop points in runs.",
    cost = 2,
    tags = { "meta", "economy" },
    effectiveValues = {
      ["run.startingShopPoints"] = 2,
    },
  },
  {
    id = "meta_bonus_reroll_1",
    name = "Spare Voucher",
    description = "+1 free shop reroll per run.",
    cost = 3,
    tags = { "meta", "shop" },
    effectiveValues = {
      ["run.startingShopRerolls"] = 1,
    },
  },
  {
    id = "meta_unlock_streak_drill",
    name = "Pattern Primer",
    description = "Unlock Streak Drill and Safety Net for future runs and shops.",
    cost = 3,
    tags = { "meta", "unlock", "coin" },
    unlockCoinIds = { "streak_drill", "safety_net" },
  },
  {
    id = "meta_unlock_merchant_tools",
    name = "Merchant Toolbelt",
    description = "Unlock Cashback Badge, Showcase Rack, Contraband Case, and Recovery Coupon for future shops.",
    cost = 4,
    tags = { "meta", "unlock", "shop" },
    unlockUpgradeIds = { "cashback_badge", "showcase_rack", "contraband_case", "recovery_coupon" },
  },
  {
    id = "meta_unlock_tactical_notes",
    name = "Tactical Notes",
    description = "Unlock Echo Cache, Reserve Fuse, and Boss Banner for future runs and shops.",
    cost = 5,
    tags = { "meta", "unlock", "strategy" },
    unlockUpgradeIds = { "echo_cache", "reserve_fuse", "boss_banner" },
  },
  {
    id = "meta_shop_quality_1",
    name = "Curated Stock",
    description = "Future shops favor uncommon and rare offers.",
    cost = 4,
    tags = { "meta", "shop", "quality" },
    effectiveValues = {
      ["shop.rarityWeight.uncommon"] = 1.35,
      ["shop.rarityWeight.rare"] = 1.20,
    },
  },
  {
    id = "meta_bonus_starter_1",
    name = "Expanded Roll Case",
    description = "+1 starting coin in future runs.",
    cost = 4,
    tags = { "meta", "opening", "collection" },
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

function MetaUpgrades.getAll()
  return definitions
end

function MetaUpgrades.getById(id)
  return byId[id]
end

return MetaUpgrades
