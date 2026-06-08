local GameConfig = require("src.app.config")
local Utils = require("src.core.utils")

local LuckSystem = {}

local function toInteger(value, defaultValue)
  local numeric = tonumber(value)

  if numeric == nil then
    return defaultValue or 0
  end

  return math.floor(numeric)
end

local function toNumber(value, defaultValue)
  local numeric = tonumber(value)

  if numeric == nil then
    return defaultValue or 0
  end

  return numeric
end

function LuckSystem.formatAmount(value)
  local amount = tonumber(value) or 0

  if math.floor(amount) == amount then
    return string.format("%d", amount)
  end

  local formatted = string.format("%.2f", amount):gsub("0+$", ""):gsub("%.$", "")
  return formatted
end

local function getConfiguredMax()
  return math.max(1, toInteger(GameConfig.get("luck.fatedFlipThreshold", 12), 12))
end

local function ensureTrace(context)
  if not context then
    return nil
  end

  context.trace = context.trace or {}
  context.trace.luck = context.trace.luck or {
    deltas = {},
  }

  return context.trace.luck
end

local function runLuckPhase(runState, context, phaseName, event)
  if not context or not context.activeSources then
    return
  end

  local HookRegistry = require("src.core.hook_registry")
  local ActionQueue = require("src.core.action_queue")
  local previousPhase = context.currentPhase
  local previousLuckGainEvent = context.currentLuckGainEvent

  context.currentPhase = phaseName
  context.currentLuckGainEvent = event
  local actions = HookRegistry.runPhase(phaseName, context.activeSources, context)
  ActionQueue.applyAll(runState, context.stageState, context, actions)
  context.currentLuckGainEvent = previousLuckGainEvent
  context.currentPhase = previousPhase
end

local function snapshot(runState)
  local luck = LuckSystem.normalize(runState)

  return {
    value = luck.value,
    max = luck.max,
    fatedFlipActive = luck.fatedFlipActive == true,
    fatedFlipGeneratesLuck = luck.fatedFlipGeneratesLuck == true,
    fountainFavor = luck.fountainFavor,
  }
end

function LuckSystem.normalize(runState)
  if not runState then
    return {
      value = 0,
      max = getConfiguredMax(),
      fatedFlipActive = false,
      fatedFlipGeneratesLuck = GameConfig.get("luck.fatedFlipGeneratesLuck", false) == true,
      fountainFavor = 0,
    }
  end

  local luck = runState.luck

  if type(luck) ~= "table" then
    luck = {}
    runState.luck = luck
  end

  local configuredFatedGeneration = GameConfig.get("luck.fatedFlipGeneratesLuck", false) == true

  luck.max = math.max(1, toInteger(luck.max, getConfiguredMax()))
  luck.value = Utils.clamp(toNumber(luck.value, 0), 0, luck.max)
  luck.fatedFlipActive = luck.fatedFlipActive == true or luck.value >= luck.max
  if luck.fatedFlipGeneratesLuck == nil then
    luck.fatedFlipGeneratesLuck = configuredFatedGeneration
  else
    luck.fatedFlipGeneratesLuck = luck.fatedFlipGeneratesLuck == true
  end

  luck.fountainFavor = math.max(0, toNumber(luck.fountainFavor, 0))

  return luck
end

function LuckSystem.ensureTrace(context)
  local trace = ensureTrace(context)

  if trace and trace.before == nil and context and context.runState then
    trace.before = snapshot(context.runState)
    trace.wasFatedFlip = context.luck and context.luck.wasFatedFlip == true or false
    trace.fatedFlipGeneratesLuck = context.luck and context.luck.fatedFlipGeneratesLuck == true or false
  end

  return trace
end

function LuckSystem.getMeter(runState)
  local luck = LuckSystem.normalize(runState)

  return {
    value = luck.value,
    max = luck.max,
    fatedFlipActive = luck.fatedFlipActive == true,
    fountainFavor = luck.fountainFavor,
  }
end

function LuckSystem.getMeterProgress(runState)
  local meter = LuckSystem.getMeter(runState)
  local maxValue = math.max(1, tonumber(meter.max) or 1)
  local ratio = Utils.clamp((tonumber(meter.value) or 0) / maxValue, 0, 1)

  return ratio, math.floor((ratio * 100) + 0.5), meter
end

function LuckSystem.formatMeter(runState)
  local meter = LuckSystem.getMeter(runState)
  return meter.fatedFlipActive and "FATE" or "Charging"
end

function LuckSystem.isFatedFlipActive(runState)
  return LuckSystem.normalize(runState).fatedFlipActive == true
end

function LuckSystem.getFatedFlipGeneratesLuck(runState)
  return LuckSystem.normalize(runState).fatedFlipGeneratesLuck == true
end

function LuckSystem.getFountainFavor(runState)
  return LuckSystem.normalize(runState).fountainFavor
end

function LuckSystem.addFountainFavor(runState, amount)
  local luck = LuckSystem.normalize(runState)
  local gained = math.max(0, toNumber(amount, 0))

  luck.fountainFavor = math.max(0, (luck.fountainFavor or 0) + gained)
  return gained, luck.fountainFavor
end

function LuckSystem.canGeneratePositiveLuck(context, options)
  if options and options.ignoreFatedSuppression == true then
    return true
  end

  if not context or not context.luck or context.luck.wasFatedFlip ~= true then
    return true
  end

  return context.luck.fatedFlipGeneratesLuck == true
end

function LuckSystem.addLuck(runState, context, amount, options)
  local luck = LuckSystem.normalize(runState)
  local delta = toNumber(amount, 0)
  local trace = LuckSystem.ensureTrace(context)
  local before = luck.value
  local suppressed = delta > 0 and not LuckSystem.canGeneratePositiveLuck(context, options)
  local source = options and options.source or nil
  local reason = options and options.reason or nil

  if suppressed then
    if trace then
      local eventId = string.format("luck_%02d", #(trace.deltas or {}) + 1)
      table.insert(trace.deltas, {
        eventId = eventId,
        amount = delta,
        appliedAmount = 0,
        before = before,
        after = before,
        source = source,
        reason = reason,
        positive = false,
        suppressed = true,
      })
      trace.after = snapshot(runState)
    end

    return 0, luck.value
  end

  luck.value = Utils.clamp(luck.value + delta, 0, luck.max)
  luck.fatedFlipActive = luck.value >= luck.max
  local appliedAmount = luck.value - before
  local event = nil

  if trace then
    event = {
      eventId = string.format("luck_%02d", #(trace.deltas or {}) + 1),
      amount = delta,
      appliedAmount = appliedAmount,
      before = before,
      after = luck.value,
      source = source,
      reason = reason,
      positive = appliedAmount > 0,
      meterFilled = before < luck.max and luck.value >= luck.max,
    }
    table.insert(trace.deltas, event)
    trace.after = snapshot(runState)
  end

  event = event or {
    amount = delta,
    appliedAmount = appliedAmount,
    before = before,
    after = luck.value,
    source = source,
    reason = reason,
    positive = appliedAmount > 0,
    meterFilled = before < luck.max and luck.value >= luck.max,
  }

  if appliedAmount > 0 and context and context.luckGainHookActive ~= true and context.luckGainHookFired ~= true then
    context.luckGainHookFired = true
    context.luckGainHookActive = true
    runLuckPhase(runState, context, "luck_gain", event)
    context.luckGainHookActive = false
  end

  if event.meterFilled == true and context and context.luckMeterFullHookFired ~= true then
    context.luckMeterFullHookFired = true
    runLuckPhase(runState, context, "luck_meter_full", event)
  end

  return appliedAmount, luck.value
end

function LuckSystem.applyBaseMatchLuck(runState, context)
  local matchCount = 0

  for _, coinState in ipairs(context and context.perCoin or {}) do
    if coinState.result == context.call then
      matchCount = matchCount + 1
    end
  end

  if matchCount <= 0 then
    LuckSystem.ensureTrace(context)
    return 0
  end

  local baseGain = math.max(0, toInteger(GameConfig.get("luck.baseMatchGain", 1), 1))
  local totalApplied = 0

  if baseGain > 0 then
    local applied = LuckSystem.addLuck(runState, context, matchCount * baseGain, {
      source = "base_match",
      reason = "matched_coins",
    })
    totalApplied = totalApplied + applied
  end

  local favor = LuckSystem.getFountainFavor(runState)
  if favor > 0 then
    local applied = LuckSystem.addLuck(runState, context, favor, {
      source = "fountain_favor",
      reason = "successful_call",
    })
    totalApplied = totalApplied + applied
  end

  return totalApplied
end

function LuckSystem.consumeFatedFlip(runState, context)
  if not context or not context.luck or context.luck.wasFatedFlip ~= true then
    return false
  end

  local luck = LuckSystem.normalize(runState)
  local trace = LuckSystem.ensureTrace(context)
  local before = luck.value

  luck.value = 0
  luck.fatedFlipActive = false

  if trace then
    trace.consumedFatedFlip = true
    table.insert(trace.deltas, {
      amount = -before,
      appliedAmount = -before,
      before = before,
      after = 0,
      source = "fated_flip",
      reason = "reset_after_resolution",
    })
    trace.after = snapshot(runState)
  end

  return true
end

return LuckSystem
