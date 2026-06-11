local Theme = require("src.ui.theme")
local Box = require("src.ui.box")

local Panel = {}

function Panel.getContentArea(x, y, width, height, title)
  local edge = math.max(1, Theme.scale(2))

  return Box.contentRect(x, y, width, height, {
    border = edge,
    padding = Theme.spacing.panelPadding,
  })
end

function Panel.draw(x, y, width, height, title)
  Box.drawFrame(x, y, width, height)
end

return Panel
