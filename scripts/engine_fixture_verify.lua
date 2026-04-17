package.path = "./?.lua;./?/init.lua;" .. package.path

local Assertions = require("scripts.fixtures.engine.helpers.assertions")
local Registry = require("scripts.fixtures.engine.registry")
local RunSteps = require("scripts.fixtures.engine.helpers.run_steps")

local function matchesFilter(scenario, filters)
  if #filters == 0 then
    return true
  end

  for _, filter in ipairs(filters) do
    if filter:sub(1, 4) == "tag:" then
      local wantedTag = filter:sub(5)

      for _, tag in ipairs(scenario.tags or {}) do
        if tag == wantedTag then
          return true
        end
      end
    elseif scenario.id == filter then
      return true
    end
  end

  return false
end

local filters = {}
for _, value in ipairs(arg or {}) do
  table.insert(filters, value)
end

local selectedScenarios = {}
local seenScenarioIds = {}
for _, scenario in ipairs(Registry) do
  assert(type(scenario) == "table", "fixture registry entries must be tables")
  assert(type(scenario.id) == "string" and scenario.id ~= "", "fixture scenarios must define id")
  assert(type(scenario.steps) == "table", string.format("fixture scenario %s must define steps", tostring(scenario.id)))
  assert(not seenScenarioIds[scenario.id], string.format("duplicate fixture scenario id %s", scenario.id))
  seenScenarioIds[scenario.id] = true

  if matchesFilter(scenario, filters) then
    table.insert(selectedScenarios, scenario)
  end
end

assert(#selectedScenarios > 0, "no fixture scenarios selected")

local passed = 0
local failures = {}

for _, scenario in ipairs(selectedScenarios) do
  local ok, errorMessage = xpcall(function()
    local env = RunSteps.executeScenario(scenario)
    local A = Assertions.new(env)

    if scenario.assert then
      scenario.assert(env, A)
    end
  end, debug.traceback)

  if ok then
    passed = passed + 1
  else
    table.insert(failures, string.format("%s failed: %s", scenario.id, tostring(errorMessage)))
  end
end

print(string.format("Engine fixture verification: %d/%d passed", passed, #selectedScenarios))

for _, failure in ipairs(failures) do
  print("- " .. failure)
end

if #failures > 0 then
  os.exit(1)
end
