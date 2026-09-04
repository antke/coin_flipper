local CoinTraits = require("src.core.coin_traits")
local ScoreBreakdown = require("src.domain.score_breakdown")
local Utils = require("src.core.utils")

local ScoreActions = {}

local SCORE_OPS = {
  add_stage_score = true,
  add_run_score = true,
  heal_opponent = true,
  apply_score_scaling = true,
  apply_score_multiplier = true,
}

local function ensureScoreBreakdown(context)
  context.scoreBreakdown = context.scoreBreakdown or ScoreBreakdown.new()

  local scoreScalings = context.scoreBreakdown.scoreScalings or context.scoreBreakdown.multipliers or {}
  context.scoreBreakdown.scoreScalings = scoreScalings
  context.scoreBreakdown.multipliers = scoreScalings
end

local function requireStageState(stageState, op)
  if not stageState then
    error(string.format("%s requires an active stageState", op))
  end
end

local function cloneActionForTrace(action)
  local tracedAction = Utils.clone(action)
  tracedAction._trace = tracedAction._trace or nil
  return tracedAction
end

local function addScoreBreakdownEntry(targetList, action, extraFields)
  local entry = {
    op = action.op,
    amount = action.amount,
    value = action.value,
    category = action.category,
    label = action.label,
    trace = Utils.clone(action._trace),
  }

  for key, value in pairs(extraFields or {}) do
    entry[key] = value
  end

  table.insert(targetList, entry)
end

local function applyStageScore(runState, stageState, context, action, additiveBonusFields)
  ensureScoreBreakdown(context)
  requireStageState(stageState, action.op)

  stageState.scoreAppliedToHp = stageState.scoreAppliedToHp + action.amount
  runState.runTotalScore = runState.runTotalScore + action.amount
  context.scoreBreakdown.totalStageScoreDelta = context.scoreBreakdown.totalStageScoreDelta + action.amount
  context.scoreBreakdown.totalRunScoreDelta = context.scoreBreakdown.totalRunScoreDelta + action.amount

  if action.category ~= "base_score" then
    local fields = {
      scoreTarget = "stage",
    }

    for key, value in pairs(additiveBonusFields or {}) do
      fields[key] = value
    end

    addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, fields)
  end
end

local function applyRunScore(runState, context, action)
  ensureScoreBreakdown(context)
  runState.runTotalScore = runState.runTotalScore + action.amount
  context.scoreBreakdown.totalRunScoreDelta = context.scoreBreakdown.totalRunScoreDelta + action.amount

  if action.category ~= "base_score" then
    addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, {
      scoreTarget = "run",
    })
  end
end

local function healOpponent(stageState, context, action)
  ensureScoreBreakdown(context)
  requireStageState(stageState, action.op)
  local requested = math.max(0, tonumber(action.amount) or 0)
  local actual = math.min(requested, math.max(0, tonumber(stageState.scoreAppliedToHp) or 0))
  stageState.scoreAppliedToHp = math.max(0, stageState.scoreAppliedToHp - actual)
  context.scoreBreakdown.totalStageScoreDelta = context.scoreBreakdown.totalStageScoreDelta - actual
  action.actualAmount = actual
  table.insert(context.scoreBreakdown.opponentHealing, {
    op = action.op,
    amount = actual,
    requestedAmount = requested,
    category = action.category,
    label = action.label,
    trace = Utils.clone(action._trace),
  })
end

local function applyScoreScaling(context, action, recordWarning)
  ensureScoreBreakdown(context)

  if action.target == "current_coin_score" then
    if context.currentScoreEvent then
      local specializedMultiplier = CoinTraits.familyMultiplier(context.currentScoreEvent, action.specializedFamily)
      local materialFamilyMatches = type(action.materialFamily) == "string"
        and action.materialFamily ~= ""
        and CoinTraits.hasRealFamily(context.currentScoreEvent, action.materialFamily)

      if action.requireSpecializedFamily == true
        and specializedMultiplier == 1
        and materialFamilyMatches ~= true then
        return
      end

      local value = action.value
      local chainDepthBonus = tonumber(action.momentumDepthBonus or action.chainDepthBonus)

      if chainDepthBonus ~= nil then
        local chainDepth = tonumber(context.currentScoreEvent.chainDepth or (context.currentCoin and context.currentCoin.chainDepth)) or 0
        value = value + (chainDepthBonus * chainDepth)
        action.appliedChainDepth = chainDepth
        action.appliedMomentumDepth = chainDepth
      end

      if type(action.materialFamily) == "string" and action.materialFamily ~= "" then
        if materialFamilyMatches then
          value = value * CoinTraits.materialPayoffMultiplier(
            context.currentScoreEvent,
            action.materialBaseMultiplier or 1,
            action.materialRankStep or 0,
            true
          )
          action.appliedMaterialRank = CoinTraits.materialRank(context.currentScoreEvent, true)
        end
      else
        value = value * specializedMultiplier
      end
      action.appliedValue = value

      context.currentScoreEvent.scoreScaling = (context.currentScoreEvent.scoreScaling or context.currentScoreEvent.multiplier or 1.0) * value
      context.currentScoreEvent.multiplier = context.currentScoreEvent.scoreScaling
      addScoreBreakdownEntry(context.scoreBreakdown.scoreScalings, action, {
        scope = "current_coin_score",
        scoreEventId = context.currentScoreEvent.eventId,
        coinId = context.currentScoreEvent.coinId,
        instanceId = context.currentScoreEvent.instanceId,
        slotIndex = context.currentScoreEvent.slotIndex,
        resolutionIndex = context.currentScoreEvent.resolutionIndex,
        appliedValue = value,
      })
    else
      recordWarning(context, "current_coin_score score scaling ignored outside coin scoring.")
    end
  else
    context.pendingScoreScaling = (context.pendingScoreScaling or context.pendingScoreMultiplier or 1.0) * action.value
    context.pendingScoreMultiplier = context.pendingScoreScaling
    table.insert(context.scoreBreakdown.scoreScalings, cloneActionForTrace(action))
  end
end

function ScoreActions.isScoreOp(op)
  return SCORE_OPS[op] == true
end

function ScoreActions.validate(action)
  if action.op == "add_stage_score" or action.op == "add_run_score" or action.op == "heal_opponent" then
    if type(action.amount) ~= "number" then
      return false, string.format("%s requires numeric amount", action.op)
    end

    if action.applyMultiplier ~= nil and type(action.applyMultiplier) ~= "boolean" then
      return false, string.format("%s applyMultiplier must be boolean", action.op)
    end

    return true
  end

  if action.op == "apply_score_scaling" or action.op == "apply_score_multiplier" then
    if type(action.value) ~= "number" then
      return false, string.format("%s requires numeric value", action.op)
    end

    if action.target ~= nil and action.target ~= "current_coin_score" then
      return false, string.format("%s target must be current_coin_score when present", action.op)
    end

    if action.chainDepthBonus ~= nil and type(action.chainDepthBonus) ~= "number" then
      return false, string.format("%s chainDepthBonus must be numeric when present", action.op)
    end

    if action.momentumDepthBonus ~= nil and type(action.momentumDepthBonus) ~= "number" then
      return false, string.format("%s momentumDepthBonus must be numeric when present", action.op)
    end

    if action.materialFamily ~= nil and (type(action.materialFamily) ~= "string" or action.materialFamily == "") then
      return false, string.format("%s materialFamily must be a non-empty string when present", action.op)
    end

    if action.materialBaseMultiplier ~= nil and type(action.materialBaseMultiplier) ~= "number" then
      return false, string.format("%s materialBaseMultiplier must be numeric when present", action.op)
    end

    if action.materialRankStep ~= nil and type(action.materialRankStep) ~= "number" then
      return false, string.format("%s materialRankStep must be numeric when present", action.op)
    end

    return true
  end

  return true
end

function ScoreActions.apply(runState, stageState, context, action, options)
  if action.op == "add_stage_score" then
    applyStageScore(runState, stageState, context, action, options and options.additiveBonusFields or nil)
  elseif action.op == "add_run_score" then
    applyRunScore(runState, context, action)
  elseif action.op == "heal_opponent" then
    healOpponent(stageState, context, action)
  elseif action.op == "apply_score_scaling" or action.op == "apply_score_multiplier" then
    applyScoreScaling(context, action, options and options.recordWarning)
  else
    return false
  end

  return true
end

function ScoreActions.applyStageScore(runState, stageState, context, action, additiveBonusFields)
  applyStageScore(runState, stageState, context, action, additiveBonusFields)
end

return ScoreActions
