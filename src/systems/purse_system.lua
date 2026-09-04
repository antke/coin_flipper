local Coins = require("src.content.coins")
local Utils = require("src.core.utils")
local Loadout = require("src.domain.loadout")

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

local function slotHasReorderLock(slot)
  local definition = slot and slot.definitionId and Coins.getById(slot.definitionId) or nil
  return definition and definition.cannotReorder == true
end

local function resetSelectedSlots(purse, slots)
  purse.selectedSlots = slots or {}
  purse.handSlots = purse.selectedSlots
end

local function ensurePurseShape(purse)
  if not purse then
    return nil
  end

  purse.availableInstanceIds = purse.availableInstanceIds or {}
  purse.exhaustedInstanceIds = purse.exhaustedInstanceIds or {}
  purse.sleightHistory = purse.sleightHistory or {}
  purse.drawHistory = purse.drawHistory or {}
  purse.reorderHistory = purse.reorderHistory or {}
  purse.exhaustionEvents = purse.exhaustionEvents or {}
  purse.hookHistory = purse.hookHistory or {}
  purse.selectionHistory = purse.selectionHistory or {}
  purse.refillHistory = purse.refillHistory or {}
  purse.replacementHistory = purse.replacementHistory or {}
  purse.smugglingHistory = purse.smugglingHistory or {}
  purse.boardSlots = purse.boardSlots or {}

  local selectedSlots = purse.selectedSlots or purse.handSlots or {}
  local dealtHandSlots = purse.dealtHandSlots or {}

  if #dealtHandSlots == 0 and #selectedSlots > 0 then
    for slotIndex, slot in ipairs(selectedSlots) do
      if slot and slot.instanceId then
        slot.dealtIndex = slot.dealtIndex or slot.originalDrawIndex or slotIndex
        slot.originalDrawIndex = slot.originalDrawIndex or slot.dealtIndex
        table.insert(dealtHandSlots, slot)
      end
    end
  end

  purse.dealtHandSlots = dealtHandSlots
  resetSelectedSlots(purse, selectedSlots)

  return purse
end

local function refreshSelectedSlotIndices(purse)
  purse = ensurePurseShape(purse)

  if not purse then
    return
  end

  for _, slot in ipairs(purse.dealtHandSlots or {}) do
    if slot then
      slot.selectedSlotIndex = nil
    end
  end

  for slotIndex, slot in ipairs(purse.selectedSlots or {}) do
    if slot then
      slot.selectedSlotIndex = slotIndex
    end
  end
end

local function removeSlotInstance(slots, instanceId)
  local index = 1

  while index <= #(slots or {}) do
    local slot = slots[index]

    if slot and slot.instanceId == instanceId then
      table.remove(slots, index)
    else
      index = index + 1
    end
  end
end

local function buildSlotEntry(runState, slot, slotIndex)
  if not slot or not slot.instanceId then
    return nil
  end

  local dealtIndex = slot.dealtIndex or slot.originalDrawIndex or slotIndex

  return {
    instanceId = slot.instanceId,
    coinId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId),
    slotIndex = slotIndex,
    dealtIndex = dealtIndex,
    originalDrawIndex = slot.originalDrawIndex or dealtIndex,
    selectedSlotIndex = slot.selectedSlotIndex,
    sleightUsed = slot.sleightUsed == true,
    sleightSaved = slot.sleightSaved == true,
    foretold = slot.foretold == true,
    foretoldResult = slot.foretoldResult,
    foretoldBy = slot.foretoldBy,
    foretoldRngRoll = slot.foretoldRngRoll,
    boardSlotIndex = slot.boardSlotIndex,
    overloadSlotIndex = slot.overloadSlotIndex,
    anchorSelectedSlotIndex = slot.anchorSelectedSlotIndex,
    anchorInstanceId = slot.anchorInstanceId,
    anchorCoinId = slot.anchorCoinId,
    anchorOverloadIndex = slot.anchorOverloadIndex,
    smuggled = slot.smuggled == true,
    smuggledBy = slot.smuggledBy,
    contrabandCopy = slot.contrabandCopy == true,
    copiedFromCoinId = slot.copiedFromCoinId,
    copiedFromInstanceId = slot.copiedFromInstanceId,
  }
end

function PurseSystem.getHandSize(runState)
  local resolved = runState and runState.resolvedValues and runState.resolvedValues["purse.handSize"] or nil
  return math.max(1, tonumber(resolved) or DEFAULT_HAND_SIZE)
end

function PurseSystem.getMaxFlipSlots(runState)
  return math.max(1, tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or PurseSystem.getHandSize(runState))
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

local function rebuildCollectionCoinIds(runState)
  local collection = {}

  for _, instance in ipairs(runState.coinInstances or {}) do
    if instance.definitionId and not Utils.contains(collection, instance.definitionId) then
      table.insert(collection, instance.definitionId)
    end
  end

  runState.collectionCoinIds = collection
end

local function removeInstanceFromStagePurse(stageState, instanceId)
  local purse = stageState and stageState.purse or nil

  if not purse then
    return
  end

  ensurePurseShape(purse)

  while removeValue(purse.availableInstanceIds, instanceId) do end
  while removeValue(purse.exhaustedInstanceIds, instanceId) do end
  removeSlotInstance(purse.dealtHandSlots, instanceId)
  removeSlotInstance(purse.selectedSlots, instanceId)
  removeSlotInstance(purse.boardSlots, instanceId)
  resetSelectedSlots(purse, purse.selectedSlots)
end

function PurseSystem.removeInstance(runState, stageState, instanceId)
  if not runState then
    return false, "run_not_initialized"
  end

  if type(instanceId) ~= "string" or instanceId == "" then
    return false, "instance_required"
  end

  if #(runState.coinInstances or {}) <= 1 then
    return false, "last_coin_required"
  end

  local removed = nil

  for index, instance in ipairs(runState.coinInstances or {}) do
    if instance.instanceId == instanceId then
      removed = table.remove(runState.coinInstances, index)
      break
    end
  end

  if not removed then
    return false, "coin_not_found"
  end

  removeInstanceFromStagePurse(stageState, instanceId)
  rebuildCollectionCoinIds(runState)

  local maxSlots = runState.maxFlipSlots or runState.maxActiveCoinSlots or 0
  runState.flipSlots = Loadout.reconcileSlotsDetailed(runState.flipSlots, runState.collectionCoinIds, maxSlots).slots
  runState.persistedFlipSlots = Loadout.reconcileSlotsDetailed(runState.persistedFlipSlots, runState.collectionCoinIds, maxSlots).slots

  return true, {
    instanceId = removed.instanceId,
    definitionId = removed.definitionId,
  }
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
    dealtHandSlots = {},
    selectedSlots = {},
    handSlots = {},
    boardSlots = {},
    exhaustedInstanceIds = {},
    sleightHistory = {},
    drawHistory = {},
    reorderHistory = {},
    exhaustionEvents = {},
    hookHistory = {},
    selectionHistory = {},
    refillHistory = {},
    replacementHistory = {},
    smugglingHistory = {},
  }

  resetSelectedSlots(stageState.purse, stageState.purse.selectedSlots)

  return stageState.purse
end

function PurseSystem.getStagePurse(runState, stageState)
  if not stageState then
    return nil
  end

  if not stageState.purse then
    PurseSystem.initializeStagePurse(runState, stageState)
  end

  return ensurePurseShape(stageState.purse)
end

function PurseSystem.fillHand(runState, stageState, rng)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return {}, "purse_unavailable"
  end

  local bonusDraws = math.max(0, tonumber(purse.nextHandBonusDraws) or 0)
  local handSize = PurseSystem.getHandSize(runState) + bonusDraws
  purse.nextHandBonusDraws = 0

  if #(purse.availableInstanceIds or {}) == 0 and #(purse.dealtHandSlots or {}) == 0 then
    local status = stageState.scoreAppliedToHp >= stageState.opponentHp and "cleared" or "failed"
    stageState.stageStatus = status
    table.insert(purse.exhaustionEvents, {
      batchIndex = stageState.batchIndex,
      flipsRemaining = stageState.flipsRemaining,
      status = status,
    })
    return purse.dealtHandSlots, "purse_empty"
  end

  local drawn = {}
  local startingCount = #(purse.dealtHandSlots or {})

  for drawIndex = startingCount + 1, handSize do
    if #purse.availableInstanceIds == 0 then
      break
    end

    local availableIndex = rng:nextInt(1, #purse.availableInstanceIds)
    local instanceId = table.remove(purse.availableInstanceIds, availableIndex)
    local definitionId = PurseSystem.getDefinitionId(runState, instanceId)

    table.insert(purse.dealtHandSlots, {
      instanceId = instanceId,
      definitionId = definitionId,
      dealtIndex = drawIndex,
      originalDrawIndex = drawIndex,
      sleightUsed = false,
    })
    table.insert(drawn, instanceId)
  end

  table.insert(purse.drawHistory, {
    batchIndex = stageState.batchIndex + 1,
    dealtInstanceIds = Utils.copyArray(drawn),
    drawnInstanceIds = drawn,
    bonusDrawCount = bonusDraws,
    heldInstanceIds = PurseSystem.getDealtInstanceIds(stageState),
  })

  return purse.dealtHandSlots, #purse.dealtHandSlots < handSize and "purse_running_low" or nil
end

function PurseSystem.dealHand(runState, stageState, rng)
  return PurseSystem.fillHand(runState, stageState, rng)
end

function PurseSystem.addNextHandDraws(stageState, amount)
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  if not purse then
    return nil, "purse_unavailable"
  end

  local delta = math.max(0, tonumber(amount) or 0)
  purse.nextHandBonusDraws = math.max(0, tonumber(purse.nextHandBonusDraws) or 0) + delta

  return purse.nextHandBonusDraws
end

local function findDealtSlot(purse, selector)
  if not purse then
    return nil, nil
  end

  if type(selector) == "number" then
    return purse.dealtHandSlots and purse.dealtHandSlots[selector] or nil, selector
  end

  for dealtIndex, slot in ipairs(purse.dealtHandSlots or {}) do
    if slot and slot.instanceId == selector then
      return slot, dealtIndex
    end
  end

  return nil, nil
end

local function findSelectedSlot(purse, selector)
  if not purse then
    return nil, nil
  end

  if type(selector) == "number" then
    return purse.selectedSlots and purse.selectedSlots[selector] or nil, selector
  end

  for slotIndex, slot in ipairs(purse.selectedSlots or {}) do
    if slot and slot.instanceId == selector then
      return slot, slotIndex
    end
  end

  return nil, nil
end

local function recordSelection(purse, stageState, rule, maxSlots)
  local selectedIds = PurseSystem.getHandInstanceIds(stageState)
  local entry = {
    batchIndex = stageState and (stageState.batchIndex + 1) or nil,
    rule = rule,
    maxFlipSlots = maxSlots,
    selectedInstanceIds = Utils.copyArray(selectedIds),
  }

  table.insert(purse.selectionHistory, entry)

  local latestDraw = purse.drawHistory and purse.drawHistory[#purse.drawHistory] or nil
  if latestDraw then
    latestDraw.selectedInstanceIds = Utils.copyArray(selectedIds)
  end

  return entry
end

function PurseSystem.selectDealtSlot(runState, stageState, selector)
  local setupOk, setupError = require("src.systems.trick_board_system").requireSetup(stageState)
  if not setupOk then return false, setupError end
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return false, "purse_unavailable"
  end

  local slot, dealtIndex = findDealtSlot(purse, selector)

  if not slot or not slot.instanceId then
    return false, "dealt_slot_empty"
  end

  refreshSelectedSlotIndices(purse)

  if slot.selectedSlotIndex ~= nil then
    return false, "already_selected"
  end

  local maxSlots = PurseSystem.getMaxFlipSlots(runState)

  if #(purse.selectedSlots or {}) >= maxSlots then
    return false, "flip_slots_full"
  end

  table.insert(purse.selectedSlots, slot)
  resetSelectedSlots(purse, purse.selectedSlots)
  refreshSelectedSlotIndices(purse)
  recordSelection(purse, stageState, "manual_select", maxSlots)

  return true, buildSlotEntry(runState, slot, #(purse.selectedSlots or {})), dealtIndex
end

function PurseSystem.deselectSelectedSlot(runState, stageState, selector)
  local setupOk, setupError = require("src.systems.trick_board_system").requireSetup(stageState)
  if not setupOk then return false, setupError end
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return false, "purse_unavailable"
  end

  local slot, slotIndex = findSelectedSlot(purse, selector)

  if not slot or not slot.instanceId then
    return false, "selected_slot_empty"
  end

  local entry = buildSlotEntry(runState, slot, slotIndex)
  table.remove(purse.selectedSlots, slotIndex)
  resetSelectedSlots(purse, purse.selectedSlots)
  refreshSelectedSlotIndices(purse)
  recordSelection(purse, stageState, "manual_deselect", PurseSystem.getMaxFlipSlots(runState))

  return true, entry
end

function PurseSystem.toggleDealtSelection(runState, stageState, selector)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return false, "purse_unavailable"
  end

  refreshSelectedSlotIndices(purse)

  local slot = findDealtSlot(purse, selector)

  if not slot or not slot.instanceId then
    return false, "dealt_slot_empty"
  end

  if slot.selectedSlotIndex ~= nil then
    local ok, result = PurseSystem.deselectSelectedSlot(runState, stageState, slot.selectedSlotIndex)
    return ok, result, "deselect"
  end

  local ok, result = PurseSystem.selectDealtSlot(runState, stageState, selector)
  return ok, result, "select"
end

function PurseSystem.replaceHeldCoin(runState, stageState, selector, rng)
  local TrickBoardSystem = require("src.systems.trick_board_system")
  local setupOk, setupError = TrickBoardSystem.requireSetup(stageState)
  if not setupOk then
    return false, setupError
  end

  local purse = PurseSystem.getStagePurse(runState, stageState)
  if not purse then
    return false, "purse_unavailable"
  end

  local charges = stageState.trickBoard and tonumber(stageState.trickBoard.replacementsRemaining) or 0
  if charges <= 0 then
    return false, "no_replacements_remaining"
  end
  if #(purse.availableInstanceIds or {}) == 0 then
    return false, "draw_pile_empty"
  end

  refreshSelectedSlotIndices(purse)
  local slot, dealtIndex = findDealtSlot(purse, selector)
  if not slot or not slot.instanceId then
    return false, "dealt_slot_empty"
  end
  if slot.selectedSlotIndex ~= nil then
    return false, "committed_coin_cannot_be_replaced"
  end

  local spentInstanceId = slot.instanceId
  local spentDefinitionId = slot.definitionId or PurseSystem.getDefinitionId(runState, spentInstanceId)
  if not Utils.contains(purse.exhaustedInstanceIds, spentInstanceId) then
    table.insert(purse.exhaustedInstanceIds, spentInstanceId)
  end

  local availableIndex = rng:nextInt(1, #purse.availableInstanceIds)
  local drawnInstanceId = table.remove(purse.availableInstanceIds, availableIndex)
  local drawnDefinitionId = PurseSystem.getDefinitionId(runState, drawnInstanceId)
  purse.dealtHandSlots[dealtIndex] = {
    instanceId = drawnInstanceId,
    definitionId = drawnDefinitionId,
    dealtIndex = slot.dealtIndex or dealtIndex,
    originalDrawIndex = slot.originalDrawIndex or dealtIndex,
    sleightUsed = false,
  }

  stageState.trickBoard.replacementsRemaining = charges - 1
  local event = {
    batchIndex = stageState.batchIndex + 1,
    handPosition = dealtIndex,
    spentInstanceId = spentInstanceId,
    spentDefinitionId = spentDefinitionId,
    drawnInstanceId = drawnInstanceId,
    drawnDefinitionId = drawnDefinitionId,
    availableIndex = availableIndex,
    replacementsRemaining = stageState.trickBoard.replacementsRemaining,
  }
  table.insert(purse.replacementHistory, Utils.clone(event))
  table.insert(stageState.trickBoard.replacementHistory, Utils.clone(event))
  return true, event
end

function PurseSystem.setSelectedSlotsFromEntries(runState, stageState, entries, options)
  local setupOk, setupError = require("src.systems.trick_board_system").requireSetup(stageState)
  if not setupOk then return false, setupError end
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return false, "purse_unavailable"
  end

  local maxSlots = PurseSystem.getMaxFlipSlots(runState)
  local selected = {}
  local seen = {}

  for _, entry in ipairs(entries or {}) do
    local selector = entry and entry.instanceId or nil
    local slot = selector and findDealtSlot(purse, selector) or nil

    if not slot or not slot.instanceId then
      return false, "selected_slot_not_dealt"
    end

    if seen[slot.instanceId] then
      return false, "duplicate_selected_slot"
    end

    if #selected >= maxSlots then
      return false, "too_many_selected_slots"
    end

    seen[slot.instanceId] = true
    table.insert(selected, slot)
  end

  resetSelectedSlots(purse, selected)
  refreshSelectedSlotIndices(purse)

  if not (options and options.suppressHistory) then
    recordSelection(purse, stageState, options and options.rule or "transcript_selection", maxSlots)
  end

  return true, PurseSystem.getSelectedSlotEntries(runState, stageState)
end

function PurseSystem.selectDefaultFlipSlots(runState, stageState)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return {}, "purse_unavailable"
  end

  if #(purse.selectedSlots or {}) > 0 then
    return purse.selectedSlots, nil
  end

  local maxSlots = PurseSystem.getMaxFlipSlots(runState)
  local selected = {}

  for _, slot in ipairs(purse.dealtHandSlots or {}) do
    if slot.instanceId then
      table.insert(selected, slot)

      if #selected >= maxSlots then
        break
      end
    end
  end

  resetSelectedSlots(purse, selected)
  refreshSelectedSlotIndices(purse)

  recordSelection(purse, stageState, "first_legal_flip_slots", maxSlots)

  return purse.selectedSlots, #selected == 0 and "hand_empty" or nil
end

function PurseSystem.drawHand(runState, stageState, rng)
  local _, dealWarning = PurseSystem.dealHand(runState, stageState, rng)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if dealWarning == "purse_empty" then
    return purse and purse.handSlots or {}, dealWarning
  end

  local selectedSlots, selectWarning = PurseSystem.selectDefaultFlipSlots(runState, stageState)
  return selectedSlots, selectWarning or dealWarning
end

function PurseSystem.moveHandSlot(stageState, slotIndex, direction)
  local setupOk, setupError = require("src.systems.trick_board_system").requireSetup(stageState)
  if not setupOk then return false, setupError end
  local purse = stageState and stageState.purse or nil
  local handSlots = purse and purse.handSlots or nil
  local targetIndex = slotIndex + direction

  if not handSlots or not handSlots[slotIndex] or not handSlots[targetIndex] then
    return false, "cannot_reorder"
  end

  if slotHasReorderLock(handSlots[slotIndex]) or slotHasReorderLock(handSlots[targetIndex]) then
    return false, "cannot_reorder"
  end

  local movedInstanceId = handSlots[slotIndex].instanceId
  local movedDefinitionId = handSlots[slotIndex].definitionId

  handSlots[slotIndex], handSlots[targetIndex] = handSlots[targetIndex], handSlots[slotIndex]
  refreshSelectedSlotIndices(purse)

  local entry = {
    batchIndex = stageState.batchIndex + 1,
    fromIndex = slotIndex,
    toIndex = targetIndex,
    movedInstanceId = movedInstanceId,
    movedDefinitionId = movedDefinitionId,
    finalOrder = PurseSystem.getHandInstanceIds(stageState),
  }
  table.insert(purse.reorderHistory, entry)

  return true, entry
end

function PurseSystem.getHandInstanceIds(stageState)
  local ids = {}
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  for _, slot in ipairs(purse and purse.handSlots or {}) do
    if slot.instanceId then
      table.insert(ids, slot.instanceId)
    end
  end

  return ids
end

function PurseSystem.getDealtInstanceIds(stageState)
  local ids = {}
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  for _, slot in ipairs(purse and purse.dealtHandSlots or {}) do
    if slot.instanceId then
      table.insert(ids, slot.instanceId)
    end
  end

  return ids
end

function PurseSystem.getDealtHandEntries(runState, stageState)
  local entries = {}
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  refreshSelectedSlotIndices(purse)

  for dealtIndex, slot in ipairs(purse and purse.dealtHandSlots or {}) do
    local entry = buildSlotEntry(runState, slot, dealtIndex)
    if entry then
      entry.slotIndex = nil
      table.insert(entries, entry)
    end
  end

  return entries
end

function PurseSystem.getSelectedSlotEntries(runState, stageState)
  local entries = {}
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  refreshSelectedSlotIndices(purse)

  for slotIndex, slot in ipairs(purse and purse.selectedSlots or {}) do
    local entry = buildSlotEntry(runState, slot, slotIndex)
    if entry then
      entry.selectedSlotIndex = slotIndex
      table.insert(entries, entry)
    end
  end

  return entries
end

function PurseSystem.getBoardSlotEntries(runState, stageState)
  local entries = {}
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  refreshSelectedSlotIndices(purse)

  for overloadIndex, slot in ipairs(purse and purse.boardSlots or {}) do
    local boardSlotIndex = slot.boardSlotIndex or (#(purse.selectedSlots or {}) + overloadIndex)
    local entry = buildSlotEntry(runState, slot, boardSlotIndex)
    if entry then
      entry.selectedSlotIndex = nil
      entry.boardSlotIndex = boardSlotIndex
      entry.overloadSlotIndex = slot.overloadSlotIndex or overloadIndex
      table.insert(entries, entry)
    end
  end

  return entries
end

function PurseSystem.smuggleCoinFromHand(runState, stageState, options)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return nil, "purse_unavailable"
  end

  local maxOverloadSlots = math.max(1, tonumber(options and options.maxOverloadSlots) or 1)
  if #(purse.boardSlots or {}) >= maxOverloadSlots then
    return nil, "overload_slot_full"
  end

  refreshSelectedSlotIndices(purse)

  local chosen = nil
  local targetInstanceId = options and options.instanceId or nil

  if not targetInstanceId then
    return nil, "target_instance_required"
  end

  for _, slot in ipairs(purse.dealtHandSlots or {}) do
    if slot.instanceId and slot.selectedSlotIndex == nil and slot.smuggled ~= true then
      if slot.instanceId == targetInstanceId then
        chosen = slot
        break
      end
    end
  end

  if not chosen then
    return nil, "no_unselected_dealt_coin"
  end

  local overloadSlotIndex = #(purse.boardSlots or {}) + 1
  local boardSlotIndex = #(purse.selectedSlots or {}) + overloadSlotIndex
  local sourceId = options and options.sourceId or nil
  local anchorSelectedSlotIndex = options and options.anchorSelectedSlotIndex or nil
  local anchorInstanceId = options and options.anchorInstanceId or nil
  local anchorCoinId = options and options.anchorCoinId or nil
  local anchorOverloadIndex = 1

  for _, slot in ipairs(purse.boardSlots or {}) do
    if anchorInstanceId ~= nil and slot.anchorInstanceId == anchorInstanceId then
      anchorOverloadIndex = anchorOverloadIndex + 1
    end
  end

  chosen.smuggled = true
  chosen.smuggledBy = sourceId
  chosen.overloadSlotIndex = overloadSlotIndex
  chosen.boardSlotIndex = boardSlotIndex
  chosen.anchorSelectedSlotIndex = anchorSelectedSlotIndex
  chosen.anchorInstanceId = anchorInstanceId
  chosen.anchorCoinId = anchorCoinId
  chosen.anchorOverloadIndex = anchorOverloadIndex

  table.insert(purse.boardSlots, chosen)

  local entry = buildSlotEntry(runState, chosen, boardSlotIndex)
  entry.selectedSlotIndex = nil
  entry.boardSlotIndex = boardSlotIndex
  entry.overloadSlotIndex = overloadSlotIndex
  entry.anchorSelectedSlotIndex = anchorSelectedSlotIndex
  entry.anchorInstanceId = anchorInstanceId
  entry.anchorCoinId = anchorCoinId
  entry.anchorOverloadIndex = anchorOverloadIndex

  local historyEntry = Utils.clone(entry)
  historyEntry.batchIndex = stageState and (stageState.batchIndex + 1) or nil
  historyEntry.sourceId = sourceId
  table.insert(purse.smugglingHistory, historyEntry)

  return entry
end

function PurseSystem.copySmuggledBoardCoin(runState, stageState, options)
  local purse = PurseSystem.getStagePurse(runState, stageState)

  if not purse then
    return nil, "purse_unavailable"
  end

  ensurePurseShape(purse)

  local maxOverloadSlots = math.max(1, tonumber(options and options.maxOverloadSlots) or 1)
  if #(purse.boardSlots or {}) >= maxOverloadSlots then
    return nil, "overload_slot_full"
  end

  local candidates = {}
  for _, slot in ipairs(purse.boardSlots or {}) do
    if slot and slot.instanceId and slot.smuggled == true then
      table.insert(candidates, slot)
    end
  end

  if #candidates == 0 then
    return nil, "no_smuggled_coin"
  end

  local rng = options and options.rng or nil
  local source = rng and rng.choose and rng:choose(candidates) or candidates[1]
  local sourceId = options and options.sourceId or nil
  local overloadSlotIndex = #(purse.boardSlots or {}) + 1
  local boardSlotIndex = #(purse.selectedSlots or {}) + overloadSlotIndex

  runState.counters.contrabandCopiesCreated = (runState.counters.contrabandCopiesCreated or 0) + 1
  local copy = {
    instanceId = string.format("contraband_%03d", runState.counters.contrabandCopiesCreated),
    definitionId = source.definitionId or PurseSystem.getDefinitionId(runState, source.instanceId),
    dealtIndex = source.dealtIndex,
    originalDrawIndex = source.originalDrawIndex or source.dealtIndex,
    smuggled = true,
    smuggledBy = sourceId,
    contrabandCopy = true,
    copiedFromCoinId = source.definitionId or PurseSystem.getDefinitionId(runState, source.instanceId),
    copiedFromInstanceId = source.instanceId,
    overloadSlotIndex = overloadSlotIndex,
    boardSlotIndex = boardSlotIndex,
    anchorSelectedSlotIndex = source.anchorSelectedSlotIndex,
    anchorInstanceId = source.anchorInstanceId,
    anchorCoinId = source.anchorCoinId,
    anchorOverloadIndex = (source.anchorOverloadIndex or 1) + 1,
  }

  for _, slot in ipairs(purse.boardSlots or {}) do
    if copy.anchorInstanceId ~= nil
      and slot.anchorInstanceId == copy.anchorInstanceId
      and (slot.anchorOverloadIndex or 0) >= copy.anchorOverloadIndex then
      copy.anchorOverloadIndex = (slot.anchorOverloadIndex or 0) + 1
    end
  end

  table.insert(purse.boardSlots, copy)

  local entry = buildSlotEntry(runState, copy, boardSlotIndex)
  entry.selectedSlotIndex = nil
  entry.boardSlotIndex = boardSlotIndex
  entry.overloadSlotIndex = overloadSlotIndex
  entry.anchorSelectedSlotIndex = copy.anchorSelectedSlotIndex
  entry.anchorInstanceId = copy.anchorInstanceId
  entry.anchorCoinId = copy.anchorCoinId
  entry.anchorOverloadIndex = copy.anchorOverloadIndex

  local historyEntry = Utils.clone(entry)
  historyEntry.batchIndex = stageState and (stageState.batchIndex + 1) or nil
  historyEntry.sourceId = sourceId
  table.insert(purse.smugglingHistory, historyEntry)

  return entry, nil, source
end

function PurseSystem.getResolutionOrder(runState, stageState)
  local entries = {}
  local purse = stageState and stageState.purse and ensurePurseShape(stageState.purse) or nil

  refreshSelectedSlotIndices(purse)

  for slotIndex, slot in ipairs(purse and purse.handSlots or {}) do
    local entry = buildSlotEntry(runState, slot, slotIndex)
    if entry then
      entry.selectedSlotIndex = slotIndex
      entry.resolutionIndex = #entries + 1
      table.insert(entries, entry)
    end
  end

  for overloadIndex, slot in ipairs(purse and purse.boardSlots or {}) do
    local boardSlotIndex = slot.boardSlotIndex or (#(purse.handSlots or {}) + overloadIndex)
    local entry = buildSlotEntry(runState, slot, boardSlotIndex)
    if entry then
      entry.selectedSlotIndex = nil
      entry.boardSlotIndex = boardSlotIndex
      entry.overloadSlotIndex = slot.overloadSlotIndex or overloadIndex
      entry.resolutionIndex = #entries + 1
      table.insert(entries, entry)
    end
  end

  return entries
end

function PurseSystem.refillHand(stageState, runState, rng)
  local purse = stageState and stageState.purse or nil

  if not purse then
    return {
      refillRule = "selected_spend_unselected_hold",
      exhaustedInstanceIds = {},
      returnedInstanceIds = {},
      availableInstanceIdsAfter = {},
      exhaustedInstanceIdsAfter = {},
    }
  end

  ensurePurseShape(purse)

  local exhausted = {}
  local held = {}
  local selectedSet = {}
  local boardSet = {}
  local smuggled = {}
  local palmed = {}

  for _, slot in ipairs(purse.selectedSlots or {}) do
    if slot.instanceId then
      if slot.sleightSaved == true then
        table.insert(palmed, slot.instanceId)
      else
        selectedSet[slot.instanceId] = true
        if not Utils.contains(purse.exhaustedInstanceIds, slot.instanceId) then
          table.insert(purse.exhaustedInstanceIds, slot.instanceId)
        end
        table.insert(exhausted, slot.instanceId)
      end
    end
  end

  for _, slot in ipairs(purse.boardSlots or {}) do
    if slot.instanceId then
      boardSet[slot.instanceId] = true

      if slot.contrabandCopy ~= true then
        if not Utils.contains(purse.exhaustedInstanceIds, slot.instanceId) then
          table.insert(purse.exhaustedInstanceIds, slot.instanceId)
        end

        if not Utils.contains(exhausted, slot.instanceId) then
          table.insert(exhausted, slot.instanceId)
        end
      end

      if slot.smuggled == true then
        table.insert(smuggled, slot.instanceId)
      end
    end
  end

  local retainedSlots = {}
  for _, slot in ipairs(purse.dealtHandSlots or {}) do
    if slot.instanceId and not selectedSet[slot.instanceId] and not boardSet[slot.instanceId] then
      slot.selectedSlotIndex = nil
      slot.boardSlotIndex = nil
      slot.overloadSlotIndex = nil
      slot.smuggled = nil
      slot.smuggledBy = nil
      slot.sleightSaved = nil
      slot.bossPalmed = nil
      slot.sleightUsed = false
      table.insert(retainedSlots, slot)
      table.insert(held, slot.instanceId)
    end
  end

  local event = {
    batchIndex = stageState and stageState.batchIndex or nil,
    refillRule = "selected_spend_unselected_hold",
    exhaustedInstanceIds = Utils.copyArray(exhausted),
    heldInstanceIds = Utils.copyArray(held),
    returnedInstanceIds = {},
    smuggledInstanceIds = Utils.copyArray(smuggled),
    palmedInstanceIds = Utils.copyArray(palmed),
    boardSlotCount = #(purse.boardSlots or {}),
    availableInstanceIdsAfter = Utils.copyArray(purse.availableInstanceIds or {}),
    exhaustedInstanceIdsAfter = Utils.copyArray(purse.exhaustedInstanceIds or {}),
  }

  purse.dealtHandSlots = retainedSlots
  purse.boardSlots = {}
  resetSelectedSlots(purse, {})

  local beforeFill = {}
  for _, slot in ipairs(retainedSlots) do
    table.insert(beforeFill, slot.instanceId)
  end
  if runState and rng and stageState.stageStatus == "active" then
    PurseSystem.fillHand(runState, stageState, rng)
  end
  local heldSet = {}
  for _, instanceId in ipairs(beforeFill) do heldSet[instanceId] = true end
  event.drawnInstanceIds = {}
  for _, slot in ipairs(purse.dealtHandSlots or {}) do
    if not heldSet[slot.instanceId] then
      table.insert(event.drawnInstanceIds, slot.instanceId)
    end
  end
  event.dealtInstanceIdsAfter = PurseSystem.getDealtInstanceIds(stageState)
  event.availableInstanceIdsAfter = Utils.copyArray(purse.availableInstanceIds or {})
  event.exhaustedInstanceIdsAfter = Utils.copyArray(purse.exhaustedInstanceIds or {})
  table.insert(purse.refillHistory, Utils.clone(event))

  return event
end

function PurseSystem.exhaustHand(stageState)
  local event = PurseSystem.refillHand(stageState)
  return event.exhaustedInstanceIds or {}
end

function PurseSystem.countZonesByDefinition(runState, stageState)
  local counts = {}

  local function ensure(definitionId)
    counts[definitionId] = counts[definitionId] or { total = 0, available = 0, dealt = 0, selected = 0, hand = 0, board = 0, exhausted = 0 }
    return counts[definitionId]
  end

  for _, instance in ipairs(runState and runState.coinInstances or {}) do
    local count = ensure(instance.definitionId)
    count.total = count.total + 1
  end

  local purse = stageState and stageState.purse or nil
  if purse then
    ensurePurseShape(purse)

    for _, instanceId in ipairs(purse.availableInstanceIds or {}) do
      local definitionId = PurseSystem.getDefinitionId(runState, instanceId)
      if definitionId then
        ensure(definitionId).available = ensure(definitionId).available + 1
      end
    end

    for _, slot in ipairs(purse.dealtHandSlots or {}) do
      if slot.instanceId then
        local definitionId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId)
        if definitionId then
          ensure(definitionId).dealt = ensure(definitionId).dealt + 1
        end
      end
    end

    for _, slot in ipairs(purse.handSlots or {}) do
      if slot.instanceId then
        local definitionId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId)
        if definitionId then
          local count = ensure(definitionId)
          count.selected = count.selected + 1
          count.hand = count.selected
        end
      end
    end

    for _, slot in ipairs(purse.boardSlots or {}) do
      if slot.instanceId then
        local definitionId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId)
        if definitionId then
          ensure(definitionId).board = ensure(definitionId).board + 1
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

  ensurePurseShape(purse)

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

  local dealtInstances = {}

  for index, slot in ipairs(purse.dealtHandSlots or {}) do
    if slot.instanceId then
      local ok, errorMessage = mark(slot.instanceId, string.format("dealt[%d]", index))
      if not ok then return false, errorMessage end
      dealtInstances[slot.instanceId] = true
    end
  end

  local selectedInstances = {}
  for index, slot in ipairs(purse.handSlots or {}) do
    if slot.instanceId then
      if selectedInstances[slot.instanceId] then
        return false, string.format("coin instance %s is selected more than once", slot.instanceId)
      end

      if not dealtInstances[slot.instanceId] then
        return false, string.format("selected[%d] references instance %s outside dealt hand", index, tostring(slot.instanceId))
      end

      selectedInstances[slot.instanceId] = true
    end
  end

  local boardInstances = {}
  for index, slot in ipairs(purse.boardSlots or {}) do
    if slot.instanceId then
      if boardInstances[slot.instanceId] then
        return false, string.format("coin instance %s is on the board more than once", slot.instanceId)
      end

      if selectedInstances[slot.instanceId] then
        return false, string.format("board[%d] references selected instance %s", index, tostring(slot.instanceId))
      end

      if slot.contrabandCopy ~= true and not dealtInstances[slot.instanceId] then
        return false, string.format("board[%d] references instance %s outside dealt hand", index, tostring(slot.instanceId))
      end

      boardInstances[slot.instanceId] = true
    end
  end

  for _, instanceId in ipairs(purse.exhaustedInstanceIds or {}) do
    local ok, errorMessage = mark(instanceId, "exhausted")
    if not ok then return false, errorMessage end
  end

  return true
end

return PurseSystem
