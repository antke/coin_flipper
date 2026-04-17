local AcquisitionSystem = require("src.systems.acquisition_system")
local Coins = require("src.content.coins")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local RewardSystem = {}

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

function RewardSystem.serializeOption(option)
  return Utils.clone(option)
end

function RewardSystem.buildPreview(runState, rng)
  local options = {}

  local coinDefinition = chooseDefinition(buildCoinCandidates(runState), rng)
  if coinDefinition then
    table.insert(options, serializeDefinition(coinDefinition, "coin"))
  end

  local upgradeDefinition = chooseDefinition(buildUpgradeCandidates(runState), rng)
  if upgradeDefinition then
    table.insert(options, serializeDefinition(upgradeDefinition, "upgrade"))
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

  if type(index) ~= "number" or index < 1 or index > #(session.options or {}) then
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
