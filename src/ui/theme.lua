local Theme = {
  colors = {
    background = { 0.08, 0.09, 0.12, 1.0 },
    panel = { 0.14, 0.16, 0.21, 0.95 },
    panelBorder = { 0.30, 0.34, 0.42, 1.0 },
    text = { 0.94, 0.96, 0.98, 1.0 },
    mutedText = { 0.72, 0.76, 0.84, 1.0 },
    accent = { 0.39, 0.72, 0.96, 1.0 },
    success = { 0.43, 0.83, 0.51, 1.0 },
    danger = { 0.92, 0.39, 0.39, 1.0 },
    warning = { 0.96, 0.79, 0.35, 1.0 },
    highlight = { 0.66, 0.49, 0.96, 1.0 },
    shadow = { 0.0, 0.0, 0.0, 0.18 },
  },

  fontSizes = {
    title = 30,
    heading = 20,
    body = 15,
    small = 12,
  },

  spacing = {
    screenPadding = 28,
    blockGap = 20,
    itemGap = 12,
    lineHeight = 24,
    panelPadding = 18,
    panelTitleHeight = 28,
    statusPadding = 16,
  },
}

function Theme.applyColor(color)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
end

function Theme.clearColor(color)
  love.graphics.clear(color[1], color[2], color[3], color[4] or 1.0)
end

return Theme
