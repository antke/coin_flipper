local PurseSystem = require("src.systems.purse_system")
local TargetSelectors = require("src.core.target_selectors")

local PredictionActions = {}

local PREDICTION_OPS = {
  foretell_coin_result = true,
}

local function recordWarning(options, context, message)
  if options and options.recordWarning then
    options.recordWarning(context, message)
  end
end

local function requireStageState(stageState, op)
  if not stageState then
    error(string.format("%s requires an active stageState", op))
  end
end

local function clampChance(value)
  return math.max(0, math.min(1, value or 0))
end

local function findDealtSlot(stageState, instanceId)
  for _, slot in ipairs(stageState and stageState.purse and stageState.purse.dealtHandSlots or {}) do
    if slot and slot.instanceId == instanceId then
      return slot
    end
  end

  return nil
end

local function chooseForetellTarget(stageState, context, action)
  if type(action.target) == "table" then
    return TargetSelectors.resolveSlot(nil, stageState, action.target, context)
  end

  if action.instanceId then
    local slot = findDealtSlot(stageState, action.instanceId)

    if slot and slot.foretold ~= true then
      return slot
    end
  end

  return context.currentCoin and findDealtSlot(stageState, context.currentCoin.instanceId) or nil
end

function PredictionActions.isPredictionOp(op)
  return PREDICTION_OPS[op] == true
end

local function isCoinResult(value)
  return value == "heads" or value == "tails"
end

function PredictionActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.target ~= nil and type(action.target) ~= "table" then
    return false, "foretell_coin_result target must be selector when present"
  end

  if type(action.target) == "table" then
    local validSelector, selectorError = selectors.validateSlotSelector(action.target)
    if not validSelector then
      return false, "foretell_coin_result " .. selectorError
    end
  end

  if action.headsChance ~= nil and (type(action.headsChance) ~= "number" or action.headsChance < 0 or action.headsChance > 1) then
    return false, "foretell_coin_result headsChance must be between 0 and 1 when present"
  end

  if action.foretoldResult ~= nil and not isCoinResult(action.foretoldResult) then
    return false, "foretell_coin_result foretoldResult must be heads|tails when present"
  end

  return true
end

function PredictionActions.apply(runState, stageState, context, action, options)
  if action.op ~= "foretell_coin_result" then
    return false
  end

  requireStageState(stageState, action.op)

  local targetSlot, targetError = chooseForetellTarget(stageState, context, action)

  if not targetSlot then
    recordWarning(options, context, targetError or "foretell_coin_result had no eligible dealt coin.")
    return true
  end

  if action.foretoldResult == nil and (not context.rng or type(context.rng.nextFloat) ~= "function") then
    recordWarning(options, context, "foretell_coin_result requires rng.")
    return true
  end

  local result = action.foretoldResult
  local roll = nil

  if result == nil then
    local headsChance = clampChance(action.headsChance or 0.5)
    roll = context.rng:nextFloat()
    result = roll <= headsChance and "heads" or "tails"
  end

  local sourceId = action._trace and action._trace.sourceId or nil

  targetSlot.foretold = true
  targetSlot.foretoldResult = result
  targetSlot.foretoldBy = sourceId
  targetSlot.foretoldRngRoll = roll

  action.instanceId = targetSlot.instanceId
  action.coinId = targetSlot.definitionId or PurseSystem.getDefinitionId(runState, targetSlot.instanceId)
  action.dealtIndex = targetSlot.dealtIndex or targetSlot.originalDrawIndex
  action.selectedSlotIndex = targetSlot.selectedSlotIndex
  action.slotIndex = targetSlot.selectedSlotIndex
  action.resolutionIndex = targetSlot.selectedSlotIndex
  action.foretoldResult = result
  action.foretoldRngRoll = roll

  context.trace.foretoldResults = context.trace.foretoldResults or {}
  table.insert(context.trace.foretoldResults, {
    coinId = action.coinId,
    instanceId = action.instanceId,
    dealtIndex = action.dealtIndex,
    selectedSlotIndex = action.selectedSlotIndex,
    result = result,
    rngRoll = roll,
    sourceId = sourceId,
  })

  return true
end

return PredictionActions
