local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Coins = require("src.content.coins")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local PurseView = require("src.ui.purse_view")
local ShopSystem = require("src.systems.shop_system")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local ShopState = {}
ShopState.__index = ShopState

function ShopState.new()
  return setmetatable({
    statusMessage = "",
    offerButtons = {},
    footerButtons = {},
    purseDialogOpen = false,
    purseScrollButtons = {},
    purseScrollOffset = 0,
    fountainOverlayOpen = false,
    fountainScrollButtons = {},
    fountainScrollOffset = 0,
    fountainButtons = {},
    selectedFountainCoinId = nil,
    selectedFountainInstanceId = nil,
    fountainStatusMessage = "",
  }, ShopState)
end

function ShopState:canBuyOffer(app, offer)
  return offer and not offer.purchased and app.runState.influence >= offer.price
end

function ShopState:tryBuyOffer(app, offerIndex)
  local offer = app.shopOffers and app.shopOffers[offerIndex] or nil

  if not offer then
    self.statusMessage = "That Black Market offer is no longer available."
    return false, "offer_not_found"
  end

  if offer.purchased then
    self.statusMessage = "That offer has already been purchased."
    return false, "offer_already_purchased"
  end

  if app.runState.influence < offer.price then
    self.statusMessage = "Not enough Influence for that offer."
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
    self.statusMessage = "You cannot reroll the Black Market right now."
    return false, "cannot_reroll"
  end

  local ok, result = app:rerollShopOffers()

  if ok then
    local traceMessages = app.lastShopGenerationTrace and app.lastShopGenerationTrace.messages or {}
    self.statusMessage = traceMessages[1] or string.format("Rerolled Black Market offers using a %s reroll.", result)
  else
    self.statusMessage = result
  end

  return ok, result
end

function ShopState:tryContinue(app)
  return app.stateGraph:request("continue")
end

function ShopState:getFountainOptionForCoin(app, coinId)
  if not coinId then
    return nil
  end

  for _, option in ipairs(app:getFountainOptions() or {}) do
    if option.coinId == coinId then
      return option
    end
  end

  return nil
end

function ShopState:openFountain(app)
  local ok, result = app:prepareFountain("shop")

  if not ok then
    self.statusMessage = tostring(result)
    return false, result
  end

  local session = app:getFountainSession()
  local selectedInstanceId = session and session.selectedInstanceId or nil
  self.purseDialogOpen = false
  self.fountainOverlayOpen = true
  self.fountainScrollOffset = 0
  self.selectedFountainInstanceId = selectedInstanceId
  self.selectedFountainCoinId = nil
  self.fountainStatusMessage = (session and session.sacrificed) and "YOU FEEL LUCKY." or "Select a coin from your pouch."

  if selectedInstanceId then
    for _, option in ipairs(app:getFountainOptions() or {}) do
      if option.instanceId == selectedInstanceId then
        self.selectedFountainCoinId = option.coinId
        break
      end
    end
  end

  return true
end

function ShopState:closeFountain()
  self.fountainOverlayOpen = false
  self.selectedFountainCoinId = nil
  self.selectedFountainInstanceId = nil
  return true
end

function ShopState:selectFountainCoin(app, coinId)
  local session = app:getFountainSession()

  if session and session.sacrificed == true then
    self.fountainStatusMessage = "YOU FEEL LUCKY."
    return false, "fountain_already_used"
  end

  local option = self:getFountainOptionForCoin(app, coinId)

  if not option then
    self.fountainStatusMessage = "That coin cannot be sacrificed."
    return false, "coin_not_found"
  end

  self.selectedFountainCoinId = coinId
  self.selectedFountainInstanceId = option.instanceId
  app:selectFountainCoin(option.instanceId, "shop")

  if option.disabled then
    self.fountainStatusMessage = option.disabledReason == "last_coin_required"
      and "The fountain will not take your final coin."
      or "That coin cannot be sacrificed."
  else
    self.fountainStatusMessage = string.format("%s selected.", option.name or option.coinId)
  end

  return true
end

function ShopState:trySacrificeFountainCoin(app)
  local option = self:getFountainOptionForCoin(app, self.selectedFountainCoinId)

  if not option or not self.selectedFountainInstanceId then
    self.fountainStatusMessage = "Select a coin to sacrifice."
    return false, "coin_required"
  end

  if option.disabled then
    self.fountainStatusMessage = option.disabledReason == "last_coin_required"
      and "The fountain will not take your final coin."
      or "That coin cannot be sacrificed."
    return false, option.disabledReason or "option_disabled"
  end

  local ok, result = app:sacrificeFountainCoin(self.selectedFountainInstanceId, "shop")

  if ok then
    self.fountainStatusMessage = "YOU FEEL LUCKY."
    self.selectedFountainCoinId = nil
    self.selectedFountainInstanceId = nil
  else
    self.fountainStatusMessage = tostring(result)
  end

  return ok, result
end

function ShopState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local infoY = padding + 76
  local infoHeight = 64
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
      label = offer.purchased and "Purchased" or "Buy",
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
  local buttonWidth = math.floor((layout.width - (padding * 2) - (gap * 3)) / 4)
  local buttonHeight = layout.footerMetrics.buttonHeight
  local y = layout.footerMetrics.buttonY
  local canReroll = self:canReroll(app)

  self.footerButtons = {
    {
      x = padding,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Reroll Market",
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
      label = "Lucky Fountain",
      variant = "warning",
      onClick = function()
        return self:openFountain(app)
      end,
    },
    {
      x = padding + ((buttonWidth + gap) * 2),
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Inspect Pouch",
      variant = "default",
      onClick = function()
        self.purseScrollOffset = 0
        self.purseDialogOpen = true
        return true
      end,
    },
    {
      x = padding + ((buttonWidth + gap) * 3),
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
  self.purseDialogOpen = false
  self.purseScrollOffset = 0
  self.fountainOverlayOpen = false
  self.fountainScrollOffset = 0
  self.selectedFountainCoinId = nil
  self.selectedFountainInstanceId = nil
  self.fountainStatusMessage = ""
  self.statusMessage = "Choose an offer, reroll, or continue."
end

function ShopState:getPurseDialogLayout()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local inset = math.max(Theme.scale(8), math.floor(padding / 2))
  local dialogWidth = math.max(Theme.scale(280), width - (inset * 2))
  local dialogHeight = math.max(Theme.scale(260), height - (inset * 2))

  return {
    x = math.floor((width - dialogWidth) / 2),
    y = math.floor((height - dialogHeight) / 2),
    width = dialogWidth,
    height = dialogHeight,
  }
end

function ShopState:getPurseCloseButton(dialog)
  local size = Theme.scale(32)

  return {
    x = dialog.x + dialog.width - Theme.spacing.panelPadding - size,
    y = dialog.y + Theme.spacing.panelPadding - Theme.scale(4),
    width = size,
    height = size,
    label = "X",
    onClick = function()
      self.purseDialogOpen = false
      return true
    end,
  }
end

function ShopState:scrollPurse(app, direction)
  local dialog = self:getPurseDialogLayout()
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")
  local maxScrollOffset = PurseView.getMaxScrollOffset(app, contentArea, nil)

  self.purseScrollOffset = math.max(0, math.min((self.purseScrollOffset or 0) + direction, maxScrollOffset))
  return true
end

function ShopState:drawPurseDialog(app)
  if not self.purseDialogOpen then
    return
  end

  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local dialog = self:getPurseDialogLayout()
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")
  local mouseX, mouseY = love.mouse.getPosition()

  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, width, height)
  Panel.draw(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")
  Button.drawButtons({ self:getPurseCloseButton(dialog) }, mouseX, mouseY)
  local maxPurseScrollOffset = PurseView.getMaxScrollOffset(app, contentArea, nil)
  self.purseScrollOffset = math.max(0, math.min(self.purseScrollOffset or 0, maxPurseScrollOffset))

  PurseView.draw(app, contentArea, nil, {
    scrollOffset = self.purseScrollOffset,
  })
  self.purseScrollButtons = PurseView.getScrollButtons(
    contentArea,
    self.purseScrollOffset,
    maxPurseScrollOffset,
    function()
      return self:scrollPurse(app, -1)
    end,
    function()
      return self:scrollPurse(app, 1)
    end
  )
  Button.drawButtons(self.purseScrollButtons, mouseX, mouseY)
end

function ShopState:getFountainOverlayLayout()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = math.max(Theme.scale(8), math.floor(Theme.spacing.screenPadding / 2))
  local gap = Theme.spacing.blockGap
  local x = padding
  local y = padding
  local overlayWidth = width - (padding * 2)
  local overlayHeight = height - (padding * 2)
  local purseWidth = math.floor((overlayWidth - gap) * 0.75)
  local fountainWidth = overlayWidth - purseWidth - gap

  return {
    x = x,
    y = y,
    width = overlayWidth,
    height = overlayHeight,
    purse = {
      x = x,
      y = y,
      width = purseWidth,
      height = overlayHeight,
    },
    fountain = {
      x = x + purseWidth + gap,
      y = y,
      width = fountainWidth,
      height = overlayHeight,
    },
  }
end

function ShopState:getFountainCloseButton(layout)
  local size = Theme.scale(32)

  return {
    x = layout.x + layout.width - Theme.spacing.panelPadding - size,
    y = layout.y + Theme.spacing.panelPadding - Theme.scale(4),
    width = size,
    height = size,
    label = "X",
    onClick = function()
      return self:closeFountain()
    end,
  }
end

function ShopState:scrollFountainPurse(app, direction)
  local layout = self:getFountainOverlayLayout()
  local contentArea = Panel.getContentArea(layout.purse.x, layout.purse.y, layout.purse.width, layout.purse.height, "Pouch")
  local maxScrollOffset = PurseView.getMaxScrollOffset(app, contentArea, nil, { includeTricks = false })

  self.fountainScrollOffset = math.max(0, math.min((self.fountainScrollOffset or 0) + direction, maxScrollOffset))
  return true
end

function ShopState:buildFountainButtons(app, layout)
  local session = app:getFountainSession()
  local option = self:getFountainOptionForCoin(app, self.selectedFountainCoinId)
  local alreadySacrificed = session and session.sacrificed == true
  local buttonHeight = Theme.componentMetrics.buttonHeight
  local buttonY = layout.fountain.y + layout.fountain.height - Theme.spacing.panelPadding - buttonHeight - Theme.scale(42)
  local sacrificeEnabled = self.selectedFountainInstanceId ~= nil and option ~= nil and not option.disabled and not alreadySacrificed

  self.fountainButtons = {
    self:getFountainCloseButton(layout),
    {
      x = layout.fountain.x + Theme.spacing.panelPadding,
      y = buttonY,
      width = layout.fountain.width - (Theme.spacing.panelPadding * 2),
      height = buttonHeight,
      label = alreadySacrificed and "Fountain Spent" or "Sacrifice",
      variant = sacrificeEnabled and "warning" or "default",
      focused = sacrificeEnabled,
      disabled = not sacrificeEnabled,
      onClick = function()
        return self:trySacrificeFountainCoin(app)
      end,
    },
  }

  return self.fountainButtons
end

function ShopState:drawFountainGraphic(app, area)
  local centerX = area.x + math.floor(area.width / 2)
  local topY = area.y + Theme.scale(26)
  local basinY = area.y + math.floor(area.height * 0.48)
  local basinWidth = math.floor(area.width * 0.82)
  local bowlWidth = math.floor(area.width * 0.58)

  Theme.applyColor({ Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 0.22 })
  love.graphics.circle("fill", centerX, topY + Theme.scale(34), Theme.scale(50))
  Theme.applyColor(Theme.colors.accent)
  love.graphics.setLineWidth(2)
  love.graphics.arc("line", "open", centerX, topY + Theme.scale(44), Theme.scale(42), math.rad(205), math.rad(335))
  love.graphics.line(centerX, topY + Theme.scale(2), centerX, basinY - Theme.scale(28))
  love.graphics.setLineWidth(1)

  Theme.applyColor(Theme.colors.warning)
  love.graphics.rectangle("fill", centerX - Theme.scale(12), basinY - Theme.scale(70), Theme.scale(24), Theme.scale(72), Theme.scale(8), Theme.scale(8))
  love.graphics.ellipse("fill", centerX, basinY - Theme.scale(74), bowlWidth / 2, Theme.scale(18))
  love.graphics.ellipse("line", centerX, basinY - Theme.scale(74), bowlWidth / 2, Theme.scale(18))

  Theme.applyColor(Theme.colors.panelBorder)
  love.graphics.ellipse("fill", centerX, basinY, basinWidth / 2, Theme.scale(34))
  Theme.applyColor(Theme.colors.accent)
  love.graphics.ellipse("fill", centerX, basinY - Theme.scale(5), basinWidth / 2 - Theme.scale(14), Theme.scale(20))
  Theme.applyColor(Theme.colors.warning)
  love.graphics.ellipse("line", centerX, basinY, basinWidth / 2, Theme.scale(34))

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf("Lucky Fountain", area.x, basinY + Theme.scale(50), area.width, "center")
end

function ShopState:drawFountainOverlay(app)
  if not self.fountainOverlayOpen then
    return
  end

  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local layout = self:getFountainOverlayLayout()
  local purseContentArea = Panel.getContentArea(layout.purse.x, layout.purse.y, layout.purse.width, layout.purse.height, "Pouch")
  local fountainContentArea = Panel.getContentArea(layout.fountain.x, layout.fountain.y, layout.fountain.width, layout.fountain.height, "Lucky Fountain")
  local mouseX, mouseY = love.mouse.getPosition()

  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, width, height)
  Panel.draw(layout.purse.x, layout.purse.y, layout.purse.width, layout.purse.height, "Pouch")
  Panel.draw(layout.fountain.x, layout.fountain.y, layout.fountain.width, layout.fountain.height, "Lucky Fountain")

  local maxPurseScrollOffset = PurseView.getMaxScrollOffset(app, purseContentArea, nil, { includeTricks = false })
  self.fountainScrollOffset = math.max(0, math.min(self.fountainScrollOffset or 0, maxPurseScrollOffset))

  PurseView.draw(app, purseContentArea, nil, {
    scrollOffset = self.fountainScrollOffset,
    selectedCoinId = self.selectedFountainCoinId,
    includeTricks = false,
    note = "Pick a coin for the fountain.",
  })
  self.fountainScrollButtons = PurseView.getScrollButtons(
    purseContentArea,
    self.fountainScrollOffset,
    maxPurseScrollOffset,
    function()
      return self:scrollFountainPurse(app, -1)
    end,
    function()
      return self:scrollFountainPurse(app, 1)
    end
  )

  self:drawFountainGraphic(app, fountainContentArea)

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(
    self.fountainStatusMessage or "",
    fountainContentArea.x,
    layout.fountain.y + layout.fountain.height - Theme.spacing.panelPadding - Theme.scale(34),
    fountainContentArea.width,
    "center"
  )

  Button.drawButtons(self:buildFountainButtons(app, layout), mouseX, mouseY)
  Button.drawButtons(self.fountainScrollButtons, mouseX, mouseY)
end

function ShopState:keypressed(app, key)
  if self.fountainOverlayOpen then
    if key == "escape" then
      self:closeFountain()
    elseif key == "up" then
      self:scrollFountainPurse(app, -1)
    elseif key == "down" then
      self:scrollFountainPurse(app, 1)
    elseif key == "return" or key == "space" or key == "kpenter" then
      self:trySacrificeFountainCoin(app)
    end

    return
  end

  if self.purseDialogOpen then
    if key == "escape" or key == "p" or key == "return" or key == "kpenter" then
      self.purseDialogOpen = false
    elseif key == "up" then
      self:scrollPurse(app, -1)
    elseif key == "down" then
      self:scrollPurse(app, 1)
    end

    return
  end

  local offerIndex = tonumber(key)

  if offerIndex and offerIndex >= 1 and offerIndex <= #app.shopOffers then
    self:tryBuyOffer(app, offerIndex)

    return
  end

  if key == "r" then
    self:tryReroll(app)

    return
  end

  if key == "p" then
    self.purseScrollOffset = 0
    self.purseDialogOpen = true
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryContinue(app)
  end
end

function ShopState:draw(app)
  local layout = self:getLayout(app)

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print("Black Market", layout.padding, layout.padding)
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.print(string.format("Influence: %d", app.runState.influence), layout.padding, layout.padding + 44)

  local infoLines = {
    string.format("Free rerolls: %d", app.runState.shopRerollsRemaining or 0),
  }

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(infoLines, layout.padding, layout.infoY, layout.width - (layout.padding * 2), Theme.colors.mutedText, Theme.spacing.lineHeight, layout.infoHeight)

  for _, entry in ipairs(layout.panelLayout) do
    local index = entry.index
    local offer = entry.offer
    Panel.draw(entry.x, entry.y, entry.width, entry.height, string.format("Offer %d", index))
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, string.format("Offer %d", index))
    local buttonHeight = 38

    local artSize = math.min(86, math.max(54, math.floor(contentArea.width * 0.30)))
    local textX = contentArea.x
    local textY = contentArea.y
    local textWidth = contentArea.width

    if offer.type == "coin" then
      local coinDefinition = Coins.getById(offer.contentId)
      CoinArt.draw(coinDefinition or offer.contentId, contentArea.x, contentArea.y, artSize, {
        selected = not offer.purchased,
        tilt = (index % 2 == 0) and 0.08 or -0.08,
      })
      textX = contentArea.x + artSize + Theme.spacing.itemGap
      textWidth = contentArea.width - artSize - Theme.spacing.itemGap
    else
      love.graphics.setColor(Theme.colors.highlight[1], Theme.colors.highlight[2], Theme.colors.highlight[3], 0.18)
      love.graphics.rectangle("fill", contentArea.x, contentArea.y, artSize, artSize, 10, 10)
      Theme.applyColor(Theme.colors.highlight)
      love.graphics.rectangle("line", contentArea.x, contentArea.y, artSize, artSize, 10, 10)
      love.graphics.setFont(app.fonts.heading)
      love.graphics.printf("TR", contentArea.x, contentArea.y + math.floor((artSize - Theme.spacing.lineHeight) / 2), artSize, "center")
      textX = contentArea.x + artSize + Theme.spacing.itemGap
      textWidth = contentArea.width - artSize - Theme.spacing.itemGap
    end

    local lines = {
      string.format("%s", offer.name),
      string.format("Price: %d Influence", offer.price),
      "",
      Terminology.getMechanicRichText(app:getOfferDescription(offer)),
    }

    Layout.drawWrappedLines(lines, textX, textY, textWidth, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height - (buttonHeight + 8))
  end

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildOfferButtons(app, layout.panelLayout), mouseX, mouseY)
  Button.drawButtons(self:buildFooterButtons(app, layout), mouseX, mouseY)

  if self.statusMessage ~= "" then
    Theme.applyColor(Theme.colors.warning)
    love.graphics.printf(self.statusMessage, layout.padding, layout.height - layout.footerMetrics.statusHeight + Theme.spacing.statusPadding, layout.width - (layout.padding * 2), "left")
  end
  self:drawPurseDialog(app)
  self:drawFountainOverlay(app)
end

function ShopState:wheelmoved(app, _, y)
  if self.fountainOverlayOpen and y ~= 0 then
    local mouseX, mouseY = love.mouse.getPosition()
    local layout = self:getFountainOverlayLayout()
    local contentArea = Panel.getContentArea(layout.purse.x, layout.purse.y, layout.purse.width, layout.purse.height, "Pouch")

    if Button.containsPoint(contentArea, mouseX, mouseY) then
      self:scrollFountainPurse(app, y > 0 and -1 or 1)
    end

    return
  end

  if not self.purseDialogOpen or y == 0 then
    return
  end

  local mouseX, mouseY = love.mouse.getPosition()
  local dialog = self:getPurseDialogLayout()
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")

  if Button.containsPoint(contentArea, mouseX, mouseY) then
    self:scrollPurse(app, y > 0 and -1 or 1)
  end
end

function ShopState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  if self.fountainOverlayOpen then
    local layout = self:getFountainOverlayLayout()
    local purseContentArea = Panel.getContentArea(layout.purse.x, layout.purse.y, layout.purse.width, layout.purse.height, "Pouch")

    if Button.handleMousePressed(self:buildFountainButtons(app, layout), x, y) then
      return
    end

    if Button.handleMousePressed(self.fountainScrollButtons, x, y) then
      return
    end

    local card = PurseView.getCardAtPoint(app, purseContentArea, nil, x, y, {
      scrollOffset = self.fountainScrollOffset,
      includeTricks = false,
    })

    if card then
      self:selectFountainCoin(app, card.coinId)
    end

    return
  end

  local layout = self:getLayout(app)

  if self.purseDialogOpen then
    local dialog = self:getPurseDialogLayout()

    if Button.handleMousePressed({ self:getPurseCloseButton(dialog) }, x, y) then
      return
    end

    if Button.handleMousePressed(self.purseScrollButtons, x, y) then
      return
    end

    if x < dialog.x or x > dialog.x + dialog.width or y < dialog.y or y > dialog.y + dialog.height then
      self.purseDialogOpen = false
    end

    return
  end

  if Button.handleMousePressed(self:buildOfferButtons(app, layout.panelLayout), x, y) then
    return
  end

  Button.handleMousePressed(self:buildFooterButtons(app, layout), x, y)
end

return ShopState
