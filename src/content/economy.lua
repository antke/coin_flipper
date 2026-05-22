local EconomyContent = {
  shop = {
    coinRarityPrices = {
      common = 4,
      uncommon = 8,
      rare = 13,
      cursed = 7,
    },
    upgradeRarityPrices = {
      common = 8,
      uncommon = 15,
      rare = 25,
      cursed = 14,
    },
    upgradePriceBonus = 1,
    fallbackPrice = 4,
  },

  victoryRewards = {
    baseShopPoints = 6,
    remainingFlipShopPoints = 3,
    overkillShopPointsPerDamage = 1.0,
    overkillShopPointsCap = 8,
  },
}

local function nonNegativeInteger(value)
  return math.max(0, math.floor(tonumber(value) or 0))
end

function EconomyContent.resolveOfferPrice(offerType, definition)
  definition = definition or {}

  if definition.price then
    return definition.price
  end

  local rarity = definition.rarity or "common"

  if offerType == "coin" then
    return EconomyContent.shop.coinRarityPrices[rarity] or EconomyContent.shop.fallbackPrice
  end

  local basePrice = EconomyContent.shop.upgradeRarityPrices[rarity] or EconomyContent.shop.fallbackPrice

  if offerType == "upgrade" then
    return basePrice + EconomyContent.shop.upgradePriceBonus
  end

  return basePrice
end

function EconomyContent.calculateVictoryShopPointReward(stageState)
  local rewards = EconomyContent.victoryRewards
  local cleared = stageState and stageState.stageStatus == "cleared"

  if not cleared then
    return {
      base = 0,
      overkill = 0,
      overkillDamage = 0,
      remainingFlips = 0,
      remainingFlipReward = 0,
      total = 0,
    }
  end

  local overkillDamage = math.max(0, (stageState.stageScore or 0) - (stageState.targetScore or 0))
  local overkillReward = math.floor(overkillDamage * rewards.overkillShopPointsPerDamage)
  overkillReward = math.min(rewards.overkillShopPointsCap, overkillReward)

  local remainingFlips = nonNegativeInteger(stageState.flipsRemaining)
  local remainingFlipReward = remainingFlips * rewards.remainingFlipShopPoints
  local baseReward = rewards.baseShopPoints

  return {
    base = baseReward,
    overkill = overkillReward,
    overkillDamage = overkillDamage,
    remainingFlips = remainingFlips,
    remainingFlipReward = remainingFlipReward,
    total = baseReward + overkillReward + remainingFlipReward,
  }
end

return EconomyContent
