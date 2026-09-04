local ActionQueue = require("src.core.action_queue")
local CoinTraits = require("src.core.coin_traits")
local RNG = require("src.core.rng")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local function dealtSlot(definitionId, instanceId, dealtIndex, selectedSlotIndex)
  return {
    definitionId = definitionId,
    instanceId = instanceId,
    dealtIndex = dealtIndex,
    originalDrawIndex = dealtIndex,
    selectedSlotIndex = selectedSlotIndex,
  }
end

local function smugglingStage()
  local source = dealtSlot("copper_hollow_coin", "source", 1, 1)
  local goldA = dealtSlot("gold_hollow_coin", "gold_a", 2)
  local silver = dealtSlot("silver_hollow_coin", "silver", 3)
  local goldB = dealtSlot("gold_hollow_coin", "gold_b", 4)
  local copper = dealtSlot("copper_hollow_coin", "copper", 5)
  return {
    batchIndex = 0,
    purse = {
      dealtHandSlots = { source, goldA, silver, goldB, copper },
      selectedSlots = { source },
      handSlots = { source },
      boardSlots = {},
      smugglingHistory = {},
    },
  }
end

local function selectedState(coinId, instanceId, result)
  return {
    coinId = coinId,
    instanceId = instanceId,
    slotIndex = 1,
    selectedSlotIndex = 1,
    dealtIndex = 1,
    originalDrawIndex = 1,
    resolutionIndex = 1,
    result = result,
  }
end

local function actionContext(stageState, coinState, seed)
  return ActionQueue.createContext("smuggling_test", {
    call = "heads",
    stageState = stageState,
    currentCoin = coinState,
    currentActivation = { activationId = "activation_001", activationFamily = "smuggle" },
    perCoin = { coinState },
    resolutionOrder = { Utils.clone(coinState) },
    batchFlags = {},
    trace = { coinRolls = { Utils.clone(coinState) } },
    rng = RNG.new(seed or 1),
  })
end

local function effectFor(trickId)
  local definition = assert(Upgrades.getById(trickId), "missing Trick " .. trickId)
  return Utils.clone(definition.triggers[1].effects[1])
end

return {
  id = "smuggling_quality_and_overload",
  tags = { "smuggling", "mechanics" },
  description = "Verifies Smuggling only imports concealed material-banded cargo into anchored overload slots.",

  steps = {},

  assert = function(_, A)
    local runState = { counters = {} }

    local highStage = smugglingStage()
    local highSource = selectedState("copper_hollow_coin", "source", nil)
    local highContext = actionContext(highStage, highSource, 8)
    ActionQueue.applyAll(runState, highStage, highContext, { effectFor("hidden_in_plain_sight") })
    local highAction = A.truthy(highContext.trace.actions[1], "highest-quality smuggle action")
    A.equal(CoinTraits.materialRank(highAction.coinId, true), 3, "highest-quality selector should constrain the random pool to Gold")
    A.truthy(highAction.instanceId == "gold_a" or highAction.instanceId == "gold_b", "highest-quality selector should randomly choose a Gold instance")
    A.equal(highAction.anchorSelectedSlotIndex, 1, "smuggled cargo should anchor to its activating slot")
    A.equal(highAction.anchorInstanceId, "source", "smuggled cargo should anchor to its activating coin")
    A.equal(highAction.anchorOverloadIndex, 1, "first cargo body should be first in the slot fan")

    local lowStage = smugglingStage()
    local lowSource = selectedState("copper_hollow_coin", "source", nil)
    local lowContext = actionContext(lowStage, lowSource, 8)
    ActionQueue.applyAll(runState, lowStage, lowContext, { effectFor("under_the_table") })
    local lowAction = A.truthy(lowContext.trace.actions[1], "lowest-quality smuggle action")
    A.equal(lowAction.instanceId, "copper", "lowest-quality selector should constrain the random pool to Copper")
    A.equal(lowAction.anchorSelectedSlotIndex, 1, "lowest-quality cargo should share the activating slot")
    A.equal(#(highContext.trace.smugglingExtractions or {}), 0, "Smuggling should not extract or substitute active coin bodies")
    A.equal(#(lowContext.trace.smugglingExtractions or {}), 0, "lowest-quality Smuggling should remain inbound-only")
  end,
}
