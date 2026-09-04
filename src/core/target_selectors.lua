local CoinTraits = require("src.core.coin_traits")

local TargetSelectors = {}

local function coinHasFamily(slot, family)
  return CoinTraits.hasFamily(slot, family)
end

local function coinHasRealFamily(slot, family)
  return CoinTraits.hasRealFamily(slot, family)
end

local function coinHasArchetype(slot, archetype)
  return CoinTraits.hasArchetype(slot, archetype)
end

local function coinHasRealArchetype(slot, archetype)
  return CoinTraits.hasRealArchetype(slot, archetype)
end

local function coinBaseScore(slot)
  return CoinTraits.baseScore(slot)
end

local function candidateResolutionIndex(candidate)
  return candidate.slot and candidate.slot.resolutionIndex
end

local function contextHasResolutionIndex(context, resolutionIndex)
  if resolutionIndex == nil then
    return false
  end

  for _, coinState in ipairs(context and context.perCoin or {}) do
    if coinState.resolutionIndex == resolutionIndex then
      return true
    end
  end

  return false
end

local function selectedInstanceIds(purse)
  local selected = {}

  for _, slot in ipairs(purse and purse.selectedSlots or {}) do
    if slot and slot.instanceId then
      selected[slot.instanceId] = true
    end
  end

  return selected
end

local function buildDealtHandCandidates(stageState)
  local purse = stageState and stageState.purse or nil
  local selected = selectedInstanceIds(purse)
  local candidates = {}

  for slotPosition, slot in ipairs(purse and purse.dealtHandSlots or {}) do
    if slot and slot.instanceId then
      table.insert(candidates, {
        slot = slot,
        slotPosition = slotPosition,
        selected = selected[slot.instanceId] == true or slot.selectedSlotIndex ~= nil,
      })
    end
  end

  return candidates
end

local function buildSelectedCoinCandidates(context)
  local candidates = {}

  for index, coinState in ipairs(context and context.perCoin or {}) do
    if coinState and (coinState.instanceId or coinState.coinId) and coinState.selectedSlotIndex ~= nil then
      table.insert(candidates, {
        slot = coinState,
        slotPosition = coinState.selectedSlotIndex or coinState.slotIndex or coinState.resolutionIndex or index,
        selected = true,
      })
    end
  end

  return candidates
end

local function buildResolutionPacketCandidates(context)
  local candidates = {}

  for index, packet in ipairs(context and context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
    if packet and packet.packetId then
      table.insert(candidates, {
        slot = packet,
        slotPosition = packet.resolutionIndex or packet.selectedSlotIndex or index,
        selected = packet.selectedSlotIndex ~= nil,
      })
    end
  end

  return candidates
end

local function matchesFilter(candidate, filter, context)
  if filter.op == "slot_index" then
    return candidate.slotPosition == filter.value
  end

  if filter.op == "family" then
    return coinHasFamily(candidate.slot, filter.value)
  end

  if filter.op == "real_family" then
    return coinHasRealFamily(candidate.slot, filter.value)
  end

  if filter.op == "archetype" then
    return coinHasArchetype(candidate.slot, filter.value)
  end

  if filter.op == "real_archetype" then
    return coinHasRealArchetype(candidate.slot, filter.value)
  end

  if filter.op == "not_selected" then
    return candidate.selected ~= true
  end

  if filter.op == "not_smuggled" then
    return candidate.slot.smuggled ~= true
  end

  if filter.op == "material_rank_below_current" then
    local currentRank = CoinTraits.materialRank(context and context.currentCoin or nil, true)
    return currentRank > 0 and CoinTraits.materialRank(candidate.slot, true) < currentRank
  end

  if filter.op == "not_foretold" then
    return candidate.slot.foretold ~= true
  end

  if filter.op == "failed_call" then
    return context and candidate.slot.result ~= nil and candidate.slot.result ~= context.call
  end

  if filter.op == "matched_call" then
    return context and candidate.slot.result ~= nil and candidate.slot.result == context.call
  end

  if filter.op == "not_current_coin" then
    return not context or not context.currentCoin or candidate.slot.instanceId ~= context.currentCoin.instanceId
  end

  if filter.op == "not_context_instance" then
    return not context or not context.selectorExcludedInstanceId or candidate.slot.instanceId ~= context.selectorExcludedInstanceId
  end

  if filter.op == "neighbor_of_current" then
    local sourceIndex = context and context.currentCoin and context.currentCoin.resolutionIndex or nil
    local resolutionIndex = candidateResolutionIndex(candidate)
    return sourceIndex ~= nil and resolutionIndex ~= nil and math.abs(resolutionIndex - sourceIndex) == 1
  end

  if filter.op == "has_neighbor" then
    local resolutionIndex = candidateResolutionIndex(candidate)
    if resolutionIndex == nil then
      return false
    end

    return contextHasResolutionIndex(context, resolutionIndex - 1) or contextHasResolutionIndex(context, resolutionIndex + 1)
  end

  if filter.op == "has_left_neighbor" then
    local resolutionIndex = candidateResolutionIndex(candidate)
    if resolutionIndex == nil then
      return false
    end

    return contextHasResolutionIndex(context, resolutionIndex - 1)
  end

  if filter.op == "has_both_neighbors" then
    local resolutionIndex = candidateResolutionIndex(candidate)
    if resolutionIndex == nil then
      return false
    end

    return contextHasResolutionIndex(context, resolutionIndex - 1) and contextHasResolutionIndex(context, resolutionIndex + 1)
  end

  if filter.op == "not_used_resolution_index" then
    local used = context and context.usedResolutionIndices or nil
    local resolutionIndex = candidateResolutionIndex(candidate)
    return resolutionIndex ~= nil and not (used and used[resolutionIndex])
  end

  if filter.op == "selected" then
    return candidate.selected == true
  end

  if filter.op == "positive_score" then
    local score = tonumber(candidate.slot.finalScoreContribution) or tonumber(candidate.slot.seed and candidate.slot.seed.finalScoreContribution) or 0
    return score > 0
  end

  if filter.op == "not_prestige_replay" then
    return candidate.slot.prestigeReplay ~= true
  end

  return true
end

local function applyFilters(candidates, filters, context)
  local filtered = candidates

  for _, filter in ipairs(filters or {}) do
    local nextCandidates = {}

    for _, candidate in ipairs(filtered) do
      if matchesFilter(candidate, filter, context) then
        table.insert(nextCandidates, candidate)
      end
    end

    filtered = nextCandidates
  end

  return filtered
end

local function matchesPreference(candidate, preference)
  if preference.op == "family" then
    return coinHasFamily(candidate.slot, preference.value)
  end

  if preference.op == "archetype" then
    return coinHasArchetype(candidate.slot, preference.value)
  end

  return false
end

local function applyPreferences(candidates, preferences)
  for _, preference in ipairs(preferences or {}) do
    local preferred = {}

    for _, candidate in ipairs(candidates) do
      if matchesPreference(candidate, preference) then
        table.insert(preferred, candidate)
      end
    end

    if #preferred > 0 then
      return preferred
    end
  end

  return candidates
end

local function applyMaterialBand(candidates, materialBand)
  if materialBand ~= "highest" and materialBand ~= "lowest" then
    return candidates
  end

  local selectedRank = nil
  for _, candidate in ipairs(candidates or {}) do
    local rank = CoinTraits.materialRank(candidate.slot, true)
    if selectedRank == nil
      or (materialBand == "highest" and rank > selectedRank)
      or (materialBand == "lowest" and rank < selectedRank) then
      selectedRank = rank
    end
  end

  local band = {}
  for _, candidate in ipairs(candidates or {}) do
    if CoinTraits.materialRank(candidate.slot, true) == selectedRank then
      table.insert(band, candidate)
    end
  end

  return band
end

local function sortCandidates(candidates, selector)
  if selector.orderBy == nil or selector.orderBy == "slot_position" then
    table.sort(candidates, function(left, right)
      return left.slotPosition < right.slotPosition
    end)
  elseif selector.orderBy == "base_score" then
    table.sort(candidates, function(left, right)
      local leftScore = coinBaseScore(left.slot)
      local rightScore = coinBaseScore(right.slot)

      if leftScore == rightScore then
        return left.slotPosition < right.slotPosition
      end

      return leftScore < rightScore
    end)
  elseif selector.orderBy == "base_score_desc" then
    table.sort(candidates, function(left, right)
      local leftScore = coinBaseScore(left.slot)
      local rightScore = coinBaseScore(right.slot)

      if leftScore == rightScore then
        return left.slotPosition < right.slotPosition
      end

      return leftScore > rightScore
    end)
  elseif selector.orderBy == "material_rank_desc" then
    table.sort(candidates, function(left, right)
      local leftRank = CoinTraits.materialRank(left.slot, true)
      local rightRank = CoinTraits.materialRank(right.slot, true)

      if leftRank == rightRank then
        return left.slotPosition < right.slotPosition
      end

      return leftRank > rightRank
    end)
  end
end

local function pickCandidate(candidates, selector, context)
  if #candidates == 0 then
    return nil
  end

  local pick = selector.pick

  if selector.orderBy == "random" then
    if not context or not context.rng or type(context.rng.choose) ~= "function" then
      return nil, "target selector requires rng for random order"
    end

    if pick ~= nil and pick.value ~= 1 then
      return nil, "random target selector only supports pick position 1"
    end

    return context.rng:choose(candidates)
  end

  if pick == nil then
    return candidates[1]
  end

  if pick.op == "slot_at_position" then
    return candidates[pick.value]
  end

  return candidates[1]
end

local function buildCandidates(stageState, selector, context)
  if type(selector) ~= "table" then
    return nil, "target_selector_required"
  end

  local candidates = {}

  if selector.zone == "dealt_hand" then
    candidates = buildDealtHandCandidates(stageState)
  elseif selector.zone == "selected_coins" then
    candidates = buildSelectedCoinCandidates(context)
  elseif selector.zone == "resolution_packets" then
    candidates = buildResolutionPacketCandidates(context)
  else
    return nil, "unsupported_target_zone"
  end

  candidates = applyFilters(candidates, selector.filters, context)
  candidates = applyPreferences(candidates, selector.prefer)
  candidates = applyMaterialBand(candidates, selector.materialBand)
  sortCandidates(candidates, selector)

  return candidates
end

function TargetSelectors.resolveSlots(runState, stageState, selector, context)
  local candidates, candidateError = buildCandidates(stageState, selector, context)
  if not candidates then
    return {}, candidateError
  end

  if selector.pick and selector.pick.op == "all" then
    local slots = {}
    for _, candidate in ipairs(candidates) do
      table.insert(slots, candidate.slot)
    end
    return slots, #slots > 0 and nil or "no_target_candidate"
  end

  local candidate, pickError = pickCandidate(candidates, selector, context)
  if candidate then
    return { candidate.slot }, nil
  end

  return {}, pickError or "no_target_candidate"
end

function TargetSelectors.resolveSlot(runState, stageState, selector, context)
  local slots, slotError = TargetSelectors.resolveSlots(runState, stageState, selector, context)
  return slots[1], slotError
end

function TargetSelectors.resolvePacket(context, selector)
  return TargetSelectors.resolveSlot(nil, nil, selector, context)
end

local function isPositiveInteger(value)
  return type(value) == "number" and math.floor(value) == value and value >= 1
end

function TargetSelectors.validateSlotSelector(selector, allowedZones)
  if type(selector) ~= "table" then
    return false, "target selector must be a table"
  end

  allowedZones = allowedZones or { dealt_hand = true }

  if allowedZones[selector.zone] ~= true then
    return false, "target selector zone is not allowed here"
  end

  if selector.materialBand ~= nil
    and selector.materialBand ~= "highest"
    and selector.materialBand ~= "lowest" then
    return false, "target selector materialBand must be highest|lowest when present"
  end

  for _, filter in ipairs(selector.filters or {}) do
    if filter.op ~= "slot_index"
      and filter.op ~= "family"
      and filter.op ~= "real_family"
      and filter.op ~= "archetype"
      and filter.op ~= "real_archetype"
      and filter.op ~= "not_selected"
      and filter.op ~= "not_smuggled"
      and filter.op ~= "material_rank_below_current"
      and filter.op ~= "not_foretold"
      and filter.op ~= "failed_call"
      and filter.op ~= "matched_call"
      and filter.op ~= "not_current_coin"
      and filter.op ~= "not_context_instance"
      and filter.op ~= "neighbor_of_current"
      and filter.op ~= "has_neighbor"
      and filter.op ~= "has_left_neighbor"
      and filter.op ~= "has_both_neighbors"
      and filter.op ~= "not_used_resolution_index"
      and filter.op ~= "selected"
      and filter.op ~= "positive_score"
      and filter.op ~= "not_prestige_replay" then
      return false, "target selector filter is not supported"
    end

    if filter.op == "slot_index" and not isPositiveInteger(filter.value) then
      return false, "target selector slot_index filter requires positive integer value"
    end

    if filter.op == "family" and (type(filter.value) ~= "string" or filter.value == "") then
      return false, "target selector family filter requires string value"
    end

    if filter.op == "real_family" and (type(filter.value) ~= "string" or filter.value == "") then
      return false, "target selector real_family filter requires string value"
    end

    if filter.op == "archetype" and (type(filter.value) ~= "string" or filter.value == "") then
      return false, "target selector archetype filter requires string value"
    end

    if filter.op == "real_archetype" and (type(filter.value) ~= "string" or filter.value == "") then
      return false, "target selector real_archetype filter requires string value"
    end
  end

  for _, preference in ipairs(selector.prefer or {}) do
    if preference.op ~= "family" and preference.op ~= "archetype" then
      return false, "target selector preference must be family|archetype"
    end

    if type(preference.value) ~= "string" or preference.value == "" then
      return false, "target selector preference requires string value"
    end
  end

  if selector.orderBy ~= nil and selector.orderBy ~= "slot_position" and selector.orderBy ~= "random" and selector.orderBy ~= "base_score" and selector.orderBy ~= "base_score_desc" and selector.orderBy ~= "material_rank_desc" then
    return false, "target selector orderBy must be slot_position|random|base_score|base_score_desc|material_rank_desc"
  end

  if selector.pick ~= nil then
    if selector.pick.op ~= "slot_at_position" and selector.pick.op ~= "all" then
      return false, "target selector pick must be slot_at_position|all"
    end

    if selector.pick.op == "slot_at_position" and not isPositiveInteger(selector.pick.value) then
      return false, "target selector pick value must be a positive integer"
    end

    if selector.orderBy == "random" and (selector.pick.op ~= "slot_at_position" or selector.pick.value ~= 1) then
      return false, "target selector random order only supports pick position 1"
    end
  end

  return true
end

return TargetSelectors
