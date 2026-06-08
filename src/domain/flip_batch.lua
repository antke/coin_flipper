local Loadout = require("src.domain.loadout")
local Utils = require("src.core.utils")

local FlipBatch = {}

function FlipBatch.new(batchId, call, flipSlots, resolutionEntries, maxFlipSlots)
  local resolutionCoinIds = {}
  local maxSlotIndex = 0

  for _, entry in ipairs(resolutionEntries or {}) do
    table.insert(resolutionCoinIds, entry.coinId)
  end

  for slotIndex in pairs(flipSlots or {}) do
    if type(slotIndex) == "number" and slotIndex > maxSlotIndex then
      maxSlotIndex = slotIndex
    end
  end

  local slotCount = math.max(1, maxFlipSlots or 0, maxSlotIndex)
  local normalizedFlipSlots = Loadout.cloneSlots(flipSlots, slotCount)

  return {
    batchId = batchId,
    call = call,
    flipSlots = normalizedFlipSlots,
    equippedCoinSlots = normalizedFlipSlots,
    resolutionCoinIds = resolutionCoinIds,
    resolutionEntries = Utils.clone(resolutionEntries or {}),
    resolvedCoinResults = {},
    actions = {},
    trace = {},
    scoreBreakdown = nil,
  }
end

return FlipBatch
