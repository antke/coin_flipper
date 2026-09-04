local PurseSystem = require("src.systems.purse_system")
local TargetSelectors = require("src.core.target_selectors")

local PurseActions = {}

local PURSE_OPS = {
  add_next_hand_draws = true,
  copy_smuggled_coin = true,
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

  if action.op == "add_next_hand_draws" then
    if type(action.amount) ~= "number" or math.floor(action.amount) ~= action.amount or action.amount < 1 then
      return false, "add_next_hand_draws requires positive integer amount"
    end

    return true
  end

  if action.op == "copy_smuggled_coin" then
    if action.chance ~= nil and (type(action.chance) ~= "number" or action.chance < 0 or action.chance > 1) then
      return false, "copy_smuggled_coin chance must be between 0 and 1 when present"
    end

    if action.maxOverloadSlots ~= nil and (type(action.maxOverloadSlots) ~= "number" or math.floor(action.maxOverloadSlots) ~= action.maxOverloadSlots or action.maxOverloadSlots < 1) then
      return false, "copy_smuggled_coin maxOverloadSlots must be a positive integer when present"
    end

    return true
  end

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
  if action.op == "add_next_hand_draws" then
    requireStageState(stageState, action.op)

    local total, errorMessage = PurseSystem.addNextHandDraws(stageState, action.amount)
    if not total then
      recordWarning(options, context, errorMessage or "add_next_hand_draws could not be applied.")
      return true
    end

    action.nextHandBonusDraws = total
    return true
  end

  if action.op == "copy_smuggled_coin" then
    requireStageState(stageState, action.op)

    local chance = action.chance == nil and 1 or action.chance
    local roll = context.rng and context.rng.nextFloat and context.rng:nextFloat() or 1
    action.chance = chance
    action.rngRoll = roll

    if roll > chance then
      action.skipped = true
      action.skipReason = "chance_failed"
      return true
    end

    local entry, errorMessage, source = PurseSystem.copySmuggledBoardCoin(runState, stageState, {
      sourceId = action._trace and action._trace.sourceId or nil,
      maxOverloadSlots = action.maxOverloadSlots,
      rng = context.rng,
    })

    if not entry then
      action.skipped = true
      action.skipReason = errorMessage or "no_smuggled_coin"
      return true
    end

    action.coinId = entry.coinId
    action.instanceId = entry.instanceId
    action.slotIndex = entry.slotIndex
    action.selectedSlotIndex = entry.selectedSlotIndex
    action.dealtIndex = entry.dealtIndex
    action.boardSlotIndex = entry.boardSlotIndex
    action.overloadSlotIndex = entry.overloadSlotIndex
    action.anchorSelectedSlotIndex = entry.anchorSelectedSlotIndex
    action.anchorInstanceId = entry.anchorInstanceId
    action.anchorCoinId = entry.anchorCoinId
    action.anchorOverloadIndex = entry.anchorOverloadIndex
    action.resolutionIndex = entry.boardSlotIndex
    action.smuggled = entry.smuggled == true
    action.smuggledBy = entry.smuggledBy
    action.contrabandCopy = entry.contrabandCopy == true
    action.copiedFromCoinId = entry.copiedFromCoinId
    action.copiedFromInstanceId = entry.copiedFromInstanceId
    action.sourceCoinId = source and (source.definitionId or source.coinId) or nil
    action.sourceInstanceId = source and source.instanceId or nil
    action.sourceSlotIndex = source and source.boardSlotIndex or nil
    action.sourceResolutionIndex = source and source.boardSlotIndex or nil
    action.targetCoinId = entry.coinId
    action.targetInstanceId = entry.instanceId
    action.targetSlotIndex = entry.slotIndex
    action.targetResolutionIndex = entry.boardSlotIndex

    context.batchFlags.smuggled_this_flip = true
    context.trace.smugglingMoves = context.trace.smugglingMoves or {}
    table.insert(context.trace.smugglingMoves, {
      op = "copy_smuggled_coin",
      sourceId = action._trace and action._trace.sourceId or nil,
      coinId = entry.coinId,
      instanceId = entry.instanceId,
      copiedFromCoinId = entry.copiedFromCoinId,
      copiedFromInstanceId = entry.copiedFromInstanceId,
      dealtIndex = entry.dealtIndex,
      boardSlotIndex = entry.boardSlotIndex,
      overloadSlotIndex = entry.overloadSlotIndex,
      anchorSelectedSlotIndex = entry.anchorSelectedSlotIndex,
      anchorInstanceId = entry.anchorInstanceId,
      anchorCoinId = entry.anchorCoinId,
      anchorOverloadIndex = entry.anchorOverloadIndex,
      resolutionIndex = entry.boardSlotIndex,
      smuggled = true,
      contrabandCopy = true,
      chance = chance,
      rngRoll = roll,
    })

    return true
  end

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
    anchorSelectedSlotIndex = context.currentCoin and context.currentCoin.selectedSlotIndex or nil,
    anchorInstanceId = context.currentCoin and context.currentCoin.instanceId or nil,
    anchorCoinId = context.currentCoin and context.currentCoin.coinId or nil,
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
  action.anchorSelectedSlotIndex = entry.anchorSelectedSlotIndex
  action.anchorInstanceId = entry.anchorInstanceId
  action.anchorCoinId = entry.anchorCoinId
  action.anchorOverloadIndex = entry.anchorOverloadIndex
  action.resolutionIndex = entry.boardSlotIndex
  action.smuggled = entry.smuggled == true
  action.smuggledBy = entry.smuggledBy
  action.smuggledCoinId = entry.coinId
  action.smuggledInstanceId = entry.instanceId
  context.batchFlags.smuggled_this_flip = true

  context.trace.smugglingMoves = context.trace.smugglingMoves or {}
  table.insert(context.trace.smugglingMoves, {
    op = "smuggle_coin_from_hand",
    sourceId = action._trace and action._trace.sourceId or nil,
    coinId = entry.coinId,
    instanceId = entry.instanceId,
    dealtIndex = entry.dealtIndex,
    boardSlotIndex = entry.boardSlotIndex,
    overloadSlotIndex = entry.overloadSlotIndex,
    anchorSelectedSlotIndex = entry.anchorSelectedSlotIndex,
    anchorInstanceId = entry.anchorInstanceId,
    anchorCoinId = entry.anchorCoinId,
    anchorOverloadIndex = entry.anchorOverloadIndex,
    resolutionIndex = entry.boardSlotIndex,
    smuggled = true,
  })

  return true
end

return PurseActions
