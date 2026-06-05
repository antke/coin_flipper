local CoinArt = require("src.ui.coin_art")
local CoinDetailContent = require("src.content.coin_detail_content")
local CoinDetailOverlay = require("src.ui.coin_detail_overlay")
local Coins = require("src.content.coins")
local Theme = require("src.ui.theme")

local PurseView = {}

local POUCH_COIN_JITTER_X = 0.105
local POUCH_COIN_JITTER_Y = 0.135

local RARITY_COLORS = {
  common = Theme.colors.mutedText,
  uncommon = Theme.colors.accent,
  rare = Theme.colors.highlight,
}

local TYPE_TAG_COLORS = {
  attunement = Theme.colors.highlight,
  basic = Theme.colors.mutedText,
  combo = Theme.colors.highlight,
  economy = Theme.colors.warning,
  heads = { 0.94, 0.46, 0.25, 1.0 },
  motion = Theme.colors.accent,
  neighbor = Theme.colors.accent,
  odds = Theme.colors.success,
  perfect = Theme.colors.highlight,
  safety = Theme.colors.success,
  tails = { 0.45, 0.62, 1.0, 1.0 },
}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function containsPoint(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height
end

local function getStableSignedValue(key, salt)
  local source = tostring(key or "") .. ":" .. tostring(salt or "")
  local hash = 5381

  for index = 1, #source do
    hash = ((hash * 33) + string.byte(source, index)) % 1000003
  end

  return ((hash % 2001) / 1000) - 1
end

local function getPillColor(pill)
  if pill.kind == "rarity" then
    return RARITY_COLORS[pill.value] or Theme.colors.mutedText
  end

  return TYPE_TAG_COLORS[pill.value] or Theme.colors.mutedText
end

local function getGridMetrics(app, area, cardCount, options)
  local gap = Theme.spacing.itemGap
  local headerHeight = Theme.scale(34)
  local gridY = area.y + headerHeight
  local gridHeight = math.max(0, area.height - headerHeight)
  local minCellWidth = options.minCellWidth or Theme.scale(188)
  local columnCount = math.max(1, math.floor((area.width + gap) / (minCellWidth + gap)))
  local cellWidth = math.floor((area.width - (gap * (columnCount - 1))) / columnCount)
  local cellSize = math.min(options.cellSize or Theme.scale(145), math.max(Theme.scale(82), cellWidth))
  local titleHeight = app.fonts.body:getHeight() + Theme.scale(4)
  local pillRowsHeight = (app.fonts.small:getHeight() + Theme.scale(8)) * 2 + Theme.scale(4)
  local countHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local zonesHeight = options.showZones and (app.fonts.small:getHeight() + Theme.scale(4)) or 0
  local cellHeight = cellSize + Theme.scale(8) + titleHeight + Theme.scale(6) + pillRowsHeight + countHeight + zonesHeight
  local visibleRows = math.max(1, math.floor((gridHeight + gap) / (cellHeight + gap)))
  local rowCount = math.max(1, math.ceil(cardCount / columnCount))

  return {
    gap = gap,
    gridY = gridY,
    gridHeight = gridHeight,
    cellWidth = cellWidth,
    cellHeight = cellHeight,
    cellSize = cellSize,
    columnCount = columnCount,
    rowCount = rowCount,
    visibleRows = visibleRows,
    maxScrollOffset = math.max(0, rowCount - visibleRows),
  }
end

function PurseView.getMaxScrollOffset(app, area, stageState, options)
  options = options or {}
  local cards = app:getPurseCardData(stageState)
  if options.showZones == nil then
    options.showZones = stageState ~= nil
  end
  local metrics = getGridMetrics(app, area, #cards, options)
  return metrics.maxScrollOffset
end

local function drawPills(app, card, x, y, width)
  local coin = Coins.getById(card.coinId)
  local detail = CoinDetailContent.build(coin)
  local pills = detail and detail.pills or {}
  local font = app.fonts.small
  local pillHeight = font:getHeight() + Theme.scale(8)
  local rowGap = Theme.scale(4)
  local columnGap = Theme.scale(6)
  local cursorX = x
  local cursorY = y
  local row = 1

  love.graphics.setFont(font)

  for _, pill in ipairs(pills) do
    local label = tostring(pill.label or "")
    local pillWidth = math.min(width, math.max(Theme.scale(54), font:getWidth(label) + Theme.scale(16)))

    if cursorX > x and cursorX + pillWidth > x + width then
      row = row + 1
      if row > 2 then
        return
      end

      cursorX = x
      cursorY = cursorY + pillHeight + rowGap
    end

    local color = getPillColor(pill)
    setColorWithAlpha(color, 0.16)
    love.graphics.rectangle("fill", cursorX, cursorY, pillWidth, pillHeight, Theme.scale(7), Theme.scale(7))
    Theme.applyColor(color)
    love.graphics.printf(label, cursorX + Theme.scale(8), cursorY + Theme.scale(3), pillWidth - Theme.scale(16), "center")

    cursorX = cursorX + pillWidth + columnGap
  end
end

local function drawPouchCell(app, card, x, y, width, metrics, options)
  local mouseX, mouseY = love.mouse.getPosition()
  local cellRect = { x = x, y = y, width = width, height = metrics.cellHeight }
  local hovered = containsPoint(cellRect, mouseX, mouseY)
  local squareX = x + math.floor((width - metrics.cellSize) / 2)
  local squareY = y
  local coinSize = math.min(Theme.scale(84), math.floor(metrics.cellSize * 0.64))
  local maxOffsetX = math.min(metrics.cellSize * POUCH_COIN_JITTER_X, math.max(0, (metrics.cellSize - coinSize) / 2))
  local maxOffsetY = math.min(metrics.cellSize * POUCH_COIN_JITTER_Y, math.max(0, (metrics.cellSize - coinSize) / 2))
  local offsetX = getStableSignedValue(card.coinId, "pouch-x") * maxOffsetX
  local offsetY = getStableSignedValue(card.coinId, "pouch-y") * maxOffsetY
  local tilt = getStableSignedValue(card.coinId, "pouch-tilt") * 0.11
  local coinX = squareX + math.floor((metrics.cellSize - coinSize) / 2 + offsetX)
  local coinY = squareY + math.floor((metrics.cellSize - coinSize) / 2 + offsetY)
  local coinCenterX = coinX + math.floor(coinSize / 2)
  local coinCenterY = coinY + math.floor(coinSize / 2)
  local textY = squareY + metrics.cellSize + Theme.scale(8)
  local selected = options.selectedCoinId == card.coinId

  if selected then
    setColorWithAlpha(Theme.colors.warning, 0.18)
    love.graphics.rectangle("fill", squareX, squareY, metrics.cellSize, metrics.cellSize, Theme.scale(10), Theme.scale(10))
    Theme.applyColor(Theme.colors.warning)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", squareX, squareY, metrics.cellSize, metrics.cellSize, Theme.scale(10), Theme.scale(10))
    love.graphics.setLineWidth(1)
  end

  if hovered then
    setColorWithAlpha(Theme.colors.accent, 0.12)
    love.graphics.circle("fill", coinCenterX, coinCenterY, math.floor(coinSize / 2) + Theme.scale(12))
    setColorWithAlpha(Theme.colors.accent, 0.36)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", coinCenterX, coinCenterY, math.floor(coinSize / 2) + Theme.scale(7))
    love.graphics.setLineWidth(1)
  end

  setColorWithAlpha(Theme.colors.shadow, 0.28)
  love.graphics.ellipse("fill", coinCenterX, coinY + coinSize + Theme.scale(7), math.floor(coinSize * 0.42), Theme.scale(7))

  CoinArt.draw(card.coinId, coinX, coinY, coinSize, {
    glow = false,
    shadow = false,
    selected = selected,
    tilt = tilt,
  })

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(card.name or card.coinId, x, textY, width, "center")

  local pillY = textY + app.fonts.body:getHeight() + Theme.scale(6)
  drawPills(app, card, x + Theme.scale(4), pillY, math.max(1, width - Theme.scale(8)))

  local countY = pillY + ((app.fonts.small:getHeight() + Theme.scale(8)) * 2) + Theme.scale(8)
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(string.format("owned: %d", card.count or 0), x, countY, width, "center")

  if options.showZones then
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(string.format("avail %d | hand %d | spent %d", card.available or 0, card.hand or 0, card.exhausted or 0), x, countY + app.fonts.small:getHeight() + Theme.scale(4), width, "center")
  end

  return hovered
end

function PurseView.getScrollButtons(area, scrollOffset, maxScrollOffset, onPrevious, onNext)
  local buttonWidth = Theme.scale(30)
  local buttonHeight = Theme.scale(22)
  local gap = Theme.scale(6)
  local y = area.y - Theme.scale(1)
  local nextX = area.x + area.width - buttonWidth

  if maxScrollOffset <= 0 then
    return {}
  end

  return {
    {
      x = nextX - buttonWidth - gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "^",
      variant = "warning",
      disabled = scrollOffset <= 0,
      onClick = onPrevious,
    },
    {
      x = nextX,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "v",
      variant = "warning",
      disabled = scrollOffset >= maxScrollOffset,
      onClick = onNext,
    },
  }
end

function PurseView.getCardAtPoint(app, area, stageState, x, y, options)
  options = options or {}
  local cards = app:getPurseCardData(stageState)
  if options.showZones == nil then
    options.showZones = stageState ~= nil
  end
  local metrics = getGridMetrics(app, area, #cards, options)

  if x < area.x or x > area.x + area.width or y < metrics.gridY or y > metrics.gridY + metrics.gridHeight then
    return nil
  end

  local scrollOffset = math.max(0, math.min(options.scrollOffset or 0, metrics.maxScrollOffset))
  local scrollY = scrollOffset * (metrics.cellHeight + metrics.gap)

  for index = 1, #cards do
    local card = cards[index]
    local cardIndex = index - 1
    local row = math.floor(cardIndex / metrics.columnCount)
    local column = cardIndex % metrics.columnCount
    local cardX = area.x + (column * (metrics.cellWidth + metrics.gap))
    local cardY = metrics.gridY + (row * (metrics.cellHeight + metrics.gap)) - scrollY

    if x >= cardX and x <= cardX + metrics.cellWidth and y >= cardY and y <= cardY + metrics.cellHeight then
      return card
    end
  end

  return nil
end

function PurseView.draw(app, area, stageState, options)
  options = options or {}
  local cards, summary = app:getPurseCardData(stageState)
  if options.showZones == nil then
    options.showZones = stageState ~= nil
  end
  local metrics = getGridMetrics(app, area, #cards, options)
  local scrollOffset = math.max(0, math.min(options.scrollOffset or 0, metrics.maxScrollOffset))
  local headerLines = {
    string.format("Pouch: %d coin(s)", summary.purseSize or 0),
    string.format("Hand size: %d", summary.handSize or 0),
  }

  if options.note then
    table.insert(headerLines, options.note)
  end

  if metrics.maxScrollOffset > 0 then
    table.insert(headerLines, string.format("Scroll %d/%d", scrollOffset + 1, metrics.maxScrollOffset + 1))
  end

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(table.concat(headerLines, "  |  "), area.x, area.y, area.width, "left")

  if #cards == 0 then
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("No coins in pouch.", area.x, area.y + Theme.scale(46), area.width, "center")
    return
  end

  local previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight = love.graphics.getScissor()
  local scrollY = scrollOffset * (metrics.cellHeight + metrics.gap)
  local hoveredCoin = nil
  local mouseX, mouseY = love.mouse.getPosition()

  love.graphics.setScissor(area.x, metrics.gridY, area.width, metrics.gridHeight)

  for index = 1, #cards do
    local card = cards[index]
    local cardIndex = index - 1
    local row = math.floor(cardIndex / metrics.columnCount)
    local column = cardIndex % metrics.columnCount
    local cardX = area.x + (column * (metrics.cellWidth + metrics.gap))
    local cardY = metrics.gridY + (row * (metrics.cellHeight + metrics.gap)) - scrollY

    if cardY + metrics.cellHeight >= metrics.gridY and cardY <= metrics.gridY + metrics.gridHeight then
      if drawPouchCell(app, card, cardX, cardY, metrics.cellWidth, metrics, options) then
        hoveredCoin = Coins.getById(card.coinId)
      end
    end
  end

  if previousScissorX then
    love.graphics.setScissor(previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight)
  else
    love.graphics.setScissor()
  end

  if hoveredCoin then
    CoinDetailOverlay.draw(app, hoveredCoin, mouseX, mouseY, {
      bounds = {
        x = area.x,
        y = area.y,
        width = area.width,
        height = area.height,
        screenPadding = Theme.scale(8),
      },
    })
  end
end

return PurseView
