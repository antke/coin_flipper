local Theme = require("src.ui.theme")

local TrickCallout = {}

local STYLE_ORDER = { "combo", "tag" }
local STYLE_LABELS = {
  combo = "Combo Pop",
  tag = "Callout Tags",
}

local ALLOWED_SOURCE_TYPES = {
  trick = true,
  ["run upgrade"] = true,
  ["temporary effect"] = true,
}

local RESOLUTION_FIELDS = {
  "resolutionIndex",
  "sourceResolutionIndex",
  "targetResolutionIndex",
  "spotlightResolutionIndex",
  "scoreCreditResolutionIndex",
  "failedResolutionIndex",
  "successResolutionIndex",
  "packetResolutionIndex",
  "chainedResolutionIndex",
}

local WEIGHT_ACTION_OPS = {
  add_weight = true,
  set_call_match_chance = true,
  modify_coin_weight = true,
}

local SCORE_ACTION_OPS = {
  add_stage_score = true,
  add_run_score = true,
  apply_score_scaling = true,
  apply_score_multiplier = true,
  forge_identity = true,
  redirect_score_credit = true,
  replay_resolution_packet = true,
  smuggle_coin_from_hand = true,
  swap_coins = true,
  trigger_random_neighbor = true,
}

local DIRECT_SCORE_ACTION_OPS = {
  add_stage_score = true,
  add_run_score = true,
}

local OUTLINE_OFFSETS = {
  { -1, 0 },
  { 1, 0 },
  { 0, -1 },
  { 0, 1 },
  { -1, -1 },
  { 1, -1 },
  { -1, 1 },
  { 1, 1 },
}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function sourceKey(sourceType, sourceId, phase)
  return string.format("%s:%s:%s", tostring(sourceType or ""), tostring(sourceId or ""), tostring(phase or ""))
end

local function normalizeLabel(label)
  local text = tostring(label or "")
  return text ~= "" and text or nil
end

local function getResolutionIndex(value)
  local number = tonumber(value)

  if not number or number < 1 or math.floor(number) ~= number then
    return nil
  end

  return number
end

local function isAllowedSourceType(sourceType)
  return ALLOWED_SOURCE_TYPES[sourceType] == true
end

local function getScoreContribution(scoreEntry)
  return tonumber(scoreEntry and scoreEntry.finalScoreContribution)
    or tonumber(scoreEntry and scoreEntry.scoreBeforeAggregateScaling)
    or tonumber(scoreEntry and scoreEntry.scoreBeforeAggregateMultiplier)
    or tonumber(scoreEntry and scoreEntry.baseScoreContribution)
    or 0
end

local function buildScoredResolutionLookup(batchResult)
  local scored = {}
  local breakdown = batchResult and batchResult.scoreBreakdown or nil

  for _, scoreEntry in ipairs(breakdown and (breakdown.scoreEvents or breakdown.perCoin) or {}) do
    local resolutionIndex = getResolutionIndex(scoreEntry.resolutionIndex)

    if resolutionIndex and getScoreContribution(scoreEntry) > 0 then
      scored[resolutionIndex] = true
    end
  end

  for _, coinState in ipairs(batchResult and batchResult.perCoin or {}) do
    local resolutionIndex = getResolutionIndex(coinState.resolutionIndex)

    if resolutionIndex and coinState.result == batchResult.call then
      scored[resolutionIndex] = true
    end
  end

  return scored
end

local function didResolutionScore(scoredResolutions, resolutionIndex)
  local targetIndex = getResolutionIndex(resolutionIndex)
  return targetIndex and scoredResolutions[targetIndex] == true or false
end

local function getWeightSide(change, call)
  if change and change.op == "set_call_match_chance" then
    return call
  end

  if not change or change.side == nil or change.side == "call" then
    return call
  end

  return change.side
end

local function isWeightChangeScoreRelevant(change, coinState, batchResult, scoredResolutions)
  if not didResolutionScore(scoredResolutions, coinState and coinState.resolutionIndex) then
    return false
  end

  local call = batchResult and batchResult.call or nil
  local side = getWeightSide(change, call)

  return (side == "heads" or side == "tails") and side == call and coinState.result == call
end

local function isScoreActionRelevant(action)
  if not action or SCORE_ACTION_OPS[action.op] ~= true then
    return false
  end

  if (action.op == "apply_score_scaling" or action.op == "apply_score_multiplier")
    and action.target ~= nil
    and action.target ~= "current_coin_score" then
    return false
  end

  return true
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

local function addCallout(stacks, seen, resolutionIndex, source, lookup, order, op)
  local targetIndex = getResolutionIndex(resolutionIndex)

  if not targetIndex then
    return false
  end

  local sourceId, sourceType, phase, label = resolveSource(source, lookup)

  if not label then
    return false
  end

  local dedupeKey = string.format("%d:%s:%s:%s", targetIndex, tostring(sourceType), tostring(sourceId), tostring(phase or ""))

  if seen[dedupeKey] then
    return false
  end

  seen[dedupeKey] = true
  stacks[targetIndex] = stacks[targetIndex] or {}
  table.insert(stacks[targetIndex], {
    label = label,
    sourceId = sourceId,
    sourceType = sourceType,
    phase = phase,
    op = op,
    resolutionIndex = targetIndex,
    order = order or 0,
  })

  return true
end

local function addScoreCallout(stacks, seen, resolutionIndex, source, lookup, order, op, scoredResolutions, allowUnscored)
  if not allowUnscored and not didResolutionScore(scoredResolutions, resolutionIndex) then
    return false
  end

  return addCallout(stacks, seen, resolutionIndex, source, lookup, order, op)
end

local function addActionCallouts(stacks, seen, action, lookup, order, scoredResolutions)
  if WEIGHT_ACTION_OPS[action and action.op] then
    return
  end

  if not isScoreActionRelevant(action) then
    return
  end

  local allowUnscored = DIRECT_SCORE_ACTION_OPS[action.op] == true

  for _, fieldName in ipairs(RESOLUTION_FIELDS) do
    addScoreCallout(stacks, seen, action[fieldName], action, lookup, order, action.op, scoredResolutions, allowUnscored)
  end
end

local function addWeightChangeCallouts(stacks, seen, batchResult, lookup, order, scoredResolutions)
  local nextOrder = order or 0

  for _, coinState in ipairs(batchResult and batchResult.perCoin or {}) do
    for _, change in ipairs(coinState.weightChanges or {}) do
      nextOrder = nextOrder + 1

      if isWeightChangeScoreRelevant(change, coinState, batchResult, scoredResolutions) then
        addCallout(stacks, seen, coinState.resolutionIndex, change, lookup, nextOrder, change.op)
      end
    end
  end

  return nextOrder
end

local function addChainLinkCallouts(stacks, seen, trace, lookup, order, scoredResolutions)
  local nextOrder = order or 0

  for _, link in ipairs(trace and trace.chainLinks or {}) do
    nextOrder = nextOrder + 1
    addScoreCallout(stacks, seen, link.sourceResolutionIndex, link, lookup, nextOrder, link.op, scoredResolutions)
    addScoreCallout(stacks, seen, link.targetResolutionIndex, link, lookup, nextOrder, link.op, scoredResolutions)
  end

  return nextOrder
end

function TrickCallout.buildStacks(batchResult)
  local trace = batchResult and batchResult.trace or nil
  local lookup = buildSourceLookup(trace)
  local scoredResolutions = buildScoredResolutionLookup(batchResult)
  local stacks = {}
  local seen = {}
  local order = 0

  for _, action in ipairs(trace and trace.actions or {}) do
    order = order + 1
    addActionCallouts(stacks, seen, action, lookup, order, scoredResolutions)
  end

  order = addWeightChangeCallouts(stacks, seen, batchResult, lookup, order, scoredResolutions)
  addChainLinkCallouts(stacks, seen, trace, lookup, order, scoredResolutions)

  for _, stack in pairs(stacks) do
    table.sort(stack, function(left, right)
      return (left.order or 0) < (right.order or 0)
    end)
  end

  return stacks
end

function TrickCallout.normalizeStyle(style)
  if style == "tag" or style == "tags" or style == "rail" then
    return "tag"
  end

  return "combo"
end

function TrickCallout.nextStyle(style)
  local normalized = TrickCallout.normalizeStyle(style)

  for index, candidate in ipairs(STYLE_ORDER) do
    if candidate == normalized then
      return STYLE_ORDER[(index % #STYLE_ORDER) + 1]
    end
  end

  return STYLE_ORDER[1]
end

function TrickCallout.getStyleLabel(style)
  return STYLE_LABELS[TrickCallout.normalizeStyle(style)]
end

local function setColor(color, alpha)
  local source = color or Theme.colors.text
  love.graphics.setColor(source[1], source[2], source[3], (source[4] or 1.0) * (alpha or 1))
end

local function truncateLabel(label, font, maxWidth)
  local text = tostring(label or "")

  if not font or not maxWidth or font:getWidth(text) <= maxWidth then
    return text
  end

  local suffix = ".."
  local candidate = text

  while #candidate > 1 and font:getWidth(candidate .. suffix) > maxWidth do
    candidate = candidate:sub(1, #candidate - 1)
  end

  return candidate .. suffix
end

local function drawText(label, x, y, color, alpha)
  setColor(color, alpha)
  love.graphics.print(label, x, y)
end

local function drawComboCallout(label, font, x, y, maxWidth, alpha, scale)
  local text = truncateLabel(string.upper(label), font, maxWidth)
  local textWidth = font:getWidth(text)
  local outline = math.max(1, Theme.scale(2))

  love.graphics.push()
  love.graphics.translate(math.floor(x), math.floor(y))
  love.graphics.scale(scale, scale)
  love.graphics.setFont(font)

  drawText(text, -math.floor(textWidth / 2) + Theme.scale(2), Theme.scale(3), { 0, 0, 0, 0.62 }, alpha)

  for _, offset in ipairs(OUTLINE_OFFSETS) do
    drawText(text, -math.floor(textWidth / 2) + (offset[1] * outline), offset[2] * outline, { 0, 0, 0, 0.90 }, alpha)
  end

  drawText(text, -math.floor(textWidth / 2), 0, Theme.colors.warning, alpha)
  love.graphics.pop()
end

local function drawTagCallout(label, font, x, y, maxWidth, alpha, scale)
  local padX = Theme.scale(7)
  local padY = Theme.scale(3)
  local stripeWidth = Theme.scale(4)
  local textMaxWidth = math.max(1, maxWidth - (padX * 2) - stripeWidth)
  local text = truncateLabel(label, font, textMaxWidth)
  local textWidth = font:getWidth(text)
  local tagWidth = math.floor(textWidth + (padX * 2) + stripeWidth)
  local tagHeight = math.floor(font:getHeight() + (padY * 2))
  local radius = Theme.scale(5)
  local left = -math.floor(tagWidth / 2)

  love.graphics.push()
  love.graphics.translate(math.floor(x), math.floor(y))
  love.graphics.scale(scale, scale)
  love.graphics.setFont(font)

  love.graphics.setColor(0, 0, 0, 0.42 * alpha)
  love.graphics.rectangle("fill", left + Theme.scale(2), Theme.scale(3), tagWidth, tagHeight, radius, radius)
  love.graphics.setColor(0.04, 0.05, 0.08, 0.84 * alpha)
  love.graphics.rectangle("fill", left, 0, tagWidth, tagHeight, radius, radius)
  setColor(Theme.colors.warning, 0.95 * alpha)
  love.graphics.rectangle("fill", left, 0, stripeWidth, tagHeight, radius, radius)
  setColor(Theme.colors.panelBorder, 0.72 * alpha)
  love.graphics.rectangle("line", left, 0, tagWidth, tagHeight, radius, radius)
  drawText(text, left + stripeWidth + padX, padY, Theme.colors.text, alpha)
  love.graphics.pop()
end

function TrickCallout.drawStack(callouts, fonts, anchorX, anchorY, options)
  if not callouts or #callouts == 0 then
    return
  end

  local calloutOptions = options or {}
  local revealAge = tonumber(calloutOptions.revealAge) or 0
  local startDelay = calloutOptions.startDelay or ((calloutOptions.coinMotionDuration or 0.25) * 0.72)
  local duration = calloutOptions.duration or 0.82
  local stagger = calloutOptions.stagger or 0.075
  local style = TrickCallout.normalizeStyle(calloutOptions.style)
  local previousFont = love.graphics.getFont()
  local previousLineWidth = love.graphics.getLineWidth()
  local font = fonts and fonts.small or previousFont
  local maxWidth = math.max(Theme.scale(72), calloutOptions.maxWidth or Theme.scale(180))
  local lineStep = math.max(Theme.scale(17), math.floor(font:getHeight() * 0.76))
  local stackHeight = (#callouts - 1) * lineStep
  local baseY = math.floor((anchorY or 0) - stackHeight)

  for index, callout in ipairs(callouts) do
    local age = revealAge - startDelay - ((index - 1) * stagger)

    if age >= 0 and age < duration then
      local progress = clamp(age / duration, 0, 1)
      local remaining = duration - age
      local fade = remaining < 0.30 and (remaining / 0.30) or 1
      local flash = clamp(age / 0.06, 0, 1)
      local alpha = fade * flash
      local scale = 1 + (0.22 * (1 - clamp(age / 0.14, 0, 1)))
      local travel = easeOutCubic(progress) * Theme.scale(22)
      local lineY = baseY + ((index - 1) * lineStep) + math.floor(travel)

      if style == "tag" then
        drawTagCallout(callout.label, font, anchorX, lineY, maxWidth, alpha, scale)
      else
        drawComboCallout(callout.label, font, anchorX, lineY, maxWidth, alpha, scale)
      end
    end
  end

  love.graphics.setFont(previousFont)
  love.graphics.setLineWidth(previousLineWidth)
  Theme.applyColor(Theme.colors.text)
end

return TrickCallout
