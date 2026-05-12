local MetaProgressionSystem = require("src.systems.meta_progression_system")
local GameConfig = require("src.app.config")
local Loadout = require("src.domain.loadout")
local ProgressionSystem = require("src.systems.progression_system")
local Utils = require("src.core.utils")

local RunHistorySystem = {}

local function serializeRewardOption(option)
  if not option then
    return nil
  end

  return {
    type = option.type,
    contentId = option.contentId,
    name = option.name,
    rarity = option.rarity,
    description = option.description,
  }
end

local function serializeEncounterChoice(choice)
  if not choice then
    return nil
  end

  return {
    id = choice.id,
    type = choice.type,
    amount = choice.amount,
    contentId = choice.contentId,
    label = choice.label,
    description = choice.description,
  }
end

local function serializeEncounterSession(session)
  if not session then
    return nil
  end

  local preview = {
    id = session.encounterId,
    name = session.name,
    description = session.description,
    choices = {},
  }

  for _, choice in ipairs(session.choices or {}) do
    table.insert(preview.choices, serializeEncounterChoice(choice))
  end

  return preview
end

function RunHistorySystem.serializeShopOffer(offer)
  return {
    type = offer.type,
    contentId = offer.contentId,
    name = offer.name,
    rarity = offer.rarity,
    price = offer.price,
    purchased = offer.purchased == true,
  }
end

function RunHistorySystem.createShopSession(runState, sourceStageId, roundIndex)
  local shopSession = {
    visitIndex = #(runState.history.shopVisits or {}) + 1,
    roundIndex = roundIndex or runState.roundIndex,
    sourceStageId = sourceStageId or "n/a",
    rerollsUsed = 0,
    actions = {},
    purchases = {},
    purchaseFailures = {},
    offerSets = {},
    generationTraces = {},
    purchaseTraces = {},
  }

  table.insert(runState.history.shopVisits, shopSession)
  return shopSession
end

function RunHistorySystem.recordShopOfferSet(shopSession, offers, reason)
  if not shopSession then
    return
  end

  local snapshot = {
    reason = reason,
    offers = {},
  }

  for _, offer in ipairs(offers or {}) do
    table.insert(snapshot.offers, RunHistorySystem.serializeShopOffer(offer))
  end

  table.insert(shopSession.offerSets, snapshot)
end

function RunHistorySystem.recordGenerationTrace(shopSession, trace)
  if shopSession and trace then
    table.insert(shopSession.generationTraces, Utils.clone(trace))
  end
end

function RunHistorySystem.recordShopOfferRefresh(shopSession, offers, trace, reason)
  if trace and trace.offerCount ~= nil then
    assert(trace.offerCount == #(offers or {}), "shop offer refresh trace offerCount mismatch")
  end

  RunHistorySystem.recordGenerationTrace(shopSession, trace)
  RunHistorySystem.recordShopOfferSet(shopSession, offers, reason)
end

function RunHistorySystem.recordFlipBatch(runState, batch)
  table.insert(runState.history.flipBatches, Utils.clone(batch))
end

function RunHistorySystem.recordStageRewardPreview(stageRecord, session)
  if not stageRecord then
    return
  end

  stageRecord.rewardChoice = nil
  stageRecord.rewardOptions = {}

  for _, option in ipairs(session and session.options or {}) do
    table.insert(stageRecord.rewardOptions, serializeRewardOption(option))
  end
end

function RunHistorySystem.recordStageRewardChoice(stageRecord, choice)
  if not stageRecord then
    return
  end

  stageRecord.rewardChoice = serializeRewardOption(choice)
end

function RunHistorySystem.recordStageEncounterPreview(stageRecord, session)
  if not stageRecord then
    return
  end

  stageRecord.encounterChoice = nil
  stageRecord.encounter = serializeEncounterSession(session)
end

function RunHistorySystem.recordStageEncounterChoice(stageRecord, choice)
  if not stageRecord then
    return
  end

  stageRecord.encounterChoice = serializeEncounterChoice(choice)
end

function RunHistorySystem.recordPurchaseSuccess(shopSession, offer, result)
  if not shopSession then
    return
  end

  table.insert(shopSession.purchases, {
    type = offer.type,
    contentId = offer.contentId,
    price = result.finalPrice,
  })

  table.insert(shopSession.actions, {
    type = "purchase",
    outcome = "success",
    offerType = offer.type,
    contentId = offer.contentId,
    finalPrice = result.finalPrice,
  })

  if result.trace then
    table.insert(shopSession.purchaseTraces, Utils.clone(result.trace))
  end
end

function RunHistorySystem.recordPurchaseFailure(shopSession, offer, result)
  if not shopSession then
    return
  end

  table.insert(shopSession.purchaseFailures, {
    type = offer and offer.type or nil,
    contentId = offer and offer.contentId or nil,
    reason = result and result.reason or "purchase_failed",
  })

  table.insert(shopSession.actions, {
    type = "purchase",
    outcome = "failure",
    offerType = offer and offer.type or nil,
    contentId = offer and offer.contentId or nil,
    reason = result and result.reason or "purchase_failed",
  })

  if result and result.trace then
    table.insert(shopSession.purchaseTraces, Utils.clone(result.trace))
  end
end

function RunHistorySystem.recordReroll(shopSession, mode)
  if not shopSession then
    return
  end

  shopSession.rerollsUsed = (shopSession.rerollsUsed or 0) + 1

  table.insert(shopSession.actions, {
    type = "reroll",
    mode = mode,
  })
end

function RunHistorySystem.finalizeStage(runState, stageState, metaState)
  local stageClearShopPoints = GameConfig.get("economy.stageClearShopPoints", 3)

  if stageState.stageStatus == "cleared" and stageState.stageClearShopPointsGranted ~= true and stageClearShopPoints > 0 then
    runState.shopPoints = runState.shopPoints + stageClearShopPoints
    stageState.stageClearShopPointsGranted = true
  end

  local stageRecord = {
    roundIndex = runState.roundIndex,
    stageId = stageState.stageId,
    stageLabel = stageState.stageLabel,
    stageType = stageState.stageType,
    variantId = stageState.variantId,
    variantName = stageState.variantName,
    status = stageState.stageStatus,
    stageScore = stageState.stageScore,
    targetScore = stageState.targetScore,
    bossModifierIds = Utils.copyArray(stageState.activeBossModifierIds or {}),
    runTotalScore = runState.runTotalScore,
    shopPoints = runState.shopPoints,
    stageClearShopPoints = stageState.stageClearShopPointsGranted and stageClearShopPoints or 0,
    shopRerollsRemaining = runState.shopRerollsRemaining,
    loadoutKey = Loadout.toCanonicalKey(runState.equippedCoinSlots, runState.maxActiveCoinSlots),
  }

  runState.runStatus = ProgressionSystem.determineRunStatus(runState, stageState)
  stageRecord.runStatus = runState.runStatus
  table.insert(runState.history.stageResults, stageRecord)

  local shouldPersistMeta = false

  if metaState then
    if stageState.stageType == "boss" and stageState.stageStatus == "cleared" then
      metaState.stats.bossesDefeated = metaState.stats.bossesDefeated + 1
      shouldPersistMeta = true
    end

    if runState.runStatus == "won" then
      metaState.stats.runsWon = metaState.stats.runsWon + 1
      shouldPersistMeta = true
    end

    if runState.runTotalScore > metaState.stats.bestRunScore then
      metaState.stats.bestRunScore = runState.runTotalScore
      shouldPersistMeta = true
    end
  end

  local metaReward = 0

  if runState.runStatus ~= "active" and metaState then
    metaReward = MetaProgressionSystem.grantRunCompletionReward(metaState, runState, stageRecord)
    stageRecord.metaRewardEarned = metaReward
    shouldPersistMeta = true
  end

  runState.pendingForcedCoinResults = {}

  return stageRecord, {
    shouldPersistMeta = shouldPersistMeta,
    metaReward = metaReward,
  }
end

return RunHistorySystem
