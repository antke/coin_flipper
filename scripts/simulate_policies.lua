package.path = "./?.lua;./?/init.lua;" .. package.path

local GameConfig = require("src.app.config")
local SimulationSystem = require("src.systems.simulation_system")

local function parseNumber(index, configPath)
  return tonumber(arg[index]) or GameConfig.get(configPath)
end

local runCount = parseNumber(1, "simulation.runCount")
local baseSeed = parseNumber(2, "simulation.baseSeed")
local seedStep = parseNumber(3, "simulation.seedStep")
local requestedPolicies = {}

for index = 4, #(arg or {}) do
  table.insert(requestedPolicies, arg[index])
end

if #requestedPolicies == 0 then
  requestedPolicies = SimulationSystem.getPolicyIds()
end

print(string.format(
  "Simulation Policy Comparison | runs=%d | baseSeed=%d | seedStep=%d",
  runCount,
  baseSeed,
  seedStep
))

for _, policyId in ipairs(requestedPolicies) do
  local results = SimulationSystem.simulateRuns({
    runCount = runCount,
    baseSeed = baseSeed,
    seedStep = seedStep,
    policy = policyId,
  })
  local wins = 0
  local totalScore = 0
  local totalFlips = 0
  local headsCalls = 0
  local tailsCalls = 0

  for _, result in ipairs(results) do
    local runState = result.runState
    if runState.runStatus == "won" then
      wins = wins + 1
    end

    totalScore = totalScore + (runState.runTotalScore or 0)
    totalFlips = totalFlips + (runState.counters.totalFlips or 0)
    headsCalls = headsCalls + (runState.counters.headsCalls or 0)
    tailsCalls = tailsCalls + (runState.counters.tailsCalls or 0)
  end

  print(string.format(
    "- %-12s wins=%d/%d (%5.1f%%) avgScore=%6.1f avgFlips=%4.2f calls=H%d/T%d",
    policyId,
    wins,
    runCount,
    (wins / math.max(1, runCount)) * 100,
    totalScore / math.max(1, runCount),
    totalFlips / math.max(1, runCount),
    headsCalls,
    tailsCalls
  ))
end
