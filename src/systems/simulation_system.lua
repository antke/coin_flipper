local Coins = require("src.content.coins")
local FlipResolver = require("src.systems.flip_resolver")
local GameConfig = require("src.app.config")
local LoadoutSystem = require("src.systems.loadout_system")
local PurseHookSystem = require("src.systems.purse_hook_system")
local PurseSystem = require("src.systems.purse_system")
local PredictionSlotSystem = require("src.systems.prediction_slot_system")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local BossTrickSystem = require("src.systems.boss_trick_system")
local RunHistorySystem = require("src.systems.run_history_system")
local MetaState = require("src.domain.meta_state")
local ProgressionSystem = require("src.systems.progression_system")
local RNG = require("src.core.rng")
local RewardSystem = require("src.systems.reward_system")
local EncounterSystem = require("src.systems.encounter_system")
local RunInitializer = require("src.systems.run_initializer")
local ShopFlowSystem = require("src.systems.shop_flow_system")
local ShopSystem = require("src.systems.shop_system")
local Stages = require("src.content.stages")
local SummarySystem = require("src.systems.summary_system")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local TrickBoardSystem = require("src.systems.trick_board_system")
local Validator = require("src.core.validator")

local SimulationSystem = {}

local POLICY_ORDER = {
  "strategic",
  "synergy_aware",
  "naive",
  "heads_only",
  "tails_only",
}

local POLICY_DEFINITIONS = {
  strategic = {
    callMode = "adaptive",
    useForetoldCall = true,
    handSelection = "build_synergy",
    acquisitionMode = "generic",
    useReplacements = true,
  },
  synergy_aware = {
    callMode = "adaptive",
    useForetoldCall = true,
    handSelection = "build_synergy",
    acquisitionMode = "build_synergy",
    useReplacements = true,
  },
  naive = {
    callMode = "alternating",
    useForetoldCall = false,
    handSelection = "first_dealt",
    acquisitionMode = "first_legal",
    useReplacements = false,
  },
  heads_only = {
    callMode = "heads",
    useForetoldCall = false,
    handSelection = "build_synergy",
    acquisitionMode = "generic",
    useReplacements = true,
  },
  tails_only = {
    callMode = "tails",
    useForetoldCall = false,
    handSelection = "build_synergy",
    acquisitionMode = "generic",
    useReplacements = true,
  },
}

local COIN_TAG_SCORES = {
  score = 4,
  match = 3,
  weight = 2,
  score_scaling = 2,
  influence = 1,
}

local OFFER_TYPE_SCORES = {
  trick = 5,
  coin = 3,
}

local OFFER_TAG_SCORES = {
  score = 4,
  match = 3,
  score_scaling = 3,
  weight = 2,
  influence = 1,
  black_market = 1,
}

local function resolvePolicy(policy)
  local policyId = policy or GameConfig.get("simulation.policy", "strategic")

  if type(policyId) == "table" then
    return policyId, policyId.id or "custom"
  end

  local definition = POLICY_DEFINITIONS[policyId]
  if not definition then
    error("unknown simulation policy: " .. tostring(policyId))
  end

  return definition, policyId
end

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

local function definitionSupportsCategory(definition, category)
  if not definition or not category then
    return false
  end

  if definition.trick and definition.trick.category == category then
    return true
  end

  for _, field in ipairs({ "tags", "typeTags", "trick_synergy" }) do
    for _, value in ipairs(definition[field] or {}) do
      if value == category then
        return true
      end
    end
  end

  return false
end

local function scoreDefinitionForOwnedBuild(runState, definition)
  local score = 0
  local candidateCategory = definition and definition.trick and definition.trick.category or nil

  for _, trickId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
    local ownedDefinition = Upgrades.getById(trickId)
    local ownedCategory = ownedDefinition and ownedDefinition.trick and ownedDefinition.trick.category or nil

    if candidateCategory and ownedCategory == candidateCategory then
      score = score + 6
    elseif ownedCategory and definitionSupportsCategory(definition, ownedCategory) then
      score = score + 5
    end
  end

  for _, instance in ipairs(runState.coinInstances or {}) do
    local coinDefinition = Coins.getById(instance.definitionId or instance.coinId)
    if candidateCategory and definitionSupportsCategory(coinDefinition, candidateCategory) then
      score = score + 1.5
    end
  end

  if definition and definition.materialRank then
    score = score + math.max(0, definition.materialRank - 1) * 2
  end

  return score
end

local function scoreChoiceForBuild(runState, choice)
  if not choice then
    return -math.huge
  end

  if choice.type == "shop_points" then
    return (choice.amount or 0) * 1.5
  end

  if choice.type == "shop_rerolls" then
    return (choice.amount or 0) * 2
  end

  local definition = getOfferDefinition(choice)
  local score = definition and scoreDefinitionByTags(definition, OFFER_TAG_SCORES) or 0
  score = score + scoreDefinitionForOwnedBuild(runState, definition)
  score = score - ((choice.seizeCost or choice.price or 0) * 0.15)
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

  for slotIndex = 1, runState.maxFlipSlots do
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
    if coinState.bossForcedResult == "heads" or coinState.bossForcedResult == "tails" then
      score = score + (coinState.bossForcedResult == call and 1 or 0)
    else
      local totalWeight = math.max((coinState.headsWeight or 0) + (coinState.tailsWeight or 0), 0.00001)
      score = score + (((coinState[call .. "Weight"] or 0) / totalWeight))
    end
  end

  local bossTrick = BossTrickSystem.snapshot(shadowStageState)
  score = score * BossTrickSystem.getScoreScaling(bossTrick, call)

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

local function chooseCall(runState, stageState, metaProjection, policy)
  if policy.callMode == "heads" or policy.callMode == "tails" then
    return policy.callMode
  end

  if policy.callMode == "alternating" then
    return stageState.lastCall == "heads" and "tails" or "heads"
  end

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

local function chooseCallFromDealtHand(runState, stageState, fallbackCall, policy)
  if policy.useForetoldCall ~= true then
    return fallbackCall
  end

  local headsReads = 0
  local tailsReads = 0
  local forecast = PredictionSlotSystem.ensure(runState, stageState)
  local hasDefyFate = false
  local hasFulfilledFate = false
  local hasPredictionCoin = false
  local bossTrick = BossTrickSystem.snapshot(stageState)

  if bossTrick and bossTrick.trickId == "written_in_stone" then
    for _, result in ipairs(bossTrick.writtenSlotResults or {}) do
      if result == "heads" then headsReads = headsReads + 1 end
      if result == "tails" then tailsReads = tailsReads + 1 end
    end
  end

  for _, trickId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
    local lineId = Upgrades.getLineId(trickId)
    hasDefyFate = hasDefyFate or lineId == "defy_fate"
    hasFulfilledFate = hasFulfilledFate or lineId == "fulfilled_fate"
  end

  for _, entry in ipairs(PurseSystem.getDealtHandEntries(runState, stageState)) do
    if entry.foretoldResult == "heads" then
      headsReads = headsReads + 1
    elseif entry.foretoldResult == "tails" then
      tailsReads = tailsReads + 1
    end
    if forecast and PredictionSlotSystem.isPredictionCoin(entry.coinId) then
      hasPredictionCoin = true
      if forecast.result == "heads" then
        headsReads = headsReads + 1
      else
        tailsReads = tailsReads + 1
      end
    end
  end

  if forecast and hasPredictionCoin and hasDefyFate and not hasFulfilledFate then
    return forecast.result == "heads" and "tails" or "heads"
  end

  if headsReads ~= tailsReads then
    return headsReads > tailsReads and "heads" or "tails"
  end

  return fallbackCall
end

local function scoreDealtCoinForBuild(runState, entry, call, stageState)
  local definition = entry and entry.coinId and Coins.getById(entry.coinId) or nil
  local score = definition and ((definition.materialRank or 1) - 1) * 2 or 0

  if entry and entry.foretoldResult == call then
    score = score + 20
  elseif entry and entry.foretold == true then
    score = score - 4
  end

  for position, trickId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
    local trick = Upgrades.getById(trickId)
    local category = trick and trick.trick and (trick.trick.activationFamily or trick.trick.category) or nil
    local pressure = stageState and stageState.trickBoard and stageState.trickBoard.pressure
      and stageState.trickBoard.pressure[position] or nil
    local pressureValue = pressure and pressure.kind == "blocked" and 0
      or (pressure and pressure.kind == "weakened" and (pressure.multiplier or 0.5) or 1)

    if category and definition then
      local matchedFamily = definition.activationFamily == category

      if matchedFamily then
        score = score + (8 * pressureValue)
      end
    end
  end

  if definition and definition.archetype == "weighted" then
    score = score + 2
  end

  return score
end

local function selectFlipSlots(runState, stageState, call, policy)
  local candidates = PurseSystem.getDealtHandEntries(runState, stageState)

  if policy.handSelection == "first_dealt" then
    local selected = {}

    for index = 1, math.min(runState.maxFlipSlots or 1, #candidates) do
      selected[index] = candidates[index]
    end

    return PurseSystem.setSelectedSlotsFromEntries(runState, stageState, selected, {
      rule = "simulation_first_dealt",
    })
  end

  table.sort(candidates, function(left, right)
    local leftScore = scoreDealtCoinForBuild(runState, left, call, stageState)
    local rightScore = scoreDealtCoinForBuild(runState, right, call, stageState)

    if leftScore ~= rightScore then
      return leftScore > rightScore
    end

    return (left.dealtIndex or 0) < (right.dealtIndex or 0)
  end)

  local selected = {}
  for index = 1, math.min(runState.maxFlipSlots or 1, #candidates) do
    selected[index] = candidates[index]
  end

  local forecast = PredictionSlotSystem.ensure(runState, stageState)
  if forecast and selected[forecast.slotIndex] then
    local predictionIndex = nil
    for index, entry in ipairs(selected) do
      if PredictionSlotSystem.isPredictionCoin(entry.coinId) then
        predictionIndex = index
        break
      end
    end
    if predictionIndex then
      selected[predictionIndex], selected[forecast.slotIndex] = selected[forecast.slotIndex], selected[predictionIndex]
    end
  end

  local enemySkill = EnemySkillSystem.snapshot(stageState)
  local pressuredSlot = enemySkill and enemySkill.surface == "slot" and enemySkill.targetIndex or nil
  if pressuredSlot and selected[pressuredSlot] then
    local lowestIndex = pressuredSlot
    local lowestScore = scoreDealtCoinForBuild(runState, selected[pressuredSlot], call, stageState)
    for index, entry in ipairs(selected) do
      local score = scoreDealtCoinForBuild(runState, entry, call, stageState)
      if score < lowestScore then
        lowestIndex = index
        lowestScore = score
      end
    end
    selected[pressuredSlot], selected[lowestIndex] = selected[lowestIndex], selected[pressuredSlot]
  end

  local bossTrick = BossTrickSystem.snapshot(stageState)
  local writtenInStone = bossTrick and bossTrick.trickId == "written_in_stone"
  if writtenInStone and #selected > 0 then
    local orderedSlots = {}
    for slotIndex = 1, #selected do
      if bossTrick.writtenSlotResults[slotIndex] == call then
        table.insert(orderedSlots, slotIndex)
      end
    end
    for slotIndex = 1, #selected do
      if bossTrick.writtenSlotResults[slotIndex] ~= call then
        table.insert(orderedSlots, slotIndex)
      end
    end

    local arranged = {}
    for entryIndex, slotIndex in ipairs(orderedSlots) do
      arranged[slotIndex] = selected[entryIndex]
    end
    selected = arranged
  end
  local spotlightSlot = bossTrick and bossTrick.trickId == "centre_stage"
    and bossTrick.spotlightSlotIndex or nil
  local offTheBooksSlot = bossTrick and bossTrick.trickId == "nothing_to_declare"
    and bossTrick.offTheBooksSlotIndex or nil
  local protectedSlot = spotlightSlot or offTheBooksSlot
  if protectedSlot and selected[protectedSlot] then
    local strongestIndex = protectedSlot
    local strongestScore = scoreDealtCoinForBuild(runState, selected[protectedSlot], call, stageState)
    for index, entry in ipairs(selected) do
      local score = scoreDealtCoinForBuild(runState, entry, call, stageState)
      if score > strongestScore then
        strongestIndex = index
        strongestScore = score
      end
    end
    selected[protectedSlot], selected[strongestIndex] = selected[strongestIndex], selected[protectedSlot]
  end


  local fullThrottle = bossTrick and bossTrick.trickId == "full_throttle"
  if fullThrottle and #selected > 1 then
    table.sort(selected, function(left, right)
      local leftScore = scoreDealtCoinForBuild(runState, left, call, stageState)
      local rightScore = scoreDealtCoinForBuild(runState, right, call, stageState)
      if leftScore ~= rightScore then
        if bossTrick.leadSlotIndex == 1 then
          return leftScore < rightScore
        end
        return leftScore > rightScore
      end
      return (left.dealtIndex or 0) < (right.dealtIndex or 0)
    end)
  end

  local stolenIdentity = bossTrick and bossTrick.trickId == "stolen_identity"
  local victimSlot = stolenIdentity and bossTrick.victimSlotIndex or nil
  local impostorSlot = stolenIdentity and bossTrick.impostorSlotIndex or nil
  if victimSlot and impostorSlot and selected[victimSlot] and selected[impostorSlot] then
    local strongestIndex = victimSlot
    local strongestScore = scoreDealtCoinForBuild(runState, selected[victimSlot], call, stageState)
    for index, entry in ipairs(selected) do
      local score = scoreDealtCoinForBuild(runState, entry, call, stageState)
      if score > strongestScore then
        strongestIndex = index
        strongestScore = score
      end
    end
    selected[victimSlot], selected[strongestIndex] = selected[strongestIndex], selected[victimSlot]

    local weakestIndex = impostorSlot
    local weakestScore = scoreDealtCoinForBuild(runState, selected[impostorSlot], call, stageState)
    for index, entry in ipairs(selected) do
      if index ~= victimSlot then
        local score = scoreDealtCoinForBuild(runState, entry, call, stageState)
        if score < weakestScore then
          weakestIndex = index
          weakestScore = score
        end
      end
    end
    selected[impostorSlot], selected[weakestIndex] = selected[weakestIndex], selected[impostorSlot]
  end

  return PurseSystem.setSelectedSlotsFromEntries(runState, stageState, selected, {
    rule = "simulation_build_synergy",
  })
end

local function replaceWorstUnsupportedCoin(runState, stageState, call, policy, rng)
  if policy.useReplacements ~= true
    or not stageState.trickBoard
    or (stageState.trickBoard.replacementsRemaining or 0) <= 0
    or #(stageState.purse and stageState.purse.availableInstanceIds or {}) == 0 then
    return false
  end

  local supportedFamilies = {}
  for position, trickId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
    local definition = Upgrades.getById(trickId)
    local family = definition and definition.trick
      and (definition.trick.activationFamily or definition.trick.category) or nil
    if family and TrickBoardSystem.getEffectiveness(stageState, position) > 0 then
      supportedFamilies[family] = true
    end
  end
  if next(supportedFamilies) == nil then return false end

  local worst = nil
  local worstScore = math.huge
  for _, entry in ipairs(PurseSystem.getDealtHandEntries(runState, stageState)) do
    local coin = entry.coinId and Coins.getById(entry.coinId) or nil
    if coin and not supportedFamilies[coin.activationFamily] then
      local score = scoreDealtCoinForBuild(runState, entry, call, stageState)
      if score < worstScore then
        worst = entry
        worstScore = score
      end
    end
  end
  if not worst then return false end

  return PurseSystem.replaceHeldCoin(runState, stageState, worst.instanceId, rng)
end

local function scoreOfferForPurchase(runState, offer, nextStageDefinition, policy)
  local definition = getOfferDefinition(offer)
  local score = OFFER_TYPE_SCORES[offer.type] or 0

  if definition then
    score = score + scoreDefinitionByTags(definition, OFFER_TAG_SCORES)

    if nextStageDefinition and nextStageDefinition.stageType == "boss" and hasTag(definition, "boss") then
      score = score + 6
    end
  end

  score = score - ((offer.price or 0) * 0.15)

  if policy.acquisitionMode == "build_synergy" then
    score = score + scoreDefinitionForOwnedBuild(runState, definition)
  end

  return score
end

local function choosePurchaseIndex(runState, offers, nextStageDefinition, policy)
  local candidates = {}

  for index, offer in ipairs(offers or {}) do
    if not offer.purchased and (offer.price or 0) <= (runState.influence or 0) then
      table.insert(candidates, {
        index = index,
        score = scoreOfferForPurchase(runState, offer, nextStageDefinition, policy),
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
    if not offer.purchased and (offer.price or 0) <= (runState.influence or 0) then
      return false
    end
  end

  return true
end

local function simulateShopVisit(runState, stageState, stageRecord, metaProjection, rng, policy)
  local shopFlow = ShopFlowSystem.createVisit(runState, stageState, metaProjection, rng, {
    sourceStageId = stageRecord.stageId,
    roundIndex = stageRecord.roundIndex,
  })

  ShopFlowSystem.ensureOffers(shopFlow)

  local actionCount = 0
  while actionCount < GameConfig.get("simulation.maxShopActionsPerVisit") do
    local nextStageDefinition = Stages.getForRound(runState.roundIndex + 1, runState)
    local purchaseIndex = choosePurchaseIndex(runState, shopFlow.offers, nextStageDefinition, policy)

    if purchaseIndex then
      local offer = shopFlow.offers[purchaseIndex]
      if offer and (offer.type == "trick" or offer.type == "upgrade") then
        local canAcquire, acquisition = TrickBoardSystem.canAcquire(runState, offer.contentId)
        if not canAcquire and type(acquisition) == "table" and acquisition.code == "trick_board_full" then
          local replacementPosition = 1
          local lowestTier = math.huge
          for position, trickId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
            local definition = Upgrades.getById(trickId)
            local tier = definition and definition.trick and definition.trick.tier or 1
            if tier < lowestTier then
              lowestTier = tier
              replacementPosition = position
            end
          end
          offer.replacePosition = replacementPosition
        end
      end
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

local function chooseRewardOptionIndex(runState, session, policy)
  if not session or #(session.options or {}) == 0 then
    return nil
  end

  local bestIndex = nil
  local bestScore = -math.huge

  for index, option in ipairs(session.options or {}) do
    if (option.type == "trick" or option.type == "upgrade")
      and (option.seizeCost or 0) <= (runState.influence or 0) then
      if policy.acquisitionMode ~= "build_synergy" then
        return index
      end

      local score = scoreChoiceForBuild(runState, option)
      if score > bestScore then
        bestIndex = index
        bestScore = score
      end
    end
  end

  return bestIndex
end

local function simulateRewardChoice(runState, stageRecord, rng, policy)
  local session = RewardSystem.buildPreviewForStage(runState, stageRecord)
  RunHistorySystem.recordStageRewardPreview(stageRecord, session)

  local selectedIndex = chooseRewardOptionIndex(runState, session, policy)
  if selectedIndex then
    RewardSystem.selectOption(session, selectedIndex)
    local option = session.options[selectedIndex]
    local canAcquire, acquisition = TrickBoardSystem.canAcquire(runState, option.contentId)
    if not canAcquire and type(acquisition) == "table" and acquisition.code == "trick_board_full" then
      local replacementPosition = 1
      local lowestTier = math.huge
      for position, trickId in ipairs(runState.ownedTrickIds or {}) do
        local definition = Upgrades.getById(trickId)
        local tier = tonumber(definition and definition.trick and definition.trick.tier) or 1
        if tier < lowestTier then
          lowestTier = tier
          replacementPosition = position
        end
      end
      session.replacementRequired = true
      session.replacePosition = replacementPosition
    end
  end

  local ok, choiceOrError
  if selectedIndex then
    ok, choiceOrError = RewardSystem.claimSelection(runState, session)
  else
    ok, choiceOrError = RewardSystem.claimSkip(runState, session)
  end
  if not ok then
    error(choiceOrError or "reward_claim_failed")
  end

  RunHistorySystem.recordStageRewardChoice(stageRecord, choiceOrError)
end

local function chooseEncounterChoiceIndex(runState, session, policy)
  if not session or #(session.choices or {}) == 0 then
    return nil
  end

  local bestIndex = nil
  local bestScore = -math.huge

  for index, choice in ipairs(session.choices or {}) do
    if policy.acquisitionMode ~= "build_synergy" then
      if choice.type == "trick" or choice.type == "upgrade" or choice.type == "coin" then
        return index
      end
    else
      local score = scoreChoiceForBuild(runState, choice)
      if score > bestScore then
        bestIndex = index
        bestScore = score
      end
    end
  end

  return bestIndex or session.selectedIndex or 1
end

local function simulateEncounterChoice(runState, stageRecord, policy)
  local session = EncounterSystem.buildSession(runState)
  RunHistorySystem.recordStageEncounterPreview(stageRecord, session)

  local selectedIndex = chooseEncounterChoiceIndex(runState, session, policy)
  if selectedIndex then
    EncounterSystem.selectChoice(session, selectedIndex, runState)
    if session.replacementRequired then
      local replacementPosition = 1
      local lowestTier = math.huge
      for position, trickId in ipairs(runState.ownedTrickIds or runState.ownedUpgradeIds or {}) do
        local definition = Upgrades.getById(trickId)
        local tier = definition and definition.trick and definition.trick.tier or 1
        if tier < lowestTier then
          lowestTier = tier
          replacementPosition = position
        end
      end
      EncounterSystem.selectReplacementPosition(
        session,
        replacementPosition,
        #(runState.ownedTrickIds or runState.ownedUpgradeIds or {})
      )
    end
  end

  local ok, choiceOrError = EncounterSystem.claimChoice(runState, session)
  if not ok then
    error(choiceOrError or "encounter_claim_failed")
  end

  RunHistorySystem.recordStageEncounterChoice(stageRecord, choiceOrError)
end

function SimulationSystem.simulateRun(options)
  options = options or {}
  local policy, policyId = resolvePolicy(options.policy)

  local metaState = cloneMetaState(options.metaState)
  local runState, metaProjection = RunInitializer.createNewRun(metaState, {
    seed = options.seed,
    startingCollectionSize = options.startingCollectionSize,
    starterCollection = options.starterCollection,
    flipSlots = options.flipSlots or options.equippedCoinSlots,
    persistedFlipSlots = options.persistedFlipSlots or options.persistedLoadoutSlots,
    ownedTrickIds = options.ownedTrickIds or options.ownedUpgradeIds,
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

      local call = chooseCall(runState, stageState, metaProjection, policy)
      local _, dealWarning = PurseSystem.dealHand(runState, stageState, rng)
      local dealHookTrace = PurseHookSystem.runAfterDealBeforeSelection(runState, stageState, metaProjection, { call = call, rng = rng })

      call = chooseCallFromDealtHand(runState, stageState, call, policy)
      if dealHookTrace then
        dealHookTrace.call = call
        local hookHistory = stageState.purse and stageState.purse.hookHistory or {}
        local storedTrace = hookHistory[#hookHistory]
        if storedTrace and storedTrace.phase == "after_deal_before_selection" and storedTrace.batchId == stageState.batchIndex + 1 then
          storedTrace.call = call
        end
      end

      if dealWarning ~= "purse_empty" then
        replaceWorstUnsupportedCoin(runState, stageState, call, policy, rng)
        local selected, selectionError = selectFlipSlots(runState, stageState, call, policy)
        if not selected then
          error(selectionError or "simulation_selection_failed")
        end
      end

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
      simulateRewardChoice(runState, stageRecord, rng, policy)
    end

    if runState.runStatus ~= "active" then
      break
    end

    if stageRecord.status == "cleared" then
      simulateEncounterChoice(runState, stageRecord, policy)
      simulateShopVisit(runState, stageState, stageRecord, metaProjection, rng, policy)
      ProgressionSystem.advanceToNextRound(runState)
    end
  end

  Validator.assertRuntimeInvariants("simulation_system.simulateRun", runState, nil, { history = true })

  return {
    seed = runState.seed,
    policyId = policyId,
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
      flipSlots = options.flipSlots or options.equippedCoinSlots,
      persistedFlipSlots = options.persistedFlipSlots or options.persistedLoadoutSlots,
      ownedTrickIds = options.ownedTrickIds or options.ownedUpgradeIds,
      policy = options.policy,
    }))
  end

  return results
end

function SimulationSystem.getPolicyIds()
  return Utils.copyArray(POLICY_ORDER)
end

function SimulationSystem.getPolicyDefinition(policyId)
  local definition = POLICY_DEFINITIONS[policyId]
  return definition and Utils.clone(definition) or nil
end

return SimulationSystem
