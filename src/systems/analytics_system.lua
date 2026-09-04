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
    nextStepLine = "Reward preview and Black Market follow."
  else
    nextStepLine = "Run summary follows."
  end

  report.stageLines = {
    string.format("Stage: %s", stageRecord.stageLabel or stageRecord.stageId or "n/a"),
    string.format("Opponent: %s", stageRecord.opponentName or "n/a"),
    string.format("Status: %s", tostring(stageRecord.status or "n/a")),
    string.format("Score Applied to HP: %d / %d", stageRecord.scoreAppliedToHp or stageRecord.stageScore or 0, stageRecord.opponentHp or stageRecord.targetScore or 0),
    string.format("Influence: %d", stageRecord.influence or stageRecord.shopPoints or runState.influence or 0),
    string.format("Black Market Rerolls Ready: %d", stageRecord.shopRerollsRemaining or runState.shopRerollsRemaining or 0),
    string.format("Pouch: %s", loadoutKey),
    string.format("Batches Resolved: %d", #stageBatches),
  }

  local victoryReward = stageRecord.victoryShopPointReward
  if victoryReward and (victoryReward.total or 0) > 0 then
    table.insert(report.stageLines, 6, string.format(
      "Victory Influence: +%d (base +%d, overkill +%d, flips +%d)",
      victoryReward.total or 0,
      victoryReward.base or 0,
      victoryReward.overkill or 0,
      victoryReward.remainingFlipReward or 0
    ))
  end

  if stageRecord.metaRewardEarned and stageRecord.metaRewardEarned > 0 then
    table.insert(report.stageLines, string.format("Reputation Reward: %d", stageRecord.metaRewardEarned))
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

local function recordStageResult(target, key, label, stageRecord)
  local entry = target[key] or {
    stageId = key,
    stageLabel = label,
    roundIndex = stageRecord.roundIndex,
    attempts = 0,
    clears = 0,
    fails = 0,
    totalStageScore = 0,
  }

  entry.attempts = entry.attempts + 1
  entry.totalStageScore = entry.totalStageScore + (stageRecord.scoreAppliedToHp or stageRecord.stageScore or 0)

  if stageRecord.status == "cleared" then
    entry.clears = entry.clears + 1
  else
    entry.fails = entry.fails + 1
  end

  target[key] = entry
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
    stageVariantStats = {},
    blackMarketOfferFrequency = {},
    purchaseFrequency = {},
    coinUsage = {},
    trickUsage = {},
    enemySkillStats = {},
    bossTrickStats = {},
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

    for _, upgradeId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
      local definition = Upgrades.getById(upgradeId)
      local entry = ensureRateEntry(report.trickUsage, upgradeId, definition and definition.name or upgradeId)
      entry.runs = entry.runs + 1
      if won then
        entry.wins = entry.wins + 1
      end
    end

    local seenEnemySkillEncounters = {}
    local seenBossTrickEncounters = {}
    for _, batch in ipairs(history.flipBatches or {}) do
      report.batchCount = report.batchCount + 1
      incrementCount(report.callDistribution, batch.call or "unknown")
      report.totalStageScoreDelta = report.totalStageScoreDelta + (((batch.scoreBreakdown or {}).totalStageScoreDelta) or 0)

      for _, coinState in ipairs(batch.resolvedCoinResults or {}) do
        incrementCount(report.outcomeDistribution, coinState.result or "unknown")
      end

      local skillSnapshot = batch.trace and batch.trace.enemySkillSnapshot or nil
      if skillSnapshot and skillSnapshot.skillId then
        local skill = report.enemySkillStats[skillSnapshot.skillId] or {
          skillId = skillSnapshot.skillId,
          name = skillSnapshot.name or skillSnapshot.skillId,
          difficultyRank = skillSnapshot.difficultyRank,
          encounters = 0,
          batches = 0,
          effectEvents = 0,
          scoreLost = 0,
          opponentHealing = 0,
        }
        local encounterKey = table.concat({
          tostring(batch.roundIndex or "?"),
          tostring(batch.stageId or "?"),
        }, "|")
        if not seenEnemySkillEncounters[encounterKey] then
          seenEnemySkillEncounters[encounterKey] = true
          skill.encounters = skill.encounters + 1
        end
        skill.batches = skill.batches + 1
        local effectEvents = #(batch.trace.enemySkillEffects or {})
        local effectKind = skillSnapshot.effect and skillSnapshot.effect.kind or nil
        if effectKind == "weakened" then
          for _, activation in ipairs(batch.trace.activationLedger or {}) do
            if activation.trickPosition == skillSnapshot.targetIndex then
              effectEvents = effectEvents + 1
            end
          end
        elseif effectKind == "blocked" or effectKind == "jammed" then
          for _, prevented in ipairs(batch.trace.preventedActivations or {}) do
            if prevented.trickPosition == skillSnapshot.targetIndex
              and prevented.pressureKind == effectKind then
              effectEvents = effectEvents + 1
            end
          end
        end
        for _, action in ipairs(batch.trace.actions or {}) do
          if action._trace and action._trace.sourceType == "enemy_skill"
            and action._trace.sourceId == skillSnapshot.skillId then
            if action.op == "add_stage_score" and (action.amount or 0) < 0 then
              skill.scoreLost = skill.scoreLost + math.abs(action.amount)
            elseif action.op == "heal_opponent" then
              skill.opponentHealing = skill.opponentHealing + (action.actualAmount or action.amount or 0)
              effectEvents = effectEvents + (action.matchCount or 1)
            end
          end
        end
        skill.effectEvents = skill.effectEvents + effectEvents
        report.enemySkillStats[skillSnapshot.skillId] = skill
      end

      local bossSnapshot = batch.trace and batch.trace.bossTrickSnapshot or nil
      if bossSnapshot and bossSnapshot.trickId then
        local boss = report.bossTrickStats[bossSnapshot.bossId] or {
          bossId = bossSnapshot.bossId,
          name = bossSnapshot.bossName or bossSnapshot.bossId,
          trickName = bossSnapshot.trickName or bossSnapshot.trickId,
          encounters = 0,
          batches = 0,
          headsFavourite = 0,
          tailsFavourite = 0,
          favouriteCalls = 0,
          underdogCalls = 0,
          spotlightSlots = {},
          spotlightEncores = 0,
          upstagedPenalties = 0,
          scoreGained = 0,
          scoreLost = 0,
          leftLeads = 0,
          rightLeads = 0,
          identitySteals = 0,
          emptyVictims = 0,
          threeCupsShuffles = 0,
          coinsPalmed = 0,
          offTheBooksSlots = {},
          taxCollected = 0,
          taxFreeScore = 0,
          writtenPatterns = {},
          writtenResultsForced = 0,
          effectEvents = 0,
        }
        local encounterKey = table.concat({
          tostring(batch.roundIndex or "?"),
          tostring(batch.stageId or "?"),
        }, "|")
        if not seenBossTrickEncounters[encounterKey] then
          seenBossTrickEncounters[encounterKey] = true
          boss.encounters = boss.encounters + 1
        end
        boss.batches = boss.batches + 1
        if bossSnapshot.trickId == "the_favourite" then
          if bossSnapshot.favouriteSide == "heads" then
            boss.headsFavourite = boss.headsFavourite + 1
          elseif bossSnapshot.favouriteSide == "tails" then
            boss.tailsFavourite = boss.tailsFavourite + 1
          end
          if batch.call == bossSnapshot.favouriteSide then
            boss.favouriteCalls = boss.favouriteCalls + 1
          else
            boss.underdogCalls = boss.underdogCalls + 1
          end
        elseif bossSnapshot.trickId == "centre_stage" then
          incrementCount(boss.spotlightSlots, bossSnapshot.spotlightSlotIndex or "unknown")
          for _, effect in ipairs(batch.trace.bossTrickEffects or {}) do
            if effect.kind == "spotlight_encore" then
              boss.spotlightEncores = boss.spotlightEncores + 1
              boss.scoreGained = boss.scoreGained + (effect.amount or 0)
            elseif effect.kind == "upstaged_penalty" then
              boss.upstagedPenalties = boss.upstagedPenalties + 1
              boss.scoreLost = boss.scoreLost + (effect.amount or 0)
            end
          end
        elseif bossSnapshot.trickId == "full_throttle" then
          if bossSnapshot.leadSlotIndex == 1 then
            boss.leftLeads = boss.leftLeads + 1
          else
            boss.rightLeads = boss.rightLeads + 1
          end
          for _, effect in ipairs(batch.trace.bossTrickEffects or {}) do
            if effect.kind == "full_throttle_scaling" then
              local amount = tonumber(effect.amount) or 0
              if amount >= 0 then
                boss.scoreGained = boss.scoreGained + amount
              else
                boss.scoreLost = boss.scoreLost + math.abs(amount)
              end
            end
          end
        elseif bossSnapshot.trickId == "stolen_identity" then
          local identity = batch.trace.stolenIdentity or {}
          if identity.stolenFamily then
            boss.identitySteals = boss.identitySteals + 1
          elseif identity.impostorCoinId then
            boss.emptyVictims = boss.emptyVictims + 1
          end
        elseif bossSnapshot.trickId == "three_cups" then
          local cups = batch.trace.threeCups or {}
          boss.threeCupsShuffles = boss.threeCupsShuffles + 1
          if cups.palmed then boss.coinsPalmed = boss.coinsPalmed + 1 end
        elseif bossSnapshot.trickId == "nothing_to_declare" then
          incrementCount(boss.offTheBooksSlots, bossSnapshot.offTheBooksSlotIndex or "unknown")
          for _, effect in ipairs(batch.trace.bossTrickEffects or {}) do
            if effect.kind == "tax_collected" then
              boss.taxCollected = boss.taxCollected + (effect.amount or 0)
              boss.taxFreeScore = boss.taxFreeScore
                + ((effect.slotScoreTotals or {})[effect.offTheBooksSlotIndex] or 0)
            end
          end
        elseif bossSnapshot.trickId == "written_in_stone" then
          local pattern = {}
          for _, result in ipairs(bossSnapshot.writtenSlotResults or {}) do
            table.insert(pattern, result == "heads" and "H" or "T")
          end
          incrementCount(boss.writtenPatterns, table.concat(pattern, ""))
          for _, effect in ipairs(batch.trace.bossTrickEffects or {}) do
            if effect.kind == "written_results" then
              boss.writtenResultsForced = boss.writtenResultsForced + (effect.forcedCount or 0)
            end
          end
        end
        boss.effectEvents = boss.effectEvents + #(batch.trace.bossTrickEffects or {})
        report.bossTrickStats[bossSnapshot.bossId] = boss
      end
    end

    for _, stageRecord in ipairs(history.stageResults or {}) do
      local aggregateLabel = stageRecord.stageLabel
      if stageRecord.variantId then
        aggregateLabel = stageRecord.stageType == "boss"
          and "Boss — All Variants"
          or string.format("Round %d — All Variants", stageRecord.roundIndex or 0)
      end

      recordStageResult(report.stageStats, stageRecord.stageId, aggregateLabel, stageRecord)

      if stageRecord.variantId then
        recordStageResult(report.stageVariantStats, stageRecord.variantId, stageRecord.stageLabel or stageRecord.variantName, stageRecord)
      end
    end

    for _, visit in ipairs(history.shopVisits or {}) do
      for _, offerSet in ipairs(visit.offerSets or {}) do
        for _, offer in ipairs(offerSet.offers or {}) do
          incrementCount(report.blackMarketOfferFrequency, string.format("%s:%s", offer.type or "unknown", offer.contentId or "unknown"))
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
  report.sortedStageVariantStats = toSortedKeyedList(report.stageVariantStats, "attempts")
  report.sortedBlackMarketOffers = toSortedKeyedList(report.blackMarketOfferFrequency)
  report.sortedPurchases = toSortedKeyedList(report.purchaseFrequency)
  report.sortedLoadouts = toSortedKeyedList(report.loadoutFrequency)
  report.sortedCoinUsage = toSortedKeyedList(report.coinUsage, "runs")
  report.sortedTrickUsage = toSortedKeyedList(report.trickUsage, "runs")
  report.sortedEnemySkillStats = toSortedKeyedList(report.enemySkillStats, "batches")
  report.sortedBossTrickStats = toSortedKeyedList(report.bossTrickStats, "batches")

  return report
end

function AnalyticsSystem.formatSimulationReport(report)
  local lines = {}
  local topItemCount = GameConfig.get("analytics.topItemCount")

  table.insert(lines, "Simulation Report")
  table.insert(lines, string.format("Runs: %d | Wins: %d | Losses: %d | Win rate: %.1f%%", report.runCount or 0, report.winCount or 0, report.lossCount or 0, (report.winRate or 0) * 100))
  table.insert(lines, string.format("Avg total score: %.2f | Avg Reputation reward: %.2f | Avg score applied per batch: %.2f", report.averageRunScore or 0, report.averageMetaReward or 0, report.averageStageScorePerBatch or 0))
  table.insert(lines, string.format("Calls: H=%d T=%d | Outcomes: H=%d T=%d", (report.callDistribution or {}).heads or 0, (report.callDistribution or {}).tails or 0, (report.outcomeDistribution or {}).heads or 0, (report.outcomeDistribution or {}).tails or 0))

  table.insert(lines, "")
  table.insert(lines, "Enemy Skill Stats:")
  for _, entry in ipairs(report.sortedEnemySkillStats or {}) do
    local skill = entry.data
    table.insert(lines, string.format(
      "- %s (rank %s): %d encounters / %d batches, %d effect events, %d Score lost, %d healing",
      skill.name or skill.skillId,
      tostring(skill.difficultyRank or "?"),
      skill.encounters or 0,
      skill.batches or 0,
      skill.effectEvents or 0,
      skill.scoreLost or 0,
      skill.opponentHealing or 0
    ))
  end

  table.insert(lines, "")
  table.insert(lines, "Boss Trick Stats:")
  for _, entry in ipairs(report.sortedBossTrickStats or {}) do
    local boss = entry.data
    if boss.trickName == "Written in Stone" then
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, %d results forced, %d effect events",
        boss.name or boss.bossId,
        boss.trickName,
        boss.encounters or 0,
        boss.batches or 0,
        boss.writtenResultsForced or 0,
        boss.effectEvents or 0
      ))
    elseif boss.trickName == "Nothing to Declare" then
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, %d Score protected / %d tax collected, %d effect events",
        boss.name or boss.bossId,
        boss.trickName,
        boss.encounters or 0,
        boss.batches or 0,
        boss.taxFreeScore or 0,
        boss.taxCollected or 0,
        boss.effectEvents or 0
      ))
    elseif boss.trickName == "Three Cups" then
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, %d shuffles / %d coins palmed, %d effect events",
        boss.name or boss.bossId,
        boss.trickName,
        boss.encounters or 0,
        boss.batches or 0,
        boss.threeCupsShuffles or 0,
        boss.coinsPalmed or 0,
        boss.effectEvents or 0
      ))
    elseif boss.trickName == "Stolen Identity" then
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, %d identities stolen / %d empty Victims, %d effect events",
        boss.name or boss.bossId,
        boss.trickName,
        boss.encounters or 0,
        boss.batches or 0,
        boss.identitySteals or 0,
        boss.emptyVictims or 0,
        boss.effectEvents or 0
      ))
    elseif boss.trickName == "Full Throttle" then
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, lead L%d/R%d, +%d / -%d Score, %d effect events",
        boss.name or boss.bossId,
        boss.trickName,
        boss.encounters or 0,
        boss.batches or 0,
        boss.leftLeads or 0,
        boss.rightLeads or 0,
        boss.scoreGained or 0,
        boss.scoreLost or 0,
        boss.effectEvents or 0
      ))
    elseif boss.trickName == "Centre Stage" then
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, %d Encores / %d Upstaged, +%d / -%d Score, %d effect events",
        boss.name or boss.bossId,
        boss.trickName,
        boss.encounters or 0,
        boss.batches or 0,
        boss.spotlightEncores or 0,
        boss.upstagedPenalties or 0,
        boss.scoreGained or 0,
        boss.scoreLost or 0,
        boss.effectEvents or 0
      ))
    else
      table.insert(lines, string.format(
        "- %s — %s: %d encounters / %d batches, favourite H%d/T%d, calls favourite %d / underdog %d, %d effect events",
        boss.name or boss.bossId,
        boss.trickName or "Boss Trick",
        boss.encounters or 0,
        boss.batches or 0,
        boss.headsFavourite or 0,
        boss.tailsFavourite or 0,
        boss.favouriteCalls or 0,
        boss.underdogCalls or 0,
        boss.effectEvents or 0
      ))
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Stage Stats:")
  for _, entry in ipairs(report.sortedStageStats or {}) do
    local stageData = entry.data
    local clearRate = stageData.attempts > 0 and ((stageData.clears / stageData.attempts) * 100) or 0
    local averageScoreApplied = stageData.attempts > 0 and (stageData.totalStageScore / stageData.attempts) or 0
    table.insert(lines, string.format("- %s: clear %.1f%% (%d/%d), avg score %.2f", stageData.stageLabel or stageData.stageId, clearRate, stageData.clears, stageData.attempts, averageScoreApplied))
  end

  if #(report.sortedStageVariantStats or {}) > 0 then
    table.insert(lines, "")
    table.insert(lines, "Variant Stats:")
    for _, entry in ipairs(report.sortedStageVariantStats or {}) do
      local stageData = entry.data
      local clearRate = stageData.attempts > 0 and ((stageData.clears / stageData.attempts) * 100) or 0
      local averageScoreApplied = stageData.attempts > 0 and (stageData.totalStageScore / stageData.attempts) or 0
      table.insert(lines, string.format("- %s: clear %.1f%% (%d/%d), avg score %.2f", stageData.stageLabel or stageData.stageId, clearRate, stageData.clears, stageData.attempts, averageScoreApplied))
    end
  end

  local function appendTopSection(title, items, formatter)
    table.insert(lines, "")
    table.insert(lines, title)

    for index = 1, math.min(topItemCount, #(items or {})) do
      table.insert(lines, formatter(items[index]))
    end
  end

  appendTopSection("Top Black Market Offers:", report.sortedBlackMarketOffers or {}, function(item)
    return string.format("- %s x%d", item.key, item.value)
  end)

  appendTopSection("Top Purchases:", report.sortedPurchases or {}, function(item)
    return string.format("- %s x%d", item.key, item.value)
  end)

  appendTopSection("Top Pouches:", report.sortedLoadouts or {}, function(item)
    return string.format("- %s x%d", item.key == "" and "(empty)" or item.key, item.value)
  end)

  appendTopSection("Coin Win Rates:", report.sortedCoinUsage or {}, function(item)
    local data = item.data
    local winRate = data.runs > 0 and ((data.wins / data.runs) * 100) or 0
    return string.format("- %s: used in %d run(s), win rate %.1f%%", data.label or item.key, data.runs, winRate)
  end)

  appendTopSection("Trick Win Rates:", report.sortedTrickUsage or {}, function(item)
    local data = item.data
    local winRate = data.runs > 0 and ((data.wins / data.runs) * 100) or 0
    return string.format("- %s: owned in %d run(s), win rate %.1f%%", data.label or item.key, data.runs, winRate)
  end)

  return table.concat(lines, "\n")
end

return AnalyticsSystem
