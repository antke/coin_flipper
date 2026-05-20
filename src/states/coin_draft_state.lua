local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local CoinDraftState = {}
CoinDraftState.__index = CoinDraftState

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
  local offerCount = math.max(1, #cards)
  local columns = math.min(3, offerCount)
  local panelWidth = math.floor((width - (padding * 2) - (gap * (columns - 1))) / columns)
  local panelHeight = math.max(230, footerMetrics.contentBottomY - offerPanelY)
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
  }
end

function CoinDraftState:buildButtons(app)
  local layout = self:getLayout(app)
  local buttons = {}

  for _, entry in ipairs(layout.panelLayout) do
    local card = entry.card
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, string.format("Option %d", entry.index))
    local buttonHeight = 38

    table.insert(buttons, {
      id = card.coinId,
      x = contentArea.x,
      y = contentArea.y + contentArea.height - buttonHeight,
      width = contentArea.width,
      height = buttonHeight,
      label = "Draft",
      variant = "primary",
      onClick = function()
        local ok, doneOrError = app:chooseDraftCoin(card.coinId)

        if not ok then
          self.statusMessage = tostring(doneOrError)
          return false
        end

        if doneOrError == true then
          return app.stateGraph:request("draft_complete")
        end

        self.statusMessage = "Coin added. New offers loaded."
        return true
      end,
    })
  end

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
  for _, entry in ipairs(panelLayout) do
    local card = entry.card
    Panel.draw(entry.x, entry.y, entry.width, entry.height, string.format("Option %d", entry.index))
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, string.format("Option %d", entry.index))
    local buttonHeight = 38
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
      "Adds +1 coin instance to your purse.",
      "",
      Terminology.getMechanicRichText(card.description),
    }

    Layout.drawWrappedLines(lines, textX, textY, textWidth, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height - (buttonHeight + 8))
  end
end

function CoinDraftState:draw(app)
  local session = app:getDraftSession() or {}
  local layout = self:getLayout(app)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Coin Draft", 64, app.fonts.title, Theme.colors.text)

  love.graphics.setFont(app.fonts.body)
  local lines = {
    string.format("Draft picks remaining: %d/%d", session.picksRemaining or 0, session.totalPicks or 0),
    "Your purse starts with 10 plain $ Coins. Each draft pick adds one special coin instance.",
    self.statusMessage,
  }
  Layout.drawWrappedLines(lines, layout.padding, layout.infoY, layout.width - (layout.padding * 2), Theme.colors.text, Theme.spacing.lineHeight, layout.infoHeight)

  self:drawOfferCards(app, layout.panelLayout)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
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

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return CoinDraftState
