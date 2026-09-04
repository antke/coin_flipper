local CoinTraits = require("src.core.coin_traits")
local PurseSystem = require("src.systems.purse_system")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local CoinChanceActions = {}

local CHANCE_OPS = {
  add_weight = true,
  set_call_match_chance = true,
  modify_coin_weight = true,
}

local function cloneActionForTrace(action)
  local tracedAction = Utils.clone(action)
  tracedAction._trace = tracedAction._trace or nil
  return tracedAction
end

local function clampChance(value)
  return math.max(0, math.min(1, value or 0))
end

local function applyCoinChanceDelta(coinState, side, amount)
  local sideField = side .. "Weight"
  local otherField = side == "heads" and "tailsWeight" or "headsWeight"
  local sideChance = clampChance((coinState[sideField] or 0) + amount)

  coinState[sideField] = sideChance
  coinState[otherField] = 1 - sideChance
end

local function setCoinCallMatchChance(coinState, call, chance)
  local matchChance = clampChance(chance)

  if call == "heads" then
    coinState.headsWeight = matchChance
    coinState.tailsWeight = 1 - matchChance
  elseif call == "tails" then
    coinState.tailsWeight = matchChance
    coinState.headsWeight = 1 - matchChance
  end
end

local function resolveWeightSide(context, action)
  if action.side == nil or action.side == "call" then
    return context.call
  end

  if action.side == "foretold" then
    return context.currentCoin and context.currentCoin.foretoldResult or nil
  end

  return action.side
end

local function getCoinWeightTargets(context, action, recordWarning)
  if type(action.target) == "table" then
    local targetCoins, targetError = TargetSelectors.resolveSlots(nil, nil, action.target, context)

    if #targetCoins > 0 then
      return targetCoins
    end

    recordWarning(context, targetError or "coin weight target selector had no eligible coin.")
    return {}
  end

  if action.target == "left_neighbor"
    or action.target == "right_neighbor"
    or action.target == "neighbors"
    or action.target == "self_and_left_neighbor"
    or action.target == "self_and_right_neighbor"
    or action.target == "self_and_neighbors" then
    local targets = {}
    local sourceIndex = action.resolutionIndex or action.slotIndex or (context.currentCoin and (context.currentCoin.resolutionIndex or context.currentCoin.slotIndex))

    if not sourceIndex then
      return targets
    end

    for _, coinState in ipairs(context.perCoin or {}) do
      local coinIndex = coinState.resolutionIndex or coinState.slotIndex
      local targetsSelf = action.target == "self_and_left_neighbor" or action.target == "self_and_right_neighbor" or action.target == "self_and_neighbors"
      local targetsLeft = action.target == "left_neighbor" or action.target == "neighbors" or action.target == "self_and_left_neighbor" or action.target == "self_and_neighbors"
      local targetsRight = action.target == "right_neighbor" or action.target == "neighbors" or action.target == "self_and_right_neighbor" or action.target == "self_and_neighbors"
      local isSelf = targetsSelf and coinIndex == sourceIndex
      local isLeftNeighbor = targetsLeft and coinIndex == sourceIndex - 1
      local isRightNeighbor = targetsRight and coinIndex == sourceIndex + 1

      if isSelf or isLeftNeighbor or isRightNeighbor then
        table.insert(targets, coinState)
      end
    end

    return targets
  end

  if context.currentCoin then
    return { context.currentCoin }
  end

  if action.instanceId ~= nil or action.resolutionIndex ~= nil or action.slotIndex ~= nil then
    local targets = {}

    for _, coinState in ipairs(context.perCoin or {}) do
      local matchesInstance = action.instanceId == nil or coinState.instanceId == action.instanceId
      local matchesResolution = action.resolutionIndex == nil or coinState.resolutionIndex == action.resolutionIndex
      local matchesSlot = action.slotIndex == nil or coinState.slotIndex == action.slotIndex

      if matchesInstance and matchesResolution and matchesSlot then
        table.insert(targets, coinState)
      end
    end

    if #targets > 0 then
      return targets
    end
  end

  if action.coinId then
    local targets = {}

    for _, coinState in ipairs(context.perCoin or {}) do
      if coinState.coinId == action.coinId then
        table.insert(targets, coinState)
      end
    end

    return targets
  end

  return context.perCoin or {}
end

local function applyPersistentCoinChanceDelta(runState, coinState, side, amount)
  local instance = coinState and coinState.instanceId and PurseSystem.getInstance(runState, coinState.instanceId) or nil

  if not instance then
    return
  end

  instance.state = instance.state or {}
  instance.state.coinWeightBonuses = instance.state.coinWeightBonuses or { heads = 0, tails = 0 }
  instance.state.coinWeightBonuses[side] = (instance.state.coinWeightBonuses[side] or 0) + amount
end

function CoinChanceActions.isChanceOp(op)
  return CHANCE_OPS[op] == true
end

function CoinChanceActions.isCoinWeightTarget(target)
  if type(target) == "table" then
    return true
  end

  return target == "left_neighbor"
    or target == "right_neighbor"
    or target == "neighbors"
    or target == "self_and_left_neighbor"
    or target == "self_and_right_neighbor"
    or target == "self_and_neighbors"
end

function CoinChanceActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.op == "modify_coin_weight" then
    if (action.side ~= "heads") and (action.side ~= "tails") then
      return false, "modify_coin_weight requires side=heads|tails"
    end

    if type(action.amount) ~= "number" then
      return false, "modify_coin_weight requires numeric amount"
    end

    if action.persistent ~= nil and type(action.persistent) ~= "boolean" then
      return false, "modify_coin_weight persistent must be boolean"
    end

    if action.target ~= nil and not CoinChanceActions.isCoinWeightTarget(action.target) then
      return false, "modify_coin_weight target must be selector|left_neighbor|right_neighbor|neighbors|self_and_left_neighbor|self_and_right_neighbor|self_and_neighbors"
    end

    if type(action.target) == "table" then
      local validSelector, selectorError = selectors.validateSlotSelector(action.target, { selected_coins = true })
      if not validSelector then
        return false, "modify_coin_weight " .. selectorError
      end
    end

    return true
  end

  if action.op == "add_weight" then
    if action.side ~= nil and action.side ~= "heads" and action.side ~= "tails"
      and action.side ~= "call" and action.side ~= "foretold" then
      return false, "add_weight side must be heads|tails|call|foretold when present"
    end

    if type(action.amount) ~= "number" then
      return false, "add_weight requires numeric amount"
    end
  elseif action.op == "set_call_match_chance" then
    if type(action.chance) ~= "number" then
      return false, "set_call_match_chance requires numeric chance"
    end

    if action.chance < 0 or action.chance > 1 then
      return false, "set_call_match_chance chance must be between 0 and 1"
    end

    if action.minimum ~= nil and type(action.minimum) ~= "boolean" then
      return false, "set_call_match_chance minimum must be boolean when present"
    end
  end

  if action.target ~= nil and not CoinChanceActions.isCoinWeightTarget(action.target) then
    return false, string.format("%s target must be selector|left_neighbor|right_neighbor|neighbors|self_and_left_neighbor|self_and_right_neighbor|self_and_neighbors", action.op)
  end

  if type(action.target) == "table" then
    local validSelector, selectorError = selectors.validateSlotSelector(action.target, { selected_coins = true })
    if not validSelector then
      return false, action.op .. " " .. selectorError
    end
  end

  return true
end

function CoinChanceActions.apply(runState, context, action, options)
  local recordWarning = options and options.recordWarning or function() end

  if action.op == "add_weight" then
    local side = resolveWeightSide(context, action)
    action.appliedSide = side

    if side ~= "heads" and side ~= "tails" then
      recordWarning(context, "add_weight ignored without an active call.")
    else
      local targets = getCoinWeightTargets(context, action, recordWarning)

      for _, coinState in ipairs(targets) do
        local amount = action.amount * CoinTraits.familyMultiplier(coinState, action.specializedFamily)

        applyCoinChanceDelta(coinState, side, amount)
        coinState.weightChanges = coinState.weightChanges or {}
        table.insert(coinState.weightChanges, cloneActionForTrace(action))
      end
    end

    return true
  elseif action.op == "set_call_match_chance" then
    if context.call ~= "heads" and context.call ~= "tails" then
      recordWarning(context, "set_call_match_chance ignored without an active call.")
    else
      local targets = getCoinWeightTargets(context, action, recordWarning)

      for _, coinState in ipairs(targets) do
        local chance = action.chance
        if action.minimum == true then
          chance = math.max(chance, coinState[context.call .. "Weight"] or 0)
        end

        setCoinCallMatchChance(coinState, context.call, chance)
        coinState.weightChanges = coinState.weightChanges or {}
        table.insert(coinState.weightChanges, cloneActionForTrace(action))
      end
    end

    return true
  elseif action.op == "modify_coin_weight" then
    local targets = getCoinWeightTargets(context, action, recordWarning)

    for _, coinState in ipairs(targets) do
      if action.persistent == true then
        applyPersistentCoinChanceDelta(runState, coinState, action.side, action.amount)
      else
        applyCoinChanceDelta(coinState, action.side, action.amount)
      end

      coinState.weightChanges = coinState.weightChanges or {}
      table.insert(coinState.weightChanges, cloneActionForTrace(action))
    end

    return true
  end

  return false
end

return CoinChanceActions
