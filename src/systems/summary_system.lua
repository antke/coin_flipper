local SummarySystem = {}

function SummarySystem.buildRunSummary(runState, stageState)
  local stageHistory = runState and runState.history.stageResults or {}
  local purchaseHistory = runState and runState.history.purchases or {}
  local shopVisits = runState and runState.history.shopVisits or {}
  local finalStageRecord = stageHistory[#stageHistory]
  local totalRerollsUsed = 0

  for _, visit in ipairs(shopVisits) do
    totalRerollsUsed = totalRerollsUsed + (visit.rerollsUsed or 0)
  end

  return {
    runStatus = runState and runState.runStatus or "inactive",
    roundIndex = runState and runState.roundIndex or 0,
    runTotalScore = runState and runState.runTotalScore or 0,
    shopPoints = runState and runState.shopPoints or 0,
    collectionSize = runState and #runState.collectionCoinIds or 0,
    upgradeCount = runState and #runState.ownedUpgradeIds or 0,
    finalStageStatus = finalStageRecord and finalStageRecord.status or (stageState and stageState.stageStatus or "n/a"),
    finalStageLabel = finalStageRecord and finalStageRecord.stageLabel or (stageState and stageState.stageLabel or "n/a"),
    totalFlips = runState and runState.counters.totalFlips or 0,
    totalMatches = runState and runState.counters.totalMatches or 0,
    totalMisses = runState and runState.counters.totalMisses or 0,
    shopVisitCount = #shopVisits,
    totalRerollsUsed = totalRerollsUsed,
    metaRewardEarned = runState and runState.metaRewardEarned or 0,
    stageHistory = stageHistory,
    purchaseHistory = purchaseHistory,
  }
end

return SummarySystem
