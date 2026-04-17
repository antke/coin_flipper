local RNG = require("src.core.rng")
local RunHistorySystem = require("src.systems.run_history_system")
local Utils = require("src.core.utils")

local ScenarioEnv = {}

function ScenarioEnv.new(definition)
  local env = {
    scenario = definition,
    setup = definition.setup and definition.setup() or {},
    results = {},
    batches = {},
  }

  function env:remember(label, value)
    if label then
      self.results[label] = value
    end

    self.lastResult = value
    return value
  end

  function env:ensureRng()
    if not self.rng and self.runState then
      self.rng = RNG.new(self.runState.seed)
    end

    return self.rng
  end

  function env:recordBatch(batchResult)
    self.lastBatchResult = batchResult
    table.insert(self.batches, batchResult)
    RunHistorySystem.recordFlipBatch(self.runState, batchResult.batch)
    return batchResult
  end

  function env:syncShopFlow(shopFlow)
    self.shopFlow = shopFlow
    self.shopSession = shopFlow.shopSession
    self.shopOffers = shopFlow.offers
    self.lastShopGenerationTrace = shopFlow.lastGenerationTrace
    self.lastShopPurchaseTrace = shopFlow.lastPurchaseTrace
    return shopFlow
  end

  return env
end

return ScenarioEnv
