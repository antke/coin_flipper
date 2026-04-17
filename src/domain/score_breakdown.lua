local ScoreBreakdown = {}

function ScoreBreakdown.new()
  return {
    baseScore = 0,
    preMultiplierScore = 0,
    finalBaseScore = 0,
    additiveBonuses = {},
    multipliers = {},
    conversions = {},
    shopPointChanges = {},
    perCoin = {},
    notes = {},
    totalStageScoreDelta = 0,
    totalRunScoreDelta = 0,
    totalShopPointDelta = 0,
  }
end

return ScoreBreakdown
