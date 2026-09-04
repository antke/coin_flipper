local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local EnemySkillSystem = require("src.systems.enemy_skill_system")

local TrickBoardSystem = {}

local VALID_PHASES = {
  setup = true,
  locked = true,
  resolving = true,
  reveal = true,
  complete = true,
}

local VALID_PRESSURE = {
  blocked = true,
  weakened = true,
  jammed = true,
  poisoned = true,
}

local function board(runState)
  if not runState then
    return {}
  end

  local tricks = runState.ownedTrickIds or runState.ownedUpgradeIds or {}
  runState.ownedTrickIds = tricks
  runState.ownedUpgradeIds = tricks
  return tricks
end

local function lineId(definition)
  return definition and definition.trick and (definition.trick.lineId or definition.id) or nil
end

function TrickBoardSystem.getCapacity(runState)
  return math.max(1, tonumber(runState and runState.maxActiveTricks) or 5)
end

function TrickBoardSystem.getActiveTrickIds(runState)
  return board(runState)
end

function TrickBoardSystem.sanitizeActiveTricks(runState)
  local active = board(runState)
  local sanitized = {}
  local removed = {}
  local capacity = TrickBoardSystem.getCapacity(runState)

  for _, trickId in ipairs(active) do
    local definition = Upgrades.getById(trickId)
    if definition and definition.familyTriggerStatus == "converted" and #sanitized < capacity then
      table.insert(sanitized, trickId)
    else
      table.insert(removed, trickId)
    end
  end

  runState.ownedTrickIds = sanitized
  runState.ownedUpgradeIds = sanitized
  return sanitized, removed
end

function TrickBoardSystem.getPhase(stageState)
  return stageState and stageState.trickBoard and stageState.trickBoard.phase or "setup"
end

function TrickBoardSystem.setPhase(stageState, phase)
  if not stageState or not VALID_PHASES[phase] then
    return false, "invalid_trick_board_phase"
  end

  stageState.trickBoard = stageState.trickBoard or {
    phase = "setup",
    revision = 1,
    pressure = {},
    replacementsRemaining = 3,
    replacementHistory = {},
  }
  stageState.trickBoard.phase = phase
  stageState.trickBoard.revision = (stageState.trickBoard.revision or 0) + 1
  return true
end

function TrickBoardSystem.requireSetup(stageState)
  if TrickBoardSystem.getPhase(stageState) ~= "setup" then
    return false, "setup_locked"
  end

  return true
end

function TrickBoardSystem.snapshot(runState, stageState)
  local snapshot = {}
  local pressure = stageState and stageState.trickBoard and stageState.trickBoard.pressure or {}

  for position, trickId in ipairs(board(runState)) do
    local definition = Upgrades.getById(trickId)
    local pressureEntry = pressure[position]
    table.insert(snapshot, {
      position = position,
      trickId = trickId,
      activationFamily = definition and definition.trick
        and (definition.trick.activationFamily or definition.trick.category) or nil,
      pressure = pressureEntry and Utils.clone(pressureEntry) or nil,
    })
  end

  return snapshot
end

function TrickBoardSystem.canAcquire(runState, trickId)
  local definition = Upgrades.getById(trickId)
  if not definition then
    return false, "unknown_trick"
  end
  if definition.familyTriggerStatus ~= "converted" then
    return false, "inactive_trick"
  end

  local active = board(runState)
  local incomingLine = lineId(definition)

  for position, ownedId in ipairs(active) do
    local owned = Upgrades.getById(ownedId)
    if ownedId == trickId then
      return false, "already_owned"
    end

    if incomingLine and incomingLine == lineId(owned) then
      local incomingTier = tonumber(definition.trick and definition.trick.tier) or 1
      local ownedTier = tonumber(owned and owned.trick and owned.trick.tier) or 1
      if incomingTier > ownedTier then
        return true, { mode = "tier_upgrade", replacePosition = position, replacedTrickId = ownedId }
      end
      return false, "lower_or_equal_tier"
    end
  end

  if #active < TrickBoardSystem.getCapacity(runState) then
    return true, { mode = "append", position = #active + 1 }
  end

  return false, {
    code = "trick_board_full",
    capacity = TrickBoardSystem.getCapacity(runState),
    activeTrickIds = Utils.copyArray(active),
  }
end

function TrickBoardSystem.acquire(runState, trickId, replacePosition)
  local canAcquire, result = TrickBoardSystem.canAcquire(runState, trickId)
  local active = board(runState)

  if canAcquire then
    if result.mode == "tier_upgrade" then
      active[result.replacePosition] = trickId
    else
      table.insert(active, trickId)
    end
    return true, result
  end

  if type(result) == "table" and result.code == "trick_board_full" then
    local position = tonumber(replacePosition)
    if not position or position < 1 or position > #active then
      return false, result
    end

    local replacedTrickId = active[position]
    active[position] = trickId
    return true, {
      mode = "replacement",
      replacePosition = position,
      replacedTrickId = replacedTrickId,
    }
  end

  return false, result
end

function TrickBoardSystem.setPressure(stageState, position, pressure)
  if not stageState or not stageState.trickBoard then
    return false, "trick_board_unavailable"
  end
  local setupOk, setupError = TrickBoardSystem.requireSetup(stageState)
  if not setupOk then return false, setupError end
  if not VALID_PRESSURE[pressure and pressure.kind] then
    return false, "invalid_trick_pressure"
  end

  position = tonumber(position)
  if not position or position < 1 or math.floor(position) ~= position then
    return false, "invalid_trick_position"
  end

  stageState.trickBoard.pressure[position] = Utils.clone(pressure)
  stageState.trickBoard.revision = (stageState.trickBoard.revision or 0) + 1
  return true
end

function TrickBoardSystem.getPressure(stageState, position)
  return stageState and stageState.trickBoard and stageState.trickBoard.pressure
    and stageState.trickBoard.pressure[position] or nil
end

function TrickBoardSystem.getEffectiveness(stageState, position)
  local pressure = TrickBoardSystem.getPressure(stageState, position)
  if not pressure then
    return 1
  end
  if pressure.kind == "blocked" then
    return 0
  end
  if pressure.kind == "weakened" then
    return math.max(0, math.min(1, tonumber(pressure.multiplier) or 0.5))
  end
  return 1
end

local function buildForgeryPlans(active, family)
  local plans = {}
  for _, forgeryEntry in ipairs(active or {}) do
    local forgeryDefinition = Upgrades.getById(forgeryEntry.trickId)
    local forgeryTrick = forgeryDefinition and forgeryDefinition.trick or nil
    if forgeryTrick and forgeryTrick.forgeryMode then
      local candidates = {}
      for _, targetEntry in ipairs(active or {}) do
        local targetDefinition = Upgrades.getById(targetEntry.trickId)
        local targetTrick = targetDefinition and targetDefinition.trick or nil
        local targetFamily = targetTrick and (targetTrick.activationFamily or targetTrick.category) or nil
        local targetTier = tonumber(targetTrick and targetTrick.tier) or 1
        if targetFamily == family and targetTier <= (forgeryTrick.forgeryMaxTier or 1) then
          table.insert(candidates, { entry = targetEntry, tier = targetTier })
        end
      end
      table.sort(candidates, function(left, right)
        if left.tier ~= right.tier then
          if forgeryTrick.forgeryMode == "forged_signature" then return left.tier > right.tier end
          return left.tier < right.tier
        end
        return left.entry.position < right.entry.position
      end)
      local limit = forgeryTrick.forgeryMode == "forged_signature" and 1
        or (forgeryTrick.forgeryMaxTricks or 1)
      local targetTrickIds = {}
      for index = 1, math.min(limit, #candidates) do
        table.insert(targetTrickIds, candidates[index].entry.trickId)
      end
      if #targetTrickIds > 0 then
        table.insert(plans, {
          forgeryTrickId = forgeryEntry.trickId,
          mode = forgeryTrick.forgeryMode,
          maxTier = forgeryTrick.forgeryMaxTier,
          maxTricks = forgeryTrick.forgeryMaxTricks,
          targetTrickIds = targetTrickIds,
        })
      end
    end
  end
  return plans
end

function TrickBoardSystem.getForgeryAssignmentPreview(runState, stageState)
  local Coins = require("src.content.coins")
  local PurseSystem = require("src.systems.purse_system")
  local selected = PurseSystem.getSelectedSlotEntries(runState, stageState)
  local active = TrickBoardSystem.snapshot(runState, stageState)
  local assignments = {}

  for selectedIndex, entry in ipairs(selected) do
    local coin = Coins.getById(entry.coinId)
    if coin and coin.activationFamily == "forgery" then
      local genuine = selected[selectedIndex - 1]
      local genuineCoin = genuine and Coins.getById(genuine.coinId) or nil
      local family = genuineCoin and genuineCoin.activationFamily or nil
      if family and family ~= "forgery" then
        local plans = buildForgeryPlans(active, family)
        table.insert(assignments, {
          coinId = entry.coinId,
          instanceId = entry.instanceId,
          slotIndex = entry.selectedSlotIndex or selectedIndex,
          resolutionIndex = entry.selectedSlotIndex or selectedIndex,
          direction = "left",
          sourceCoinId = genuine.coinId,
          sourceInstanceId = genuine.instanceId,
          sourceSlotIndex = genuine.selectedSlotIndex or (selectedIndex - 1),
          sourceResolutionIndex = genuine.selectedSlotIndex or (selectedIndex - 1),
          sourceFamily = family,
          actingFamily = #plans > 0 and family or nil,
          plans = plans,
        })
      end
    end
  end
  return assignments
end

function TrickBoardSystem.getActivationPreview(runState, stageState)
  local counts = {}
  local forgedCounts = {}
  local Coins = require("src.content.coins")
  local PurseSystem = require("src.systems.purse_system")

  local selected = PurseSystem.getSelectedSlotEntries(runState, stageState)
  for _, entry in ipairs(selected) do
    local coin = Coins.getById(entry.coinId)
    local family = coin and coin.activationFamily
    if family then
      counts[family] = (counts[family] or 0) + 1
    end
  end

  local active = TrickBoardSystem.snapshot(runState, stageState)
  for _, assignment in ipairs(TrickBoardSystem.getForgeryAssignmentPreview(runState, stageState)) do
    for _, plan in ipairs(assignment.plans or {}) do
      for _, trickId in ipairs(plan.targetTrickIds or {}) do
        forgedCounts[trickId] = (forgedCounts[trickId] or 0) + 1
      end
    end
  end

  local preview = {}
  for _, entry in ipairs(active) do
    entry.activationCount = entry.activationFamily and (counts[entry.activationFamily] or 0) or 0
    entry.forgedActivationCount = forgedCounts[entry.trickId] or 0
    entry.effectiveness = TrickBoardSystem.getEffectiveness(stageState, entry.position)
    table.insert(preview, entry)
  end
  return preview
end

function TrickBoardSystem.applyOpponentPressure(runState, stageState)
  if not stageState or not stageState.trickBoard then return {} end
  return EnemySkillSystem.prepareIntent(runState, stageState)
end

return TrickBoardSystem
