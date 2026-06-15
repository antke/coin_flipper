local PurseSystem = require("src.systems.purse_system")
local TargetSelectors = require("src.core.target_selectors")

local PurseActions = {}

local PURSE_OPS = {
  smuggle_coin_from_hand = true,
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

function PurseActions.isPurseOp(op)
  return PURSE_OPS[op] == true
end

function PurseActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.target == nil then
    return false, "smuggle_coin_from_hand requires target selector"
  end

  local validSelector, selectorError = selectors.validateSlotSelector(action.target)
  if not validSelector then
    return false, "smuggle_coin_from_hand " .. selectorError
  end

  if action.maxOverloadSlots ~= nil and (type(action.maxOverloadSlots) ~= "number" or math.floor(action.maxOverloadSlots) ~= action.maxOverloadSlots or action.maxOverloadSlots < 1) then
    return false, "smuggle_coin_from_hand maxOverloadSlots must be a positive integer when present"
  end

  return true
end

function PurseActions.apply(runState, stageState, context, action, options)
  if action.op ~= "smuggle_coin_from_hand" then
    return false
  end

  requireStageState(stageState, action.op)

  local targetSlot, targetError = TargetSelectors.resolveSlot(runState, stageState, action.target, context)

  if not targetSlot then
    recordWarning(options, context, targetError or "smuggle_coin_from_hand had no eligible unselected dealt coin.")
    return true
  end

  local entry, errorMessage = PurseSystem.smuggleCoinFromHand(runState, stageState, {
    sourceId = action._trace and action._trace.sourceId or nil,
    maxOverloadSlots = action.maxOverloadSlots,
    instanceId = targetSlot.instanceId,
  })

  if not entry then
    recordWarning(options, context, errorMessage or "smuggle_coin_from_hand had no eligible unselected dealt coin.")
    return true
  end

  action.coinId = entry.coinId
  action.instanceId = entry.instanceId
  action.slotIndex = entry.slotIndex
  action.selectedSlotIndex = entry.selectedSlotIndex
  action.dealtIndex = entry.dealtIndex
  action.boardSlotIndex = entry.boardSlotIndex
  action.overloadSlotIndex = entry.overloadSlotIndex
  action.resolutionIndex = entry.boardSlotIndex
  action.smuggled = entry.smuggled == true
  action.smuggledBy = entry.smuggledBy
  action.smuggledCoinId = entry.coinId
  action.smuggledInstanceId = entry.instanceId

  context.trace.smugglingMoves = context.trace.smugglingMoves or {}
  table.insert(context.trace.smugglingMoves, {
    op = "smuggle_coin_from_hand",
    sourceId = action._trace and action._trace.sourceId or nil,
    coinId = entry.coinId,
    instanceId = entry.instanceId,
    dealtIndex = entry.dealtIndex,
    boardSlotIndex = entry.boardSlotIndex,
    overloadSlotIndex = entry.overloadSlotIndex,
    resolutionIndex = entry.boardSlotIndex,
    smuggled = true,
  })

  return true
end

return PurseActions
