local ScoreBreakdown = {}

function ScoreBreakdown.new()
  local scoreScalings = {}

  return {
    baseScore = 0,
    preScoreScalingScore = 0,
    preMultiplierScore = 0,
    finalBaseScore = 0,
    additiveBonuses = {},
    scoreScalings = scoreScalings,
    multipliers = scoreScalings,
    conversions = {},
    shopPointChanges = {},
    scoreEvents = {},
    resolutionPackets = {},
    prestigeReplays = {},
    forgedOutcomeCopies = {},
    opponentHealing = {},
    chainLinks = {},
    perCoin = {},
    notes = {},
    totalStageScoreDelta = 0,
    totalRunScoreDelta = 0,
    totalShopPointDelta = 0,
  }
end

return ScoreBreakdown
