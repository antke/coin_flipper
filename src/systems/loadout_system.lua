local GameConfig = require("src.app.config")
local Loadout = require("src.domain.loadout")
local Validator = require("src.core.validator")
local Utils = require("src.core.utils")

local LoadoutSystem = {}

function LoadoutSystem.createSelection(runState)
  local reconciliation = Validator.reconcilePersistedLoadout(runState)
  local selection = Loadout.cloneSlots(reconciliation.slots, runState.maxActiveCoinSlots)
  local originalCount = Loadout.countEquipped(reconciliation.originalSlots, runState.maxActiveCoinSlots)

  reconciliation.reconciledSlots = Loadout.cloneSlots(selection, runState.maxActiveCoinSlots)
  reconciliation.reconciledCanonicalKey = Loadout.toCanonicalKey(reconciliation.reconciledSlots, runState.maxActiveCoinSlots)

  if Loadout.countEquipped(selection, runState.maxActiveCoinSlots) == 0 then
    for slotIndex = 1, runState.maxActiveCoinSlots do
      local coinId = runState.collectionCoinIds[slotIndex]
      selection[slotIndex] = coinId

      if coinId then
        table.insert(reconciliation.changes, {
          slotIndex = slotIndex,
          coinId = coinId,
          reason = "fallback_fill",
        })
      end
    end

    reconciliation.usedFallback = true
    reconciliation.fallbackReason = originalCount > 0 and "persisted_invalid" or "persisted_empty"
  else
    reconciliation.usedFallback = false
    reconciliation.fallbackReason = nil
  end

  reconciliation.originalCanonicalKey = Loadout.toCanonicalKey(reconciliation.originalSlots, runState.maxActiveCoinSlots)
  reconciliation.reconciledCanonicalKey = Loadout.toCanonicalKey(reconciliation.slots, runState.maxActiveCoinSlots)
  reconciliation.preparedSlots = Loadout.cloneSlots(selection, runState.maxActiveCoinSlots)
  reconciliation.preparedCanonicalKey = Loadout.toCanonicalKey(selection, runState.maxActiveCoinSlots)
  reconciliation.selectionCanonicalKey = Loadout.toCanonicalKey(selection, runState.maxActiveCoinSlots)
  reconciliation.selectionSlots = Loadout.cloneSlots(selection, runState.maxActiveCoinSlots)
  reconciliation.changed = reconciliation.originalCanonicalKey ~= reconciliation.selectionCanonicalKey or #(reconciliation.changes or {}) > 0

  return Loadout.normalizeSlots(selection, runState.maxActiveCoinSlots), reconciliation
end

function LoadoutSystem.assignCoinToSlot(runState, selection, coinId, slotIndex)
  if not Utils.contains(runState.collectionCoinIds, coinId) then
    return Loadout.normalizeSlots(selection, runState.maxActiveCoinSlots), "coin_not_owned"
  end

  local nextSelection = Loadout.normalizeSlots(selection, runState.maxActiveCoinSlots)

  for existingSlot = 1, runState.maxActiveCoinSlots do
    if nextSelection[existingSlot] == coinId then
      nextSelection[existingSlot] = nil
    end
  end

  nextSelection[slotIndex] = coinId
  return nextSelection
end

function LoadoutSystem.clearSlot(runState, selection, slotIndex)
  local nextSelection = Loadout.normalizeSlots(selection, runState.maxActiveCoinSlots)
  nextSelection[slotIndex] = nil
  return nextSelection
end

function LoadoutSystem.commitLoadout(runState, selection)
  local ok, result = Validator.validateLoadoutSelection(runState, selection)

  if not ok then
    return nil, result
  end

  local normalizedSelection = Loadout.normalizeSlots(result, runState.maxActiveCoinSlots)

  runState.equippedCoinSlots = normalizedSelection
  runState.persistedLoadoutSlots = Loadout.cloneSlots(normalizedSelection, runState.maxActiveCoinSlots)

  if runState.history and runState.history.loadoutCommits then
    local entry = {
      roundIndex = runState.roundIndex,
      stageId = runState.currentStageId,
      slots = Loadout.cloneSlots(runState.equippedCoinSlots, runState.maxActiveCoinSlots),
      compactCoinIds = Loadout.compactSlots(runState.equippedCoinSlots, runState.maxActiveCoinSlots),
      canonicalKey = Loadout.toCanonicalKey(runState.equippedCoinSlots, runState.maxActiveCoinSlots),
    }
    local replaced = false

    for index, existing in ipairs(runState.history.loadoutCommits) do
      if existing.roundIndex == entry.roundIndex and existing.stageId == entry.stageId then
        runState.history.loadoutCommits[index] = entry
        replaced = true
        break
      end
    end

    if not replaced then
      table.insert(runState.history.loadoutCommits, entry)
    end
  end

  return runState.equippedCoinSlots
end

function LoadoutSystem.getResolutionOrder(runState)
  local compact = {}

  for slotIndex = 1, runState.maxActiveCoinSlots do
    local coinId = runState.equippedCoinSlots[slotIndex]

    if coinId then
      table.insert(compact, {
        coinId = coinId,
        slotIndex = slotIndex,
      })
    end
  end

  if GameConfig.get("flip.orderMode") == "slot_order" then
    for resolutionIndex, entry in ipairs(compact) do
      entry.resolutionIndex = resolutionIndex
    end

    return compact
  end

  table.sort(compact, function(left, right)
    if left.coinId ~= right.coinId then
      return left.coinId < right.coinId
    end

    return left.slotIndex < right.slotIndex
  end)

  for resolutionIndex, entry in ipairs(compact) do
    entry.resolutionIndex = resolutionIndex
  end

  return compact
end

return LoadoutSystem
