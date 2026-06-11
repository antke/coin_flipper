local Theme = require("src.ui.theme")

local TextBox = {}

local function snap(value)
  return math.floor((value or 0) + 0.5)
end

local function resolveScale(font, text, rect, options)
  local maxScale = options.maxScale or 1
  local minScale = options.minScale or maxScale
  local scale = maxScale
  local textWidth = math.max(1, font:getWidth(text))
  local textHeight = math.max(1, font:getHeight())

  if options.fit == "shrink" then
    scale = math.min(scale, rect.width / textWidth, rect.height / textHeight)
    scale = math.min(maxScale, scale)

    if options.hardFit == false then
      scale = math.max(minScale, scale)
    else
      scale = math.max(0.01, scale)
    end
  end

  return scale, textWidth, textHeight
end

local function drawAt(text, font, rect, options, offsetX, offsetY)
  if rect.width <= 0 or rect.height <= 0 then
    return {
      x = rect.x,
      y = rect.y,
      width = 0,
      height = 0,
      scale = 0,
      centerX = rect.x,
      centerY = rect.y,
    }
  end

  local scale, textWidth, textHeight = resolveScale(font, text, rect, options)
  local drawWidth = textWidth * scale
  local drawHeight = textHeight * scale
  local x = rect.x
  local y = rect.y

  if options.align == "right" then
    x = rect.x + rect.width - drawWidth
  elseif options.align ~= "left" then
    x = rect.x + ((rect.width - drawWidth) / 2)
  end

  if options.valign == "bottom" then
    y = rect.y + rect.height - drawHeight
  elseif options.valign ~= "top" then
    y = rect.y + ((rect.height - drawHeight) / 2)
  end

  love.graphics.push()
  love.graphics.translate(snap(x + (offsetX or 0)), snap(y + (offsetY or 0)))
  love.graphics.scale(scale, scale)
  love.graphics.setFont(font)
  if options.color then
    Theme.applyColor(options.color)
  end
  love.graphics.printf(text, 0, 0, textWidth, options.align or "center")
  love.graphics.pop()

  return {
    x = snap(x),
    y = snap(y),
    width = snap(drawWidth),
    height = snap(drawHeight),
    scale = scale,
    centerX = snap(x + (drawWidth / 2)),
    centerY = snap(y + (drawHeight / 2)),
  }
end

function TextBox.draw(text, rect, options)
  options = options or {}
  local font = options.font or love.graphics.getFont()
  local previousFont = love.graphics.getFont()
  local label = tostring(text or "")

  local bounds = drawAt(label, font, rect, options, options.offsetX or 0, options.offsetY or 0)

  if previousFont and previousFont ~= font then
    love.graphics.setFont(previousFont)
  end

  return bounds
end

function TextBox.drawOutlined(text, rect, options)
  options = options or {}
  local outline = math.max(0, options.outline or 0)
  local outlineColor = options.outlineColor or { 0, 0, 0, 0.85 }
  local color = options.color or Theme.colors.text
  local bounds = nil

  if outline > 0 then
    local outlineOptions = {}
    for key, value in pairs(options) do
      outlineOptions[key] = value
    end
    outlineOptions.color = outlineColor

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
      drawAt(tostring(text or ""), outlineOptions.font or love.graphics.getFont(), rect, outlineOptions, offset[1], offset[2])
    end
  end

  local textOptions = {}
  for key, value in pairs(options) do
    textOptions[key] = value
  end
  textOptions.color = color
  bounds = TextBox.draw(text, rect, textOptions)

  return bounds
end

return TextBox
