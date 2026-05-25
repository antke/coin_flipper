local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local CoinDetailOverlay = {}

local RARITY_COLORS = {
  common = Theme.colors.mutedText,
  uncommon = Theme.colors.accent,
  rare = Theme.colors.highlight,
  cursed = Theme.colors.danger,
}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function capitalize(value)
  local text = tostring(value or "common")
  return (text:gsub("^%l", string.upper))
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

function CoinDetailOverlay.draw(app, coin, x, y, options)
  if not coin then
    return
  end

  options = options or {}

  local bounds = getBounds(options)
  local margin = bounds.screenPadding or Theme.spacing.screenPadding
  local availableWidth = math.max(1, bounds.width - (margin * 2))
  local availableHeight = math.max(1, bounds.height - (margin * 2))
  local width = math.min(options.width or Theme.scale(430), availableWidth)
  local padding = Theme.scale(16)
  local gap = Theme.scale(12)
  local contentWidth = math.max(1, width - (padding * 2))
  local artSize = math.min(Theme.scale(82), math.max(Theme.scale(58), math.floor(width * 0.22)))
  local headerTextXOffset = padding + artSize + gap
  local headerTextWidth = math.max(Theme.scale(96), width - headerTextXOffset - padding)
  local nameLineHeight = app.fonts.heading:getHeight() + Theme.scale(2)
  local rarityLineHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local descriptionLineHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local sectionLabelHeight = app.fonts.body:getHeight()
  local nameHeight = getWrappedHeight(app.fonts.heading, coin.name or coin.id, headerTextWidth, nameLineHeight)
  local headerHeight = math.max(artSize, nameHeight + Theme.scale(6) + rarityLineHeight)
  local tagText = string.format("Tags: %s", Terminology.formatTagList(coin.tags))
  local tagHeight = getWrappedHeight(app.fonts.small, tagText, contentWidth, descriptionLineHeight)
  local descriptionHeight = getWrappedHeight(app.fonts.small, coin.description or "", contentWidth, descriptionLineHeight)
  local fixedHeight = padding + headerHeight + Theme.scale(16) + sectionLabelHeight + Theme.scale(6) + Theme.scale(12) + tagHeight + padding
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
  local textX = overlayX + headerTextXOffset

  CoinArt.draw(coin, contentX, contentY, artSize, { selected = true, tilt = -0.04 })

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(coin.name or coin.id, textX, contentY, headerTextWidth, "left")

  love.graphics.setFont(app.fonts.small)
  local rarityColor = RARITY_COLORS[coin.rarity or "common"] or Theme.colors.mutedText
  setColorWithAlpha(rarityColor, 0.18)
  local pillY = contentY + nameHeight + Theme.scale(6)
  local pillWidth = math.min(headerTextWidth, math.max(Theme.scale(82), app.fonts.small:getWidth(capitalize(coin.rarity)) + Theme.scale(20)))
  love.graphics.rectangle("fill", textX, pillY, pillWidth, rarityLineHeight, Theme.scale(8), Theme.scale(8))
  Theme.applyColor(rarityColor)
  love.graphics.printf(capitalize(coin.rarity), textX + Theme.scale(10), pillY + Theme.scale(2), pillWidth - Theme.scale(20), "center")

  local descriptionY = contentY + headerHeight + Theme.scale(16)
  drawLabel("Effect", contentX, descriptionY, app.fonts.body)

  love.graphics.setFont(app.fonts.small)
  Layout.drawRichWrappedText(
    Terminology.getMechanicRichText(coin.description or ""),
    contentX,
    descriptionY + sectionLabelHeight + Theme.scale(6),
    contentWidth,
    Theme.colors.mutedText,
    descriptionLineHeight,
    descriptionMaxHeight
  )

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(tagText, contentX, overlayY + height - padding - tagHeight, contentWidth, "left")
end

return CoinDetailOverlay
