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
    rim = { 0.88, 0.92, 0.96, 1.0 },
    face = { 0.58, 0.66, 0.74, 1.0 },
    dark = { 0.20, 0.25, 0.31, 1.0 },
    shine = { 1.00, 1.00, 1.00, 1.0 },
    glow = { 0.66, 0.84, 1.00, 1.0 },
  },
  rare = {
    rim = { 1.00, 0.88, 0.34, 1.0 },
    face = { 0.92, 0.64, 0.12, 1.0 },
    dark = { 0.40, 0.24, 0.04, 1.0 },
    shine = { 1.00, 0.98, 0.68, 1.0 },
    glow = { 1.00, 0.72, 0.12, 1.0 },
  },
}

local FACE_PATTERNS = {
  match_spark = {
    "0000001000000",
    "0000011100000",
    "0000111001000",
    "0011011011000",
    "0111111110000",
    "0001111100000",
    "0000111000000",
    "0001010100000",
    "0010010010000",
    "0000010000000",
    "0000101000000",
    "0001000100000",
    "0000000000000",
  },
  heads_hunter = {
    "0000011100000",
    "0000100010000",
    "0000101010000",
    "0000011100000",
    "0000000000000",
    "0011100011100",
    "0100010100010",
    "0101010101010",
    "0011100011100",
    "0001000100000",
    "0010000010000",
    "0100000001000",
    "0000000000000",
  },
  tails_chaser = {
    "0000001110000",
    "0000110001000",
    "0001000001000",
    "0010000110000",
    "0010001000000",
    "0010010000000",
    "0001100000000",
    "0000110000000",
    "0000011001000",
    "0000001110000",
    "0000000100000",
    "0000001000000",
    "0000000000000",
  },
  boss_biter = {
    "0101000101000",
    "1111101111100",
    "1010101010100",
    "1111111111110",
    "0111111111100",
    "0011011011000",
    "0001111110000",
    "0011111111000",
    "0110101011100",
    "1111111111110",
    "0100100100100",
    "1001001001000",
    "0000000000000",
  },
  heads_banker = {
    "0000011100000",
    "0000101010000",
    "0000100010000",
    "0000011100000",
    "0000000000000",
    "0001111110000",
    "0010000011000",
    "0010111011000",
    "0010101011000",
    "0010111011000",
    "0001111110000",
    "0000101000000",
    "0000000000000",
  },
  tails_banker = {
    "0000111100000",
    "0000011000000",
    "0000011000000",
    "0000011000000",
    "0000011000000",
    "0000000000000",
    "0001111110000",
    "0010000011000",
    "0010111011000",
    "0010101011000",
    "0010111011000",
    "0001111110000",
    "0000000000000",
  },
  safety_net = {
    "1000100010001",
    "0101000101010",
    "0010001000100",
    "0101000101010",
    "1000100010001",
    "0000000000000",
    "0011111111100",
    "0010000000100",
    "0010101010100",
    "0010010100100",
    "0010101010100",
    "0011111111100",
    "0000000000000",
  },
  parachute_pin = {
    "0000011100000",
    "0001111111000",
    "0011111111100",
    "0111011101110",
    "0101010101010",
    "0001010101000",
    "0001010101000",
    "0000111110000",
    "0000011100000",
    "0000011100000",
    "0000001000000",
    "0000011100000",
    "0000000000000",
  },
  tails_echo = {
    "0000111100000",
    "0000011000000",
    "0000011000000",
    "0000011000000",
    "0000011000000",
    "0000000000000",
    "0001110000000",
    "0010001000000",
    "0100110100000",
    "0101001010000",
    "0100110100000",
    "0010001000000",
    "0001110000000",
  },
  perfect_penny = {
    "0000001000000",
    "0000011100000",
    "0000111110000",
    "0011111111100",
    "0001111111000",
    "0000111110000",
    "0001111111000",
    "0011111111100",
    "0000111110000",
    "0000011100000",
    "0000001000000",
    "0000100010000",
    "0001000001000",
  },
  fresh_mint = {
    "0000001000000",
    "0000011100000",
    "0000111110000",
    "0001111111000",
    "0011111111100",
    "0000011100000",
    "0000011100000",
    "0000011100000",
    "0000111110000",
    "0001111111000",
    "0000001000000",
    "0000010100000",
    "0000100010000",
  },
  sun_stamp = {
    "1000010000100",
    "0100010001000",
    "0010010010000",
    "0001111110000",
    "0011111111000",
    "0001111110000",
    "1111111111111",
    "0001111110000",
    "0011111111000",
    "0001111110000",
    "0010010010000",
    "0100010001000",
    "1000010000100",
  },
  black_cat_cent = {
    "0010000000100",
    "0111000001110",
    "1111100011111",
    "1111111111111",
    "1101011101011",
    "1111111111111",
    "1110011100111",
    "1111001001111",
    "0111111111110",
    "0011111111100",
    "0001100011000",
    "0001000001000",
    "0000000000000",
  },
  flywheel = {
    "0000011100000",
    "0001100011000",
    "0010011100100",
    "0100101010010",
    "0101011101010",
    "1011100011101",
    "1010101010101",
    "1011100011101",
    "0101011101010",
    "0100101010010",
    "0010011100100",
    "0001100011000",
    "0000011100000",
  },
  vanishing = {
    "0000011100000",
    "0001111000000",
    "0011111100000",
    "0111111110000",
    "0111111011000",
    "1111110001000",
    "1111100000100",
    "1111110001000",
    "0111111011000",
    "0111111110000",
    "0011111100000",
    "0001111000000",
    "0000011100000",
  },
  heads = {
    "0000011100000",
    "0000100010000",
    "0000101010000",
    "0000100010000",
    "0000011100000",
    "0000010100000",
    "0000100010000",
    "0001000001000",
    "0000000000000",
    "0001111110000",
    "0000010000000",
    "0000010000000",
    "0001111110000",
  },
  tails = {
    "0001111110000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
    "0000010000000",
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

local function getFaceKey(definition)
  if definition and definition.art and definition.art.face then
    return definition.art.face
  end

  if hasTag(definition, "bent") then
    return "bent"
  end

  if hasTag(definition, "blank") then
    return "blank"
  end

  if hasTag(definition, "hollow") then
    return "hollow"
  end

  if hasTag(definition, "vanishing") or hasTag(definition, "palm") then
    return "vanishing"
  end

  if hasTag(definition, "marked") then
    return "marked"
  end

  if hasTag(definition, "fate") or hasTag(definition, "luck_meter") then
    return "lucky"
  end

  if hasTag(definition, "flywheel") or hasTag(definition, "momentum") then
    return "flywheel"
  end

  if hasTag(definition, "weighted") or hasTag(definition, "reliable") then
    return "weighted"
  end

  if hasTag(definition, "influence") or hasTag(definition, "payout") or hasTag(definition, "black_market") then
    return "lucky"
  end

  if hasTag(definition, "weight") then
    if hasTag(definition, "tails") then
      return "tails"
    end

    if hasTag(definition, "heads") then
      return "heads"
    end

    return "weighted"
  end

  if hasTag(definition, "boss") then
    return "boss_biter"
  end

  if hasTag(definition, "heads") then
    return "heads"
  end

  if hasTag(definition, "tails") then
    return "tails"
  end

  if hasTag(definition, "score") then
    return "match_spark"
  end

  return "blank"
end

local function getRimType(definition)
  if definition and definition.art and definition.art.rim then
    return definition.art.rim
  end

  if hasTag(definition, "boss") then
    return "boss"
  end

  if hasTag(definition, "hollow") or hasTag(definition, "neighbor") or hasTag(definition, "momentum") or hasTag(definition, "flywheel") or hasTag(definition, "sleight") or hasTag(definition, "vanishing") or hasTag(definition, "draw") or hasTag(definition, "reorder") or hasTag(definition, "flip") then
    return "motion"
  end

  if hasTag(definition, "weighted") or hasTag(definition, "weight") then
    return "weight"
  end

  if hasTag(definition, "bent") or hasTag(definition, "fate") or hasTag(definition, "perfect") or hasTag(definition, "score_scaling") then
    return "combo"
  end

  if hasTag(definition, "marked") or hasTag(definition, "safety") or hasTag(definition, "miss") or hasTag(definition, "counter") then
    return "safety"
  end

  if hasTag(definition, "influence") or hasTag(definition, "payout") or hasTag(definition, "black_market") then
    return "influence"
  end

  return "score"
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

local FACE_GRID_SIZE = 25

local function cell(ctx, x, y)
  if x < 0 or y < 0 or x >= FACE_GRID_SIZE or y >= FACE_GRID_SIZE then
    return
  end

  love.graphics.rectangle("fill", ctx.x + (x * ctx.cell), ctx.y + (y * ctx.cell), ctx.cell, ctx.cell)
end

local function block(ctx, x, y, width, height)
  for row = 0, height - 1 do
    for column = 0, width - 1 do
      cell(ctx, x + column, y + row)
    end
  end
end

local function line(ctx, x1, y1, x2, y2, width)
  local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1), 1)
  width = width or 1

  for index = 0, steps do
    local t = index / steps
    local x = math.floor(x1 + ((x2 - x1) * t) + 0.5)
    local y = math.floor(y1 + ((y2 - y1) * t) + 0.5)
    block(ctx, x - math.floor(width / 2), y - math.floor(width / 2), width, width)
  end
end

local function mask(ctx, rows, x, y)
  for rowIndex, row in ipairs(rows) do
    for columnIndex = 1, #row do
      if row:sub(columnIndex, columnIndex) == "1" then
        cell(ctx, x + columnIndex - 1, y + rowIndex - 1)
      end
    end
  end
end

local function head(ctx, x, y)
  mask(ctx, {
    "000111000",
    "001111100",
    "011000110",
    "110101011",
    "110000011",
    "110111011",
    "011000110",
    "001111100",
    "000111000",
    "000010000",
  }, x, y)
end

local function tail(ctx, x, y)
  mask(ctx, {
    "111111111",
    "111111111",
    "000111000",
    "000111000",
    "000111000",
    "000111000",
    "000111000",
    "000111000",
    "000111000",
    "000111000",
  }, x, y)
end

local function bag(ctx, x, y)
  mask(ctx, {
    "000010000",
    "000111000",
    "001111100",
    "011111110",
    "111101111",
    "111111111",
    "111101111",
    "011111110",
    "001111100",
    "000111000",
  }, x, y)
end

local function cache(ctx, x, y)
  mask(ctx, {
    "111111111",
    "100000001",
    "101111101",
    "101000101",
    "101010101",
    "101000101",
    "101111101",
    "100000001",
    "111111111",
  }, x, y)
end

local function spark(ctx, x, y)
  cell(ctx, x + 5, y)
  block(ctx, x + 4, y + 1, 3, 1)
  block(ctx, x + 3, y + 2, 5, 1)
  block(ctx, x + 1, y + 3, 9, 2)
  block(ctx, x, y + 5, 11, 1)
  block(ctx, x + 2, y + 6, 7, 1)
  block(ctx, x + 4, y + 7, 3, 1)
  cell(ctx, x + 5, y + 8)
  line(ctx, x + 5, y + 10, x + 5, y + 14, 2)
  line(ctx, x + 2, y + 12, x + 8, y + 12, 1)
end

local function anchor(ctx, x, y)
  line(ctx, x + 5, y, x + 5, y + 9, 2)
  block(ctx, x + 1, y + 4, 9, 2)
  line(ctx, x + 1, y + 9, x + 5, y + 12, 2)
  line(ctx, x + 9, y + 9, x + 5, y + 12, 2)
  block(ctx, x, y + 8, 2, 2)
  block(ctx, x + 9, y + 8, 2, 2)
end

local function arrow(ctx, x, y, direction)
  if direction == "left" then
    line(ctx, x + 10, y + 5, x + 2, y + 5, 3)
    line(ctx, x + 4, y + 1, x, y + 5, 2)
    line(ctx, x, y + 5, x + 4, y + 9, 2)
  elseif direction == "right" then
    line(ctx, x, y + 5, x + 8, y + 5, 3)
    line(ctx, x + 6, y + 1, x + 10, y + 5, 2)
    line(ctx, x + 10, y + 5, x + 6, y + 9, 2)
  else
    line(ctx, x + 5, y + 10, x + 5, y + 2, 3)
    line(ctx, x + 1, y + 4, x + 5, y, 2)
    line(ctx, x + 9, y + 4, x + 5, y, 2)
  end
end

local function star(ctx, x, y)
  mask(ctx, {
    "000010000",
    "000111000",
    "100111001",
    "111111111",
    "011111110",
    "001111100",
    "011101110",
    "110000011",
    "100000001",
  }, x, y)
end

local function net(ctx, x, y)
  for offset = 0, 10, 2 do
    line(ctx, x + offset, y, x, y + offset, 1)
    line(ctx, x + 10, y + offset, x + offset, y + 10, 1)
  end
  block(ctx, x, y, 11, 1)
  block(ctx, x, y + 10, 11, 1)
end

local function moon(ctx, x, y)
  mask(ctx, {
    "00011110",
    "00111100",
    "01110000",
    "11100000",
    "11100000",
    "11100000",
    "01110000",
    "00111100",
    "00011110",
  }, x, y)
end

local function cat(ctx, x, y)
  mask(ctx, {
    "100000001",
    "110000011",
    "111000111",
    "111111111",
    "101111101",
    "111111111",
    "111010111",
    "011111110",
    "001010100",
  }, x, y)
end

local function diamond(ctx, x, y)
  mask(ctx, {
    "000010000",
    "000111000",
    "001101100",
    "011000110",
    "110010011",
    "011000110",
    "001101100",
    "000111000",
    "000010000",
  }, x, y)
end

local function skull(ctx, x, y)
  mask(ctx, {
    "001111100",
    "011111110",
    "110111011",
    "111111111",
    "101111101",
    "111010111",
    "011111110",
    "001010100",
    "001010100",
  }, x, y)
end

local function chain(ctx, x, y)
  for index = 0, 2 do
    local linkX = x + (index * 4)
    block(ctx, linkX, y + 2, 4, 1)
    block(ctx, linkX, y + 6, 4, 1)
    block(ctx, linkX, y + 3, 1, 3)
    block(ctx, linkX + 3, y + 3, 1, 3)
  end
end

local FACE_DRAWERS = {
  bent = function(ctx)
    chain(ctx, 5, 5)
    line(ctx, 5, 15, 14, 12, 2)
    line(ctx, 14, 12, 16, 15, 2)
  end,
  blank = function(ctx)
    block(ctx, 5, 8, 11, 2)
    block(ctx, 7, 13, 7, 1)
  end,
  hollow = function(ctx)
    diamond(ctx, 7, 3)
    block(ctx, 9, 8, 3, 5)
    block(ctx, 8, 9, 5, 3)
  end,
  vanishing = function(ctx)
    moon(ctx, 4, 5)
    line(ctx, 12, 5, 17, 3, 1)
    line(ctx, 12, 10, 18, 10, 1)
    line(ctx, 12, 15, 17, 17, 1)
    cell(ctx, 18, 4)
    cell(ctx, 19, 10)
    cell(ctx, 18, 16)
  end,
  marked = function(ctx)
    line(ctx, 5, 5, 15, 15, 2)
    line(ctx, 15, 5, 5, 15, 2)
    block(ctx, 8, 8, 5, 5)
  end,
  lucky = function(ctx)
    star(ctx, 8, 3)
    line(ctx, 6, 14, 10, 17, 2)
    line(ctx, 10, 17, 15, 10, 2)
  end,
  weighted = function(ctx)
    block(ctx, 5, 5, 11, 2)
    block(ctx, 9, 7, 3, 8)
    block(ctx, 6, 15, 9, 2)
    line(ctx, 7, 9, 4, 13, 1)
    line(ctx, 13, 9, 16, 13, 1)
  end,
  match_spark = function(ctx) spark(ctx, 7, 3) end,
  heads_hunter = function(ctx)
    head(ctx, 8, 1)
    head(ctx, 3, 11)
    head(ctx, 13, 11)
    line(ctx, 10, 7, 5, 11, 1)
    line(ctx, 10, 7, 15, 11, 1)
  end,
  tails_chaser = function(ctx)
    tail(ctx, 8, 2)
    line(ctx, 4, 12, 8, 16, 2)
    line(ctx, 8, 16, 15, 15, 2)
    line(ctx, 15, 15, 17, 10, 2)
    cell(ctx, 16, 8)
    cell(ctx, 14, 7)
  end,
  boss_biter = function(ctx)
    block(ctx, 4, 4, 13, 2)
    block(ctx, 5, 15, 11, 2)
    for x = 5, 15, 3 do
      line(ctx, x, 6, x + 1, 10, 1)
      line(ctx, x + 1, 14, x, 10, 1)
    end
    block(ctx, 7, 9, 7, 2)
  end,
  heads_banker = function(ctx) head(ctx, 3, 3); bag(ctx, 12, 11) end,
  tails_banker = function(ctx) tail(ctx, 4, 3); bag(ctx, 12, 11) end,
  safety_net = function(ctx) net(ctx, 6, 5); block(ctx, 5, 15, 11, 2) end,
  parachute_pin = function(ctx)
    line(ctx, 5, 9, 10, 15, 1)
    line(ctx, 15, 9, 10, 15, 1)
    block(ctx, 6, 4, 9, 2)
    line(ctx, 6, 6, 4, 9, 1)
    line(ctx, 14, 6, 16, 9, 1)
    star(ctx, 8, 14)
  end,
  tails_echo = function(ctx) tail(ctx, 4, 3); line(ctx, 12, 7, 17, 12, 1); line(ctx, 11, 11, 17, 17, 1); line(ctx, 14, 5, 19, 10, 1) end,
  perfect_penny = function(ctx) star(ctx, 8, 4); line(ctx, 6, 13, 9, 16, 2); line(ctx, 9, 16, 16, 8, 2) end,
  fresh_mint = function(ctx) star(ctx, 8, 3); line(ctx, 10, 11, 10, 18, 2); line(ctx, 7, 14, 10, 11, 1); line(ctx, 13, 14, 10, 11, 1) end,
  right_hand_charm = function(ctx) head(ctx, 3, 5); line(ctx, 9, 10, 14, 10, 2); arrow(ctx, 13, 7, "right") end,
  edge_bet = function(ctx) star(ctx, 2, 5); star(ctx, 16, 5); line(ctx, 3, 15, 17, 15, 2) end,
  sun_stamp = function(ctx)
    line(ctx, 10, 2, 10, 18, 1)
    line(ctx, 2, 10, 18, 10, 1)
    line(ctx, 4, 4, 16, 16, 1)
    line(ctx, 16, 4, 4, 16, 1)
    block(ctx, 7, 7, 7, 7)
  end,
  black_cat_cent = function(ctx) cat(ctx, 7, 5); line(ctx, 6, 15, 3, 17, 1); line(ctx, 14, 15, 17, 17, 1) end,
  grave_taler = function(ctx) skull(ctx, 6, 3); chain(ctx, 5, 14) end,
  blood_oracle = function(ctx) skull(ctx, 6, 3); line(ctx, 10, 13, 6, 18, 2); line(ctx, 10, 13, 14, 18, 2) end,
  triple_crown = function(ctx) head(ctx, 1, 6); head(ctx, 8, 3); head(ctx, 15, 6) end,
  switchback_cent = function(ctx) head(ctx, 3, 4); tail(ctx, 8, 8); head(ctx, 13, 4) end,
  tails_triad = function(ctx) tail(ctx, 1, 6); tail(ctx, 8, 3); tail(ctx, 15, 6) end,
  turnabout_token = function(ctx) tail(ctx, 3, 4); head(ctx, 8, 8); tail(ctx, 13, 4) end,
  rising_run = function(ctx) head(ctx, 2, 4); head(ctx, 8, 4); tail(ctx, 14, 8) end,
  falling_run = function(ctx) tail(ctx, 2, 8); tail(ctx, 8, 8); head(ctx, 14, 4) end,
  heads_tail_gate = function(ctx) head(ctx, 2, 4); tail(ctx, 8, 8); tail(ctx, 14, 8) end,
  tails_head_gate = function(ctx) tail(ctx, 2, 8); head(ctx, 8, 4); head(ctx, 14, 4) end,
  edge_echo = function(ctx) star(ctx, 2, 6); line(ctx, 6, 10, 14, 10, 1); star(ctx, 12, 6) end,
  heads = function(ctx) head(ctx, 8, 4) end,
  tails = function(ctx) tail(ctx, 8, 4) end,
}

local function drawFace(faceKey, pattern, x, y, size, scale, palette, alpha)
  local drawer = FACE_DRAWERS[faceKey]

  if drawer then
    local pixelSize = math.max(1, math.floor(size / FACE_GRID_SIZE))
    local faceSize = FACE_GRID_SIZE * pixelSize
    local faceX = math.floor(x + ((size - faceSize) / 2))
    local faceY = math.floor(y + ((size - faceSize) / 2) + (scale * 0.5))

    local shadowOffset = math.max(1, math.floor(pixelSize / 3))

    apply(palette.dark, 0.50 * alpha)
    drawer({ x = faceX + shadowOffset, y = faceY + shadowOffset, cell = pixelSize })
    apply(palette.shine, 0.98 * alpha)
    drawer({ x = faceX, y = faceY, cell = pixelSize })
    return
  end

  local symbolPixel = math.max(1, math.floor(size / 17))
  local patternWidth = #pattern[1] * symbolPixel
  local patternHeight = #pattern * symbolPixel

  drawPattern(
    pattern,
    math.floor(x + ((size - patternWidth) / 2)),
    math.floor(y + ((size - patternHeight) / 2) + (scale * 0.5)),
    symbolPixel,
    palette.shine
  )
end

local function drawRimMark(x, y, width, height, color, alpha)
  apply(color, alpha)
  love.graphics.rectangle("fill", x, y, width, height)
end

local function drawRimMarks(rimType, x, y, size, scale, palette, alpha)
  local color = palette.shine
  local softAlpha = 0.82 * alpha

  if rimType == "influence" then
    for index = 0, 3 do
      local markX = x + ((index * 4 + 2) * scale)
      drawRimMark(markX, y + (2 * scale), 2 * scale, 2 * scale, color, softAlpha)
      drawRimMark(markX, y + (12 * scale), 2 * scale, 2 * scale, color, softAlpha)
    end
    drawRimMark(x + (2 * scale), y + (6 * scale), 2 * scale, 2 * scale, color, softAlpha)
    drawRimMark(x + (12 * scale), y + (6 * scale), 2 * scale, 2 * scale, color, softAlpha)
  elseif rimType == "weight" then
    drawRimMark(x + (3 * scale), y + (13 * scale), 10 * scale, scale, color, softAlpha)
    drawRimMark(x + (2 * scale), y + (11 * scale), 3 * scale, 2 * scale, color, softAlpha)
    drawRimMark(x + (11 * scale), y + (11 * scale), 3 * scale, 2 * scale, color, softAlpha)
    drawRimMark(x + (1 * scale), y + (7 * scale), 2 * scale, 3 * scale, color, softAlpha)
    drawRimMark(x + (13 * scale), y + (7 * scale), 2 * scale, 3 * scale, color, softAlpha)
  elseif rimType == "combo" then
    for index = 0, 2 do
      drawRimMark(x + ((3 + index * 3) * scale), y + (2 * scale), 2 * scale, scale, color, softAlpha)
      drawRimMark(x + ((4 + index * 3) * scale), y + (3 * scale), scale, 2 * scale, color, softAlpha)
      drawRimMark(x + ((3 + index * 3) * scale), y + (13 * scale), 2 * scale, scale, color, softAlpha)
      drawRimMark(x + ((4 + index * 3) * scale), y + (11 * scale), scale, 2 * scale, color, softAlpha)
    end
  elseif rimType == "safety" then
    for index = 0, 4 do
      drawRimMark(x + ((2 + index * 3) * scale), y + ((3 + index % 2) * scale), scale, 3 * scale, color, softAlpha)
      drawRimMark(x + ((2 + index * 3) * scale), y + ((10 - index % 2) * scale), scale, 3 * scale, color, softAlpha)
    end
    drawRimMark(x + (2 * scale), y + (5 * scale), 12 * scale, scale, color, softAlpha * 0.85)
    drawRimMark(x + (2 * scale), y + (10 * scale), 12 * scale, scale, color, softAlpha * 0.85)
  elseif rimType == "motion" then
    drawRimMark(x + (2 * scale), y + (4 * scale), 4 * scale, scale, color, softAlpha)
    drawRimMark(x + (2 * scale), y + (11 * scale), 4 * scale, scale, color, softAlpha)
    drawRimMark(x + (10 * scale), y + (4 * scale), 4 * scale, scale, color, softAlpha)
    drawRimMark(x + (10 * scale), y + (11 * scale), 4 * scale, scale, color, softAlpha)
    drawRimMark(x + (5 * scale), y + (3 * scale), scale, scale, color, softAlpha)
    drawRimMark(x + (10 * scale), y + (12 * scale), scale, scale, color, softAlpha)
  elseif rimType == "boss" then
    for index = 0, 3 do
      drawRimMark(x + ((3 + index * 3) * scale), y + (2 * scale), scale, 3 * scale, color, softAlpha)
      drawRimMark(x + ((4 + index * 3) * scale), y + (11 * scale), scale, 3 * scale, color, softAlpha)
    end
    drawRimMark(x + (2 * scale), y + (7 * scale), 2 * scale, scale, color, softAlpha)
    drawRimMark(x + (12 * scale), y + (8 * scale), 2 * scale, scale, color, softAlpha)
  else
    drawRimMark(x + (2 * scale), y + (5 * scale), 2 * scale, scale, color, softAlpha)
    drawRimMark(x + (12 * scale), y + (10 * scale), 2 * scale, scale, color, softAlpha)
    drawRimMark(x + (7 * scale), y + (1 * scale), 2 * scale, scale, color, softAlpha)
    drawRimMark(x + (7 * scale), y + (14 * scale), 2 * scale, scale, color, softAlpha)
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
  local faceKey = getFaceKey(definition)
  local pattern = FACE_PATTERNS[faceKey] or FACE_PATTERNS.blank
  local rimType = getRimType(definition)
  local alpha = options.alpha or 1.0

  x = math.floor(x)
  y = math.floor(y)

  local tilt = options.tilt or 0
  local scaleX = options.scaleX or 1
  local scaleY = options.scaleY or 1
  local transformed = tilt ~= 0 or scaleX ~= 1 or scaleY ~= 1

  if transformed then
    love.graphics.push()
    love.graphics.translate(x + (size / 2), y + (size / 2))
    love.graphics.rotate(tilt)
    love.graphics.scale(scaleX, scaleY)
    love.graphics.translate(-(x + (size / 2)), -(y + (size / 2)))
  end

  if options.glow == true then
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

  if options.shadow == true then
    apply(Theme.colors.shadow, 0.24 * alpha)
    love.graphics.rectangle("fill", x, y + (2 * scale), size, size, 6, 6)
  end

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

  drawRimMarks(rimType, x, y, size, scale, palette, alpha)

  drawFace(faceKey, pattern, x, y, size, scale, palette, alpha)

  if options.selected then
    apply(palette.glow or Theme.colors.accent, 0.90)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x + (size / 2), y + (size / 2), (size / 2) + 3)
    love.graphics.setLineWidth(1)
  end

  if transformed then
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
  })
end

return CoinArt
