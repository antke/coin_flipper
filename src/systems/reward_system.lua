local AcquisitionSystem = require("src.systems.acquisition_system")
local ActionQueue = require("src.core.action_queue")
local Coins = require("src.content.coins")
local RNG = require("src.core.rng")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local RewardSystem = {}

local function isTrickType(contentType)
  return contentType == "trick" or contentType == "upgrade"
end

local REWARD_OPTION_COUNT = 3
local SKIP_INFLUENCE_REWARD = 1
local WILDCARD_CHANCE = 0.25
local WILDCARD_CAP = 1

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
    categories = { "fate" },
  },
  pit_boss = {
    label = "Pit Boss",
    categories = { "misdirection" },
  },
  magician = {
    label = "Magician",
    categories = { "sleight" },
  },
  showman = {
    label = "Showman",
    categories = { "prestige", "chain" },
  },
}

local function hashText(text)
  local hash = 2166136261

  for index = 1, #text do
    hash = (hash * 131 + string.byte(text, index)) % 2147483647
  end

  return hash
end

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
  }
end

local function buildCoinCandidates(runState)
  local candidates = {}

  for _, definition in ipairs(Coins.getAll()) do
    if definition.rewardEligible ~= false and Coins.isUnlocked(definition, runState.unlockedCoinIds) then
      local ok = AcquisitionSystem.canGrantCoin(runState, definition.id)

      if ok then
        table.insert(candidates, definition)
      end
    end
  end

  return candidates
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

local function buildExtraCandidates(coinCandidates, upgradeCandidates)
  local candidates = {}

  for _, definition in ipairs(coinCandidates or {}) do
    table.insert(candidates, serializeDefinition(definition, "coin"))
  end

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
  local preview = RewardSystem.buildPreview(runState, RewardSystem.createPreviewRng(runState, stageRecord, normalizedRerollCount), stageRecord)
  preview.rerollCount = normalizedRerollCount
  return preview
end

function RewardSystem.buildPreview(runState, rng, stageRecord)
  local classOptions, generation = chooseEnemyClassTrickOptions(runState, rng, stageRecord)

  if #classOptions > 0 then
    return {
      options = classOptions,
      selectedIndex = nil,
      choice = nil,
      claimed = false,
      generation = generation,
    }
  end

  local options = {}

  local coinCandidates = buildCoinCandidates(runState)
  local upgradeCandidates = buildUpgradeCandidates(runState)

  local coinDefinition = chooseDefinition(coinCandidates, rng)
  if coinDefinition then
    table.insert(options, serializeDefinition(coinDefinition, "coin"))
    coinCandidates = removeDefinition(coinCandidates, coinDefinition.id)
  end

  local upgradeDefinition = chooseDefinition(upgradeCandidates, rng)
  if upgradeDefinition then
    table.insert(options, serializeDefinition(upgradeDefinition, "trick"))
    upgradeCandidates = removeDefinition(upgradeCandidates, upgradeDefinition.id)
  end

  local extraCandidates = buildExtraCandidates(coinCandidates, upgradeCandidates)

  while #options < REWARD_OPTION_COUNT do
    local extraOption = chooseSerializedOption(extraCandidates, rng)

    if not extraOption then
      break
    end

    table.insert(options, RewardSystem.serializeOption(extraOption))
    extraCandidates = removeSerializedOption(extraCandidates, extraOption)

    if extraOption.type == "coin" then
      coinCandidates = removeDefinition(coinCandidates, extraOption.contentId)
    elseif isTrickType(extraOption.type) then
      upgradeCandidates = removeDefinition(upgradeCandidates, extraOption.contentId)
    end
  end

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
    and (#(session.options or {}) == 0 or session.claimed == true or session.selectedIndex ~= nil)
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

  local ok, result
  if option.type == "coin" then
    ok, result = AcquisitionSystem.grantCoin(runState, option.contentId)
  elseif isTrickType(option.type) then
    ok, result = AcquisitionSystem.grantTrick(runState, option.contentId)
  else
    return false, "invalid_reward_option_type"
  end

  if not ok then
    return false, result
  end

  session.choice = RewardSystem.serializeOption(option)
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
    local ok, errorMessage

    if option.type == "coin" then
      ok, errorMessage = AcquisitionSystem.grantCoin(projectedRunState, option.contentId)
    elseif isTrickType(option.type) then
      ok, errorMessage = AcquisitionSystem.grantTrick(projectedRunState, option.contentId)
    else
      return nil, "invalid_reward_option_type"
    end

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
