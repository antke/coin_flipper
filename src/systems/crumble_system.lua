local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local CrumbleSystem = {}

local function ensureState(runState)
  runState.crumblingTrickUses = runState.crumblingTrickUses or {}
  return runState.crumblingTrickUses
end

local function getOwnedList(runState)
  runState.ownedTrickIds = runState.ownedTrickIds or runState.ownedUpgradeIds or {}
  runState.ownedUpgradeIds = runState.ownedTrickIds
  return runState.ownedTrickIds
end

local function removeOwnedTrick(runState, trickId)
  local owned = getOwnedList(runState)

  for index = #owned, 1, -1 do
    if owned[index] == trickId then
      table.remove(owned, index)
    end
  end
end

function CrumbleSystem.getMaxUses(definitionOrId)
  local definition = type(definitionOrId) == "string" and Upgrades.getById(definitionOrId) or definitionOrId
  local uses = definition and definition.crumble and definition.crumble.uses or nil

  if type(uses) == "number" then
    return math.max(0, math.floor(uses))
  end

  return nil
end

function CrumbleSystem.getRemainingUses(runState, trickId)
  local definition = Upgrades.getById(trickId)
  local maxUses = CrumbleSystem.getMaxUses(definition)

  if not maxUses then
    return nil
  end

  local state = ensureState(runState)
  local remaining = state[trickId]

  if remaining == nil then
    return maxUses
  end

  return math.max(0, math.floor(tonumber(remaining) or 0))
end

function CrumbleSystem.findOwnedEffectSource(runState, effectName)
  local best = nil

  for _, trickId in ipairs(getOwnedList(runState)) do
    local definition = Upgrades.getById(trickId)

    if definition
      and definition.familyTriggerStatus ~= "removed"
      and definition.familyTriggerStatus ~= "held"
      and definition.extortion
      and definition.extortion.effect == effectName
      and CrumbleSystem.getRemainingUses(runState, trickId) ~= nil
      and CrumbleSystem.getRemainingUses(runState, trickId) > 0 then
      local tier = Upgrades.getTier(definition)

      if not best or tier > best.tier then
        best = {
          trickId = trickId,
          definition = definition,
          tier = tier,
          remainingUses = CrumbleSystem.getRemainingUses(runState, trickId),
        }
      end
    end
  end

  return best
end

function CrumbleSystem.consumeUse(runState, trickId, reason)
  local definition = Upgrades.getById(trickId)
  local maxUses = CrumbleSystem.getMaxUses(definition)

  if not maxUses then
    return nil, "not_crumbling"
  end

  if not Utils.contains(getOwnedList(runState), trickId) then
    return nil, "trick_not_owned"
  end

  local state = ensureState(runState)
  local usesBefore = CrumbleSystem.getRemainingUses(runState, trickId)
  local usesAfter = math.max(0, usesBefore - 1)
  local crumbled = usesAfter <= 0

  if crumbled then
    state[trickId] = nil
    removeOwnedTrick(runState, trickId)
  else
    state[trickId] = usesAfter
  end

  return {
    trickId = trickId,
    name = definition.name,
    reason = reason,
    usesBefore = usesBefore,
    usesAfter = usesAfter,
    crumbled = crumbled,
  }
end

function CrumbleSystem.clearState(runState, trickId)
  if type(runState) ~= "table" then
    return
  end

  local state = ensureState(runState)
  state[trickId] = nil
end

return CrumbleSystem
