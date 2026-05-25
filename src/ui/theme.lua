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
    compact = { title = 30, heading = 20, body = 15, small = 12, outcomeBurst = 112 },
    standard = { title = 38, heading = 25, body = 19, small = 15, outcomeBurst = 140 },
    large = { title = 45, heading = 30, body = 23, small = 18, outcomeBurst = 168 },
    max = { title = 60, heading = 40, body = 30, small = 24, outcomeBurst = 224 },
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
    compact = { screenPadding = 28, blockGap = 20, itemGap = 12, lineHeight = 24, panelPadding = 18, panelTitleHeight = 28, statusPadding = 16 },
    standard = { screenPadding = 35, blockGap = 25, itemGap = 15, lineHeight = 30, panelPadding = 23, panelTitleHeight = 35, statusPadding = 20 },
    large = { screenPadding = 42, blockGap = 30, itemGap = 18, lineHeight = 36, panelPadding = 27, panelTitleHeight = 42, statusPadding = 24 },
    max = { screenPadding = 56, blockGap = 40, itemGap = 24, lineHeight = 48, panelPadding = 36, panelTitleHeight = 56, statusPadding = 32 },
  },

  componentMetricTiers = {
    compact = { buttonHeight = 42, cardMinWidth = 82, cardMaxWidth = 190 },
    standard = { buttonHeight = 53, cardMinWidth = 103, cardMaxWidth = 238 },
    large = { buttonHeight = 63, cardMinWidth = 123, cardMaxWidth = 285 },
    max = { buttonHeight = 84, cardMinWidth = 164, cardMaxWidth = 380 },
  },

  componentMetrics = {
    buttonHeight = 42,
    cardMinWidth = 82,
    cardMaxWidth = 190,
  },

  uiScale = 1,
}

function Theme.applyViewportMetrics(metrics)
  local tier = metrics and metrics.tier or "standard"
  Theme.fontSizes = Theme.fontSizeTiers[tier]
  Theme.spacing = Theme.spacingTiers[tier]
  Theme.componentMetrics = Theme.componentMetricTiers[tier]
  Theme.uiScale = metrics and metrics.scale or 1
end

function Theme.scale(value)
  return math.floor((value or 0) * (Theme.uiScale or 1) + 0.5)
end

function Theme.applyColor(color)
  love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
end

function Theme.clearColor(color)
  love.graphics.clear(color[1], color[2], color[3], color[4] or 1.0)
end

return Theme
