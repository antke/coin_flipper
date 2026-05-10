local Theme = require("src.ui.theme")

local Button = {}

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

function Button.containsPoint(button, x, y)
  return x >= button.x and x <= (button.x + button.width) and y >= button.y and y <= (button.y + button.height)
end

function Button.drawTextButton(x, y, width, height, label, options)
  if type(options) == "boolean" then
    options = { focused = options }
  end

  options = options or {}
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
end

function Button.drawButtons(buttons, mouseX, mouseY)
  for _, button in ipairs(buttons or {}) do
    Button.drawTextButton(button.x, button.y, button.width, button.height, button.label, {
      focused = button.focused,
      hovered = mouseX and mouseY and not button.disabled and Button.containsPoint(button, mouseX, mouseY),
      disabled = button.disabled,
      variant = button.variant,
      align = button.align,
    })
  end
end

function Button.handleMousePressed(buttons, x, y)
  for _, button in ipairs(buttons or {}) do
    if not button.disabled and Button.containsPoint(button, x, y) then
      if button.onClick then
        return true, button.onClick(button), button
      end

      return true, button.id or true, button
    end
  end

  return false
end

return Button
