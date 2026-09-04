local Coins = require("src.content.coins")
local RNG = require("src.core.rng")
local Utils = require("src.core.utils")

local PredictionSlotSystem = {}

local function getSlotCount(runState)
  return math.max(1, math.floor(tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1))
end

function PredictionSlotSystem.generate(runState, stageState)
  local rng = RNG.newFromText(table.concat({
    tostring(runState and runState.seed or 1),
    tostring(runState and runState.roundIndex or 1),
    tostring(stageState and stageState.stageId or "stage"),
    tostring(stageState and stageState.variantId or "base"),
    "prediction-slot-v1",
  }, ":"))

  return {
    revision = 1,
    slotIndex = rng:nextInt(1, getSlotCount(runState)),
    result = rng:nextInt(1, 2) == 1 and "heads" or "tails",
  }
end

function PredictionSlotSystem.ensure(runState, stageState)
  if type(stageState) ~= "table" then
    return nil
  end

  local forecast = stageState.predictionSlot
  local valid = type(forecast) == "table"
    and tonumber(forecast.revision) == 1
    and tonumber(forecast.slotIndex) ~= nil
    and forecast.slotIndex >= 1
    and forecast.slotIndex <= getSlotCount(runState)
    and (forecast.result == "heads" or forecast.result == "tails")

  if not valid then
    stageState.predictionSlot = PredictionSlotSystem.generate(runState, stageState)
  end

  return stageState.predictionSlot
end

function PredictionSlotSystem.isPredictionCoin(coinOrId)
  if type(coinOrId) == "table" and coinOrId.actingFamily == "prediction" then
    return true
  end
  local coinId = type(coinOrId) == "table" and coinOrId.coinId or coinOrId
  local definition = coinId and Coins.getById(coinId) or nil
  return definition and definition.activationFamily == "prediction" or false
end

function PredictionSlotSystem.applyToCoin(runState, stageState, coinState)
  local forecast = PredictionSlotSystem.ensure(runState, stageState)
  if not forecast or type(coinState) ~= "table" then
    return false
  end

  if coinState.selectedSlotIndex ~= forecast.slotIndex
    or not PredictionSlotSystem.isPredictionCoin(coinState) then
    return false
  end

  coinState.foretold = true
  coinState.foretoldResult = forecast.result
  coinState.foretoldBy = "prediction_slot"
  coinState.predictionSlotForced = true
  coinState.predictionSlotIndex = forecast.slotIndex
  return true
end

function PredictionSlotSystem.snapshot(runState, stageState)
  return Utils.clone(PredictionSlotSystem.ensure(runState, stageState))
end

return PredictionSlotSystem
