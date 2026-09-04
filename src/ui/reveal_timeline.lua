local Coins = require("src.content.coins")

local RevealTimeline = {}

local DEFAULTS = {
  coinMotionDuration = 0.176,
  baseHoldDuration = 0.096,
  effectHoldDuration = 0.128,
  scoreHoldDuration = 0.056,
  linkDuration = 0.208,
  sleightMoveDuration = 0.160,
  threeCupsDuration = 1.48,
}

local ALLOWED_SOURCE_TYPES = {
  trick = true,
  ["run upgrade"] = true,
  ["temporary effect"] = true,
}

local LINK_ACTION_OPS = {
  copy_outcome = true,
  forge_trick_activations = true,
  replay_resolution_packet = true,
  swap_coins = true,
  replace_coin_from_hand = true,
  extract_failed_smuggling_coin = true,
  palm_failed_coin = true,
  monte_rearrange = true,
  trigger_random_neighbor = true,
}

local SPECIAL_ACTION_LABELS = {
  copy_outcome = "OUTCOME COUNTERFEITED",
  forge_trick_activations = "TRICK IMITATED",
  smuggle_coin_from_hand = "COIN SMUGGLED",
  extract_failed_smuggling_coin = "VALUABLE COIN EXTRACTED",
  palm_failed_coin = "COIN PALMED",
  monte_rearrange = "THREE-CARD MONTE",
}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function getEventSpeedFactor(eventIndex)
  return clamp(1 - (math.max(1, eventIndex or 1) - 1) * 0.12, 0.58, 1)
end

local function getResolutionIndex(value)
  local number = tonumber(value)

  if not number or number < 1 or math.floor(number) ~= number then
    return nil
  end

  return number
end

local function sourceKey(sourceType, sourceId, phase)
  return string.format("%s:%s:%s", tostring(sourceType or ""), tostring(sourceId or ""), tostring(phase or ""))
end

local function normalizeLabel(label)
  local text = tostring(label or "")
  return text ~= "" and text or nil
end

local function isAllowedSourceType(sourceType)
  return ALLOWED_SOURCE_TYPES[sourceType] == true
end

local function getCoinLabel(coinId)
  local definition = coinId and Coins.getById(coinId) or nil
  local name = tostring(definition and definition.name or coinId or "Coin")
  return (name:gsub("%s+[Cc]oin$", ""))
end

local function getScoreContribution(scoreEntry)
  return tonumber(scoreEntry and scoreEntry.finalScoreContribution)
    or tonumber(scoreEntry and scoreEntry.scoreBeforeAggregateScaling)
    or tonumber(scoreEntry and scoreEntry.scoreBeforeAggregateMultiplier)
    or tonumber(scoreEntry and scoreEntry.baseScoreContribution)
    or 0
end

local function buildSourceLookup(trace)
  local lookup = {
    labelsBySource = {},
    labelsBySourcePhase = {},
    labelsById = {},
    typesById = {},
  }

  for _, source in ipairs(trace and trace.triggeredSources or {}) do
    if isAllowedSourceType(source.sourceType) then
      local sourceId = source.sourceId
      local label = normalizeLabel(source.sourceName or source.name or sourceId)

      if sourceId ~= nil and label then
        lookup.labelsBySource[sourceKey(source.sourceType, sourceId)] = label
        lookup.labelsBySourcePhase[sourceKey(source.sourceType, sourceId, source.phase)] = label
        lookup.labelsById[tostring(sourceId)] = label
        lookup.typesById[tostring(sourceId)] = source.sourceType
      end
    end
  end

  return lookup
end

local function resolveSource(source, lookup)
  local trace = source and source._trace or {}
  local sourceId = source and (source.sourceId or trace.sourceId) or nil
  local sourceType = source and (source.sourceType or trace.sourceType) or nil
  local phase = source and (source.phase or trace.phase) or nil

  if not sourceType and sourceId ~= nil then
    sourceType = lookup.typesById[tostring(sourceId)]
  end

  if not sourceId or not isAllowedSourceType(sourceType) then
    return nil, nil, nil, nil
  end

  local label = normalizeLabel(source.sourceName or trace.sourceName)
    or lookup.labelsBySourcePhase[sourceKey(sourceType, sourceId, phase)]
    or lookup.labelsBySource[sourceKey(sourceType, sourceId)]
    or lookup.labelsById[tostring(sourceId)]
    or normalizeLabel(sourceId)

  return sourceId, sourceType, phase, label
end

local function addLink(links, seen, sourceResolutionIndex, targetResolutionIndex, source, lookup, op, order)
  local sourceIndex = getResolutionIndex(sourceResolutionIndex)
  local targetIndex = getResolutionIndex(targetResolutionIndex)

  if not sourceIndex or not targetIndex or sourceIndex == targetIndex then
    return false
  end

  local sourceId, sourceType, phase, label = resolveSource(source, lookup)

  if not label then
    return false
  end

  local key = string.format("%d:%d:%s:%s:%s", sourceIndex, targetIndex, tostring(sourceType), tostring(sourceId), tostring(op or ""))

  if seen[key] then
    return false
  end

  seen[key] = true
  table.insert(links, {
    sourceResolutionIndex = sourceIndex,
    targetResolutionIndex = targetIndex,
    label = label,
    sourceId = sourceId,
    sourceType = sourceType,
    phase = phase,
    op = op,
    order = order or 0,
  })

  return true
end

local function collectLinks(batchResult, lookup)
  local trace = batchResult and batchResult.trace or nil
  local links = {}
  local seen = {}
  local order = 0

  for _, action in ipairs(trace and trace.actions or {}) do
    order = order + 1

    if LINK_ACTION_OPS[action.op] and resolveSource(action, lookup) then
      local sourceIndex = action.sourceResolutionIndex or (action._trace and action._trace.resolutionIndex) or action.resolutionIndex

      addLink(links, seen, sourceIndex, action.targetResolutionIndex, action, lookup, action.op, order)
      addLink(links, seen, sourceIndex, action.packetResolutionIndex, action, lookup, action.op, order)
      addLink(links, seen, sourceIndex, action.chainedResolutionIndex, action, lookup, action.op, order)

      if action.op == "swap_coins" then
        addLink(links, seen, action.failedResolutionIndex, action.successResolutionIndex, action, lookup, action.op, order)
      end
    end
  end

  for _, link in ipairs(trace and trace.chainLinks or {}) do
    order = order + 1
    addLink(links, seen, link.sourceResolutionIndex, link.targetResolutionIndex, link, lookup, link.op or "trigger_random_neighbor", order)
  end

  table.sort(links, function(left, right)
    return (left.order or 0) < (right.order or 0)
  end)

  return links
end

local function getCalloutLabel(trickCallouts, resolutionIndex)
  local stack = trickCallouts and trickCallouts[resolutionIndex] or nil

  if not stack or #stack == 0 then
    return nil
  end

  if #stack == 1 then
    return stack[1].label
  end

  return string.format("Combo x%d", #stack)
end

local function collectScoreEntries(batchResult, trickCallouts)
  local entriesByResolution = {}
  local scoreEntries = batchResult and batchResult.scoreBreakdown and batchResult.scoreBreakdown.perCoin or {}

  for _, scoreEntry in ipairs(scoreEntries) do
    local resolutionIndex = getResolutionIndex(scoreEntry.resolutionIndex)
    local amount = getScoreContribution(scoreEntry)

    if resolutionIndex and amount > 0 then
      entriesByResolution[resolutionIndex] = {
        resolutionIndex = resolutionIndex,
        amount = amount,
        sourceLabel = getCalloutLabel(trickCallouts, resolutionIndex) or getCoinLabel(scoreEntry.scoringCoinId or scoreEntry.forgedCoinId or scoreEntry.coinId),
      }
    end
  end

  return entriesByResolution
end

local function addSpecialEvent(events, seen, event)
  local key = string.format("%s:%s:%s:%s", tostring(event.kind), tostring(event.resolutionIndex), tostring(event.instanceId), tostring(event.coinId))

  if seen[key] then
    return false
  end

  seen[key] = true
  table.insert(events, event)
  return true
end

local function collectSpecialEvents(batchResult, timeline)
  local trace = batchResult and batchResult.trace or nil
  local events = {}
  local seen = {}

  for _, move in ipairs(trace and trace.smugglingMoves or {}) do
    local resolutionIndex = getResolutionIndex(move.resolutionIndex or move.boardSlotIndex)
    addSpecialEvent(events, seen, {
      kind = "smuggle_coin_from_hand",
      label = SPECIAL_ACTION_LABELS.smuggle_coin_from_hand,
      coinId = move.coinId,
      instanceId = move.instanceId,
      resolutionIndex = resolutionIndex,
      startTime = 0,
    })
  end

  for _, action in ipairs(trace and trace.actions or {}) do
    if SPECIAL_ACTION_LABELS[action.op] then
      local resolutionIndex = getResolutionIndex(action.resolutionIndex or action.boardSlotIndex)
      local range = timeline and timeline.coinRangesByResolution and timeline.coinRangesByResolution[resolutionIndex] or nil
      local isPostFlipMove = action.op == "extract_failed_smuggling_coin"
        or action.op == "palm_failed_coin"
        or action.op == "monte_rearrange"
      local startTime = isPostFlipMove
        and ((range and range.startTime or 0) + ((timeline and timeline.coinMotionDuration or DEFAULTS.coinMotionDuration) * 0.82))
        or 0
      addSpecialEvent(events, seen, {
        kind = action.op,
        label = SPECIAL_ACTION_LABELS[action.op],
        coinId = action.smuggledCoinId or action.coinId,
        instanceId = action.smuggledInstanceId or action.instanceId,
        resolutionIndex = resolutionIndex,
        startTime = startTime,
      })
    end
  end

  table.sort(events, function(left, right)
    return (left.startTime or 0) < (right.startTime or 0)
  end)

  return events
end

local function addSleightTravel(travels, move, fields)
  local coinId = fields.coinId

  if not coinId then
    return false
  end

  table.insert(travels, {
    op = move.op,
    coinId = coinId,
    instanceId = fields.instanceId,
    sourceResolutionIndex = getResolutionIndex(fields.sourceResolutionIndex),
    targetResolutionIndex = getResolutionIndex(fields.targetResolutionIndex),
    sourceKind = fields.sourceKind,
    targetKind = fields.targetKind,
    sourceDealtIndex = fields.sourceDealtIndex,
    targetDealtIndex = fields.targetDealtIndex,
    order = fields.order or 0,
  })

  return true
end

local function collectSleightTravels(batchResult)
  local trace = batchResult and batchResult.trace or nil
  local travels = {}
  local order = 0

  for _, move in ipairs(trace and trace.sleightMoves or {}) do
    if move.op == "swap_coins" then
      order = order + 1

      addSleightTravel(travels, move, {
        coinId = move.failedCoinId,
        instanceId = move.failedInstanceId,
        sourceResolutionIndex = move.failedResolutionIndex,
        targetResolutionIndex = move.successResolutionIndex,
        order = order,
      })
      addSleightTravel(travels, move, {
        coinId = move.successCoinId,
        instanceId = move.successInstanceId,
        sourceResolutionIndex = move.successResolutionIndex,
        targetResolutionIndex = move.failedResolutionIndex,
        order = order,
      })
    elseif move.op == "replace_coin_from_hand" then
      order = order + 1

      addSleightTravel(travels, move, {
        coinId = move.replacementCoinId,
        instanceId = move.replacementInstanceId,
        sourceKind = "hand",
        sourceDealtIndex = move.replacementDealtIndex,
        targetResolutionIndex = move.targetResolutionIndex,
        order = order,
      })
      addSleightTravel(travels, move, {
        coinId = move.targetCoinId,
        instanceId = move.targetInstanceId,
        sourceResolutionIndex = move.targetResolutionIndex,
        targetKind = "hand",
        targetDealtIndex = move.replacementDealtIndex,
        order = order,
      })
    elseif move.op == "palm_failed_coin" then
      order = order + 1
      addSleightTravel(travels, move, {
        coinId = move.coinId,
        instanceId = move.instanceId,
        sourceResolutionIndex = move.targetResolutionIndex,
        targetKind = "hand",
        targetDealtIndex = move.targetDealtIndex,
        order = order,
      })
    elseif move.op == "monte_rearrange" then
      order = order + 1
      for _, bodyMove in ipairs(move.moves or {}) do
        addSleightTravel(travels, move, {
          coinId = bodyMove.coinId,
          instanceId = bodyMove.instanceId,
          sourceResolutionIndex = bodyMove.sourceResolutionIndex,
          targetResolutionIndex = bodyMove.targetResolutionIndex,
          order = order,
        })
      end
    end
  end

  for _, move in ipairs(trace and trace.smugglingExtractions or {}) do
    order = order + 1

    addSleightTravel(travels, move, {
      coinId = move.replacementCoinId,
      instanceId = move.replacementInstanceId,
      sourceKind = "hand",
      sourceDealtIndex = move.replacementDealtIndex,
      targetResolutionIndex = move.targetResolutionIndex,
      order = order,
    })
    addSleightTravel(travels, move, {
      coinId = move.savedCoinId,
      instanceId = move.savedInstanceId,
      sourceResolutionIndex = move.targetResolutionIndex,
      targetKind = "hand",
      targetDealtIndex = move.replacementDealtIndex,
      order = order,
    })
  end

  return travels
end

local function hasSmuggleEvent(batchResult)
  local trace = batchResult and batchResult.trace or nil

  if #(trace and trace.smugglingMoves or {}) > 0 then
    return true
  end

  for _, action in ipairs(trace and trace.actions or {}) do
    if action.op == "smuggle_coin_from_hand" then
      return true
    end
  end

  return false
end

local function groupLinksBySource(links)
  local grouped = {}

  for _, link in ipairs(links or {}) do
    grouped[link.sourceResolutionIndex] = grouped[link.sourceResolutionIndex] or {}
    table.insert(grouped[link.sourceResolutionIndex], link)
  end

  return grouped
end

local function buildOptions(options)
  local source = options or {}

  return {
    coinMotionDuration = tonumber(source.coinMotionDuration) or DEFAULTS.coinMotionDuration,
    baseHoldDuration = tonumber(source.baseHoldDuration) or DEFAULTS.baseHoldDuration,
    effectHoldDuration = tonumber(source.effectHoldDuration) or DEFAULTS.effectHoldDuration,
    scoreHoldDuration = tonumber(source.scoreHoldDuration) or DEFAULTS.scoreHoldDuration,
    linkDuration = tonumber(source.linkDuration) or DEFAULTS.linkDuration,
    sleightMoveDuration = tonumber(source.sleightMoveDuration) or DEFAULTS.sleightMoveDuration,
    threeCupsDuration = tonumber(source.threeCupsDuration) or DEFAULTS.threeCupsDuration,
    trickCallouts = source.trickCallouts,
  }
end

local function getLandTime(timeline, resolutionIndex)
  local normalizedResolutionIndex = getResolutionIndex(resolutionIndex)

  if not normalizedResolutionIndex then
    return nil
  end

  local startTime = timeline.coinStartsByResolution[normalizedResolutionIndex]

  if startTime == nil then
    return nil
  end

  return startTime + ((timeline.coinMotionDuration or DEFAULTS.coinMotionDuration) * 0.78)
end

local function resolveSleightStartTime(timeline, travel, holdDuration)
  local sourceLandTime = getLandTime(timeline, travel.sourceResolutionIndex)
  local targetLandTime = getLandTime(timeline, travel.targetResolutionIndex)
  local startTime = math.max(sourceLandTime or 0, targetLandTime or 0)

  return startTime + ((holdDuration or DEFAULTS.effectHoldDuration) * 0.34)
end

local function scheduleSleightTravels(timeline, travels, options)
  local latestEndTime = timeline.displayDuration or 0

  for _, travel in ipairs(travels or {}) do
    local speedFactor = getEventSpeedFactor(travel.order or 1)
    travel.startTime = resolveSleightStartTime(timeline, travel, options.effectHoldDuration)
    travel.duration = (options.sleightMoveDuration or DEFAULTS.sleightMoveDuration) * speedFactor
    latestEndTime = math.max(latestEndTime, travel.startTime + travel.duration)
    table.insert(timeline.sleightTravels, travel)
  end

  table.sort(timeline.sleightTravels, function(left, right)
    if (left.startTime or 0) == (right.startTime or 0) then
      return (left.order or 0) < (right.order or 0)
    end

    return (left.startTime or 0) < (right.startTime or 0)
  end)

  timeline.displayDuration = math.max(timeline.displayDuration or 0, latestEndTime + 0.24)
end

function RevealTimeline.build(batchResult, options)
  local timelineOptions = buildOptions(options)
  local trace = batchResult and batchResult.trace or nil
  local lookup = buildSourceLookup(trace)
  local links = collectLinks(batchResult, lookup)
  local sleightTravels = collectSleightTravels(batchResult)
  local linksBySource = groupLinksBySource(links)
  local scoreEntriesByResolution = collectScoreEntries(batchResult, timelineOptions.trickCallouts)
  local timeline = {
    coinMotionDuration = timelineOptions.coinMotionDuration,
    coinStarts = {},
    coinStartsByResolution = {},
    coinRangesByResolution = {},
    links = {},
    sleightTravels = {},
    scoreBounces = {},
    scoreFeed = {},
    eventFeed = {},
    revealDuration = 0,
    displayDuration = 0,
    threeCupsDuration = trace and trace.threeCups and trace.threeCups.palmed
      and timelineOptions.threeCupsDuration or 0,
  }
  local currentTime = timeline.threeCupsDuration
    + (hasSmuggleEvent(batchResult) and (timelineOptions.baseHoldDuration + timelineOptions.effectHoldDuration) or 0)
  local perCoin = batchResult and batchResult.perCoin or {}

  for index, coinState in ipairs(perCoin) do
    local resolutionIndex = getResolutionIndex(coinState.resolutionIndex) or index
    local coinStartTime = currentTime
    local coinLandTime = coinStartTime + (timelineOptions.coinMotionDuration * 0.78)
    local sourceLinks = linksBySource[resolutionIndex] or {}
    local scoreEntry = scoreEntriesByResolution[resolutionIndex]
    local calloutCount = #(timelineOptions.trickCallouts and timelineOptions.trickCallouts[resolutionIndex] or {})
    local eventCount = math.max(#sourceLinks, calloutCount)
    local totalEventCount = eventCount + (scoreEntry and 1 or 0)
    local coinSpeed = getEventSpeedFactor(totalEventCount)
    local eventHoldDuration = timelineOptions.effectHoldDuration * coinSpeed
    local scoreHoldDuration = timelineOptions.scoreHoldDuration * coinSpeed
    local baseHoldDuration = timelineOptions.baseHoldDuration * math.max(0.72, coinSpeed)

    timeline.coinStarts[index] = coinStartTime
    timeline.coinStartsByResolution[resolutionIndex] = coinStartTime

    if scoreEntry then
      table.insert(timeline.scoreFeed, {
        startTime = coinLandTime + 0.06,
        resolutionIndex = resolutionIndex,
        amount = scoreEntry.amount,
        sourceLabel = scoreEntry.sourceLabel,
        kind = "coin_score",
      })
    end

    for linkIndex, link in ipairs(sourceLinks) do
      local eventSpeed = getEventSpeedFactor(linkIndex)
      local startTime = coinLandTime + 0.08 + ((linkIndex - 1) * eventHoldDuration)

      local linkDuration = timelineOptions.linkDuration * eventSpeed

      table.insert(timeline.links, {
        startTime = startTime,
        duration = linkDuration,
        sourceResolutionIndex = link.sourceResolutionIndex,
        targetResolutionIndex = link.targetResolutionIndex,
        label = link.label,
        sourceId = link.sourceId,
        sourceType = link.sourceType,
        phase = link.phase,
        op = link.op,
      })

      if scoreEntriesByResolution[link.targetResolutionIndex] then
        table.insert(timeline.scoreBounces, {
          startTime = startTime + (linkDuration * 0.72),
          resolutionIndex = link.targetResolutionIndex,
        })
      end
    end

    currentTime = coinStartTime
      + timelineOptions.coinMotionDuration
      + baseHoldDuration
      + (eventCount * eventHoldDuration)
      + (scoreEntry and scoreHoldDuration or 0)

    timeline.coinRangesByResolution[resolutionIndex] = {
      startTime = coinStartTime,
      endTime = currentTime,
    }
  end

  table.sort(timeline.scoreFeed, function(left, right)
    return (left.startTime or 0) < (right.startTime or 0)
  end)

  timeline.revealDuration = timeline.coinStarts[#perCoin] or 0
  timeline.displayDuration = currentTime + 0.82
  scheduleSleightTravels(timeline, sleightTravels, timelineOptions)
  timeline.eventFeed = collectSpecialEvents(batchResult, timeline)

  return timeline
end

function RevealTimeline.getCoinStart(timeline, index, resolutionIndex)
  if not timeline then
    return nil
  end

  return timeline.coinStartsByResolution[getResolutionIndex(resolutionIndex)] or timeline.coinStarts[index]
end

function RevealTimeline.isCoinActive(timeline, resolutionIndex, elapsed)
  if not timeline then
    return false
  end

  local range = timeline.coinRangesByResolution[getResolutionIndex(resolutionIndex)]

  if not range then
    return false
  end

  return (elapsed or 0) >= (range.startTime or 0) and (elapsed or 0) < (range.endTime or 0)
end

function RevealTimeline.getActiveLinks(timeline, elapsed)
  local active = {}

  for _, link in ipairs(timeline and timeline.links or {}) do
    local age = (elapsed or 0) - (link.startTime or 0)

    if age >= 0 and age < (link.duration or DEFAULTS.linkDuration) then
      local copy = {}

      for key, value in pairs(link) do
        copy[key] = value
      end

      copy.age = age
      copy.progress = clamp(age / math.max(0.001, link.duration or DEFAULTS.linkDuration), 0, 1)
      table.insert(active, copy)
    end
  end

  return active
end

function RevealTimeline.getActiveSleightTravels(timeline, elapsed)
  local active = {}

  for _, travel in ipairs(timeline and timeline.sleightTravels or {}) do
    local age = (elapsed or 0) - (travel.startTime or 0)

    if age >= 0 and age < (travel.duration or DEFAULTS.sleightMoveDuration) then
      local copy = {}

      for key, value in pairs(travel) do
        copy[key] = value
      end

      copy.age = age
      copy.progress = clamp(age / math.max(0.001, travel.duration or DEFAULTS.sleightMoveDuration), 0, 1)
      table.insert(active, copy)
    end
  end

  return active
end

return RevealTimeline
