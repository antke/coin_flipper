local AcquisitionSystem = require("src.systems.acquisition_system")
local Coins = require("src.content.coins")
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

local function serializeDefinition(definition, contentType)
  return {
    type = contentType,
    contentId = definition.id,
    name = definition.name,
    rarity = definition.rarity,
    description = definition.description,
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

local function buildUpgradeCandidates(runState)
  local candidates = {}

  for _, definition in ipairs(Upgrades.getAll()) do
    if definition.rewardEligible ~= false and Upgrades.isUnlocked(definition, runState.unlockedUpgradeIds) then
      local ok = AcquisitionSystem.canGrantUpgrade(runState, definition.id)

      if ok then
        table.insert(candidates, definition)
      end
    end
  end

  return candidates
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
    table.insert(candidates, serializeDefinition(definition, "upgrade"))
  end

  return candidates
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

function RewardSystem.createPreviewRng(runState, stageRecord)
  if type(runState) ~= "table" then
    return nil
  end

  local seed = tostring(runState.seed or 1)
  local roundIndex = tostring(stageRecord and stageRecord.roundIndex or runState.roundIndex or 1)
  local stageId = tostring(stageRecord and stageRecord.stageId or runState.currentStageId or "unknown_stage")
  local derivedSeed = ((hashText(seed .. ":reward:" .. roundIndex .. ":" .. stageId) - 1) % 2147483646) + 1

  return RNG.new(derivedSeed)
end

function RewardSystem.buildPreviewForStage(runState, stageRecord)
  return RewardSystem.buildPreview(runState, RewardSystem.createPreviewRng(runState, stageRecord))
end

function RewardSystem.buildPreview(runState, rng)
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
    table.insert(options, serializeDefinition(upgradeDefinition, "upgrade"))
    upgradeCandidates = removeDefinition(upgradeCandidates, upgradeDefinition.id)
  end

  local extraCandidates = buildExtraCandidates(coinCandidates, upgradeCandidates)

  while #options < 4 do
    local extraOption = chooseSerializedOption(extraCandidates, rng)

    if not extraOption then
      break
    end

    table.insert(options, RewardSystem.serializeOption(extraOption))
    extraCandidates = removeSerializedOption(extraCandidates, extraOption)

    if extraOption.type == "coin" then
      coinCandidates = removeDefinition(coinCandidates, extraOption.contentId)
    elseif extraOption.type == "upgrade" then
      upgradeCandidates = removeDefinition(upgradeCandidates, extraOption.contentId)
    end
  end

  return {
    options = options,
    selectedIndex = nil,
    choice = nil,
    claimed = false,
  }
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
  elseif option.type == "upgrade" then
    ok, result = AcquisitionSystem.grantUpgrade(runState, option.contentId)
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
    elseif option.type == "upgrade" then
      ok, errorMessage = AcquisitionSystem.grantUpgrade(projectedRunState, option.contentId)
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
    upgradeCountBefore = #(runState.ownedUpgradeIds or {}),
    upgradeCountAfter = #(projectedRunState.ownedUpgradeIds or {}),
    shopPointsBefore = runState.shopPoints or 0,
    shopPointsAfter = projectedRunState.shopPoints or 0,
    shopRerollsBefore = runState.shopRerollsRemaining or 0,
    shopRerollsAfter = projectedRunState.shopRerollsRemaining or 0,
    maxSlotsBefore = runState.maxActiveCoinSlots or 0,
    maxSlotsAfter = projectedRunState.maxActiveCoinSlots or 0,
  }
end

return RewardSystem
