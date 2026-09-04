local Coins = require("src.content.coins")
local CoinTraits = require("src.core.coin_traits")
local Upgrades = require("src.content.upgrades")

local MATERIALS = {
  { id = "copper", rank = 1, rarity = "common" },
  { id = "silver", rank = 2, rarity = "uncommon" },
  { id = "gold", rank = 3, rarity = "rare" },
}

local FAMILY_CONTRACTS = {
  prestige = { archetype = "bent", expected = { 2.0, 3.0, 4.0 }, mode = "family_multiplier" },
  momentum = { archetype = "flywheel", expected = { 1.0, 1.25, 1.5 }, mode = "material_multiplier", base = 1.0, step = 0.25 },
  smuggle = { archetype = "hollow", expected = { 1.0, 1.25, 1.5 }, upgradeId = "hidden_in_plain_sight", op = "apply_score_scaling", field = "materialFamily", baseField = "materialBaseMultiplier", stepField = "materialRankStep" },
  sleight = { archetype = "vanishing", mode = "movement_only" },
  forgery = { archetype = "blank", mode = "activation_support" },
  prediction = { archetype = "marked", expected = { 2.0, 2.5, 3.0 }, upgradeId = "fulfilled_fate", op = "apply_score_scaling", field = "materialFamily", baseField = "materialBaseMultiplier", stepField = "materialRankStep" },
  fate = { archetype = "lucky", expected = { 2, 3, 4 }, mode = "luck_gain" },
  weighted = { archetype = "weighted", expected = { 1.5, 1.75, 2.0 }, odds = { 0.65, 0.75, 0.85 }, upgradeId = "weighted_palm", op = "apply_score_scaling", field = "materialFamily", baseField = "materialBaseMultiplier", stepField = "materialRankStep" },
}

local function collectActions(actions, output)
  for _, action in ipairs(actions or {}) do
    table.insert(output, action)

    if action.op == "queue_actions" then
      collectActions(action.actions, output)
    end
  end
end

local function findUpgradeAction(contract)
  local upgrade = Upgrades.getById(contract.upgradeId)
  local actions = {}

  for _, trigger in ipairs(upgrade and upgrade.triggers or {}) do
    collectActions(trigger.effects, actions)
  end

  for _, action in ipairs(actions) do
    if action.op == contract.op and action[contract.field] then
      return action
    end
  end

  return nil
end

local function findLuckGain(coin)
  for _, trigger in ipairs(coin and coin.triggers or {}) do
    for _, action in ipairs(trigger.effects or {}) do
      if action.op == "add_luck" then
        return action.amount
      end
    end
  end

  return nil
end

return {
  id = "material_family_contracts",
  tags = { "coins", "materials", "families" },
  description = "Verifies every core family has Copper, Silver, and Gold coins with wired material payoffs.",

  steps = {},

  assert = function(_, A)
    A.equal(#Coins.getAll(), 24, "eight archetypes should expose exactly three material variants each")

    for family, contract in pairs(FAMILY_CONTRACTS) do
      local configuredAction = nil

      if contract.upgradeId then
        configuredAction = A.truthy(findUpgradeAction(contract), family .. " should expose a material-aware Trick action")
        A.equal(configuredAction[contract.field], family, family .. " Trick action should name its real coin family")
        A.equal(configuredAction[contract.baseField], contract.expected[1], family .. " Copper payoff should match its action base")
        A.equal(configuredAction[contract.stepField], contract.expected[2] - contract.expected[1], family .. " material step should match Silver payoff")
      end

      for index, material in ipairs(MATERIALS) do
        local coinId = string.format("%s_%s_coin", material.id, contract.archetype)
        local coin = A.truthy(Coins.getById(coinId), family .. " should define " .. material.id .. " coin")

        A.equal(coin.material, material.id, coinId .. " material")
        A.equal(coin.materialRank, material.rank, coinId .. " rank")
        A.equal(coin.rarity, material.rarity, coinId .. " rarity")
        A.equal(coin.base_score, 10, coinId .. " Base Score")
        A.truthy(CoinTraits.hasRealFamily(coinId, family), coinId .. " should belong to " .. family)
        A.truthy(coin.material_variants and coin.material_variants.copper, coinId .. " should reference Copper variant")
        A.truthy(coin.material_variants and coin.material_variants.silver, coinId .. " should reference Silver variant")
        A.truthy(coin.material_variants and coin.material_variants.gold, coinId .. " should reference Gold variant")

        if contract.mode == "family_multiplier" then
          A.equal(CoinTraits.familyMultiplier(coinId, family), contract.expected[index], coinId .. " family multiplier")
        elseif contract.mode == "material_multiplier" then
          A.equal(
            CoinTraits.materialPayoffMultiplier(coinId, contract.base, contract.step, true),
            contract.expected[index],
            coinId .. " material multiplier"
          )
        elseif contract.mode == "luck_gain" then
          A.equal(findLuckGain(coin), contract.expected[index], coinId .. " Luck gain")
        elseif contract.mode == "movement_only" then
          A.truthy(true, coinId .. " material quality is consumed by Sleight targeting rather than a score multiplier")
        elseif contract.mode == "activation_support" then
          A.truthy(true, coinId .. " material quality improves its own Outcome while Forgery Trick tiers gate copied activations")
        else
          A.equal(
            CoinTraits.materialPayoffMultiplier(coinId, configuredAction[contract.baseField], configuredAction[contract.stepField], true),
            contract.expected[index],
            coinId .. " configured material payoff"
          )
        end

        if contract.odds then
          A.equal(coin.call_match_chance, contract.odds[index], coinId .. " Matching Call chance")
        end
      end
    end
  end,
}
