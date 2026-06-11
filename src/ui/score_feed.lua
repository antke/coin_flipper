local Theme = require("src.ui.theme")

local ScoreFeed = {}

local MAX_VISIBLE = 5
local PUSH_DURATION = 0.20
local HEADER_BASE_SCALE = 2.0
local HEADER_PULSE_DURATION = 0.34
local HEADER_SPARK_DURATION = 0.44

local POSITION_ALPHA = {
  1.00,
  0.80,
  0.60,
  0.40,
  0.25,
  0.12,
}

local OUTLINE_OFFSETS = {
  { -2, 0 },
  { 2, 0 },
  { 0, -2 },
  { 0, 2 },
  { -2, -2 },
  { 2, -2 },
  { -2, 2 },
  { 2, 2 },
}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function lerp(startValue, endValue, progress)
  return startValue + ((endValue - startValue) * progress)
end

local function formatSignedScore(value)
  local amount = tonumber(value) or 0

  if math.abs(amount - math.floor(amount + 0.5)) < 0.001 then
    amount = math.floor(amount + 0.5)
    return amount >= 0 and string.format("+%d", amount) or tostring(amount)
  end

  return amount >= 0 and string.format("+%.1f", amount) or string.format("%.1f", amount)
end

local function getEntryAmount(entry)
  return tonumber(entry and entry.amount) or 0
end

local function setColor(color, alpha)
  local source = color or Theme.colors.text
  love.graphics.setColor(source[1], source[2], source[3], (source[4] or 1) * (alpha or 1))
end

local function getEntryLabel(entry)
  local score = formatSignedScore(entry and entry.amount or 0)
  local source = tostring(entry and entry.sourceLabel or "Score")

  if source == "" then
    source = "Score"
  end

  return string.format("%s %s", score, source)
end

local function drawOutlined(label, font, x, y, width, color, alpha, scale)
  local textScale = scale or 1
  local scaledWidth = math.max(1, math.floor((width or 1) / math.max(0.01, textScale)))

  love.graphics.push()
  love.graphics.translate(math.floor(x), math.floor(y))
  love.graphics.scale(textScale, textScale)
  love.graphics.setFont(font)

  setColor({ 0, 0, 0, 0.52 }, alpha)
  love.graphics.printf(label, Theme.scale(3), Theme.scale(4), scaledWidth, "left")

  for _, offset in ipairs(OUTLINE_OFFSETS) do
    setColor({ 0, 0, 0, 0.82 }, alpha)
    love.graphics.printf(label, offset[1], offset[2], scaledWidth, "left")
  end

  setColor(color, alpha)
  love.graphics.printf(label, 0, 0, scaledWidth, "left")

  love.graphics.pop()
end

local function drawOutlinedSingleLine(label, font, x, y, color, alpha, scale)
  local textScale = scale or 1

  love.graphics.push()
  love.graphics.translate(math.floor(x), math.floor(y))
  love.graphics.scale(textScale, textScale)
  love.graphics.setFont(font)

  setColor({ 0, 0, 0, 0.52 }, alpha)
  love.graphics.print(label, Theme.scale(3), Theme.scale(4))

  for _, offset in ipairs(OUTLINE_OFFSETS) do
    setColor({ 0, 0, 0, 0.82 }, alpha)
    love.graphics.print(label, offset[1], offset[2])
  end

  setColor(color, alpha)
  love.graphics.print(label, 0, 0)

  love.graphics.pop()
end

local function getSingleLineScale(label, font, width, scale)
  local targetScale = scale or 1
  local labelWidth = font:getWidth(label)

  if labelWidth <= 0 then
    return targetScale
  end

  return math.min(targetScale, math.max(0.48, (width or 1) / labelWidth))
end

local function drawHeaderGlow(label, font, x, y, width, color, alpha, scale, intensity)
  local glow = clamp(intensity or 0, 0, 1)

  if glow <= 0.01 then
    return
  end

  local textScale = scale or HEADER_BASE_SCALE
  local scaledWidth = math.max(1, math.floor((width or 1) / math.max(0.01, textScale)))
  local radii = { Theme.scale(10), Theme.scale(6), Theme.scale(3) }

  love.graphics.push()
  love.graphics.translate(math.floor(x), math.floor(y))
  love.graphics.scale(textScale, textScale)
  love.graphics.setFont(font)

  for index, radius in ipairs(radii) do
    setColor(color, alpha * glow * (0.11 / index))
    love.graphics.printf(label, -radius, 0, scaledWidth, "left")
    love.graphics.printf(label, radius, 0, scaledWidth, "left")
    love.graphics.printf(label, 0, -radius, scaledWidth, "left")
    love.graphics.printf(label, 0, radius, scaledWidth, "left")
  end

  love.graphics.pop()
end

local function drawHeaderSparks(x, y, width, fontHeight, color, age)
  local progress = clamp((age or 0) / HEADER_SPARK_DURATION, 0, 1)

  if progress <= 0 or progress >= 1 then
    return
  end

  local alpha = (1 - progress) * 0.58
  local centerX = x + math.min(width * 0.72, Theme.scale(118))
  local centerY = y + math.floor(fontHeight * HEADER_BASE_SCALE * 0.42)
  local distance = Theme.scale(8) + (Theme.scale(18) * easeOutCubic(progress))
  local sparkCount = 5

  for index = 1, sparkCount do
    local angle = (-0.85 + (index - 1) * 0.42) * math.pi
    local sparkX = centerX + (math.cos(angle) * distance)
    local sparkY = centerY + (math.sin(angle) * distance * 0.48)
    local radius = Theme.scale(index % 2 == 0 and 1.7 or 2.2)

    setColor(color, alpha)
    love.graphics.circle("fill", sparkX, sparkY, radius)
  end
end

local function getActiveEntries(entries, elapsed)
  local active = {}

  for _, entry in ipairs(entries or {}) do
    if (entry.startTime or 0) <= (elapsed or 0) then
      table.insert(active, entry)
    end
  end

  table.sort(active, function(left, right)
    return (left.startTime or 0) > (right.startTime or 0)
  end)

  return active
end

local function getCumulativeAmount(activeEntries)
  local total = 0

  for _, entry in ipairs(activeEntries or {}) do
    total = total + getEntryAmount(entry)
  end

  return total
end

function ScoreFeed.draw(entries, fonts, x, y, width, options)
  if #(entries or {}) == 0 then
    return
  end

  local active = getActiveEntries(entries, options and options.elapsed or 0)

  local previousFont = love.graphics.getFont()
  local previousLineWidth = love.graphics.getLineWidth()
  local font = fonts and fonts.heading or previousFont
  local elapsed = options and options.elapsed or 0
  local baseLineStep = options and options.lineStep or math.max(Theme.scale(24), math.floor(font:getHeight() * 0.72))
  local drawWidth = math.max(1, width or Theme.scale(180))
  local maxRows = options and options.maxVisible or MAX_VISIBLE
  local rowsToDraw = math.min(#active, maxRows + 1)
  local cumulative = getCumulativeAmount(active)
  local latestEntry = active[1]
  local latestAge = latestEntry and (elapsed - (latestEntry.startTime or 0)) or HEADER_PULSE_DURATION
  local headerPulse = latestEntry and (1 - clamp(latestAge / HEADER_PULSE_DURATION, 0, 1)) or 0
  local headerScale = HEADER_BASE_SCALE + (0.20 * easeOutCubic(headerPulse))
  local headerColor = cumulative < 0 and Theme.colors.danger or Theme.colors.success
  local headerLabel = formatSignedScore(cumulative)
  local headerReservedHeight = math.floor(font:getHeight() * (HEADER_BASE_SCALE + 0.28))
  local listY = headerReservedHeight + Theme.scale(10)
  local availableHeight = options and options.height or nil
  local listHeight = availableHeight and math.max(1, availableHeight - listY) or nil
  local rowScale = listHeight and clamp(listHeight / math.max(baseLineStep, rowsToDraw * baseLineStep), 0.62, 1) or 1
  local lineStep = math.max(Theme.scale(14), math.floor(baseLineStep * rowScale))

  drawHeaderGlow(headerLabel, font, x, y, drawWidth, headerColor, 1, headerScale, 0.32 + (headerPulse * 0.68))
  drawOutlined(headerLabel, font, x, y, drawWidth, headerColor, 1, headerScale)

  if latestEntry and getEntryAmount(latestEntry) > 0 then
    drawHeaderSparks(x, y, drawWidth, font:getHeight(), headerColor, latestAge)
  end

  for index = rowsToDraw, 1, -1 do
    local entry = active[index]
    local slotIndex = index - 1
    local pushTime = index > 1 and active[index - 1].startTime or entry.startTime
    local pushProgress = clamp((elapsed - (pushTime or 0)) / PUSH_DURATION, 0, 1)
    local easedPush = easeOutCubic(pushProgress)
    local targetY = (slotIndex * lineStep)
    local previousY = slotIndex == 0 and -lineStep or ((slotIndex - 1) * lineStep)
    local rowY = lerp(previousY, targetY, easedPush)
    local alpha = POSITION_ALPHA[slotIndex + 1] or 0.10

    if slotIndex >= maxRows then
      alpha = alpha * (1 - easedPush)
    end

    if alpha > 0.01 then
      local age = elapsed - (entry.startTime or 0)
      local flash = clamp(age / 0.08, 0, 1)
      local pop = 1 + (0.18 * (1 - clamp(age / 0.16, 0, 1)))
      local color = getEntryAmount(entry) < 0 and Theme.colors.danger or Theme.colors.success

      local label = getEntryLabel(entry)
      local fittedScale = getSingleLineScale(label, font, drawWidth, pop * rowScale)

      drawOutlinedSingleLine(label, font, x, y + listY + rowY, color, alpha * flash, fittedScale)
    end
  end

  love.graphics.setFont(previousFont)
  love.graphics.setLineWidth(previousLineWidth)
  Theme.applyColor(Theme.colors.text)
end

return ScoreFeed
