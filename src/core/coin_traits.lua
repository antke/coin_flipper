local Coins = require("src.content.coins")

local CoinTraits = {}

function CoinTraits.getCoinId(coin)
  return coin and (coin.definitionId or coin.coinId) or nil
end

function CoinTraits.getDefinition(coinOrId)
  local coinId = type(coinOrId) == "string" and coinOrId or CoinTraits.getCoinId(coinOrId)
  return coinId and Coins.getById(coinId) or nil
end

function CoinTraits.hasTag(coinOrId, tag)
  local definition = CoinTraits.getDefinition(coinOrId)

  for _, currentTag in ipairs(definition and definition.tags or {}) do
    if currentTag == tag then
      return true
    end
  end

  return false
end

function CoinTraits.hasFamily(coinOrId, family)
  if type(family) ~= "string" or family == "" then
    return false
  end

  local definition = CoinTraits.getDefinition(coinOrId)
  if not definition then
    return false
  end

  for _, field in ipairs({ "trick_synergy", "typeTags", "tags" }) do
    for _, tag in ipairs(definition[field] or {}) do
      if tag == family then
        return true
      end
    end
  end

  return false
end

function CoinTraits.hasArchetype(coinOrId, archetype)
  local definition = CoinTraits.getDefinition(coinOrId)
  return definition and definition.archetype == archetype
end

function CoinTraits.baseScore(coinOrId)
  local definition = CoinTraits.getDefinition(coinOrId)
  return definition and tonumber(definition.base_score) or 1
end

function CoinTraits.familyMultiplier(coinOrId, family)
  if not CoinTraits.hasFamily(coinOrId, family) then
    return 1
  end

  local definition = CoinTraits.getDefinition(coinOrId)
  local materialRank = definition and definition.materialRank or 1
  return math.max(2, materialRank + 1)
end

function CoinTraits.filterByFamily(candidates, family)
  local specialized = {}

  for _, candidate in ipairs(candidates or {}) do
    if CoinTraits.hasFamily(candidate, family) then
      table.insert(specialized, candidate)
    end
  end

  return specialized
end

return CoinTraits
