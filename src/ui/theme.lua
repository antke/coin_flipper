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
    outcomeBurst = 112,
  },

  fontSizeTiers = {
    compact = { title = 26, heading = 18, body = 14, small = 11, outcomeBurst = 88 },
    standard = { title = 30, heading = 20, body = 15, small = 12, outcomeBurst = 112 },
    large = { title = 34, heading = 22, body = 16, small = 13, outcomeBurst = 124 },
    max = { title = 38, heading = 24, body = 18, small = 14, outcomeBurst = 136 },
  },

  fontPaths = {
    outcomeBurst = nil,
  },

  outcomeBurst = {
    duration = 1.05,
    flashInDuration = 0.12,
    fadeOutDuration = 0.32,
    popScale = 1.28,
    labels = {
      [0] = "OUCH",
      [2] = "NICE",
      [3] = "SUPER",
      [4] = "JACKPOT",
      [5] = "LEGENDARY",
      default = "LEGENDARY",
      clutch = "CLUTCH",
      combo = "COMBO",
      jackpot = "JACKPOT",
      overkill = "OVERKILL",
    },
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

  spacingTiers = {
    compact = { screenPadding = 20, blockGap = 16, itemGap = 10, lineHeight = 22, panelPadding = 14, panelTitleHeight = 24, statusPadding = 12 },
    standard = { screenPadding = 28, blockGap = 20, itemGap = 12, lineHeight = 24, panelPadding = 18, panelTitleHeight = 28, statusPadding = 16 },
    large = { screenPadding = 32, blockGap = 22, itemGap = 14, lineHeight = 26, panelPadding = 20, panelTitleHeight = 30, statusPadding = 18 },
    max = { screenPadding = 36, blockGap = 24, itemGap = 16, lineHeight = 28, panelPadding = 22, panelTitleHeight = 32, statusPadding = 20 },
  },

  componentMetricTiers = {
    compact = { buttonHeight = 42, cardMinWidth = 76, cardMaxWidth = 170 },
    standard = { buttonHeight = 42, cardMinWidth = 82, cardMaxWidth = 190 },
    large = { buttonHeight = 48, cardMinWidth = 90, cardMaxWidth = 205 },
    max = { buttonHeight = 54, cardMinWidth = 96, cardMaxWidth = 220 },
  },
}

function Theme.applyViewportMetrics(metrics)
  local tier = metrics and metrics.tier or "standard"
  Theme.fontSizes = Theme.fontSizeTiers[tier]
  Theme.spacing = Theme.spacingTiers[tier]
end

function Theme.applyColor(color)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
end

function Theme.clearColor(color)
  love.graphics.clear(color[1], color[2], color[3], color[4] or 1.0)
end

return Theme
