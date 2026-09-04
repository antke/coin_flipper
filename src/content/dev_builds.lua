local Coins = require("src.content.coins")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local definitions = {
  {
    id = "weighted_coin_test",
    label = "Weighted Coins",
    description = "A focused Weighted engine with Prestige and Momentum support.",
    runOptions = {
      starterCollection = {
        "copper_weighted_coin",
        "copper_flywheel_coin",
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
        "copper_flywheel_coin",
        "copper_flywheel_coin",
        "copper_bent_coin",
        "copper_bent_coin",
        "copper_marked_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
      },
      ownedTrickIds = {
        "weighted_tail_coating",
        "heads_varnish",
        "weighted_palm",
        "encore",
        "keep_it_rolling",
      },
      maxFlipSlots = 3,
      startingInfluence = 12,
      startingShopRerolls = 1,
    },
  },
  {
    id = "shop_economy_test",
    label = "Prestige + Forgery",
    description = "A Prestige engine that positions Blank Coins after Bent Coins to counterfeit extra Prestige activations.",
    runOptions = {
      starterCollection = {
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
        "copper_marked_coin",
        "copper_flywheel_coin",
        "copper_weighted_coin",
      },
      starterPurse = {
        "copper_bent_coin",
        "copper_bent_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "silver_blank_coin",
        "gold_blank_coin",
        "copper_bent_coin",
        "copper_weighted_coin",
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_flywheel_coin",
        "copper_hollow_coin",
      },
      ownedTrickIds = {
        "encore_iii",
        "curtain_call_ii",
        "impossible_finale_iii",
        "borrowed_name_ii",
        "forged_signature_iii",
      },
      maxFlipSlots = 3,
      startingInfluence = 35,
      startingShopRerolls = 4,
    },
  },
  {
    id = "heads_tails_contract_test",
    label = "Prediction Lines",
    description = "Foretold self-payoff, neighbour influence and sacrifice play.",
    runOptions = {
      starterCollection = {
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_flywheel_coin",
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
        "copper_flywheel_coin",
        "copper_flywheel_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_hollow_coin",
        "copper_weighted_coin",
      },
      ownedTrickIds = {
        "fulfilled_fate",
        "read_the_stars",
        "written_in_the_stars",
        "defy_fate",
        "encore",
      },
      maxFlipSlots = 3,
      startingInfluence = 10,
    },
  },
  {
    id = "large_hand_slot_test",
    label = "Mixed Family Board",
    description = "Five active families competing for a persistent five-coin hand.",
    runOptions = {
      starterCollection = {
        "copper_hollow_coin",
        "copper_bent_coin",
        "copper_blank_coin",
        "copper_weighted_coin",
        "copper_marked_coin",
        "copper_flywheel_coin",
        "copper_vanishing_coin",
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
        "copper_flywheel_coin",
        "copper_vanishing_coin",
        "copper_vanishing_coin",
      },
      ownedTrickIds = {
        "hidden_pocket",
        "hidden_in_plain_sight",
        "switcheroo",
        "vanishing_act",
        "keep_it_rolling",
      },
      maxFlipSlots = 3,
      handSize = 5,
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
  local definition = Upgrades.getById(trickId)
  assert(definition, string.format("prepared build %s references unknown trick %s", buildId, tostring(trickId)))
  assert(
    definition.familyTriggerStatus == "converted",
    string.format("prepared build %s references inactive trick %s", buildId, tostring(trickId))
  )
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
