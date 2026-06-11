local Theme = require("src.ui.theme")

local ScoreFloaty = {}

local function copyColor(color)
  local source = color or Theme.colors.text
  return { source[1], source[2], source[3], source[4] or 1.0 }
end

local function getConfig(options)
  return options and options.config or Theme.scoreFloaty or {}
end

function ScoreFloaty.new(label, x, y, options)
  local floatyOptions = options or {}
  local config = getConfig(floatyOptions)
  local direction = floatyOptions.direction or "up"
  local distance = floatyOptions.distance or (direction == "down" and config.damageDistance or config.distance) or 48

  return {
    label = label or "",
    x = x or 0,
    y = y or 0,
    elapsed = 0,
    duration = floatyOptions.duration or config.duration or 1.05,
    fadeOutDuration = config.fadeOutDuration or 0.32,
    popScale = floatyOptions.popScale or config.popScale or 1.25,
    direction = direction,
    distance = distance,
    color = copyColor(floatyOptions.color),
    outlineColor = copyColor(config.outlineColor or { 0, 0, 0, 0.86 }),
    shadowColor = copyColor(config.shadowColor or { 0, 0, 0, 0.55 }),
    outline = floatyOptions.outline or config.outline or 3,
    fontName = floatyOptions.fontName or config.fontName or "heading",
  }
end

function ScoreFloaty.update(floaty, dt)
  if not floaty then
    return nil
  end

  floaty.elapsed = floaty.elapsed + (dt or 0)

  if floaty.elapsed >= floaty.duration then
    return nil
  end

  return floaty
end

function ScoreFloaty.updateAll(floaties, dt)
  if not floaties then
    return {}
  end

  for index = #floaties, 1, -1 do
    if not ScoreFloaty.update(floaties[index], dt) then
      table.remove(floaties, index)
    end
  end

  return floaties
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function getAlpha(floaty)
  local duration = math.max(0.01, floaty.duration or 1.05)
  local fadeOutDuration = math.max(0.01, math.min(floaty.fadeOutDuration or 0.32, duration))
  local remaining = math.max(0, duration - (floaty.elapsed or 0))
  local fade = remaining < fadeOutDuration and (remaining / fadeOutDuration) or 1
  local flash = math.min(1, (floaty.elapsed or 0) / 0.08)

  return fade * flash
end

local function getScale(floaty)
  local progress = math.min(1, (floaty.elapsed or 0) / 0.16)
  return 1 + (((floaty.popScale or 1.25) - 1) * (1 - progress))
end

local function drawCenteredText(label, font, x, y, color, alpha)
  local padding = Theme.scale(8)
  local width = math.max(1, font:getWidth(label) + (padding * 2))
  love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * alpha)
  love.graphics.printf(label, x - math.floor(width / 2), y, width, "center")
end

function ScoreFloaty.draw(floaty, fonts)
  if not floaty or floaty.label == "" then
    return
  end

  local currentFont = love.graphics.getFont()
  local font = fonts and fonts[floaty.fontName] or currentFont
  local progress = math.min(1, (floaty.elapsed or 0) / math.max(0.01, floaty.duration or 1.05))
  local travel = easeOutCubic(progress) * (floaty.distance or 48)
  local directionSign = floaty.direction == "down" and 1 or -1
  local alpha = getAlpha(floaty)
  local scale = getScale(floaty)
  local x = math.floor(floaty.x or 0)
  local y = math.floor((floaty.y or 0) + (travel * directionSign) - (font:getHeight() * 0.5))
  local outline = math.max(1, math.floor(floaty.outline or 3))

  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  love.graphics.setFont(font)

  drawCenteredText(floaty.label, font, outline + 2, outline + 4, floaty.shadowColor, alpha)

  for _, offset in ipairs({
    { -outline, 0 },
    { outline, 0 },
    { 0, -outline },
    { 0, outline },
    { -outline, -outline },
    { outline, -outline },
    { -outline, outline },
    { outline, outline },
  }) do
    drawCenteredText(floaty.label, font, offset[1], offset[2], floaty.outlineColor, alpha)
  end

  drawCenteredText(floaty.label, font, 0, 0, floaty.color, alpha)

  love.graphics.pop()
  love.graphics.setFont(currentFont)
  Theme.applyColor(Theme.colors.text)
end

function ScoreFloaty.drawAll(floaties, fonts)
  for _, floaty in ipairs(floaties or {}) do
    ScoreFloaty.draw(floaty, fonts)
  end
end

return ScoreFloaty
