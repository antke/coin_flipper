local MetaState = require("src.domain.meta_state")
local RunInitializer = require("src.systems.run_initializer")
local Utils = require("src.core.utils")

local Common = require("scripts.fixtures.engine.helpers.steps.common")

local RunCoreSteps = {}
local handlers = {}

local function initRun(env, step)
  local metaStateOptions = step.metaStateOptions or env.setup.metaStateOptions or {}
  local runOptions = Common.mergeTable(Utils.clone(env.setup.runOptions or {}), step.runOptions or {})

  env.metaState = step.metaState or MetaState.new(metaStateOptions)
  env.runState, env.metaProjection = RunInitializer.createNewRun(env.metaState, runOptions)
  env:ensureRng()
  Common.assertRuntime(env, "fixtures.init_run", { history = true })

  return {
    seed = env.runState.seed,
    runOptions = Utils.clone(runOptions),
  }
end

local function assertInvariants(env, step)
  local options = Common.cloneStepOptions(step.options or {})

  if step.includeShopOffers then
    options.shopOffers = env.shopFlow and env.shopFlow.offers or nil
  end

  if step.batchLabel then
    options.batchResult = env.results[step.batchLabel]
  elseif step.includeLastBatch then
    options.batchResult = env.lastBatchResult
  end

  if options.history == nil then
    options.history = true
  end

  Common.assertRuntime(env, step.label or "fixtures.assert_invariants", options)
  return true
end

handlers.init_run = initRun
handlers.assert_invariants = assertInvariants

RunCoreSteps.handlers = handlers

return RunCoreSteps
