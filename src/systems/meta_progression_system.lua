local EffectiveValueSystem = require("src.systems.effective_value_system")
local MetaUpgrades = require("src.content.meta_upgrades")
local Utils = require("src.core.utils")

local MetaProgressionSystem = {}

local function appendUniqueIds(target, values)
  local index = {}

  for _, value in ipairs(target or {}) do
    index[value] = true
  end

  for _, value in ipairs(values or {}) do
    if type(value) == "string" and value ~= "" and not index[value] then
      index[value] = true
      table.insert(target, value)
    end
  end
end

function MetaProgressionSystem.getUpgradeOptions(metaState)
  local options = {}

  for _, definition in ipairs(MetaUpgrades.getAll()) do
    local purchased = Utils.contains(metaState.purchasedMetaUpgradeIds, definition.id)
    local effectiveValues = EffectiveValueSystem.getDefinitionEffectiveValues(definition)

    table.insert(options, {
      id = definition.id,
      name = definition.name,
      description = definition.description,
      cost = definition.cost or 0,
      tags = definition.tags or {},
      effectiveValues = effectiveValues,
      runModifiers = EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(effectiveValues, {}),
      unlockCoinIds = Utils.copyArray(definition.unlockCoinIds or {}),
      unlockUpgradeIds = Utils.copyArray(definition.unlockUpgradeIds or {}),
      purchased = purchased,
      affordable = purchased or (metaState.metaPoints >= (definition.cost or 0)),
    })
  end

  return options
end

function MetaProgressionSystem.canPurchase(metaState, metaUpgradeId)
  local definition = MetaUpgrades.getById(metaUpgradeId)

  if not definition then
    return false, "unknown_meta_upgrade"
  end

  if Utils.contains(metaState.purchasedMetaUpgradeIds, metaUpgradeId) then
    return false, "already_purchased"
  end

  if metaState.metaPoints < (definition.cost or 0) then
    return false, "not_enough_meta_points"
  end

  return true, definition
end

function MetaProgressionSystem.purchase(metaState, metaUpgradeId)
  local ok, result = MetaProgressionSystem.canPurchase(metaState, metaUpgradeId)

  if not ok then
    return false, result
  end

  metaState.metaPoints = metaState.metaPoints - (result.cost or 0)
  table.insert(metaState.purchasedMetaUpgradeIds, metaUpgradeId)
  EffectiveValueSystem.mergeEffectiveValueTables(metaState.effectiveValues, EffectiveValueSystem.getDefinitionEffectiveValues(result))
  metaState.modifiers = EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(metaState.effectiveValues, {})
  appendUniqueIds(metaState.unlockedCoinIds, result.unlockCoinIds)
  appendUniqueIds(metaState.unlockedUpgradeIds, result.unlockUpgradeIds)
  return true, result
end

function MetaProgressionSystem.calculateRunReward(runState, stageRecord)
  local reward = 1

  if runState then
    reward = reward + math.floor((runState.runTotalScore or 0) / 12)
  end

  if stageRecord and stageRecord.stageType == "boss" and stageRecord.status == "cleared" then
    reward = reward + 1
  end

  if stageRecord and stageRecord.runStatus == "won" then
    reward = reward + 1
  end

  return math.max(1, reward)
end

function MetaProgressionSystem.grantRunCompletionReward(metaState, runState, stageRecord)
  if not runState or runState.metaRewardGranted then
    return 0
  end

  local reward = MetaProgressionSystem.calculateRunReward(runState, stageRecord)
  runState.metaRewardGranted = true
  runState.metaRewardEarned = reward
  metaState.metaPoints = (metaState.metaPoints or 0) + reward
  metaState.lifetimeMetaPointsEarned = (metaState.lifetimeMetaPointsEarned or 0) + reward

  return reward
end

return MetaProgressionSystem
