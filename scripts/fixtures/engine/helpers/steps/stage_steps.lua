local FlipResolver = require("src.systems.flip_resolver")
local LoadoutSystem = require("src.systems.loadout_system")
local RunHistorySystem = require("src.systems.run_history_system")
local RunInitializer = require("src.systems.run_initializer")

local Common = require("scripts.fixtures.engine.helpers.steps.common")

local StageSteps = {}
local handlers = {}

local function createStage(env)
  env.stageState, env.stageDefinition = RunInitializer.createStageForCurrentRound(env.runState)
  Common.assertRuntime(env, "fixtures.create_stage", { history = true })
  return env.stageState
end

local function commitLoadout(env, step)
  local selection = step.slots or env.setup.initialLoadout or LoadoutSystem.createSelection(env.runState)
  local committedSelection, errorMessage = LoadoutSystem.commitLoadout(env.runState, selection)
  assert(committedSelection, errorMessage)
  Common.assertRuntime(env, "fixtures.commit_loadout", { history = true })
  return committedSelection
end

local function resolveBatch(env, step)
  local batchResult, errorMessage = FlipResolver.resolveBatch(
    env.runState,
    env.stageState,
    env.metaProjection,
    step.call or "heads",
    env:ensureRng()
  )
  assert(batchResult, errorMessage)
  env:recordBatch(batchResult)
  Common.assertRuntime(env, "fixtures.resolve_batch", {
    batchResult = batchResult,
    history = true,
  })
  return batchResult
end

local function resolveUntilStageEnd(env, step)
  local batchResults = {}
  local maxBatches = step.maxBatches or 12
  local count = 0

  while env.stageState.stageStatus == "active" and count < maxBatches do
    count = count + 1
    local call = step.call

    if type(call) == "table" then
      call = call[count] or call[#call]
    end

      table.insert(batchResults, resolveBatch(env, { call = call or "heads" }))
  end

  assert(env.stageState.stageStatus ~= "active", string.format("stage did not end within %d batches", maxBatches))
  return batchResults
end

local function forceStageClearTestOnly(env, step)
  env.stageState.stageScore = step.score or env.stageState.targetScore
  env.stageState.stageStatus = "cleared"
  Common.assertRuntime(env, "fixtures.force_stage_clear_test_only", { history = true })
  return env.stageState
end

local function finalizeStage(env)
  env.stageRecord, env.finalizeMeta = RunHistorySystem.finalizeStage(env.runState, env.stageState, env.metaState)
  Common.assertRuntime(env, "fixtures.finalize_stage", { history = true })
  return env.stageRecord
end

handlers.create_stage = createStage
handlers.commit_loadout = commitLoadout
handlers.resolve_batch = resolveBatch
handlers.resolve_until_stage_end = resolveUntilStageEnd
handlers.force_stage_clear = forceStageClearTestOnly
handlers.finalize_stage = finalizeStage

StageSteps.handlers = handlers

return StageSteps
