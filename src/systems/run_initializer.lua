local Coins = require("src.content.coins")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local Loadout = require("src.domain.loadout")
local MetaUpgrades = require("src.content.meta_upgrades")
local RunState = require("src.domain.run_state")
local StageState = require("src.domain.stage_state")
local Stages = require("src.content.stages")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local RunInitializer = {}
local DEFAULT_STARTER_COLLECTION = {
  "copper_bent_coin",
  "copper_blank_coin",
  "copper_hollow_coin",
  "copper_marked_coin",
  "copper_lucky_coin",
  "copper_weighted_coin",
}

local function buildStarterPurse()
  local starterPurse = {}

  for index = 1, 10 do
    table.insert(starterPurse, DEFAULT_STARTER_COLLECTION[((index - 1) % #DEFAULT_STARTER_COLLECTION) + 1])
  end

  return starterPurse
end

local function buildStarterPurseFromCollection(starterCollection, resolvedValues)
  local starterPurse = {}

  if #(starterCollection or {}) == 0 then
    return starterPurse
  end

  local purseSize = math.max(1, (resolvedValues.handSize or 5) * (resolvedValues.baseFlipsPerStage or 1))

  for index = 1, purseSize do
    table.insert(starterPurse, starterCollection[((index - 1) % #starterCollection) + 1])
  end

  return starterPurse
end

function RunInitializer.createMetaProjection(metaState)
  local effectiveValues = Utils.clone(metaState.effectiveValues or {})

  local modifiers = EffectiveValueSystem.buildLegacyModifierTableFromCanonicalEffectiveValues(effectiveValues, {})

  return {
    id = "meta_projection",
    name = "Meta Projection",
    modifiers = modifiers,
    effectiveValues = effectiveValues,
    triggers = {},
  }
end

function RunInitializer.createNewRun(metaState, options)
  options = options or {}

  local metaProjection = RunInitializer.createMetaProjection(metaState)
  local resolvedValues = EffectiveValueSystem.resolveRunBootstrapValues(metaProjection, options)
  local starterCollection = Utils.copyArray(options.starterCollection or DEFAULT_STARTER_COLLECTION)
  local starterPurse = nil

  if options.starterPurse then
    starterPurse = Utils.copyArray(options.starterPurse)
  elseif options.starterCollection then
    starterPurse = buildStarterPurseFromCollection(starterCollection, resolvedValues)
  else
    starterPurse = buildStarterPurse()
  end

  local runState = RunState.new({
    seed = options.seed,
    metaProjection = metaProjection,
    resolvedValues = resolvedValues,
    starterCollection = starterCollection,
    starterPurse = starterPurse,
    unlockedCoinIds = Utils.copyArray(metaState.unlockedCoinIds or {}),
    unlockedTrickIds = Utils.copyArray(metaState.unlockedTrickIds or metaState.unlockedUpgradeIds or {}),
    flipSlots = Utils.copyArray(options.flipSlots or options.equippedCoinSlots or {}),
    persistedFlipSlots = Utils.copyArray(options.persistedFlipSlots or options.persistedLoadoutSlots or {}),
    ownedTrickIds = Utils.copyArray(options.ownedTrickIds or options.ownedUpgradeIds or {}),
    maxFlipSlots = resolvedValues.maxFlipSlots or resolvedValues.maxActiveCoinSlots,
    baseFlipsPerStage = resolvedValues.baseFlipsPerStage,
    startingInfluence = resolvedValues.startingInfluence or resolvedValues.startingShopPoints,
    startingShopRerolls = resolvedValues.startingShopRerolls,
  })

  runState.history.bootstrap = {
    seed = runState.seed,
    starterCollection = Utils.copyArray(starterCollection),
    starterPurse = Utils.copyArray(starterPurse),
    flipSlots = Loadout.cloneSlots(runState.flipSlots, runState.maxFlipSlots),
    persistedFlipSlots = Loadout.cloneSlots(runState.persistedFlipSlots, runState.maxFlipSlots),
    ownedTrickIds = Utils.copyArray(runState.ownedTrickIds or runState.ownedUpgradeIds),
    metaState = Utils.clone(metaState),
    startingCollectionSize = resolvedValues.startingCollectionSize,
    resolvedValues = {
      ["run.startingCollectionSize"] = resolvedValues.startingCollectionSize,
      ["run.maxFlipSlots"] = resolvedValues.maxFlipSlots or resolvedValues.maxActiveCoinSlots,
      ["run.maxActiveCoinSlots"] = resolvedValues.maxFlipSlots or resolvedValues.maxActiveCoinSlots,
      ["stage.flipsPerStage"] = resolvedValues.baseFlipsPerStage,
      ["purse.handSize"] = resolvedValues.handSize,
      ["run.startingInfluence"] = resolvedValues.startingInfluence or resolvedValues.startingShopPoints,
      ["run.startingShopPoints"] = resolvedValues.startingInfluence or resolvedValues.startingShopPoints,
      ["run.startingShopRerolls"] = resolvedValues.startingShopRerolls,
    },
  }

  Validator.assertRuntimeInvariants("run_initializer.createNewRun", runState, nil, { history = true })

  return runState, metaProjection
end

function RunInitializer.createStageForCurrentRound(runState)
  local stageDefinition = Stages.getForRound(runState.roundIndex, runState)
  assert(stageDefinition, string.format("Missing stage definition for round %s", tostring(runState.roundIndex)))

  runState.currentStageId = stageDefinition.id
  local flipsPerStage = EffectiveValueSystem.getEffectiveValue("stage.flipsPerStage", runState, nil, {
    metaProjection = runState.metaProjection,
    stageDefinition = stageDefinition,
  })

  local stageState = StageState.new(stageDefinition, runState, {
    flipsPerStage = flipsPerStage,
    resolvedValues = {
      ["stage.flipsPerStage"] = flipsPerStage,
    },
  })

  Validator.assertRuntimeInvariants("run_initializer.createStageForCurrentRound", runState, stageState, { history = true })

  return stageState, stageDefinition
end

return RunInitializer
