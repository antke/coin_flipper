local SummarySystem = {}

SummarySystem.MAX_RUN_RECORDS = 20

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
    seed = runState and runState.seed or nil,
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

function SummarySystem.buildRunRecord(runState, resultType, stageState)
  local summary = SummarySystem.buildRunSummary(runState, stageState)
  local finalStageStatus = summary.finalStageStatus
  local finalStageLabel = summary.finalStageLabel

  if finalStageStatus == "n/a" then
    if stageState and stageState.stageStatus then
      finalStageStatus = stageState.stageStatus
      finalStageLabel = stageState.stageLabel or finalStageLabel
    elseif runState and runState.runStatus == "active" then
      finalStageStatus = "active"
      finalStageLabel = runState.currentStageId or "Loadout"
    end
  end

  local record = {
    resultType = resultType or summary.runStatus,
    seed = runState and runState.seed or nil,
    runStatus = summary.runStatus,
    finalRound = summary.roundIndex,
    finalStageLabel = finalStageLabel,
    finalStageStatus = finalStageStatus,
    finalStageVariant = summary.stageHistory and summary.stageHistory[#(summary.stageHistory or {})] and summary.stageHistory[#summary.stageHistory].variantName or nil,
    runTotalScore = summary.runTotalScore,
    metaRewardEarned = summary.metaRewardEarned or 0,
    shopVisitCount = summary.shopVisitCount or 0,
    totalRerollsUsed = summary.totalRerollsUsed or 0,
    collectionSize = summary.collectionSize or 0,
    upgradeCount = summary.upgradeCount or 0,
    loadoutKey = runState and (runState.history and runState.history.loadoutCommits and runState.history.loadoutCommits[#(runState.history.loadoutCommits or {})] and runState.history.loadoutCommits[#runState.history.loadoutCommits].canonicalKey) or nil,
    stageHistory = {},
    shopHistory = {},
    purchaseHistory = {},
  }

  for _, stageRecord in ipairs(summary.stageHistory or {}) do
    table.insert(record.stageHistory, {
      roundIndex = stageRecord.roundIndex,
      stageLabel = stageRecord.stageLabel,
      stageType = stageRecord.stageType,
      variantName = stageRecord.variantName,
      status = stageRecord.status,
      stageScore = stageRecord.stageScore,
      targetScore = stageRecord.targetScore,
      loadoutKey = stageRecord.loadoutKey,
      rewardChoice = stageRecord.rewardChoice and {
        type = stageRecord.rewardChoice.type,
        contentId = stageRecord.rewardChoice.contentId,
        name = stageRecord.rewardChoice.name,
      } or nil,
      rewardOptionsCount = stageRecord.rewardOptions and #stageRecord.rewardOptions or 0,
      encounterChoice = stageRecord.encounterChoice and {
        id = stageRecord.encounterChoice.id,
        type = stageRecord.encounterChoice.type,
        contentId = stageRecord.encounterChoice.contentId,
        label = stageRecord.encounterChoice.label,
      } or nil,
      encounterOptionsCount = stageRecord.encounter and #(stageRecord.encounter.choices or {}) or 0,
    })
  end

  local stageLabelsByKey = {}
  for _, stageRecord in ipairs(summary.stageHistory or {}) do
    stageLabelsByKey[string.format("%s:%s", tostring(stageRecord.roundIndex), tostring(stageRecord.stageId))] = stageRecord.stageLabel
  end

  for _, visit in ipairs(runState and runState.history and runState.history.shopVisits or {}) do
    local compactPurchases = {}
    for _, purchase in ipairs(visit.purchases or {}) do
      table.insert(compactPurchases, {
        type = purchase.type,
        contentId = purchase.contentId,
        price = purchase.price,
      })
    end

    table.insert(record.shopHistory, {
      roundIndex = visit.roundIndex,
      sourceStageId = visit.sourceStageId,
      sourceStageLabel = stageLabelsByKey[string.format("%s:%s", tostring(visit.roundIndex), tostring(visit.sourceStageId))],
      rerollsUsed = visit.rerollsUsed or 0,
      offersSeen = #(visit.offerSets or {}),
      purchases = compactPurchases,
    })
  end

  for _, purchase in ipairs(summary.purchaseHistory or {}) do
    table.insert(record.purchaseHistory, {
      type = purchase.type,
      contentId = purchase.contentId,
      price = purchase.price,
    })
  end

  return record
end

function SummarySystem.appendRunRecord(metaState, record)
  metaState.runRecords = metaState.runRecords or {}
  table.insert(metaState.runRecords, 1, record)

  while #metaState.runRecords > SummarySystem.MAX_RUN_RECORDS do
    table.remove(metaState.runRecords)
  end
end

return SummarySystem
