local AcquisitionSystem = require("src.systems.acquisition_system")
local Coins = require("src.content.coins")
local Encounters = require("src.content.encounters")
local RNG = require("src.core.rng")
local TrickBoardSystem = require("src.systems.trick_board_system")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local EncounterSystem = {}

local function isTrickType(choiceType)
  return choiceType == "trick" or choiceType == "upgrade"
end

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
    replacedTrickPosition = choice.replacedTrickPosition,
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

  if isTrickType(choice.type) then
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

local function chooseEncounterDefinition(runState, definitions)
  definitions = definitions or Encounters.getAll()

  if #definitions == 0 then
    return nil
  end

  local previousEncounterFamily = nil
  local seenEncounterFamilies = {}
  local stageResults = runState and runState.history and runState.history.stageResults or nil
  local lastStageRecord = stageResults and stageResults[#stageResults] or nil

  for _, stageRecord in ipairs(stageResults or {}) do
    if stageRecord.encounter and stageRecord.encounter.id then
      local previousDefinition = Encounters.getById(stageRecord.encounter.id)
      local familyId = previousDefinition and (previousDefinition.familyId or previousDefinition.id) or stageRecord.encounter.id
      seenEncounterFamilies[familyId] = true
      previousEncounterFamily = familyId
    end
  end

  if previousEncounterFamily and #definitions > 1 then
    local unseen = {}

    for _, definition in ipairs(definitions) do
      if not seenEncounterFamilies[definition.familyId or definition.id] then
        table.insert(unseen, definition)
      end
    end

    if #unseen > 0 then
      definitions = unseen
    end
  end

  if previousEncounterFamily and #definitions > 1 then
    local filtered = {}

    for _, definition in ipairs(definitions) do
      if (definition.familyId or definition.id) ~= previousEncounterFamily then
        table.insert(filtered, definition)
      end
    end

    if #filtered > 0 then
      definitions = filtered
    end
  end

  table.sort(definitions, function(left, right)
    return (left.id or "") < (right.id or "")
  end)

  local seed = tostring(runState and runState.seed or 1)
  local roundIndex = tostring(runState and runState.roundIndex or 1)
  local decisionKey = table.concat({ seed, "encounter", roundIndex }, ":")
  return RNG.newFromText(decisionKey):choose(definitions)
end

function EncounterSystem.serializeChoice(choice)
  return serializeChoice(choice)
end

local function applyChoiceToRun(runState, choice, options)
  if choice.type == "shop_points" then
    runState.influence = runState.influence + (choice.amount or 0)
    return true, serializeChoice(choice)
  end

  if choice.type == "shop_rerolls" then
    runState.shopRerollsRemaining = math.max(0, (runState.shopRerollsRemaining or 0) + (choice.amount or 0))
    return true, serializeChoice(choice)
  end

  if choice.type == "coin" then
    return AcquisitionSystem.grantCoin(runState, choice.contentId)
  end

  if isTrickType(choice.type) then
    return AcquisitionSystem.grantTrick(runState, choice.contentId, nil, {
      replacePosition = options and options.replacePosition,
    })
  end

  return false, "invalid_encounter_choice_type"
end

function EncounterSystem.buildSession(runState)
  local eligibleDefinitions = {}

  for _, definition in ipairs(Encounters.getAll()) do
    if #buildEligibleChoices(runState, definition) > 0 then
      table.insert(eligibleDefinitions, definition)
    end
  end

  local definition = chooseEncounterDefinition(runState, eligibleDefinitions)

  if not definition then
    return {
      encounterId = "quiet_hallway",
      name = "Quiet Hallway",
      description = "No encounter is active for this stop.",
      choices = {},
      selectedIndex = nil,
      choice = nil,
      claimed = false,
      replacementRequired = false,
      replacePosition = nil,
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
    replacementRequired = false,
    replacePosition = nil,
  }
end

function EncounterSystem.selectChoice(session, index, runState)
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
  session.replacementRequired = false
  session.replacePosition = nil
  local choice = session.choices[index]
  if runState and choice and isTrickType(choice.type) then
    local canAcquire, result = TrickBoardSystem.canAcquire(runState, choice.contentId)
    if not canAcquire and type(result) == "table" and result.code == "trick_board_full" then
      session.replacementRequired = true
      session.replacementMetadata = result
    end
  end
  return true, choice
end

function EncounterSystem.selectReplacementPosition(session, position, activeCount)
  if type(session) ~= "table" or session.replacementRequired ~= true then
    return false, "encounter_replacement_not_required"
  end
  position = tonumber(position)
  if not position or math.floor(position) ~= position or position < 1 or position > (tonumber(activeCount) or 0) then
    return false, "encounter_replacement_position_invalid"
  end
  session.replacePosition = position
  return true, position
end

function EncounterSystem.canContinue(session)
  if type(session) ~= "table" then
    return false
  end

  return session.claimed == true
    or #(session.choices or {}) == 0
    or (session.selectedIndex ~= nil
      and (session.replacementRequired ~= true or session.replacePosition ~= nil))
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

  local ok, result = applyChoiceToRun(runState, choice, {
    replacePosition = session.replacePosition,
  })

  if not ok then
    return false, result
  end

  session.claimed = true
  session.choice = serializeChoice(choice)
  session.choice.replacedTrickPosition = session.replacePosition
  return true, serializeChoice(session.choice)
end

function EncounterSystem.buildProjectedOutcome(runState, session)
  if type(session) ~= "table" then
    return nil, "encounter_session_missing"
  end

  local projectedRunState = Utils.clone(runState)
  local choice = session.choice or (session.selectedIndex and session.choices and session.choices[session.selectedIndex]) or nil

  if choice and session.claimed ~= true then
    local ok, errorMessage = applyChoiceToRun(projectedRunState, choice, {
      replacePosition = session.replacePosition,
    })

    if not ok then
      return nil, errorMessage
    end
  end

  return {
    choice = serializeChoice(choice),
    claimed = session.claimed == true,
    projectedRunState = projectedRunState,
    influenceBefore = runState and runState.influence or 0,
    influenceAfter = projectedRunState and projectedRunState.influence or 0,
    shopPointsBefore = runState and runState.influence or 0,
    shopPointsAfter = projectedRunState and projectedRunState.influence or 0,
    shopRerollsBefore = runState and runState.shopRerollsRemaining or 0,
    shopRerollsAfter = projectedRunState and projectedRunState.shopRerollsRemaining or 0,
    collectionSizeBefore = #(runState and runState.collectionCoinIds or {}),
    collectionSizeAfter = #(projectedRunState and projectedRunState.collectionCoinIds or {}),
    upgradeCountBefore = #(runState and (runState.ownedTrickIds or runState.ownedUpgradeIds) or {}),
    upgradeCountAfter = #(projectedRunState and (projectedRunState.ownedTrickIds or projectedRunState.ownedUpgradeIds) or {}),
  }
end

return EncounterSystem
