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
  love.graphics.rectangle("fill", x + 4, y + 4, width, height)

  Theme.applyColor(Theme.colors.panel)
  love.graphics.rectangle("fill", x, y, width, height)

  if title then
    Theme.applyColor(Theme.colors.accent)
    love.graphics.print(title, x + Theme.spacing.panelPadding, y + Theme.spacing.panelPadding)
  end
end

return Panel
