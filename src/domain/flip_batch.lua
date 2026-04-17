local Loadout = require("src.domain.loadout")
local Utils = require("src.core.utils")

local FlipBatch = {}

function FlipBatch.new(batchId, call, equippedCoinSlots, resolutionEntries, maxActiveCoinSlots)
  local resolutionCoinIds = {}
  local maxSlotIndex = 0

  for _, entry in ipairs(resolutionEntries or {}) do
    table.insert(resolutionCoinIds, entry.coinId)
  end

  for slotIndex in pairs(equippedCoinSlots or {}) do
    if type(slotIndex) == "number" and slotIndex > maxSlotIndex then
      maxSlotIndex = slotIndex
    end
  end

  local slotCount = math.max(1, maxActiveCoinSlots or 0, maxSlotIndex)

  return {
    batchId = batchId,
    call = call,
    equippedCoinSlots = Loadout.cloneSlots(equippedCoinSlots, slotCount),
    resolutionCoinIds = resolutionCoinIds,
    resolutionEntries = Utils.clone(resolutionEntries or {}),
    resolvedCoinResults = {},
    actions = {},
    trace = {},
    scoreBreakdown = nil,
  }
end

return FlipBatch
