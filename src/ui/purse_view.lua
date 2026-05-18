local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local PurseView = {}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function getWrappedPreview(text, width, maxLines)
  local font = love.graphics.getFont()
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  local lines = {}

  for index = 1, math.min(#wrapped, maxLines) do
    table.insert(lines, wrapped[index])
  end

  if #wrapped > maxLines and #lines > 0 then
    local last = lines[#lines]
    lines[#lines] = string.format("%s...", last:sub(1, math.max(1, #last - 3)))
  end

  return table.concat(lines, "\n")
end

local function drawCard(app, card, x, y, width, height, showZones)
  local coinSize = math.min(60, math.max(44, math.floor(height * 0.38)))
  local artX = x + 12
  local artY = y + 38
  local textX = artX + coinSize + 12
  local textWidth = math.max(40, x + width - textX - 12)

  setColorWithAlpha(Theme.colors.panel, 0.92)
  love.graphics.rectangle("fill", x, y, width, height, 12, 12)
  setColorWithAlpha(Theme.colors.panelBorder, 0.90)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, width, height, 12, 12)

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(card.name or card.coinId, x + 10, y + 10, width - 20, "center")

  CoinArt.draw(card.coinId, artX, artY, coinSize, {
    selected = false,
    tilt = -0.04,
  })

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  local descriptionLineHeight = app.fonts.small:getHeight() + 2
  Layout.drawRichWrappedText(Terminology.getMechanicRichText(card.description), textX, y + 38, textWidth, Theme.colors.mutedText, descriptionLineHeight, descriptionLineHeight * 4)

  local countText = string.format("x%d", card.count or 0)
  if showZones then
    countText = string.format(
      "x%d  avail %d | hand %d | spent %d",
      card.count or 0,
      card.available or 0,
      card.hand or 0,
      card.exhausted or 0
    )
  end

  setColorWithAlpha(Theme.colors.accent, 0.18)
  love.graphics.rectangle("fill", x + 10, y + height - 28, width - 20, 20, 8, 8)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(countText, x + 14, y + height - 25, width - 28, "center")
end

local function getGridMetrics(area, cardCount, options)
  local gap = Theme.spacing.itemGap
  local gridY = area.y + 30
  local gridHeight = math.max(0, area.height - 30)
  local minCardWidth = options.minCardWidth or 190
  local columnCount = math.max(1, math.floor((area.width + gap) / (minCardWidth + gap)))
  local cardWidth = math.floor((area.width - (gap * (columnCount - 1))) / columnCount)
  local cardHeight = math.min(options.cardHeight or 148, math.max(118, gridHeight))
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
  local buttonWidth = 30
  local buttonHeight = 22
  local gap = 6
  local y = area.y - 1
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
    love.graphics.printf("No coins in purse.", area.x, area.y + 46, area.width, "center")
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
      drawCard(app, card, cardX, cardY, metrics.cardWidth, metrics.cardHeight, stageState ~= nil)
    end
  end

  if previousScissorX then
    love.graphics.setScissor(previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight)
  else
    love.graphics.setScissor()
  end
end

return PurseView
