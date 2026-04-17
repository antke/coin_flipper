local AcquisitionSystem = require("src.systems.acquisition_system")
local Coins = require("src.content.coins")
local Encounters = require("src.content.encounters")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local EncounterSystem = {}

local function serializeChoice(choice)
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

local function canUseChoice(runState, choice)
  if choice.type == "shop_points" then
    return true
  end

  if choice.type == "shop_rerolls" then
    return true
  end

  if choice.type == "coin" then
    return AcquisitionSystem.canGrantCoin(runState, choice.contentId)
  end

  if choice.type == "upgrade" then
    return AcquisitionSystem.canGrantUpgrade(runState, choice.contentId)
  end

  return false, "invalid_encounter_choice_type"
end

local function buildEligibleChoices(runState, definition)
  local choices = {}

  for _, choice in ipairs(definition.choices or {}) do
    local ok = canUseChoice(runState, choice)

    if ok then
      table.insert(choices, serializeChoice(choice))
    end
  end

  return choices
end

local function chooseEncounterDefinition(runState)
  local definitions = Encounters.getAll()

  if #definitions == 0 then
    return nil
  end

  local index = ((runState.seed + runState.roundIndex - 2) % #definitions) + 1
  return definitions[index]
end

function EncounterSystem.serializeChoice(choice)
  return serializeChoice(choice)
end

local function applyChoiceToRun(runState, choice)
  if choice.type == "shop_points" then
    runState.shopPoints = runState.shopPoints + (choice.amount or 0)
    return true, serializeChoice(choice)
  end

  if choice.type == "shop_rerolls" then
    runState.shopRerollsRemaining = math.max(0, (runState.shopRerollsRemaining or 0) + (choice.amount or 0))
    return true, serializeChoice(choice)
  end

  if choice.type == "coin" then
    return AcquisitionSystem.grantCoin(runState, choice.contentId)
  end

  if choice.type == "upgrade" then
    return AcquisitionSystem.grantUpgrade(runState, choice.contentId)
  end

  return false, "invalid_encounter_choice_type"
end

function EncounterSystem.buildSession(runState)
  local definition = chooseEncounterDefinition(runState)

  if not definition then
    return {
      encounterId = nil,
      name = "Quiet Hallway",
      description = "No encounter is active for this stop.",
      choices = {},
      selectedIndex = nil,
      choice = nil,
      claimed = false,
    }
  end

  local choices = buildEligibleChoices(runState, definition)

  return {
    encounterId = definition.id,
    name = definition.name,
    description = definition.description,
    choices = choices,
    selectedIndex = nil,
    choice = nil,
    claimed = false,
  }
end

function EncounterSystem.selectChoice(session, index)
  if type(session) ~= "table" then
    return false, "encounter_session_missing"
  end

  if session.claimed == true then
    return false, "encounter_choice_already_claimed"
  end

  if type(index) ~= "number" then
    return false, "encounter_choice_index_invalid"
  end

  index = math.floor(index)
  if index < 1 or index > #(session.choices or {}) then
    return false, "encounter_choice_index_invalid"
  end

  session.selectedIndex = index
  return true, session.choices[index]
end

function EncounterSystem.canContinue(session)
  if type(session) ~= "table" then
    return false
  end

  return session.claimed == true or #(session.choices or {}) == 0 or session.selectedIndex ~= nil
end

function EncounterSystem.claimChoice(runState, session)
  if type(session) ~= "table" then
    return false, "encounter_session_missing"
  end

  if session.claimed == true then
    return true, serializeChoice(session.choice)
  end

  if #(session.choices or {}) == 0 then
    session.claimed = true
    session.choice = nil
    return true, nil
  end

  local choice = session.selectedIndex and session.choices[session.selectedIndex] or nil
  if not choice then
    return false, "encounter_choice_not_selected"
  end

  local ok, result = applyChoiceToRun(runState, choice)

  if not ok then
    return false, result
  end

  session.claimed = true
  session.choice = serializeChoice(choice)
  return true, serializeChoice(choice)
end

function EncounterSystem.buildProjectedOutcome(runState, session)
  if type(session) ~= "table" then
    return nil, "encounter_session_missing"
  end

  local projectedRunState = Utils.clone(runState)
  local choice = session.choice or (session.selectedIndex and session.choices and session.choices[session.selectedIndex]) or nil

  if choice and session.claimed ~= true then
    local ok, errorMessage = applyChoiceToRun(projectedRunState, choice)

    if not ok then
      return nil, errorMessage
    end
  end

  return {
    choice = serializeChoice(choice),
    claimed = session.claimed == true,
    projectedRunState = projectedRunState,
    shopPointsBefore = runState and runState.shopPoints or 0,
    shopPointsAfter = projectedRunState and projectedRunState.shopPoints or 0,
    shopRerollsBefore = runState and runState.shopRerollsRemaining or 0,
    shopRerollsAfter = projectedRunState and projectedRunState.shopRerollsRemaining or 0,
    collectionSizeBefore = #(runState and runState.collectionCoinIds or {}),
    collectionSizeAfter = #(projectedRunState and projectedRunState.collectionCoinIds or {}),
    upgradeCountBefore = #(runState and runState.ownedUpgradeIds or {}),
    upgradeCountAfter = #(projectedRunState and projectedRunState.ownedUpgradeIds or {}),
  }
end

return EncounterSystem
