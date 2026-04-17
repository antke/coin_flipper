package.path = "./?.lua;./?/init.lua;" .. package.path

local AnalyticsSystem = require("src.systems.analytics_system")
local GameConfig = require("src.app.config")
local SimulationSystem = require("src.systems.simulation_system")

local function parseArg(index, configPath)
  return tonumber(arg[index]) or GameConfig.get(configPath)
end

local runCount = parseArg(1, "simulation.runCount")
local baseSeed = parseArg(2, "simulation.baseSeed")
local seedStep = parseArg(3, "simulation.seedStep")

local results = SimulationSystem.simulateRuns({
  runCount = runCount,
  baseSeed = baseSeed,
  seedStep = seedStep,
})

local report = AnalyticsSystem.buildSimulationReport(results)
print(AnalyticsSystem.formatSimulationReport(report))
