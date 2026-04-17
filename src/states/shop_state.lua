local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local ShopSystem = require("src.systems.shop_system")
local Theme = require("src.ui.theme")

local ShopState = {}
ShopState.__index = ShopState

function ShopState.new()
  return setmetatable({
    statusMessage = "",
    offerButtons = {},
    footerButtons = {},
  }, ShopState)
end

function ShopState:canBuyOffer(app, offer)
  return offer and not offer.purchased and app.runState.shopPoints >= offer.price
end

function ShopState:tryBuyOffer(app, offerIndex)
  local offer = app.shopOffers and app.shopOffers[offerIndex] or nil

  if not offer then
    self.statusMessage = "That shop offer is no longer available."
    return false, "offer_not_found"
  end

  if offer.purchased then
    self.statusMessage = "That offer has already been purchased."
    return false, "offer_already_purchased"
  end

  if app.runState.shopPoints < offer.price then
    self.statusMessage = "Not enough shop points for that offer."
    return false, "not_enough_shop_points"
  end

  local ok, result = app:purchaseShopOffer(offerIndex)

  if ok then
    local traceMessages = result and result.trace and result.trace.messages or {}
    self.statusMessage = traceMessages[1] or string.format("Purchased offer %d.", offerIndex)
  else
    self.statusMessage = result
  end

  return ok, result
end

function ShopState:canReroll(app)
  return ShopSystem.canReroll(app.runState, app.stageState, app.metaProjection)
end

function ShopState:tryReroll(app)
  if not self:canReroll(app) then
    self.statusMessage = "You cannot reroll the shop right now."
    return false, "cannot_reroll"
  end

  local ok, result = app:rerollShopOffers()

  if ok then
    local traceMessages = app.lastShopGenerationTrace and app.lastShopGenerationTrace.messages or {}
    self.statusMessage = traceMessages[1] or string.format("Rerolled shop offers using a %s reroll.", result)
  else
    self.statusMessage = result
  end

  return ok, result
end

function ShopState:tryContinue(app)
  return app.stateGraph:request("continue")
end

function ShopState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local infoY = padding + 34
  local infoHeight = 136
  local offerPanelY = infoY + infoHeight + gap
  local footerMetrics = Layout.getFooterMetrics(height, {
    statusHeight = 74,
  })
  local offerCount = math.max(1, #(app.shopOffers or {}))
  local columns = math.min(3, offerCount)
  local rows = math.max(1, math.ceil(offerCount / columns))
  local panelWidth = math.floor((width - (padding * 2) - (gap * (columns - 1))) / columns)
  local panelHeight = math.max(150, math.floor((footerMetrics.contentBottomY - offerPanelY - (gap * (rows - 1))) / rows))
  local panelLayout = {}

  for index, offer in ipairs(app.shopOffers or {}) do
    local row = math.floor((index - 1) / columns)
    local column = (index - 1) % columns
    local x = padding + (column * (panelWidth + gap))
    local y = offerPanelY + (row * (panelHeight + gap))

    table.insert(panelLayout, {
      index = index,
      offer = offer,
      x = x,
      y = y,
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
    offerPanelY = offerPanelY,
    footerMetrics = footerMetrics,
    panelLayout = panelLayout,
  }
end

function ShopState:buildOfferButtons(app, panelLayout)
  local buttons = {}

  for _, entry in ipairs(panelLayout) do
    local offer = entry.offer
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, string.format("Offer %d", entry.index))
    local buttonHeight = 38
    local buttonY = contentArea.y + contentArea.height - buttonHeight

    table.insert(buttons, {
      x = contentArea.x,
      y = buttonY,
      width = contentArea.width,
      height = buttonHeight,
      label = offer.purchased and "Purchased" or string.format("Buy Offer %d", entry.index),
      variant = "primary",
      disabled = not self:canBuyOffer(app, offer),
      onClick = function()
        return self:tryBuyOffer(app, entry.index)
      end,
    })
  end

  self.offerButtons = buttons
  return buttons
end

function ShopState:buildFooterButtons(app, layout)
  local padding = layout.padding
  local gap = Theme.spacing.itemGap
  local buttonWidth = math.floor((layout.width - (padding * 2) - gap) / 2)
  local buttonHeight = layout.footerMetrics.buttonHeight
  local y = layout.footerMetrics.buttonY
  local canReroll = self:canReroll(app)

  self.footerButtons = {
    {
      x = padding,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Reroll Shop",
      variant = "warning",
      disabled = not canReroll,
      onClick = function()
        return self:tryReroll(app)
      end,
    },
    {
      x = padding + buttonWidth + gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Continue",
      variant = "success",
      onClick = function()
        return self:tryContinue(app)
      end,
    },
  }

  return self.footerButtons
end

function ShopState:enter(app)
  self.statusMessage = string.format("Buy with buttons or 1-%d, reroll with the button or R, then continue when ready.", #app.shopOffers)
end

function ShopState:keypressed(app, key)
  local offerIndex = tonumber(key)

  if offerIndex and offerIndex >= 1 and offerIndex <= #app.shopOffers then
    self:tryBuyOffer(app, offerIndex)

    return
  end

  if key == "r" then
    self:tryReroll(app)

    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryContinue(app)
  end
end

function ShopState:draw(app)
  local upcomingStage = app:getUpcomingStageDefinition()
  local layout = self:getLayout(app)

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print("Shop", layout.padding, layout.padding)
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.print(string.format("Shop Points: %d", app.runState.shopPoints), layout.padding, layout.padding + 30)

  local infoLines = app:getShopStatusLines()
  if upcomingStage then
    table.insert(infoLines, 1, string.format("Next stage: %s", upcomingStage.label))

    if upcomingStage.variantName then
      table.insert(infoLines, 2, string.format("Variant: %s", upcomingStage.variantName))
    end
  end

  local traceLines = app:getShopTraceLines(4)

  if #traceLines > 0 then
    table.insert(infoLines, "")

    for _, line in ipairs(traceLines) do
      table.insert(infoLines, line)
    end
  end

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(infoLines, layout.padding, layout.infoY, layout.width - (layout.padding * 2), Theme.colors.mutedText, Theme.spacing.lineHeight, layout.infoHeight)

  for _, entry in ipairs(layout.panelLayout) do
    local index = entry.index
    local offer = entry.offer
    Panel.draw(entry.x, entry.y, entry.width, entry.height, string.format("Offer %d", index))
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, string.format("Offer %d", index))
    local buttonHeight = 38

    local lines = {
      string.format("%s", offer.name),
      string.format("Type: %s", offer.type),
      string.format("Rarity: %s", offer.rarity),
      string.format("Price: %d", offer.price),
      offer.purchased and "Status: purchased" or "Status: available",
      "",
      app:getOfferDescription(offer),
    }

    local metaLines = app:getOfferMetaLines(offer)

    if #metaLines > 0 then
      table.insert(lines, "")

      for _, line in ipairs(metaLines) do
        table.insert(lines, line)
      end
    end

    Layout.drawWrappedLines(lines, contentArea.x, contentArea.y, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height - (buttonHeight + 8))
  end

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildOfferButtons(app, layout.panelLayout), mouseX, mouseY)
  Button.drawButtons(self:buildFooterButtons(app, layout), mouseX, mouseY)

  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(self.statusMessage, layout.padding, layout.height - layout.footerMetrics.statusHeight + Theme.spacing.statusPadding, layout.width - (layout.padding * 2), "left")
end

function ShopState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)

  if Button.handleMousePressed(self:buildOfferButtons(app, layout.panelLayout), x, y) then
    return
  end

  Button.handleMousePressed(self:buildFooterButtons(app, layout), x, y)
end

return ShopState
