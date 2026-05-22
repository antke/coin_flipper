local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Coins = require("src.content.coins")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local CoinDraftState = {}
CoinDraftState.__index = CoinDraftState

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

function CoinDraftState.new()
  return setmetatable({
    buttons = {},
    statusMessage = "Draft one coin at a time. Each pick refreshes the offers.",
  }, CoinDraftState)
end

function CoinDraftState:enter(app)
  local session = app:getDraftSession()

  if not session or (session.picksRemaining or 0) <= 0 then
    app.stateGraph:request("draft_complete")
    return
  end

  if not session.offers or #session.offers == 0 then
    app:generateDraftOffers()
  end

  self.statusMessage = "Choose a coin to add to your purse. Offers refresh after each pick."
end

function CoinDraftState:getLayout(app)
  local cards = app:getDraftOfferCards()
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local infoY = 118
  local infoHeight = 84
  local offerPanelY = infoY + infoHeight + gap
  local footerMetrics = Layout.getFooterMetrics(height, {
    statusHeight = 54,
  })
  local selectedSummaryHeight = 118
  local offerCount = math.max(1, #cards)
  local columns = math.min(3, offerCount)
  local panelWidth = math.floor((width - (padding * 2) - (gap * (columns - 1))) / columns)
  local panelHeight = math.max(230, footerMetrics.contentBottomY - offerPanelY - selectedSummaryHeight - gap)
  local selectedSummaryY = offerPanelY + panelHeight + gap
  local panelLayout = {}

  for index, card in ipairs(cards) do
    local x = padding + ((index - 1) * (panelWidth + gap))

    table.insert(panelLayout, {
      index = index,
      card = card,
      x = x,
      y = offerPanelY,
      width = panelWidth,
      height = panelHeight,
    })
  end

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    infoY = infoY,
    infoHeight = infoHeight,
    footerMetrics = footerMetrics,
    panelLayout = panelLayout,
    selectedSummary = {
      x = padding,
      y = selectedSummaryY,
      width = width - (padding * 2),
      height = selectedSummaryHeight,
    },
  }
end

local function containsPoint(rect, x, y)
  return x >= rect.x and x <= (rect.x + rect.width) and y >= rect.y and y <= (rect.y + rect.height)
end

function CoinDraftState:chooseOffer(app, coinId)
  local ok, doneOrError = app:chooseDraftCoin(coinId)

  if not ok then
    self.statusMessage = tostring(doneOrError)
    return false
  end

  if app.audioSystem then
    app.audioSystem:playCue("draft_select")
  end

  if doneOrError == true then
    return app.stateGraph:request("draft_complete")
  end

  self.statusMessage = "Coin added. New offers loaded."
  return true
end

function CoinDraftState:buildButtons(app)
  local layout = self:getLayout(app)
  local buttons = {}

  table.insert(buttons, {
    x = layout.width - Theme.spacing.screenPadding - 150,
    y = layout.footerMetrics.buttonY,
    width = 150,
    height = layout.footerMetrics.buttonHeight,
    label = "Pause",
    variant = "default",
    onClick = function()
      return app.stateGraph:request("open_pause")
    end,
  })

  self.buttons = buttons
  return buttons
end

function CoinDraftState:drawOfferCards(app, panelLayout)
  local mouseX, mouseY = love.mouse.getPosition()

  for _, entry in ipairs(panelLayout) do
    local card = entry.card
    local hovered = mouseX and mouseY and containsPoint(entry, mouseX, mouseY)

    Panel.draw(entry.x, entry.y, entry.width, entry.height)
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height)
    local artSize = math.min(86, math.max(54, math.floor(contentArea.width * 0.30)))
    local textX = contentArea.x + artSize + Theme.spacing.itemGap
    local textY = contentArea.y
    local textWidth = contentArea.width - artSize - Theme.spacing.itemGap

    CoinArt.draw(card.coinId, contentArea.x, contentArea.y, artSize, {
      selected = true,
      tilt = (entry.index % 2 == 0) and 0.08 or -0.08,
    })

    local lines = {
      string.format("%s", card.name or card.coinId),
      string.format("Rarity: %s", card.rarity or "n/a"),
      "",
      Terminology.getMechanicRichText(card.description),
    }

    Layout.drawWrappedLines(lines, textX, textY, textWidth, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height)

    if hovered then
      Theme.applyColor(Theme.colors.highlight)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", entry.x, entry.y, entry.width, entry.height)
      love.graphics.setLineWidth(1)
    end
  end
end

function CoinDraftState:drawCoinDetailOverlay(app, coinId, x, y)
  local coin = coinId and Coins.getById(coinId) or nil

  if not coin then
    return
  end

  local width = 330
  local height = 150
  local screenWidth = love.graphics.getWidth()
  local screenHeight = love.graphics.getHeight()
  local overlayX = math.min(x + 18, screenWidth - width - Theme.spacing.screenPadding)
  local overlayY = math.min(y + 18, screenHeight - height - Theme.spacing.screenPadding)

  overlayX = math.max(Theme.spacing.screenPadding, overlayX)
  overlayY = math.max(Theme.spacing.screenPadding, overlayY)

  love.graphics.setColor(0.03, 0.04, 0.07, 0.96)
  love.graphics.rectangle("fill", overlayX + 4, overlayY + 4, width, height)
  love.graphics.setColor(0.08, 0.10, 0.15, 0.98)
  love.graphics.rectangle("fill", overlayX, overlayY, width, height)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", overlayX, overlayY, width, height)
  love.graphics.setLineWidth(1)

  CoinArt.draw(coin, overlayX + 14, overlayY + 18, 62, { selected = true, tilt = -0.04 })
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(string.format("%s (%s)", coin.name, coin.rarity), overlayX + 90, overlayY + 16)
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  Layout.drawRichWrappedText(Terminology.getMechanicRichText(coin.description or ""), overlayX + 90, overlayY + 42, width - 106, Theme.colors.mutedText, app.fonts.small:getHeight() + 2, 68)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(string.format("Tags: %s", Terminology.formatTagList(coin.tags)), overlayX + 14, overlayY + 118, width - 28, "left")
end

function CoinDraftState:drawSelectedCoinSummary(app, area, session)
  Panel.draw(area.x, area.y, area.width, area.height, "Draft Slots")

  local contentArea = Panel.getContentArea(area.x, area.y, area.width, area.height, "Draft Slots")
  local pickedCoinIds = session.pickedCoinIds or {}
  local slotCount = math.max(session.totalPicks or 0, #pickedCoinIds)

  if slotCount == 0 then
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("No draft slots available.", contentArea.x, contentArea.y + 18, contentArea.width, "center")
    return nil
  end

  local mouseX, mouseY = love.mouse.getPosition()
  local gap = Theme.spacing.itemGap
  local itemHeight = math.min(58, contentArea.height)
  local itemWidth = math.floor((contentArea.width - (gap * (slotCount - 1))) / slotCount)
  local hoveredCoinId = nil

  for index = 1, slotCount do
    local coinId = pickedCoinIds[index]
    local coin = Coins.getById(coinId)
    local itemX = contentArea.x + ((index - 1) * (itemWidth + gap))
    local itemY = contentArea.y + math.floor((contentArea.height - itemHeight) / 2)
    local filled = coinId ~= nil
    local hovered = filled and mouseX and mouseY and mouseX >= itemX and mouseX <= itemX + itemWidth and mouseY >= itemY and mouseY <= itemY + itemHeight

    if hovered then
      hoveredCoinId = coinId
    end

    setColorWithAlpha(filled and (hovered and Theme.colors.accent or Theme.colors.panelBorder) or Theme.colors.panel, filled and 0.16 or 0.75)
    love.graphics.rectangle("fill", itemX, itemY, itemWidth, itemHeight, 8, 8)
    if filled then
      Theme.applyColor(hovered and Theme.colors.accent or Theme.colors.panelBorder)
    else
      setColorWithAlpha(Theme.colors.panelBorder, 0.75)
    end
    love.graphics.setLineWidth(hovered and 2 or 1)
    love.graphics.rectangle("line", itemX, itemY, itemWidth, itemHeight, 8, 8)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(app.fonts.small)

    if filled then
      CoinArt.draw(coinId, itemX + 9, itemY + 10, 38, { selected = hovered, glow = hovered })
      Theme.applyColor(Theme.colors.text)
      love.graphics.printf(coin and coin.name or coinId, itemX + 56, itemY + 20, math.max(1, itemWidth - 64), "left")
    end
  end

  return hoveredCoinId
end

function CoinDraftState:draw(app)
  local session = app:getDraftSession() or {}
  local layout = self:getLayout(app)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Coin Draft", 64, app.fonts.title, Theme.colors.text)

  love.graphics.setFont(app.fonts.body)
  local lines = {
    string.format("Draft picks remaining: %d/%d", session.picksRemaining or 0, session.totalPicks or 0),
    "Your purse starts with 5 Heads-Loaded Pennies and 5 Tails-Loaded Pennies. Each draft pick adds one special coin instance.",
    self.statusMessage,
  }
  Layout.drawWrappedLines(lines, layout.padding, layout.infoY, layout.width - (layout.padding * 2), Theme.colors.text, Theme.spacing.lineHeight, layout.infoHeight)

  self:drawOfferCards(app, layout.panelLayout)
  local hoveredSelectedCoinId = self:drawSelectedCoinSummary(app, layout.selectedSummary, session)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)

  if hoveredSelectedCoinId then
    self:drawCoinDetailOverlay(app, hoveredSelectedCoinId, mouseX, mouseY)
  end
end

function CoinDraftState:keypressed(app, key)
  if key == "escape" then
    app.stateGraph:request("open_pause")
  end
end

function CoinDraftState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)

  for _, entry in ipairs(layout.panelLayout) do
    if containsPoint(entry, x, y) then
      return self:chooseOffer(app, entry.card.coinId)
    end
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return CoinDraftState
