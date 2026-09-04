local Coins = require("src.content.coins")

local CoinTraits = {}

function CoinTraits.getCoinId(coin)
  return coin and (coin.definitionId or coin.coinId) or nil
end

local function copyIdentityIds(values)
  local ids = {}

  for _, value in ipairs(values or {}) do
    if type(value) == "string" and value ~= "" then
      table.insert(ids, value)
    end
  end

  return ids
end

function CoinTraits.getIdentityIds(coinOrId)
  if type(coinOrId) == "string" then
    return { coinOrId }
  end

  if type(coinOrId) ~= "table" then
    return {}
  end

  local explicitIds = copyIdentityIds(coinOrId.effectiveIdentityIds)
  if #explicitIds > 0 then
    return explicitIds
  end

  if type(coinOrId.scoringCoinId) == "string" and coinOrId.scoringCoinId ~= "" then
    return { coinOrId.scoringCoinId }
  end

  if type(coinOrId.forgedCoinId) == "string" and coinOrId.forgedCoinId ~= "" then
    return { coinOrId.forgedCoinId }
  end

  local coinId = CoinTraits.getCoinId(coinOrId)
  return coinId and { coinId } or {}
end

function CoinTraits.getPrimaryIdentityCoinId(coinOrId)
  local ids = CoinTraits.getIdentityIds(coinOrId)
  return ids[1]
end

function CoinTraits.getDefinition(coinOrId)
  local coinId = type(coinOrId) == "string" and coinOrId or CoinTraits.getPrimaryIdentityCoinId(coinOrId)
  return coinId and Coins.getById(coinId) or nil
end

function CoinTraits.getRealDefinition(coinOrId)
  local coinId = type(coinOrId) == "string" and coinOrId or CoinTraits.getCoinId(coinOrId)
  return coinId and Coins.getById(coinId) or nil
end

local function anyIdentityMatches(coinOrId, predicate)
  for _, coinId in ipairs(CoinTraits.getIdentityIds(coinOrId)) do
    local definition = Coins.getById(coinId)

    if definition and predicate(definition) then
      return true, definition
    end
  end

  return false, nil
end

function CoinTraits.hasTag(coinOrId, tag)
  local hasTag = anyIdentityMatches(coinOrId, function(definition)
    for _, currentTag in ipairs(definition.tags or {}) do
      if currentTag == tag then
        return true
      end
    end

    return false
  end)

  return hasTag == true
end

function CoinTraits.hasRealTag(coinOrId, tag)
  local definition = CoinTraits.getRealDefinition(coinOrId)

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

  local hasFamily = anyIdentityMatches(coinOrId, function(definition)
    for _, field in ipairs({ "trick_synergy", "typeTags", "tags" }) do
      for _, tag in ipairs(definition[field] or {}) do
        if tag == family then
          return true
        end
      end
    end

    return false
  end)

  return hasFamily == true
end

function CoinTraits.hasRealFamily(coinOrId, family)
  if type(family) ~= "string" or family == "" then
    return false
  end

  local definition = CoinTraits.getRealDefinition(coinOrId)
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
  local hasArchetype = anyIdentityMatches(coinOrId, function(definition)
    return definition.archetype == archetype
  end)

  return hasArchetype == true
end

function CoinTraits.hasRealArchetype(coinOrId, archetype)
  local definition = CoinTraits.getRealDefinition(coinOrId)
  return definition and definition.archetype == archetype
end

function CoinTraits.baseScore(coinOrId)
  local definition = CoinTraits.getDefinition(coinOrId)
  return definition and tonumber(definition.base_score) or 1
end

function CoinTraits.materialRank(coinOrId, useRealIdentity)
  local definition = useRealIdentity == true
    and CoinTraits.getRealDefinition(coinOrId)
    or CoinTraits.getDefinition(coinOrId)

  return math.max(1, tonumber(definition and definition.materialRank) or 1)
end

function CoinTraits.materialPayoffMultiplier(coinOrId, baseMultiplier, rankStep, useRealIdentity)
  local rank = CoinTraits.materialRank(coinOrId, useRealIdentity)
  return (tonumber(baseMultiplier) or 1) + ((rank - 1) * (tonumber(rankStep) or 0))
end

function CoinTraits.familyMultiplier(coinOrId, family)
  local multiplier = 1

  for _, coinId in ipairs(CoinTraits.getIdentityIds(coinOrId)) do
    if CoinTraits.hasFamily(coinId, family) then
      local definition = Coins.getById(coinId)
      local materialRank = definition and definition.materialRank or 1
      multiplier = math.max(multiplier, math.max(2, materialRank + 1))
    end
  end

  return multiplier
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
