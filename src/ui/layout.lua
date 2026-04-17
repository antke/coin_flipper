local Theme = require("src.ui.theme")

local Layout = {}

local function getWrappedLineCount(text, width)
  local font = love.graphics.getFont()
  local content = tostring(text or "")

  if content == "" then
    return 1
  end

  if width == nil then
    return 1
  end

  local _, wrapped = font:getWrap(content, width)
  return math.max(1, #wrapped)
end

function Layout.centeredText(text, y, font, color)
  local width = love.graphics.getWidth()
  local previousFont = love.graphics.getFont()

  if font then
    love.graphics.setFont(font)
  end

  if color then
    Theme.applyColor(color)
  else
    Theme.applyColor(Theme.colors.text)
  end

  love.graphics.printf(text, 0, y, width, "center")

  if font then
    love.graphics.setFont(previousFont)
  end
end

function Layout.drawLines(lines, startX, startY, color, lineHeight)
  local currentY = startY
  Theme.applyColor(color or Theme.colors.text)

  for _, line in ipairs(lines or {}) do
    love.graphics.print(line, startX, currentY)
    currentY = currentY + (lineHeight or Theme.spacing.lineHeight)
  end

  return currentY
end

function Layout.drawWrappedText(text, startX, startY, width, color, lineHeight, align)
  local currentY = startY
  local heightPerLine = lineHeight or Theme.spacing.lineHeight
  local content = tostring(text or "")

  Theme.applyColor(color or Theme.colors.text)

  if content == "" then
    return currentY + heightPerLine
  end

  love.graphics.printf(content, startX, currentY, width, align or "left")
  return currentY + (getWrappedLineCount(content, width) * heightPerLine)
end

function Layout.drawWrappedLines(lines, startX, startY, width, color, lineHeight, maxHeight)
  local currentY = startY
  local heightPerLine = lineHeight or Theme.spacing.lineHeight
  local maximumY = maxHeight and (startY + maxHeight) or nil

  Theme.applyColor(color or Theme.colors.text)

  for _, line in ipairs(lines or {}) do
    local lineCount = getWrappedLineCount(line, width)
    local nextY = currentY + (lineCount * heightPerLine)

    if maximumY and nextY > maximumY then
      if currentY + heightPerLine <= maximumY then
        love.graphics.printf("…", startX, currentY, width, "left")
        currentY = currentY + heightPerLine
      end

      return currentY, true
    end

    currentY = Layout.drawWrappedText(line, startX, currentY, width, color, heightPerLine)
  end

  return currentY, false
end

function Layout.getFooterMetrics(totalHeight, options)
  options = options or {}

  local buttonHeight = options.buttonHeight or 46
  local buttonRows = math.max(0, options.buttonRows or 1)
  local rowGap = options.rowGap or Theme.spacing.itemGap
  local statusHeight = math.max(0, options.statusHeight or 0)
  local bottomPadding = options.bottomPadding or Theme.spacing.screenPadding
  local extraSpacing = math.max(0, options.extraSpacing or (Theme.spacing.statusPadding + Theme.spacing.itemGap))
  local buttonsHeight = (buttonHeight * buttonRows) + (rowGap * math.max(0, buttonRows - 1))
  local reservedHeight = buttonsHeight + statusHeight + extraSpacing

  return {
    buttonHeight = buttonHeight,
    buttonRows = buttonRows,
    rowGap = rowGap,
    statusHeight = statusHeight,
    bottomPadding = bottomPadding,
    extraSpacing = extraSpacing,
    buttonsHeight = buttonsHeight,
    reservedHeight = reservedHeight,
    contentBottomY = totalHeight - bottomPadding - reservedHeight,
    buttonY = totalHeight - bottomPadding - statusHeight - buttonHeight,
  }
end

return Layout
