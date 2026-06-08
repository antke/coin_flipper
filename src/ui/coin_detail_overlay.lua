local CoinDetailContent = require("src.content.coin_detail_content")
local Layout = require("src.ui.layout")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local CoinDetailOverlay = {}

local RARITY_COLORS = {
  common = Theme.colors.mutedText,
  uncommon = Theme.colors.accent,
  rare = Theme.colors.highlight,
}

local TYPE_TAG_COLORS = {
  basic = Theme.colors.mutedText,
  combo = Theme.colors.highlight,
  influence = Theme.colors.warning,
  heads = { 0.94, 0.46, 0.25, 1.0 },
  motion = Theme.colors.accent,
  neighbor = Theme.colors.accent,
  odds = Theme.colors.success,
  perfect = Theme.colors.highlight,
  safety = Theme.colors.success,
  score_scaling = Theme.colors.highlight,
  tails = { 0.45, 0.62, 1.0, 1.0 },
}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function getPillColor(pill)
  if pill.kind == "rarity" then
    return RARITY_COLORS[pill.value] or Theme.colors.mutedText
  end

  return TYPE_TAG_COLORS[pill.value] or Theme.colors.mutedText
end

local function buildPills(detail)
  local pills = {}

  for _, pill in ipairs(detail and detail.pills or {}) do
    table.insert(pills, {
      label = pill.label,
      color = getPillColor(pill),
      minWidth = pill.kind == "rarity" and Theme.scale(82) or Theme.scale(58),
    })
  end

  return pills
end

local function getPillWidth(font, pill)
  return math.max(pill.minWidth or Theme.scale(58), font:getWidth(pill.label) + Theme.scale(20))
end

local function getPillRowsHeight(font, pills, maxWidth, pillHeight, rowGap, columnGap)
  local rows = 1
  local rowWidth = 0

  for _, pill in ipairs(pills) do
    local pillWidth = math.min(maxWidth, getPillWidth(font, pill))

    if rowWidth > 0 and rowWidth + columnGap + pillWidth > maxWidth then
      rows = rows + 1
      rowWidth = pillWidth
    elseif rowWidth > 0 then
      rowWidth = rowWidth + columnGap + pillWidth
    else
      rowWidth = pillWidth
    end
  end

  return (rows * pillHeight) + ((rows - 1) * rowGap)
end

local function drawPills(font, pills, x, y, maxWidth, pillHeight)
  local rowGap = Theme.scale(6)
  local columnGap = Theme.scale(6)
  local cursorX = x
  local cursorY = y

  love.graphics.setFont(font)

  for _, pill in ipairs(pills) do
    local pillWidth = math.min(maxWidth, getPillWidth(font, pill))

    if cursorX > x and cursorX + pillWidth > x + maxWidth then
      cursorX = x
      cursorY = cursorY + pillHeight + rowGap
    end

    setColorWithAlpha(pill.color, 0.18)
    love.graphics.rectangle("fill", cursorX, cursorY, pillWidth, pillHeight, Theme.scale(8), Theme.scale(8))
    Theme.applyColor(pill.color)
    love.graphics.printf(pill.label, cursorX + Theme.scale(10), cursorY + Theme.scale(2), pillWidth - Theme.scale(20), "center")

    cursorX = cursorX + pillWidth + columnGap
  end
end

local function getBounds(options)
  local bounds = options and options.bounds or nil

  if bounds then
    return {
      x = bounds.x or 0,
      y = bounds.y or 0,
      width = bounds.width or love.graphics.getWidth(),
      height = bounds.height or love.graphics.getHeight(),
      screenPadding = bounds.screenPadding,
    }
  end

  return {
    x = 0,
    y = 0,
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight(),
    screenPadding = nil,
  }
end

local function getWrappedHeight(font, text, width, lineHeight)
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped) * lineHeight
end

local function drawLabel(text, x, y, font)
  love.graphics.setFont(font)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.print(text, x, y)
end

local function hasText(text)
  return type(text) == "string" and text ~= ""
end

function CoinDetailOverlay.draw(app, coin, x, y, options)
  if not coin then
    return
  end

  options = options or {}

  local detail = CoinDetailContent.build(coin)

  local bounds = getBounds(options)
  local margin = bounds.screenPadding or Theme.spacing.screenPadding
  local availableWidth = math.max(1, bounds.width - (margin * 2))
  local availableHeight = math.max(1, bounds.height - (margin * 2))
  local width = math.min(options.width or Theme.scale(430), availableWidth)
  local padding = Theme.scale(16)
  local contentWidth = math.max(1, width - (padding * 2))
  local nameLineHeight = app.fonts.heading:getHeight() + Theme.scale(2)
  local rarityLineHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local descriptionLineHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local sectionLabelHeight = app.fonts.body:getHeight()
  local nameHeight = getWrappedHeight(app.fonts.heading, detail.title, contentWidth, nameLineHeight)
  local pills = buildPills(detail)
  local pillRowGap = Theme.scale(6)
  local pillColumnGap = Theme.scale(6)
  local pillRowsHeight = getPillRowsHeight(app.fonts.small, pills, contentWidth, rarityLineHeight, pillRowGap, pillColumnGap)
  local chanceHeight = app.fonts.body:getHeight() + Theme.scale(4)
  local effectHeight = hasText(detail.effectText) and getWrappedHeight(app.fonts.small, detail.effectText, contentWidth, descriptionLineHeight) or 0
  local descriptionHeight = getWrappedHeight(app.fonts.small, detail.description, contentWidth, descriptionLineHeight)
  local sectionGap = Theme.scale(12)
  local labelGap = Theme.scale(6)
  local headerHeight = nameHeight + Theme.scale(6) + pillRowsHeight
  local effectSectionHeight = hasText(detail.effectText) and (sectionGap + sectionLabelHeight + labelGap + effectHeight) or 0
  local fixedHeight = padding + headerHeight + sectionGap + chanceHeight + effectSectionHeight + sectionGap + sectionLabelHeight + labelGap + padding
  local height = math.min(fixedHeight + descriptionHeight, availableHeight)
  local descriptionMaxHeight = math.max(descriptionLineHeight, height - fixedHeight)
  local overlayX = math.min(x + Theme.scale(18), bounds.x + bounds.width - width - margin)
  local overlayY = math.min(y + Theme.scale(18), bounds.y + bounds.height - height - margin)

  overlayX = math.max(bounds.x + margin, overlayX)
  overlayY = math.max(bounds.y + margin, overlayY)

  local radius = Theme.scale(10)
  local shadowOffset = Theme.scale(4)

  love.graphics.setColor(0.03, 0.04, 0.07, 0.96)
  love.graphics.rectangle("fill", overlayX + shadowOffset, overlayY + shadowOffset, width, height, radius, radius)
  love.graphics.setColor(0.08, 0.10, 0.15, 0.98)
  love.graphics.rectangle("fill", overlayX, overlayY, width, height, radius, radius)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", overlayX, overlayY, width, height, radius, radius)
  love.graphics.setLineWidth(1)

  local contentX = overlayX + padding
  local contentY = overlayY + padding

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(detail.title, contentX, contentY, contentWidth, "left")

  love.graphics.setFont(app.fonts.small)
  local pillY = contentY + nameHeight + Theme.scale(6)
  drawPills(app.fonts.small, pills, contentX, pillY, contentWidth, rarityLineHeight)

  local currentY = contentY + headerHeight + sectionGap

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.print("Chance", contentX, currentY)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(detail.chanceText, contentX + Theme.scale(80), currentY)
  currentY = currentY + chanceHeight

  if hasText(detail.effectText) then
    currentY = currentY + sectionGap
    drawLabel("Effect", contentX, currentY, app.fonts.body)

    love.graphics.setFont(app.fonts.small)
    Layout.drawRichWrappedText(
      Terminology.getMechanicRichText(detail.effectText),
      contentX,
      currentY + sectionLabelHeight + labelGap,
      contentWidth,
      Theme.colors.mutedText,
      descriptionLineHeight,
      effectHeight
    )
    currentY = currentY + sectionLabelHeight + labelGap + effectHeight
  end

  currentY = currentY + sectionGap
  drawLabel("Description", contentX, currentY, app.fonts.body)

  love.graphics.setFont(app.fonts.small)
  Layout.drawRichWrappedText(
    detail.description,
    contentX,
    currentY + sectionLabelHeight + labelGap,
    contentWidth,
    Theme.colors.mutedText,
    descriptionLineHeight,
    descriptionMaxHeight
  )

end

return CoinDetailOverlay
