local Coins = require("src.content.coins")
local GameConfig = require("src.app.config")
local Upgrades = require("src.content.upgrades")

local AnalyticsSystem = {}

local function incrementCount(target, key, amount)
  target[key] = (target[key] or 0) + (amount or 1)
end

local function buildLoadoutKeyForStage(runState, stageRecord)
  if stageRecord and stageRecord.loadoutKey then
    return stageRecord.loadoutKey
  end

  for _, commit in ipairs(runState and runState.history and runState.history.loadoutCommits or {}) do
    if commit.roundIndex == stageRecord.roundIndex and commit.stageId == stageRecord.stageId then
      return commit.canonicalKey or "(empty)"
    end
  end

  return "n/a"
end

function AnalyticsSystem.buildPostStageReport(runState, stageRecord, lastBatchResult)
  local report = {
    stageLines = {},
    distributionLines = {},
    traceLines = {},
    lastBatchLines = {},
  }

  if not runState or not stageRecord then
    report.stageLines = { "No finalized stage analytics available yet." }
    report.distributionLines = { "No stage batch data available." }
    report.traceLines = { "No trace data available." }
    report.lastBatchLines = { "No batch summary available." }
    return report
  end

  local stageBatches = {}
  local callDistribution = { heads = 0, tails = 0 }
  local outcomeDistribution = { heads = 0, tails = 0 }
  local totalMatches = 0
  local totalMisses = 0
  local totalTriggeredSources = 0
  local totalActions = 0
  local totalQueued = 0
  local totalTempGrants = 0
  local totalTempConsumes = 0
  local totalForced = 0

  for _, batch in ipairs(runState.history and runState.history.flipBatches or {}) do
    if batch.roundIndex == stageRecord.roundIndex and batch.stageId == stageRecord.stageId then
      table.insert(stageBatches, batch)
      incrementCount(callDistribution, batch.call or "unknown")

      for _, coinState in ipairs(batch.resolvedCoinResults or {}) do
        incrementCount(outcomeDistribution, coinState.result or "unknown")
        if coinState.didMatch then
          totalMatches = totalMatches + 1
        else
          totalMisses = totalMisses + 1
        end
      end

      totalTriggeredSources = totalTriggeredSources + #(batch.trace and batch.trace.triggeredSources or {})
      totalActions = totalActions + #(batch.trace and batch.trace.actions or {})
      totalQueued = totalQueued + #(batch.trace and batch.trace.queuedActions or {})
      totalTempGrants = totalTempGrants + #(batch.trace and batch.trace.temporaryEffectsGranted or {})
      totalTempConsumes = totalTempConsumes + #(batch.trace and batch.trace.temporaryEffectsConsumed or {})
      totalForced = totalForced + #(batch.trace and batch.trace.forcedResults or {})
    end
  end

  local loadoutKey = buildLoadoutKeyForStage(runState, stageRecord)
  local nextStepLine

  if stageRecord.stageType == "boss" and stageRecord.status == "cleared" and stageRecord.runStatus == "won" then
    nextStepLine = "Victory reward follows."
  elseif stageRecord.runStatus == "active" then
    nextStepLine = "Reward preview and shop follow."
  else
    nextStepLine = "Run summary follows."
  end

  report.stageLines = {
    string.format("Stage: %s", stageRecord.stageLabel or stageRecord.stageId or "n/a"),
    string.format("Status: %s", tostring(stageRecord.status or "n/a")),
    string.format("Score: %d / %d", stageRecord.stageScore or 0, stageRecord.targetScore or 0),
    string.format("Run Total Score: %d", stageRecord.runTotalScore or runState.runTotalScore or 0),
    string.format("Shop Points: %d", stageRecord.shopPoints or runState.shopPoints or 0),
    string.format("Shop Rerolls Ready: %d", stageRecord.shopRerollsRemaining or runState.shopRerollsRemaining or 0),
    string.format("Loadout: %s", loadoutKey),
    string.format("Batches Resolved: %d", #stageBatches),
  }

  if stageRecord.metaRewardEarned and stageRecord.metaRewardEarned > 0 then
    table.insert(report.stageLines, string.format("Meta Reward: %d", stageRecord.metaRewardEarned))
  end

  report.distributionLines = {
    string.format("Calls — Heads: %d | Tails: %d", callDistribution.heads or 0, callDistribution.tails or 0),
    string.format("Outcomes — Heads: %d | Tails: %d", outcomeDistribution.heads or 0, outcomeDistribution.tails or 0),
    string.format("Matches / Misses: %d / %d", totalMatches, totalMisses),
  }

  report.traceLines = {
    string.format("Triggered sources: %d", totalTriggeredSources),
    string.format("Emitted actions: %d", totalActions),
    string.format("Queued actions: %d", totalQueued),
    string.format("Temporary effects: +%d / -%d", totalTempGrants, totalTempConsumes),
    string.format("Forced results used: %d", totalForced),
    nextStepLine,
  }

  if lastBatchResult and lastBatchResult.batchId then
    table.insert(report.lastBatchLines, string.format("Last batch #%d (%s)", lastBatchResult.batchId, string.upper(lastBatchResult.call or "?")))

    for _, coinState in ipairs(lastBatchResult.perCoin or {}) do
      table.insert(report.lastBatchLines, string.format(
        "- %s @ slot %s/order %s => %s%s",
        coinState.coinId or "unknown",
        tostring(coinState.slotIndex or "?"),
        tostring(coinState.resolutionIndex or "?"),
        string.upper(coinState.result or "?"),
        coinState.didMatch and " (match)" or " (miss)"
      ))
    end
  else
    report.lastBatchLines = { "No last batch data available." }
  end

  return report
end
local function ensureRateEntry(target, key, label)
  if not target[key] then
    target[key] = {
      key = key,
      label = label or key,
      runs = 0,
      wins = 0,
    }
  end

  return target[key]
end

local function toSortedKeyedList(map, valueKey)
  local items = {}

  for key, value in pairs(map or {}) do
    table.insert(items, {
      key = key,
      value = valueKey and value[valueKey] or value,
      data = value,
    })
  end

  table.sort(items, function(left, right)
    if left.value ~= right.value then
      return left.value > right.value
    end

    return tostring(left.key) < tostring(right.key)
  end)

  return items
end

function AnalyticsSystem.buildSimulationReport(results)
  local report = {
    runCount = #(results or {}),
    winCount = 0,
    lossCount = 0,
    batchCount = 0,
    totalRunScore = 0,
    totalMetaReward = 0,
    totalStageScoreDelta = 0,
    callDistribution = { heads = 0, tails = 0 },
    outcomeDistribution = { heads = 0, tails = 0 },
    stageStats = {},
    shopOfferFrequency = {},
    purchaseFrequency = {},
    coinUsage = {},
    upgradeUsage = {},
    loadoutFrequency = {},
  }

  for _, result in ipairs(results or {}) do
    local summary = result.summary or {}
    local runState = result.runState or {}
    local history = runState.history or {}
    local won = summary.runStatus == "won"

    if won then
      report.winCount = report.winCount + 1
    else
      report.lossCount = report.lossCount + 1
    end

    report.totalRunScore = report.totalRunScore + (summary.runTotalScore or 0)
    report.totalMetaReward = report.totalMetaReward + (summary.metaRewardEarned or 0)

    local usedCoinIds = {}
    for _, commit in ipairs(history.loadoutCommits or {}) do
      incrementCount(report.loadoutFrequency, commit.canonicalKey or "")

      for _, coinId in ipairs(commit.compactCoinIds or {}) do
        usedCoinIds[coinId] = true
      end
    end

    for coinId in pairs(usedCoinIds) do
      local definition = Coins.getById(coinId)
      local entry = ensureRateEntry(report.coinUsage, coinId, definition and definition.name or coinId)
      entry.runs = entry.runs + 1
      if won then
        entry.wins = entry.wins + 1
      end
    end

    for _, upgradeId in ipairs(runState.ownedUpgradeIds or {}) do
      local definition = Upgrades.getById(upgradeId)
      local entry = ensureRateEntry(report.upgradeUsage, upgradeId, definition and definition.name or upgradeId)
      entry.runs = entry.runs + 1
      if won then
        entry.wins = entry.wins + 1
      end
    end

    for _, batch in ipairs(history.flipBatches or {}) do
      report.batchCount = report.batchCount + 1
      incrementCount(report.callDistribution, batch.call or "unknown")
      report.totalStageScoreDelta = report.totalStageScoreDelta + (((batch.scoreBreakdown or {}).totalStageScoreDelta) or 0)

      for _, coinState in ipairs(batch.resolvedCoinResults or {}) do
        incrementCount(report.outcomeDistribution, coinState.result or "unknown")
      end
    end

    for _, stageRecord in ipairs(history.stageResults or {}) do
      local stageEntry = report.stageStats[stageRecord.stageId] or {
        stageId = stageRecord.stageId,
        stageLabel = stageRecord.stageLabel,
        attempts = 0,
        clears = 0,
        fails = 0,
        totalStageScore = 0,
      }

      stageEntry.attempts = stageEntry.attempts + 1
      stageEntry.totalStageScore = stageEntry.totalStageScore + (stageRecord.stageScore or 0)

      if stageRecord.status == "cleared" then
        stageEntry.clears = stageEntry.clears + 1
      else
        stageEntry.fails = stageEntry.fails + 1
      end

      report.stageStats[stageRecord.stageId] = stageEntry
    end

    for _, visit in ipairs(history.shopVisits or {}) do
      for _, offerSet in ipairs(visit.offerSets or {}) do
        for _, offer in ipairs(offerSet.offers or {}) do
          incrementCount(report.shopOfferFrequency, string.format("%s:%s", offer.type or "unknown", offer.contentId or "unknown"))
        end
      end
    end

    for _, purchase in ipairs(history.purchases or {}) do
      incrementCount(report.purchaseFrequency, string.format("%s:%s", purchase.type or "unknown", purchase.contentId or "unknown"))
    end
  end

  report.winRate = report.runCount > 0 and (report.winCount / report.runCount) or 0
  report.averageRunScore = report.runCount > 0 and (report.totalRunScore / report.runCount) or 0
  report.averageMetaReward = report.runCount > 0 and (report.totalMetaReward / report.runCount) or 0
  report.averageStageScorePerBatch = report.batchCount > 0 and (report.totalStageScoreDelta / report.batchCount) or 0
  report.sortedStageStats = toSortedKeyedList(report.stageStats, "attempts")
  report.sortedShopOffers = toSortedKeyedList(report.shopOfferFrequency)
  report.sortedPurchases = toSortedKeyedList(report.purchaseFrequency)
  report.sortedLoadouts = toSortedKeyedList(report.loadoutFrequency)
  report.sortedCoinUsage = toSortedKeyedList(report.coinUsage, "runs")
  report.sortedUpgradeUsage = toSortedKeyedList(report.upgradeUsage, "runs")

  return report
end

function AnalyticsSystem.formatSimulationReport(report)
  local lines = {}
  local topItemCount = GameConfig.get("analytics.topItemCount")

  table.insert(lines, "Simulation Report")
  table.insert(lines, string.format("Runs: %d | Wins: %d | Losses: %d | Win rate: %.1f%%", report.runCount or 0, report.winCount or 0, report.lossCount or 0, (report.winRate or 0) * 100))
  table.insert(lines, string.format("Avg run score: %.2f | Avg meta reward: %.2f | Avg stage score per batch: %.2f", report.averageRunScore or 0, report.averageMetaReward or 0, report.averageStageScorePerBatch or 0))
  table.insert(lines, string.format("Calls: H=%d T=%d | Outcomes: H=%d T=%d", (report.callDistribution or {}).heads or 0, (report.callDistribution or {}).tails or 0, (report.outcomeDistribution or {}).heads or 0, (report.outcomeDistribution or {}).tails or 0))

  table.insert(lines, "")
  table.insert(lines, "Stage Stats:")
  for _, entry in ipairs(report.sortedStageStats or {}) do
    local stageData = entry.data
    local clearRate = stageData.attempts > 0 and ((stageData.clears / stageData.attempts) * 100) or 0
    local averageScore = stageData.attempts > 0 and (stageData.totalStageScore / stageData.attempts) or 0
    table.insert(lines, string.format("- %s: clear %.1f%% (%d/%d), avg score %.2f", stageData.stageLabel or stageData.stageId, clearRate, stageData.clears, stageData.attempts, averageScore))
  end

  local function appendTopSection(title, items, formatter)
    table.insert(lines, "")
    table.insert(lines, title)

    for index = 1, math.min(topItemCount, #(items or {})) do
      table.insert(lines, formatter(items[index]))
    end
  end

  appendTopSection("Top Shop Offers:", report.sortedShopOffers or {}, function(item)
    return string.format("- %s x%d", item.key, item.value)
  end)

  appendTopSection("Top Purchases:", report.sortedPurchases or {}, function(item)
    return string.format("- %s x%d", item.key, item.value)
  end)

  appendTopSection("Top Loadouts:", report.sortedLoadouts or {}, function(item)
    return string.format("- %s x%d", item.key == "" and "(empty)" or item.key, item.value)
  end)

  appendTopSection("Coin Win Rates:", report.sortedCoinUsage or {}, function(item)
    local data = item.data
    local winRate = data.runs > 0 and ((data.wins / data.runs) * 100) or 0
    return string.format("- %s: used in %d run(s), win rate %.1f%%", data.label or item.key, data.runs, winRate)
  end)

  appendTopSection("Upgrade Win Rates:", report.sortedUpgradeUsage or {}, function(item)
    local data = item.data
    local winRate = data.runs > 0 and ((data.wins / data.runs) * 100) or 0
    return string.format("- %s: owned in %d run(s), win rate %.1f%%", data.label or item.key, data.runs, winRate)
  end)

  return table.concat(lines, "\n")
end

return AnalyticsSystem
