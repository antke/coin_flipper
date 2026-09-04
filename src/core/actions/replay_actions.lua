local CoinTraits = require("src.core.coin_traits")
local ScoreActions = require("src.core.actions.score_actions")
local ScoreBreakdown = require("src.domain.score_breakdown")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local ReplayActions = {}

local REPLAY_OPS = {
  copy_outcome = true,
  replay_resolution_packet = true,
}

local function ensureScoreBreakdown(context)
  context.scoreBreakdown = context.scoreBreakdown or ScoreBreakdown.new()

  local scoreScalings = context.scoreBreakdown.scoreScalings or context.scoreBreakdown.multipliers or {}
  context.scoreBreakdown.scoreScalings = scoreScalings
  context.scoreBreakdown.multipliers = scoreScalings
end

local function requireStageState(stageState, op)
  if not stageState then
    error(string.format("%s requires an active stageState", op))
  end
end

local function recordWarning(options, context, message)
  if options and options.recordWarning then
    options.recordWarning(context, message)
  end
end

local function claimOnce(options, context, action, defaultKey, warning)
  if options and options.claimOnce then
    local key = defaultKey

    if options.getOnceKey then
      key = options.getOnceKey(action, defaultKey)
    elseif type(action.onceKey) == "string" and action.onceKey ~= "" then
      key = action.onceKey
    end

    return options.claimOnce(context, key, warning)
  end

  return true
end

local function packetHasBentCoin(packet)
  return CoinTraits.hasArchetype(packet, "bent") or CoinTraits.hasTag(packet, "bent") or CoinTraits.hasTag(packet, "prestige")
end

local function getPacketScore(packet)
  return tonumber(packet and packet.finalScoreContribution) or tonumber(packet and packet.seed and packet.seed.finalScoreContribution) or 0
end

local function isEligibleOutcomePacket(packet)
  return packet and packet.packetId and getPacketScore(packet) > 0
    and packet.prestigeReplay ~= true and packet.rootOutcome ~= false
end

local function buildEligibleOutcomePackets(context)
  local packets = {}

  for index, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
    if isEligibleOutcomePacket(packet) then
      table.insert(packets, {
        packet = packet,
        index = index,
      })
    end
  end

  return packets
end

local function packetMatchesPreference(packet, action)
  if type(action.preferFamily) == "string" and action.preferFamily ~= "" and CoinTraits.hasFamily(packet, action.preferFamily) then
    return true
  end

  if type(action.preferArchetype) == "string" and action.preferArchetype ~= "" and CoinTraits.hasArchetype(packet, action.preferArchetype) then
    return true
  end

  return false
end

local function removeChosenPacket(candidates, chosen)
  for index, candidate in ipairs(candidates) do
    if candidate == chosen then
      table.remove(candidates, index)
      return
    end
  end
end

local function chooseRandomOutcomePackets(context, action, count)
  local remaining = buildEligibleOutcomePackets(context)
  local chosen = {}

  for _ = 1, count do
    if #remaining == 0 then
      break
    end

    local preferred = {}

    for _, candidate in ipairs(remaining) do
      if packetMatchesPreference(candidate.packet, action) then
        table.insert(preferred, candidate)
      end
    end

    local pool = #preferred > 0 and preferred or remaining
    local candidate

    if context.rng and context.rng.choose then
      candidate = context.rng:choose(pool)
    else
      candidate = pool[1]
    end

    table.insert(chosen, candidate)
    removeChosenPacket(remaining, candidate)
  end

  return chosen
end

local function chooseHighestValueOutcomePackets(context, count)
  local candidates = buildEligibleOutcomePackets(context)

  table.sort(candidates, function(left, right)
    local leftScore = getPacketScore(left.packet)
    local rightScore = getPacketScore(right.packet)

    if leftScore == rightScore then
      return (left.packet.resolutionIndex or left.index) < (right.packet.resolutionIndex or right.index)
    end

    return leftScore > rightScore
  end)

  local chosen = {}

  for index = 1, math.min(count, #candidates) do
    table.insert(chosen, candidates[index])
  end

  return chosen
end

local function chooseAllOutcomePackets(context)
  local candidates = buildEligibleOutcomePackets(context)

  table.sort(candidates, function(left, right)
    return (left.packet.resolutionIndex or left.index) < (right.packet.resolutionIndex or right.index)
  end)

  return candidates
end

local function chooseSingleTargetPacket(context, action)
  if type(action.target) == "table" then
    local packet, chosenIndex = TargetSelectors.resolvePacket(context, action.target)

    if packet then
      return {
        {
          packet = packet,
          index = chosenIndex,
        },
      }
    end

    return {}
  end

  local eligible = {}
  local bent = {}

  for _, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
    if isEligibleOutcomePacket(packet) then
      table.insert(eligible, packet)

      if packetHasBentCoin(packet) then
        table.insert(bent, packet)
      end
    end
  end

  local pool = #bent > 0 and bent or eligible

  if #pool == 0 then
    return nil, nil
  end

  if context.rng and context.rng.choose then
    local packet, chosenIndex = context.rng:choose(pool)
    return {
      {
        packet = packet,
        index = chosenIndex,
      },
    }
  end

  return {
    {
      packet = pool[1],
      index = 1,
    },
  }
end

local function chooseReplayPackets(context, action)
  local selectionMode = action.selectionMode or action.selection or nil
  local count = tonumber(action.count) or 1

  if selectionMode == "activation_source" then
    local activation = context.currentActivation
    for index, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
      if isEligibleOutcomePacket(packet)
        and activation
        and packet.instanceId == activation.sourceInstanceId then
        return { { packet = packet, index = index } }
      end
    end
    return {}
  end

  if selectionMode == "random_other" then
    local activation = context.currentActivation
    local candidates = {}
    for index, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
      if isEligibleOutcomePacket(packet)
        and (not activation or packet.instanceId ~= activation.sourceInstanceId) then
        table.insert(candidates, { packet = packet, index = index })
      end
    end
    if #candidates == 0 then
      return chooseReplayPackets(context, {
        selectionMode = "activation_source",
        count = 1,
      })
    end
    local chosen = {}
    for _ = 1, math.min(count, #candidates) do
      local candidate = context.rng and context.rng.choose and context.rng:choose(candidates) or candidates[1]
      table.insert(chosen, candidate)
      removeChosenPacket(candidates, candidate)
    end
    return chosen
  end

  if selectionMode == "directional" then
    local activation = context.currentActivation
    local lockedForgerySourceInstanceId = action.op == "copy_outcome" and context.currentCoin
      and context.currentCoin.forgerySourceInstanceId or nil
    if lockedForgerySourceInstanceId then
      for index, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
        if isEligibleOutcomePacket(packet) and packet.instanceId == lockedForgerySourceInstanceId
          and not (action.requireGenuineFamilySource == true and CoinTraits.hasRealFamily(packet, "forgery")) then
          action.sourceCoinId = context.currentCoin.forgerySourceCoinId
          action.sourceInstanceId = lockedForgerySourceInstanceId
          action.sourceResolutionIndex = context.currentCoin.forgerySourceResolutionIndex
          action.forgeryDirection = context.currentCoin.forgeryDirection or "left"
          return { { packet = packet, index = index } }
        end
      end
      return {}
    end
    local direction = action.direction == "left" and -1 or 1
    local targets = {}
    local nextIndex = activation and activation.sourceResolutionIndex and (activation.sourceResolutionIndex + direction) or nil
    while nextIndex and #targets < count do
      local chance = #targets == 0 and (tonumber(action.chance) or 1)
        or (tonumber(action.continuationChance) or tonumber(action.chance) or 1)
      local roll = context.rng and context.rng.nextFloat and context.rng:nextFloat() or 1
      if roll > chance then break end
      local found = nil
      for index, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
        if isEligibleOutcomePacket(packet) and packet.resolutionIndex == nextIndex
          and not (action.requireGenuineFamilySource == true and CoinTraits.hasRealFamily(packet, "forgery")) then
          found = { packet = packet, index = index }
          break
        end
      end
      if found then table.insert(targets, found) end
      nextIndex = nextIndex + direction
      if math.abs(nextIndex - activation.sourceResolutionIndex) > #(context.perCoin or {}) then break end
    end
    return targets
  end

  if selectionMode == "random" then
    return chooseRandomOutcomePackets(context, action, count)
  end

  if selectionMode == "highest_value" then
    return chooseHighestValueOutcomePackets(context, count)
  end

  if selectionMode == "all" then
    return chooseAllOutcomePackets(context)
  end

  return chooseSingleTargetPacket(context, action)
end

local function applyReplayResolutionPacket(runState, stageState, context, action, options)
  requireStageState(stageState, action.op)
  ensureScoreBreakdown(context)

  local packets = chooseReplayPackets(context, action)

  if #packets == 0 then
    recordWarning(options, context, "replay_resolution_packet had no eligible completed coin Outcome.")
    return
  end

  local forgedOutcomeCopy = action.op == "copy_outcome"
  if not claimOnce(
    options,
    context,
    action,
    forgedOutcomeCopy and "copy_outcome" or "replay_resolution_packet",
    forgedOutcomeCopy
      and "copy_outcome ignored because this Forgery activation already copied an Outcome."
      or "replay_resolution_packet ignored because a Prestige replay already resolved this flip."
  ) then
    return
  end

  local scale = tonumber(action.scale) or 0.2
  local sourceId = action._trace and action._trace.sourceId or nil
  local originSlotIndex = context.currentActivation and context.currentActivation.sourceSlotIndex

  action.packetIds = {}
  action.packetCoinIds = {}
  action.packetInstanceIds = {}
  action.packetSlotIndices = {}
  action.packetSelectedSlotIndices = {}
  action.packetResolutionIndices = {}
  action.packetFinalScoreContributions = {}
  action.chosenPacketIndices = {}
  action.prestigeScales = {}
  action.rawReplayedScores = {}
  action.replayedScores = {}
  action.replayedPacketCount = #packets
  action.originSlotIndex = originSlotIndex
  action.prestigeReplay = not forgedOutcomeCopy
  action.prestigeReplayBy = not forgedOutcomeCopy and sourceId or nil
  action.forgedOutcomeCopy = forgedOutcomeCopy
  action.forgedOutcomeCopyBy = forgedOutcomeCopy and sourceId or nil
  action.replayMode = forgedOutcomeCopy and "forged_outcome_copy" or "packet_replay_only"
  action.replayScope = forgedOutcomeCopy and "no_recursive_forgery" or "no_recursive_prestige"

  context.trace.prestigeReplays = context.trace.prestigeReplays or {}
  context.scoreBreakdown.prestigeReplays = context.scoreBreakdown.prestigeReplays or {}
  context.trace.forgedOutcomeCopies = context.trace.forgedOutcomeCopies or {}
  context.scoreBreakdown.forgedOutcomeCopies = context.scoreBreakdown.forgedOutcomeCopies or {}

  local totalReplayedScore = 0

  for replayIndex, choice in ipairs(packets) do
    local packet = choice.packet
    local appliedScale = scale * CoinTraits.familyMultiplier(packet, action.specializedFamily)
    local originalScore = getPacketScore(packet)
    local rawReplayedScore = originalScore * appliedScale
    local replayedScore = originalScore > 0 and math.max(1, math.floor(rawReplayedScore + 0.00001)) or 0

    totalReplayedScore = totalReplayedScore + replayedScore

    table.insert(action.packetIds, packet.packetId)
    table.insert(action.packetCoinIds, packet.coinId)
    table.insert(action.packetInstanceIds, packet.instanceId)
    table.insert(action.packetSlotIndices, packet.slotIndex)
    table.insert(action.packetSelectedSlotIndices, packet.selectedSlotIndex)
    table.insert(action.packetResolutionIndices, packet.resolutionIndex)
    table.insert(action.packetFinalScoreContributions, originalScore)
    table.insert(action.chosenPacketIndices, choice.index)
    table.insert(action.prestigeScales, appliedScale)
    table.insert(action.rawReplayedScores, rawReplayedScore)
    table.insert(action.replayedScores, replayedScore)

    if replayIndex == 1 then
      action.packetId = packet.packetId
      action.packetCoinId = packet.coinId
      action.packetInstanceId = packet.instanceId
      action.packetSlotIndex = packet.slotIndex
      action.packetSelectedSlotIndex = packet.selectedSlotIndex
      action.packetResolutionIndex = packet.resolutionIndex
      action.packetFinalScoreContribution = originalScore
      action.prestigeScale = appliedScale
      action.rawReplayedScore = rawReplayedScore
      action.chosenPacketIndex = choice.index
    end

    local replay = {
      op = action.op,
      mode = forgedOutcomeCopy and "forged_outcome_copy" or "packet_replay_only",
      scope = forgedOutcomeCopy and "no_recursive_forgery" or "no_recursive_prestige",
      sourceId = sourceId,
      replayIndex = replayIndex,
      packetId = packet.packetId,
      packetCoinId = packet.coinId,
      packetInstanceId = packet.instanceId,
      packetSlotIndex = packet.slotIndex,
      packetSelectedSlotIndex = packet.selectedSlotIndex,
      packetResolutionIndex = packet.resolutionIndex,
      packetFinalScoreContribution = originalScore,
      scale = appliedScale,
      rawReplayedScore = rawReplayedScore,
      replayedScore = replayedScore,
      originSlotIndex = originSlotIndex,
      prestigeReplay = not forgedOutcomeCopy,
      forgedOutcomeCopy = forgedOutcomeCopy,
    }

    if forgedOutcomeCopy then
      table.insert(context.trace.forgedOutcomeCopies, replay)
      table.insert(context.scoreBreakdown.forgedOutcomeCopies, Utils.clone(replay))
    else
      table.insert(context.trace.prestigeReplays, replay)
      table.insert(context.scoreBreakdown.prestigeReplays, Utils.clone(replay))
    end

    if replayedScore > 0 then
      ScoreActions.applyStageScore(runState, stageState, context, {
        op = action.op,
        amount = replayedScore,
        category = action.category,
        label = action.label,
        _trace = action._trace,
      }, {
        prestigeReplay = not forgedOutcomeCopy,
        forgedOutcomeCopy = forgedOutcomeCopy,
        packetId = packet.packetId,
      })
    end
  end

  action.rawReplayedScore = action.rawReplayedScores[1]
  action.replayedScore = totalReplayedScore
  action.amount = totalReplayedScore
end

function ReplayActions.isReplayOp(op)
  return REPLAY_OPS[op] == true
end

function ReplayActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.target ~= nil and type(action.target) ~= "table" then
    return false, action.op .. " target must be selector when present"
  end

  if type(action.target) == "table" then
    local validSelector, selectorError = selectors.validateSlotSelector(action.target, { resolution_packets = true })
    if not validSelector then
      return false, action.op .. " " .. selectorError
    end
  end

  if action.scale ~= nil and (type(action.scale) ~= "number" or action.scale < 0 or action.scale > 1) then
    return false, action.op .. " scale must be between 0 and 1 when present"
  end

  if action.count ~= nil and (type(action.count) ~= "number" or math.floor(action.count) ~= action.count or action.count < 1) then
    return false, "replay_resolution_packet count must be a positive integer when present"
  end
  if action.chance ~= nil and (type(action.chance) ~= "number" or action.chance < 0 or action.chance > 1) then
    return false, "replay_resolution_packet chance must be between 0 and 1"
  end
  if action.continuationChance ~= nil and (type(action.continuationChance) ~= "number"
    or action.continuationChance < 0 or action.continuationChance > 1) then
    return false, "replay_resolution_packet continuationChance must be between 0 and 1"
  end

  if action.selectionMode ~= nil and action.selectionMode ~= "random" and action.selectionMode ~= "highest_value"
    and action.selectionMode ~= "all" and action.selectionMode ~= "activation_source"
    and action.selectionMode ~= "random_other" and action.selectionMode ~= "directional" then
    return false, "replay_resolution_packet selectionMode is invalid"
  end

  if action.selection ~= nil and action.selection ~= "random" and action.selection ~= "highest_value" and action.selection ~= "all" then
    return false, "replay_resolution_packet selection must be random, highest_value, or all when present"
  end

  if action.preferFamily ~= nil and type(action.preferFamily) ~= "string" then
    return false, "replay_resolution_packet preferFamily must be string when present"
  end

  if action.preferArchetype ~= nil and type(action.preferArchetype) ~= "string" then
    return false, "replay_resolution_packet preferArchetype must be string when present"
  end

  if action.op == "copy_outcome" then
    if action.selectionMode ~= "directional" or action.direction ~= "left" or (action.count ~= nil and action.count ~= 1) then
      return false, "copy_outcome must select exactly one directional left Outcome"
    end
    if action.requireGenuineFamilySource ~= nil and type(action.requireGenuineFamilySource) ~= "boolean" then
      return false, "copy_outcome requireGenuineFamilySource must be boolean when present"
    end
  end

  return true
end

function ReplayActions.apply(runState, stageState, context, action, options)
  if action.op == "replay_resolution_packet" or action.op == "copy_outcome" then
    applyReplayResolutionPacket(runState, stageState, context, action, options)
    return true
  end

  return false
end

return ReplayActions
