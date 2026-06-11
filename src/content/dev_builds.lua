local Coins = require("src.content.coins")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local definitions = {
  {
    id = "weighted_coin_test",
    label = "Weighted Coins",
    description = "Loaded purse with odds and luck tricks.",
    runOptions = {
      starterCollection = {
        "copper_weighted_coin",
        "copper_lucky_coin",
        "copper_marked_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
      },
      starterPurse = {
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_lucky_coin",
        "copper_lucky_coin",
        "copper_lucky_coin",
        "copper_marked_coin",
        "copper_marked_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
      },
      ownedTrickIds = {
        "weighted_tail_coating",
        "heads_varnish",
        "weighted_palm",
        "omen_engine",
      },
      maxFlipSlots = 4,
      startingInfluence = 12,
      startingShopRerolls = 1,
    },
  },
  {
    id = "shop_economy_test",
    label = "Shop Economy",
    description = "Influence, rerolls, discounts, and refunds.",
    runOptions = {
      starterCollection = {
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
        "copper_weighted_coin",
      },
      starterPurse = {
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
        "copper_weighted_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
        "copper_weighted_coin",
      },
      ownedTrickIds = {
        "cashback_badge",
        "coupon_case",
        "showcase_rack",
        "recovery_coupon",
      },
      startingInfluence = 35,
      startingShopRerolls = 4,
    },
  },
  {
    id = "heads_tails_contract_test",
    label = "Call Contracts",
    description = "Heads/tails scoring and payout hooks.",
    runOptions = {
      starterCollection = {
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
      },
      starterPurse = {
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_marked_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
        "copper_lucky_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
        "copper_weighted_coin",
      },
      ownedTrickIds = {
        "heads_contract",
        "tails_contract",
        "heads_notebook",
        "see_behind_the_veil",
        "fulfilled_fate",
      },
      maxFlipSlots = 4,
      startingInfluence = 10,
    },
  },
  {
    id = "large_hand_slot_test",
    label = "Big Hand Slots",
    description = "More hand space, slots, and smuggling.",
    runOptions = {
      starterCollection = {
        "copper_hollow_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
      },
      starterPurse = {
        "copper_hollow_coin",
        "copper_hollow_coin",
        "copper_hollow_coin",
        "copper_hollow_coin",
        "copper_bent_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_blank_coin",
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_lucky_coin",
      },
      ownedTrickIds = {
        "roomy_bandolier",
        "sleeve_pocket",
        "switcheroo",
        "domino_line",
      },
      maxFlipSlots = 5,
      handSize = 7,
      startingInfluence = 8,
      startingShopRerolls = 2,
    },
  },
}

local byId = {}

local function assertKnownCoin(buildId, coinId)
  assert(Coins.getById(coinId), string.format("prepared build %s references unknown coin %s", buildId, tostring(coinId)))
end

local function assertKnownTrick(buildId, trickId)
  assert(Upgrades.getById(trickId), string.format("prepared build %s references unknown trick %s", buildId, tostring(trickId)))
end

for _, build in ipairs(definitions) do
  assert(type(build.id) == "string" and build.id ~= "", "prepared builds must define id")
  assert(not byId[build.id], string.format("duplicate prepared build id %s", build.id))
  assert(type(build.label) == "string" and build.label ~= "", string.format("prepared build %s must define label", build.id))

  local runOptions = build.runOptions or {}

  for _, coinId in ipairs(runOptions.starterCollection or {}) do
    assertKnownCoin(build.id, coinId)
  end

  for _, coinId in ipairs(runOptions.starterPurse or {}) do
    assertKnownCoin(build.id, coinId)
  end

  for _, trickId in ipairs(runOptions.ownedTrickIds or runOptions.ownedUpgradeIds or {}) do
    assertKnownTrick(build.id, trickId)
  end

  byId[build.id] = build
end

local DevBuilds = {}

function DevBuilds.getAll()
  return definitions
end

function DevBuilds.getById(id)
  return byId[id]
end

function DevBuilds.resolve(id, seed)
  local build = byId[id]

  if not build then
    return nil, string.format("unknown_prepared_build:%s", tostring(id))
  end

  local runOptions = Utils.clone(build.runOptions or {})
  runOptions.seed = seed

  return runOptions
end

return DevBuilds
