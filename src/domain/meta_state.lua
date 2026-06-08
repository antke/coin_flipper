local EffectiveValueSystem = require("src.systems.effective_value_system")
local MetaUpgrades = require("src.content.meta_upgrades")
local Utils = require("src.core.utils")

local MetaState = {}

local DEFAULT_MODIFIERS = {
  shopPointMultiplier = 1.0,
  bonusStartingCoins = 0,
  bonusCoinSlots = 0,
  bonusRerolls = 0,
  startingShopPoints = 0,
}

local DEFAULT_STATS = {
  runsStarted = 0,
  runsWon = 0,
  bestRunScore = 0,
  bossesDefeated = 0,
}

local function appendUniqueIds(target, index, values)
  for _, value in ipairs(values or {}) do
    if type(value) == "string" and value ~= "" and not index[value] then
      index[value] = true
      table.insert(target, value)
    end
  end
end

local function mergeMissingEffectiveValues(target, source)
  for key, value in pairs(source or {}) do
    if target[key] == nil then
      target[key] = Utils.clone(value)
    end
  end
end

local function getTattooLoadoutLimit(options)
  local limit = tonumber(options and options.tattooLoadoutLimit)

  if not limit then
    limit = MetaUpgrades.getEquipLimit()
  end

  return math.max(0, math.floor(limit))
end

local function appendEquippedTattooId(target, equippedIndex, purchasedIndex, metaUpgradeId, limit)
  if #target >= limit or equippedIndex[metaUpgradeId] or not purchasedIndex[metaUpgradeId] then
    return
  end

  local definition = MetaUpgrades.getById(metaUpgradeId)
  if not MetaUpgrades.isEquipEligible(definition) then
    return
  end

  equippedIndex[metaUpgradeId] = true
  table.insert(target, metaUpgradeId)
end

local function normalizeEquippedTattooIds(sourceEquippedTattooIds, purchasedMetaUpgradeIds, tattooLoadoutLimit)
  local purchasedIndex = {}
  local equippedIndex = {}
  local equippedTattooIds = {}

  for _, metaUpgradeId in ipairs(purchasedMetaUpgradeIds or {}) do
    purchasedIndex[metaUpgradeId] = true
  end

  if type(sourceEquippedTattooIds) == "table" then
    for _, metaUpgradeId in ipairs(sourceEquippedTattooIds) do
      appendEquippedTattooId(equippedTattooIds, equippedIndex, purchasedIndex, metaUpgradeId, tattooLoadoutLimit)
    end
  else
    for _, metaUpgradeId in ipairs(purchasedMetaUpgradeIds or {}) do
      appendEquippedTattooId(equippedTattooIds, equippedIndex, purchasedIndex, metaUpgradeId, tattooLoadoutLimit)
    end
  end

  return equippedTattooIds
end

local function buildEquippedTattooEffectiveValues(equippedTattooIds)
  local effectiveValues = {}

  for _, metaUpgradeId in ipairs(equippedTattooIds or {}) do
    local definition = MetaUpgrades.getById(metaUpgradeId)

    if definition then
      EffectiveValueSystem.mergeEffectiveValueTables(
        effectiveValues,
        EffectiveValueSystem.getDefinitionEffectiveValues(definition)
      )
    end
  end

  return effectiveValues
end

function MetaState.new(options)
  if type(options) ~= "table" then
    options = {}
  end

  local sourceModifiers = type(options.modifiers) == "table" and options.modifiers or {}
  local sourceEffectiveValues = type(options.effectiveValues) == "table" and options.effectiveValues or nil
  local sourceStats = type(options.stats) == "table" and options.stats or {}
  local unlockedCoinIds = type(options.unlockedCoinIds) == "table" and options.unlockedCoinIds or {}
  local unlockedUpgradeIds = type(options.unlockedUpgradeIds) == "table" and options.unlockedUpgradeIds or {}
  local purchasedMetaUpgradeIds = type(options.purchasedMetaUpgradeIds) == "table" and options.purchasedMetaUpgradeIds or {}
  local sourceEquippedTattooIds = type(options.equippedTattooIds) == "table" and options.equippedTattooIds or nil
  local tattooLoadoutLimit = getTattooLoadoutLimit(options)
  local equippedTattooIds = normalizeEquippedTattooIds(sourceEquippedTattooIds, purchasedMetaUpgradeIds, tattooLoadoutLimit)

  local effectiveValues = buildEquippedTattooEffectiveValues(equippedTattooIds)
  local modifiers = {}
  local stats = {}
  local normalizedUnlockedCoinIds = {}
  local normalizedUnlockedUpgradeIds = {}
  local unlockedCoinIndex = {}
  local unlockedUpgradeIndex = {}

  if sourceEffectiveValues and #purchasedMetaUpgradeIds == 0 then
    EffectiveValueSystem.mergeEffectiveValueTables(effectiveValues, sourceEffectiveValues)
  elseif not sourceEffectiveValues then
    EffectiveValueSystem.mergeEffectiveValueTables(
      effectiveValues,
      EffectiveValueSystem.buildCanonicalEffectiveValuesFromLegacyModifiers(sourceModifiers)
    )
  end

  modifiers = EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(effectiveValues, DEFAULT_MODIFIERS)

  appendUniqueIds(normalizedUnlockedCoinIds, unlockedCoinIndex, unlockedCoinIds)
  appendUniqueIds(normalizedUnlockedUpgradeIds, unlockedUpgradeIndex, unlockedUpgradeIds)

  for _, metaUpgradeId in ipairs(purchasedMetaUpgradeIds) do
    local definition = MetaUpgrades.getById(metaUpgradeId)

    if definition then
      appendUniqueIds(normalizedUnlockedCoinIds, unlockedCoinIndex, definition.unlockCoinIds)
      appendUniqueIds(normalizedUnlockedUpgradeIds, unlockedUpgradeIndex, definition.unlockUpgradeIds)
    end
  end

  for key, defaultValue in pairs(DEFAULT_STATS) do
    if sourceStats[key] ~= nil then
      stats[key] = sourceStats[key]
    else
      stats[key] = defaultValue
    end
  end

  return {
    metaPoints = tonumber(options.metaPoints) or 0,
    lifetimeMetaPointsEarned = tonumber(options.lifetimeMetaPointsEarned) or 0,
    unlockedCoinIds = normalizedUnlockedCoinIds,
    unlockedUpgradeIds = normalizedUnlockedUpgradeIds,
    purchasedMetaUpgradeIds = Utils.copyArray(purchasedMetaUpgradeIds),
    equippedTattooIds = Utils.copyArray(equippedTattooIds),
    tattooLoadoutLimit = tattooLoadoutLimit,
    runRecords = Utils.clone(type(options.runRecords) == "table" and options.runRecords or {}),
    effectiveValues = effectiveValues,
    modifiers = modifiers,
    stats = stats,
  }
end

return MetaState
