local TrickBoardSystem = require("src.systems.trick_board_system")

local TrickBoardActions = {}

local TRICK_BOARD_OPS = {
  set_trick_pressure = true,
}

function TrickBoardActions.isTrickBoardOp(op)
  return TRICK_BOARD_OPS[op] == true
end

function TrickBoardActions.validate(action)
  if type(action.position) ~= "number" or action.position < 1 or math.floor(action.position) ~= action.position then
    return false, "set_trick_pressure requires a positive integer position"
  end
  if type(action.pressure) ~= "table"
    or (action.pressure.kind ~= "blocked"
      and action.pressure.kind ~= "weakened"
      and action.pressure.kind ~= "jammed") then
    return false, "set_trick_pressure requires Block, Weaken, or Jam pressure"
  end
  return true
end

function TrickBoardActions.apply(_, stageState, context, action, options)
  local ok, reason = TrickBoardSystem.setPressure(stageState, action.position, action.pressure)
  if not ok then
    action.skipped = true
    action.skipReason = reason
    if options and options.recordWarning then
      options.recordWarning(context, "set_trick_pressure ignored: " .. tostring(reason))
    end
  end
  return ok, reason
end

return TrickBoardActions
