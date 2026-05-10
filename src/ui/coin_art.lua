local Coins = require("src.content.coins")
local Theme = require("src.ui.theme")

local CoinArt = {}

local RARITY_PALETTES = {
  common = {
    rim = { 0.96, 0.70, 0.25, 1.0 },
    face = { 0.80, 0.47, 0.15, 1.0 },
    dark = { 0.38, 0.20, 0.08, 1.0 },
    shine = { 1.00, 0.92, 0.52, 1.0 },
    glow = { 1.00, 0.50, 0.16, 1.0 },
  },
  uncommon = {
    rim = { 0.56, 0.88, 0.68, 1.0 },
    face = { 0.22, 0.62, 0.42, 1.0 },
    dark = { 0.08, 0.26, 0.18, 1.0 },
    shine = { 0.78, 1.00, 0.82, 1.0 },
    glow = { 0.16, 1.00, 0.62, 1.0 },
  },
  rare = {
    rim = { 0.78, 0.62, 1.00, 1.0 },
    face = { 0.42, 0.24, 0.78, 1.0 },
    dark = { 0.18, 0.10, 0.34, 1.0 },
    shine = { 0.94, 0.84, 1.00, 1.0 },
    glow = { 0.82, 0.28, 1.00, 1.0 },
  },
}

local SYMBOL_PATTERNS = {
  heads = {
    "1001",
    "1111",
    "1001",
    "1001",
    "1001",
  },
  tails = {
    "1111",
    "0110",
    "0110",
    "0110",
    "0110",
  },
  economy = {
    "0110",
    "1000",
    "0110",
    "0001",
    "1110",
  },
  weight = {
    "0110",
    "1111",
    "1111",
    "0110",
    "0110",
  },
  streak = {
    "1000",
    "1100",
    "1110",
    "0111",
    "0011",
  },
  boss = {
    "1001",
    "1111",
    "0110",
    "1111",
    "1001",
  },
  score = {
    "0110",
    "1111",
    "1111",
    "0110",
    "0110",
  },
  default = {
    "0110",
    "1001",
    "1001",
    "1001",
    "0110",
  },
}

local function apply(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1.0)
end

local function hasTag(definition, tag)
  for _, value in ipairs(definition and definition.tags or {}) do
    if value == tag then
      return true
    end
  end

  return false
end

local function resolveDefinition(coinOrId)
  if type(coinOrId) == "table" then
    return coinOrId
  end

  return Coins.getById(coinOrId)
end

local function getSymbolKey(definition, side)
  if side == "heads" or side == "tails" then
    return side
  end

  if hasTag(definition, "economy") or hasTag(definition, "shop") then
    return "economy"
  end

  if hasTag(definition, "weight") then
    return "weight"
  end

  if hasTag(definition, "streak") then
    return "streak"
  end

  if hasTag(definition, "boss") then
    return "boss"
  end

  if hasTag(definition, "heads") then
    return "heads"
  end

  if hasTag(definition, "tails") then
    return "tails"
  end

  if hasTag(definition, "score") then
    return "score"
  end

  return "default"
end

local function drawPattern(pattern, x, y, pixelSize, color)
  apply(color)

  for rowIndex, row in ipairs(pattern) do
    for columnIndex = 1, #row do
      if row:sub(columnIndex, columnIndex) == "1" then
        love.graphics.rectangle(
          "fill",
          x + ((columnIndex - 1) * pixelSize),
          y + ((rowIndex - 1) * pixelSize),
          pixelSize,
          pixelSize
        )
      end
    end
  end
end

function CoinArt.getPalette(definition)
  definition = resolveDefinition(definition)
  return RARITY_PALETTES[(definition and definition.rarity) or "common"] or RARITY_PALETTES.common
end

function CoinArt.draw(coinOrId, x, y, size, options)
  options = options or {}
  local definition = resolveDefinition(coinOrId)
  local palette = CoinArt.getPalette(definition)
  local scale = size / 16
  local symbolKey = getSymbolKey(definition, options.side)
  local pattern = SYMBOL_PATTERNS[symbolKey] or SYMBOL_PATTERNS.default
  local alpha = options.alpha or 1.0
  local tilt = options.tilt or 0

  x = math.floor(x)
  y = math.floor(y)

  if tilt ~= 0 then
    love.graphics.push()
    love.graphics.translate(x + (size / 2), y + (size / 2))
    love.graphics.rotate(tilt)
    love.graphics.translate(-(x + (size / 2)), -(y + (size / 2)))
  end

  if options.glow ~= false then
    for index = 1, 3 do
      apply(palette.glow or palette.rim, (0.10 / index) * alpha)
      love.graphics.rectangle(
        "fill",
        x - (index * scale),
        y - (index * scale),
        size + (index * scale * 2),
        size + (index * scale * 2),
        8,
        8
      )
    end
  end

  apply(Theme.colors.shadow, 0.28 * alpha)
  love.graphics.rectangle("fill", x + (2 * scale), y + (3 * scale), size, size, 6, 6)

  local rows = {
    { 5, 6 },
    { 3, 10 },
    { 2, 12 },
    { 1, 14 },
    { 1, 14 },
    { 0, 16 },
    { 0, 16 },
    { 0, 16 },
    { 0, 16 },
    { 0, 16 },
    { 0, 16 },
    { 1, 14 },
    { 1, 14 },
    { 2, 12 },
    { 3, 10 },
    { 5, 6 },
  }

  for rowIndex, row in ipairs(rows) do
    apply(palette.dark, alpha)
    love.graphics.rectangle("fill", x + (row[1] * scale), y + ((rowIndex - 1) * scale), row[2] * scale, scale)
  end

  for rowIndex = 2, 15 do
    local row = rows[rowIndex]
    apply(palette.rim, alpha)
    love.graphics.rectangle("fill", x + ((row[1] + 1) * scale), y + ((rowIndex - 1) * scale), math.max(0, row[2] - 2) * scale, scale)
  end

  for rowIndex = 4, 13 do
    local row = rows[rowIndex]
    apply(palette.face, alpha)
    love.graphics.rectangle("fill", x + ((row[1] + 3) * scale), y + ((rowIndex - 1) * scale), math.max(0, row[2] - 6) * scale, scale)
  end

  apply(palette.shine, 0.92 * alpha)
  love.graphics.rectangle("fill", x + (5 * scale), y + (3 * scale), 5 * scale, scale)
  love.graphics.rectangle("fill", x + (4 * scale), y + (4 * scale), 2 * scale, scale)
  love.graphics.rectangle("fill", x + (3 * scale), y + (6 * scale), scale, 3 * scale)

  apply(palette.dark, 0.34 * alpha)
  for rowIndex = 7, 12, 2 do
    love.graphics.rectangle("fill", x + (3 * scale), y + (rowIndex * scale), 10 * scale, math.max(1, scale * 0.35))
  end

  apply(palette.rim, 0.95 * alpha)
  love.graphics.rectangle("fill", x + (2 * scale), y + (5 * scale), 2 * scale, scale)
  love.graphics.rectangle("fill", x + (12 * scale), y + (10 * scale), 2 * scale, scale)
  love.graphics.rectangle("fill", x + (7 * scale), y + (1 * scale), 2 * scale, scale)
  love.graphics.rectangle("fill", x + (7 * scale), y + (14 * scale), 2 * scale, scale)

  local symbolPixel = math.max(1, math.floor(size / 22))
  local patternWidth = #pattern[1] * symbolPixel
  local patternHeight = #pattern * symbolPixel
  drawPattern(
    pattern,
    math.floor(x + ((size - patternWidth) / 2)),
    math.floor(y + ((size - patternHeight) / 2) + (scale * 0.5)),
    symbolPixel,
    palette.shine
  )

  if options.selected then
    apply(palette.glow or Theme.colors.accent, 0.90)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x - 3, y - 3, size + 6, size + 6, 6, 6)
    love.graphics.setLineWidth(1)
  end

  if tilt ~= 0 then
    love.graphics.pop()
  end
end

function CoinArt.drawMini(coinOrId, x, y, size, options)
  CoinArt.draw(coinOrId, x, y, size or 28, options)
end

function CoinArt.drawCard(coinOrId, x, y, width, height, options)
  options = options or {}
  local definition = resolveDefinition(coinOrId)
  local palette = CoinArt.getPalette(definition)
  local tilt = options.tilt or 0

  if tilt ~= 0 then
    love.graphics.push()
    love.graphics.translate(x + (width / 2), y + (height / 2))
    love.graphics.rotate(tilt)
    love.graphics.translate(-(x + (width / 2)), -(y + (height / 2)))
  end

  apply(Theme.colors.shadow, 0.34)
  love.graphics.rectangle("fill", x + 5, y + 7, width, height, 12, 12)
  love.graphics.setColor(0.08, 0.09, 0.13, 0.96)
  love.graphics.rectangle("fill", x, y, width, height, 12, 12)
  apply(palette.glow or palette.rim, options.selected and 0.42 or 0.22)
  love.graphics.rectangle("fill", x + 4, y + 4, width - 8, height - 8, 9, 9)
  love.graphics.setColor(0.12, 0.13, 0.18, 0.98)
  love.graphics.rectangle("fill", x + 8, y + 8, width - 16, height - 16, 8, 8)
  apply(palette.rim, options.selected and 1.0 or 0.82)
  love.graphics.setLineWidth(options.selected and 3 or 2)
  love.graphics.rectangle("line", x, y, width, height, 12, 12)
  love.graphics.setLineWidth(1)

  local coinSize = math.min(width - 22, height - 30)
  CoinArt.draw(definition, x + math.floor((width - coinSize) / 2), y + 14, coinSize, {
    side = options.side,
    selected = options.selected,
    glow = true,
    tilt = -tilt,
  })

  if tilt ~= 0 then
    love.graphics.pop()
  end
end

return CoinArt
