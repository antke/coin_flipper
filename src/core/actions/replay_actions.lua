local CoinTraits = require("src.core.coin_traits")
local ScoreActions = require("src.core.actions.score_actions")
local ScoreBreakdown = require("src.domain.score_breakdown")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local ReplayActions = {}

local REPLAY_OPS = {
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

local function chooseEncorePacket(context, action)
  if type(action.target) == "table" then
    return TargetSelectors.resolvePacket(context, action.target)
  end

  local eligible = {}
  local bent = {}

  for _, packet in ipairs(context.scoreBreakdown and context.scoreBreakdown.resolutionPackets or {}) do
    local isSelected = packet.selectedSlotIndex ~= nil
    local hasOutput = getPacketScore(packet) > 0
    local isReplay = packet.prestigeReplay == true

    if isSelected and hasOutput and not isReplay then
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
    return context.rng:choose(pool)
  end

  return pool[1], 1
end

local function applyReplayResolutionPacket(runState, stageState, context, action, options)
  requireStageState(stageState, action.op)
  ensureScoreBreakdown(context)

  local packet, chosenIndex = chooseEncorePacket(context, action)

  if not packet then
    recordWarning(options, context, "replay_resolution_packet had no eligible completed selected packet.")
    return
  end

  if not claimOnce(
    options,
    context,
    action,
    "replay_resolution_packet",
    "replay_resolution_packet ignored because a Prestige replay already resolved this flip."
  ) then
    return
  end

  local scale = tonumber(action.scale) or 0.2
  scale = scale * CoinTraits.familyMultiplier(packet.coinId, action.specializedFamily)
  local originalScore = getPacketScore(packet)
  local rawReplayedScore = originalScore * scale
  local replayedScore = originalScore > 0 and math.max(1, math.floor(rawReplayedScore + 0.00001)) or 0
  local sourceId = action._trace and action._trace.sourceId or nil

  action.packetId = packet.packetId
  action.packetCoinId = packet.coinId
  action.packetInstanceId = packet.instanceId
  action.packetSlotIndex = packet.slotIndex
  action.packetSelectedSlotIndex = packet.selectedSlotIndex
  action.packetResolutionIndex = packet.resolutionIndex
  action.packetFinalScoreContribution = originalScore
  action.prestigeReplay = true
  action.prestigeReplayBy = sourceId
  action.prestigeScale = scale
  action.rawReplayedScore = rawReplayedScore
  action.replayedScore = replayedScore
  action.amount = replayedScore
  action.chosenPacketIndex = chosenIndex
  action.replayMode = "packet_replay_only"
  action.replayScope = "no_recursive_prestige"

  local replay = {
    op = "replay_resolution_packet",
    mode = "packet_replay_only",
    scope = "no_recursive_prestige",
    sourceId = sourceId,
    packetId = packet.packetId,
    packetCoinId = packet.coinId,
    packetInstanceId = packet.instanceId,
    packetSlotIndex = packet.slotIndex,
    packetSelectedSlotIndex = packet.selectedSlotIndex,
    packetResolutionIndex = packet.resolutionIndex,
    packetFinalScoreContribution = originalScore,
    scale = scale,
    rawReplayedScore = rawReplayedScore,
    replayedScore = replayedScore,
    prestigeReplay = true,
  }

  context.trace.prestigeReplays = context.trace.prestigeReplays or {}
  table.insert(context.trace.prestigeReplays, replay)
  context.scoreBreakdown.prestigeReplays = context.scoreBreakdown.prestigeReplays or {}
  table.insert(context.scoreBreakdown.prestigeReplays, Utils.clone(replay))

  if replayedScore > 0 then
    ScoreActions.applyStageScore(runState, stageState, context, action, {
      prestigeReplay = true,
      packetId = packet.packetId,
    })
  end
end

function ReplayActions.isReplayOp(op)
  return REPLAY_OPS[op] == true
end

function ReplayActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.target ~= nil and type(action.target) ~= "table" then
    return false, "replay_resolution_packet target must be selector when present"
  end

  if type(action.target) == "table" then
    local validSelector, selectorError = selectors.validateSlotSelector(action.target, { resolution_packets = true })
    if not validSelector then
      return false, "replay_resolution_packet " .. selectorError
    end
  end

  if action.scale ~= nil and (type(action.scale) ~= "number" or action.scale < 0 or action.scale > 1) then
    return false, "replay_resolution_packet scale must be between 0 and 1 when present"
  end

  return true
end

function ReplayActions.apply(runState, stageState, context, action, options)
  if action.op == "replay_resolution_packet" then
    applyReplayResolutionPacket(runState, stageState, context, action, options)
    return true
  end

  return false
end

return ReplayActions
