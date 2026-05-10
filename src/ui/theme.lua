local Theme = {
  colors = {
    background = { 0.05, 0.06, 0.09, 1.0 },
    panel = { 0.10, 0.12, 0.18, 0.92 },
    panelBorder = { 0.23, 0.27, 0.38, 1.0 },
    text = { 0.96, 0.91, 0.76, 1.0 },
    mutedText = { 0.63, 0.70, 0.77, 1.0 },
    accent = { 0.22, 0.74, 0.86, 1.0 },
    success = { 0.35, 0.82, 0.38, 1.0 },
    danger = { 0.88, 0.27, 0.31, 1.0 },
    warning = { 0.94, 0.73, 0.25, 1.0 },
    highlight = { 0.80, 0.42, 0.98, 1.0 },
    shadow = { 0.0, 0.0, 0.0, 0.24 },
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
