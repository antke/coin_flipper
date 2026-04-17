local Theme = require("src.ui.theme")

local Panel = {}

function Panel.getContentArea(x, y, width, height, title)
  local padding = Theme.spacing.panelPadding
  local titleOffset = title and Theme.spacing.panelTitleHeight or 0

  return {
    x = x + padding,
    y = y + padding + titleOffset,
    width = width - (padding * 2),
    height = height - (padding * 2) - titleOffset,
  }
end

function Panel.draw(x, y, width, height, title)
  Theme.applyColor(Theme.colors.shadow)
  love.graphics.rectangle("fill", x + 4, y + 4, width, height, 10, 10)

  Theme.applyColor(Theme.colors.panel)
  love.graphics.rectangle("fill", x, y, width, height, 10, 10)

  Theme.applyColor(Theme.colors.panelBorder)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, width, height, 10, 10)

  if title then
    Theme.applyColor(Theme.colors.accent)
    love.graphics.print(title, x + Theme.spacing.panelPadding, y + Theme.spacing.panelPadding)

    Theme.applyColor(Theme.colors.panelBorder)
    love.graphics.line(
      x + Theme.spacing.panelPadding,
      y + Theme.spacing.panelPadding + Theme.spacing.panelTitleHeight - 6,
      x + width - Theme.spacing.panelPadding,
      y + Theme.spacing.panelPadding + Theme.spacing.panelTitleHeight - 6
    )
  end
end

return Panel
