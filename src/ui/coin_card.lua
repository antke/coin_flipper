local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local CoinCard = {}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

function CoinCard.draw(app, card, x, y, width, height, options)
  options = options or {}
  local showZones = options.showZones == true
  local showCount = options.showCount

  if showCount == nil then
    showCount = showZones or card.count ~= nil
  end

  local coinSize = math.min(showCount and 84 or 116, math.max(58, math.floor(height * (showCount and 0.48 or 0.50))))
  local artX = x + 12
  local artY = y + 42
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
  })

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  local descriptionLineHeight = app.fonts.small:getHeight() + 2
  Layout.drawRichWrappedText(Terminology.getMechanicRichText(card.description), textX, y + 38, textWidth, Theme.colors.mutedText, descriptionLineHeight, descriptionLineHeight * 4)

  if not showCount then
    return
  end

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

  local countY = y + height - 28
  setColorWithAlpha(Theme.colors.accent, 0.18)
  love.graphics.rectangle("fill", x + 10, countY, width - 20, 20, 8, 8)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(countText, x + 14, countY + 3, width - 28, "center")
end

return CoinCard
