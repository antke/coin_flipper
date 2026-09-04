local MetaState = require("src.domain.meta_state")
local LuckSystem = require("src.systems.luck_system")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
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

local function setLuckMeter(env, step)
  local luck = LuckSystem.normalize(env.runState)
  local value = step.value ~= nil and step.value or luck.max

  luck.value = math.max(0, math.min(luck.max, value))
  luck.fatedFlipActive = luck.value >= luck.max
  Common.assertRuntime(env, "fixtures.set_luck_meter", { history = true })
  return luck
end

local function queueForcedResults(env, step)
  assert(env.runState, "queue_forced_results requires an initialized run")
  env.runState.pendingForcedCoinResults = Utils.copyArray(step.results or {})
  Common.assertRuntime(env, "fixtures.queue_forced_results", { history = true })
  return Utils.copyArray(env.runState.pendingForcedCoinResults)
end

local function setEnemySkill(env, step)
  assert(env.runState and env.stageState, "set_enemy_skill requires an active stage")
  local snapshot = EnemySkillSystem.prepareIntent(env.runState, env.stageState, {
    skillId = assert(step.skillId, "set_enemy_skill requires skillId"),
    targetIndex = step.targetIndex,
  })
  Common.assertRuntime(env, "fixtures.set_enemy_skill", { history = true })
  return snapshot
end

handlers.init_run = initRun
handlers.assert_invariants = assertInvariants
handlers.set_luck_meter = setLuckMeter
handlers.queue_forced_results = queueForcedResults
handlers.set_enemy_skill = setEnemySkill

RunCoreSteps.handlers = handlers

return RunCoreSteps
