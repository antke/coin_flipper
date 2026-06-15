local Coins = require("src.content.coins")
local ChainActions = require("src.core.actions.chain_actions")
local CoinChanceActions = require("src.core.actions.coin_chance_actions")
local EconomyActions = require("src.core.actions.economy_actions")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local IdentityActions = require("src.core.actions.identity_actions")
local Loadout = require("src.domain.loadout")
local PredictionActions = require("src.core.actions.prediction_actions")
local PurseActions = require("src.core.actions.purse_actions")
local ReplayActions = require("src.core.actions.replay_actions")
local ScoreBreakdown = require("src.domain.score_breakdown")
local ScoreActions = require("src.core.actions.score_actions")
local ShopActions = require("src.core.actions.shop_actions")
local TargetSelectors = require("src.core.target_selectors")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local ActionQueue = {}

local PurseSystem = require("src.systems.purse_system")

ActionQueue.ACQUISITION_SAFE_OPS = {
  add_influence = true,
  add_shop_points = true,
  add_shop_rerolls = true,
  increase_coin_slots = true,
  grant_coin = true,
  grant_trick = true,
  grant_upgrade = true,
  queue_trace_note = true,
  set_run_flag = true,
}

ActionQueue.KNOWN_OPS = {
  add_stage_score = true,
  add_run_score = true,
  add_influence = true,
  add_shop_points = true,
  add_luck = true,
  add_weight = true,
  set_call_match_chance = true,
  foretell_coin_result = true,
  forge_identity = true,
  redirect_score_credit = true,
  swap_coins = true,
  smuggle_coin_from_hand = true,
  replay_resolution_packet = true,
  trigger_random_neighbor = true,
  modify_coin_weight = true,
  apply_score_scaling = true,
  apply_score_multiplier = true,
  set_batch_flag = true,
  set_shop_flag = true,
  set_stage_flag = true,
  set_run_flag = true,
  queue_trace_note = true,
  grant_trick = true,
  grant_upgrade = true,
  grant_coin = true,
  increase_coin_slots = true,
  add_shop_rerolls = true,
  set_flips_remaining = true,
  consume_effect = true,
  add_shop_offer = true,
  adjust_shop_price = true,
  block_purchase = true,
  add_shop_message = true,
  mark_shop_offer_purchased = true,
  record_purchase = true,
  grant_temporary_effect = true,
  queue_actions = true,
}

local function ensureTrace(context)
  context.trace = context.trace or {}
  context.trace.actions = context.trace.actions or {}
  context.trace.notes = context.trace.notes or {}
  context.trace.warnings = context.trace.warnings or {}
  context.trace.queuedActions = context.trace.queuedActions or {}
  context.trace.temporaryEffectsGranted = context.trace.temporaryEffectsGranted or {}
  context.trace.temporaryEffectsConsumed = context.trace.temporaryEffectsConsumed or {}
end

local function requireStageState(stageState, op)
  if not stageState then
    error(string.format("%s requires an active stageState", op))
  end
end

local function ensureScoreBreakdown(context)
  context.scoreBreakdown = context.scoreBreakdown or ScoreBreakdown.new()

  local scoreScalings = context.scoreBreakdown.scoreScalings or context.scoreBreakdown.multipliers or {}
  context.scoreBreakdown.scoreScalings = scoreScalings
  context.scoreBreakdown.multipliers = scoreScalings
end

local function ensurePendingActionContext(context)
  context.pendingActions = context.pendingActions or {}
end

local function recordWarning(context, message)
  ensureTrace(context)
  table.insert(context.trace.warnings, message)
  table.insert(context.trace.notes, message)
end

local function getOnceKey(action, defaultKey)
  if type(action.onceKey) == "string" and action.onceKey ~= "" then
    return action.onceKey
  end

  return defaultKey
end

local function claimOnce(context, key, warning)
  context.onceFlags = context.onceFlags or {}

  if context.onceFlags[key] == true then
    recordWarning(context, warning)
    return false
  end

  context.onceFlags[key] = true
  return true
end

local function cloneActionForTrace(action)
  local tracedAction = Utils.clone(action)
  tracedAction._trace = tracedAction._trace or nil
  return tracedAction
end

function ActionQueue.createContext(mode, overrides)
  local context = {
    runState = nil,
    stageState = nil,
    metaProjection = {
      modifiers = {},
    },
    batchFlags = {},
    shopFlags = {},
    shopOffers = {},
    currentOffer = nil,
    purchase = nil,
    shopMessages = {},
    activeSources = {},
    pendingActions = {},
    currentPhase = nil,
    currentChainDepth = 0,
    actionMetrics = nil,
    trace = {
      mode = mode or "generic",
      actions = {},
      notes = {},
      messages = {},
    },
  }

  for key, value in pairs(overrides or {}) do
    if key == "trace" and type(value) == "table" then
      for traceKey, traceValue in pairs(value) do
        context.trace[traceKey] = traceValue
      end
    else
      context[key] = value
    end
  end

  context.metaProjection = context.metaProjection or { modifiers = {} }
  context.batchFlags = context.batchFlags or {}
  context.shopFlags = context.shopFlags or {}
  context.shopOffers = context.shopOffers or {}
  context.shopMessages = context.shopMessages or {}
  context.activeSources = context.activeSources or {}
  context.pendingActions = context.pendingActions or {}
  ensureTrace(context)

  return context
end

function ActionQueue.isAcquisitionSafeAction(action)
  return action and ActionQueue.ACQUISITION_SAFE_OPS[action.op] == true
end

local function cloneOnAcquireActions(actionList)
  local cloned = {}

  for _, action in ipairs(actionList or {}) do
    local nextAction = Utils.clone(action)

    if (nextAction.op == "add_influence" or nextAction.op == "add_shop_points") and nextAction.applyMultiplier == nil then
      nextAction.applyMultiplier = false
    end

    table.insert(cloned, nextAction)
  end

  return cloned
end

local function cloneQueuedActions(actionList)
  local cloned = {}

  for _, queuedAction in ipairs(actionList or {}) do
    table.insert(cloned, Utils.clone(queuedAction))
  end

  return cloned
end

local function validateQueuedActions(actionList)
  if type(actionList) ~= "table" then
    return false, "queue_actions requires actions table"
  end

  for _, queuedAction in ipairs(actionList) do
    local ok, errorMessage = ActionQueue.validateAction(queuedAction)

    if not ok then
      return false, errorMessage
    end
  end

  return true
end

local function collectConditionFlagKeysFromActions(actionList, flagKeys)
  for _, action in ipairs(actionList or {}) do
    if (action.op == "set_batch_flag" or action.op == "set_shop_flag") and type(action.flag) == "string" and action.flag ~= "" then
      flagKeys[action.flag] = true
    elseif action.op == "queue_actions" then
      collectConditionFlagKeysFromActions(action.actions, flagKeys)
    elseif action.op == "grant_temporary_effect" and type(action.effect) == "table" then
      for _, trigger in ipairs(action.effect.triggers or {}) do
        collectConditionFlagKeysFromActions(trigger.effects, flagKeys)
      end
    end
  end
end

local function validateTemporaryEffectDefinition(effect)
  if type(effect) ~= "table" then
    return false, "grant_temporary_effect requires effect table"
  end

  if type(effect.id) ~= "string" or effect.id == "" then
    return false, "temporary effect requires id"
  end

  if type(effect.name) ~= "string" or effect.name == "" then
    return false, "temporary effect requires name"
  end

  if effect.priorityLayer ~= nil and type(effect.priorityLayer) ~= "number" then
    return false, "temporary effect priorityLayer must be numeric"
  end

  if effect.customResolver ~= nil then
    if type(effect.customResolver) ~= "string" or effect.customResolver == "" then
      return false, "temporary effect customResolver must be non-empty string"
    end

    local ok, resolverModule = pcall(require, effect.customResolver)

    if not ok then
      return false, string.format("temporary effect customResolver %s could not be required", effect.customResolver)
    end

    if type(resolverModule) ~= "table" or type(resolverModule.resolve) ~= "function" then
      return false, string.format("temporary effect customResolver %s must export resolve", effect.customResolver)
    end
  end

  local ok, errorMessage = EffectiveValueSystem.validateEffectiveValuesTable(effect.effectiveValues)

  if not ok then
    return false, string.format("temporary effect %s has invalid effectiveValues: %s", effect.id, errorMessage)
  end

  local allowedFlagKeys = HookRegistry.getSystemConditionFlagKeys()
  for _, trigger in ipairs(effect.triggers or {}) do
    collectConditionFlagKeysFromActions(trigger.effects, allowedFlagKeys)
  end

  for _, trigger in ipairs(effect.triggers or {}) do
    if not HookRegistry.isValidPhase(trigger.hook) then
      return false, string.format("temporary effect %s uses invalid hook %s", effect.id, tostring(trigger.hook))
    end

    ok, errorMessage = HookRegistry.validateCondition(trigger.condition, allowedFlagKeys, trigger.hook)

    if not ok then
      return false, string.format("temporary effect %s has invalid condition: %s", effect.id, errorMessage)
    end

    ok, errorMessage = validateQueuedActions(trigger.effects or {})

    if not ok then
      return false, string.format("temporary effect %s has invalid effect: %s", effect.id, errorMessage)
    end

    for _, nestedAction in ipairs(trigger.effects or {}) do
      if nestedAction.op == "queue_actions" then
        local triggerOrder = HookRegistry.getPhaseOrder(trigger.hook)
        local targetOrder = HookRegistry.getPhaseOrder(nestedAction.phase)

        if triggerOrder and targetOrder and targetOrder < triggerOrder then
          return false, string.format(
            "temporary effect %s queues phase %s before enclosing phase %s",
            effect.id,
            tostring(nestedAction.phase),
            tostring(trigger.hook)
          )
        end
      end
    end
  end

  return true
end

local function canApplyAnotherAction(context)
  ensureTrace(context)

  if not context.actionMetrics then
    return true
  end

  if context.actionMetrics.appliedCount >= context.actionMetrics.maxAppliedCount then
    if not context.actionMetrics.limitHit then
      context.actionMetrics.limitHit = true
      recordWarning(context, string.format("Action limit hit at %d applications; skipping remaining actions.", context.actionMetrics.maxAppliedCount))
    end

    return false
  end

  return true
end

local function buildTemporaryEffectInstance(runState, context, effectDefinition, trace)
  runState.counters.temporaryEffectInstances = (runState.counters.temporaryEffectInstances or 0) + 1

  local instance = Utils.clone(effectDefinition)
  local baseId = effectDefinition.id
  local instanceId = string.format("%s__%d", baseId, runState.counters.temporaryEffectInstances)

  instance.id = instanceId
  instance.baseEffectId = baseId
  instance.grantedAtBatchId = context.batchId
  instance.grantedAtPhase = context.currentPhase
  instance.grantedBy = Utils.clone(trace)

  return instance
end

local function grantCoinFromAction(runState, action)
  local definition = Coins.getById(action.coinId)

  if not definition then
    error("unknown_coin")
  end

  PurseSystem.createInstance(runState, action.coinId)

  return definition
end

local function grantUpgradeFromAction(runState, stageState, context, action)
  local trickId = action.trickId or action.upgradeId
  local definition = Upgrades.getById(trickId)

  if not definition then
    error("unknown_upgrade")
  end

  runState.ownedTrickIds = runState.ownedTrickIds or runState.ownedUpgradeIds or {}
  runState.ownedUpgradeIds = runState.ownedTrickIds

  if not Utils.contains(runState.ownedTrickIds, trickId) then
    table.insert(runState.ownedTrickIds, trickId)
    ActionQueue.applyAll(runState, stageState, context, cloneOnAcquireActions(definition.onAcquire))
  end

  return definition
end

function ActionQueue.validateAction(action)
  if type(action) ~= "table" then
    return false, "action must be a table"
  end

  if not ActionQueue.KNOWN_OPS[action.op] then
    return false, string.format("unknown op: %s", tostring(action.op))
  end

  if action.onceKey ~= nil and (type(action.onceKey) ~= "string" or action.onceKey == "") then
    return false, "action onceKey must be a non-empty string when present"
  end

  if ScoreActions.isScoreOp(action.op) then
    return ScoreActions.validate(action)
  end

  if EconomyActions.isEconomyOp(action.op) then
    return EconomyActions.validate(action)
  end

  if CoinChanceActions.isChanceOp(action.op) then
    return CoinChanceActions.validate(action, TargetSelectors)
  end

  if PredictionActions.isPredictionOp(action.op) then
    return PredictionActions.validate(action, TargetSelectors)
  end

  if IdentityActions.isIdentityOp(action.op) then
    return IdentityActions.validate(action, TargetSelectors)
  end

  if PurseActions.isPurseOp(action.op) then
    return PurseActions.validate(action, TargetSelectors)
  end

  if ReplayActions.isReplayOp(action.op) then
    return ReplayActions.validate(action, TargetSelectors)
  end

  if ChainActions.isChainOp(action.op) then
    return ChainActions.validate(action, TargetSelectors)
  end

  if ShopActions.isShopOp(action.op) then
    return ShopActions.validate(action)
  end

  if (action.op == "set_batch_flag" or action.op == "set_shop_flag" or action.op == "set_stage_flag" or action.op == "set_run_flag")
    and (type(action.flag) ~= "string" or action.flag == "") then
    return false, string.format("%s requires flag", action.op)
  end

  if (action.op == "set_batch_flag" or action.op == "set_shop_flag" or action.op == "set_stage_flag" or action.op == "set_run_flag")
    and action.value ~= nil and type(action.value) ~= "boolean" then
    return false, string.format("%s value must be boolean when present", action.op)
  end

  if action.op == "queue_trace_note" and action.note ~= nil and type(action.note) ~= "string" then
    return false, "queue_trace_note note must be a string"
  end

  if action.op == "grant_trick" or action.op == "grant_upgrade" then
    local trickId = action.trickId or action.upgradeId

    if type(trickId) ~= "string" or trickId == "" then
      return false, string.format("%s requires trickId", action.op)
    end

    if not Upgrades.getById(trickId) then
      return false, string.format("%s references unknown Trick %s", action.op, tostring(trickId))
    end
  end

  if action.op == "grant_coin" and (type(action.coinId) ~= "string" or action.coinId == "") then
    return false, "grant_coin requires coinId"
  end

  if action.op == "grant_coin" and not Coins.getById(action.coinId) then
    return false, string.format("grant_coin references unknown coin %s", tostring(action.coinId))
  end

  if action.op == "grant_temporary_effect" then
    local ok, errorMessage = validateTemporaryEffectDefinition(action.effect)

    if not ok then
      return false, errorMessage
    end
  end

  if action.op == "queue_actions" then
    if type(action.phase) ~= "string" or action.phase == "" then
      return false, "queue_actions requires phase"
    end

    if not HookRegistry.isValidPhase(action.phase) then
      return false, string.format("queue_actions uses invalid phase %s", tostring(action.phase))
    end

    local ok, errorMessage = validateQueuedActions(action.actions)

    if not ok then
      return false, errorMessage
    end
  end

  if action.op == "increase_coin_slots" and not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
    return false, "increase_coin_slots requires integer amount"
  end

  if action.op == "set_flips_remaining" and not (type(action.value) == "number" and math.floor(action.value) == action.value) then
    return false, "set_flips_remaining requires integer value"
  end

  if action.op == "set_flips_remaining" and action.value < 0 then
    return false, "set_flips_remaining requires non-negative value"
  end

  if action.op == "consume_effect" and action.effectId ~= nil and (type(action.effectId) ~= "string" or action.effectId == "") then
    return false, "consume_effect requires effectId"
  end

  return true
end

function ActionQueue.apply(runState, stageState, context, action)
  ensureTrace(context)

  if ScoreActions.isScoreOp(action.op) then
    ScoreActions.apply(runState, stageState, context, action, {
      recordWarning = recordWarning,
    })
  elseif EconomyActions.isEconomyOp(action.op) then
    EconomyActions.apply(runState, stageState, context, action)
  elseif CoinChanceActions.isChanceOp(action.op) then
    CoinChanceActions.apply(runState, context, action, { recordWarning = recordWarning })
  elseif PredictionActions.isPredictionOp(action.op) then
    PredictionActions.apply(runState, stageState, context, action, { recordWarning = recordWarning })
  elseif IdentityActions.isIdentityOp(action.op) then
    IdentityActions.apply(context, action, {
      recordWarning = recordWarning,
      claimOnce = claimOnce,
      getOnceKey = getOnceKey,
    })
  elseif PurseActions.isPurseOp(action.op) then
    PurseActions.apply(runState, stageState, context, action, { recordWarning = recordWarning })
  elseif ReplayActions.isReplayOp(action.op) then
    ReplayActions.apply(runState, stageState, context, action, {
      recordWarning = recordWarning,
      claimOnce = claimOnce,
      getOnceKey = getOnceKey,
    })
  elseif ChainActions.isChainOp(action.op) then
    ChainActions.apply(context, action, {
      recordWarning = recordWarning,
      claimOnce = claimOnce,
      getOnceKey = getOnceKey,
    })
  elseif action.op == "set_batch_flag" then
    context.batchFlags[action.flag] = action.value ~= false
  elseif action.op == "set_shop_flag" then
    context.shopFlags = context.shopFlags or {}
    context.shopFlags[action.flag] = action.value ~= false
  elseif action.op == "set_stage_flag" then
    requireStageState(stageState, action.op)
    stageState.flags[action.flag] = action.value ~= false
  elseif action.op == "set_run_flag" then
    runState.flags[action.flag] = action.value ~= false
  elseif action.op == "queue_trace_note" then
    ensureScoreBreakdown(context)
    table.insert(context.trace.notes, action.note or "(empty note)")
    table.insert(context.scoreBreakdown.notes, action.note or "(empty note)")
  elseif action.op == "grant_trick" or action.op == "grant_upgrade" then
    grantUpgradeFromAction(runState, stageState, context, action)
  elseif action.op == "grant_coin" then
    grantCoinFromAction(runState, action)
  elseif action.op == "increase_coin_slots" then
    runState.maxFlipSlots = math.max(1, runState.maxFlipSlots + action.amount)
    runState.flipSlots = Loadout.normalizeSlots(runState.flipSlots, runState.maxFlipSlots)
    runState.persistedFlipSlots = Loadout.normalizeSlots(runState.persistedFlipSlots, runState.maxFlipSlots)
  elseif action.op == "set_flips_remaining" then
    requireStageState(stageState, action.op)
    stageState.flipsRemaining = math.max(0, action.value)
  elseif action.op == "consume_effect" then
    if not action.effectId then
      error("consume_effect requires effectId")
    end

    for index, effect in ipairs(runState.temporaryRunEffects) do
      if effect.id == action.effectId then
        table.remove(runState.temporaryRunEffects, index)
        break
      end
    end

    if context.activeSources then
      HookRegistry.removeSourceById(context.activeSources, action.effectId)
    end

    table.insert(context.trace.temporaryEffectsConsumed, action.effectId)
  elseif action.op == "grant_temporary_effect" then
    local instance = buildTemporaryEffectInstance(runState, context, action.effect, action._trace)
    runState.temporaryRunEffects = runState.temporaryRunEffects or {}
    table.insert(runState.temporaryRunEffects, instance)

    -- Outside batch resolution, temporary effects are still stored for later batches,
    -- but only batch resolution currently reuses the evolving active source list mid-transaction.
    if context.activeSources then
      HookRegistry.insertSource(context.activeSources, HookRegistry.buildSource("temporary effect", instance.id, instance))
    end

    table.insert(context.trace.temporaryEffectsGranted, {
      id = instance.id,
      baseEffectId = instance.baseEffectId,
      name = instance.name,
      phase = context.currentPhase,
    })
  elseif action.op == "queue_actions" then
    ensurePendingActionContext(context)
    local canQueue = true

    if context.trace and context.trace.mode ~= "batch" then
      recordWarning(context, string.format("queue_actions ignored in non-batch context (%s).", tostring(context.trace.mode)))
      canQueue = false
    end

    local nextDepth = (context.currentChainDepth or 0) + 1
    local maxDepth = context.actionMetrics and context.actionMetrics.maxPendingActionDepth or GameConfig.get("engine.maxPendingActionDepth")
    local currentPhaseOrder = HookRegistry.getPhaseOrder(context.currentPhase)
    local targetPhaseOrder = HookRegistry.getPhaseOrder(action.phase)

    if canQueue and currentPhaseOrder and targetPhaseOrder and targetPhaseOrder < currentPhaseOrder then
      recordWarning(context, string.format("Queued action for already-passed phase %s was dropped.", action.phase))
      canQueue = false
    elseif canQueue and nextDepth > maxDepth then
      recordWarning(context, string.format("Queued action chain dropped at depth %d for phase %s.", nextDepth, action.phase))
      canQueue = false
    end

    if canQueue then
      context.pendingActions[action.phase] = context.pendingActions[action.phase] or {}
      table.insert(context.pendingActions[action.phase], {
        phase = action.phase,
        chainDepth = nextDepth,
        actions = cloneQueuedActions(action.actions),
        queuedBy = Utils.clone(action._trace),
      })

      table.insert(context.trace.queuedActions, {
        phase = action.phase,
        chainDepth = nextDepth,
        actionCount = #(action.actions or {}),
      })
    end
  elseif ShopActions.isShopOp(action.op) then
    ShopActions.apply(runState, context, action)
  end

  table.insert(context.trace.actions, cloneActionForTrace(action))
end

function ActionQueue.applyAll(runState, stageState, context, actionList)
  for _, action in ipairs(actionList or {}) do
    if not canApplyAnotherAction(context) then
      break
    end

    local ok, errorMessage = ActionQueue.validateAction(action)

    if not ok then
      error(errorMessage)
    end

    if context.actionMetrics then
      context.actionMetrics.appliedCount = context.actionMetrics.appliedCount + 1
    end

    ActionQueue.apply(runState, stageState, context, action)
  end
end

return ActionQueue
