local ActionQueue = require("src.core.action_queue")
local Bets = require("src.content.bets")
local Utils = require("src.core.utils")

local BetSystem = {}

function BetSystem.getSelectedBet(runState)
  return Bets.getById(runState and runState.selectedBetId or nil) or Bets.getById(Bets.getDefaultId())
end

function BetSystem.canAfford(runState, bet)
  local stake = bet and bet.stake or 0
  return (runState and runState.shopPoints or 0) >= stake
end

function BetSystem.validateSelectedBet(runState)
  local bet = BetSystem.getSelectedBet(runState)

  if not bet then
    return false, "unknown_bet"
  end

  if not BetSystem.canAfford(runState, bet) then
    return false, "not_enough_chips_for_bet"
  end

  return true, bet
end

function BetSystem.resolveSelectedBet(runState, stageState, context)
  local ok, betOrError = BetSystem.validateSelectedBet(runState)

  if not ok then
    return nil, betOrError
  end

  local bet = betOrError
  local result = {
    id = bet.id,
    name = bet.name,
    stake = bet.stake or 0,
    outcome = "none",
    amount = 0,
  }

  if bet.id == "none" then
    context.betResult = Utils.clone(result)
    context.trace.betResult = Utils.clone(result)
    return result
  end

  if bet.winFlag and context.batchFlags and context.batchFlags[bet.winFlag] == true then
    result.outcome = "won"
    result.amount = bet.winAmount or 0
  elseif bet.loseFlag and context.batchFlags and context.batchFlags[bet.loseFlag] == true then
    result.outcome = "lost"
    result.amount = -(bet.stake or 0)
  end

  if result.amount ~= 0 then
    ActionQueue.apply(runState, stageState, context, {
      op = "add_shop_points",
      amount = result.amount,
      applyMultiplier = false,
      category = "bet",
      label = bet.name,
      _trace = {
        phase = "bet_resolution",
        sourceId = bet.id,
        sourceType = "bet",
      },
    })
  end

  context.betResult = Utils.clone(result)
  context.trace.betResult = Utils.clone(result)
  return result
end

return BetSystem
