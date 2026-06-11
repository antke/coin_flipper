local Theme = require("src.ui.theme")
local Box = require("src.ui.box")
local TextBox = require("src.ui.text_box")

local Button = {}

local soundPlayer = nil
local defaultFont = nil
local pressEffects = {}
local PRESS_EFFECT_DURATION = 0.18

local BUTTON_HOVER_OVERLAY_ALPHA = 0.08

local function resolveButtonColors(options)
  if options.disabled then
    return Theme.colors.panel, Theme.colors.panelBorder, Theme.colors.mutedText
  end

  if options.active then
    return { 0.22, 0.31, 0.40, 0.96 }, { 0.48, 0.62, 0.70, 1.0 }, Theme.colors.text
  end

  return Theme.colors.panel, Theme.colors.panelBorder, Theme.colors.text
end

local function getTime()
  return love.timer.getTime()
end

local function sameRect(effect, button)
  return effect.x == button.x and effect.y == button.y and effect.width == button.width and effect.height == button.height
end

local function addPressEffect(button)
  table.insert(pressEffects, {
    x = button.x,
    y = button.y,
    width = button.width,
    height = button.height,
    startedAt = getTime(),
  })
end

local function buttonIsPressed(button, now)
  for _, effect in ipairs(pressEffects) do
    if sameRect(effect, button) and now - effect.startedAt <= 0.08 then
      return true
    end
  end

  return false
end

local function drawPixelButtonFrame(x, y, width, height, fill, border, options)
  local _, inner, edge, radius = Box.drawFrame(x, y, width, height, {
    fill = fill,
    border = border,
  })

  if options.disabled then
    Theme.applyColor({ Theme.colors.shadow[1], Theme.colors.shadow[2], Theme.colors.shadow[3], 0.20 })
    love.graphics.rectangle("fill", inner.x, inner.y, inner.width, inner.height, radius, radius)
    return
  end

  if options.pressed then
    Theme.applyColor(Theme.colors.shadow)
    love.graphics.rectangle("fill", inner.x, inner.y, inner.width, edge)
  end

  if options.hovered then
    love.graphics.setColor(1, 1, 1, BUTTON_HOVER_OVERLAY_ALPHA)
    love.graphics.rectangle("fill", x + (edge * 2), y + (edge * 2), width - (edge * 4), height - (edge * 4), radius, radius)
  end
end

function Button.containsPoint(button, x, y)
  return x >= button.x and x <= (button.x + button.width) and y >= button.y and y <= (button.y + button.height)
end

function Button.setSoundPlayer(player)
  soundPlayer = player
end

function Button.setDefaultFont(font)
  defaultFont = font
end

function Button.drawTextButton(x, y, width, height, label, options)
  if type(options) == "boolean" then
    options = { focused = options }
  end

  options = options or {}
  local previousFont = love.graphics.getFont()
  local buttonFont = options.font or defaultFont or previousFont

  if buttonFont and buttonFont ~= previousFont then
    love.graphics.setFont(buttonFont)
  end

  local fill, border, textColor = resolveButtonColors(options)
  local font = love.graphics.getFont()
  local edge = math.max(1, Theme.scale(2))
  local contentArea = Box.contentRect(x, y, width, height, {
    border = edge * 2,
    padding = math.max(1, Theme.scale(2)),
  })
  local textOffset = options.pressed and math.max(1, Theme.scale(1)) or 0

  drawPixelButtonFrame(x, y, width, height, fill, border, options)

  TextBox.draw(label, contentArea, {
    font = font,
    color = textColor,
    align = options.align or "center",
    valign = "center",
    fit = "shrink",
    minScale = 0.5,
    maxScale = 1,
    offsetY = textOffset,
  })

  if buttonFont and buttonFont ~= previousFont then
    love.graphics.setFont(previousFont)
  end
end

function Button.drawButtons(buttons, mouseX, mouseY)
  local now = getTime()

  for _, button in ipairs(buttons or {}) do
    local pressed = buttonIsPressed(button, now)

    Button.drawTextButton(button.x, button.y, button.width, button.height, button.label, {
      focused = button.focused,
      active = button.active,
      hovered = mouseX and mouseY and not button.disabled and Button.containsPoint(button, mouseX, mouseY),
      pressed = pressed,
      disabled = button.disabled,
      align = button.align,
      font = button.font,
    })
  end

  for index = #pressEffects, 1, -1 do
    local effect = pressEffects[index]
    local age = now - effect.startedAt

    if age >= PRESS_EFFECT_DURATION then
      table.remove(pressEffects, index)
    else
      local progress = age / PRESS_EFFECT_DURATION
      local padding = math.floor(4 + (10 * progress))
      local alpha = 0.32 * (1 - progress)

      Theme.applyColor({ Theme.colors.highlight[1], Theme.colors.highlight[2], Theme.colors.highlight[3], alpha })
      love.graphics.setLineWidth(2)
      love.graphics.rectangle(
        "line",
        effect.x - padding,
        effect.y - padding,
        effect.width + (padding * 2),
        effect.height + (padding * 2),
        8,
        8
      )
      love.graphics.setLineWidth(1)
    end
  end
end

function Button.handleMousePressed(buttons, x, y)
  for _, button in ipairs(buttons or {}) do
    if not button.disabled and Button.containsPoint(button, x, y) then
      addPressEffect(button)

      if soundPlayer then
        soundPlayer(button.soundCue or "button_click")
      end

      if button.onClick then
        return true, button.onClick(button), button
      end

      return true, button.id or true, button
    end
  end

  return false
end

return Button
