local ActionQueue = require("src.core.action_queue")
local Coins = require("src.content.coins")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local PurseSystem = require("src.systems.purse_system")
local ScoreBreakdown = require("src.domain.score_breakdown")
local Utils = require("src.core.utils")

local PurseHookSystem = {}

local function sourceExists(sources, instanceId)
  for _, source in ipairs(sources or {}) do
    if source.instanceId == instanceId or source.sourceId == instanceId then
      return true
    end
  end

  return false
end

local function ensureEventSources(runState, sources, eventCoins)
  for _, coinState in ipairs(eventCoins or {}) do
    if coinState.instanceId and not sourceExists(sources, coinState.instanceId) then
      local definition = Coins.getById(coinState.coinId)

      if definition then
        HookRegistry.insertSource(sources, HookRegistry.buildSource("equipped coin", coinState.instanceId, definition, {
          instanceId = coinState.instanceId,
          coinId = coinState.coinId,
          slotIndex = coinState.slotIndex,
        }))
      end
    end
  end
end

function PurseHookSystem.buildCoinState(runState, slot, slotIndex, overrides)
  overrides = overrides or {}
  local instanceId = overrides.instanceId or (slot and slot.instanceId)
  local coinId = overrides.coinId or overrides.definitionId or (slot and slot.definitionId) or PurseSystem.getDefinitionId(runState, instanceId)

  if not instanceId or not coinId then
    return nil
  end

  return {
    coinId = coinId,
    instanceId = instanceId,
    slotIndex = overrides.slotIndex or slotIndex,
    originalDrawIndex = overrides.originalDrawIndex or (slot and slot.originalDrawIndex),
    resolutionIndex = overrides.resolutionIndex or overrides.slotIndex or slotIndex,
    dealtIndex = overrides.dealtIndex or (slot and slot.dealtIndex),
    selectedSlotIndex = overrides.selectedSlotIndex or (slot and slot.selectedSlotIndex),
    foretold = slot and slot.foretold == true or false,
    foretoldResult = slot and slot.foretoldResult or nil,
    foretoldBy = slot and slot.foretoldBy or nil,
    foretoldRngRoll = slot and slot.foretoldRngRoll or nil,
    flags = {},
  }
end

function PurseHookSystem.buildHandCoinStates(runState, stageState)
  local eventCoins = {}

  for slotIndex, slot in ipairs(stageState and stageState.purse and stageState.purse.handSlots or {}) do
    local coinState = PurseHookSystem.buildCoinState(runState, slot, slotIndex)

    if coinState then
      table.insert(eventCoins, coinState)
    end
  end

  return eventCoins
end

function PurseHookSystem.buildDealtCoinStates(runState, stageState)
  local eventCoins = {}

  for dealtIndex, slot in ipairs(stageState and stageState.purse and stageState.purse.dealtHandSlots or {}) do
    local coinState = PurseHookSystem.buildCoinState(runState, slot, dealtIndex, {
      slotIndex = dealtIndex,
      originalDrawIndex = slot and slot.originalDrawIndex or dealtIndex,
      resolutionIndex = dealtIndex,
    })

    if coinState then
      table.insert(eventCoins, coinState)
    end
  end

  return eventCoins
end

function PurseHookSystem.runImmediatePhase(runState, stageState, metaProjection, phaseName, eventCoins, options)
  options = options or {}
  eventCoins = eventCoins or {}

  if #eventCoins == 0 then
    return nil
  end

  local context = ActionQueue.createContext("purse", {
    batchId = stageState.batchIndex + 1,
    call = options.call,
    runState = runState,
    stageState = stageState,
    metaProjection = metaProjection or runState.metaProjection,
    activeSources = HookRegistry.collectGlobalSources(runState, stageState, metaProjection or runState.metaProjection),
    purseEventCoins = eventCoins,
    scoreBreakdown = ScoreBreakdown.new(),
    rng = options.rng,
    actionMetrics = {
      appliedCount = 0,
      maxAppliedCount = GameConfig.get("engine.maxAppliedActionsPerBatch"),
      maxPendingActionDepth = GameConfig.get("engine.maxPendingActionDepth"),
      limitHit = false,
    },
    trace = {
      mode = "purse",
      phase = phaseName,
      batchId = stageState.batchIndex + 1,
      call = options.call,
      eventCoins = Utils.clone(eventCoins),
      triggeredSources = {},
      actions = {},
      notes = {},
      warnings = {},
      queuedActions = {},
      temporaryEffectsGranted = {},
      temporaryEffectsConsumed = {},
    },
  })

  ensureEventSources(runState, context.activeSources, eventCoins)

  local actions = HookRegistry.runPhase(phaseName, context.activeSources, context)
  context.currentPhase = phaseName
  context.currentChainDepth = 0
  ActionQueue.applyAll(runState, stageState, context, actions)
  context.currentPhase = nil

  if #context.trace.actions > 0 or #context.trace.triggeredSources > 0 or #context.trace.notes > 0 or #context.trace.warnings > 0 then
    local purse = PurseSystem.getStagePurse(runState, stageState)
    purse.hookHistory = purse.hookHistory or {}
    table.insert(purse.hookHistory, Utils.clone(context.trace))
  end

  return context.trace
end

function PurseHookSystem.runAfterHandDraw(runState, stageState, metaProjection, options)
  local purse = stageState and stageState.purse
  local latestDraw = purse and purse.drawHistory and purse.drawHistory[#purse.drawHistory] or nil

  if not latestDraw or latestDraw.afterHandDrawApplied == true then
    return nil
  end

  latestDraw.afterHandDrawApplied = true
  return PurseHookSystem.runImmediatePhase(
    runState,
    stageState,
    metaProjection,
    "after_hand_draw",
    PurseHookSystem.buildHandCoinStates(runState, stageState),
    options
  )
end

function PurseHookSystem.runAfterDealBeforeSelection(runState, stageState, metaProjection, options)
  local purse = stageState and stageState.purse
  local latestDraw = purse and purse.drawHistory and purse.drawHistory[#purse.drawHistory] or nil

  if not latestDraw or latestDraw.afterDealBeforeSelectionApplied == true then
    return nil
  end

  latestDraw.afterDealBeforeSelectionApplied = true
  return PurseHookSystem.runImmediatePhase(
    runState,
    stageState,
    metaProjection,
    "after_deal_before_selection",
    PurseHookSystem.buildDealtCoinStates(runState, stageState),
    options
  )
end

return PurseHookSystem
