local DevBuilds = require("src.content.dev_builds")
local MetaState = require("src.domain.meta_state")
local RunInitializer = require("src.systems.run_initializer")

local function assertContainsAll(A, actualValues, expectedValues, labelPrefix)
  for _, expectedValue in ipairs(expectedValues or {}) do
    A.contains(actualValues, expectedValue, string.format("%s should contain %s", labelPrefix, expectedValue))
  end
end

return {
  id = "prepared_build_bootstrap",
  tags = { "bootstrap", "prepared_builds" },
  description = "Verifies each prepared build resolves into a valid bootstrapped run.",

  steps = {},

  assert = function(_, A)
    local builds = DevBuilds.getAll()
    A.truthy(#builds > 0, "prepared builds should exist")

    for index, build in ipairs(builds) do
      local seed = 9100 + index
      local runOptions = A.truthy(DevBuilds.resolve(build.id, seed), string.format("%s should resolve", build.id))
      local runState = RunInitializer.createNewRun(MetaState.new(), runOptions)

      A.equal(runState.seed, seed, string.format("%s seed", build.id))
      A.equal(#runState.coinInstances, #runOptions.starterPurse, string.format("%s purse size", build.id))
      assertContainsAll(A, runState.ownedTrickIds, runOptions.ownedTrickIds, string.format("%s owned tricks", build.id))
    end
  end,
}
