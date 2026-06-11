local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")
local Box = require("src.ui.box")

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

  local padding = Theme.scale(12)
  local titleY = y + Theme.scale(10)
  local contentY = y + Theme.scale(42)
  local countHeight = Theme.scale(20)
  local countY = y + height - Theme.scale(28)
  local coinSize = math.min(showCount and Theme.scale(84) or Theme.scale(116), math.max(Theme.scale(58), math.floor(height * (showCount and 0.48 or 0.50))))
  local artX = x + padding
  local artY = contentY
  local textX = artX + coinSize + padding
  local textWidth = math.max(Theme.scale(40), x + width - textX - padding)

  Box.drawFrame(x, y, width, height, {
    fill = { Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.92 },
    border = { Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 0.90 },
  })

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(card.name or card.coinId, x + Theme.scale(10), titleY, width - Theme.scale(20), "center")

  CoinArt.draw(card.coinId, artX, artY, coinSize, {
    selected = false,
  })

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  local descriptionLineHeight = app.fonts.small:getHeight() + Theme.scale(2)
  local detailHeight = math.max(descriptionLineHeight, (showCount and countY or (y + height - padding)) - contentY - Theme.scale(8))
  local detailY = contentY - Theme.scale(4)
  local remainingHeight = detailHeight

  if card.chanceText then
    Theme.applyColor(Theme.colors.text)
    love.graphics.printf("Chance: " .. card.chanceText, textX, detailY, textWidth, "left")
    detailY = detailY + descriptionLineHeight
    remainingHeight = remainingHeight - descriptionLineHeight
  end

  if card.effectDescription and card.effectDescription ~= "" and remainingHeight > descriptionLineHeight then
    local effectHeight = math.max(descriptionLineHeight, math.floor(remainingHeight * 0.60))
    local nextY = Layout.drawRichWrappedText(Terminology.getMechanicRichText("Effect: " .. card.effectDescription), textX, detailY, textWidth, Theme.colors.mutedText, descriptionLineHeight, effectHeight)
    local usedHeight = nextY - detailY
    detailY = detailY + usedHeight
    remainingHeight = remainingHeight - usedHeight
  end

  if card.description and card.description ~= "" and remainingHeight > 0 then
    Layout.drawRichWrappedText("Description: " .. card.description, textX, detailY, textWidth, Theme.colors.mutedText, descriptionLineHeight, remainingHeight)
  end

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

  setColorWithAlpha(Theme.colors.accent, 0.18)
  love.graphics.rectangle("fill", x + Theme.scale(10), countY, width - Theme.scale(20), countHeight, Theme.scale(8), Theme.scale(8))
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(countText, x + Theme.scale(14), countY + Theme.scale(3), width - Theme.scale(28), "center")
end

return CoinCard
