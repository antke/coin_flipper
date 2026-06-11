local CoinArt = require("src.ui.coin_art")
local CoinDetailOverlay = require("src.ui.coin_detail_overlay")
local Coins = require("src.content.coins")
local Theme = require("src.ui.theme")
local TrickCharm = require("src.ui.trick_charm")
local Box = require("src.ui.box")

local PurseView = {}

local POUCH_COIN_JITTER_X = 0.105
local POUCH_COIN_JITTER_Y = 0.135

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
  local countHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local cellHeight = cellSize + Theme.scale(8) + titleHeight + Theme.scale(4) + countHeight
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

local function getCards(app, stageState, options)
  options = options or {}

  local cards = app:getPurseCardData(stageState)

  if options.includeTricks ~= false and app.getTrickCharmData then
    for _, charm in ipairs(app:getTrickCharmData()) do
      table.insert(cards, charm)
    end
  end

  return cards
end

function PurseView.getMaxScrollOffset(app, area, stageState, options)
  options = options or {}
  local cards = getCards(app, stageState, options)
  local metrics = getGridMetrics(app, area, #cards, options)
  return metrics.maxScrollOffset
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
    Box.drawFrame(squareX, squareY, metrics.cellSize, metrics.cellSize, {
      fill = { Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.18 },
      border = Theme.colors.warning,
    })
  end

  local hoverScale = hovered and 1.10 or 1.0
  local visualCoinSize = math.floor(coinSize * hoverScale)
  local visualCoinX = coinCenterX - math.floor(visualCoinSize / 2)
  local visualCoinY = coinCenterY - math.floor(visualCoinSize / 2)

  setColorWithAlpha(Theme.colors.shadow, 0.28)
  love.graphics.ellipse("fill", coinCenterX, visualCoinY + visualCoinSize + Theme.scale(7), math.floor(visualCoinSize * 0.42), Theme.scale(7))

  CoinArt.draw(card.coinId, visualCoinX, visualCoinY, visualCoinSize, {
    glow = false,
    shadow = false,
    selected = false,
    tilt = tilt,
  })

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(card.name or card.coinId, x, textY, width, "center")

  local countY = textY + app.fonts.body:getHeight() + Theme.scale(4)
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(string.format("×%d", card.count or 0), x, countY, width, "center")

  return hovered
end

local function drawTrickCharmCell(app, card, x, y, width, metrics)
  local mouseX, mouseY = love.mouse.getPosition()
  local cellRect = { x = x, y = y, width = width, height = metrics.cellHeight }
  local hovered = containsPoint(cellRect, mouseX, mouseY)
  local squareX = x + math.floor((width - metrics.cellSize) / 2)
  local squareY = y
  local charmSize = math.min(Theme.scale(72), math.floor(metrics.cellSize * 0.58))
  local charmX = squareX + math.floor((metrics.cellSize - charmSize) / 2)
  local charmY = squareY + math.floor((metrics.cellSize - charmSize) / 2)
  local textY = squareY + metrics.cellSize + Theme.scale(8)

  if hovered then
    Box.drawFrame(squareX, squareY, metrics.cellSize, metrics.cellSize, {
      fill = { Theme.colors.highlight[1], Theme.colors.highlight[2], Theme.colors.highlight[3], 0.12 },
      border = { Theme.colors.highlight[1], Theme.colors.highlight[2], Theme.colors.highlight[3], 0.36 },
    })
  end

  TrickCharm.draw(app, card, charmX, charmY, charmSize, {
    hovered = hovered,
  })

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(card.name or card.trickId or "Trick", x, textY, width, "center")

  local countY = textY + app.fonts.body:getHeight() + Theme.scale(4)
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.highlight)
  love.graphics.printf(card.familyLabel or TrickCharm.getFamilyLabel(card), x, countY, width, "center")

  return hovered
end

local function drawCardCell(app, card, x, y, width, metrics, options)
  if card.kind == "trick_charm" then
    return drawTrickCharmCell(app, card, x, y, width, metrics)
  end

  return drawPouchCell(app, card, x, y, width, metrics, options)
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
  local cards = getCards(app, stageState, options)
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
  local cards = getCards(app, stageState, options)
  local metrics = getGridMetrics(app, area, #cards, options)
  local scrollOffset = math.max(0, math.min(options.scrollOffset or 0, metrics.maxScrollOffset))

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf("Pouch", area.x, area.y, area.width, "left")

  if #cards == 0 then
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("No coins or Trick Charms in pouch.", area.x, area.y + Theme.scale(46), area.width, "center")
    return
  end

  local previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight = love.graphics.getScissor()
  local scrollY = scrollOffset * (metrics.cellHeight + metrics.gap)
  local hoveredCoin = nil
  local hoveredTrickCharm = nil
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
      if drawCardCell(app, card, cardX, cardY, metrics.cellWidth, metrics, options) then
        if card.kind == "trick_charm" then
          hoveredTrickCharm = card
        else
          hoveredCoin = Coins.getById(card.coinId)
        end
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
      compact = true,
      bounds = {
        x = area.x,
        y = area.y,
        width = area.width,
        height = area.height,
        screenPadding = Theme.scale(8),
      },
    })
  elseif hoveredTrickCharm then
    TrickCharm.drawDetailOverlay(app, hoveredTrickCharm, mouseX, mouseY, {
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
