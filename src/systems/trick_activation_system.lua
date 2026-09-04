local ActionQueue = require("src.core.action_queue")
local Coins = require("src.content.coins")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local TrickBoardSystem = require("src.systems.trick_board_system")
local Utils = require("src.core.utils")

local TrickActivationSystem = {}

local function coinFamily(coinState)
  if coinState and coinState.bossActivationFamily ~= nil then
    return coinState.bossActivationFamily or nil
  end
  local definition = coinState and coinState.coinId and Coins.getById(coinState.coinId) or nil
  return definition and definition.activationFamily or nil
end

local function findCoin(context, resolutionIndex)
  for _, coinState in ipairs(context.perCoin or {}) do
    if coinState.resolutionIndex == resolutionIndex then return coinState end
  end
  return nil
end

local function findCoinByInstanceId(context, instanceId)
  for _, coinState in ipairs(context and context.perCoin or {}) do
    if coinState.instanceId == instanceId then return coinState end
  end
  return nil
end

local function recordPrevented(context, source, pressure)
  context.preventedActivationKeys = context.preventedActivationKeys or {}
  context.trace.preventedActivations = context.trace.preventedActivations or {}
  local activation = context.currentActivation or {}
  local key = table.concat({
    tostring(activation.activationId or "no_activation"),
    tostring(source.boardPosition or "no_position"),
    tostring(pressure and pressure.kind or "pressure"),
  }, "|")
  if context.preventedActivationKeys[key] then return end
  context.preventedActivationKeys[key] = true
  table.insert(context.trace.preventedActivations, {
    activationId = activation.activationId,
    kind = activation.kind,
    family = activation.activationFamily,
    trickId = source.sourceId,
    trickPosition = source.boardPosition,
    pressureKind = pressure and pressure.kind or nil,
    reason = pressure and pressure.kind == "blocked" and "trick_blocked"
      or (pressure and pressure.kind == "jammed" and "trick_jammed" or "trick_pressure"),
  })
end

local function matchingSources(context, family)
  local matches = {}
  for _, source in ipairs(context.activeTrickSources or {}) do
    local trick = source.definition and source.definition.trick or {}
    local sourceFamily = trick.activationFamily or trick.category
    local pressure = TrickBoardSystem.getPressure(context.stageState, source.boardPosition)
    if sourceFamily == family then
      if pressure and pressure.kind == "blocked" then
        recordPrevented(context, source, pressure)
      elseif not (pressure and pressure.kind == "jammed"
        and context.jammedTrickActivations[source.boardPosition] ~= nil
        and context.jammedTrickActivations[source.boardPosition] ~= (context.currentActivation and context.currentActivation.activationId)) then
        table.insert(matches, source)
      else
        recordPrevented(context, source, pressure)
      end
    end
  end
  return matches
end

local function sourceHasPhase(source, phaseName)
  for _, trigger in ipairs(source and source.definition and source.definition.triggers or {}) do
    if trigger.hook == phaseName then return true end
  end
  return false
end

local function dynamicLeftGenuineFamilyCoin(context)
  local current = context and context.currentCoin or nil
  local left = current and current.resolutionIndex and findCoin(context, current.resolutionIndex - 1) or nil
  local family = coinFamily(left)
  if not left or not family or family == "forgery" or left.smuggled == true or left.contrabandCopy == true then
    return nil, nil
  end
  return left, family
end

local function getLockedForgeryAssignment(context, coinState)
  local instanceId = coinState and coinState.instanceId or nil
  return instanceId and context and context.forgeryAssignmentByInstanceId
    and context.forgeryAssignmentByInstanceId[instanceId] or nil
end

local function leftGenuineFamilyCoin(context)
  local assignment = getLockedForgeryAssignment(context, context and context.currentCoin or nil)
  if assignment then
    local source = findCoinByInstanceId(context, assignment.sourceInstanceId) or {
      coinId = assignment.sourceCoinId,
      instanceId = assignment.sourceInstanceId,
      resolutionIndex = assignment.sourceResolutionIndex,
      selectedSlotIndex = assignment.sourceSlotIndex,
    }
    return source, assignment.sourceFamily, assignment
  end
  local source, family = dynamicLeftGenuineFamilyCoin(context)
  return source, family, nil
end

local function sortForgeryCandidates(candidates, mode)
  table.sort(candidates, function(left, right)
    local leftTier = tonumber(left.definition and left.definition.trick and left.definition.trick.tier) or 1
    local rightTier = tonumber(right.definition and right.definition.trick and right.definition.trick.tier) or 1
    if leftTier ~= rightTier then
      if mode == "forged_signature" then return leftTier > rightTier end
      return leftTier < rightTier
    end
    return (left.boardPosition or 999) < (right.boardPosition or 999)
  end)
end

local function selectForgeryPlanTargets(context, family, mode, maxTier, maxTricks)
  local candidates = {}
  maxTier = math.max(1, math.min(3, tonumber(maxTier) or 1))
  for _, source in ipairs(context and context.activeTrickSources or {}) do
    local trick = source.definition and source.definition.trick or {}
    local sourceFamily = trick.activationFamily or trick.category
    local tier = math.max(1, tonumber(trick.tier) or 1)
    if sourceFamily == family and tier <= maxTier then
      table.insert(candidates, source)
    end
  end

  sortForgeryCandidates(candidates, mode)
  local limit = mode == "forged_signature" and 1
    or math.max(1, math.min(3, tonumber(maxTricks) or 1))
  while #candidates > limit do table.remove(candidates) end
  return candidates
end

function TrickActivationSystem.applyForgeryAssignment(context, coinState)
  local assignment = getLockedForgeryAssignment(context, coinState)
  if not assignment then return false end
  coinState.forgeryDirection = assignment.direction
  coinState.forgerySourceCoinId = assignment.sourceCoinId
  coinState.forgerySourceInstanceId = assignment.sourceInstanceId
  coinState.forgerySourceResolutionIndex = assignment.sourceResolutionIndex
  coinState.actingFamily = assignment.actingFamily
  return true
end

function TrickActivationSystem.lockForgeryAssignments(context)
  if not context then return {} end
  if context.forgeryAssignmentsLocked == true then
    for _, coinState in ipairs(context.perCoin or {}) do
      TrickActivationSystem.applyForgeryAssignment(context, coinState)
    end
    return context.forgeryAssignments or {}
  end

  context.forgeryAssignmentsLocked = true
  context.forgeryAssignments = {}
  context.forgeryAssignmentByInstanceId = {}

  for _, coinState in ipairs(context.perCoin or {}) do
    if coinFamily(coinState) == "forgery" and coinState.selectedSlotIndex ~= nil
      and coinState.smuggled ~= true and coinState.contrabandCopy ~= true then
      local left = coinState.resolutionIndex and findCoin(context, coinState.resolutionIndex - 1) or nil
      local family = coinFamily(left)
      if left and left.selectedSlotIndex ~= nil and family and family ~= "forgery"
        and left.smuggled ~= true and left.contrabandCopy ~= true then
        local assignment = {
          coinId = coinState.coinId,
          instanceId = coinState.instanceId,
          slotIndex = coinState.selectedSlotIndex,
          resolutionIndex = coinState.resolutionIndex,
          direction = "left",
          sourceCoinId = left.coinId,
          sourceInstanceId = left.instanceId,
          sourceSlotIndex = left.selectedSlotIndex,
          sourceResolutionIndex = left.resolutionIndex,
          sourceFamily = family,
          plans = {},
          plansByTrickId = {},
        }

        for _, source in ipairs(context.activeTrickSources or {}) do
          local trick = source.definition and source.definition.trick or nil
          if trick and trick.activationFamily == "forgery" and trick.forgeryMode then
            local targets = selectForgeryPlanTargets(
              context,
              family,
              trick.forgeryMode,
              trick.forgeryMaxTier,
              trick.forgeryMaxTricks
            )
            if #targets > 0 then
              local targetTrickIds = {}
              for _, target in ipairs(targets) do table.insert(targetTrickIds, target.sourceId) end
              local plan = {
                forgeryTrickId = source.sourceId,
                mode = trick.forgeryMode,
                maxTier = trick.forgeryMaxTier,
                maxTricks = trick.forgeryMaxTricks,
                targetTrickIds = targetTrickIds,
              }
              assignment.plansByTrickId[source.sourceId] = plan
              table.insert(assignment.plans, plan)
            end
          end
        end

        if #assignment.plans > 0 then assignment.actingFamily = family end
        context.forgeryAssignmentByInstanceId[coinState.instanceId] = assignment
        table.insert(context.forgeryAssignments, assignment)
        TrickActivationSystem.applyForgeryAssignment(context, coinState)
      end
    end
  end

  context.trace.forgeryAssignments = {}
  for _, assignment in ipairs(context.forgeryAssignments) do
    local traced = Utils.clone(assignment)
    traced.plansByTrickId = nil
    table.insert(context.trace.forgeryAssignments, traced)
  end
  return context.forgeryAssignments
end

function TrickActivationSystem.getForgeryPlan(context, coinState, forgeryTrickId)
  local assignment = getLockedForgeryAssignment(context, coinState)
  return assignment and assignment.plansByTrickId[forgeryTrickId] or nil, assignment
end

local function forgedCandidates(context, action, phaseName)
  local _, family = leftGenuineFamilyCoin(context)
  if not family then return {}, nil end

  local candidates = {}
  local targetIndex = nil
  if type(action and action.targetTrickIds) == "table" then
    targetIndex = {}
    for _, trickId in ipairs(action.targetTrickIds) do targetIndex[trickId] = true end
  end
  local maxTier = math.max(1, math.min(3, tonumber(action and action.maxTier) or 1))
  for _, source in ipairs(context.activeTrickSources or {}) do
    local trick = source.definition and source.definition.trick or {}
    local sourceFamily = trick.activationFamily or trick.category
    local tier = math.max(1, tonumber(trick.tier) or 1)
    if sourceFamily == family and tier <= maxTier and sourceHasPhase(source, phaseName)
      and (targetIndex == nil or targetIndex[source.sourceId]) then
      table.insert(candidates, source)
    end
  end

  sortForgeryCandidates(candidates, action.mode)

  local limit = action.mode == "forged_signature" and 1
    or math.max(1, math.min(3, tonumber(action.maxTricks) or 1))
  while #candidates > limit do table.remove(candidates) end
  return candidates, family
end

function TrickActivationSystem.hasForgedTrickTarget(context, action, phaseName)
  if not context or not context.currentActivation or context.currentActivation.forged == true then return false end
  if coinFamily(context.currentCoin) ~= "forgery" then return false end
  local candidates = forgedCandidates(context, action or {}, phaseName)
  return #candidates > 0
end

local function applyPressureToActions(actions, pressure)
  if not pressure or pressure.kind ~= "weakened" then return end
  local multiplier = tonumber(pressure.multiplier) or 0.5
  for _, action in ipairs(actions or {}) do
    if action.op == "forge_trick_activations" then
      action.forgeryEffectiveness = (tonumber(action.forgeryEffectiveness) or 1) * multiplier
      if action.mode == "borrowed_name" then
        action.maxTricks = math.max(1, math.ceil((tonumber(action.maxTricks) or 1) * multiplier))
        while type(action.targetTrickIds) == "table" and #action.targetTrickIds > action.maxTricks do
          table.remove(action.targetTrickIds)
        end
      end
    end
    if type(action.amount) == "number" then action.amount = action.amount * multiplier end
    if type(action.scale) == "number" then action.scale = action.scale * multiplier end
    if type(action.chance) == "number" then action.chance = action.chance * multiplier end
    if type(action.value) == "number" and action.value >= 1 then
      action.value = 1 + ((action.value - 1) * multiplier)
    end
  end
end

function TrickActivationSystem.initialize(context, runState, stageState)
  context.activeTrickSources = HookRegistry.buildActiveTrickSources(runState)
  context.trickBoardSnapshot = context.trickBoardSnapshot or TrickBoardSystem.snapshot(runState, stageState)
  context.activationQueue = {}
  context.finishQueue = {}
  context.activationLedger = {}
  context.reactivationCounts = {}
  context.trickActivationCounts = {}
  context.jammedTrickActivations = {}
  context.activationSequence = 0
  context.preventedActivationKeys = {}
  context.maxActivationEvents = GameConfig.get("tricks.maxActivationEventsPerFlip", 24)
  context.trace.activationLedger = context.activationLedger
  context.trace.activationRolls = context.trace.activationRolls or {}
  context.trace.preventedActivations = context.trace.preventedActivations or {}
  context.trace.forgeryAssignments = context.trace.forgeryAssignments or {}
end

function TrickActivationSystem.newActivation(context, coinState, kind, parent)
  context.activationSequence = (context.activationSequence or 0) + 1
  local activation = {
    activationId = string.format("activation_%03d", context.activationSequence),
    kind = kind or "root",
    sourceInstanceId = coinState.instanceId,
    sourceCoinId = coinState.coinId,
    sourceSlotIndex = coinState.slotIndex,
    sourceResolutionIndex = coinState.resolutionIndex,
    activationFamily = coinFamily(coinState),
    result = coinState.result,
    parentActivationId = parent and parent.activationId or nil,
    parentTrickId = parent and parent.parentTrickId or nil,
    chainDepth = parent and ((parent.chainDepth or 0) + 1) or 0,
    forged = parent and parent.forged == true or false,
    canRunSetup = kind == nil or kind == "root",
    canActivateTricks = coinState.contrabandCopy ~= true and coinState.smuggled ~= true,
  }
  return activation
end

function TrickActivationSystem.enqueueReactivation(context, action)
  local source = context.currentCoin
  if not source then return false, "activation_source_required" end

  local directions = action.directions or { action.direction or "right" }
  local maxTargets = math.max(1, tonumber(action.maxTargets) or 1)
  local initialChance = tonumber(action.chance) or 1
  local continuationChance = tonumber(action.continuationChance) or initialChance
  local queued = 0

  for _, direction in ipairs(directions) do
    local step = direction == "left" and -1 or 1
    local targetIndex = source.resolutionIndex + step
    local chance = initialChance
    while queued < maxTargets do
      local target = findCoin(context, targetIndex)
      if not target then break end
      local roll = context.rng and context.rng.nextFloat and context.rng:nextFloat() or 1
      local success = roll <= chance
      table.insert(context.trace.activationRolls, {
        sourceResolutionIndex = source.resolutionIndex,
        targetResolutionIndex = targetIndex,
        direction = direction,
        chance = chance,
        roll = roll,
        success = success,
      })
      if not success then break end

      local count = context.reactivationCounts[target.instanceId] or 0
      local limit = math.max(1, tonumber(action.maxReactivationsPerCoin) or 1)
      if count < limit then
        context.reactivationCounts[target.instanceId] = count + 1
        table.insert(context.activationQueue, TrickActivationSystem.newActivation(
          context,
          target,
          "reactivation",
          {
            activationId = context.currentActivation and context.currentActivation.activationId,
            parentTrickId = action._trace and action._trace.sourceId,
            chainDepth = context.currentActivation and context.currentActivation.chainDepth or 0,
            forged = context.currentActivation and context.currentActivation.forged == true,
          }
        ))
        queued = queued + 1
      end
      targetIndex = targetIndex + step
      chance = continuationChance
    end
  end
  return true, queued
end

function TrickActivationSystem.enqueueRepeat(context, action)
  local sourceCoin = context.currentCoin
  if not sourceCoin then return false, "activation_source_required" end

  local targetSource = nil
  for _, source in ipairs(context.activeTrickSources or {}) do
    if source.sourceId == action.trickId then
      targetSource = source
      break
    end
  end
  if not targetSource then
    table.insert(context.trace.warnings, "repeat_trick target is not active: " .. tostring(action.trickId))
    return false, "repeat_target_not_active"
  end

  local repeatActivation = TrickActivationSystem.newActivation(
    context,
    sourceCoin,
    "repeat",
    {
      activationId = context.currentActivation and context.currentActivation.activationId,
      parentTrickId = action._trace and action._trace.sourceId,
      chainDepth = context.currentActivation and context.currentActivation.chainDepth or 0,
      forged = context.currentActivation and context.currentActivation.forged == true,
    }
  )
  repeatActivation.targetTrickId = action.trickId
  repeatActivation.repeatPhase = action.phase
    or (action._trace and action._trace.phase)
    or context.currentPhase
    or "after_all_effects"
  repeatActivation.canActivateTricks = false
  table.insert(context.activationQueue, repeatActivation)
  return true
end

function TrickActivationSystem.runTrickPhase(runState, stageState, context, activation, coinState, phaseName)
  if not activation or not activation.canActivateTricks or not activation.activationFamily then return end

  local previousActivation = context.currentActivation
  local previousCoin = context.currentCoin
  context.currentActivation = activation
  context.currentCoin = coinState

  for _, source in ipairs(matchingSources(context, activation.activationFamily)) do
    local before = #(context.trace.triggeredSources or {})
    local actions = HookRegistry.runSourcePhase(phaseName, source, context)
    if #actions > 0 then
      local pressure = TrickBoardSystem.getPressure(stageState, source.boardPosition)
      applyPressureToActions(actions, pressure)
      ActionQueue.applyAll(runState, stageState, context, actions)
    end
    local triggered = #(context.trace.triggeredSources or {}) > before
    if triggered then
      context.trickActivationCounts[source.sourceId] = (context.trickActivationCounts[source.sourceId] or 0) + 1
      EnemySkillSystem.recordTrickActivation(context, source, activation)
      if TrickBoardSystem.getPressure(stageState, source.boardPosition)
        and TrickBoardSystem.getPressure(stageState, source.boardPosition).kind == "jammed"
        and context.jammedTrickActivations[source.boardPosition] == nil then
        context.jammedTrickActivations[source.boardPosition] = activation.activationId
      end
      table.insert(context.activationLedger, {
        activationId = activation.activationId,
        kind = activation.kind,
        family = activation.activationFamily,
        coinId = coinState.coinId,
        instanceId = coinState.instanceId,
        resolutionIndex = coinState.resolutionIndex,
        trickId = source.sourceId,
        trickPosition = source.boardPosition,
        phase = phaseName,
        chainDepth = activation.chainDepth,
      })
    end
  end

  context.currentActivation = previousActivation
  context.currentCoin = previousCoin
end

function TrickActivationSystem.runRepeatedTrick(runState, stageState, context, activation, coinState)
  if not activation or not activation.targetTrickId then return end
  local source = nil
  for _, candidate in ipairs(context.activeTrickSources or {}) do
    if candidate.sourceId == activation.targetTrickId then
      source = candidate
      break
    end
  end
  if not source then return end

  local pressure = TrickBoardSystem.getPressure(stageState, source.boardPosition)
  if pressure and pressure.kind == "blocked" then
    local previousActivation = context.currentActivation
    context.currentActivation = activation
    recordPrevented(context, source, pressure)
    context.currentActivation = previousActivation
    return
  end
  if pressure and pressure.kind == "jammed"
    and context.jammedTrickActivations[source.boardPosition] ~= nil
    and context.jammedTrickActivations[source.boardPosition] ~= activation.activationId then
    local previousActivation = context.currentActivation
    context.currentActivation = activation
    recordPrevented(context, source, pressure)
    context.currentActivation = previousActivation
    return
  end

  local previousActivation = context.currentActivation
  local previousCoin = context.currentCoin
  context.currentActivation = activation
  context.currentCoin = coinState
  local before = #(context.trace.triggeredSources or {})
  local actions = HookRegistry.runSourcePhase(activation.repeatPhase, source, context)
  applyPressureToActions(actions, pressure)
  ActionQueue.applyAll(runState, stageState, context, actions)
  if #(context.trace.triggeredSources or {}) > before then
    context.trickActivationCounts[source.sourceId] = (context.trickActivationCounts[source.sourceId] or 0) + 1
    EnemySkillSystem.recordTrickActivation(context, source, activation)
    if pressure and pressure.kind == "jammed"
      and context.jammedTrickActivations[source.boardPosition] == nil then
      context.jammedTrickActivations[source.boardPosition] = activation.activationId
    end
    table.insert(context.activationLedger, {
      activationId = activation.activationId,
      kind = "repeat",
      family = source.definition and source.definition.trick
        and (source.definition.trick.activationFamily or source.definition.trick.category) or nil,
      coinId = coinState.coinId,
      instanceId = coinState.instanceId,
      resolutionIndex = coinState.resolutionIndex,
      trickId = source.sourceId,
      trickPosition = source.boardPosition,
      phase = activation.repeatPhase,
      chainDepth = activation.chainDepth,
    })
  end
  context.currentActivation = previousActivation
  context.currentCoin = previousCoin
end

function TrickActivationSystem.applyForgedTrickActivations(runState, stageState, context, action)
  local parentActivation = context.currentActivation
  local forgeryCoin = context.currentCoin
  if not parentActivation or not forgeryCoin or parentActivation.forged == true or coinFamily(forgeryCoin) ~= "forgery" then
    action.skipped = true
    action.skipReason = "forged_activation_cannot_recurse"
    return false, action.skipReason
  end

  local genuineCoin, family, assignment = leftGenuineFamilyCoin(context)
  local candidates = forgedCandidates(context, action, action.phase)
  if not genuineCoin or not family or #candidates == 0 then
    action.skipped = true
    action.skipReason = "no_left_genuine_family_trick"
    return false, action.skipReason
  end

  action.sourceCoinId = genuineCoin.coinId
  action.sourceInstanceId = genuineCoin.instanceId
  action.sourceResolutionIndex = assignment and assignment.sourceResolutionIndex or genuineCoin.resolutionIndex
  action.targetCoinId = forgeryCoin.coinId
  action.targetInstanceId = forgeryCoin.instanceId
  action.targetResolutionIndex = forgeryCoin.resolutionIndex
  action.forgedFamily = family
  action.forgeryDirection = assignment and assignment.direction or "left"
  action.forgedTrickIds = {}
  context.trace.forgedActivations = context.trace.forgedActivations or {}

  local outerTrickId = action._trace and action._trace.sourceId or "forgery"
  for _, source in ipairs(candidates) do
    local pressure = TrickBoardSystem.getPressure(stageState, source.boardPosition)
    local synthetic = {
      activationId = table.concat({
        tostring(parentActivation.activationId),
        "forged",
        tostring(action.mode),
        tostring(outerTrickId),
        tostring(source.sourceId),
      }, ":"),
      kind = action.mode,
      sourceInstanceId = forgeryCoin.instanceId,
      sourceCoinId = forgeryCoin.coinId,
      sourceSlotIndex = forgeryCoin.slotIndex,
      sourceResolutionIndex = forgeryCoin.resolutionIndex,
      activationFamily = family,
      result = forgeryCoin.result,
      parentActivationId = parentActivation.activationId,
      parentTrickId = outerTrickId,
      chainDepth = (parentActivation.chainDepth or 0) + 1,
      canRunSetup = false,
      canActivateTricks = false,
      forged = true,
      forgeryMode = action.mode,
      genuineSourceInstanceId = genuineCoin.instanceId,
      genuineSourceCoinId = genuineCoin.coinId,
      targetTrickId = source.sourceId,
    }

    local prevented = pressure and pressure.kind == "blocked"
      or (pressure and pressure.kind == "jammed"
        and context.jammedTrickActivations[source.boardPosition] ~= nil
        and context.jammedTrickActivations[source.boardPosition] ~= synthetic.activationId)
    if prevented then
      local previousActivation = context.currentActivation
      context.currentActivation = synthetic
      recordPrevented(context, source, pressure)
      context.currentActivation = previousActivation
    else
      local previousActivation = context.currentActivation
      local previousCoin = context.currentCoin
      context.currentActivation = synthetic
      context.currentCoin = forgeryCoin
      local before = #(context.trace.triggeredSources or {})
      local actions = HookRegistry.runSourcePhase(action.phase, source, context)
      applyPressureToActions(actions, pressure)
      if type(action.forgeryEffectiveness) == "number" and action.forgeryEffectiveness < 1 then
        applyPressureToActions(actions, { kind = "weakened", multiplier = action.forgeryEffectiveness })
      end
      ActionQueue.applyAll(runState, stageState, context, actions)
      if #(context.trace.triggeredSources or {}) > before then
        context.trickActivationCounts[source.sourceId] = (context.trickActivationCounts[source.sourceId] or 0) + 1
        EnemySkillSystem.recordTrickActivation(context, source, synthetic)
        if pressure and pressure.kind == "jammed" and context.jammedTrickActivations[source.boardPosition] == nil then
          context.jammedTrickActivations[source.boardPosition] = synthetic.activationId
        end
        table.insert(action.forgedTrickIds, source.sourceId)
        local ledgerEntry = {
          activationId = synthetic.activationId,
          kind = action.mode,
          family = family,
          coinId = forgeryCoin.coinId,
          instanceId = forgeryCoin.instanceId,
          resolutionIndex = forgeryCoin.resolutionIndex,
          genuineSourceCoinId = genuineCoin.coinId,
          genuineSourceInstanceId = genuineCoin.instanceId,
          genuineSourceResolutionIndex = assignment and assignment.sourceResolutionIndex or genuineCoin.resolutionIndex,
          forgeryDirection = assignment and assignment.direction or "left",
          forgeryTrickId = outerTrickId,
          trickId = source.sourceId,
          trickPosition = source.boardPosition,
          phase = action.phase,
          chainDepth = synthetic.chainDepth,
          forged = true,
        }
        table.insert(context.activationLedger, ledgerEntry)
        table.insert(context.trace.forgedActivations, Utils.clone(ledgerEntry))
      end
      context.currentActivation = previousActivation
      context.currentCoin = previousCoin
    end
  end

  action.forgedActivationCount = #action.forgedTrickIds
  return true, action.forgedActivationCount
end

function TrickActivationSystem.getCoin(context, activation)
  return activation and findCoin(context, activation.sourceResolutionIndex) or nil
end

function TrickActivationSystem.buildRootActivations(context)
  local roots = {}
  for _, coinState in ipairs(context.perCoin or {}) do
    if coinState.selectedSlotIndex ~= nil then
      table.insert(roots, TrickActivationSystem.newActivation(context, coinState, "root"))
    end
  end
  context.rootActivations = roots
  return roots
end

return TrickActivationSystem
