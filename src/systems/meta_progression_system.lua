local EffectiveValueSystem = require("src.systems.effective_value_system")
local MetaProgressionContent = require("src.content.meta_progression")
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

local function rebuildEquippedTattooEffects(metaState)
  metaState.effectiveValues = {}

  for _, metaUpgradeId in ipairs(metaState.equippedTattooIds or {}) do
    local definition = MetaUpgrades.getById(metaUpgradeId)

    if definition then
      EffectiveValueSystem.mergeEffectiveValueTables(metaState.effectiveValues, EffectiveValueSystem.getDefinitionEffectiveValues(definition))
    end
  end

  metaState.modifiers = EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(metaState.effectiveValues, {})
end

function MetaProgressionSystem.getUpgradeOptions(metaState)
  local options = {}

  for _, definition in ipairs(MetaUpgrades.getAll()) do
    local purchased = Utils.contains(metaState.purchasedMetaUpgradeIds, definition.id)
    local equipped = Utils.contains(metaState.equippedTattooIds, definition.id)
    local equipEligible = MetaUpgrades.isEquipEligible(definition)
    local effectiveValues = EffectiveValueSystem.getDefinitionEffectiveValues(definition)
    local equippedCount = #(metaState.equippedTattooIds or {})
    local tattooLoadoutLimit = metaState.tattooLoadoutLimit or MetaUpgrades.getEquipLimit()

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
      tattoo = Utils.clone(definition.tattoo),
      purchased = purchased,
      equipped = equipped,
      equipEligible = equipEligible,
      tattooLoadoutLimit = tattooLoadoutLimit,
      equippedCount = equippedCount,
      canEquip = purchased and equipEligible and not equipped and equippedCount < tattooLoadoutLimit,
      canUnequip = equipped,
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

  metaState.equippedTattooIds = metaState.equippedTattooIds or {}

  if MetaUpgrades.isEquipEligible(result) and #metaState.equippedTattooIds < (metaState.tattooLoadoutLimit or MetaUpgrades.getEquipLimit()) then
    table.insert(metaState.equippedTattooIds, metaUpgradeId)
  end

  rebuildEquippedTattooEffects(metaState)
  appendUniqueIds(metaState.unlockedCoinIds, result.unlockCoinIds)
  appendUniqueIds(metaState.unlockedUpgradeIds, result.unlockUpgradeIds)
  return true, result
end

function MetaProgressionSystem.canEquipTattoo(metaState, metaUpgradeId)
  local definition = MetaUpgrades.getById(metaUpgradeId)

  if not definition then
    return false, "unknown_meta_upgrade"
  end

  if not Utils.contains(metaState.purchasedMetaUpgradeIds, metaUpgradeId) then
    return false, "not_purchased"
  end

  if not MetaUpgrades.isEquipEligible(definition) then
    return false, "tattoo_not_equip_eligible"
  end

  if Utils.contains(metaState.equippedTattooIds, metaUpgradeId) then
    return false, "already_equipped"
  end

  if #(metaState.equippedTattooIds or {}) >= (metaState.tattooLoadoutLimit or MetaUpgrades.getEquipLimit()) then
    return false, "tattoo_loadout_full"
  end

  return true, definition
end

function MetaProgressionSystem.equipTattoo(metaState, metaUpgradeId)
  local ok, result = MetaProgressionSystem.canEquipTattoo(metaState, metaUpgradeId)

  if not ok then
    return false, result
  end

  metaState.equippedTattooIds = metaState.equippedTattooIds or {}
  table.insert(metaState.equippedTattooIds, metaUpgradeId)
  rebuildEquippedTattooEffects(metaState)
  return true, result
end

function MetaProgressionSystem.unequipTattoo(metaState, metaUpgradeId)
  metaState.equippedTattooIds = metaState.equippedTattooIds or {}

  if not Utils.contains(metaState.equippedTattooIds, metaUpgradeId) then
    return false, "not_equipped"
  end

  Utils.removeValue(metaState.equippedTattooIds, metaUpgradeId)
  rebuildEquippedTattooEffects(metaState)
  return true, MetaUpgrades.getById(metaUpgradeId)
end

function MetaProgressionSystem.calculateRunReward(runState, stageRecord)
  return MetaProgressionContent.calculateRunReward(runState, stageRecord)
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
