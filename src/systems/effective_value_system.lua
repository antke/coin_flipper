local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local Utils = require("src.core.utils")

local EffectiveValueSystem = {}

EffectiveValueSystem.KNOWN_KEYS = {
  ["run.startingCollectionSize"] = {
    defaultMode = "add",
    basePath = "run.startingCollectionSize",
    integer = true,
    min = 0,
  },
  ["run.maxActiveCoinSlots"] = {
    defaultMode = "add",
    basePath = "run.startingCoinSlots",
    integer = true,
    min = 1,
  },
  ["stage.flipsPerStage"] = {
    defaultMode = "override",
    basePath = "run.startingFlipsPerStage",
    integer = true,
    min = 1,
  },
  ["purse.handSize"] = {
    defaultMode = "override",
    basePath = "purse.handSize",
    integer = true,
    min = 1,
  },
  ["run.startingShopPoints"] = {
    defaultMode = "add",
    basePath = "economy.startingShopPoints",
    integer = true,
    min = 0,
  },
  ["run.startingShopRerolls"] = {
    defaultMode = "add",
    basePath = "economy.startingShopRerolls",
    integer = true,
    min = 0,
  },
  ["economy.shopPointMultiplier"] = {
    defaultMode = "multiply",
    basePath = "economy.shopPointMultiplier",
    min = 0,
  },
  ["shop.offerCount"] = {
    defaultMode = "override",
    basePath = "shop.offerCount",
    integer = true,
    min = 0,
  },
  ["shop.guaranteedCoinOffers"] = {
    defaultMode = "override",
    basePath = "shop.guaranteedCoinOffers",
    integer = true,
    min = 0,
  },
  ["shop.guaranteedUpgradeOffers"] = {
    defaultMode = "override",
    basePath = "shop.guaranteedUpgradeOffers",
    integer = true,
    min = 0,
  },
  ["shop.rerollCost"] = {
    defaultMode = "override",
    basePath = "shop.rerollCost",
    integer = true,
    min = 0,
  },
  ["shop.rarityWeight.common"] = {
    defaultMode = "multiply",
    basePath = "shop.rarityWeights.common",
    min = 0,
  },
  ["shop.rarityWeight.uncommon"] = {
    defaultMode = "multiply",
    basePath = "shop.rarityWeights.uncommon",
    min = 0,
  },
  ["shop.rarityWeight.rare"] = {
    defaultMode = "multiply",
    basePath = "shop.rarityWeights.rare",
    min = 0,
  },
  ["flip.baseHeadsWeight"] = {
    defaultMode = "override",
    basePath = "flip.baseHeadsWeight",
    min = 0,
  },
  ["flip.baseTailsWeight"] = {
    defaultMode = "override",
    basePath = "flip.baseTailsWeight",
    min = 0,
  },
}

EffectiveValueSystem.LEGACY_MODIFIER_ALIASES = {
  shopPointMultiplier = {
    path = "economy.shopPointMultiplier",
    mode = "multiply",
  },
  bonusStartingCoins = {
    path = "run.startingCollectionSize",
    mode = "add",
  },
  bonusCoinSlots = {
    path = "run.maxActiveCoinSlots",
    mode = "add",
  },
  bonusRerolls = {
    path = "run.startingShopRerolls",
    mode = "add",
  },
  startingShopPoints = {
    path = "run.startingShopPoints",
    mode = "add",
  },
}

EffectiveValueSystem.BOOTSTRAP_RESOLVED_VALUE_ALIASES = {
  ["run.startingCollectionSize"] = { "startingCollectionSize" },
  ["run.maxActiveCoinSlots"] = { "maxActiveCoinSlots" },
  ["stage.flipsPerStage"] = { "baseFlipsPerStage" },
  ["purse.handSize"] = { "handSize" },
  ["run.startingShopPoints"] = { "startingShopPoints" },
  ["run.startingShopRerolls"] = { "startingShopRerolls" },
}

local function normalizeInteger(value)
  if value >= 0 then
    return math.floor(value + 0.00001)
  end

  return math.ceil(value - 0.00001)
end

local function getActiveBossModifierIds(stageDefinition)
  if stageDefinition and type(stageDefinition.bossModifierIds) == "table" then
    return Utils.copyArray(stageDefinition.bossModifierIds)
  end

  if stageDefinition and stageDefinition.bossModifierId then
    return { stageDefinition.bossModifierId }
  end

  return {}
end

local function buildStageSourceState(stageState, stageDefinition)
  if stageState then
    return stageState
  end

  if not stageDefinition then
    return nil
  end

  return {
    stageType = stageDefinition.stageType or "normal",
    activeStageModifierIds = Utils.copyArray(stageDefinition.activeStageModifierIds or {}),
    activeBossModifierIds = getActiveBossModifierIds(stageDefinition),
    effectiveValues = Utils.clone(stageDefinition.effectiveValues or {}),
  }
end

local function normalizeEntry(path, rawValue)
  local keyDefinition = EffectiveValueSystem.KNOWN_KEYS[path]

  if not keyDefinition then
    return nil, string.format("unknown effective value key: %s", tostring(path))
  end

  if type(rawValue) == "number" then
    return {
      mode = keyDefinition.defaultMode,
      value = rawValue,
    }
  end

  if type(rawValue) == "table" then
    if rawValue.mode ~= nil and rawValue.mode ~= "add" and rawValue.mode ~= "multiply" and rawValue.mode ~= "override" then
      return nil, string.format("effective value %s has invalid mode %s", path, tostring(rawValue.mode))
    end

    if type(rawValue.value) ~= "number" then
      return nil, string.format("effective value %s requires numeric value", path)
    end

    return {
      mode = rawValue.mode or keyDefinition.defaultMode,
      value = rawValue.value,
    }
  end

  return nil, string.format("effective value %s must be numeric or { mode, value }", path)
end

local function applyEntry(currentValue, entry)
  if entry.mode == "add" then
    return currentValue + entry.value
  end

  if entry.mode == "multiply" then
    return currentValue * entry.value
  end

  return entry.value
end

local function finalizeValue(path, value)
  local keyDefinition = EffectiveValueSystem.KNOWN_KEYS[path]

  if keyDefinition.integer then
    value = normalizeInteger(value)
  end

  if keyDefinition.min ~= nil then
    value = math.max(keyDefinition.min, value)
  end

  if keyDefinition.max ~= nil then
    value = math.min(keyDefinition.max, value)
  end

  return value
end

local function getBaseValue(path)
  local keyDefinition = EffectiveValueSystem.KNOWN_KEYS[path]
  return GameConfig.get(keyDefinition.basePath)
end

local function getSourceEffectiveValue(source, path)
  if not source or not source.definition or type(source.definition.effectiveValues) ~= "table" then
    return nil
  end

  return source.definition.effectiveValues[path]
end

local function applyLegacyModifierValue(currentValue, key, value)
  local aliasDefinition = EffectiveValueSystem.LEGACY_MODIFIER_ALIASES[key]

  if aliasDefinition and aliasDefinition.mode == "multiply" then
    return (currentValue or 1.0) * value
  end

  if type(value) == "number" then
    return (currentValue or 0) + value
  end

  return value
end

local function mergeEntryIntoTable(target, path, rawValue)
  local entry, errorMessage = normalizeEntry(path, rawValue)
  assert(entry, errorMessage)

  local existingRawValue = target[path]
  if existingRawValue == nil then
    target[path] = Utils.clone(entry)
    return
  end

  local existingEntry, existingError = normalizeEntry(path, existingRawValue)
  assert(existingEntry, existingError)

  if existingEntry.mode == entry.mode then
    if entry.mode == "add" then
      target[path] = {
        mode = "add",
        value = existingEntry.value + entry.value,
      }
      return
    end

    if entry.mode == "multiply" then
      target[path] = {
        mode = "multiply",
        value = existingEntry.value * entry.value,
      }
      return
    end

    target[path] = Utils.clone(entry)
    return
  end

  local collapsedValue = applyEntry(applyEntry(getBaseValue(path), existingEntry), entry)
  target[path] = {
    mode = "override",
    value = finalizeValue(path, collapsedValue),
  }
end

local function getResolvedBootstrapOverride(options, key)
  if type(options.resolvedValues) ~= "table" then
    return nil
  end

  if options.resolvedValues[key] ~= nil then
    return options.resolvedValues[key]
  end

  for _, aliasKey in ipairs(EffectiveValueSystem.BOOTSTRAP_RESOLVED_VALUE_ALIASES[key] or {}) do
    if options.resolvedValues[aliasKey] ~= nil then
      return options.resolvedValues[aliasKey]
    end
  end

  return nil
end

function EffectiveValueSystem.buildCanonicalEffectiveValuesFromLegacyModifiers(modifierTable)
  local effectiveValues = {}

  for alias, aliasDefinition in pairs(EffectiveValueSystem.LEGACY_MODIFIER_ALIASES) do
    local value = modifierTable and modifierTable[alias] or nil

    if type(value) == "number" then
      mergeEntryIntoTable(effectiveValues, aliasDefinition.path, {
        mode = aliasDefinition.mode,
        value = value,
      })
    end
  end

  return effectiveValues
end

function EffectiveValueSystem.mergeEffectiveValueTables(target, sourceValues)
  target = target or {}

  for path, rawValue in pairs(sourceValues or {}) do
    mergeEntryIntoTable(target, path, rawValue)
  end

  return target
end

function EffectiveValueSystem.getDefinitionEffectiveValues(definition)
  local effectiveValues = {}

  if type(definition and definition.effectiveValues) == "table" then
    EffectiveValueSystem.mergeEffectiveValueTables(effectiveValues, definition.effectiveValues)
  end

  if type(definition and definition.runModifiers) == "table" then
    EffectiveValueSystem.mergeEffectiveValueTables(
      effectiveValues,
      EffectiveValueSystem.buildCanonicalEffectiveValuesFromLegacyModifiers(definition.runModifiers)
    )
  end

  return effectiveValues
end

function EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(effectiveValues, baseModifiers)
  local modifiers = Utils.clone(baseModifiers or {})

  for alias, aliasDefinition in pairs(EffectiveValueSystem.LEGACY_MODIFIER_ALIASES) do
    local baseValue = modifiers[alias]

    if baseValue == nil then
      baseValue = aliasDefinition.mode == "multiply" and 1.0 or 0
    end

    local rawValue = effectiveValues and effectiveValues[aliasDefinition.path] or nil

    if rawValue ~= nil then
      local entry, errorMessage = normalizeEntry(aliasDefinition.path, rawValue)
      assert(entry, errorMessage)
      modifiers[alias] = applyEntry(baseValue, entry)
    else
      modifiers[alias] = baseValue
    end
  end

  return modifiers
end

function EffectiveValueSystem.validateLegacyModifierTable(modifierTable)
  for key, value in pairs(modifierTable or {}) do
    local aliasDefinition = EffectiveValueSystem.LEGACY_MODIFIER_ALIASES[key]

    if not aliasDefinition then
      return false, string.format("unknown runModifier alias: %s", tostring(key))
    end

    if type(value) ~= "number" then
      return false, string.format("runModifier %s must be numeric", tostring(key))
    end
  end

  return true
end

function EffectiveValueSystem.validateEffectiveValuesTable(effectiveValues)
  if effectiveValues == nil then
    return true
  end

  if type(effectiveValues) ~= "table" then
    return false, "effectiveValues must be a table"
  end

  for path, rawValue in pairs(effectiveValues) do
    local _, errorMessage = normalizeEntry(path, rawValue)

    if errorMessage then
      return false, errorMessage
    end
  end

  return true
end

function EffectiveValueSystem.getEffectiveValue(path, runState, stageState, context)
  local keyDefinition = EffectiveValueSystem.KNOWN_KEYS[path]

  if not keyDefinition then
    error(string.format("Unknown effective value key: %s", tostring(path)))
  end

  context = context or {}

  local value = getBaseValue(path)
  local metaProjection = context.metaProjection or (runState and runState.metaProjection) or nil
  local stageDefinition = context.stageDefinition
  local sourceStageState = buildStageSourceState(stageState, stageDefinition)
  local sourceList = context.activeSources or context.sources or HookRegistry.collectSources(runState, sourceStageState, metaProjection)
  local stageEffectiveValues = stageState and stageState.effectiveValues or (stageDefinition and stageDefinition.effectiveValues) or nil

  if stageEffectiveValues and stageEffectiveValues[path] ~= nil then
    local entry, errorMessage = normalizeEntry(path, stageEffectiveValues[path])
    assert(entry, errorMessage)
    value = applyEntry(value, entry)
  end

  if path == "stage.flipsPerStage" and stageDefinition and stageDefinition.flipsPerStage ~= nil then
    value = stageDefinition.flipsPerStage
  end

  for _, source in ipairs(sourceList or {}) do
    local rawValue = getSourceEffectiveValue(source, path)

    if rawValue ~= nil then
      local entry, errorMessage = normalizeEntry(path, rawValue)
      assert(entry, errorMessage)
      value = applyEntry(value, entry)
    end
  end

  return finalizeValue(path, value)
end

function EffectiveValueSystem.getBaseCoinWeights(runState, stageState, context)
  local headsWeight = EffectiveValueSystem.getEffectiveValue("flip.baseHeadsWeight", runState, stageState, context)
  local tailsWeight = EffectiveValueSystem.getEffectiveValue("flip.baseTailsWeight", runState, stageState, context)

  if headsWeight <= 0 and tailsWeight <= 0 then
    return 0.5, 0.5
  end

  return headsWeight, tailsWeight
end

function EffectiveValueSystem.getShopRules(runState, stageState, context)
  local rules = {
    offerCount = EffectiveValueSystem.getEffectiveValue("shop.offerCount", runState, stageState, context),
    guaranteedCoinOffers = EffectiveValueSystem.getEffectiveValue("shop.guaranteedCoinOffers", runState, stageState, context),
    guaranteedUpgradeOffers = EffectiveValueSystem.getEffectiveValue("shop.guaranteedUpgradeOffers", runState, stageState, context),
    rerollCost = EffectiveValueSystem.getEffectiveValue("shop.rerollCost", runState, stageState, context),
    rarityWeights = {
      common = EffectiveValueSystem.getEffectiveValue("shop.rarityWeight.common", runState, stageState, context),
      uncommon = EffectiveValueSystem.getEffectiveValue("shop.rarityWeight.uncommon", runState, stageState, context),
      rare = EffectiveValueSystem.getEffectiveValue("shop.rarityWeight.rare", runState, stageState, context),
    },
  }

  rules.offerCount = math.max(rules.offerCount, rules.guaranteedCoinOffers + rules.guaranteedUpgradeOffers)
  return rules
end

function EffectiveValueSystem.resolveRunBootstrapValues(metaProjection, options)
  options = options or {}

  local bootstrapRunState = {
    ownedUpgradeIds = Utils.copyArray(options.ownedUpgradeIds or {}),
    collectionCoinIds = Utils.copyArray(options.starterCollection or {}),
    equippedCoinSlots = {},
    maxActiveCoinSlots = 0,
    temporaryRunEffects = {},
    metaProjection = metaProjection,
  }

  local startingCollectionSize = options.startingCollectionSize

  if startingCollectionSize == nil then
    startingCollectionSize = getResolvedBootstrapOverride(options, "run.startingCollectionSize")
  end

  if startingCollectionSize == nil then
    if options.starterCollection then
      startingCollectionSize = #options.starterCollection
    else
      startingCollectionSize = EffectiveValueSystem.getEffectiveValue("run.startingCollectionSize", bootstrapRunState, nil, {
        metaProjection = metaProjection,
      })
    end
  end

  local maxActiveCoinSlots = options.maxActiveCoinSlots

  if maxActiveCoinSlots == nil then
    maxActiveCoinSlots = getResolvedBootstrapOverride(options, "run.maxActiveCoinSlots")
  end

  if maxActiveCoinSlots == nil then
    maxActiveCoinSlots = EffectiveValueSystem.getEffectiveValue("run.maxActiveCoinSlots", bootstrapRunState, nil, {
      metaProjection = metaProjection,
    })
  end

  bootstrapRunState.maxActiveCoinSlots = maxActiveCoinSlots
  bootstrapRunState.equippedCoinSlots = Utils.copyArray(options.equippedCoinSlots or {})

  local baseFlipsPerStage = options.baseFlipsPerStage
  if baseFlipsPerStage == nil then
    baseFlipsPerStage = getResolvedBootstrapOverride(options, "stage.flipsPerStage")
  end

  if baseFlipsPerStage == nil then
    baseFlipsPerStage = EffectiveValueSystem.getEffectiveValue("stage.flipsPerStage", bootstrapRunState, nil, {
      metaProjection = metaProjection,
    })
  end

  local startingShopPoints = options.startingShopPoints
  if startingShopPoints == nil then
    startingShopPoints = getResolvedBootstrapOverride(options, "run.startingShopPoints")
  end

  if startingShopPoints == nil then
    startingShopPoints = EffectiveValueSystem.getEffectiveValue("run.startingShopPoints", bootstrapRunState, nil, {
      metaProjection = metaProjection,
    })
  end

  local startingShopRerolls = options.startingShopRerolls
  if startingShopRerolls == nil then
    startingShopRerolls = getResolvedBootstrapOverride(options, "run.startingShopRerolls")
  end

  if startingShopRerolls == nil then
    startingShopRerolls = EffectiveValueSystem.getEffectiveValue("run.startingShopRerolls", bootstrapRunState, nil, {
      metaProjection = metaProjection,
    })
  end

  local handSize = options.handSize
  if handSize == nil then
    handSize = getResolvedBootstrapOverride(options, "purse.handSize")
  end

  if handSize == nil then
    handSize = EffectiveValueSystem.getEffectiveValue("purse.handSize", bootstrapRunState, nil, {
      metaProjection = metaProjection,
    })
  end

  return {
    startingCollectionSize = startingCollectionSize,
    maxActiveCoinSlots = maxActiveCoinSlots,
    baseFlipsPerStage = baseFlipsPerStage,
    startingShopPoints = startingShopPoints,
    startingShopRerolls = startingShopRerolls,
    handSize = handSize,
  }
end

function EffectiveValueSystem.applyLegacyModifierValue(currentValue, key, value)
  return applyLegacyModifierValue(currentValue, key, value)
end

return EffectiveValueSystem
