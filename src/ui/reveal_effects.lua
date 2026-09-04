local RevealTimeline = require("src.ui.reveal_timeline")
local Theme = require("src.ui.theme")

local RevealEffects = {}

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function lerp(startValue, endValue, progress)
  return startValue + ((endValue - startValue) * progress)
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function setColor(color, alpha)
  local source = color or Theme.colors.text
  love.graphics.setColor(source[1], source[2], source[3], (source[4] or 1) * (alpha or 1))
end

local function getPointOnCurve(source, controlX, controlY, target, progress)
  local inverse = 1 - progress
  local x = (inverse * inverse * source.x) + (2 * inverse * progress * controlX) + (progress * progress * target.x)
  local y = (inverse * inverse * source.y) + (2 * inverse * progress * controlY) + (progress * progress * target.y)

  return x, y
end

local function drawCurve(source, target, progress)
  local distance = math.abs((target.x or 0) - (source.x or 0))
  local archHeight = math.max(Theme.scale(34), math.min(Theme.scale(88), distance * 0.22))
  local controlX = (source.x + target.x) / 2
  local controlY = math.min(source.y, target.y) - archHeight
  local steps = math.max(5, math.floor(10 * clamp(progress, 0, 1)))
  local previousX = source.x
  local previousY = source.y

  for step = 1, steps do
    local t = progress * (step / steps)
    local nextX, nextY = getPointOnCurve(source, controlX, controlY, target, t)
    love.graphics.line(previousX, previousY, nextX, nextY)
    previousX = nextX
    previousY = nextY
  end

  return getPointOnCurve(source, controlX, controlY, target, clamp(progress, 0, 1))
end

local function drawOutlinedText(label, font, x, y, width, alpha)
  local text = tostring(label or "")

  if text == "" then
    return
  end

  love.graphics.setFont(font)
  setColor({ 0, 0, 0, 0.80 }, alpha)
  love.graphics.printf(text, x + Theme.scale(1), y + Theme.scale(2), width, "center")
  love.graphics.printf(text, x - Theme.scale(1), y, width, "center")
  love.graphics.printf(text, x + Theme.scale(1), y, width, "center")
  love.graphics.printf(text, x, y - Theme.scale(1), width, "center")
  love.graphics.printf(text, x, y + Theme.scale(1), width, "center")
  setColor(Theme.colors.warning, alpha)
  love.graphics.printf(text, x, y, width, "center")
end

function RevealEffects.drawLinks(timeline, elapsed, positions, fonts)
  local activeLinks = RevealTimeline.getActiveLinks(timeline, elapsed)

  if #activeLinks == 0 then
    return
  end

  local previousFont = love.graphics.getFont()
  local previousLineWidth = love.graphics.getLineWidth()
  local font = fonts and fonts.small or previousFont

  for _, link in ipairs(activeLinks) do
    local source = positions and positions[link.sourceResolutionIndex] or nil
    local target = positions and positions[link.targetResolutionIndex] or nil

    if source and target then
      local progress = clamp(link.progress or 0, 0, 1)
      local fadeIn = clamp(progress / 0.16, 0, 1)
      local fadeOut = 1 - clamp((progress - 0.76) / 0.24, 0, 1)
      local alpha = fadeIn * fadeOut
      local easedProgress = easeOutCubic(progress)

      love.graphics.setLineWidth(Theme.scale(5))
      setColor({ 0, 0, 0, 0.54 }, alpha)
      drawCurve(source, target, easedProgress)

      love.graphics.setLineWidth(Theme.scale(2))
      setColor(Theme.colors.warning, 0.88 * alpha)
      local sparkX, sparkY = drawCurve(source, target, easedProgress)

      setColor(Theme.colors.text, 0.88 * alpha)
      love.graphics.circle("fill", sparkX, sparkY, Theme.scale(4))
      setColor(Theme.colors.warning, 0.42 * alpha)
      love.graphics.circle("line", sparkX, sparkY, Theme.scale(8))

      if progress > 0.18 and progress < 0.86 then
        local midX = lerp(source.x, target.x, 0.5)
        local midY = math.min(source.y, target.y) - math.max(Theme.scale(36), math.abs(target.x - source.x) * 0.14)
        local labelWidth = Theme.scale(160)
        drawOutlinedText(link.label, font, midX - math.floor(labelWidth / 2), midY - Theme.scale(12), labelWidth, alpha)
      end
    end
  end

  love.graphics.setFont(previousFont)
  love.graphics.setLineWidth(previousLineWidth)
  Theme.applyColor(Theme.colors.text)
end

return RevealEffects
