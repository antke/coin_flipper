local Coins = require("src.content.coins")
local Utils = require("src.core.utils")

local PurseSystem = {}

local DEFAULT_HAND_SIZE = 5

local function removeValue(values, value)
  for index, current in ipairs(values or {}) do
    if current == value then
      table.remove(values, index)
      return true
    end
  end

  return false
end

local function findInstance(runState, instanceId)
  for _, instance in ipairs(runState and runState.coinInstances or {}) do
    if instance.instanceId == instanceId then
      return instance
    end
  end

  return nil
end

local function ensureDefinitionInCollection(runState, definitionId)
  if not Utils.contains(runState.collectionCoinIds, definitionId) then
    table.insert(runState.collectionCoinIds, definitionId)
  end
end

function PurseSystem.getHandSize(runState)
  local resolved = runState and runState.resolvedValues and runState.resolvedValues["purse.handSize"] or nil
  return math.max(1, tonumber(resolved) or DEFAULT_HAND_SIZE)
end

function PurseSystem.createInstance(runState, definitionId)
  local definition = Coins.getById(definitionId)

  if not definition then
    return nil, "unknown_coin"
  end

  runState.counters.coinInstancesCreated = (runState.counters.coinInstancesCreated or 0) + 1
  local instance = {
    instanceId = string.format("coin_%03d", runState.counters.coinInstancesCreated),
    definitionId = definitionId,
    state = {},
    flags = {},
  }

  table.insert(runState.coinInstances, instance)
  ensureDefinitionInCollection(runState, definitionId)
  return instance
end

function PurseSystem.createInstancesFromDefinitionIds(runState, definitionIds)
  for _, definitionId in ipairs(definitionIds or {}) do
    local instance, errorMessage = PurseSystem.createInstance(runState, definitionId)

    if not instance then
      return nil, errorMessage
    end
  end

  return runState.coinInstances
end

function PurseSystem.getInstance(runState, instanceId)
  return findInstance(runState, instanceId)
end

function PurseSystem.getDefinitionId(runState, instanceId)
  local instance = findInstance(runState, instanceId)
  return instance and instance.definitionId or nil
end

function PurseSystem.getDefinition(runState, instanceId)
  local definitionId = PurseSystem.getDefinitionId(runState, instanceId)
  return definitionId and Coins.getById(definitionId) or nil
end

function PurseSystem.initializeStagePurse(runState, stageState)
  if not runState or not stageState then
    return nil, "stage_not_initialized"
  end

  local available = {}

  for _, instance in ipairs(runState.coinInstances or {}) do
    table.insert(available, instance.instanceId)
  end

  stageState.purse = {
    availableInstanceIds = available,
    handSlots = {},
    exhaustedInstanceIds = {},
    sleightHistory = {},
    drawHistory = {},
    reorderHistory = {},
    exhaustionEvents = {},
  }

  return stageState.purse
end

function PurseSystem.getStagePurse(runState, stageState)
  if not stageState then
    return nil
  end

  if not stageState.purse then
    PurseSystem.initializeStagePurse(runState, stageState)
  end

  return stageState.purse
end

function PurseSystem.drawHand(runState, stageState, rng)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse or #(purse.handSlots or {}) > 0 then
    return purse and purse.handSlots or {}, nil
  end

  local handSize = PurseSystem.getHandSize(runState)

  if #(purse.availableInstanceIds or {}) == 0 then
    local status = stageState.stageScore >= stageState.targetScore and "cleared" or "failed"
    stageState.stageStatus = status
    table.insert(purse.exhaustionEvents, {
      batchIndex = stageState.batchIndex,
      flipsRemaining = stageState.flipsRemaining,
      status = status,
    })
    return purse.handSlots, "purse_empty"
  end

  local drawn = {}

  for drawIndex = 1, handSize do
    if #purse.availableInstanceIds == 0 then
      break
    end

    local availableIndex = rng:nextInt(1, #purse.availableInstanceIds)
    local instanceId = table.remove(purse.availableInstanceIds, availableIndex)
    local definitionId = PurseSystem.getDefinitionId(runState, instanceId)

    table.insert(purse.handSlots, {
      instanceId = instanceId,
      definitionId = definitionId,
      originalDrawIndex = drawIndex,
      sleightUsed = false,
    })
    table.insert(drawn, instanceId)
  end

  table.insert(purse.drawHistory, {
    batchIndex = stageState.batchIndex + 1,
    drawnInstanceIds = drawn,
  })

  return purse.handSlots, #drawn < handSize and "purse_running_low" or nil
end

function PurseSystem.sleightSlot(runState, stageState, slotIndex, rng, call)
  local purse = PurseSystem.getStagePurse(runState, stageState)
  local slot = purse and purse.handSlots and purse.handSlots[slotIndex] or nil

  if not slot then
    return false, "slot_empty"
  end

  if slot.sleightUsed then
    return false, "sleight_already_used"
  end

  local definition = PurseSystem.getDefinition(runState, slot.instanceId)

  if definition and definition.cannotSleight == true then
    return false, "cannot_sleight"
  end

  local returnedInstanceId = slot.instanceId
  slot.sleightUsed = true
  table.insert(purse.availableInstanceIds, returnedInstanceId)

  local replacementIndex = nil

  if #purse.availableInstanceIds == 1 then
    replacementIndex = 1
  elseif #purse.availableInstanceIds > 1 then
    repeat
      replacementIndex = rng:nextInt(1, #purse.availableInstanceIds)
    until purse.availableInstanceIds[replacementIndex] ~= returnedInstanceId
  end

  local replacementInstanceId = nil

  if replacementIndex then
    replacementInstanceId = table.remove(purse.availableInstanceIds, replacementIndex)
    slot.instanceId = replacementInstanceId
    slot.definitionId = PurseSystem.getDefinitionId(runState, replacementInstanceId)
  else
    slot.instanceId = nil
    slot.definitionId = nil
  end

  local entry = {
    batchIndex = stageState.batchIndex + 1,
    slotIndex = slotIndex,
    returnedInstanceId = returnedInstanceId,
    replacementInstanceId = replacementInstanceId,
    call = call,
  }
  table.insert(purse.sleightHistory, entry)

  return true, entry
end

function PurseSystem.moveHandSlot(stageState, slotIndex, direction)
  local purse = stageState and stageState.purse or nil
  local handSlots = purse and purse.handSlots or nil
  local targetIndex = slotIndex + direction

  if not handSlots or not handSlots[slotIndex] or not handSlots[targetIndex] then
    return false, "cannot_reorder"
  end

  handSlots[slotIndex], handSlots[targetIndex] = handSlots[targetIndex], handSlots[slotIndex]

  table.insert(purse.reorderHistory, {
    batchIndex = stageState.batchIndex + 1,
    fromIndex = slotIndex,
    toIndex = targetIndex,
    finalOrder = PurseSystem.getHandInstanceIds(stageState),
  })

  return true
end

function PurseSystem.getHandInstanceIds(stageState)
  local ids = {}

  for _, slot in ipairs(stageState and stageState.purse and stageState.purse.handSlots or {}) do
    if slot.instanceId then
      table.insert(ids, slot.instanceId)
    end
  end

  return ids
end

function PurseSystem.getResolutionOrder(runState, stageState)
  local entries = {}

  for slotIndex, slot in ipairs(stageState and stageState.purse and stageState.purse.handSlots or {}) do
    if slot.instanceId then
      table.insert(entries, {
        instanceId = slot.instanceId,
        coinId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId),
        slotIndex = slotIndex,
        originalDrawIndex = slot.originalDrawIndex,
        resolutionIndex = #entries + 1,
        sleightUsed = slot.sleightUsed == true,
      })
    end
  end

  return entries
end

function PurseSystem.exhaustHand(stageState)
  local purse = stageState and stageState.purse or nil

  if not purse then
    return {}
  end

  local exhausted = {}

  for _, slot in ipairs(purse.handSlots or {}) do
    if slot.instanceId then
      table.insert(purse.exhaustedInstanceIds, slot.instanceId)
      table.insert(exhausted, slot.instanceId)
    end
  end

  purse.handSlots = {}
  return exhausted
end

function PurseSystem.countZonesByDefinition(runState, stageState)
  local counts = {}

  local function ensure(definitionId)
    counts[definitionId] = counts[definitionId] or { total = 0, available = 0, hand = 0, exhausted = 0 }
    return counts[definitionId]
  end

  for _, instance in ipairs(runState and runState.coinInstances or {}) do
    local count = ensure(instance.definitionId)
    count.total = count.total + 1
  end

  local purse = stageState and stageState.purse or nil
  if purse then
    for _, instanceId in ipairs(purse.availableInstanceIds or {}) do
      local definitionId = PurseSystem.getDefinitionId(runState, instanceId)
      if definitionId then
        ensure(definitionId).available = ensure(definitionId).available + 1
      end
    end

    for _, slot in ipairs(purse.handSlots or {}) do
      if slot.instanceId then
        local definitionId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId)
        if definitionId then
          ensure(definitionId).hand = ensure(definitionId).hand + 1
        end
      end
    end

    for _, instanceId in ipairs(purse.exhaustedInstanceIds or {}) do
      local definitionId = PurseSystem.getDefinitionId(runState, instanceId)
      if definitionId then
        ensure(definitionId).exhausted = ensure(definitionId).exhausted + 1
      end
    end
  end

  return counts
end

function PurseSystem.validateZones(runState, stageState)
  local seen = {}
  local known = {}

  for _, instance in ipairs(runState and runState.coinInstances or {}) do
    if type(instance.instanceId) ~= "string" or instance.instanceId == "" then
      return false, "coin instance missing instanceId"
    end

    if known[instance.instanceId] then
      return false, string.format("duplicate coin instance %s", instance.instanceId)
    end

    if not Coins.getById(instance.definitionId) then
      return false, string.format("coin instance %s references unknown definition %s", instance.instanceId, tostring(instance.definitionId))
    end

    known[instance.instanceId] = true
  end

  local purse = stageState and stageState.purse or nil
  if not purse then
    return true
  end

  local function mark(instanceId, zone)
    if not known[instanceId] then
      return false, string.format("%s references unknown instance %s", zone, tostring(instanceId))
    end

    if seen[instanceId] then
      return false, string.format("coin instance %s exists in both %s and %s", instanceId, seen[instanceId], zone)
    end

    seen[instanceId] = zone
    return true
  end

  for _, instanceId in ipairs(purse.availableInstanceIds or {}) do
    local ok, errorMessage = mark(instanceId, "available")
    if not ok then return false, errorMessage end
  end

  for index, slot in ipairs(purse.handSlots or {}) do
    if slot.instanceId then
      local ok, errorMessage = mark(slot.instanceId, string.format("hand[%d]", index))
      if not ok then return false, errorMessage end
    end
  end

  for _, instanceId in ipairs(purse.exhaustedInstanceIds or {}) do
    local ok, errorMessage = mark(instanceId, "exhausted")
    if not ok then return false, errorMessage end
  end

  return true
end

return PurseSystem
