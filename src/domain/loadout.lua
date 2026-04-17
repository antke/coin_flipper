local Loadout = {}

function Loadout.normalizeSlots(slots, maxSlots)
  local normalized = {}

  for slotIndex = 1, (maxSlots or 0) do
    normalized[slotIndex] = slots and slots[slotIndex] or nil
  end

  return normalized
end

function Loadout.cloneSlots(slots, maxSlots)
  return Loadout.normalizeSlots(slots, maxSlots)
end

function Loadout.countEquipped(slots, maxSlots)
  local count = 0

  for slotIndex = 1, (maxSlots or 0) do
    if slots and slots[slotIndex] ~= nil then
      count = count + 1
    end
  end

  return count
end

function Loadout.compactSlots(slots, maxSlots)
  local compact = {}

  for slotIndex = 1, (maxSlots or 0) do
    local coinId = slots and slots[slotIndex] or nil

    if coinId ~= nil then
      table.insert(compact, coinId)
    end
  end

  return compact
end

function Loadout.containsDuplicateIds(slots, maxSlots)
  local seen = {}

  for slotIndex = 1, (maxSlots or 0) do
    local coinId = slots and slots[slotIndex] or nil

    if coinId ~= nil then
      if seen[coinId] then
        return true, coinId
      end

      seen[coinId] = true
    end
  end

  return false, nil
end

function Loadout.reconcileSlotsAgainstCollection(slots, collectionCoinIds, maxSlots)
  local details = Loadout.reconcileSlotsDetailed(slots, collectionCoinIds, maxSlots)
  return details.slots, details.firstDuplicateId
end

function Loadout.reconcileSlotsDetailed(slots, collectionCoinIds, maxSlots)
  local normalized = Loadout.normalizeSlots(slots, maxSlots)
  local collectionIndex = {}
  local changes = {}
  local firstDuplicateId = nil

  for _, coinId in ipairs(collectionCoinIds or {}) do
    collectionIndex[coinId] = true
  end

  for slotIndex = 1, (maxSlots or 0) do
    if normalized[slotIndex] ~= nil and not collectionIndex[normalized[slotIndex]] then
      table.insert(changes, {
        slotIndex = slotIndex,
        coinId = normalized[slotIndex],
        reason = "not_owned",
      })
      normalized[slotIndex] = nil
    end
  end

  local hasDuplicate, duplicateId = Loadout.containsDuplicateIds(normalized, maxSlots)

  if hasDuplicate then
    local seen = {}

    for slotIndex = 1, maxSlots do
      local coinId = normalized[slotIndex]
      if coinId ~= nil then
        if seen[coinId] then
          if not firstDuplicateId then
            firstDuplicateId = coinId
          end

          table.insert(changes, {
            slotIndex = slotIndex,
            coinId = coinId,
            keptSlotIndex = seen[coinId],
            reason = "duplicate",
          })
          normalized[slotIndex] = nil
        else
          seen[coinId] = true
        end
      end
    end
  end

  return {
    originalSlots = Loadout.normalizeSlots(slots, maxSlots),
    slots = normalized,
    changed = #changes > 0,
    changes = changes,
    firstDuplicateId = firstDuplicateId or duplicateId,
  }
end

function Loadout.toCanonicalKey(slots, maxSlots)
  local compact = Loadout.compactSlots(slots, maxSlots)
  table.sort(compact)
  return table.concat(compact, "|")
end

return Loadout
