local ActionQueue = require("src.core.action_queue")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local Loadout = require("src.domain.loadout")
local PurseSystem = require("src.systems.purse_system")
local Utils = require("src.core.utils")

local Validator = {}

local VALID_RUN_STATUSES = {
  active = true,
  won = true,
  lost = true,
}

local VALID_STAGE_STATUSES = {
  active = true,
  cleared = true,
  failed = true,
}

local VALID_STAGE_TYPES = {
  normal = true,
  boss = true,
}

local VALID_COIN_RESULTS = {
  heads = true,
  tails = true,
}

local VALID_META_STATE_KEYS = {
  metaPoints = true,
  lifetimeMetaPointsEarned = true,
  unlockedCoinIds = true,
  unlockedUpgradeIds = true,
  purchasedMetaUpgradeIds = true,
  runRecords = true,
  effectiveValues = true,
  modifiers = true,
  stats = true,
}

local VALID_META_STATS = {
  runsStarted = true,
  runsWon = true,
  bestRunScore = true,
  bossesDefeated = true,
}

local VALID_RUN_RECORD_KEYS = {
  resultType = true,
  seed = true,
  runStatus = true,
  finalRound = true,
  finalStageLabel = true,
  finalStageStatus = true,
  finalStageVariant = true,
  runTotalScore = true,
  metaRewardEarned = true,
  shopVisitCount = true,
  totalRerollsUsed = true,
  collectionSize = true,
  upgradeCount = true,
  loadoutKey = true,
  stageHistory = true,
  shopHistory = true,
  purchaseHistory = true,
}

local VALID_RUN_RECORD_STAGE_KEYS = {
  roundIndex = true,
  stageLabel = true,
  stageType = true,
  variantName = true,
  status = true,
  stageScore = true,
  targetScore = true,
  loadoutKey = true,
  rewardChoice = true,
  rewardOptionsCount = true,
  encounterChoice = true,
  encounterOptionsCount = true,
}

local VALID_RUN_RECORD_PURCHASE_KEYS = {
  type = true,
  contentId = true,
  price = true,
}

local VALID_RUN_RECORD_SHOP_KEYS = {
  roundIndex = true,
  sourceStageId = true,
  sourceStageLabel = true,
  rerollsUsed = true,
  offersSeen = true,
  purchases = true,
}

local VALID_RUN_RECORD_ENCOUNTER_CHOICE_KEYS = {
  id = true,
  type = true,
  amount = true,
  contentId = true,
  label = true,
  description = true,
  name = true,
}

local VALID_SAVE_ARTIFACT_KEYS = {
  artifactType = true,
  version = true,
  metaState = true,
}

local VALID_ACTIVE_RUN_ARTIFACT_KEYS = {
  artifactType = true,
  version = true,
  currentState = true,
  runState = true,
  stageState = true,
  runRngSeed = true,
  selectedCall = true,
  lastBatchResult = true,
  lastStageResult = true,
  postResultNextState = true,
  rewardPreviewSession = true,
  encounterSession = true,
  shopOffers = true,
  shopSession = true,
  lastShopGenerationTrace = true,
  lastShopPurchaseTrace = true,
  currentStageDefinitionId = true,
  screenState = true,
}

local VALID_ACTIVE_RUN_STATES = {
  loadout = true,
  boss_warning = true,
  stage = true,
  result = true,
  post_stage_analytics = true,
  reward_preview = true,
  boss_reward = true,
  encounter = true,
  shop = true,
}

local VALID_POST_RESULT_NEXT_STATES = {
  post_stage_analytics = true,
  reward_preview = true,
  boss_reward = true,
  shop = true,
  summary = true,
}

local VALID_REPLAY_TRANSCRIPT_KEYS = {
  artifactType = true,
  version = true,
  bootstrap = true,
  stages = true,
  expected = true,
}

local VALID_REPLAY_BOOTSTRAP_KEYS = {
  seed = true,
  starterCollection = true,
  starterPurse = true,
  equippedCoinSlots = true,
  persistedLoadoutSlots = true,
  ownedUpgradeIds = true,
  metaState = true,
  startingCollectionSize = true,
  resolvedValues = true,
}

local VALID_REPLAY_STAGE_KEYS = {
  roundIndex = true,
  stageId = true,
  stageType = true,
  variantId = true,
  variantName = true,
  loadout = true,
  batches = true,
  reward = true,
  encounter = true,
  shop = true,
}

local VALID_REPLAY_REWARD_KEYS = {
  options = true,
  choice = true,
}

local VALID_REPLAY_REWARD_OPTION_KEYS = {
  type = true,
  contentId = true,
  name = true,
  rarity = true,
  description = true,
}

local VALID_REPLAY_ENCOUNTER_KEYS = {
  id = true,
  name = true,
  description = true,
  choices = true,
  choice = true,
}

local VALID_REPLAY_ENCOUNTER_CHOICE_KEYS = {
  id = true,
  type = true,
  amount = true,
  contentId = true,
  label = true,
  description = true,
}

local VALID_REPLAY_LOADOUT_KEYS = {
  slots = true,
  canonicalKey = true,
}

local VALID_REPLAY_BATCH_KEYS = {
  batchId = true,
  roundIndex = true,
  stageId = true,
  call = true,
  resolutionEntries = true,
  forcedResults = true,
}

local VALID_REPLAY_RESOLUTION_ENTRY_KEYS = {
  coinId = true,
  instanceId = true,
  originalDrawIndex = true,
  slotIndex = true,
  resolutionIndex = true,
  sleightUsed = true,
}

local VALID_REPLAY_FORCED_RESULT_KEYS = {
  result = true,
  coinId = true,
  instanceId = true,
  slotIndex = true,
  resolutionIndex = true,
  rngRoll = true,
}

local VALID_REPLAY_SHOP_KEYS = {
  roundIndex = true,
  sourceStageId = true,
  actions = true,
  offerSets = true,
  generationTraces = true,
  purchaseTraces = true,
}

local VALID_REPLAY_SHOP_ACTION_KEYS = {
  type = true,
  mode = true,
  outcome = true,
  offerType = true,
  contentId = true,
  finalPrice = true,
  reason = true,
}

local function isInteger(value)
  return type(value) == "number" and math.floor(value) == value
end

local function isPositiveInteger(value)
  return isInteger(value) and value > 0
end

local function isNonNegativeInteger(value)
  return isInteger(value) and value >= 0
end

local function validateIdList(values, label, resolver)
  local seen = {}

  for index, value in ipairs(values or {}) do
    if type(value) ~= "string" or value == "" then
      return false, string.format("%s contains invalid id at index %d", label, index)
    end

    if seen[value] then
      return false, string.format("%s contains duplicate id %s", label, value)
    end

    if resolver and not resolver(value) then
      return false, string.format("%s references unknown id %s", label, value)
    end

    seen[value] = true
  end

  return true, seen
end

local function validateIdArray(values, label, resolver)
  for index, value in ipairs(values or {}) do
    if type(value) ~= "string" or value == "" then
      return false, string.format("%s contains invalid id at index %d", label, index)
    end

    if resolver and not resolver(value) then
      return false, string.format("%s references unknown id %s", label, value)
    end
  end

  return true
end

local function valuesDeepEqual(left, right)
  if type(left) ~= type(right) then
    return false
  end

  if type(left) ~= "table" then
    return left == right
  end

  local seen = {}

  for key, leftValue in pairs(left) do
    if not valuesDeepEqual(leftValue, right[key]) then
      return false
    end

    seen[key] = true
  end

  for key in pairs(right) do
    if not seen[key] then
      return false
    end
  end

  return true
end

local function getMaxNumericIndex(values)
  local maxIndex = 0

  for key in pairs(values or {}) do
    if type(key) == "number" and key > maxIndex then
      maxIndex = key
    end
  end

  return maxIndex
end

local function validateSlotState(slots, maxActiveCoinSlots, collectionIndex, label, requireAtLeastOne)
  if type(slots) ~= "table" then
    return false, string.format("%s must be a table", label)
  end

  local normalized = Loadout.normalizeSlots(slots, maxActiveCoinSlots)
  local hasDuplicate, duplicateId = Loadout.containsDuplicateIds(normalized, maxActiveCoinSlots)

  if hasDuplicate then
    return false, string.format("%s contains duplicate coin %s", label, duplicateId)
  end

  if requireAtLeastOne and Loadout.countEquipped(normalized, maxActiveCoinSlots) == 0 then
    return false, string.format("%s must equip at least one coin", label)
  end

  for slotIndex = 1, maxActiveCoinSlots do
    local coinId = normalized[slotIndex]

    if coinId ~= nil then
      if type(coinId) ~= "string" or coinId == "" then
        return false, string.format("%s has invalid coin id in slot %d", label, slotIndex)
      end

      if collectionIndex and not collectionIndex[coinId] then
        return false, string.format("%s uses unowned coin %s", label, coinId)
      end
    end
  end

  return true, normalized
end

local function validateBatchSnapshot(batch)
  if type(batch) ~= "table" then
    return false, "batch snapshot must be a table"
  end

  if not isPositiveInteger(batch.batchId) then
    return false, "batch snapshot requires positive integer batchId"
  end

  if batch.call ~= "heads" and batch.call ~= "tails" then
    return false, "batch snapshot requires call=heads|tails"
  end

  if not isPositiveInteger(batch.roundIndex) then
    return false, "batch snapshot requires positive integer roundIndex"
  end

  if type(batch.stageId) ~= "string" or batch.stageId == "" then
    return false, "batch snapshot requires stageId"
  end

  if batch.stageType ~= nil and not VALID_STAGE_TYPES[batch.stageType] then
    return false, string.format("batch snapshot has invalid stageType %s", tostring(batch.stageType))
  end

  local equippedSlotCount = getMaxNumericIndex(batch.equippedCoinSlots)
  local maxSlots = math.max(
    equippedSlotCount,
    #(batch.resolutionCoinIds or {}),
    #(batch.resolvedCoinResults or {})
  )
  local ok, normalizedSlots = validateSlotState(batch.equippedCoinSlots or {}, maxSlots, nil, "batch equippedCoinSlots", equippedSlotCount > 0)

  if not ok then
    return false, normalizedSlots
  end

  local compactSlots = equippedSlotCount > 0 and Loadout.compactSlots(normalizedSlots, maxSlots) or Utils.copyArray(batch.resolutionCoinIds or {})
  local resolutionOrder = batch.resolutionCoinIds or {}
  local resolutionEntries = batch.resolutionEntries or {}

  if #resolutionOrder ~= #compactSlots then
    return false, string.format("batch snapshot resolved %d coin(s) for %d equipped coin(s)", #resolutionOrder, #compactSlots)
  end

  local compactIndex = {}
  for _, coinId in ipairs(compactSlots) do
    compactIndex[coinId] = true
  end

  local resolutionIndex = {}
  local resolvedByCoinId = {}
  local resolvedByInstanceId = {}
  for index, coinId in ipairs(resolutionOrder) do
    if type(coinId) ~= "string" or coinId == "" then
      return false, string.format("batch resolution order has invalid coin at index %d", index)
    end

    if equippedSlotCount > 0 and resolutionIndex[coinId] then
      return false, string.format("batch resolution order contains duplicate coin %s", coinId)
    end

    if equippedSlotCount > 0 and not compactIndex[coinId] then
      return false, string.format("batch resolution order contains unequipped coin %s", coinId)
    end

    resolutionIndex[coinId] = true
  end

  local function getResolvedCoin(entry)
    if entry and entry.instanceId ~= nil then
      return resolvedByInstanceId[entry.instanceId]
    end

    return entry and resolvedByCoinId[entry.coinId]
  end

  if #resolutionEntries > 0 and #resolutionEntries ~= #resolutionOrder then
    return false, string.format("batch resolutionEntries count %d does not match resolution order %d", #resolutionEntries, #resolutionOrder)
  end

  for index, entry in ipairs(resolutionEntries) do
    if type(entry) ~= "table" then
      return false, string.format("batch resolutionEntries[%d] must be a table", index)
    end

    if entry.coinId ~= resolutionOrder[index] then
      return false, string.format("batch resolutionEntries[%d].coinId mismatch", index)
    end

    if not isPositiveInteger(entry.slotIndex) then
      return false, string.format("batch resolutionEntries[%d].slotIndex must be a positive integer", index)
    end

    if equippedSlotCount > 0 and normalizedSlots[entry.slotIndex] ~= entry.coinId then
      return false, string.format("batch resolutionEntries[%d] slotIndex does not match equipped slots", index)
    end

    if entry.resolutionIndex ~= index then
      return false, string.format("batch resolutionEntries[%d].resolutionIndex mismatch", index)
    end
  end

  if #(batch.resolvedCoinResults or {}) ~= #resolutionOrder then
    return false, string.format("batch resolvedCoinResults count %d does not match resolution order %d", #(batch.resolvedCoinResults or {}), #resolutionOrder)
  end

  for index, coinState in ipairs(batch.resolvedCoinResults or {}) do
    if coinState.coinId ~= resolutionOrder[index] then
      return false, string.format("batch resolvedCoinResults[%d] coinId mismatch", index)
    end

    resolvedByCoinId[coinState.coinId] = coinState

    if coinState.instanceId ~= nil then
      resolvedByInstanceId[coinState.instanceId] = coinState
    end

    if #resolutionEntries > 0 then
      local expectedEntry = resolutionEntries[index]

      if coinState.slotIndex ~= expectedEntry.slotIndex then
        return false, string.format("batch resolvedCoinResults[%d] slotIndex mismatch", index)
      end

      if coinState.resolutionIndex ~= expectedEntry.resolutionIndex then
        return false, string.format("batch resolvedCoinResults[%d] resolutionIndex mismatch", index)
      end
    end

    if not VALID_COIN_RESULTS[coinState.result] then
      return false, string.format("batch resolvedCoinResults[%d] has invalid result %s", index, tostring(coinState.result))
    end
  end

  for index, forcedEntry in ipairs(batch.forcedResults or (batch.trace and batch.trace.forcedResults) or {}) do
    if type(forcedEntry) ~= "table" then
      return false, string.format("batch forcedResults[%d] must be a table", index)
    end

    if not VALID_COIN_RESULTS[forcedEntry.result] then
      return false, string.format("batch forcedResults[%d] has invalid result %s", index, tostring(forcedEntry.result))
    end

    local resolvedCoin = getResolvedCoin(forcedEntry)

    if not resolvedCoin then
      return false, string.format("batch forcedResults[%d] references unknown coin %s", index, tostring(forcedEntry.coinId))
    end

    if not isPositiveInteger(forcedEntry.slotIndex) or forcedEntry.slotIndex ~= resolvedCoin.slotIndex then
      return false, string.format("batch forcedResults[%d].slotIndex mismatch", index)
    end

    if not isPositiveInteger(forcedEntry.resolutionIndex) or forcedEntry.resolutionIndex ~= resolvedCoin.resolutionIndex then
      return false, string.format("batch forcedResults[%d].resolutionIndex mismatch", index)
    end
  end

  if batch.trace then
    if batch.trace.batchId ~= nil and batch.trace.batchId ~= batch.batchId then
      return false, "batch trace batchId mismatch"
    end

    if batch.trace.call ~= nil and batch.trace.call ~= batch.call then
      return false, "batch trace call mismatch"
    end

    if #(batch.trace.forcedResults or {}) ~= #(batch.forcedResults or {}) then
      return false, "batch trace forcedResults count mismatch"
    end

    for index, coinRoll in ipairs(batch.trace.coinRolls or {}) do
      local resolvedCoin = batch.resolvedCoinResults[index]

      if resolvedCoin then
        if coinRoll.coinId ~= resolvedCoin.coinId then
          return false, string.format("batch trace coinRolls[%d].coinId mismatch", index)
        end

        if coinRoll.instanceId ~= nil and coinRoll.instanceId ~= resolvedCoin.instanceId then
          return false, string.format("batch trace coinRolls[%d].instanceId mismatch", index)
        end

        if coinRoll.slotIndex ~= resolvedCoin.slotIndex then
          return false, string.format("batch trace coinRolls[%d].slotIndex mismatch", index)
        end

        if coinRoll.resolutionIndex ~= resolvedCoin.resolutionIndex then
          return false, string.format("batch trace coinRolls[%d].resolutionIndex mismatch", index)
        end
      end
    end

    for index, source in ipairs(batch.trace.triggeredSources or {}) do
      if source.coinId ~= nil then
        local resolvedCoin = getResolvedCoin(source)

        if not resolvedCoin then
          return false, string.format("batch trace triggeredSources[%d] references unknown resolved coin %s", index, tostring(source.coinId))
        end

        if not isPositiveInteger(source.slotIndex) then
          return false, string.format("batch trace triggeredSources[%d].slotIndex must be positive integer", index)
        end

        if not isPositiveInteger(source.resolutionIndex) then
          return false, string.format("batch trace triggeredSources[%d].resolutionIndex must be positive integer", index)
        end

        if source.slotIndex ~= resolvedCoin.slotIndex then
          return false, string.format("batch trace triggeredSources[%d].slotIndex mismatch", index)
        end

        if source.resolutionIndex ~= resolvedCoin.resolutionIndex then
          return false, string.format("batch trace triggeredSources[%d].resolutionIndex mismatch", index)
        end
      end
    end

    for index, action in ipairs(batch.trace.actions or {}) do
      if action.coinId ~= nil and (action.slotIndex ~= nil or action.resolutionIndex ~= nil) then
        local resolvedCoin = getResolvedCoin(action)

        if not resolvedCoin then
          return false, string.format("batch trace actions[%d] references unknown coin %s", index, tostring(action.coinId))
        end

        if not isPositiveInteger(action.slotIndex) then
          return false, string.format("batch trace actions[%d].slotIndex must be positive integer", index)
        end

        if not isPositiveInteger(action.resolutionIndex) then
          return false, string.format("batch trace actions[%d].resolutionIndex must be positive integer", index)
        end

        if action.slotIndex ~= resolvedCoin.slotIndex then
          return false, string.format("batch trace actions[%d].slotIndex mismatch", index)
        end

        if action.resolutionIndex ~= resolvedCoin.resolutionIndex then
          return false, string.format("batch trace actions[%d].resolutionIndex mismatch", index)
        end
      end

      if type(action._trace) == "table" and action._trace.coinId ~= nil then
        local resolvedCoin = getResolvedCoin(action._trace)

        if not resolvedCoin then
          return false, string.format("batch trace actions[%d]._trace references unknown coin %s", index, tostring(action._trace.coinId))
        end

        if not isPositiveInteger(action._trace.slotIndex) then
          return false, string.format("batch trace actions[%d]._trace.slotIndex must be positive integer", index)
        end

        if not isPositiveInteger(action._trace.resolutionIndex) then
          return false, string.format("batch trace actions[%d]._trace.resolutionIndex must be positive integer", index)
        end

        if action._trace.slotIndex ~= resolvedCoin.slotIndex then
          return false, string.format("batch trace actions[%d]._trace.slotIndex mismatch", index)
        end

        if action._trace.resolutionIndex ~= resolvedCoin.resolutionIndex then
          return false, string.format("batch trace actions[%d]._trace.resolutionIndex mismatch", index)
        end
      end
    end

    for index, forcedEntry in ipairs(batch.trace.forcedResults or {}) do
      local batchForcedEntry = (batch.forcedResults or {})[index]

      if not batchForcedEntry then
        return false, string.format("batch trace forcedResults[%d] missing batch forced result", index)
      end

      if forcedEntry.coinId ~= batchForcedEntry.coinId or forcedEntry.result ~= batchForcedEntry.result then
        return false, string.format("batch trace forcedResults[%d] mismatch", index)
      end

      if forcedEntry.slotIndex ~= batchForcedEntry.slotIndex or forcedEntry.resolutionIndex ~= batchForcedEntry.resolutionIndex then
        return false, string.format("batch trace forcedResults[%d] slot/resolution mismatch", index)
      end
    end
  end

  return true
end

local function validateRewardOption(option, label)
  local Coins = require("src.content.coins")
  local Upgrades = require("src.content.upgrades")

  if type(option) ~= "table" then
    return false, string.format("%s must be a table", label)
  end

  if option.type ~= "coin" and option.type ~= "upgrade" then
    return false, string.format("%s type must be coin|upgrade", label)
  end

  if type(option.contentId) ~= "string" or option.contentId == "" then
    return false, string.format("%s contentId is required", label)
  end

  local definition = option.type == "coin" and Coins.getById(option.contentId) or Upgrades.getById(option.contentId)
  if not definition then
    return false, string.format("%s references unknown %s %s", label, option.type, option.contentId)
  end

  return true
end

local function validateEncounterChoice(choice, label)
  local Coins = require("src.content.coins")
  local Upgrades = require("src.content.upgrades")

  if type(choice) ~= "table" then
    return false, string.format("%s must be a table", label)
  end

  for key in pairs(choice) do
    if not VALID_REPLAY_ENCOUNTER_CHOICE_KEYS[key] then
      return false, string.format("%s has unknown field %s", label, tostring(key))
    end
  end

  if type(choice.id) ~= "string" or choice.id == "" then
    return false, string.format("%s id must be a non-empty string", label)
  end

  if choice.type ~= "shop_points" and choice.type ~= "shop_rerolls" and choice.type ~= "coin" and choice.type ~= "upgrade" then
    return false, string.format("%s type must be shop_points, shop_rerolls, coin, or upgrade", label)
  end

  if choice.type == "shop_points" or choice.type == "shop_rerolls" then
    if type(choice.amount) ~= "number" then
      return false, string.format("%s amount must be numeric", label)
    end
  else
    if type(choice.contentId) ~= "string" or choice.contentId == "" then
      return false, string.format("%s contentId must be a non-empty string", label)
    end

    local lookup = choice.type == "coin" and Coins.getById or Upgrades.getById
    if not lookup(choice.contentId) then
      return false, string.format("%s references unknown %s %s", label, choice.type, tostring(choice.contentId))
    end
  end

  if type(choice.label) ~= "string" or choice.label == "" then
    return false, string.format("%s label must be a non-empty string", label)
  end

  if type(choice.description) ~= "string" or choice.description == "" then
    return false, string.format("%s description must be a non-empty string", label)
  end

  return true
end

local function validateEncounterSession(session, label)
  if type(session) ~= "table" then
    return false, string.format("%s must be a table", label)
  end

  if type(session.encounterId) ~= "string" or session.encounterId == "" then
    return false, string.format("%s encounterId must be a non-empty string", label)
  end

  if type(session.name) ~= "string" or session.name == "" then
    return false, string.format("%s name must be a non-empty string", label)
  end

  if type(session.description) ~= "string" or session.description == "" then
    return false, string.format("%s description must be a non-empty string", label)
  end

  if type(session.choices or {}) ~= "table" then
    return false, string.format("%s choices must be a table", label)
  end

  local seenChoiceIds = {}
  for index, choice in ipairs(session.choices or {}) do
    local ok, errorMessage = validateEncounterChoice(choice, string.format("%s choice %d", label, index))
    if not ok then
      return false, errorMessage
    end

    if seenChoiceIds[choice.id] then
      return false, string.format("%s choices contain duplicate id %s", label, tostring(choice.id))
    end

    seenChoiceIds[choice.id] = true
  end

  if session.selectedIndex ~= nil then
    if not isPositiveInteger(session.selectedIndex) then
      return false, string.format("%s selectedIndex must be a positive integer", label)
    end

    if session.choices[session.selectedIndex] == nil then
      return false, string.format("%s selectedIndex is out of range", label)
    end
  end

  if session.choice ~= nil then
    local ok, errorMessage = validateEncounterChoice(session.choice, label .. " choice")
    if not ok then
      return false, errorMessage
    end

    local found = false
    for _, choice in ipairs(session.choices or {}) do
      if choice.id == session.choice.id then
        found = true
        break
      end
    end

    if not found then
      return false, string.format("%s choice %s is not present in choices", label, tostring(session.choice.id))
    end
  end

  if type(session.claimed) ~= "boolean" then
    return false, string.format("%s claimed must be boolean", label)
  end

  if session.claimed and #(session.choices or {}) > 0 and session.choice == nil then
    return false, string.format("%s claimed session is missing a chosen option", label)
  end

  return true
end

function Validator.validateEncounterRegistry(definitions)
  local seenEncounterIds = {}

  for _, definition in ipairs(definitions or {}) do
    local ok, errorMessage = Validator.validateContentDefinition(definition)
    if not ok then
      return false, string.format("encounters registry error: %s", errorMessage)
    end

    if seenEncounterIds[definition.id] then
      return false, string.format("encounters registry has duplicate id %s", tostring(definition.id))
    end

    seenEncounterIds[definition.id] = true

    if type(definition.description) ~= "string" or definition.description == "" then
      return false, string.format("encounters registry error: %s is missing description", tostring(definition.id))
    end

    if type(definition.choices) ~= "table" then
      return false, string.format("encounters registry error: %s choices must be a table", tostring(definition.id))
    end

    local seenChoiceIds = {}
    for index, choice in ipairs(definition.choices or {}) do
      ok, errorMessage = validateEncounterChoice(choice, string.format("encounter %s choice %d", tostring(definition.id), index))
      if not ok then
        return false, string.format("encounters registry error: %s", errorMessage)
      end

      if seenChoiceIds[choice.id] then
        return false, string.format("encounters registry error: %s has duplicate choice id %s", tostring(definition.id), tostring(choice.id))
      end

      seenChoiceIds[choice.id] = true
    end
  end

  return true
end

local function collectConditionFlagKeysFromActions(actionList, flagKeys)
  for _, action in ipairs(actionList or {}) do
    if (action.op == "set_batch_flag" or action.op == "set_shop_flag") and type(action.flag) == "string" and action.flag ~= "" then
      flagKeys[action.flag] = true
    elseif action.op == "queue_actions" then
      collectConditionFlagKeysFromActions(action.actions, flagKeys)
    elseif action.op == "grant_temporary_effect" and type(action.effect) == "table" then
      for _, trigger in ipairs(action.effect.triggers or {}) do
        collectConditionFlagKeysFromActions(trigger.effects, flagKeys)
      end
    end
  end
end

local function collectConditionFlagKeysFromDefinition(definition)
  local flagKeys = HookRegistry.getSystemConditionFlagKeys()

  for _, trigger in ipairs(definition.triggers or {}) do
    collectConditionFlagKeysFromActions(trigger.effects, flagKeys)
  end

  collectConditionFlagKeysFromActions(definition.onAcquire, flagKeys)

  return flagKeys
end

local function validateCustomResolver(definition)
  if definition.customResolver == nil then
    return true
  end

  if type(definition.customResolver) ~= "string" or definition.customResolver == "" then
    return false, string.format("definition %s customResolver must be non-empty string", definition.id)
  end

  local ok, resolverModule = pcall(require, definition.customResolver)

  if not ok then
    return false, string.format("definition %s customResolver %s could not be required", definition.id, definition.customResolver)
  end

  if type(resolverModule) ~= "table" or type(resolverModule.resolve) ~= "function" then
    return false, string.format("definition %s customResolver %s must export resolve", definition.id, definition.customResolver)
  end

  return true
end

local function validateRunRecord(record, index)
  if type(record) ~= "table" then
    return false, string.format("runRecords[%d] must be a table", index)
  end

  for key in pairs(record) do
    if not VALID_RUN_RECORD_KEYS[key] then
      return false, string.format("runRecords[%d] contains unknown field %s", index, tostring(key))
    end
  end

  if type(record.resultType) ~= "string" or record.resultType == "" then
    return false, string.format("runRecords[%d] resultType must be a non-empty string", index)
  end

  if record.seed ~= nil and not isPositiveInteger(record.seed) then
    return false, string.format("runRecords[%d] seed must be a positive integer when present", index)
  end

  if not VALID_RUN_STATUSES[record.runStatus] then
    return false, string.format("runRecords[%d] has invalid runStatus %s", index, tostring(record.runStatus))
  end

  if not isPositiveInteger(record.finalRound) then
    return false, string.format("runRecords[%d] finalRound must be a positive integer", index)
  end

  if type(record.finalStageLabel) ~= "string" or record.finalStageLabel == "" then
    return false, string.format("runRecords[%d] finalStageLabel must be a non-empty string", index)
  end

  if record.finalStageVariant ~= nil and (type(record.finalStageVariant) ~= "string" or record.finalStageVariant == "") then
    return false, string.format("runRecords[%d] finalStageVariant must be a non-empty string when present", index)
  end

  if not VALID_STAGE_STATUSES[record.finalStageStatus] then
    return false, string.format("runRecords[%d] has invalid finalStageStatus %s", index, tostring(record.finalStageStatus))
  end

  if type(record.runTotalScore) ~= "number" or record.runTotalScore < 0 then
    return false, string.format("runRecords[%d] runTotalScore must be a non-negative number", index)
  end

  if not isNonNegativeInteger(record.metaRewardEarned or 0) then
    return false, string.format("runRecords[%d] metaRewardEarned must be a non-negative integer", index)
  end

  if not isNonNegativeInteger(record.shopVisitCount or 0) then
    return false, string.format("runRecords[%d] shopVisitCount must be a non-negative integer", index)
  end

  if not isNonNegativeInteger(record.totalRerollsUsed or 0) then
    return false, string.format("runRecords[%d] totalRerollsUsed must be a non-negative integer", index)
  end

  if not isNonNegativeInteger(record.collectionSize or 0) then
    return false, string.format("runRecords[%d] collectionSize must be a non-negative integer", index)
  end

  if not isNonNegativeInteger(record.upgradeCount or 0) then
    return false, string.format("runRecords[%d] upgradeCount must be a non-negative integer", index)
  end

  if record.loadoutKey ~= nil and (type(record.loadoutKey) ~= "string" or record.loadoutKey == "") then
    return false, string.format("runRecords[%d] loadoutKey must be a non-empty string when present", index)
  end

  if type(record.stageHistory) ~= "table" then
    return false, string.format("runRecords[%d] stageHistory must be a table", index)
  end

  for stageIndex, stageRecord in ipairs(record.stageHistory) do
    if type(stageRecord) ~= "table" then
      return false, string.format("runRecords[%d].stageHistory[%d] must be a table", index, stageIndex)
    end

    for key in pairs(stageRecord) do
      if not VALID_RUN_RECORD_STAGE_KEYS[key] then
        return false, string.format("runRecords[%d].stageHistory[%d] contains unknown field %s", index, stageIndex, tostring(key))
      end
    end

    if not isPositiveInteger(stageRecord.roundIndex) then
      return false, string.format("runRecords[%d].stageHistory[%d] roundIndex must be a positive integer", index, stageIndex)
    end

    if type(stageRecord.stageLabel) ~= "string" or stageRecord.stageLabel == "" then
      return false, string.format("runRecords[%d].stageHistory[%d] stageLabel must be a non-empty string", index, stageIndex)
    end

    if not VALID_STAGE_TYPES[stageRecord.stageType] then
      return false, string.format("runRecords[%d].stageHistory[%d] has invalid stageType %s", index, stageIndex, tostring(stageRecord.stageType))
    end

    if stageRecord.variantName ~= nil and (type(stageRecord.variantName) ~= "string" or stageRecord.variantName == "") then
      return false, string.format("runRecords[%d].stageHistory[%d] variantName must be a non-empty string when present", index, stageIndex)
    end

    if not VALID_STAGE_STATUSES[stageRecord.status] then
      return false, string.format("runRecords[%d].stageHistory[%d] has invalid status %s", index, stageIndex, tostring(stageRecord.status))
    end

    if type(stageRecord.stageScore) ~= "number" or stageRecord.stageScore < 0 then
      return false, string.format("runRecords[%d].stageHistory[%d] stageScore must be a non-negative number", index, stageIndex)
    end

    if type(stageRecord.targetScore) ~= "number" or stageRecord.targetScore <= 0 then
      return false, string.format("runRecords[%d].stageHistory[%d] targetScore must be a positive number", index, stageIndex)
    end

    if stageRecord.loadoutKey ~= nil and (type(stageRecord.loadoutKey) ~= "string" or stageRecord.loadoutKey == "") then
      return false, string.format("runRecords[%d].stageHistory[%d] loadoutKey must be a non-empty string when present", index, stageIndex)
    end

    if stageRecord.rewardChoice then
      local ok, errorMessage = validateRewardOption(stageRecord.rewardChoice, string.format("runRecords[%d].stageHistory[%d].rewardChoice", index, stageIndex))
      if not ok then
        return false, errorMessage
      end
    end

    if not isNonNegativeInteger(stageRecord.rewardOptionsCount or 0) then
      return false, string.format("runRecords[%d].stageHistory[%d] rewardOptionsCount must be a non-negative integer", index, stageIndex)
    end

    if stageRecord.encounterChoice then
      if type(stageRecord.encounterChoice) ~= "table" then
        return false, string.format("runRecords[%d].stageHistory[%d].encounterChoice must be a table", index, stageIndex)
      end

      for key in pairs(stageRecord.encounterChoice) do
        if not VALID_RUN_RECORD_ENCOUNTER_CHOICE_KEYS[key] then
          return false, string.format("runRecords[%d].stageHistory[%d].encounterChoice contains unknown field %s", index, stageIndex, tostring(key))
        end
      end

      if type(stageRecord.encounterChoice.id) ~= "string" or stageRecord.encounterChoice.id == "" then
        return false, string.format("runRecords[%d].stageHistory[%d].encounterChoice id must be a non-empty string", index, stageIndex)
      end

      if stageRecord.encounterChoice.type ~= "shop_points" and stageRecord.encounterChoice.type ~= "shop_rerolls" and stageRecord.encounterChoice.type ~= "coin" and stageRecord.encounterChoice.type ~= "upgrade" then
        return false, string.format("runRecords[%d].stageHistory[%d].encounterChoice has invalid type %s", index, stageIndex, tostring(stageRecord.encounterChoice.type))
      end

      if type(stageRecord.encounterChoice.label) ~= "string" or stageRecord.encounterChoice.label == "" then
        return false, string.format("runRecords[%d].stageHistory[%d].encounterChoice label must be a non-empty string", index, stageIndex)
      end
    end

    if not isNonNegativeInteger(stageRecord.encounterOptionsCount or 0) then
      return false, string.format("runRecords[%d].stageHistory[%d] encounterOptionsCount must be a non-negative integer", index, stageIndex)
    end
  end

  if type(record.shopHistory or {}) ~= "table" then
    return false, string.format("runRecords[%d] shopHistory must be a table", index)
  end

  for shopIndex, shopRecord in ipairs(record.shopHistory or {}) do
    if type(shopRecord) ~= "table" then
      return false, string.format("runRecords[%d].shopHistory[%d] must be a table", index, shopIndex)
    end

    for key in pairs(shopRecord) do
      if not VALID_RUN_RECORD_SHOP_KEYS[key] then
        return false, string.format("runRecords[%d].shopHistory[%d] contains unknown field %s", index, shopIndex, tostring(key))
      end
    end

    if not isPositiveInteger(shopRecord.roundIndex) then
      return false, string.format("runRecords[%d].shopHistory[%d] roundIndex must be a positive integer", index, shopIndex)
    end

    if type(shopRecord.sourceStageId) ~= "string" or shopRecord.sourceStageId == "" then
      return false, string.format("runRecords[%d].shopHistory[%d] sourceStageId must be a non-empty string", index, shopIndex)
    end

    if shopRecord.sourceStageLabel ~= nil and (type(shopRecord.sourceStageLabel) ~= "string" or shopRecord.sourceStageLabel == "") then
      return false, string.format("runRecords[%d].shopHistory[%d] sourceStageLabel must be a non-empty string when present", index, shopIndex)
    end

    if not isNonNegativeInteger(shopRecord.rerollsUsed or 0) then
      return false, string.format("runRecords[%d].shopHistory[%d] rerollsUsed must be a non-negative integer", index, shopIndex)
    end

    if not isNonNegativeInteger(shopRecord.offersSeen or 0) then
      return false, string.format("runRecords[%d].shopHistory[%d] offersSeen must be a non-negative integer", index, shopIndex)
    end

    if type(shopRecord.purchases or {}) ~= "table" then
      return false, string.format("runRecords[%d].shopHistory[%d] purchases must be a table", index, shopIndex)
    end

    for purchaseIndex, purchase in ipairs(shopRecord.purchases or {}) do
      if type(purchase) ~= "table" then
        return false, string.format("runRecords[%d].shopHistory[%d].purchases[%d] must be a table", index, shopIndex, purchaseIndex)
      end

      for key in pairs(purchase) do
        if not VALID_RUN_RECORD_PURCHASE_KEYS[key] then
          return false, string.format("runRecords[%d].shopHistory[%d].purchases[%d] contains unknown field %s", index, shopIndex, purchaseIndex, tostring(key))
        end
      end
    end
  end

  if type(record.purchaseHistory) ~= "table" then
    return false, string.format("runRecords[%d] purchaseHistory must be a table", index)
  end

  for purchaseIndex, purchase in ipairs(record.purchaseHistory) do
    if type(purchase) ~= "table" then
      return false, string.format("runRecords[%d].purchaseHistory[%d] must be a table", index, purchaseIndex)
    end

    for key in pairs(purchase) do
      if not VALID_RUN_RECORD_PURCHASE_KEYS[key] then
        return false, string.format("runRecords[%d].purchaseHistory[%d] contains unknown field %s", index, purchaseIndex, tostring(key))
      end
    end

    if purchase.type ~= "coin" and purchase.type ~= "upgrade" then
      return false, string.format("runRecords[%d].purchaseHistory[%d] has invalid type %s", index, purchaseIndex, tostring(purchase.type))
    end

    if type(purchase.contentId) ~= "string" or purchase.contentId == "" then
      return false, string.format("runRecords[%d].purchaseHistory[%d] contentId must be a non-empty string", index, purchaseIndex)
    end

    if type(purchase.price) ~= "number" or purchase.price < 0 then
      return false, string.format("runRecords[%d].purchaseHistory[%d] price must be a non-negative number", index, purchaseIndex)
    end
  end

  return true
end

function Validator.validateMetaStatePayload(metaStateTable)
  local Coins = require("src.content.coins")
  local MetaUpgrades = require("src.content.meta_upgrades")
  local Upgrades = require("src.content.upgrades")

  if type(metaStateTable) ~= "table" then
    return false, "metaState payload must be a table"
  end

  for key in pairs(metaStateTable) do
    if not VALID_META_STATE_KEYS[key] then
      return false, string.format("metaState payload has unknown field %s", tostring(key))
    end
  end

  if metaStateTable.metaPoints ~= nil and not isNonNegativeInteger(metaStateTable.metaPoints) then
    return false, "metaState metaPoints must be a non-negative integer"
  end

  if metaStateTable.lifetimeMetaPointsEarned ~= nil and not isNonNegativeInteger(metaStateTable.lifetimeMetaPointsEarned) then
    return false, "metaState lifetimeMetaPointsEarned must be a non-negative integer"
  end

  local ok, errorMessage = validateIdList(metaStateTable.unlockedCoinIds or {}, "metaState unlockedCoinIds", Coins.getById)
  if not ok then
    return false, errorMessage
  end

  ok, errorMessage = validateIdList(metaStateTable.unlockedUpgradeIds or {}, "metaState unlockedUpgradeIds", Upgrades.getById)
  if not ok then
    return false, errorMessage
  end

  ok, errorMessage = validateIdList(metaStateTable.purchasedMetaUpgradeIds or {}, "metaState purchasedMetaUpgradeIds", MetaUpgrades.getById)
  if not ok then
    return false, errorMessage
  end

  local expectedPurchasedEffectiveValues = {}
  local expectedUnlockedCoinIds = {}
  local expectedUnlockedUpgradeIds = {}

  for _, metaUpgradeId in ipairs(metaStateTable.purchasedMetaUpgradeIds or {}) do
    local definition = MetaUpgrades.getById(metaUpgradeId)

    if definition then
      EffectiveValueSystem.mergeEffectiveValueTables(
        expectedPurchasedEffectiveValues,
        EffectiveValueSystem.getDefinitionEffectiveValues(definition)
      )
      Utils.appendAll(expectedUnlockedCoinIds, definition.unlockCoinIds or {})
      Utils.appendAll(expectedUnlockedUpgradeIds, definition.unlockUpgradeIds or {})
    end
  end

  ok, errorMessage = EffectiveValueSystem.validateEffectiveValuesTable(metaStateTable.effectiveValues)
  if not ok then
    return false, string.format("metaState effectiveValues invalid: %s", errorMessage)
  end

  ok, errorMessage = EffectiveValueSystem.validateLegacyModifierTable(metaStateTable.modifiers)
  if not ok then
    return false, string.format("metaState modifiers invalid: %s", errorMessage)
  end

  if metaStateTable.effectiveValues ~= nil and metaStateTable.modifiers ~= nil then
    local derivedModifiers = EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(metaStateTable.effectiveValues, {})

    for alias, aliasDefinition in pairs(EffectiveValueSystem.LEGACY_MODIFIER_ALIASES) do
      local expectedValue = derivedModifiers[alias]
      local actualValue = metaStateTable.modifiers[alias]

      if actualValue == nil then
        actualValue = aliasDefinition.mode == "multiply" and 1.0 or 0
      end

      if actualValue ~= expectedValue then
        return false, "metaState effectiveValues and modifiers conflict"
      end
    end
  end

  if metaStateTable.effectiveValues ~= nil then
    for key, expectedEntry in pairs(expectedPurchasedEffectiveValues) do
      if not valuesDeepEqual(metaStateTable.effectiveValues[key], expectedEntry) then
        return false, string.format("metaState effectiveValues missing purchased effect %s", tostring(key))
      end
    end
  end

  if metaStateTable.unlockedCoinIds ~= nil then
    local unlockedCoinIndex = {}

    for _, coinId in ipairs(metaStateTable.unlockedCoinIds or {}) do
      unlockedCoinIndex[coinId] = true
    end

    for _, coinId in ipairs(expectedUnlockedCoinIds) do
      if not unlockedCoinIndex[coinId] then
        return false, string.format("metaState unlockedCoinIds missing purchased unlock %s", tostring(coinId))
      end
    end
  end

  if metaStateTable.unlockedUpgradeIds ~= nil then
    local unlockedUpgradeIndex = {}

    for _, upgradeId in ipairs(metaStateTable.unlockedUpgradeIds or {}) do
      unlockedUpgradeIndex[upgradeId] = true
    end

    for _, upgradeId in ipairs(expectedUnlockedUpgradeIds) do
      if not unlockedUpgradeIndex[upgradeId] then
        return false, string.format("metaState unlockedUpgradeIds missing purchased unlock %s", tostring(upgradeId))
      end
    end
  end

  if metaStateTable.runRecords ~= nil then
    if type(metaStateTable.runRecords) ~= "table" then
      return false, "metaState runRecords must be a table"
    end

    for index, record in ipairs(metaStateTable.runRecords) do
      ok, errorMessage = validateRunRecord(record, index)

      if not ok then
        return false, errorMessage
      end
    end
  end

  if metaStateTable.stats ~= nil then
    if type(metaStateTable.stats) ~= "table" then
      return false, "metaState stats must be a table"
    end

    for statKey, statValue in pairs(metaStateTable.stats) do
      if not VALID_META_STATS[statKey] then
        return false, string.format("metaState stats has unknown field %s", tostring(statKey))
      end

      if not isNonNegativeInteger(statValue) then
        return false, string.format("metaState stat %s must be a non-negative integer", tostring(statKey))
      end
    end
  end

  return true
end

function Validator.validateMetaState(metaState)
  local ok, errorMessage = Validator.validateMetaStatePayload(metaState)

  if not ok then
    return false, errorMessage
  end

  if type(metaState.effectiveValues) ~= "table" then
    return false, "metaState effectiveValues must be a table"
  end

  if type(metaState.modifiers) ~= "table" then
    return false, "metaState modifiers must be a table"
  end

  return true
end

function Validator.validateSaveArtifactPayload(artifact)
  if type(artifact) ~= "table" then
    return false, "save artifact must be a table"
  end

  for key in pairs(artifact) do
    if not VALID_SAVE_ARTIFACT_KEYS[key] then
      return false, string.format("save artifact has unknown field %s", tostring(key))
    end
  end

  if type(artifact.artifactType) ~= "string" or artifact.artifactType == "" then
    return false, "save artifact artifactType must be non-empty string"
  end

  if not isPositiveInteger(artifact.version) then
    return false, "save artifact version must be a positive integer"
  end

  if type(artifact.metaState) ~= "table" then
    return false, "save artifact metaState must be a table"
  end

  return Validator.validateMetaStatePayload(artifact.metaState)
end

function Validator.validateActiveRunArtifactPayload(artifact)
  if type(artifact) ~= "table" then
    return false, "active run artifact must be a table"
  end

  for key in pairs(artifact) do
    if not VALID_ACTIVE_RUN_ARTIFACT_KEYS[key] then
      return false, string.format("active run artifact contains unknown field %s", tostring(key))
    end
  end

  if type(artifact.artifactType) ~= "string" or artifact.artifactType == "" then
    return false, "active run artifact must include artifactType"
  end

  if not isPositiveInteger(artifact.version) then
    return false, "active run artifact version must be a positive integer"
  end

  if type(artifact.currentState) ~= "string" or not VALID_ACTIVE_RUN_STATES[artifact.currentState] then
    return false, "active run artifact has invalid currentState"
  end

  if type(artifact.runState) ~= "table" then
    return false, "active run artifact runState must be a table"
  end

  local ok, errorMessage = Validator.validateRunState(artifact.runState)

  if not ok then
    return false, errorMessage
  end

  if not isPositiveInteger(artifact.runRngSeed) then
    return false, "active run artifact runRngSeed must be a positive integer"
  end

  if artifact.selectedCall ~= nil and not VALID_COIN_RESULTS[artifact.selectedCall] then
    return false, "active run artifact selectedCall must be heads or tails"
  end

  if artifact.postResultNextState ~= nil then
    if type(artifact.postResultNextState) ~= "string" or not VALID_POST_RESULT_NEXT_STATES[artifact.postResultNextState] then
      return false, "active run artifact postResultNextState is invalid"
    end
  end

  if artifact.stageState ~= nil then
    if type(artifact.stageState) ~= "table" then
      return false, "active run artifact stageState must be a table"
    end

    ok, errorMessage = Validator.validateStageState(artifact.runState, artifact.stageState)

    if not ok then
      return false, errorMessage
    end
  end

  if artifact.lastBatchResult ~= nil then
    if type(artifact.lastBatchResult) ~= "table" then
      return false, "active run artifact lastBatchResult must be a table"
    end

    if artifact.stageState == nil then
      return false, "active run artifact lastBatchResult requires stageState"
    end

    ok, errorMessage = Validator.validateBatchResult(artifact.runState, artifact.stageState, artifact.lastBatchResult)

    if not ok then
      return false, errorMessage
    end
  end

  if artifact.shopOffers ~= nil then
    if type(artifact.shopOffers) ~= "table" then
      return false, "active run artifact shopOffers must be a table"
    end

    ok, errorMessage = Validator.validateShopOffers(artifact.runState, artifact.shopOffers)

    if not ok then
      return false, errorMessage
    end
  end

  if artifact.rewardPreviewSession ~= nil then
    if type(artifact.rewardPreviewSession) ~= "table" then
      return false, "active run artifact rewardPreviewSession must be a table"
    end

    if type(artifact.rewardPreviewSession.options or {}) ~= "table" then
      return false, "active run artifact rewardPreviewSession options must be a table"
    end

    local seenOptions = {}

    for index, option in ipairs(artifact.rewardPreviewSession.options or {}) do
      ok, errorMessage = validateRewardOption(option, string.format("active run reward option %d", index))

      if not ok then
        return false, errorMessage
      end

      local optionKey = string.format("%s:%s", option.type, option.contentId)

      if seenOptions[optionKey] then
        return false, string.format("active run reward options contain duplicate option %s", optionKey)
      end

      seenOptions[optionKey] = true
    end

    if artifact.rewardPreviewSession.selectedIndex ~= nil then
      if not isPositiveInteger(artifact.rewardPreviewSession.selectedIndex) then
        return false, "active run artifact rewardPreviewSession selectedIndex must be a positive integer"
      end

      if artifact.rewardPreviewSession.options[artifact.rewardPreviewSession.selectedIndex] == nil then
        return false, "active run artifact rewardPreviewSession selectedIndex is out of range"
      end
    end

    if artifact.rewardPreviewSession.choice ~= nil then
      ok, errorMessage = validateRewardOption(artifact.rewardPreviewSession.choice, "active run reward choice")

      if not ok then
        return false, errorMessage
      end

      local choiceKey = string.format(
        "%s:%s",
        tostring(artifact.rewardPreviewSession.choice.type),
        tostring(artifact.rewardPreviewSession.choice.contentId)
      )

      if not seenOptions[choiceKey] then
        return false, "active run artifact reward choice is not present in reward options"
      end
    end

    if type(artifact.rewardPreviewSession.claimed) ~= "boolean" then
      return false, "active run artifact rewardPreviewSession claimed must be boolean"
    end

    if artifact.rewardPreviewSession.claimed == true and #(artifact.rewardPreviewSession.options or {}) > 0 and artifact.rewardPreviewSession.choice == nil then
      return false, "active run artifact claimed rewardPreviewSession must include reward choice"
    end
  end

  if artifact.encounterSession ~= nil then
    ok, errorMessage = validateEncounterSession(artifact.encounterSession, "active run artifact encounterSession")
    if not ok then
      return false, errorMessage
    end
  end

  if artifact.currentStageDefinitionId ~= nil then
    if type(artifact.currentStageDefinitionId) ~= "string" or artifact.currentStageDefinitionId == "" then
      return false, "active run artifact currentStageDefinitionId must be a non-empty string"
    end

    local Stages = require("src.content.stages")

    if not Stages.getById(artifact.currentStageDefinitionId) then
      return false, string.format("active run artifact references unknown stage definition %s", artifact.currentStageDefinitionId)
    end

    if artifact.stageState ~= nil then
      local expectedIds = {
        [artifact.stageState.stageId] = true,
      }

      if artifact.stageState.variantId then
        expectedIds[artifact.stageState.variantId] = true
      end

      local resolvedForRun = artifact.runState and Stages.getForRound(artifact.runState.roundIndex, artifact.runState) or nil
      if resolvedForRun then
        expectedIds[resolvedForRun.id] = true

        if resolvedForRun.variantId then
          expectedIds[resolvedForRun.variantId] = true
        end
      end

      if not expectedIds[artifact.currentStageDefinitionId] then
        return false, "active run artifact currentStageDefinitionId does not match current stage state"
      end
    end
  end

  if artifact.screenState ~= nil and type(artifact.screenState) ~= "table" then
    return false, "active run artifact screenState must be a table"
  end

  local requiresStageState = {
    boss_warning = true,
    stage = true,
    result = true,
    post_stage_analytics = true,
    reward_preview = true,
    boss_reward = true,
    encounter = true,
    shop = true,
  }

  if requiresStageState[artifact.currentState] and artifact.stageState == nil then
    return false, string.format("active run artifact state %s requires stageState", artifact.currentState)
  end

  if (artifact.currentState == "result" or artifact.currentState == "post_stage_analytics" or artifact.currentState == "reward_preview" or artifact.currentState == "boss_reward" or artifact.currentState == "encounter" or artifact.currentState == "shop")
    and type(artifact.lastStageResult) ~= "table" then
    return false, string.format("active run artifact state %s requires lastStageResult", artifact.currentState)
  end

  if (artifact.currentState == "result" or artifact.currentState == "post_stage_analytics") and artifact.lastStageResult ~= nil then
    if artifact.postResultNextState == nil then
      return false, string.format("active run artifact state %s requires postResultNextState", artifact.currentState)
    end
  end

  if artifact.currentState == "post_stage_analytics" and artifact.postResultNextState ~= "post_stage_analytics" then
    return false, "active run artifact post_stage_analytics state must preserve postResultNextState"
  end

  if (artifact.currentState == "reward_preview" or artifact.currentState == "boss_reward")
    and type(artifact.rewardPreviewSession) ~= "table" then
    return false, string.format("active run artifact state %s requires rewardPreviewSession", artifact.currentState)
  end

  if artifact.currentState == "encounter" and type(artifact.encounterSession) ~= "table" then
    return false, "active run artifact encounter state requires encounterSession"
  end

  if artifact.currentState == "shop" and type(artifact.shopSession) ~= "table" then
    return false, "active run artifact shop state requires shopSession"
  end

  if artifact.currentState == "shop" and type(artifact.shopOffers) ~= "table" then
    return false, "active run artifact shop state requires shopOffers"
  end

  if artifact.currentState == "stage" and artifact.stageState and artifact.stageState.stageStatus ~= "active" then
    return false, "active run artifact stage state must be active"
  end

  if artifact.currentState == "loadout" then
    if artifact.stageState ~= nil then
      return false, "active run artifact loadout state must not include stageState"
    end

    if artifact.lastStageResult ~= nil then
      return false, "active run artifact loadout state must not include lastStageResult"
    end

    if artifact.rewardPreviewSession ~= nil then
      return false, "active run artifact loadout state must not include rewardPreviewSession"
    end

    if artifact.shopSession ~= nil or (artifact.shopOffers and #artifact.shopOffers > 0) then
      return false, "active run artifact loadout state must not include shop state"
    end

    local resumeLoadoutState = artifact.screenState and artifact.screenState.resumeLoadoutState or nil

    if artifact.screenState ~= nil and resumeLoadoutState == nil then
      return false, "active run artifact loadout screenState must include resumeLoadoutState"
    end

    if resumeLoadoutState ~= nil then
      if type(resumeLoadoutState) ~= "table" then
        return false, "active run artifact resumeLoadoutState must be a table"
      end

      if type(resumeLoadoutState.selectionSlots) ~= "table" then
        return false, "active run artifact resumeLoadoutState selectionSlots must be a table"
      end

      local collectionIndex = {}
      for _, coinId in ipairs(artifact.runState.collectionCoinIds or {}) do
        collectionIndex[coinId] = true
      end

      ok, errorMessage = validateSlotState(
        resumeLoadoutState.selectionSlots,
        artifact.runState.maxActiveCoinSlots,
        collectionIndex,
        "active run artifact resumeLoadoutState selectionSlots",
        false
      )

      if not ok then
        return false, errorMessage
      end

      local selectedCollectionIndex = resumeLoadoutState.selectedCollectionIndex
      if selectedCollectionIndex == nil then
        selectedCollectionIndex = resumeLoadoutState.selectedCoinIndex
      end

      if selectedCollectionIndex ~= nil and not isPositiveInteger(selectedCollectionIndex) then
        return false, "active run artifact resumeLoadoutState selectedCollectionIndex must be a positive integer"
      end

      if resumeLoadoutState.collectionScrollOffset ~= nil and not isPositiveInteger(resumeLoadoutState.collectionScrollOffset) then
        return false, "active run artifact resumeLoadoutState collectionScrollOffset must be a positive integer"
      end
    end
  end

  local latestStageResult = artifact.runState.history
    and artifact.runState.history.stageResults
    and artifact.runState.history.stageResults[#(artifact.runState.history.stageResults or {})]
    or nil

  if artifact.lastStageResult ~= nil then
    if type(artifact.lastStageResult) ~= "table" then
      return false, "active run artifact lastStageResult must be a table"
    end

    if latestStageResult == nil then
      return false, "active run artifact lastStageResult requires stage history"
    end

    if artifact.lastStageResult.roundIndex ~= latestStageResult.roundIndex
      or artifact.lastStageResult.stageId ~= latestStageResult.stageId
      or artifact.lastStageResult.status ~= latestStageResult.status then
      return false, "active run artifact lastStageResult does not match latest stage history"
    end
  end

  local latestShopVisit = artifact.runState.history
    and artifact.runState.history.shopVisits
    and artifact.runState.history.shopVisits[#(artifact.runState.history.shopVisits or {})]
    or nil

  if artifact.shopSession ~= nil then
    if type(artifact.shopSession) ~= "table" then
      return false, "active run artifact shopSession must be a table"
    end

    if latestShopVisit == nil then
      return false, "active run artifact shopSession requires shop history"
    end

    if artifact.shopSession.visitIndex ~= latestShopVisit.visitIndex
      or artifact.shopSession.roundIndex ~= latestShopVisit.roundIndex
      or artifact.shopSession.sourceStageId ~= latestShopVisit.sourceStageId then
      return false, "active run artifact shopSession does not match latest shop history"
    end
  end

  local rewardEligible = artifact.lastStageResult
    and ((artifact.lastStageResult.stageType == "normal" and artifact.lastStageResult.status == "cleared" and artifact.runState.runStatus == "active")
      or (artifact.lastStageResult.stageType == "boss" and artifact.lastStageResult.status == "cleared" and artifact.runState.runStatus == "won"))

  if (artifact.currentState == "result" or artifact.currentState == "post_stage_analytics") and rewardEligible and type(artifact.rewardPreviewSession) ~= "table" then
    return false, string.format("active run artifact state %s requires rewardPreviewSession when reward flow is pending", artifact.currentState)
  end

  if artifact.currentState == "encounter" then
    local encounterEligible = artifact.lastStageResult
      and artifact.lastStageResult.stageType == "normal"
      and artifact.lastStageResult.status == "cleared"
      and artifact.runState.runStatus == "active"

    if not encounterEligible then
      return false, "active run artifact encounter state is only valid for cleared active normal stages"
    end
  end

  return true
end

function Validator.validateReplayTranscriptPayload(transcript)
  local Coins = require("src.content.coins")
  local Stages = require("src.content.stages")
  local Upgrades = require("src.content.upgrades")

  if type(transcript) ~= "table" then
    return false, "replay transcript must be a table"
  end

  for key in pairs(transcript) do
    if not VALID_REPLAY_TRANSCRIPT_KEYS[key] then
      return false, string.format("replay transcript has unknown field %s", tostring(key))
    end
  end

  if transcript.artifactType ~= "replay_transcript" then
    return false, "replay transcript artifactType must be replay_transcript"
  end

  if not isPositiveInteger(transcript.version) then
    return false, "replay transcript version must be a positive integer"
  end

  if type(transcript.bootstrap) ~= "table" then
    return false, "replay transcript bootstrap must be a table"
  end

  for key in pairs(transcript.bootstrap) do
    if not VALID_REPLAY_BOOTSTRAP_KEYS[key] then
      return false, string.format("replay transcript bootstrap has unknown field %s", tostring(key))
    end
  end

  if not isPositiveInteger(transcript.bootstrap.seed) then
    return false, "replay transcript bootstrap seed must be a positive integer"
  end

  if type(transcript.bootstrap.metaState) ~= "table" then
    return false, "replay transcript bootstrap metaState must be a table"
  end

  if type(transcript.bootstrap.starterCollection) ~= "table" then
    return false, "replay transcript bootstrap starterCollection must be a table"
  end

  if type(transcript.bootstrap.ownedUpgradeIds) ~= "table" then
    return false, "replay transcript bootstrap ownedUpgradeIds must be a table"
  end

  local ok, errorMessage = validateIdList(transcript.bootstrap.starterCollection or {}, "replay transcript bootstrap starterCollection", Coins.getById)
  if not ok then
    return false, errorMessage
  end

  ok, errorMessage = validateIdArray(transcript.bootstrap.starterPurse or {}, "replay transcript bootstrap starterPurse", Coins.getById)
  if not ok then
    return false, errorMessage
  end

  ok, errorMessage = validateIdList(transcript.bootstrap.ownedUpgradeIds or {}, "replay transcript bootstrap ownedUpgradeIds", Upgrades.getById)
  if not ok then
    return false, errorMessage
  end

  if transcript.bootstrap.startingCollectionSize ~= nil and not isPositiveInteger(transcript.bootstrap.startingCollectionSize) then
    return false, "replay transcript bootstrap startingCollectionSize must be a positive integer"
  end

  if type(transcript.bootstrap.resolvedValues) ~= "table" then
    return false, "replay transcript bootstrap resolvedValues must be a table"
  end

  ok, errorMessage = Validator.validateMetaStatePayload(transcript.bootstrap.metaState or {})
  if not ok then
    return false, string.format("replay transcript bootstrap metaState invalid: %s", errorMessage)
  end

  if type(transcript.stages) ~= "table" then
    return false, "replay transcript stages must be a table"
  end

  for index, stageEntry in ipairs(transcript.stages or {}) do
    if type(stageEntry) ~= "table" then
      return false, string.format("replay transcript stage %d must be a table", index)
    end

    for key in pairs(stageEntry) do
      if not VALID_REPLAY_STAGE_KEYS[key] then
        return false, string.format("replay transcript stage %d has unknown field %s", index, tostring(key))
      end
    end

    if not isPositiveInteger(stageEntry.roundIndex) then
      return false, string.format("replay transcript stage %d roundIndex must be a positive integer", index)
    end

    if type(stageEntry.stageId) ~= "string" or stageEntry.stageId == "" or not Stages.getById(stageEntry.stageId) then
      return false, string.format("replay transcript stage %d has unknown stageId %s", index, tostring(stageEntry.stageId))
    end

    if stageEntry.stageType ~= nil and not VALID_STAGE_TYPES[stageEntry.stageType] then
      return false, string.format("replay transcript stage %d has invalid stageType %s", index, tostring(stageEntry.stageType))
    end

    if stageEntry.variantId ~= nil and (type(stageEntry.variantId) ~= "string" or stageEntry.variantId == "") then
      return false, string.format("replay transcript stage %d variantId must be a non-empty string", index)
    end

    if stageEntry.variantName ~= nil and (type(stageEntry.variantName) ~= "string" or stageEntry.variantName == "") then
      return false, string.format("replay transcript stage %d variantName must be a non-empty string", index)
    end

    if stageEntry.variantId ~= nil then
      local resolvedStage = Stages.getForRound(stageEntry.roundIndex, {
        seed = transcript.bootstrap.seed,
      })

      if not resolvedStage then
        return false, string.format("replay transcript stage %d could not resolve stage variant", index)
      end

      local expectedVariantId = resolvedStage.variantId or resolvedStage.id

      if stageEntry.variantId ~= expectedVariantId then
        return false, string.format("replay transcript stage %d variantId %s does not match resolved variant %s", index, tostring(stageEntry.variantId), tostring(expectedVariantId))
      end

      if stageEntry.variantName ~= nil and resolvedStage.variantName ~= nil and stageEntry.variantName ~= resolvedStage.variantName then
        return false, string.format("replay transcript stage %d variantName %s does not match resolved variantName %s", index, tostring(stageEntry.variantName), tostring(resolvedStage.variantName))
      end
    end

    if stageEntry.loadout ~= nil then
      if type(stageEntry.loadout) ~= "table" then
        return false, string.format("replay transcript stage %d loadout must be a table", index)
      end

      for key in pairs(stageEntry.loadout) do
        if not VALID_REPLAY_LOADOUT_KEYS[key] then
          return false, string.format("replay transcript stage %d loadout has unknown field %s", index, tostring(key))
        end
      end

      if type(stageEntry.loadout.slots) ~= "table" then
        return false, string.format("replay transcript stage %d loadout slots must be a table", index)
      end

      if type(stageEntry.loadout.canonicalKey) ~= "string" or stageEntry.loadout.canonicalKey == "" then
        return false, string.format("replay transcript stage %d loadout canonicalKey is required", index)
      end

      local inferredMaxSlots = math.max(1, getMaxNumericIndex(stageEntry.loadout.slots))
      local expectedCanonicalKey = Loadout.toCanonicalKey(stageEntry.loadout.slots, inferredMaxSlots)

      if expectedCanonicalKey ~= stageEntry.loadout.canonicalKey then
        return false, string.format("replay transcript stage %d loadout canonicalKey does not match slots", index)
      end
    end

    if type(stageEntry.batches) ~= "table" then
      return false, string.format("replay transcript stage %d batches must be a table", index)
    end

    local rewardEligible = stageEntry.stageType == "normal" or stageEntry.stageType == "boss"

    if stageEntry.shop ~= nil and stageEntry.reward == nil then
      return false, string.format("replay transcript stage %d is missing reward data before shop", index)
    end

    if stageEntry.shop ~= nil and stageEntry.encounter == nil then
      return false, string.format("replay transcript stage %d is missing encounter data before shop", index)
    end

    if stageEntry.reward ~= nil then
      if not rewardEligible then
        return false, string.format("replay transcript stage %d has reward data for ineligible stage", index)
      end

      if type(stageEntry.reward) ~= "table" then
        return false, string.format("replay transcript stage %d reward must be a table", index)
      end

      for key in pairs(stageEntry.reward) do
        if not VALID_REPLAY_REWARD_KEYS[key] then
          return false, string.format("replay transcript stage %d reward has unknown field %s", index, tostring(key))
        end
      end

      if type(stageEntry.reward.options) ~= "table" then
        return false, string.format("replay transcript stage %d reward options must be a table", index)
      end

      local seenRewardOptionKeys = {}
      for optionIndex, option in ipairs(stageEntry.reward.options or {}) do
        for key in pairs(option or {}) do
          if not VALID_REPLAY_REWARD_OPTION_KEYS[key] then
            return false, string.format("replay transcript stage %d reward option %d has unknown field %s", index, optionIndex, tostring(key))
          end
        end

        local okOption, optionError = validateRewardOption(option, string.format("replay transcript stage %d reward option %d", index, optionIndex))
        if not okOption then
          return false, optionError
        end

        local optionKey = string.format("%s:%s", tostring(option.type), tostring(option.contentId))
        if seenRewardOptionKeys[optionKey] then
          return false, string.format("replay transcript stage %d reward option %d duplicates %s", index, optionIndex, optionKey)
        end
        seenRewardOptionKeys[optionKey] = true
      end

      if #(stageEntry.reward.options or {}) > 0 and stageEntry.reward.choice == nil then
        return false, string.format("replay transcript stage %d reward choice is required when reward options exist", index)
      end

      if stageEntry.reward.choice ~= nil then
        for key in pairs(stageEntry.reward.choice or {}) do
          if not VALID_REPLAY_REWARD_OPTION_KEYS[key] then
            return false, string.format("replay transcript stage %d reward choice has unknown field %s", index, tostring(key))
          end
        end

        local okChoice, choiceError = validateRewardOption(stageEntry.reward.choice, string.format("replay transcript stage %d reward choice", index))
        if not okChoice then
          return false, choiceError
        end

        local choiceKey = string.format("%s:%s", tostring(stageEntry.reward.choice.type), tostring(stageEntry.reward.choice.contentId))
        if not seenRewardOptionKeys[choiceKey] then
          return false, string.format("replay transcript stage %d reward choice %s is not present in options", index, choiceKey)
        end
      end
    end

    local encounterEligible = stageEntry.stageType == "normal"

    if stageEntry.encounter ~= nil then
      if not encounterEligible then
        return false, string.format("replay transcript stage %d has encounter data for ineligible stage", index)
      end

      if type(stageEntry.encounter) ~= "table" then
        return false, string.format("replay transcript stage %d encounter must be a table", index)
      end

      for key in pairs(stageEntry.encounter) do
        if not VALID_REPLAY_ENCOUNTER_KEYS[key] then
          return false, string.format("replay transcript stage %d encounter has unknown field %s", index, tostring(key))
        end
      end

      if type(stageEntry.encounter.id) ~= "string" or stageEntry.encounter.id == "" then
        return false, string.format("replay transcript stage %d encounter requires id", index)
      end

      if type(stageEntry.encounter.name) ~= "string" or stageEntry.encounter.name == "" then
        return false, string.format("replay transcript stage %d encounter requires name", index)
      end

      if type(stageEntry.encounter.description) ~= "string" or stageEntry.encounter.description == "" then
        return false, string.format("replay transcript stage %d encounter requires description", index)
      end

      if type(stageEntry.encounter.choices) ~= "table" then
        return false, string.format("replay transcript stage %d encounter choices must be a table", index)
      end

      local seenEncounterChoiceIds = {}
      for choiceIndex, choice in ipairs(stageEntry.encounter.choices or {}) do
        local okChoice, choiceError = validateEncounterChoice(choice, string.format("replay transcript stage %d encounter choice %d", index, choiceIndex))
        if not okChoice then
          return false, choiceError
        end

        if seenEncounterChoiceIds[choice.id] then
          return false, string.format("replay transcript stage %d encounter choice %d duplicates %s", index, choiceIndex, tostring(choice.id))
        end

        seenEncounterChoiceIds[choice.id] = true
      end

      if #(stageEntry.encounter.choices or {}) > 0 and stageEntry.encounter.choice == nil then
        return false, string.format("replay transcript stage %d encounter choice is required when encounter choices exist", index)
      end

      if stageEntry.encounter.choice ~= nil then
        local okChoice, choiceError = validateEncounterChoice(stageEntry.encounter.choice, string.format("replay transcript stage %d encounter choice", index))
        if not okChoice then
          return false, choiceError
        end

        if not seenEncounterChoiceIds[stageEntry.encounter.choice.id] then
          return false, string.format("replay transcript stage %d encounter choice %s is not present in encounter choices", index, tostring(stageEntry.encounter.choice.id))
        end
      end
    end

    local encounterEligible = stageEntry.stageType == "normal"

    if stageEntry.encounter ~= nil then
      if not encounterEligible then
        return false, string.format("replay transcript stage %d has encounter data for ineligible stage", index)
      end

      if type(stageEntry.encounter) ~= "table" then
        return false, string.format("replay transcript stage %d encounter must be a table", index)
      end

      for key in pairs(stageEntry.encounter) do
        if not VALID_REPLAY_ENCOUNTER_KEYS[key] then
          return false, string.format("replay transcript stage %d encounter has unknown field %s", index, tostring(key))
        end
      end

      if type(stageEntry.encounter.id) ~= "string" or stageEntry.encounter.id == "" then
        return false, string.format("replay transcript stage %d encounter requires id", index)
      end

      if type(stageEntry.encounter.name) ~= "string" or stageEntry.encounter.name == "" then
        return false, string.format("replay transcript stage %d encounter requires name", index)
      end

      if type(stageEntry.encounter.description) ~= "string" or stageEntry.encounter.description == "" then
        return false, string.format("replay transcript stage %d encounter requires description", index)
      end

      if type(stageEntry.encounter.choices) ~= "table" then
        return false, string.format("replay transcript stage %d encounter choices must be a table", index)
      end

      local seenEncounterChoiceIds = {}
      for choiceIndex, choice in ipairs(stageEntry.encounter.choices or {}) do
        local okChoice, choiceError = validateEncounterChoice(choice, string.format("replay transcript stage %d encounter choice %d", index, choiceIndex))
        if not okChoice then
          return false, choiceError
        end

        if seenEncounterChoiceIds[choice.id] then
          return false, string.format("replay transcript stage %d encounter choice %d duplicates %s", index, choiceIndex, tostring(choice.id))
        end

        seenEncounterChoiceIds[choice.id] = true
      end

      if #(stageEntry.encounter.choices or {}) > 0 and stageEntry.encounter.choice == nil then
        return false, string.format("replay transcript stage %d encounter choice is required when encounter choices exist", index)
      end

      if stageEntry.encounter.choice ~= nil then
        local okChoice, choiceError = validateEncounterChoice(stageEntry.encounter.choice, string.format("replay transcript stage %d encounter choice", index))
        if not okChoice then
          return false, choiceError
        end

        if not seenEncounterChoiceIds[stageEntry.encounter.choice.id] then
          return false, string.format("replay transcript stage %d encounter choice %s is not present in encounter choices", index, tostring(stageEntry.encounter.choice.id))
        end
      end
    end

    for batchIndex, batchEntry in ipairs(stageEntry.batches or {}) do
      if type(batchEntry) ~= "table" then
        return false, string.format("replay transcript stage %d batch %d must be a table", index, batchIndex)
      end

      for key in pairs(batchEntry) do
        if not VALID_REPLAY_BATCH_KEYS[key] then
          return false, string.format("replay transcript stage %d batch %d has unknown field %s", index, batchIndex, tostring(key))
        end
      end

      if not isPositiveInteger(batchEntry.batchId) then
        return false, string.format("replay transcript stage %d batch %d batchId must be a positive integer", index, batchIndex)
      end

      if batchEntry.roundIndex ~= stageEntry.roundIndex then
        return false, string.format("replay transcript stage %d batch %d roundIndex mismatch", index, batchIndex)
      end

      if batchEntry.stageId ~= stageEntry.stageId then
        return false, string.format("replay transcript stage %d batch %d stageId mismatch", index, batchIndex)
      end

      if batchEntry.call ~= "heads" and batchEntry.call ~= "tails" then
        return false, string.format("replay transcript stage %d batch %d call must be heads or tails", index, batchIndex)
      end

      if batchEntry.resolutionEntries ~= nil then
        if type(batchEntry.resolutionEntries) ~= "table" then
          return false, string.format("replay transcript stage %d batch %d resolutionEntries must be a table", index, batchIndex)
        end

        local seenCoinIds = {}
        local seenInstanceIds = {}
        local seenSlotIndices = {}
        local expectedSlotCount = nil

        local usesInstanceEntries = false
        for _, entry in ipairs(batchEntry.resolutionEntries) do
          if type(entry) == "table" and entry.instanceId ~= nil then
            usesInstanceEntries = true
            break
          end
        end

        if stageEntry.loadout and not usesInstanceEntries then
          local inferredMaxSlots = math.max(1, getMaxNumericIndex(stageEntry.loadout.slots))
          local okLoadout, normalizedLoadout = validateSlotState(stageEntry.loadout.slots, inferredMaxSlots, nil, string.format("replay transcript stage %d loadout slots", index), false)

          if not okLoadout then
            return false, normalizedLoadout
          end

          expectedSlotCount = #Loadout.compactSlots(normalizedLoadout, inferredMaxSlots)

          if #batchEntry.resolutionEntries ~= expectedSlotCount then
            return false, string.format("replay transcript stage %d batch %d resolution entry count does not match loadout", index, batchIndex)
          end
        end

        for resolutionIndex, entry in ipairs(batchEntry.resolutionEntries) do
          if type(entry) ~= "table" then
            return false, string.format("replay transcript stage %d batch %d resolutionEntries[%d] must be a table", index, batchIndex, resolutionIndex)
          end

          for key in pairs(entry) do
            if not VALID_REPLAY_RESOLUTION_ENTRY_KEYS[key] then
              return false, string.format("replay transcript stage %d batch %d resolution entry %d has unknown field %s", index, batchIndex, resolutionIndex, tostring(key))
            end
          end

          if type(entry.coinId) ~= "string" or entry.coinId == "" then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d requires coinId", index, batchIndex, resolutionIndex)
          end

          if not Coins.getById(entry.coinId) then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d references unknown coin %s", index, batchIndex, resolutionIndex, tostring(entry.coinId))
          end

          if entry.instanceId ~= nil then
            if type(entry.instanceId) ~= "string" or entry.instanceId == "" then
              return false, string.format("replay transcript stage %d batch %d resolution entry %d has invalid instanceId", index, batchIndex, resolutionIndex)
            end

            if seenInstanceIds[entry.instanceId] then
              return false, string.format("replay transcript stage %d batch %d resolution entry %d duplicates instance %s", index, batchIndex, resolutionIndex, tostring(entry.instanceId))
            end

            seenInstanceIds[entry.instanceId] = true
          end

          if stageEntry.loadout and not usesInstanceEntries and seenCoinIds[entry.coinId] then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d duplicates coin %s", index, batchIndex, resolutionIndex, tostring(entry.coinId))
          end

          seenCoinIds[entry.coinId] = true

          if not isPositiveInteger(entry.slotIndex) then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d slotIndex must be positive integer", index, batchIndex, resolutionIndex)
          end

          if seenSlotIndices[entry.slotIndex] then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d duplicates slotIndex %s", index, batchIndex, resolutionIndex, tostring(entry.slotIndex))
          end

          seenSlotIndices[entry.slotIndex] = true

          if not isPositiveInteger(entry.resolutionIndex) then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d resolutionIndex must be positive integer", index, batchIndex, resolutionIndex)
          end

          if entry.resolutionIndex ~= resolutionIndex then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d resolutionIndex mismatch", index, batchIndex, resolutionIndex)
          end

          if stageEntry.loadout and not usesInstanceEntries and stageEntry.loadout.slots[entry.slotIndex] ~= entry.coinId then
            return false, string.format("replay transcript stage %d batch %d resolution entry %d does not match loadout slots", index, batchIndex, resolutionIndex)
          end
        end
      end

      if batchEntry.forcedResults ~= nil then
        if type(batchEntry.forcedResults) ~= "table" then
          return false, string.format("replay transcript stage %d batch %d forcedResults must be a table", index, batchIndex)
        end

        local seenForcedResolutions = {}

        for forcedIndex, entry in ipairs(batchEntry.forcedResults) do
          if type(entry) ~= "table" then
            return false, string.format("replay transcript stage %d batch %d forced result %d must be a table", index, batchIndex, forcedIndex)
          end

          for key in pairs(entry) do
            if not VALID_REPLAY_FORCED_RESULT_KEYS[key] then
              return false, string.format("replay transcript stage %d batch %d forced result %d has unknown field %s", index, batchIndex, forcedIndex, tostring(key))
            end
          end

          if entry.result ~= "heads" and entry.result ~= "tails" then
            return false, string.format("replay transcript stage %d batch %d forced result %d has invalid result %s", index, batchIndex, forcedIndex, tostring(entry.result))
          end

          if type(entry.coinId) ~= "string" or entry.coinId == "" or not Coins.getById(entry.coinId) then
            return false, string.format("replay transcript stage %d batch %d forced result %d references unknown coin %s", index, batchIndex, forcedIndex, tostring(entry.coinId))
          end

          if entry.instanceId ~= nil and (type(entry.instanceId) ~= "string" or entry.instanceId == "") then
            return false, string.format("replay transcript stage %d batch %d forced result %d has invalid instanceId", index, batchIndex, forcedIndex)
          end

          if not isPositiveInteger(entry.slotIndex) then
            return false, string.format("replay transcript stage %d batch %d forced result %d slotIndex must be positive integer", index, batchIndex, forcedIndex)
          end

          if not isPositiveInteger(entry.resolutionIndex) then
            return false, string.format("replay transcript stage %d batch %d forced result %d resolutionIndex must be positive integer", index, batchIndex, forcedIndex)
          end

          if seenForcedResolutions[entry.resolutionIndex] then
            return false, string.format("replay transcript stage %d batch %d forced result %d duplicates resolutionIndex %s", index, batchIndex, forcedIndex, tostring(entry.resolutionIndex))
          end

          seenForcedResolutions[entry.resolutionIndex] = true

          if stageEntry.loadout and entry.instanceId == nil and stageEntry.loadout.slots[entry.slotIndex] ~= entry.coinId then
            return false, string.format("replay transcript stage %d batch %d forced result %d does not match loadout slots", index, batchIndex, forcedIndex)
          end
        end
      end
    end

    if stageEntry.shop ~= nil then
      if type(stageEntry.shop) ~= "table" then
        return false, string.format("replay transcript stage %d shop must be a table", index)
      end

      for key in pairs(stageEntry.shop) do
        if not VALID_REPLAY_SHOP_KEYS[key] then
          return false, string.format("replay transcript stage %d shop has unknown field %s", index, tostring(key))
        end
      end

      if not isPositiveInteger(stageEntry.shop.roundIndex) or stageEntry.shop.roundIndex ~= stageEntry.roundIndex then
        return false, string.format("replay transcript stage %d shop roundIndex mismatch", index)
      end

      if stageEntry.shop.sourceStageId ~= stageEntry.stageId then
        return false, string.format("replay transcript stage %d shop sourceStageId mismatch", index)
      end

      if type(stageEntry.shop.actions) ~= "table" or type(stageEntry.shop.offerSets) ~= "table"
        or type(stageEntry.shop.generationTraces) ~= "table" or type(stageEntry.shop.purchaseTraces) ~= "table" then
        return false, string.format("replay transcript stage %d shop trace arrays must be tables", index)
      end

      for actionIndex, action in ipairs(stageEntry.shop.actions or {}) do
        if type(action) ~= "table" then
          return false, string.format("replay transcript stage %d shop action %d must be a table", index, actionIndex)
        end

        for key in pairs(action) do
          if not VALID_REPLAY_SHOP_ACTION_KEYS[key] then
            return false, string.format("replay transcript stage %d shop action %d has unknown field %s", index, actionIndex, tostring(key))
          end
        end

        if action.type == "reroll" then
          if action.mode ~= nil and (type(action.mode) ~= "string" or action.mode == "") then
            return false, string.format("replay transcript stage %d reroll action %d has invalid mode", index, actionIndex)
          end
        elseif action.type == "purchase" then
          if action.outcome ~= "success" and action.outcome ~= "failure" then
            return false, string.format("replay transcript stage %d purchase action %d has invalid outcome", index, actionIndex)
          end

          if action.offerType ~= "coin" and action.offerType ~= "upgrade" then
            return false, string.format("replay transcript stage %d purchase action %d has invalid offerType", index, actionIndex)
          end

          if type(action.contentId) ~= "string" or action.contentId == "" then
            return false, string.format("replay transcript stage %d purchase action %d requires contentId", index, actionIndex)
          end
        else
          return false, string.format("replay transcript stage %d shop action %d has invalid type %s", index, actionIndex, tostring(action.type))
        end
      end
    end
  end

  if type(transcript.expected) ~= "table" then
    return false, "replay transcript expected must be a table"
  end

  return true
end

function Validator.validateRunState(runState)
  if type(runState) ~= "table" then
    return false, "runState must be a table"
  end

  if not isPositiveInteger(runState.seed) then
    return false, "runState.seed must be a positive integer"
  end

  if not isPositiveInteger(runState.roundIndex) then
    return false, "runState.roundIndex must be a positive integer"
  end

  if not VALID_RUN_STATUSES[runState.runStatus] then
    return false, string.format("runState has invalid runStatus %s", tostring(runState.runStatus))
  end

  if type(runState.currentStageId) ~= "nil" and (type(runState.currentStageId) ~= "string" or runState.currentStageId == "") then
    return false, "runState.currentStageId must be nil or a stage id"
  end

  if not isPositiveInteger(runState.maxActiveCoinSlots) then
    return false, "runState.maxActiveCoinSlots must be a positive integer"
  end

  if not isPositiveInteger(runState.baseFlipsPerStage) then
    return false, "runState.baseFlipsPerStage must be a positive integer"
  end

  if type(runState.resolvedValues) ~= "table" then
    return false, "runState.resolvedValues must be a table"
  end

  if type(runState.metaProjection) ~= "table" and runState.metaProjection ~= nil then
    return false, "runState.metaProjection must be a table or nil"
  end

  if type(runState.metaProjection) == "table" then
    local ok, errorMessage = EffectiveValueSystem.validateEffectiveValuesTable(runState.metaProjection.effectiveValues)

    if not ok then
      return false, string.format("runState.metaProjection.effectiveValues invalid: %s", errorMessage)
    end
  end

  if type(runState.history) ~= "table" then
    return false, "runState.history must be a table"
  end

  if type(runState.counters) ~= "table" then
    return false, "runState.counters must be a table"
  end

  if type(runState.flags) ~= "table" then
    return false, "runState.flags must be a table"
  end

  if type(runState.temporaryRunEffects) ~= "table" then
    return false, "runState.temporaryRunEffects must be a table"
  end

   if type(runState.pendingForcedCoinResults) ~= "table" then
    return false, "runState.pendingForcedCoinResults must be a table"
  end

  if type(runState.shopPoints) ~= "number" or runState.shopPoints < 0 then
    return false, "runState.shopPoints must be a non-negative number"
  end

  if not isNonNegativeInteger(runState.shopRerollsRemaining) then
    return false, "runState.shopRerollsRemaining must be a non-negative integer"
  end

  if type(runState.runTotalScore) ~= "number" or runState.runTotalScore < 0 then
    return false, "runState.runTotalScore must be a non-negative number"
  end

  local Coins = require("src.content.coins")
  local Upgrades = require("src.content.upgrades")
  local ok, collectionIndex = validateIdList(runState.collectionCoinIds, "runState.collectionCoinIds", Coins.getById)

  if not ok then
    return false, collectionIndex
  end

  local purseOk, purseError = PurseSystem.validateZones(runState, nil)

  if not purseOk then
    return false, purseError
  end

  local upgradeOk, upgradeError = validateIdList(runState.ownedUpgradeIds, "runState.ownedUpgradeIds", Upgrades.getById)

  if not upgradeOk then
    return false, upgradeError
  end

  local unlockedCoinsOk, unlockedCoinsError = validateIdList(runState.unlockedCoinIds or {}, "runState.unlockedCoinIds", Coins.getById)

  if not unlockedCoinsOk then
    return false, unlockedCoinsError
  end

  local unlockedUpgradesOk, unlockedUpgradesError = validateIdList(runState.unlockedUpgradeIds or {}, "runState.unlockedUpgradeIds", Upgrades.getById)

  if not unlockedUpgradesOk then
    return false, unlockedUpgradesError
  end

  local slotOk, slotError = validateSlotState(runState.equippedCoinSlots or {}, runState.maxActiveCoinSlots, collectionIndex, "runState.equippedCoinSlots", false)

  if not slotOk then
    return false, slotError
  end

  slotOk, slotError = validateSlotState(runState.persistedLoadoutSlots or {}, runState.maxActiveCoinSlots, collectionIndex, "runState.persistedLoadoutSlots", false)

  if not slotOk then
    return false, slotError
  end

  for counterName, counterValue in pairs(runState.counters or {}) do
    if not isNonNegativeInteger(counterValue) then
      return false, string.format("runState.counters.%s must be a non-negative integer", tostring(counterName))
    end
  end

  local effectIds = {}
  for index, effect in ipairs(runState.temporaryRunEffects or {}) do
    local actionOk, actionError = ActionQueue.validateAction({ op = "grant_temporary_effect", effect = effect })

    if not actionOk then
      return false, string.format("runState.temporaryRunEffects[%d] invalid: %s", index, actionError)
    end

    if effectIds[effect.id] then
      return false, string.format("runState.temporaryRunEffects contains duplicate id %s", effect.id)
    end

    effectIds[effect.id] = true
  end

  for index, forcedResult in ipairs(runState.pendingForcedCoinResults or {}) do
    if forcedResult ~= "heads" and forcedResult ~= "tails" then
      return false, string.format("runState.pendingForcedCoinResults[%d] must be heads or tails", index)
    end
  end

  return true
end

function Validator.validateStageState(runState, stageState)
  if stageState == nil then
    return true
  end

  if type(stageState) ~= "table" then
    return false, "stageState must be a table"
  end

  local purseOk, purseError = PurseSystem.validateZones(runState, stageState)

  if not purseOk then
    return false, purseError
  end

  if type(stageState.stageId) ~= "string" or stageState.stageId == "" then
    return false, "stageState.stageId is required"
  end

  if type(stageState.stageLabel) ~= "string" or stageState.stageLabel == "" then
    return false, "stageState.stageLabel is required"
  end

  if not VALID_STAGE_TYPES[stageState.stageType] then
    return false, string.format("stageState has invalid stageType %s", tostring(stageState.stageType))
  end

  if not VALID_STAGE_STATUSES[stageState.stageStatus] then
    return false, string.format("stageState has invalid stageStatus %s", tostring(stageState.stageStatus))
  end

  if type(stageState.targetScore) ~= "number" or stageState.targetScore <= 0 then
    return false, "stageState.targetScore must be a positive number"
  end

  if type(stageState.stageScore) ~= "number" or stageState.stageScore < 0 then
    return false, "stageState.stageScore must be a non-negative number"
  end

  if not isNonNegativeInteger(stageState.flipsRemaining) then
    return false, "stageState.flipsRemaining must be a non-negative integer"
  end

  if not isNonNegativeInteger(stageState.batchIndex) then
    return false, "stageState.batchIndex must be a non-negative integer"
  end

  if type(stageState.flags) ~= "table" then
    return false, "stageState.flags must be a table"
  end

  if type(stageState.resolvedValues) ~= "table" then
    return false, "stageState.resolvedValues must be a table"
  end

  if type(stageState.effectiveValues) ~= "table" then
    return false, "stageState.effectiveValues must be a table"
  end

  if stageState.lastCall ~= nil and stageState.lastCall ~= "heads" and stageState.lastCall ~= "tails" then
    return false, string.format("stageState.lastCall has invalid value %s", tostring(stageState.lastCall))
  end

  local maxFlips = stageState.resolvedValues["stage.flipsPerStage"] or (runState and runState.baseFlipsPerStage) or stageState.flipsRemaining
  if not isPositiveInteger(maxFlips) then
    return false, "stageState resolved flipsPerStage must be a positive integer"
  end

  if stageState.flipsRemaining > maxFlips then
    return false, string.format("stageState.flipsRemaining %d exceeds resolved max %d", stageState.flipsRemaining, maxFlips)
  end

  if stageState.stageStatus == "active" then
    if stageState.flipsRemaining <= 0 then
      return false, "active stageState must have flips remaining"
    end

    if stageState.stageScore >= stageState.targetScore then
      return false, "active stageState cannot already meet targetScore"
    end
  elseif stageState.stageStatus == "cleared" then
    if stageState.stageScore < stageState.targetScore then
      return false, "cleared stageState must meet targetScore"
    end
  elseif stageState.stageStatus == "failed" then
    if stageState.flipsRemaining ~= 0 then
      return false, "failed stageState must have zero flips remaining"
    end
  end

  if runState and runState.currentStageId and runState.currentStageId ~= stageState.stageId then
    return false, string.format("runState.currentStageId %s does not match stageState.stageId %s", tostring(runState.currentStageId), tostring(stageState.stageId))
  end

  local Bosses = require("src.content.bosses")
  local StageModifiers = require("src.content.stage_modifiers")
  local ok, errorMessage = validateIdList(stageState.activeBossModifierIds or {}, "stageState.activeBossModifierIds", Bosses.getById)

  if not ok then
    return false, errorMessage
  end

  ok, errorMessage = validateIdList(stageState.activeStageModifierIds or {}, "stageState.activeStageModifierIds", StageModifiers.getById)

  if not ok then
    return false, errorMessage
  end

  for streakName, streakValue in pairs(stageState.streak or {}) do
    if not isNonNegativeInteger(streakValue) then
      return false, string.format("stageState.streak.%s must be a non-negative integer", tostring(streakName))
    end
  end

  if stageState.lastBatchResults then
    if stageState.lastBatchResults.batchId ~= nil and stageState.lastBatchResults.batchId ~= stageState.batchIndex then
      return false, "stageState.lastBatchResults.batchId does not match stageState.batchIndex"
    end

    if stageState.lastBatchResults.stageStatusAfter ~= nil and stageState.lastBatchResults.stageStatusAfter ~= stageState.stageStatus then
      return false, "stageState.lastBatchResults.stageStatusAfter does not match stageState.stageStatus"
    end

    if stageState.lastBatchResults.flipsRemainingAfter ~= nil and stageState.lastBatchResults.flipsRemainingAfter ~= stageState.flipsRemaining then
      return false, "stageState.lastBatchResults.flipsRemainingAfter does not match stageState.flipsRemaining"
    end
  end

  return true
end

function Validator.validateBatchResult(runState, stageState, batchResult)
  if type(batchResult) ~= "table" then
    return false, "batchResult must be a table"
  end

  if type(batchResult.batch) ~= "table" then
    return false, "batchResult.batch must be a table"
  end

  local ok, errorMessage = validateBatchSnapshot(batchResult.batch)

  if not ok then
    return false, errorMessage
  end

  if batchResult.batchId ~= batchResult.batch.batchId then
    return false, "batchResult.batchId does not match batch snapshot"
  end

  if batchResult.call ~= batchResult.batch.call then
    return false, "batchResult.call does not match batch snapshot"
  end

  if runState and batchResult.batch.roundIndex ~= runState.roundIndex then
    return false, "batchResult roundIndex does not match runState"
  end

  if stageState then
    if batchResult.batch.stageId ~= stageState.stageId then
      return false, "batchResult stageId does not match stageState"
    end

    if batchResult.batch.stageType ~= stageState.stageType then
      return false, "batchResult stageType does not match stageState"
    end
  end

  if batchResult.status ~= (batchResult.trace and batchResult.trace.stageStatusAfter) then
    return false, "batchResult status does not match trace stageStatusAfter"
  end

  if batchResult.stageScore ~= (batchResult.trace and batchResult.trace.stageScoreAfter) then
    return false, "batchResult stageScore does not match trace stageScoreAfter"
  end

  if batchResult.runTotalScore ~= (batchResult.trace and batchResult.trace.runScoreAfter) then
    return false, "batchResult runTotalScore does not match trace runScoreAfter"
  end

  if batchResult.shopPoints ~= (batchResult.trace and batchResult.trace.shopPointsAfter) then
    return false, "batchResult shopPoints does not match trace shopPointsAfter"
  end

  if batchResult.flipsRemaining ~= (batchResult.trace and batchResult.trace.flipsRemainingAfter) then
    return false, "batchResult flipsRemaining does not match trace flipsRemainingAfter"
  end

  return true
end

function Validator.validateShopOffers(runState, offers)
  if type(offers) ~= "table" then
    return false, "shop offers must be a table"
  end

  local Coins = require("src.content.coins")
  local Upgrades = require("src.content.upgrades")
  local offerIds = {}
  local contentPairs = {}
  local ownedIndex = {}

  for _, coinId in ipairs(runState and runState.collectionCoinIds or {}) do
    ownedIndex["coin:" .. coinId] = true
  end

  for _, upgradeId in ipairs(runState and runState.ownedUpgradeIds or {}) do
    ownedIndex["upgrade:" .. upgradeId] = true
  end

  for index, offer in ipairs(offers) do
    if type(offer) ~= "table" then
      return false, string.format("shop offer %d must be a table", index)
    end

    if type(offer.id) ~= "string" or offer.id == "" then
      return false, string.format("shop offer %d missing id", index)
    end

    if offerIds[offer.id] then
      return false, string.format("shop offers contain duplicate id %s", offer.id)
    end
    offerIds[offer.id] = true

    if offer.type ~= "coin" and offer.type ~= "upgrade" then
      return false, string.format("shop offer %s has invalid type %s", offer.id, tostring(offer.type))
    end

    if type(offer.contentId) ~= "string" or offer.contentId == "" then
      return false, string.format("shop offer %s missing contentId", offer.id)
    end

    local contentKey = string.format("%s:%s", offer.type, offer.contentId)
    if contentPairs[contentKey] then
      return false, string.format("shop offers contain duplicate content %s", contentKey)
    end
    contentPairs[contentKey] = true

    if type(offer.price) ~= "number" or offer.price < 0 then
      return false, string.format("shop offer %s has invalid price %s", offer.id, tostring(offer.price))
    end

    if offer.type == "coin" and not Coins.getById(offer.contentId) then
      return false, string.format("shop offer %s references unknown coin %s", offer.id, offer.contentId)
    end

    if offer.type == "upgrade" and not Upgrades.getById(offer.contentId) then
      return false, string.format("shop offer %s references unknown upgrade %s", offer.id, offer.contentId)
    end

    local definition = offer.type == "coin" and Coins.getById(offer.contentId) or Upgrades.getById(offer.contentId)
    local isUnlocked

    if offer.type == "coin" then
      isUnlocked = Coins.isUnlocked(definition, runState and runState.unlockedCoinIds or {})
    else
      isUnlocked = Upgrades.isUnlocked(definition, runState and runState.unlockedUpgradeIds or {})
    end

    if not isUnlocked then
      return false, string.format("shop offer %s exposes locked content %s", offer.id, contentKey)
    end

    if offer.purchased ~= nil and type(offer.purchased) ~= "boolean" then
      return false, string.format("shop offer %s purchased flag must be boolean", offer.id)
    end

    if offer.type ~= "coin" and not offer.purchased and ownedIndex[contentKey] then
      return false, string.format("shop offer %s exposes already-owned content %s", offer.id, contentKey)
    end
  end

  return true
end

function Validator.validateRunHistory(runState)
  if type(runState) ~= "table" or type(runState.history) ~= "table" then
    return false, "runState.history must be a table"
  end

  local history = runState.history
  local requiredLists = {
    "loadoutCommits",
    "stageResults",
    "purchases",
    "shopVisits",
    "flipBatches",
  }

  for _, key in ipairs(requiredLists) do
    if type(history[key]) ~= "table" then
      return false, string.format("runState.history.%s must be a table", key)
    end
  end

  if type(history.bootstrap) ~= "table" then
    return false, "runState.history.bootstrap must exist"
  end

  if history.bootstrap.seed ~= runState.seed then
    return false, "runState.history.bootstrap.seed does not match runState.seed"
  end

  if type(history.bootstrap.resolvedValues) ~= "table" then
    return false, "runState.history.bootstrap.resolvedValues must be a table"
  end

  local bootstrapResolvedValues = history.bootstrap.resolvedValues
  local expectedBootstrapResolvedKeys = {
    "run.startingCollectionSize",
    "run.maxActiveCoinSlots",
    "stage.flipsPerStage",
    "purse.handSize",
    "run.startingShopPoints",
    "run.startingShopRerolls",
  }

  for _, key in ipairs(expectedBootstrapResolvedKeys) do
    local value = bootstrapResolvedValues[key]

    if value == nil then
      if key == "run.startingCollectionSize" and history.bootstrap.startingCollectionSize ~= nil then
        value = history.bootstrap.startingCollectionSize
      elseif key == "run.maxActiveCoinSlots" then
        value = bootstrapResolvedValues.maxActiveCoinSlots
      elseif key == "stage.flipsPerStage" then
        value = bootstrapResolvedValues.baseFlipsPerStage
      elseif key == "purse.handSize" then
        value = bootstrapResolvedValues.handSize
      elseif key == "run.startingShopPoints" then
        value = bootstrapResolvedValues.startingShopPoints
      elseif key == "run.startingShopRerolls" then
        value = bootstrapResolvedValues.startingShopRerolls
      end
    end

    local isValid = isNonNegativeInteger(value)

    if key == "run.maxActiveCoinSlots" or key == "stage.flipsPerStage" or key == "purse.handSize" then
      isValid = isPositiveInteger(value)
    end

    if not isValid then
      return false, string.format("runState.history.bootstrap.resolvedValues[%s] must be a valid integer", key)
    end
  end

  local stageIndex = {}
  local previousRoundIndex = 0

  for index, stageRecord in ipairs(history.stageResults or {}) do
    if not isPositiveInteger(stageRecord.roundIndex) then
      return false, string.format("stageResults[%d] requires positive integer roundIndex", index)
    end

    if stageRecord.roundIndex < previousRoundIndex then
      return false, string.format("stageResults[%d] roundIndex regressed from %d to %d", index, previousRoundIndex, stageRecord.roundIndex)
    end

    previousRoundIndex = stageRecord.roundIndex

    if type(stageRecord.stageId) ~= "string" or stageRecord.stageId == "" then
      return false, string.format("stageResults[%d] missing stageId", index)
    end

    if not VALID_STAGE_TYPES[stageRecord.stageType] then
      return false, string.format("stageResults[%d] has invalid stageType %s", index, tostring(stageRecord.stageType))
    end

    if not VALID_STAGE_STATUSES[stageRecord.status] then
      return false, string.format("stageResults[%d] has invalid status %s", index, tostring(stageRecord.status))
    end

    local stageKey = string.format("%d:%s", stageRecord.roundIndex, stageRecord.stageId)
    if stageIndex[stageKey] then
      return false, string.format("stageResults contains duplicate stage key %s", stageKey)
    end

    stageIndex[stageKey] = stageRecord

    local rewardEligible = (
      stageRecord.stageType == "normal"
      and stageRecord.status == "cleared"
      and (stageRecord.runStatus == "active" or stageRecord.runStatus == "won")
    ) or (
      stageRecord.stageType == "boss"
      and stageRecord.status == "cleared"
      and stageRecord.runStatus == "won"
    )

    if stageRecord.rewardOptions ~= nil then
      if not rewardEligible then
        return false, string.format("stageResults[%d] has reward data for ineligible stage", index)
      end

      if type(stageRecord.rewardOptions) ~= "table" then
        return false, string.format("stageResults[%d].rewardOptions must be a table", index)
      end

      local seenRewardOptionKeys = {}
      for optionIndex, option in ipairs(stageRecord.rewardOptions) do
        local okOption, optionError = validateRewardOption(option, string.format("stageResults[%d].rewardOptions[%d]", index, optionIndex))
        if not okOption then
          return false, optionError
        end

        local optionKey = string.format("%s:%s", tostring(option.type), tostring(option.contentId))
        if seenRewardOptionKeys[optionKey] then
          return false, string.format("stageResults[%d].rewardOptions duplicates %s", index, optionKey)
        end
        seenRewardOptionKeys[optionKey] = true
      end

      if #stageRecord.rewardOptions > 0 and stageRecord.rewardChoice == nil then
        local isPendingLatestRewardSelection = index == #(history.stageResults or {})

        if not isPendingLatestRewardSelection then
          return false, string.format("stageResults[%d] is missing rewardChoice despite rewardOptions", index)
        end
      end

      if stageRecord.rewardChoice ~= nil then
        local okChoice, choiceError = validateRewardOption(stageRecord.rewardChoice, string.format("stageResults[%d].rewardChoice", index))
        if not okChoice then
          return false, choiceError
        end

        local choiceKey = string.format("%s:%s", tostring(stageRecord.rewardChoice.type), tostring(stageRecord.rewardChoice.contentId))
        if not seenRewardOptionKeys[choiceKey] then
          return false, string.format("stageResults[%d].rewardChoice is not present in rewardOptions", index)
        end
      end
    elseif stageRecord.rewardChoice ~= nil then
      return false, string.format("stageResults[%d] has rewardChoice without rewardOptions", index)
    end

    local encounterEligible = stageRecord.stageType == "normal"
      and stageRecord.status == "cleared"
      and stageRecord.runStatus == "active"

    if stageRecord.encounter ~= nil then
      if not encounterEligible then
        return false, string.format("stageResults[%d] has encounter data for ineligible stage", index)
      end

      if type(stageRecord.encounter) ~= "table" then
        return false, string.format("stageResults[%d].encounter must be a table", index)
      end

      if type(stageRecord.encounter.id) ~= "string" or stageRecord.encounter.id == "" then
        return false, string.format("stageResults[%d].encounter requires id", index)
      end

      if type(stageRecord.encounter.name) ~= "string" or stageRecord.encounter.name == "" then
        return false, string.format("stageResults[%d].encounter requires name", index)
      end

      if type(stageRecord.encounter.description) ~= "string" or stageRecord.encounter.description == "" then
        return false, string.format("stageResults[%d].encounter requires description", index)
      end

      if type(stageRecord.encounter.choices) ~= "table" then
        return false, string.format("stageResults[%d].encounter choices must be a table", index)
      end

      local seenEncounterChoiceIds = {}
      for choiceIndex, choice in ipairs(stageRecord.encounter.choices or {}) do
        local okChoice, choiceError = validateEncounterChoice(choice, string.format("stageResults[%d].encounter.choices[%d]", index, choiceIndex))
        if not okChoice then
          return false, choiceError
        end

        if seenEncounterChoiceIds[choice.id] then
          return false, string.format("stageResults[%d].encounter.choices duplicates %s", index, tostring(choice.id))
        end

        seenEncounterChoiceIds[choice.id] = true
      end

      if #stageRecord.encounter.choices > 0 and stageRecord.encounterChoice == nil then
        local isPendingLatestEncounterSelection = index == #(history.stageResults or {})
        if not isPendingLatestEncounterSelection then
          return false, string.format("stageResults[%d] is missing encounterChoice despite encounter choices", index)
        end
      end

      if stageRecord.encounterChoice ~= nil then
        local okChoice, choiceError = validateEncounterChoice(stageRecord.encounterChoice, string.format("stageResults[%d].encounterChoice", index))
        if not okChoice then
          return false, choiceError
        end

        if not seenEncounterChoiceIds[stageRecord.encounterChoice.id] then
          return false, string.format("stageResults[%d].encounterChoice is not present in encounter choices", index)
        end
      end
    elseif stageRecord.encounterChoice ~= nil then
      return false, string.format("stageResults[%d] has encounterChoice without encounter", index)
    end
  end

  for index, commit in ipairs(history.loadoutCommits or {}) do
    if not isPositiveInteger(commit.roundIndex) then
      return false, string.format("loadoutCommits[%d] requires positive integer roundIndex", index)
    end

    if type(commit.stageId) ~= "string" or commit.stageId == "" then
      return false, string.format("loadoutCommits[%d] missing stageId", index)
    end

    if type(commit.canonicalKey) ~= "string" then
      return false, string.format("loadoutCommits[%d] missing canonicalKey", index)
    end

    local slotCount = math.max(getMaxNumericIndex(commit.slots), #(commit.compactCoinIds or {}), runState.maxActiveCoinSlots)
    local ok, normalizedSlots = validateSlotState(commit.slots or {}, slotCount, nil, string.format("loadoutCommits[%d].slots", index), true)

    if not ok then
      return false, normalizedSlots
    end

    local expectedKey = Loadout.toCanonicalKey(normalizedSlots, slotCount)
    if expectedKey ~= commit.canonicalKey then
      return false, string.format("loadoutCommits[%d] canonicalKey mismatch", index)
    end
  end

  local previousBatchPerStage = {}
  local stageLastBatch = {}
  local activeStageKey = runState.currentStageId and string.format("%d:%s", runState.roundIndex, runState.currentStageId) or nil
  for index, batch in ipairs(history.flipBatches or {}) do
    local ok, errorMessage = validateBatchSnapshot(batch)

    if not ok then
      return false, string.format("flipBatches[%d] invalid: %s", index, errorMessage)
    end

    local stageKey = string.format("%d:%s", batch.roundIndex, batch.stageId)
    local previousBatchId = previousBatchPerStage[stageKey] or 0

    if batch.batchId <= previousBatchId then
      return false, string.format("flipBatches[%d] batchId %d is not strictly increasing for %s", index, batch.batchId, stageKey)
    end

    if not stageIndex[stageKey] and stageKey ~= activeStageKey then
      return false, string.format("flipBatches[%d] references unknown finalized stage key %s", index, stageKey)
    end

    previousBatchPerStage[stageKey] = batch.batchId
    stageLastBatch[stageKey] = batch
  end

  local successfulPurchases = 0
  local purchaseCursor = 1
  local previousVisitIndex = 0
  for index, visit in ipairs(history.shopVisits or {}) do
    if not isPositiveInteger(visit.visitIndex) then
      return false, string.format("shopVisits[%d] missing positive visitIndex", index)
    end

    if visit.visitIndex <= previousVisitIndex then
      return false, string.format("shopVisits[%d] visitIndex %d is not strictly increasing", index, visit.visitIndex)
    end

    previousVisitIndex = visit.visitIndex

    if not isPositiveInteger(visit.roundIndex) then
      return false, string.format("shopVisits[%d] missing positive roundIndex", index)
    end

    if type(visit.sourceStageId) ~= "string" or visit.sourceStageId == "" then
      return false, string.format("shopVisits[%d] missing sourceStageId", index)
    end

    local stageKey = string.format("%d:%s", visit.roundIndex, visit.sourceStageId)
    if not stageIndex[stageKey] then
      return false, string.format("shopVisits[%d] references unknown stage key %s", index, stageKey)
    end

    if stageIndex[stageKey].status ~= "cleared" then
      return false, string.format("shopVisits[%d] references uncleared stage %s", index, stageKey)
    end

    if stageIndex[stageKey].rewardOptions == nil then
      return false, string.format("shopVisits[%d] references stage %s without reward preview data", index, stageKey)
    end

    if stageIndex[stageKey].encounter == nil then
      return false, string.format("shopVisits[%d] references stage %s without encounter preview data", index, stageKey)
    end

    local encounterChoices = stageIndex[stageKey].encounter and stageIndex[stageKey].encounter.choices or {}
    if #encounterChoices > 0 and stageIndex[stageKey].encounterChoice == nil then
      return false, string.format("shopVisits[%d] references stage %s with incomplete encounter choice", index, stageKey)
    end

    if type(visit.actions) ~= "table" then
      return false, string.format("shopVisits[%d].actions must be a table", index)
    end

    if type(visit.offerSets) ~= "table" or type(visit.generationTraces) ~= "table" or type(visit.purchaseTraces) ~= "table" then
      return false, string.format("shopVisits[%d] is missing offer/trace history tables", index)
    end

    if #visit.offerSets ~= ((visit.rerollsUsed or 0) + 1) then
      return false, string.format("shopVisits[%d] offerSets count does not match reroll history", index)
    end

    if #visit.generationTraces ~= #visit.offerSets then
      return false, string.format("shopVisits[%d] generationTraces count does not match offerSets", index)
    end

    local rerollActionCount = 0
    local successCount = 0
    local failureCount = 0
    local visitPurchaseCursor = 1
    local visitFailureCursor = 1

    for actionIndex, action in ipairs(visit.actions or {}) do
      if action.type == "reroll" then
        rerollActionCount = rerollActionCount + 1
        if action.mode ~= nil and action.mode ~= "free" and action.mode ~= "paid" then
          return false, string.format("shopVisits[%d].actions[%d] has invalid reroll mode %s", index, actionIndex, tostring(action.mode))
        end
      elseif action.type == "purchase" then
        if action.outcome == "success" then
          successCount = successCount + 1

          local purchaseRecord = (visit.purchases or {})[visitPurchaseCursor]
          local historyRecord = (history.purchases or {})[purchaseCursor]

          if not purchaseRecord then
            return false, string.format("shopVisits[%d] missing purchase record for successful action %d", index, actionIndex)
          end

          if purchaseRecord.type ~= action.offerType or purchaseRecord.contentId ~= action.contentId then
            return false, string.format("shopVisits[%d] purchase record mismatch for successful action %d", index, actionIndex)
          end

          if action.finalPrice ~= nil and purchaseRecord.price ~= action.finalPrice then
            return false, string.format("shopVisits[%d] purchase price mismatch for successful action %d", index, actionIndex)
          end

          if not historyRecord then
            return false, string.format("runState.history.purchases missing entry for successful shop action %d", actionIndex)
          end

          if historyRecord.type ~= purchaseRecord.type or historyRecord.contentId ~= purchaseRecord.contentId or historyRecord.price ~= purchaseRecord.price then
            return false, string.format("runState.history.purchases mismatch for shopVisits[%d] action %d", index, actionIndex)
          end

          visitPurchaseCursor = visitPurchaseCursor + 1
          purchaseCursor = purchaseCursor + 1
        elseif action.outcome == "failure" then
          failureCount = failureCount + 1

          local failureRecord = (visit.purchaseFailures or {})[visitFailureCursor]
          if not failureRecord then
            return false, string.format("shopVisits[%d] missing failure record for failed action %d", index, actionIndex)
          end

          if failureRecord.type ~= action.offerType or failureRecord.contentId ~= action.contentId then
            return false, string.format("shopVisits[%d] failure record mismatch for action %d", index, actionIndex)
          end

          if action.reason ~= nil and failureRecord.reason ~= action.reason then
            return false, string.format("shopVisits[%d] failure reason mismatch for action %d", index, actionIndex)
          end

          visitFailureCursor = visitFailureCursor + 1
        else
          return false, string.format("shopVisits[%d].actions[%d] has invalid purchase outcome %s", index, actionIndex, tostring(action.outcome))
        end
      else
        return false, string.format("shopVisits[%d].actions[%d] has invalid action type %s", index, actionIndex, tostring(action.type))
      end
    end

    if rerollActionCount ~= (visit.rerollsUsed or 0) then
      return false, string.format("shopVisits[%d] rerollsUsed does not match reroll actions", index)
    end

    if successCount ~= #(visit.purchases or {}) then
      return false, string.format("shopVisits[%d] purchase success count mismatch", index)
    end

    if failureCount ~= #(visit.purchaseFailures or {}) then
      return false, string.format("shopVisits[%d] purchase failure count mismatch", index)
    end

    if #visit.purchaseTraces ~= (successCount + failureCount) then
      return false, string.format("shopVisits[%d] purchaseTraces count mismatch", index)
    end

    successfulPurchases = successfulPurchases + successCount
  end

  if successfulPurchases ~= #(history.purchases or {}) then
    return false, "runState.history.purchases does not match successful shop purchases"
  end

  for stageKey, stageRecord in pairs(stageIndex) do
    local finalBatch = stageLastBatch[stageKey]

    if finalBatch and finalBatch.trace then
      if finalBatch.trace.stageStatusAfter ~= stageRecord.status then
        return false, string.format("final batch status mismatch for stage %s", stageKey)
      end

      if finalBatch.trace.stageScoreAfter ~= stageRecord.stageScore then
        return false, string.format("final batch stageScore mismatch for stage %s", stageKey)
      end
    end
  end

  if runState.runStatus ~= "active" and #(history.stageResults or {}) > 0 then
    local finalStage = history.stageResults[#history.stageResults]
    if finalStage.runStatus ~= runState.runStatus then
      return false, "final stage runStatus does not match runState.runStatus"
    end
  end

  return true
end

function Validator.assertRuntimeInvariants(label, runState, stageState, options)
  options = options or {}

  local ok, errorMessage = Validator.validateRunState(runState)
  if not ok then
    error(string.format("Invariant violation [%s]: %s", tostring(label), errorMessage))
  end

  ok, errorMessage = Validator.validateStageState(runState, stageState)
  if not ok then
    error(string.format("Invariant violation [%s]: %s", tostring(label), errorMessage))
  end

  if options.batchResult then
    ok, errorMessage = Validator.validateBatchResult(runState, stageState, options.batchResult)
    if not ok then
      error(string.format("Invariant violation [%s]: %s", tostring(label), errorMessage))
    end
  end

  if options.shopOffers then
    ok, errorMessage = Validator.validateShopOffers(runState, options.shopOffers)
    if not ok then
      error(string.format("Invariant violation [%s]: %s", tostring(label), errorMessage))
    end
  end

  if options.history then
    ok, errorMessage = Validator.validateRunHistory(runState)
    if not ok then
      error(string.format("Invariant violation [%s]: %s", tostring(label), errorMessage))
    end
  end
end

function Validator.validateLoadoutSelection(runState, slots)
  local normalized = Loadout.normalizeSlots(slots, runState.maxActiveCoinSlots)

  if Loadout.countEquipped(normalized, runState.maxActiveCoinSlots) == 0 then
    return false, "at least one equipped coin is required"
  end

  local hasDuplicate, duplicateId = Loadout.containsDuplicateIds(normalized, runState.maxActiveCoinSlots)

  if hasDuplicate then
    return false, string.format("duplicate equipped coin: %s", duplicateId)
  end

  for slotIndex = 1, runState.maxActiveCoinSlots do
    local coinId = normalized[slotIndex]

    if coinId and not Utils.contains(runState.collectionCoinIds, coinId) then
      return false, string.format("coin is not owned: %s", coinId)
    end
  end

  return true, normalized
end

function Validator.reconcilePersistedLoadout(runState)
  return Loadout.reconcileSlotsDetailed(
    runState.persistedLoadoutSlots,
    runState.collectionCoinIds,
    runState.maxActiveCoinSlots
  )
end

function Validator.validateBatchInput(runState, stageState, call)
  if call ~= "heads" and call ~= "tails" then
    return false, "call must be heads or tails"
  end

  if not stageState or stageState.stageStatus ~= "active" then
    return false, "stage must be active"
  end

  if stageState.flipsRemaining <= 0 then
    return false, "no flips remain"
  end

  local resolutionOrder = PurseSystem.getResolutionOrder(runState, stageState)

  if #resolutionOrder == 0 then
    return false, "hand is empty"
  end

  return true, resolutionOrder
end

function Validator.validateContentDefinition(definition)
  if type(definition) ~= "table" then
    return false, "definition must be a table"
  end

  if type(definition.id) ~= "string" or definition.id == "" then
    return false, "definition.id is required"
  end

  if type(definition.name) ~= "string" or definition.name == "" then
    return false, string.format("definition %s is missing a name", definition.id)
  end

  if definition.unlockedByDefault ~= nil and type(definition.unlockedByDefault) ~= "boolean" then
    return false, string.format("definition %s unlockedByDefault must be boolean", definition.id)
  end

  local ok, errorMessage = validateCustomResolver(definition)

  if not ok then
    return false, errorMessage
  end

  ok, errorMessage = EffectiveValueSystem.validateEffectiveValuesTable(definition.effectiveValues)

  if not ok then
    return false, string.format("definition %s has invalid effectiveValues: %s", definition.id, errorMessage)
  end

  local allowedFlagKeys = collectConditionFlagKeysFromDefinition(definition)

  for _, trigger in ipairs(definition.triggers or {}) do
    if not HookRegistry.isValidPhase(trigger.hook) then
      return false, string.format("definition %s uses invalid hook %s", definition.id, tostring(trigger.hook))
    end

    ok, errorMessage = HookRegistry.validateCondition(trigger.condition, allowedFlagKeys, trigger.hook)

    if not ok then
      return false, string.format("definition %s has invalid condition: %s", definition.id, errorMessage)
    end

    for _, effect in ipairs(trigger.effects or {}) do
      ok, errorMessage = ActionQueue.validateAction(effect)

      if not ok then
        return false, string.format("definition %s has invalid effect: %s", definition.id, errorMessage)
      end

      if effect.op == "queue_actions" then
        local triggerOrder = HookRegistry.getPhaseOrder(trigger.hook)
        local targetOrder = HookRegistry.getPhaseOrder(effect.phase)

        if triggerOrder and targetOrder and targetOrder < triggerOrder then
          return false, string.format(
            "definition %s queues phase %s before enclosing phase %s",
            definition.id,
            tostring(effect.phase),
            tostring(trigger.hook)
          )
        end
      end
    end
  end

  for _, action in ipairs(definition.onAcquire or {}) do
    local ok, errorMessage = ActionQueue.validateAction(action)

    if not ok then
      return false, string.format("definition %s has invalid onAcquire action: %s", definition.id, errorMessage)
    end

    if not ActionQueue.isAcquisitionSafeAction(action) then
      return false, string.format("definition %s has onAcquire action that is not acquisition-safe: %s", definition.id, tostring(action.op))
    end
  end

  return true
end

function Validator.validateContentRegistry(registryName, definitions)
  local seenIds = {}

  for _, definition in ipairs(definitions or {}) do
    local ok, errorMessage = Validator.validateContentDefinition(definition)

    if not ok then
      return false, string.format("%s registry error: %s", registryName, errorMessage)
    end

    if seenIds[definition.id] then
      return false, string.format("%s registry has duplicate id %s", registryName, definition.id)
    end

    seenIds[definition.id] = true
  end

  if registryName == "stages" then
    local Bosses = require("src.content.bosses")
    local StageModifiers = require("src.content.stage_modifiers")
    local expectedRounds = GameConfig.totalStageCount()
    local seenRounds = {}
    local seenBossVariantIds = {}
    local seenStageVariantIds = {}

    for _, definition in ipairs(definitions or {}) do
      if type(definition.roundIndex) ~= "number" then
        return false, string.format("stages registry error: %s is missing numeric roundIndex", definition.id)
      end

      if type(definition.label) ~= "string" or definition.label == "" then
        return false, string.format("stages registry error: %s is missing label", definition.id)
      end

      if type(definition.targetScore) ~= "number" then
        return false, string.format("stages registry error: %s is missing targetScore", definition.id)
      end

      if definition.activeStageModifierIds ~= nil and type(definition.activeStageModifierIds) ~= "table" then
        return false, string.format("stages registry error: %s has non-table activeStageModifierIds", definition.id)
      end

      if definition.bossModifierIds ~= nil and type(definition.bossModifierIds) ~= "table" then
        return false, string.format("stages registry error: %s has non-table bossModifierIds", definition.id)
      end

      if definition.bossVariants ~= nil and type(definition.bossVariants) ~= "table" then
        return false, string.format("stages registry error: %s has non-table bossVariants", definition.id)
      end

      if definition.variants ~= nil and type(definition.variants) ~= "table" then
        return false, string.format("stages registry error: %s has non-table variants", definition.id)
      end

      if definition.bossVariants ~= nil and definition.stageType ~= "boss" then
        return false, string.format("stages registry error: %s defines bossVariants on a non-boss stage", definition.id)
      end

      if definition.variants ~= nil and definition.stageType == "boss" then
        return false, string.format("stages registry error: %s defines variants on a boss stage", definition.id)
      end

      if definition.bossModifierId and definition.bossModifierIds then
        return false, string.format("stages registry error: %s must not define both bossModifierId and bossModifierIds", definition.id)
      end

      if definition.stageType == "boss"
        and not definition.bossModifierId
        and #(definition.bossModifierIds or {}) == 0
        and #(definition.bossVariants or {}) == 0 then
        return false, string.format("stages registry error: %s boss stage must define bossModifierIds or bossVariants", definition.id)
      end

      if seenRounds[definition.roundIndex] then
        return false, string.format("stages registry error: duplicate roundIndex %s", definition.roundIndex)
      end

      seenRounds[definition.roundIndex] = true

      for _, modifierId in ipairs(definition.activeStageModifierIds or {}) do
        if not StageModifiers.getById(modifierId) then
          return false, string.format("stages registry error: %s references missing stage modifier %s", definition.id, modifierId)
        end
      end

      for _, modifierId in ipairs(definition.bossModifierIds or {}) do
        if not Bosses.getById(modifierId) then
          return false, string.format("stages registry error: %s references missing boss modifier %s", definition.id, modifierId)
        end
      end

      local seenVariantIds = {}
      for variantIndex, variant in ipairs(definition.variants or {}) do
        if type(variant) ~= "table" then
          return false, string.format("stages registry error: %s variants[%d] must be a table", definition.id, variantIndex)
        end

        if type(variant.id) ~= "string" or variant.id == "" then
          return false, string.format("stages registry error: %s variants[%d] is missing id", definition.id, variantIndex)
        end

        if seenVariantIds[variant.id] then
          return false, string.format("stages registry error: %s has duplicate stage variant id %s", definition.id, variant.id)
        end

        if seenIds[variant.id] or seenStageVariantIds[variant.id] or seenBossVariantIds[variant.id] then
          return false, string.format("stages registry error: duplicate stage variant id %s", variant.id)
        end

        seenVariantIds[variant.id] = true
        seenStageVariantIds[variant.id] = true

        if type(variant.name) ~= "string" or variant.name == "" then
          return false, string.format("stages registry error: %s variants[%d] is missing name", definition.id, variantIndex)
        end

        if type(variant.label) ~= "string" or variant.label == "" then
          return false, string.format("stages registry error: %s variants[%d] is missing label", definition.id, variantIndex)
        end

        if variant.targetScore ~= nil and type(variant.targetScore) ~= "number" then
          return false, string.format("stages registry error: %s variants[%d] has non-numeric targetScore", definition.id, variantIndex)
        end

        if type(variant.activeStageModifierIds) ~= "table" or #variant.activeStageModifierIds == 0 then
          return false, string.format("stages registry error: %s variants[%d] must define activeStageModifierIds", definition.id, variantIndex)
        end

        for _, modifierId in ipairs(variant.activeStageModifierIds) do
          if not StageModifiers.getById(modifierId) then
            return false, string.format("stages registry error: %s stage variant %s references missing stage modifier %s", definition.id, variant.id, modifierId)
          end
        end
      end

      for variantIndex, variant in ipairs(definition.bossVariants or {}) do
        if type(variant) ~= "table" then
          return false, string.format("stages registry error: %s bossVariants[%d] must be a table", definition.id, variantIndex)
        end

        if type(variant.id) ~= "string" or variant.id == "" then
          return false, string.format("stages registry error: %s bossVariants[%d] is missing id", definition.id, variantIndex)
        end

        if seenVariantIds[variant.id] then
          return false, string.format("stages registry error: %s has duplicate boss variant id %s", definition.id, variant.id)
        end

        if seenIds[variant.id] or seenBossVariantIds[variant.id] then
          return false, string.format("stages registry error: duplicate boss variant id %s", variant.id)
        end

        seenVariantIds[variant.id] = true
        seenBossVariantIds[variant.id] = true

        if type(variant.name) ~= "string" or variant.name == "" then
          return false, string.format("stages registry error: %s bossVariants[%d] is missing name", definition.id, variantIndex)
        end

        if type(variant.label) ~= "string" or variant.label == "" then
          return false, string.format("stages registry error: %s bossVariants[%d] is missing label", definition.id, variantIndex)
        end

        if type(variant.bossModifierIds) ~= "table" or #variant.bossModifierIds == 0 then
          return false, string.format("stages registry error: %s bossVariants[%d] must define bossModifierIds", definition.id, variantIndex)
        end

        for _, modifierId in ipairs(variant.bossModifierIds) do
          if not Bosses.getById(modifierId) then
            return false, string.format("stages registry error: %s boss variant %s references missing boss modifier %s", definition.id, variant.id, modifierId)
          end
        end
      end

      if definition.bossModifierId and not Bosses.getById(definition.bossModifierId) then
        return false, string.format("stages registry error: %s references missing boss modifier %s", definition.id, definition.bossModifierId)
      end
    end

    for roundIndex = 1, expectedRounds do
      if not seenRounds[roundIndex] then
        return false, string.format("stages registry error: missing roundIndex %s", roundIndex)
      end
    end
  elseif registryName == "meta_upgrades" then
    for _, definition in ipairs(definitions or {}) do
      if type(definition.cost) ~= "number" or definition.cost < 0 then
        return false, string.format("meta_upgrades registry error: %s is missing non-negative cost", definition.id)
      end

      if definition.runModifiers ~= nil and definition.effectiveValues ~= nil then
        return false, string.format("meta_upgrades registry error: %s must not define both runModifiers and effectiveValues", definition.id)
      end

      if definition.runModifiers == nil and definition.effectiveValues == nil
        and definition.unlockCoinIds == nil and definition.unlockUpgradeIds == nil then
        return false, string.format("meta_upgrades registry error: %s must define effectiveValues, runModifiers, unlockCoinIds, or unlockUpgradeIds", definition.id)
      end

      if definition.runModifiers ~= nil then
        if type(definition.runModifiers) ~= "table" then
          return false, string.format("meta_upgrades registry error: %s has non-table runModifiers", definition.id)
        end

        local ok, errorMessage = EffectiveValueSystem.validateLegacyModifierTable(definition.runModifiers)

        if not ok then
          return false, string.format("meta_upgrades registry error: %s has invalid runModifiers: %s", definition.id, errorMessage)
        end
      end

      if definition.effectiveValues ~= nil then
        local ok, errorMessage = EffectiveValueSystem.validateEffectiveValuesTable(definition.effectiveValues)

        if not ok then
          return false, string.format("meta_upgrades registry error: %s has invalid effectiveValues: %s", definition.id, errorMessage)
        end
      end

      if definition.unlockCoinIds ~= nil then
        if type(definition.unlockCoinIds) ~= "table" then
          return false, string.format("meta_upgrades registry error: %s unlockCoinIds must be a table", definition.id)
        end

        local ok, errorMessage = validateIdList(definition.unlockCoinIds, string.format("meta_upgrades %s unlockCoinIds", definition.id), require("src.content.coins").getById)

        if not ok then
          return false, errorMessage
        end
      end

      if definition.unlockUpgradeIds ~= nil then
        if type(definition.unlockUpgradeIds) ~= "table" then
          return false, string.format("meta_upgrades registry error: %s unlockUpgradeIds must be a table", definition.id)
        end

        local ok, errorMessage = validateIdList(definition.unlockUpgradeIds, string.format("meta_upgrades %s unlockUpgradeIds", definition.id), require("src.content.upgrades").getById)

        if not ok then
          return false, errorMessage
        end
      end
    end
  end

  return true
end

return Validator
