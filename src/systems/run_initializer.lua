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

local function buildStarterPurse(unlockedCoinIds, seed)
  local baseline = Coins.getStarterCoinIds(5, unlockedCoinIds, seed)
  local specials = Coins.getStarterCoinIds(8, unlockedCoinIds, seed)
  local starterPurse = {}

  for _ = 1, 3 do
    for _, coinId in ipairs(baseline) do
      table.insert(starterPurse, coinId)
    end
  end

  for index = 6, math.min(8, #specials) do
    table.insert(starterPurse, specials[index])
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
  local starterCollection = Utils.copyArray(options.starterCollection or Coins.getStarterCoinIds(resolvedValues.startingCollectionSize, metaState.unlockedCoinIds, options.seed))
  local starterPurse = Utils.copyArray(options.starterPurse or buildStarterPurse(metaState.unlockedCoinIds, options.seed))

  local runState = RunState.new({
    seed = options.seed,
    metaProjection = metaProjection,
    resolvedValues = resolvedValues,
    starterCollection = starterCollection,
    starterPurse = starterPurse,
    unlockedCoinIds = Utils.copyArray(metaState.unlockedCoinIds or {}),
    unlockedUpgradeIds = Utils.copyArray(metaState.unlockedUpgradeIds or {}),
    equippedCoinSlots = Utils.copyArray(options.equippedCoinSlots or {}),
    persistedLoadoutSlots = Utils.copyArray(options.persistedLoadoutSlots or {}),
    ownedUpgradeIds = Utils.copyArray(options.ownedUpgradeIds or {}),
    maxActiveCoinSlots = resolvedValues.maxActiveCoinSlots,
    baseFlipsPerStage = resolvedValues.baseFlipsPerStage,
    startingShopPoints = resolvedValues.startingShopPoints,
    startingShopRerolls = resolvedValues.startingShopRerolls,
    selectedBetId = options.selectedBetId,
  })

  runState.history.bootstrap = {
    seed = runState.seed,
    starterCollection = Utils.copyArray(starterCollection),
    starterPurse = Utils.copyArray(starterPurse),
    equippedCoinSlots = Loadout.cloneSlots(runState.equippedCoinSlots, runState.maxActiveCoinSlots),
    persistedLoadoutSlots = Loadout.cloneSlots(runState.persistedLoadoutSlots, runState.maxActiveCoinSlots),
    ownedUpgradeIds = Utils.copyArray(runState.ownedUpgradeIds),
    metaState = Utils.clone(metaState),
    startingCollectionSize = resolvedValues.startingCollectionSize,
    resolvedValues = {
      ["run.startingCollectionSize"] = resolvedValues.startingCollectionSize,
      ["run.maxActiveCoinSlots"] = resolvedValues.maxActiveCoinSlots,
      ["stage.flipsPerStage"] = resolvedValues.baseFlipsPerStage,
      ["purse.handSize"] = resolvedValues.handSize,
      ["run.startingShopPoints"] = resolvedValues.startingShopPoints,
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
