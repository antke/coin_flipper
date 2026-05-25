local CoinCard = require("src.ui.coin_card")
local Theme = require("src.ui.theme")

local PurseView = {}

local function getGridMetrics(area, cardCount, options)
  local gap = Theme.spacing.itemGap
  local headerHeight = Theme.scale(30)
  local gridY = area.y + headerHeight
  local gridHeight = math.max(0, area.height - headerHeight)
  local minCardWidth = options.minCardWidth or Theme.scale(190)
  local columnCount = math.max(1, math.floor((area.width + gap) / (minCardWidth + gap)))
  local cardWidth = math.floor((area.width - (gap * (columnCount - 1))) / columnCount)
  local cardHeight = math.min(options.cardHeight or Theme.scale(148), math.max(Theme.scale(118), gridHeight))
  local visibleRows = math.max(1, math.floor((gridHeight + gap) / (cardHeight + gap)))
  local rowCount = math.max(1, math.ceil(cardCount / columnCount))

  return {
    gap = gap,
    gridY = gridY,
    gridHeight = gridHeight,
    cardWidth = cardWidth,
    cardHeight = cardHeight,
    columnCount = columnCount,
    rowCount = rowCount,
    visibleRows = visibleRows,
    maxScrollOffset = math.max(0, rowCount - visibleRows),
  }
end

function PurseView.getMaxScrollOffset(app, area, stageState, options)
  options = options or {}
  local cards = app:getPurseCardData(stageState)
  local metrics = getGridMetrics(area, #cards, options)
  return metrics.maxScrollOffset
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

function PurseView.draw(app, area, stageState, options)
  options = options or {}
  local cards, summary = app:getPurseCardData(stageState)
  local metrics = getGridMetrics(area, #cards, options)
  local scrollOffset = math.max(0, math.min(options.scrollOffset or 0, metrics.maxScrollOffset))
  local headerLines = {
    string.format("Purse: %d coin(s)", summary.purseSize or 0),
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
    love.graphics.printf("No coins in purse.", area.x, area.y + Theme.scale(46), area.width, "center")
    return
  end

  local previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight = love.graphics.getScissor()
  local scrollY = scrollOffset * (metrics.cardHeight + metrics.gap)

  love.graphics.setScissor(area.x, metrics.gridY, area.width, metrics.gridHeight)

  for index = 1, #cards do
    local card = cards[index]
    local cardIndex = index - 1
    local row = math.floor(cardIndex / metrics.columnCount)
    local column = cardIndex % metrics.columnCount
    local cardX = area.x + (column * (metrics.cardWidth + metrics.gap))
    local cardY = metrics.gridY + (row * (metrics.cardHeight + metrics.gap)) - scrollY

    if cardY + metrics.cardHeight >= metrics.gridY and cardY <= metrics.gridY + metrics.gridHeight then
      CoinCard.draw(app, card, cardX, cardY, metrics.cardWidth, metrics.cardHeight, {
        showZones = stageState ~= nil,
      })
    end
  end

  if previousScissorX then
    love.graphics.setScissor(previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight)
  else
    love.graphics.setScissor()
  end
end

return PurseView
