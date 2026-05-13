local Coins = require("src.content.coins")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local Loadout = require("src.domain.loadout")
local ScoreBreakdown = require("src.domain.score_breakdown")
local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local ActionQueue = {}

local PurseSystem = require("src.systems.purse_system")

ActionQueue.ACQUISITION_SAFE_OPS = {
  add_shop_points = true,
  add_shop_rerolls = true,
  increase_coin_slots = true,
  grant_coin = true,
  grant_upgrade = true,
  queue_trace_note = true,
  set_run_flag = true,
}

ActionQueue.KNOWN_OPS = {
  add_stage_score = true,
  add_run_score = true,
  add_shop_points = true,
  modify_coin_weight = true,
  apply_score_multiplier = true,
  set_batch_flag = true,
  set_shop_flag = true,
  set_stage_flag = true,
  set_run_flag = true,
  increment_streak = true,
  reset_streak = true,
  queue_trace_note = true,
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
end

local function ensureShopContext(context)
  context.shopOffers = context.shopOffers or {}
  context.shopMessages = context.shopMessages or {}
end

local function ensurePendingActionContext(context)
  context.pendingActions = context.pendingActions or {}
end

local function recordWarning(context, message)
  ensureTrace(context)
  table.insert(context.trace.warnings, message)
  table.insert(context.trace.notes, message)
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

    if nextAction.op == "add_shop_points" and nextAction.applyMultiplier == nil then
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
  local definition = Upgrades.getById(action.upgradeId)

  if not definition then
    error("unknown_upgrade")
  end

  if not Utils.contains(runState.ownedUpgradeIds, action.upgradeId) then
    table.insert(runState.ownedUpgradeIds, action.upgradeId)
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

  if action.op == "add_stage_score" or action.op == "add_run_score" or action.op == "add_shop_points" then
    if type(action.amount) ~= "number" then
      return false, string.format("%s requires numeric amount", action.op)
    end

    if action.applyMultiplier ~= nil and type(action.applyMultiplier) ~= "boolean" then
      return false, string.format("%s applyMultiplier must be boolean", action.op)
    end
  end

  if action.op == "modify_coin_weight" then
    if (action.side ~= "heads") and (action.side ~= "tails") then
      return false, "modify_coin_weight requires side=heads|tails"
    end

    if type(action.amount) ~= "number" then
      return false, "modify_coin_weight requires numeric amount"
    end
  end

  if action.op == "apply_score_multiplier" and type(action.value) ~= "number" then
    return false, "apply_score_multiplier requires numeric value"
  end

  if (action.op == "set_batch_flag" or action.op == "set_shop_flag" or action.op == "set_stage_flag" or action.op == "set_run_flag")
    and (type(action.flag) ~= "string" or action.flag == "") then
    return false, string.format("%s requires flag", action.op)
  end

  if (action.op == "set_batch_flag" or action.op == "set_shop_flag" or action.op == "set_stage_flag" or action.op == "set_run_flag")
    and action.value ~= nil and type(action.value) ~= "boolean" then
    return false, string.format("%s value must be boolean when present", action.op)
  end

  if action.op == "increment_streak" then
    if action.counter ~= nil and type(action.counter) ~= "string" then
      return false, "increment_streak counter must be a string"
    end

    if action.amount ~= nil and not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
      return false, "increment_streak amount must be integer"
    end
  end

  if action.op == "reset_streak" and action.counter ~= nil and type(action.counter) ~= "string" then
    return false, "reset_streak counter must be a string"
  end

  if action.op == "queue_trace_note" and action.note ~= nil and type(action.note) ~= "string" then
    return false, "queue_trace_note note must be a string"
  end

  if action.op == "grant_upgrade" and (type(action.upgradeId) ~= "string" or action.upgradeId == "") then
    return false, "grant_upgrade requires upgradeId"
  end

  if action.op == "grant_upgrade" and not Upgrades.getById(action.upgradeId) then
    return false, string.format("grant_upgrade references unknown upgrade %s", tostring(action.upgradeId))
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

  if action.op == "add_shop_offer" then
    if action.offerType ~= "coin" and action.offerType ~= "upgrade" then
      return false, "add_shop_offer requires offerType=coin|upgrade"
    end

    if type(action.contentId) ~= "string" or action.contentId == "" then
      return false, "add_shop_offer requires contentId"
    end

    if action.price ~= nil and type(action.price) ~= "number" then
      return false, "add_shop_offer price must be numeric"
    end

    if action.price ~= nil and action.price < 0 then
      return false, "add_shop_offer price must be non-negative"
    end

    local definition = action.offerType == "coin" and Coins.getById(action.contentId) or Upgrades.getById(action.contentId)

    if not definition then
      return false, string.format("add_shop_offer references unknown %s %s", action.offerType, tostring(action.contentId))
    end
  end

  if action.op == "adjust_shop_price" then
    if type(action.delta) ~= "number" then
      return false, "adjust_shop_price requires numeric delta"
    end

    if action.offerType ~= nil and action.offerType ~= "coin" and action.offerType ~= "upgrade" then
      return false, "adjust_shop_price offerType must be coin|upgrade"
    end

    if action.contentId ~= nil and (type(action.contentId) ~= "string" or action.contentId == "") then
      return false, "adjust_shop_price contentId must be non-empty string"
    end

    if action.rarity ~= nil and (type(action.rarity) ~= "string" or action.rarity == "") then
      return false, "adjust_shop_price rarity must be non-empty string"
    end
  end

  if action.op == "block_purchase" and action.reason ~= nil and type(action.reason) ~= "string" then
    return false, "block_purchase reason must be a string"
  end

  if action.op == "add_shop_message" and type(action.message) ~= "string" then
    return false, "add_shop_message requires a message"
  end

   if action.op == "record_purchase" then
    if action.purchaseType ~= "coin" and action.purchaseType ~= "upgrade" then
      return false, "record_purchase requires purchaseType=coin|upgrade"
    end

    if type(action.contentId) ~= "string" or action.contentId == "" then
      return false, "record_purchase requires contentId"
    end

      if type(action.price) ~= "number" then
      return false, "record_purchase requires numeric price"
    end

    if action.price < 0 then
      return false, "record_purchase price must be non-negative"
    end

    if action.purchaseType == "coin" and not Coins.getById(action.contentId) then
      return false, string.format("record_purchase references unknown coin %s", tostring(action.contentId))
    end

    if action.purchaseType == "upgrade" and not Upgrades.getById(action.contentId) then
      return false, string.format("record_purchase references unknown upgrade %s", tostring(action.contentId))
    end
  end

  if action.op == "increase_coin_slots" and not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
    return false, "increase_coin_slots requires integer amount"
  end

  if action.op == "add_shop_rerolls" and not (type(action.amount) == "number" and math.floor(action.amount) == action.amount) then
    return false, "add_shop_rerolls requires integer amount"
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

  if action.op == "add_stage_score" then
    ensureScoreBreakdown(context)
    requireStageState(stageState, action.op)
    stageState.stageScore = stageState.stageScore + action.amount
    context.scoreBreakdown.totalStageScoreDelta = context.scoreBreakdown.totalStageScoreDelta + action.amount
    runState.shopPoints = runState.shopPoints + action.amount
    context.scoreBreakdown.totalShopPointDelta = context.scoreBreakdown.totalShopPointDelta + action.amount

    table.insert(context.scoreBreakdown.shopPointChanges, {
      op = "add_shop_points",
      amount = action.amount,
      appliedAmount = action.amount,
      category = "stage_score_chips",
      label = action.label or "Stage score chips",
      trace = Utils.clone(action._trace),
    })

    if action.category ~= "base_score" then
      addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, {
        scoreTarget = "stage",
      })
    end
  elseif action.op == "add_run_score" then
    ensureScoreBreakdown(context)
    runState.runTotalScore = runState.runTotalScore + action.amount
    context.scoreBreakdown.totalRunScoreDelta = context.scoreBreakdown.totalRunScoreDelta + action.amount

    if action.category ~= "base_score" then
      addScoreBreakdownEntry(context.scoreBreakdown.additiveBonuses, action, {
        scoreTarget = "run",
      })
    end
  elseif action.op == "add_shop_points" then
    ensureScoreBreakdown(context)
    local multiplier = 1.0

    if action.applyMultiplier ~= false then
      multiplier = EffectiveValueSystem.getEffectiveValue("economy.shopPointMultiplier", runState, stageState, {
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

    runState.shopPoints = runState.shopPoints + scaledAmount
    context.scoreBreakdown.totalShopPointDelta = context.scoreBreakdown.totalShopPointDelta + scaledAmount

    local appliedAction = Utils.clone(action)
    appliedAction.appliedAmount = scaledAmount
    table.insert(context.scoreBreakdown.shopPointChanges, appliedAction)
  elseif action.op == "modify_coin_weight" then
    local targets = {}

    if context.currentCoin then
      targets = { context.currentCoin }
    elseif action.coinId then
      for _, coinState in ipairs(context.perCoin or {}) do
        if coinState.coinId == action.coinId then
          table.insert(targets, coinState)
        end
      end
    else
      targets = context.perCoin or {}
    end

    for _, coinState in ipairs(targets) do
      local fieldName = action.side .. "Weight"
      coinState[fieldName] = math.max(0, coinState[fieldName] + action.amount)
      coinState.weightChanges = coinState.weightChanges or {}
      table.insert(coinState.weightChanges, cloneActionForTrace(action))
    end
  elseif action.op == "apply_score_multiplier" then
    ensureScoreBreakdown(context)
    context.pendingScoreMultiplier = (context.pendingScoreMultiplier or 1.0) * action.value
    table.insert(context.scoreBreakdown.multipliers, cloneActionForTrace(action))
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
  elseif action.op == "increment_streak" then
    requireStageState(stageState, action.op)
    local counterName = action.counter or "consecutiveMatches"
    stageState.streak[counterName] = (stageState.streak[counterName] or 0) + (action.amount or 1)
  elseif action.op == "reset_streak" then
    requireStageState(stageState, action.op)
    stageState.streak[action.counter or "consecutiveMatches"] = 0
  elseif action.op == "queue_trace_note" then
    ensureScoreBreakdown(context)
    table.insert(context.trace.notes, action.note or "(empty note)")
    table.insert(context.scoreBreakdown.notes, action.note or "(empty note)")
  elseif action.op == "grant_upgrade" then
    grantUpgradeFromAction(runState, stageState, context, action)
  elseif action.op == "grant_coin" then
    grantCoinFromAction(runState, action)
  elseif action.op == "increase_coin_slots" then
    runState.maxActiveCoinSlots = math.max(1, runState.maxActiveCoinSlots + action.amount)
    runState.equippedCoinSlots = Loadout.normalizeSlots(runState.equippedCoinSlots, runState.maxActiveCoinSlots)
    runState.persistedLoadoutSlots = Loadout.normalizeSlots(runState.persistedLoadoutSlots, runState.maxActiveCoinSlots)
  elseif action.op == "add_shop_rerolls" then
    runState.shopRerollsRemaining = math.max(0, (runState.shopRerollsRemaining or 0) + action.amount)
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
  elseif action.op == "add_shop_offer" then
    ensureShopContext(context)

    local definition = action.offerType == "coin" and Coins.getById(action.contentId) or Upgrades.getById(action.contentId)

    if definition then
      local ownedList = action.offerType == "coin" and runState.collectionCoinIds or runState.ownedUpgradeIds
      local alreadyOffered = false

      for _, offer in ipairs(context.shopOffers) do
        if offer.contentId == action.contentId then
          alreadyOffered = true
          break
        end
      end

      if not Utils.contains(ownedList, action.contentId) and not alreadyOffered then
        table.insert(context.shopOffers, {
          type = action.offerType,
          contentId = action.contentId,
          name = definition.name,
          rarity = definition.rarity,
          price = action.price or ShopContent.resolvePrice(action.offerType, definition),
          purchased = false,
          injectedBy = Utils.clone(action._trace),
          tags = Utils.copyArray(definition.tags or {}),
        })
      end
    end
  elseif action.op == "adjust_shop_price" then
    ensureShopContext(context)

    local targets = {}

    if context.currentOffer then
      targets = { context.currentOffer }
    else
      targets = context.shopOffers
    end

    for _, offer in ipairs(targets) do
      local matchesType = action.offerType == nil or offer.type == action.offerType
      local matchesContent = action.contentId == nil or offer.contentId == action.contentId
      local matchesRarity = action.rarity == nil or offer.rarity == action.rarity

      if matchesType and matchesContent and matchesRarity then
        offer.price = math.max(0, (offer.price or 0) + action.delta)
        offer.priceAdjustments = offer.priceAdjustments or {}
        table.insert(offer.priceAdjustments, cloneActionForTrace(action))
      end
    end
  elseif action.op == "block_purchase" then
    context.purchaseBlocked = true
    context.purchaseBlockReason = action.reason or "purchase_blocked"
  elseif action.op == "add_shop_message" then
    ensureShopContext(context)
    table.insert(context.shopMessages, action.message)
  elseif action.op == "mark_shop_offer_purchased" then
    if context.currentOffer then
      context.currentOffer.purchased = true
    end
  elseif action.op == "record_purchase" then
    table.insert(runState.history.purchases, {
      type = action.purchaseType,
      contentId = action.contentId,
      price = action.price,
    })
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
