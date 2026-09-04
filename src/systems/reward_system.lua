local AcquisitionSystem = require("src.systems.acquisition_system")
local ActionQueue = require("src.core.action_queue")
local CrumbleSystem = require("src.systems.crumble_system")
local EconomyContent = require("src.content.economy")
local RNG = require("src.core.rng")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local RewardSystem = {}

local function hashText(text)
  local hash = 2166136261

  for index = 1, #text do
    hash = (hash * 131 + string.byte(text, index)) % 2147483647
  end

  return hash
end

local function isTrickType(contentType)
  return contentType == "trick" or contentType == "upgrade"
end

local REWARD_OPTION_COUNT = 3
local SKIP_INFLUENCE_REWARD = 1
local WILDCARD_CHANCE = 0.25
local WILDCARD_CAP = 1
local TAKE_WHATS_OWED_DISCOUNT = 2

local ENEMY_CLASS_POOLS = {
  forger = {
    label = "Forger",
    categories = { "forgery" },
  },
  smuggler = {
    label = "Smuggler",
    categories = { "smuggle" },
  },
  card_shark = {
    label = "Card Shark",
    categories = { "prediction", "weighted" },
  },
  fortune_teller = {
    label = "Fortune Teller",
    categories = { "prediction" },
  },
  pit_boss = {
    label = "Pit Boss",
    categories = { "weighted", "forgery" },
  },
  magician = {
    label = "Magician",
    categories = { "sleight" },
  },
  showman = {
    label = "Showman",
    categories = { "prestige", "momentum" },
  },
}

local function serializeDefinition(definition, contentType, metadata)
  metadata = metadata or {}

  return {
    type = contentType,
    contentId = definition.id,
    name = definition.name,
    rarity = definition.rarity,
    description = definition.description,
    rewardSource = metadata.rewardSource,
    enemyClass = metadata.enemyClass,
    enemyClassLabel = metadata.enemyClassLabel,
    rewardPoolCategories = Utils.clone(metadata.rewardPoolCategories),
    wildcard = metadata.wildcard,
    wildcardChance = metadata.wildcardChance,
    wildcardCap = metadata.wildcardCap,
    trickCategory = definition.trick and definition.trick.category or nil,
    trickTags = definition.trick and Utils.clone(definition.trick.tags) or nil,
    extortionEffect = metadata.extortionEffect,
    extortionSourceId = metadata.extortionSourceId,
  }
end

local function buildOwnedIndex(runState)
  local index = {}

  for _, trickId in ipairs(runState and (runState.ownedTrickIds or runState.ownedUpgradeIds) or {}) do
    index[trickId] = true
  end

  return index
end

local function getSeizeBaseCost(rarity)
  return EconomyContent.shop.coinRarityPrices[rarity or "common"] or EconomyContent.shop.fallbackPrice
end

local function applySeizeCosts(runState, options)
  local source = CrumbleSystem.findOwnedEffectSource(runState, "spoils_seize_discount")
  local discount = source and ((source.definition.extortion and source.definition.extortion.value) or TAKE_WHATS_OWED_DISCOUNT) or 0

  for _, option in ipairs(options or {}) do
    if isTrickType(option.type) then
      local baseCost = getSeizeBaseCost(option.rarity)
      option.baseSeizeCost = baseCost

      if source then
        option.seizeDiscount = math.min(discount, baseCost)
        option.seizeDiscountSourceId = source.trickId
      else
        option.seizeDiscount = 0
        option.seizeDiscountSourceId = nil
      end

      option.seizeCost = math.max(0, baseCost - (option.seizeDiscount or 0))
    end
  end
end

local function buildCategoryIndex(categories)
  if type(categories) ~= "table" then
    return nil
  end

  local index = {}

  for _, category in ipairs(categories) do
    if type(category) == "string" and category ~= "" then
      index[category] = true
    end
  end

  return index
end

local function definitionMatchesCategories(definition, categoryIndex)
  if not categoryIndex then
    return true
  end

  local trick = definition and definition.trick or nil
  if trick and categoryIndex[trick.category] then
    return true
  end

  for _, tag in ipairs((trick and trick.tags) or definition.tags or {}) do
    if categoryIndex[tag] then
      return true
    end
  end

  return false
end

local function buildUpgradeCandidates(runState, categories)
  local candidates = {}
  local categoryIndex = buildCategoryIndex(categories)

  for _, definition in ipairs(Upgrades.getAll()) do
    if definition.rewardEligible ~= false
      and definitionMatchesCategories(definition, categoryIndex)
      and Upgrades.isUnlocked(definition, runState.unlockedTrickIds or runState.unlockedUpgradeIds) then
      local ok = AcquisitionSystem.canGrantUpgrade(runState, definition.id)

      if ok then
        table.insert(candidates, definition)
      end
    end
  end

  return candidates
end

local function buildWildcardUpgradeCandidates(runState, categories)
  local candidates = {}
  local categoryIndex = buildCategoryIndex(categories)

  for _, definition in ipairs(Upgrades.getAll()) do
    if definition.rewardEligible ~= false
      and not definitionMatchesCategories(definition, categoryIndex)
      and Upgrades.isUnlocked(definition, runState.unlockedTrickIds or runState.unlockedUpgradeIds) then
      local ok = AcquisitionSystem.canGrantUpgrade(runState, definition.id)

      if ok then
        table.insert(candidates, definition)
      end
    end
  end

  return candidates
end

local function getEnemyClassPool(enemyClass)
  if type(enemyClass) ~= "string" or enemyClass == "" then
    return nil
  end

  return ENEMY_CLASS_POOLS[enemyClass]
end

local function getStageEnemyClass(stageRecord)
  if type(stageRecord) ~= "table" then
    return nil
  end

  return stageRecord.enemyClass or stageRecord.opponentEnemyClass or stageRecord.opponentClass
end

local function chooseDefinition(candidates, rng)
  if #candidates == 0 then
    return nil
  end

  if rng and rng.choose then
    return rng:choose(candidates)
  end

  return candidates[1]
end

local function chooseSerializedOption(candidates, rng)
  if #candidates == 0 then
    return nil
  end

  if rng and rng.choose then
    return rng:choose(candidates)
  end

  return candidates[1]
end

local function removeDefinition(candidates, definitionId)
  local filtered = {}

  for _, definition in ipairs(candidates or {}) do
    if definition.id ~= definitionId then
      table.insert(filtered, definition)
    end
  end

  return filtered
end

local function buildExtraCandidates(upgradeCandidates)
  local candidates = {}

  for _, definition in ipairs(upgradeCandidates or {}) do
    table.insert(candidates, serializeDefinition(definition, "trick"))
  end

  return candidates
end

local function buildRewardMetadata(enemyClass, classPool, rewardSource, wildcard)
  return {
    rewardSource = rewardSource,
    enemyClass = enemyClass,
    enemyClassLabel = classPool and classPool.label or nil,
    rewardPoolCategories = classPool and Utils.copyArray(classPool.categories or {}) or nil,
    wildcard = wildcard == true,
    wildcardChance = WILDCARD_CHANCE,
    wildcardCap = WILDCARD_CAP,
  }
end

local function chooseEnemyClassTrickOptions(runState, rng, stageRecord)
  local enemyClass = getStageEnemyClass(stageRecord)
  local classPool = getEnemyClassPool(enemyClass)

  if not classPool then
    return {}, {
      enemyClass = enemyClass,
      enemyClassLabel = nil,
      rewardPoolCategories = {},
      wildcardChance = WILDCARD_CHANCE,
      wildcardCap = WILDCARD_CAP,
      wildcardOfferCount = 0,
      classOfferCount = 0,
      optionCount = 0,
    }
  end

  local allUpgradeCandidates = buildUpgradeCandidates(runState)
  local classUpgradeCandidates = buildUpgradeCandidates(runState, classPool.categories)
  local wildcardUpgradeCandidates = buildWildcardUpgradeCandidates(runState, classPool.categories)
  local options = {}
  local wildcardCount = 0
  local classOfferCount = 0

  local function removeChosen(definition)
    allUpgradeCandidates = removeDefinition(allUpgradeCandidates, definition.id)
    classUpgradeCandidates = removeDefinition(classUpgradeCandidates, definition.id)
    wildcardUpgradeCandidates = removeDefinition(wildcardUpgradeCandidates, definition.id)
  end

  while #options < REWARD_OPTION_COUNT and #allUpgradeCandidates > 0 do
    local useWildcard = false

    if classPool then
      if #classUpgradeCandidates > 0
        and #wildcardUpgradeCandidates > 0
        and wildcardCount < WILDCARD_CAP
        and rng
        and rng.nextFloat
        and rng:nextFloat() < WILDCARD_CHANCE then
        useWildcard = true
      end
    end

    local sourceCandidates = useWildcard and wildcardUpgradeCandidates or classUpgradeCandidates
    local definition = chooseDefinition(sourceCandidates, rng)

    if not definition and not useWildcard and wildcardCount < WILDCARD_CAP then
      useWildcard = true
      sourceCandidates = wildcardUpgradeCandidates
      definition = chooseDefinition(sourceCandidates, rng)
    end

    if not definition then
      break
    end

    local rewardSource = useWildcard and "wildcard" or "enemy_class"
    local metadata = buildRewardMetadata(enemyClass, classPool, rewardSource, useWildcard)

    table.insert(options, serializeDefinition(definition, "trick", metadata))
    removeChosen(definition)

    if useWildcard then
      wildcardCount = wildcardCount + 1
    else
      classOfferCount = classOfferCount + 1
    end

  end

  return options, {
    enemyClass = enemyClass,
    enemyClassLabel = classPool and classPool.label or nil,
    rewardPoolCategories = classPool and Utils.copyArray(classPool.categories or {}) or {},
    wildcardChance = WILDCARD_CHANCE,
    wildcardCap = WILDCARD_CAP,
    wildcardOfferCount = wildcardCount,
    classOfferCount = classOfferCount,
    optionCount = #options,
  }
end

local function removeSerializedOption(candidates, option)
  local filtered = {}

  for _, candidate in ipairs(candidates or {}) do
    if not (candidate.type == option.type and candidate.contentId == option.contentId) then
      table.insert(filtered, candidate)
    end
  end

  return filtered
end

local function chooseExcludedDefinition(candidates, rng, excludedIds)
  local filtered = {}

  for _, definition in ipairs(candidates or {}) do
    if not excludedIds[definition.id] then
      table.insert(filtered, definition)
    end
  end

  return chooseDefinition(filtered, rng)
end

local function appendSpoilsOption(options, definition, metadata)
  if not definition then
    return nil
  end

  local option = serializeDefinition(definition, "trick", metadata)
  table.insert(options, option)
  return option
end

local function consumeSpoilsSource(runState, source, effects, reason, option)
  local crumble = source and CrumbleSystem.consumeUse(runState, source.trickId, reason) or nil

  table.insert(effects, {
    effect = source and source.definition and source.definition.extortion and source.definition.extortion.effect or nil,
    sourceId = source and source.trickId or nil,
    contentId = option and option.contentId or nil,
    crumble = crumble,
  })
end

local function applySpoilsPreviewExtortion(runState, rng, stageRecord, options, generation, rerollCount)
  if math.max(0, math.floor(tonumber(rerollCount) or 0)) ~= 0 then
    return
  end

  local effects = {}
  local excludedIds = buildOwnedIndex(runState)

  for _, option in ipairs(options or {}) do
    excludedIds[option.contentId] = true
  end

  local function addFromSource(effectName, categories, metadata, reason, filter)
    local source = CrumbleSystem.findOwnedEffectSource(runState, effectName)
    if not source then
      return
    end

    local candidates = buildUpgradeCandidates(runState, categories)

    if filter then
      local filtered = {}
      for _, candidate in ipairs(candidates) do
        if filter(candidate) then
          table.insert(filtered, candidate)
        end
      end
      candidates = filtered
    end

    local definition = chooseExcludedDefinition(candidates, rng, excludedIds)

    if not definition then
      table.insert(effects, {
        effect = effectName,
        sourceId = source.trickId,
        skipped = true,
        skipReason = "no_spoils_option_available",
      })
      return
    end

    metadata = metadata or {}
    metadata.rewardSource = metadata.rewardSource or "extortion"
    metadata.extortionEffect = effectName
    metadata.extortionSourceId = source.trickId
    local option = appendSpoilsOption(options, definition, metadata)
    excludedIds[definition.id] = true
    consumeSpoilsSource(runState, source, effects, reason, option)
  end

  local enemyClass = getStageEnemyClass(stageRecord)
  local classPool = getEnemyClassPool(enemyClass)

  addFromSource("extra_spoils_option", nil, {
    rewardSource = "extortion_extra_spoils",
  }, "spoils_screen")

  if classPool then
    addFromSource("extra_enemy_family_spoils", classPool.categories, buildRewardMetadata(enemyClass, classPool, "extortion_enemy_family", false), "spoils_screen")
  end

  addFromSource("reveal_higher_tier_spoils", nil, {
    rewardSource = "extortion_higher_tier",
  }, "spoils_screen", function(definition)
    return Upgrades.getTier(definition) >= 2
  end)

  if #effects > 0 then
    generation.extortionEffects = effects
  end
end

function RewardSystem.serializeOption(option)
  return Utils.clone(option)
end

function RewardSystem.createPreviewRng(runState, stageRecord, rerollCount)
  if type(runState) ~= "table" then
    return nil
  end

  local seed = tostring(runState.seed or 1)
  local roundIndex = tostring(stageRecord and stageRecord.roundIndex or runState.roundIndex or 1)
  local stageId = tostring(stageRecord and stageRecord.stageId or runState.currentStageId or "unknown_stage")
  local rerollKey = tostring(math.max(0, math.floor(tonumber(rerollCount) or 0)))
  local seedKey = seed .. ":reward:" .. roundIndex .. ":" .. stageId

  if rerollKey ~= "0" then
    seedKey = seedKey .. ":reroll:" .. rerollKey
  end

  local derivedSeed = ((hashText(seedKey) - 1) % 2147483646) + 1

  return RNG.new(derivedSeed)
end

function RewardSystem.buildPreviewForStage(runState, stageRecord, rerollCount)
  local normalizedRerollCount = math.max(0, math.floor(tonumber(rerollCount) or 0))
  local preview = RewardSystem.buildPreview(runState, RewardSystem.createPreviewRng(runState, stageRecord, normalizedRerollCount), stageRecord, normalizedRerollCount)
  preview.rerollCount = normalizedRerollCount
  return preview
end

function RewardSystem.buildPreview(runState, rng, stageRecord, rerollCount)
  local classOptions, generation = chooseEnemyClassTrickOptions(runState, rng, stageRecord)

  if #classOptions > 0 then
    applySpoilsPreviewExtortion(runState, rng, stageRecord, classOptions, generation, rerollCount)
    applySeizeCosts(runState, classOptions)
    generation.optionCount = #classOptions

    return {
      options = classOptions,
      selectedIndex = nil,
      choice = nil,
      claimed = false,
      generation = generation,
    }
  end

  local options = {}
  local upgradeCandidates = buildUpgradeCandidates(runState)

  local upgradeDefinition = chooseDefinition(upgradeCandidates, rng)
  if upgradeDefinition then
    table.insert(options, serializeDefinition(upgradeDefinition, "trick"))
    upgradeCandidates = removeDefinition(upgradeCandidates, upgradeDefinition.id)
  end

  local extraCandidates = buildExtraCandidates(upgradeCandidates)

  while #options < REWARD_OPTION_COUNT do
    local extraOption = chooseSerializedOption(extraCandidates, rng)

    if not extraOption then
      break
    end

    table.insert(options, RewardSystem.serializeOption(extraOption))
    extraCandidates = removeSerializedOption(extraCandidates, extraOption)

    if isTrickType(extraOption.type) then
      upgradeCandidates = removeDefinition(upgradeCandidates, extraOption.contentId)
    end
  end

  applySpoilsPreviewExtortion(runState, rng, stageRecord, options, generation, rerollCount)
  applySeizeCosts(runState, options)
  generation.optionCount = #options

  return {
    options = options,
    selectedIndex = nil,
    choice = nil,
    claimed = false,
    generation = generation,
  }
end

function RewardSystem.rerollPreview(runState, session, stageRecord)
  if type(session) ~= "table" then
    return false, "reward_preview_not_initialized"
  end

  if session.claimed == true then
    return false, "reward_already_claimed"
  end

  local rerollCount = math.max(0, math.floor(tonumber(session.rerollCount) or 0)) + 1
  local preview = RewardSystem.buildPreviewForStage(runState, stageRecord, rerollCount)

  session.options = preview.options
  session.selectedIndex = nil
  session.choice = nil
  session.claimed = false
  session.generation = preview.generation
  session.rerollCount = rerollCount
  session.skipped = false
  session.replacementRequired = false
  session.replacePosition = nil
  session.replacementMetadata = nil

  return true, session
end

function RewardSystem.getSkipInfluenceReward()
  return SKIP_INFLUENCE_REWARD
end

function RewardSystem.selectOption(session, index)
  if type(session) ~= "table" then
    return false, "reward_preview_not_initialized"
  end

  if session.claimed == true then
    return false, "reward_already_claimed"
  end

  if type(index) ~= "number" then
    return false, "invalid_reward_option"
  end

  index = math.floor(index)

  if index < 1 or index > #(session.options or {}) then
    return false, "invalid_reward_option"
  end

  session.selectedIndex = index
  return true, session.options[index]
end

function RewardSystem.canContinue(session)
  return type(session) == "table"
    and (#(session.options or {}) == 0 or session.claimed == true
      or (session.selectedIndex ~= nil and (session.replacementRequired ~= true or session.replacePosition ~= nil)))
end

function RewardSystem.selectReplacementPosition(session, position, activeCount)
  if type(session) ~= "table" then return false, "reward_preview_not_initialized" end
  position = tonumber(position)
  if not position or position < 1 or position > (activeCount or 0) or math.floor(position) ~= position then
    return false, "invalid_trick_replacement_position"
  end
  session.replacePosition = position
  return true, position
end

function RewardSystem.claimSkip(runState, session)
  if type(session) ~= "table" then
    return false, "reward_preview_not_initialized"
  end

  if session.claimed == true then
    return false, "reward_already_claimed"
  end

  local amount = RewardSystem.getSkipInfluenceReward()
  local influenceBefore = runState.influence or 0
  local context = ActionQueue.createContext("reward_skip", {
    runState = runState,
  })

  ActionQueue.applyAll(runState, nil, context, {
    {
      op = "add_influence",
      amount = amount,
      applyMultiplier = false,
      category = "reward_skip",
      label = "reward_skip",
    },
  })

  local appliedAmount = (runState.influence or 0) - influenceBefore
  local choice = {
    type = "currency",
    contentId = "skip_influence",
    name = string.format("+%d Influence", appliedAmount),
    description = string.format("Skipped the reward choice for +%d Influence.", appliedAmount),
    amount = appliedAmount,
    currency = "influence",
  }

  session.selectedIndex = nil
  session.choice = RewardSystem.serializeOption(choice)
  session.claimed = true
  session.skipped = true

  return true, session.choice
end

function RewardSystem.claimSelection(runState, session)
  if type(session) ~= "table" then
    return false, "reward_preview_not_initialized"
  end

  if session.claimed then
    return true, session.choice
  end

  if #(session.options or {}) == 0 then
    session.claimed = true
    return true, nil
  end

  local option = session.selectedIndex and session.options[session.selectedIndex] or nil

  if not option then
    return false, "reward_option_not_selected"
  end

  if not isTrickType(option.type) then
    return false, "invalid_reward_option_type"
  end

  local seizeCost = math.max(0, math.floor(tonumber(option.seizeCost) or getSeizeBaseCost(option.rarity)))

  if (runState.influence or 0) < seizeCost then
    return false, "not_enough_influence"
  end

  local grantOk, grantResult = AcquisitionSystem.canGrantByType(runState, option.type, option.contentId)

  if not grantOk then
    return false, grantResult
  end

  runState.influence = (runState.influence or 0) - seizeCost

  if option.seizeDiscountSourceId then
    option.seizeDiscountCrumble = CrumbleSystem.consumeUse(runState, option.seizeDiscountSourceId, "seized_charm")
  end

  local ok, result = AcquisitionSystem.grantTrick(runState, option.contentId, nil, {
    replacePosition = session.replacePosition,
  })

  if not ok then
    return false, result
  end

  session.choice = RewardSystem.serializeOption(option)
  session.choice.replacedTrickPosition = session.replacePosition
  session.claimed = true
  return true, session.choice
end

function RewardSystem.buildProjectedOutcome(runState, session)
  if type(runState) ~= "table" then
    return nil, "run_not_initialized"
  end

  if type(session) ~= "table" then
    return nil, "reward_preview_not_initialized"
  end

  local projectedRunState = Utils.clone(runState)
  local option = nil

  if session.claimed then
    option = session.choice and RewardSystem.serializeOption(session.choice) or nil
  elseif #(session.options or {}) > 0 and session.selectedIndex ~= nil then
    option = session.options[session.selectedIndex]
  end

  if option and session.claimed ~= true then
    if not isTrickType(option.type) then
      return nil, "invalid_reward_option_type"
    end

    local seizeCost = math.max(0, math.floor(tonumber(option.seizeCost) or getSeizeBaseCost(option.rarity)))

    if (projectedRunState.influence or 0) < seizeCost then
      return nil, "not_enough_influence"
    end

    projectedRunState.influence = (projectedRunState.influence or 0) - seizeCost

    if option.seizeDiscountSourceId then
      CrumbleSystem.consumeUse(projectedRunState, option.seizeDiscountSourceId, "seized_charm")
    end

    local ok, errorMessage = AcquisitionSystem.grantTrick(projectedRunState, option.contentId, nil, {
      replacePosition = session.replacePosition,
    })

    if not ok then
      return nil, errorMessage
    end
  end

  return {
    option = option and RewardSystem.serializeOption(option) or nil,
    claimed = session.claimed == true,
    projectedRunState = projectedRunState,
    collectionSizeBefore = #(runState.collectionCoinIds or {}),
    collectionSizeAfter = #(projectedRunState.collectionCoinIds or {}),
    upgradeCountBefore = #(runState.ownedTrickIds or runState.ownedUpgradeIds or {}),
    upgradeCountAfter = #(projectedRunState.ownedTrickIds or projectedRunState.ownedUpgradeIds or {}),
    influenceBefore = runState.influence or 0,
    influenceAfter = projectedRunState.influence or 0,
    shopPointsBefore = runState.influence or 0,
    shopPointsAfter = projectedRunState.influence or 0,
    shopRerollsBefore = runState.shopRerollsRemaining or 0,
    shopRerollsAfter = projectedRunState.shopRerollsRemaining or 0,
    maxSlotsBefore = runState.maxFlipSlots or runState.maxActiveCoinSlots or 0,
    maxSlotsAfter = projectedRunState.maxFlipSlots or projectedRunState.maxActiveCoinSlots or 0,
  }
end

return RewardSystem
