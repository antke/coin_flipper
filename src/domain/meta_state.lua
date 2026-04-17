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

  local effectiveValues = {}
  local modifiers = {}
  local stats = {}
  local normalizedUnlockedCoinIds = {}
  local normalizedUnlockedUpgradeIds = {}
  local unlockedCoinIndex = {}
  local unlockedUpgradeIndex = {}

  if sourceEffectiveValues then
    EffectiveValueSystem.mergeEffectiveValueTables(effectiveValues, sourceEffectiveValues)

    local purchasedEffectiveValues = {}

    for _, metaUpgradeId in ipairs(purchasedMetaUpgradeIds) do
      local definition = MetaUpgrades.getById(metaUpgradeId)

      if definition then
        EffectiveValueSystem.mergeEffectiveValueTables(
          purchasedEffectiveValues,
          EffectiveValueSystem.getDefinitionEffectiveValues(definition)
        )
      end
    end

    mergeMissingEffectiveValues(effectiveValues, purchasedEffectiveValues)
  else
    EffectiveValueSystem.mergeEffectiveValueTables(
      effectiveValues,
      EffectiveValueSystem.buildCanonicalEffectiveValuesFromLegacyModifiers(sourceModifiers)
    )

    for _, metaUpgradeId in ipairs(purchasedMetaUpgradeIds) do
      local definition = MetaUpgrades.getById(metaUpgradeId)

      if definition then
        EffectiveValueSystem.mergeEffectiveValueTables(
          effectiveValues,
          EffectiveValueSystem.getDefinitionEffectiveValues(definition)
        )
      end
    end
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
    effectiveValues = effectiveValues,
    modifiers = modifiers,
    stats = stats,
  }
end

return MetaState
