local Coins = require("src.content.coins")
local FlipResolver = require("src.systems.flip_resolver")
local GameConfig = require("src.app.config")
local LoadoutSystem = require("src.systems.loadout_system")
local RunHistorySystem = require("src.systems.run_history_system")
local MetaState = require("src.domain.meta_state")
local ProgressionSystem = require("src.systems.progression_system")
local RNG = require("src.core.rng")
local RewardSystem = require("src.systems.reward_system")
local RunInitializer = require("src.systems.run_initializer")
local ShopFlowSystem = require("src.systems.shop_flow_system")
local ShopSystem = require("src.systems.shop_system")
local Stages = require("src.content.stages")
local SummarySystem = require("src.systems.summary_system")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local SimulationSystem = {}

local COIN_TAG_SCORES = {
  score = 4,
  match = 3,
  weight = 2,
  multiplier = 2,
  economy = 1,
}

local OFFER_TYPE_SCORES = {
  upgrade = 5,
  coin = 3,
}

local OFFER_TAG_SCORES = {
  score = 4,
  match = 3,
  multiplier = 3,
  weight = 2,
  economy = 1,
  shop = 1,
}

local function hasTag(definition, tag)
  for _, currentTag in ipairs(definition and definition.tags or {}) do
    if currentTag == tag then
      return true
    end
  end

  return false
end

local function getOfferDefinition(offer)
  if not offer then
    return nil
  end

  if offer.type == "coin" then
    return Coins.getById(offer.contentId)
  end

  return Upgrades.getById(offer.contentId)
end

local function cloneMetaState(metaState)
  if metaState then
    return MetaState.new(Utils.clone(metaState))
  end

  return MetaState.new()
end

local function scoreDefinitionByTags(definition, weights)
  local score = 0

  for tag, value in pairs(weights or {}) do
    if hasTag(definition, tag) then
      score = score + value
    end
  end

  return score
end

local function scoreCoinForStage(coinId, stageDefinition)
  local definition = Coins.getById(coinId)
  local score = 0

  if not definition then
    return score
  end

  score = score + scoreDefinitionByTags(definition, COIN_TAG_SCORES)

  if hasTag(definition, "boss") then
    score = score + (stageDefinition and stageDefinition.stageType == "boss" and 6 or -1)
  end

  return score
end

local function chooseLoadoutSelection(runState, stageDefinition)
  local candidates = {}

  for _, coinId in ipairs(runState.collectionCoinIds or {}) do
    table.insert(candidates, {
      coinId = coinId,
      score = scoreCoinForStage(coinId, stageDefinition),
    })
  end

  table.sort(candidates, function(left, right)
    if left.score ~= right.score then
      return left.score > right.score
    end

    return left.coinId < right.coinId
  end)

  local selection = {}

  for slotIndex = 1, runState.maxActiveCoinSlots do
    selection[slotIndex] = candidates[slotIndex] and candidates[slotIndex].coinId or nil
  end

  return selection
end

local function buildProjectionRng(shadowRunState, shadowStageState, call)
  local callOffset = call == "tails" and 1000 or 0
  return RNG.new((shadowRunState.seed or 1) + (shadowStageState.batchIndex or 0) + callOffset)
end

local function estimateSideWeight(runState, stageState, metaProjection, call)
  local shadowRunState = Utils.clone(runState)
  local shadowStageState = Utils.clone(stageState)
  local context = FlipResolver.projectBatchBeforeRoll(
    shadowRunState,
    shadowStageState,
    metaProjection,
    call,
    buildProjectionRng(shadowRunState, shadowStageState, call)
  )
  local score = 0

  for _, coinState in ipairs(context.perCoin or {}) do
    local totalWeight = math.max((coinState.headsWeight or 0) + (coinState.tailsWeight or 0), 0.00001)
    score = score + (((coinState[call .. "Weight"] or 0) / totalWeight))
  end

  return score
end

local function estimateCallPreference(runState, stageState, metaProjection)
  local headsScore = estimateSideWeight(runState, stageState, metaProjection, "heads")
  local tailsScore = estimateSideWeight(runState, stageState, metaProjection, "tails")

  if stageState.lastCall == "heads" then
    tailsScore = tailsScore + 0.05
  elseif stageState.lastCall == "tails" then
    headsScore = headsScore + 0.05
  end

  return headsScore, tailsScore
end

local function chooseCall(runState, stageState, metaProjection)
  local headsScore, tailsScore = estimateCallPreference(runState, stageState, metaProjection)

  if headsScore == tailsScore then
    if stageState.lastCall == "heads" then
      return "tails"
    elseif stageState.lastCall == "tails" then
      return "heads"
    end

    return "heads"
  end

  return headsScore > tailsScore and "heads" or "tails"
end

local function scoreOfferForPurchase(offer, nextStageDefinition)
  local definition = getOfferDefinition(offer)
  local score = OFFER_TYPE_SCORES[offer.type] or 0

  if definition then
    score = score + scoreDefinitionByTags(definition, OFFER_TAG_SCORES)

    if nextStageDefinition and nextStageDefinition.stageType == "boss" and hasTag(definition, "boss") then
      score = score + 6
    end
  end

  score = score - ((offer.price or 0) * 0.15)
  return score
end

local function choosePurchaseIndex(runState, offers, nextStageDefinition)
  local candidates = {}

  for index, offer in ipairs(offers or {}) do
    if not offer.purchased and (offer.price or 0) <= (runState.shopPoints or 0) then
      table.insert(candidates, {
        index = index,
        score = scoreOfferForPurchase(offer, nextStageDefinition),
        price = offer.price or 0,
        contentId = offer.contentId,
      })
    end
  end

  table.sort(candidates, function(left, right)
    if left.score ~= right.score then
      return left.score > right.score
    end

    if left.price ~= right.price then
      return left.price < right.price
    end

    return tostring(left.contentId) < tostring(right.contentId)
  end)

  return candidates[1] and candidates[1].index or nil
end

local function shouldReroll(runState, stageState, metaProjection, offers, rerollsUsed)
  if rerollsUsed >= GameConfig.get("simulation.maxRerollsPerVisit") then
    return false
  end

  if not select(1, ShopSystem.canReroll(runState, stageState, metaProjection)) then
    return false
  end

  for _, offer in ipairs(offers or {}) do
    if not offer.purchased and (offer.price or 0) <= (runState.shopPoints or 0) then
      return false
    end
  end

  return true
end

local function simulateShopVisit(runState, stageState, stageRecord, metaProjection, rng)
  local shopFlow = ShopFlowSystem.createVisit(runState, stageState, metaProjection, rng, {
    sourceStageId = stageRecord.stageId,
    roundIndex = stageRecord.roundIndex,
  })

  ShopFlowSystem.ensureOffers(shopFlow)

  local actionCount = 0
  while actionCount < GameConfig.get("simulation.maxShopActionsPerVisit") do
    local nextStageDefinition = Stages.getForRound(runState.roundIndex + 1, runState)
    local purchaseIndex = choosePurchaseIndex(runState, shopFlow.offers, nextStageDefinition)

    if purchaseIndex then
      local ok, result = ShopFlowSystem.purchase(shopFlow, purchaseIndex)

      if not ok then
        break
      end

      actionCount = actionCount + 1
    elseif shouldReroll(runState, stageState, metaProjection, shopFlow.offers, shopFlow.shopSession.rerollsUsed) then
      local rerollMode = ShopFlowSystem.reroll(shopFlow)

      if not rerollMode then
        break
      end

      actionCount = actionCount + 1
    else
      break
    end
  end

  Validator.assertRuntimeInvariants("simulation_system.simulateShopVisit", runState, stageState, { history = true })
end

local function chooseRewardOptionIndex(session)
  if not session or #(session.options or {}) == 0 then
    return nil
  end

  for index, option in ipairs(session.options or {}) do
    if option.type == "upgrade" then
      return index
    end
  end

  return session.selectedIndex or 1
end

local function simulateRewardChoice(runState, stageRecord, rng)
  local session = RewardSystem.buildPreview(runState, rng)
  RunHistorySystem.recordStageRewardPreview(stageRecord, session)

  local selectedIndex = chooseRewardOptionIndex(session)
  if selectedIndex then
    RewardSystem.selectOption(session, selectedIndex)
  end

  local ok, choiceOrError = RewardSystem.claimSelection(runState, session)
  if not ok then
    error(choiceOrError or "reward_claim_failed")
  end

  RunHistorySystem.recordStageRewardChoice(stageRecord, choiceOrError)
end

function SimulationSystem.simulateRun(options)
  options = options or {}

  local metaState = cloneMetaState(options.metaState)
  local runState, metaProjection = RunInitializer.createNewRun(metaState, {
    seed = options.seed,
    startingCollectionSize = options.startingCollectionSize,
    starterCollection = options.starterCollection,
    equippedCoinSlots = options.equippedCoinSlots,
    persistedLoadoutSlots = options.persistedLoadoutSlots,
    ownedUpgradeIds = options.ownedUpgradeIds,
  })
  local rng = RNG.new(runState.seed)
  local stageCount = 0

  while runState.runStatus == "active" do
    local stageState, stageDefinition = RunInitializer.createStageForCurrentRound(runState)
    local selection = chooseLoadoutSelection(runState, stageDefinition)
    local committedSelection, errorMessage = LoadoutSystem.commitLoadout(runState, selection)

    if not committedSelection then
      error(errorMessage)
    end

    local batchCount = 0

    while stageState.stageStatus == "active" do
      batchCount = batchCount + 1

      if batchCount > GameConfig.get("simulation.maxBatchesPerStage") then
        stageState.stageStatus = "failed"
        stageState.flags.simulationAborted = true
        break
      end

      local call = chooseCall(runState, stageState, metaProjection)
      local batchResult, batchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, call, rng)

      if not batchResult then
        error(batchError)
      end

      table.insert(runState.history.flipBatches, Utils.clone(batchResult.batch))
    end

    stageCount = stageCount + 1
    local stageRecord = RunHistorySystem.finalizeStage(runState, stageState, metaState)

    local shouldSimulateReward = (
      stageRecord.status == "cleared"
      and runState.runStatus == "active"
    ) or (
      stageRecord.stageType == "boss"
      and stageRecord.status == "cleared"
      and runState.runStatus == "won"
    )

    if shouldSimulateReward then
      simulateRewardChoice(runState, stageRecord, rng)
    end

    if runState.runStatus ~= "active" then
      break
    end

    if stageRecord.status == "cleared" then
      simulateShopVisit(runState, stageState, stageRecord, metaProjection, rng)
      ProgressionSystem.advanceToNextRound(runState)
    end
  end

  Validator.assertRuntimeInvariants("simulation_system.simulateRun", runState, nil, { history = true })

  return {
    seed = runState.seed,
    stageCount = stageCount,
    runState = Utils.clone(runState),
    metaState = Utils.clone(metaState),
    summary = SummarySystem.buildRunSummary(runState, nil),
  }
end

function SimulationSystem.simulateRuns(options)
  options = options or {}

  local runCount = options.runCount or GameConfig.get("simulation.runCount")
  local baseSeed = options.baseSeed or GameConfig.get("simulation.baseSeed")
  local seedStep = options.seedStep or GameConfig.get("simulation.seedStep")
  local results = {}

  for index = 1, runCount do
    table.insert(results, SimulationSystem.simulateRun({
      seed = baseSeed + ((index - 1) * seedStep),
      metaState = options.metaState,
      startingCollectionSize = options.startingCollectionSize,
      starterCollection = options.starterCollection,
      equippedCoinSlots = options.equippedCoinSlots,
      persistedLoadoutSlots = options.persistedLoadoutSlots,
      ownedUpgradeIds = options.ownedUpgradeIds,
    }))
  end

  return results
end

return SimulationSystem
