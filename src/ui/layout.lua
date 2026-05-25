local Theme = require("src.ui.theme")

local Layout = {}

local TARGETS = {
  { id = "compact", label = "Compact", tier = "compact", width = 1280, height = 720 },
  { id = "standard", label = "Standard", tier = "standard", width = 1600, height = 900 },
  { id = "large", label = "Large", tier = "large", width = 1920, height = 1080 },
  { id = "max", label = "Max", tier = "max", width = 2560, height = 1440 },
}

local MIN_TARGET = TARGETS[1]
local MAX_TARGET = TARGETS[#TARGETS]

local function isRichText(value)
  return type(value) == "table" and value.richText == true and type(value.segments) == "table"
end

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

local function drawTextToken(text, x, y, color, bold)
  Theme.applyColor(color or Theme.colors.text)
  love.graphics.print(text, x, y)

  if bold then
    love.graphics.print(text, x, y + 1)
  end
end

local function drawEllipsis(startX, currentY, color, bold)
  drawTextToken("…", startX, currentY, color, bold)
end

local function resolveTier(width, height)
  local tier = "compact"

  for _, target in ipairs(TARGETS) do
    if width >= target.width and height >= target.height then
      tier = target.tier
    end
  end

  return tier
end

local function copyTable(source)
  local result = {}

  for key, value in pairs(source or {}) do
    result[key] = value
  end

  return result
end

function Layout.getDisplayTargets()
  local targets = {}

  for _, target in ipairs(TARGETS) do
    table.insert(targets, copyTable(target))
  end

  return targets
end

function Layout.getDefaultDisplayTargetId()
  return "compact"
end

function Layout.getDisplayTargetById(targetId)
  for _, target in ipairs(TARGETS) do
    if target.id == targetId then
      return copyTable(target)
    end
  end

  return nil
end

function Layout.resolveViewport(windowWidth, windowHeight)
  local width = math.floor(windowWidth or MIN_TARGET.width)
  local height = math.floor(windowHeight or MIN_TARGET.height)
  local tier = resolveTier(width, height)
  local scale = math.min(width / MIN_TARGET.width, height / MIN_TARGET.height)

  return {
    window = {
      width = width,
      height = height,
    },
    rect = {
      x = 0,
      y = 0,
      width = width,
      height = height,
    },
    target = {
      minWidth = MIN_TARGET.width,
      minHeight = MIN_TARGET.height,
      maxWidth = MAX_TARGET.width,
      maxHeight = MAX_TARGET.height,
    },
    tier = tier,
    scale = scale,
    spacing = copyTable(Theme.spacingTiers[tier]),
    fontSizes = copyTable(Theme.fontSizeTiers[tier]),
    metrics = copyTable(Theme.componentMetricTiers[tier]),
  }
end

function Layout.resolveGrid(rect, columns, rows, gap, areas)
  local resolved = {}
  local columnCount = math.max(1, columns or 1)
  local rowCount = math.max(1, rows or 1)
  local gridGap = math.max(0, gap or 0)
  local cellWidth = math.max(0, ((rect.width or 0) - (gridGap * (columnCount - 1))) / columnCount)
  local cellHeight = math.max(0, ((rect.height or 0) - (gridGap * (rowCount - 1))) / rowCount)

  for name, area in pairs(areas or {}) do
    local column = math.max(1, area.column or 1)
    local row = math.max(1, area.row or 1)
    local columnSpan = math.max(1, area.columnSpan or 1)
    local rowSpan = math.max(1, area.rowSpan or 1)
    local x = (rect.x or 0) + ((column - 1) * (cellWidth + gridGap))
    local y = (rect.y or 0) + ((row - 1) * (cellHeight + gridGap))

    resolved[name] = {
      x = math.floor(x),
      y = math.floor(y),
      width = math.max(1, math.floor((cellWidth * columnSpan) + (gridGap * (columnSpan - 1)))),
      height = math.max(1, math.floor((cellHeight * rowSpan) + (gridGap * (rowSpan - 1)))),
    }
  end

  return resolved
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

function Layout.drawRichWrappedText(richText, startX, startY, width, color, lineHeight, maxHeight)
  local currentX = startX
  local currentY = startY
  local heightPerLine = lineHeight or Theme.spacing.lineHeight
  local maximumY = maxHeight and (startY + maxHeight) or nil
  local segments = isRichText(richText) and richText.segments or { { text = tostring(richText or ""), bold = false } }
  local drewText = false

  local function canDrawNextLine()
    return not maximumY or currentY + heightPerLine <= maximumY
  end

  local function newLine()
    currentY = currentY + heightPerLine
    currentX = startX
    return canDrawNextLine()
  end

  if not canDrawNextLine() then
    return currentY, true
  end

  for _, segment in ipairs(segments) do
    local text = tostring(segment.text or "")
    local bold = segment.bold == true
    local position = 1

    while position <= #text do
      local newlineStart, newlineEnd = string.find(text, "\n", position, true)
      local chunk = newlineStart and text:sub(position, newlineStart - 1) or text:sub(position)

      local chunkIndex = 1

      while chunkIndex <= #chunk do
        local isWhitespace = string.match(chunk:sub(chunkIndex, chunkIndex), "%s") ~= nil
        local tokenEnd = chunkIndex

        while tokenEnd <= #chunk and (string.match(chunk:sub(tokenEnd, tokenEnd), "%s") ~= nil) == isWhitespace do
          tokenEnd = tokenEnd + 1
        end

        local token = chunk:sub(chunkIndex, tokenEnd - 1)
        local tokenWidth = love.graphics.getFont():getWidth(token)

        if isWhitespace then
          if currentX > startX then
            if currentX + tokenWidth > startX + width then
              if not newLine() then
                return currentY + heightPerLine, true
              end
            else
              currentX = currentX + tokenWidth
            end
          end
        else
          if currentX > startX and currentX + tokenWidth > startX + width then
            if not newLine() then
              drawEllipsis(startX, currentY, color, bold)
              return currentY + heightPerLine, true
            end
          end

          drawTextToken(token, currentX, currentY, color, bold)
          drewText = true
          currentX = currentX + tokenWidth
        end

        chunkIndex = tokenEnd
      end

      if newlineStart then
        if not newLine() then
          return currentY + heightPerLine, true
        end

        position = newlineEnd + 1
      else
        break
      end
    end
  end

  if not drewText then
    return currentY + heightPerLine, false
  end

  return currentY + heightPerLine, false
end

function Layout.drawWrappedLines(lines, startX, startY, width, color, lineHeight, maxHeight)
  local currentY = startY
  local heightPerLine = lineHeight or Theme.spacing.lineHeight
  local maximumY = maxHeight and (startY + maxHeight) or nil

  Theme.applyColor(color or Theme.colors.text)

  for _, line in ipairs(lines or {}) do
    if isRichText(line) then
      local didClip = false
      currentY, didClip = Layout.drawRichWrappedText(line, startX, currentY, width, color, heightPerLine, maximumY and (maximumY - currentY) or nil)

      if didClip then
        return currentY, true
      end
    else
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
  end

  return currentY, false
end

function Layout.getFooterMetrics(totalHeight, options)
  options = options or {}

  local buttonHeight = options.buttonHeight or Theme.componentMetrics.buttonHeight or 46
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
