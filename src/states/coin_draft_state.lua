local Button = require("src.ui.button")
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

function CoinDraftState:buildButtons(app)
  local cards = app:getDraftOfferCards()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local cardWidth = 260
  local cardHeight = 260
  local gap = Theme.spacing.blockGap
  local totalWidth = (#cards * cardWidth) + (math.max(#cards - 1, 0) * gap)
  local startX = math.floor((width - totalWidth) / 2)
  local cardY = 210
  local buttons = {}

  for index, card in ipairs(cards) do
    local x = startX + ((index - 1) * (cardWidth + gap))
    table.insert(buttons, {
      id = card.coinId,
      x = x + 24,
      y = cardY + cardHeight - 58,
      width = cardWidth - 48,
      height = 42,
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
    x = width - Theme.spacing.screenPadding - 150,
    y = footerMetrics.buttonY,
    width = 150,
    height = footerMetrics.buttonHeight,
    label = "Pause",
    variant = "default",
    onClick = function()
      return app.stateGraph:request("open_pause")
    end,
  })

  self.buttons = buttons
  return buttons
end

function CoinDraftState:drawOfferCards(app, cards)
  local width = love.graphics.getWidth()
  local cardWidth = 260
  local cardHeight = 260
  local gap = Theme.spacing.blockGap
  local totalWidth = (#cards * cardWidth) + (math.max(#cards - 1, 0) * gap)
  local startX = math.floor((width - totalWidth) / 2)
  local cardY = 210

  for index, card in ipairs(cards) do
    local x = startX + ((index - 1) * (cardWidth + gap))
    Panel.draw(x, cardY, cardWidth, cardHeight, card.name)
    local content = Panel.getContentArea(x, cardY, cardWidth, cardHeight, card.name)
    local descriptionY = content.y + (Theme.spacing.lineHeight * 2)
    local lines = {
      string.format("Rarity: %s", card.rarity or "common"),
      "",
    }

    love.graphics.setFont(app.fonts.body)
    Layout.drawWrappedLines(lines, content.x, content.y, content.width, Theme.colors.text, Theme.spacing.lineHeight, content.height - 58)
    Layout.drawRichWrappedText(Terminology.getMechanicRichText(card.description or ""), content.x, descriptionY, content.width, Theme.colors.text, Theme.spacing.lineHeight, content.height - 58 - (Theme.spacing.lineHeight * 2))
  end
end

function CoinDraftState:draw(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local session = app:getDraftSession() or {}
  local cards = app:getDraftOfferCards()
  local padding = Theme.spacing.screenPadding

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Coin Draft", 64, app.fonts.title, Theme.colors.text)

  love.graphics.setFont(app.fonts.body)
  local lines = {
    string.format("Draft picks remaining: %d/%d", session.picksRemaining or 0, session.totalPicks or 0),
    "Your purse starts with 10 plain $ Coins. Each draft pick adds one special coin instance.",
    self.statusMessage,
  }
  Layout.drawWrappedLines(lines, padding, 118, width - (padding * 2), Theme.colors.text, Theme.spacing.lineHeight, 84)

  self:drawOfferCards(app, cards)

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
