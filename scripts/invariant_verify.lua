package.path = "./?.lua;./?/init.lua;" .. package.path

local GameConfig = require("src.app.config")
local FlipResolver = require("src.systems.flip_resolver")
local LoadoutSystem = require("src.systems.loadout_system")
local MetaState = require("src.domain.meta_state")
local ReplaySystem = require("src.systems.replay_system")
local RNG = require("src.core.rng")
local RunHistorySystem = require("src.systems.run_history_system")
local RunInitializer = require("src.systems.run_initializer")
local ShopFlowSystem = require("src.systems.shop_flow_system")
local SimulationSystem = require("src.systems.simulation_system")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local function parseArg(index, configPath)
  return tonumber(arg[index]) or GameConfig.get(configPath)
end

local runCount = parseArg(1, "simulation.runCount")
local baseSeed = parseArg(2, "simulation.baseSeed")
local seedStep = parseArg(3, "simulation.seedStep")

local function runTargetedShopScenario(seed)
  local metaState = MetaState.new()
  local runState, metaProjection = RunInitializer.createNewRun(metaState, {
    seed = seed,
  })
  local stageState = RunInitializer.createStageForCurrentRound(runState)
  local selection = LoadoutSystem.createSelection(runState)
  local committedSelection, errorMessage = LoadoutSystem.commitLoadout(runState, selection)
  assert(committedSelection, errorMessage)

  stageState.stageScore = stageState.targetScore
  stageState.stageStatus = "cleared"

  local stageRecord = RunHistorySystem.finalizeStage(runState, stageState, metaState)
  RunHistorySystem.recordStageRewardPreview(stageRecord, { options = {}, choice = nil })
  RunHistorySystem.recordStageEncounterPreview(stageRecord, {
    encounterId = "quiet_hallway",
    name = "Quiet Hallway",
    description = "No encounter is active for this stop.",
    choices = {},
    choice = nil,
    claimed = false,
  })
  runState.shopPoints = 20
  runState.shopRerollsRemaining = 1

  local rng = RNG.new(seed)
  local shopFlow = ShopFlowSystem.createVisit(runState, stageState, metaProjection, rng, {
    sourceStageId = stageRecord.stageId,
    roundIndex = stageRecord.roundIndex,
  })
  local offers = ShopFlowSystem.ensureOffers(shopFlow)
  Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.initial_shop", runState, stageState, { shopOffers = offers, history = true })

  local purchaseIndex = nil
  for index, offer in ipairs(offers) do
    if not offer.purchased and (offer.price or 0) <= runState.shopPoints then
      purchaseIndex = index
      break
    end
  end

  assert(purchaseIndex, "no affordable offer for targeted invariant scenario")

  local purchased, purchaseResult = ShopFlowSystem.purchase(shopFlow, purchaseIndex)
  assert(purchased, purchaseResult and purchaseResult.reason or "purchase_failed")
  Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.purchase", runState, stageState, { shopOffers = shopFlow.offers, history = true })

  local rerollMode, rerollError = ShopFlowSystem.reroll(shopFlow)
  assert(rerollMode, rerollError or "reroll_failed")
  Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.reroll", runState, stageState, { shopOffers = shopFlow.offers, history = true })
end

local function runTargetedQueueScenario(baseSeed)
  for offset = 0, 31 do
    local seed = baseSeed + offset
    local metaState = MetaState.new()
    local runState, metaProjection = RunInitializer.createNewRun(metaState, {
      seed = seed,
      starterCollection = { "weighted_shell" },
      ownedUpgradeIds = { "heads_varnish", "echo_cache", "reserve_fuse" },
    })
    local stageState = RunInitializer.createStageForCurrentRound(runState)
    local selection, errorMessage = LoadoutSystem.commitLoadout(runState, { [1] = "weighted_shell" })
    assert(selection, errorMessage)

    local rng = RNG.new(seed)
    local sawQueue = false
    local sawGrant = false
    local sawConsume = false

    while stageState.stageStatus == "active" do
      local batchResult, batchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, "heads", rng)
      assert(batchResult, batchError)
      table.insert(runState.history.flipBatches, Utils.clone(batchResult.batch))

      sawQueue = sawQueue or #(batchResult.trace.queuedActions or {}) > 0
      sawGrant = sawGrant or #(batchResult.trace.temporaryEffectsGranted or {}) > 0
      sawConsume = sawConsume or #(batchResult.trace.temporaryEffectsConsumed or {}) > 0

      Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.queue_batch", runState, stageState, {
        batchResult = batchResult,
        history = true,
      })
    end

    RunHistorySystem.finalizeStage(runState, stageState, metaState)
    Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.queue_final", runState, nil, { history = true })

    if sawQueue and sawGrant and sawConsume then
      return true
    end
  end

  error("targeted_queue_effect_invariant_scenario_not_found")
end

local function runTargetedForcedResultScenario(seed)
  local metaState = MetaState.new()
  local runState, metaProjection = RunInitializer.createNewRun(metaState, {
    seed = seed,
    starterCollection = { "match_spark" },
  })
  local stageState = RunInitializer.createStageForCurrentRound(runState)
  local selection, errorMessage = LoadoutSystem.commitLoadout(runState, { [1] = "match_spark" })
  assert(selection, errorMessage)

  local rng = RNG.new(seed)
  table.insert(runState.pendingForcedCoinResults, "tails")

  local firstBatch, batchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, "heads", rng)
  assert(firstBatch, batchError)
  table.insert(runState.history.flipBatches, Utils.clone(firstBatch.batch))

  assert(#(firstBatch.trace.forcedResults or {}) == 1, "forced-result scenario should consume exactly one forced result")
  assert(firstBatch.trace.forcedResults[1].result == "tails", "forced-result scenario should force tails")
  assert(firstBatch.perCoin[1].forcedResult == "tails", "per-coin forced result missing")
  assert(#runState.pendingForcedCoinResults == 0, "forced-result queue should be empty after first batch")

  Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.forced_first_batch", runState, stageState, {
    batchResult = firstBatch,
    history = true,
  })

  while stageState.stageStatus == "active" do
    local batchResult, nextBatchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, "heads", rng)
    assert(batchResult, nextBatchError)
    table.insert(runState.history.flipBatches, Utils.clone(batchResult.batch))
    Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.forced_followup", runState, stageState, {
      batchResult = batchResult,
      history = true,
    })
  end

  RunHistorySystem.finalizeStage(runState, stageState, metaState)
  Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.forced_final", runState, nil, { history = true })
end

local function runForcedResultLeakScenario(seed)
  local metaState = MetaState.new()
  local runState = RunInitializer.createNewRun(metaState, {
    seed = seed,
    starterCollection = { "match_spark" },
  })
  local stageState = RunInitializer.createStageForCurrentRound(runState)
  local selection, errorMessage = LoadoutSystem.commitLoadout(runState, { [1] = "match_spark" })
  assert(selection, errorMessage)

  table.insert(runState.pendingForcedCoinResults, "heads")
  stageState.stageScore = stageState.targetScore
  stageState.stageStatus = "cleared"

  RunHistorySystem.finalizeStage(runState, stageState, metaState)
  assert(#runState.pendingForcedCoinResults == 0, "forced-result queue should clear on stage finalization")
  Validator.assertRuntimeInvariants("scripts.invariant_verify.targeted.forced_queue_cleared", runState, nil, { history = true })
end

local passed = 0
local failures = {}

for index = 1, runCount do
  local seed = baseSeed + ((index - 1) * seedStep)
  local ok, errorMessage = pcall(function()
    local simulation = SimulationSystem.simulateRun({ seed = seed })
    Validator.assertRuntimeInvariants("scripts.invariant_verify.simulation", simulation.runState, nil, { history = true })

    local transcript, transcriptError = ReplaySystem.buildTranscript(simulation.runState)
    assert(transcript, transcriptError)

    local replay = ReplaySystem.replayTranscript(transcript)
    assert(replay.ok, table.concat(replay.mismatches or {}, " | "))
    Validator.assertRuntimeInvariants("scripts.invariant_verify.replay", replay.runState, nil, { history = true })
  end)

  if ok then
    passed = passed + 1
  else
    table.insert(failures, string.format("Seed %d failed: %s", seed, tostring(errorMessage)))
  end
end

local targetedOk, targetedError = pcall(function()
  runTargetedShopScenario(baseSeed + (runCount * seedStep) + 97)
end)

if targetedOk then
  passed = passed + 1
  runCount = runCount + 1
else
  table.insert(failures, string.format("Targeted scenario failed: %s", tostring(targetedError)))
  runCount = runCount + 1
end

local targetedQueueOk, targetedQueueError = pcall(function()
  runTargetedQueueScenario(baseSeed + (runCount * seedStep) + 197)
end)

if targetedQueueOk then
  passed = passed + 1
  runCount = runCount + 1
else
  table.insert(failures, string.format("Targeted queue/effect scenario failed: %s", tostring(targetedQueueError)))
  runCount = runCount + 1
end

local targetedForcedOk, targetedForcedError = pcall(function()
  runTargetedForcedResultScenario(baseSeed + (runCount * seedStep) + 307)
end)

if targetedForcedOk then
  passed = passed + 1
  runCount = runCount + 1
else
  table.insert(failures, string.format("Targeted forced-result scenario failed: %s", tostring(targetedForcedError)))
  runCount = runCount + 1
end

local forcedLeakOk, forcedLeakError = pcall(function()
  runForcedResultLeakScenario(baseSeed + (runCount * seedStep) + 401)
end)

if forcedLeakOk then
  passed = passed + 1
  runCount = runCount + 1
else
  table.insert(failures, string.format("Forced-result queue clearing scenario failed: %s", tostring(forcedLeakError)))
  runCount = runCount + 1
end

print(string.format("Invariant verification: %d/%d passed", passed, runCount))

for _, failure in ipairs(failures) do
  print(failure)
end

if #failures > 0 then
  os.exit(1)
end
