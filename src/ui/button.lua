local Theme = require("src.ui.theme")

local Button = {}

local soundPlayer = nil
local defaultFont = nil
local pressEffects = {}
local PRESS_EFFECT_DURATION = 0.18

local VARIANT_COLORS = {
  default = {
    fill = Theme.colors.panel,
    border = Theme.colors.panelBorder,
  },
  primary = {
    fill = Theme.colors.accent,
    border = Theme.colors.highlight,
  },
  success = {
    fill = Theme.colors.success,
    border = Theme.colors.accent,
  },
  danger = {
    fill = Theme.colors.danger,
    border = Theme.colors.warning,
  },
  warning = {
    fill = Theme.colors.warning,
    border = Theme.colors.highlight,
  },
  accent = {
    fill = Theme.colors.accent,
    border = Theme.colors.highlight,
  },
}

local function resolveButtonColors(options)
  local variant = VARIANT_COLORS[options.variant or "default"] or VARIANT_COLORS.default

  if options.disabled then
    return Theme.colors.panel, Theme.colors.panelBorder, Theme.colors.mutedText
  end

  if options.focused or options.hovered then
    return variant.fill, variant.border, Theme.colors.text
  end

  return Theme.colors.panel, variant.border, Theme.colors.text
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
  local textY = y + math.floor((height - font:getHeight()) / 2)

  Theme.applyColor(fill)
  love.graphics.rectangle("fill", x + 3, y + 3, width, height)
  Theme.applyColor(fill)
  love.graphics.rectangle("fill", x, y, width, height)
  Theme.applyColor(border)
  love.graphics.rectangle("line", x, y, width, height)

  Theme.applyColor(textColor)
  love.graphics.printf(label, x + 6, textY, width - 12, options.align or "center")

  if buttonFont and buttonFont ~= previousFont then
    love.graphics.setFont(previousFont)
  end
end

function Button.drawButtons(buttons, mouseX, mouseY)
  local now = getTime()

  for _, button in ipairs(buttons or {}) do
    local pressOffset = buttonIsPressed(button, now) and 2 or 0

    Button.drawTextButton(button.x, button.y + pressOffset, button.width, button.height, button.label, {
      focused = button.focused,
      hovered = mouseX and mouseY and not button.disabled and Button.containsPoint(button, mouseX, mouseY),
      disabled = button.disabled,
      variant = button.variant,
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
