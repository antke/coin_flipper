local ScenarioEnv = require("scripts.fixtures.engine.helpers.scenario_env")
local Common = require("scripts.fixtures.engine.helpers.steps.common")
local ReplaySteps = require("scripts.fixtures.engine.helpers.steps.replay_steps")
local RewardSteps = require("scripts.fixtures.engine.helpers.steps.reward_steps")
local RunCoreSteps = require("scripts.fixtures.engine.helpers.steps.run_core_steps")
local ShopSteps = require("scripts.fixtures.engine.helpers.steps.shop_steps")
local StageSteps = require("scripts.fixtures.engine.helpers.steps.stage_steps")

local RunSteps = {}

local STEP_HANDLERS = Common.mergeHandlers(
  RunCoreSteps.handlers,
  StageSteps.handlers,
  RewardSteps.handlers,
  ShopSteps.handlers,
  ReplaySteps.handlers
)

function RunSteps.executeScenario(definition)
  local env = ScenarioEnv.new(definition)
  local seenLabels = {}

  for index, step in ipairs(definition.steps or {}) do
    assert(type(step) == "table", string.format("fixture step %d must be a table", index))
    assert(type(step.op) == "string" and step.op ~= "", string.format("fixture step %d must define non-empty op", index))

    if step.label ~= nil then
      assert(type(step.label) == "string" and step.label ~= "", string.format("fixture step %d label must be non-empty string", index))
      assert(not seenLabels[step.label], string.format("duplicate fixture step label %s", step.label))
      seenLabels[step.label] = true
    end

    local handler = STEP_HANDLERS[step.op]
    assert(handler, string.format("unknown fixture step op %s", tostring(step.op)))
    env:remember(step.label, handler(env, step))
  end

  return env
end

return RunSteps
