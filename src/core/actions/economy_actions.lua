local EffectiveValueSystem = require("src.systems.effective_value_system")
local LuckSystem = require("src.systems.luck_system")
local ScoreBreakdown = require("src.domain.score_breakdown")
local Utils = require("src.core.utils")

local EconomyActions = {}

local ECONOMY_OPS = {
  add_influence = true,
  add_shop_points = true,
  add_luck = true,
}

local function ensureScoreBreakdown(context)
  context.scoreBreakdown = context.scoreBreakdown or ScoreBreakdown.new()

  local scoreScalings = context.scoreBreakdown.scoreScalings or context.scoreBreakdown.multipliers or {}
  context.scoreBreakdown.scoreScalings = scoreScalings
  context.scoreBreakdown.multipliers = scoreScalings
end

function EconomyActions.isEconomyOp(op)
  return ECONOMY_OPS[op] == true
end

function EconomyActions.validate(action)
  if type(action.amount) ~= "number" then
    return false, string.format("%s requires numeric amount", action.op)
  end

  if (action.op == "add_influence" or action.op == "add_shop_points")
    and action.applyMultiplier ~= nil and type(action.applyMultiplier) ~= "boolean" then
    return false, string.format("%s applyMultiplier must be boolean", action.op)
  end

  return true
end

function EconomyActions.apply(runState, stageState, context, action)
  if action.op == "add_influence" or action.op == "add_shop_points" then
    ensureScoreBreakdown(context)
    local multiplier = 1.0

    if action.applyMultiplier ~= false then
      multiplier = EffectiveValueSystem.getEffectiveValue("economy.influenceMultiplier", runState, stageState, {
        metaProjection = context.metaProjection,
        activeSources = context.activeSources,
      })
    end

    local scaledAmount = action.amount

    if multiplier ~= 1.0 and action.amount ~= 0 then
      local scaledRawAmount = action.amount * multiplier

      if scaledRawAmount >= 0 then
        scaledAmount = math.max(1, math.floor(scaledRawAmount + 0.00001))
      else
        scaledAmount = math.min(-1, math.ceil(scaledRawAmount - 0.00001))
      end
    end

    runState.influence = runState.influence + scaledAmount
    context.scoreBreakdown.totalShopPointDelta = context.scoreBreakdown.totalShopPointDelta + scaledAmount

    local appliedAction = Utils.clone(action)
    appliedAction.appliedAmount = scaledAmount
    table.insert(context.scoreBreakdown.shopPointChanges, appliedAction)
    return true
  elseif action.op == "add_luck" then
    LuckSystem.addLuck(runState, context, action.amount, {
      source = "action",
      reason = action.reason,
      action = action,
      ignoreFatedSuppression = action.ignoreFatedSuppression == true,
    })
    return true
  end

  return false
end

return EconomyActions
