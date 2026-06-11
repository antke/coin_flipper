local Panel = require("src.ui.panel")
local Box = require("src.ui.box")
local Theme = require("src.ui.theme")
local TrickCharm = require("src.ui.trick_charm")

local TrickCharmDrawer = {}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function containsPoint(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height
end

local function getCharmCount(charms)
  if type(charms) == "number" then
    return charms
  end

  return #(charms or {})
end

local function getGridMetrics(app, area, charms, options)
  options = options or {}

  local charmCount = getCharmCount(charms)
  local gap = Theme.spacing.itemGap
  local headerHeight = app.fonts.small:getHeight() + Theme.scale(18)
  local gridY = area.y + headerHeight
  local gridHeight = math.max(0, area.height - headerHeight)
  local minCellWidth = options.minCellWidth or Theme.scale(148)
  local columnCount = math.max(1, math.floor((area.width + gap) / (minCellWidth + gap)))
  local cellWidth = math.floor((area.width - (gap * (columnCount - 1))) / columnCount)
  local cellSize = math.min(options.cellSize or Theme.scale(74), math.max(Theme.scale(44), math.floor(cellWidth * 0.42)))
  local lineHeight = app.fonts.small:getHeight() + Theme.scale(2)
  local cellHeight = cellSize + Theme.scale(8) + (lineHeight * 2) + Theme.scale(10)
  local visibleRows = math.max(1, math.floor((gridHeight + gap) / (cellHeight + gap)))
  local rowCount = math.max(1, math.ceil(charmCount / columnCount))

  return {
    gap = gap,
    headerHeight = headerHeight,
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

local function drawCharmCell(app, charm, x, y, width, metrics)
  local mouseX, mouseY = love.mouse.getPosition()
  local cellRect = { x = x, y = y, width = width, height = metrics.cellHeight }
  local hovered = containsPoint(cellRect, mouseX, mouseY)
  local charmSize = metrics.cellSize
  local charmX = x + math.floor((width - charmSize) / 2)
  local charmY = y + Theme.scale(8)
  local textY = charmY + charmSize + Theme.scale(8)
  local textPadding = Theme.scale(6)
  local textWidth = math.max(1, width - (textPadding * 2))

  local fillColor = hovered and Theme.colors.highlight or Theme.colors.panelBorder
  local borderColor = hovered and Theme.colors.highlight or Theme.colors.panelBorder
  Box.drawFrame(x, y, width, metrics.cellHeight, {
    fill = { fillColor[1], fillColor[2], fillColor[3], hovered and 0.16 or 0.10 },
    border = { borderColor[1], borderColor[2], borderColor[3], hovered and 0.52 or 0.28 },
  })

  TrickCharm.draw(app, charm, charmX, charmY, charmSize, {
    hovered = hovered,
  })

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(charm.name or charm.trickId or "Trick", x + textPadding, textY, textWidth, "center")

  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(charm.familyLabel or TrickCharm.getFamilyLabel(charm), x + textPadding, textY + app.fonts.small:getHeight() + Theme.scale(2), textWidth, "center")

  return hovered
end

function TrickCharmDrawer.getDrawerLayout(area)
  local width = math.min(area.width, math.max(Theme.scale(280), math.min(Theme.scale(520), math.floor(area.width * 0.56))))

  return {
    x = area.x + area.width - width,
    y = area.y,
    width = width,
    height = area.height,
  }
end

function TrickCharmDrawer.getContentArea(drawer)
  return Panel.getContentArea(drawer.x, drawer.y, drawer.width, drawer.height, "Charms")
end

function TrickCharmDrawer.getCloseButton(drawer, onClick)
  local size = Theme.scale(28)

  return {
    x = drawer.x + drawer.width - Theme.spacing.panelPadding - size,
    y = drawer.y + Theme.spacing.panelPadding - Theme.scale(4),
    width = size,
    height = size,
    label = "X",
    variant = "default",
    onClick = onClick,
  }
end

function TrickCharmDrawer.getMaxScrollOffset(app, area, charms, options)
  return getGridMetrics(app, area, charms, options).maxScrollOffset
end

function TrickCharmDrawer.getScrollButtons(area, scrollOffset, maxScrollOffset, onPrevious, onNext)
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

function TrickCharmDrawer.drawTrigger(app, area, charms, options)
  options = options or {}
  charms = charms or {}

  local mouseX, mouseY = love.mouse.getPosition()
  local triggerRect = { x = area.x, y = area.y, width = area.width, height = area.height }
  local triggerHovered = containsPoint(triggerRect, mouseX, mouseY)
  local titleHeight = app.fonts.small:getHeight() + Theme.scale(8)
  local gap = Theme.scale(8)
  local size = math.min(Theme.scale(38), math.max(Theme.scale(24), area.width - Theme.scale(12)))
  local startX = area.x + math.floor((area.width - size) / 2)
  local startY = area.y + titleHeight
  local step = size + gap
  local availableHeight = math.max(1, area.y + area.height - startY)
  local maxVisible = math.max(1, math.floor((availableHeight + gap) / step))
  local visibleCount = math.min(#charms, maxVisible)
  local hoveredCharm = nil

  if #charms > visibleCount and visibleCount > 1 then
    visibleCount = visibleCount - 1
  end

  if options.open or triggerHovered then
    local fillColor = options.open and Theme.colors.highlight or Theme.colors.panelBorder
    local borderColor = options.open and Theme.colors.highlight or Theme.colors.panelBorder
    Box.drawFrame(area.x, area.y, area.width, area.height, {
      fill = { fillColor[1], fillColor[2], fillColor[3], options.open and 0.18 or 0.12 },
      border = { borderColor[1], borderColor[2], borderColor[3], options.open and 0.56 or 0.34 },
    })
  end

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(options.open and Theme.colors.warning or Theme.colors.mutedText)
  love.graphics.printf("Charms", area.x, area.y, area.width, "center")

  if #charms == 0 then
    Box.drawFrame(startX, startY, size, size, {
      fill = { Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 0.30 },
      border = { Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 0.80 },
    })
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("T", startX, startY + math.floor((size - app.fonts.small:getHeight()) / 2), size, "center")

    return {
      hoveredCharm = nil,
      triggerRect = triggerRect,
      hovered = triggerHovered,
    }
  end

  if visibleCount > 1 then
    setColorWithAlpha(Theme.colors.highlight, 0.34)
    love.graphics.setLineWidth(2)
    love.graphics.line(
      area.x + math.floor(area.width / 2),
      startY + math.floor(size / 2),
      area.x + math.floor(area.width / 2),
      startY + ((visibleCount - 1) * step) + math.floor(size / 2)
    )
    love.graphics.setLineWidth(1)
  end

  for index = 1, visibleCount do
    local charm = charms[index]
    local y = startY + ((index - 1) * step)
    local hovered = containsPoint({ x = startX, y = y, width = size, height = size }, mouseX, mouseY)

    TrickCharm.draw(app, charm, startX, y, size, {
      hovered = hovered,
    })

    if hovered then
      hoveredCharm = charm
    end
  end

  if #charms > visibleCount then
    local moreY = math.min(area.y + area.height - app.fonts.small:getHeight(), startY + (visibleCount * step) - gap + Theme.scale(2))

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.highlight)
    love.graphics.printf("+" .. tostring(#charms - visibleCount), area.x, moreY, area.width, "center")
  end

  return {
    hoveredCharm = hoveredCharm,
    triggerRect = triggerRect,
    hovered = triggerHovered,
  }
end

function TrickCharmDrawer.drawDrawer(app, drawer, charms, options)
  options = options or {}
  charms = charms or {}

  local contentArea = TrickCharmDrawer.getContentArea(drawer)
  local metrics = getGridMetrics(app, contentArea, charms, options)
  local scrollOffset = math.max(0, math.min(options.scrollOffset or 0, metrics.maxScrollOffset))
  local mouseX, mouseY = love.mouse.getPosition()
  local hoveredCharm = nil

  Panel.draw(drawer.x, drawer.y, drawer.width, drawer.height, "Charms")

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf("Owned Trick Charms", contentArea.x, contentArea.y, contentArea.width, "left")
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(tostring(#charms), contentArea.x, contentArea.y, contentArea.width, "right")

  if #charms == 0 then
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("No Trick Charms yet.", contentArea.x, contentArea.y + Theme.scale(54), contentArea.width, "center")
    return nil
  end

  local previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight = love.graphics.getScissor()
  local scrollY = scrollOffset * (metrics.cellHeight + metrics.gap)

  love.graphics.setScissor(contentArea.x, metrics.gridY, contentArea.width, metrics.gridHeight)

  for index, charm in ipairs(charms) do
    local charmIndex = index - 1
    local row = math.floor(charmIndex / metrics.columnCount)
    local column = charmIndex % metrics.columnCount
    local cardX = contentArea.x + (column * (metrics.cellWidth + metrics.gap))
    local cardY = metrics.gridY + (row * (metrics.cellHeight + metrics.gap)) - scrollY

    if cardY + metrics.cellHeight >= metrics.gridY and cardY <= metrics.gridY + metrics.gridHeight then
      if drawCharmCell(app, charm, cardX, cardY, metrics.cellWidth, metrics) then
        hoveredCharm = charm
      end
    end
  end

  if previousScissorX then
    love.graphics.setScissor(previousScissorX, previousScissorY, previousScissorWidth, previousScissorHeight)
  else
    love.graphics.setScissor()
  end

  if hoveredCharm and not containsPoint(drawer, mouseX, mouseY) then
    hoveredCharm = nil
  end

  return hoveredCharm
end

return TrickCharmDrawer
