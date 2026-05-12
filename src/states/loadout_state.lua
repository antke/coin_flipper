local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Coins = require("src.content.coins")
local GameConfig = require("src.app.config")
local Layout = require("src.ui.layout")
local Loadout = require("src.domain.loadout")
local LoadoutSystem = require("src.systems.loadout_system")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local LoadoutState = {}
LoadoutState.__index = LoadoutState

local COLLECTION_CARD_WIDTH = 158
local COLLECTION_CARD_HEIGHT = 104
local COLLECTION_CARD_GAP = 12
local SCROLL_BUTTON_WIDTH = 30

function LoadoutState.new()
  return setmetatable({
    selectedCollectionIndex = 1,
    collectionScrollOffset = 1,
    selectionSlots = {},
    reconciliation = nil,
    statusMessage = "",
    collectionButtons = {},
    actionButtons = {},
    slotRects = {},
    dragCoinId = nil,
    dragStartX = nil,
    dragStartY = nil,
    detailCoinId = nil,
  }, LoadoutState)
end

local function getDistanceSquared(x1, y1, x2, y2)
  local dx = (x2 or 0) - (x1 or 0)
  local dy = (y2 or 0) - (y1 or 0)
  return (dx * dx) + (dy * dy)
end

local function getVisibleCardCount(width)
  return math.max(1, math.floor((width + COLLECTION_CARD_GAP) / (COLLECTION_CARD_WIDTH + COLLECTION_CARD_GAP)))
end

local function drawNumberBadge(app, number, x, y, size)
  size = size or 24
  love.graphics.setColor(0.03, 0.04, 0.07, 1.0)
  love.graphics.circle("fill", x + (size / 2), y + (size / 2), size / 2)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.circle("line", x + (size / 2), y + (size / 2), size / 2)
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(tostring(number), x, y + math.floor((size - app.fonts.small:getHeight()) / 2), size, "center")
end

function LoadoutState:clampCollectionOffset(app, visibleRows)
  local maxOffset = math.max(1, #app.runState.collectionCoinIds - visibleRows + 1)
  self.collectionScrollOffset = math.max(1, math.min(self.collectionScrollOffset, maxOffset))
end

function LoadoutState:ensureSelectedCoinVisible(app, visibleRows)
  self:clampCollectionOffset(app, visibleRows)

  if self.selectedCollectionIndex < self.collectionScrollOffset then
    self.collectionScrollOffset = self.selectedCollectionIndex
  elseif self.selectedCollectionIndex > (self.collectionScrollOffset + visibleRows - 1) then
    self.collectionScrollOffset = self.selectedCollectionIndex - visibleRows + 1
  end

  self:clampCollectionOffset(app, visibleRows)
end

function LoadoutState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local panelY = 82
  local footerMetrics = Layout.getFooterMetrics(height, {
    buttonHeight = 38,
    buttonRows = 1,
    statusHeight = 44,
    extraSpacing = Theme.spacing.statusPadding,
  })
  local availableHeight = math.max(220, footerMetrics.contentBottomY - panelY)
  local contentWidth = width - (padding * 2)
  local topHeight = math.min(170, math.floor(availableHeight * 0.34))
  local slotY = panelY + topHeight + gap
  local slotHeight = availableHeight - topHeight - gap

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    headerY = padding,
    panelY = panelY,
    footerMetrics = footerMetrics,
    availableHeight = availableHeight,
    contentWidth = contentWidth,
    topHeight = topHeight,
    slotY = slotY,
    slotHeight = slotHeight,
  }
end

function LoadoutState:selectCollectionIndex(app, index)
  self.selectedCollectionIndex = math.max(1, math.min(index, #app.runState.collectionCoinIds))
  self:ensureSelectedCoinVisible(app, self.collectionVisibleRows or 1)
end

function LoadoutState:getReconciliationLines(app)
  local details = self.reconciliation

  if not details then
    return { "Persisted build: n/a" }
  end

  local lines = {
    string.format("Persisted build: %s", self:formatBuildSummary(details.originalSlots, app.runState.maxActiveCoinSlots)),
  }

  if details.usedFallback then
    table.insert(lines, string.format("Reconciled persisted build: %s", self:formatBuildSummary(details.reconciledSlots, app.runState.maxActiveCoinSlots)))
  end

  table.insert(lines, string.format("Prepared build: %s", self:formatBuildSummary(details.preparedSlots, app.runState.maxActiveCoinSlots)))

  if details.usedFallback then
    local fallbackMessage = details.fallbackReason == "persisted_invalid"
      and "Fallback build prepared because the persisted build was no longer valid."
      or "Fallback build prepared because no persisted build was available."
    table.insert(lines, fallbackMessage)
  elseif details.changed then
    table.insert(lines, "Persisted build was reconciled before stage start.")
  else
    table.insert(lines, "Persisted build is still valid.")
  end

  if #(details.changes or {}) > 0 then
    table.insert(lines, "")
    table.insert(lines, "Reconciliation:")

    for _, change in ipairs(details.changes) do
      if change.reason == "not_owned" then
        table.insert(lines, string.format("- Slot %d cleared: %s is no longer owned.", change.slotIndex, app:getCoinName(change.coinId)))
      elseif change.reason == "duplicate" then
        table.insert(lines, string.format("- Slot %d cleared: duplicate %s (kept slot %d).", change.slotIndex, app:getCoinName(change.coinId), change.keptSlotIndex or 0))
      elseif change.reason == "fallback_fill" then
        table.insert(lines, string.format("- Slot %d filled from collection: %s.", change.slotIndex, app:getCoinName(change.coinId)))
      end
    end
  end

  return lines
end

function LoadoutState:formatBuildSummary(slots, maxSlots)
      if GameConfig.get("flip.orderMode") == "slot_order" then
    local parts = {}

    for slotIndex = 1, maxSlots do
      local coinId = slots and slots[slotIndex] or nil
      local definition = coinId and Coins.getById(coinId) or nil
      table.insert(parts, string.format("%d:%s", slotIndex, definition and definition.name or coinId or "-"))
    end

    return table.concat(parts, " | ")
  end

  local key = Loadout.toCanonicalKey(slots, maxSlots)
  return key ~= "" and key or "(empty)"
end

function LoadoutState:getSelectionStatusMessage(app, reconciliation)
  if not reconciliation then
    return "Review your build, then click Start Stage or press Enter."
  end

  if reconciliation.usedFallback then
    if reconciliation.fallbackReason == "persisted_invalid" then
      return "Persisted build was invalid, so a fallback build was prepared."
    end

    return "No persisted build was available, so a fallback build was prepared."
  end

  if reconciliation.changed then
    return "Persisted build was reconciled. Review the slot notes before starting."
  end

  return "Click coin = next slot. Drag coin = chosen slot. Click slot = clear."
end

function LoadoutState:getFirstOpenSlot(app)
  for slotIndex = 1, app.runState.maxActiveCoinSlots do
    if not self.selectionSlots[slotIndex] then
      return slotIndex
    end
  end

  return nil
end

function LoadoutState:assignCoinToNextOpenSlot(app, coinId)
  local slotIndex = self:getFirstOpenSlot(app)

  if not slotIndex then
    self.statusMessage = "Build full. Drop on a slot to replace, or click a slot to clear."
    return false, "no_open_slot"
  end

  self.selectionSlots = LoadoutSystem.assignCoinToSlot(app.runState, self.selectionSlots, coinId, slotIndex)
  self.statusMessage = string.format("Added %s to slot %d.", app:getCoinName(coinId), slotIndex)
  return true
end

function LoadoutState:scrollCollection(app, direction)
  self.collectionScrollOffset = self.collectionScrollOffset + direction
  self:clampCollectionOffset(app, self.collectionVisibleRows or 1)
  return true
end

function LoadoutState:assignSelectedCoinToSlot(app, slotIndex)
  local coinId = app.runState.collectionCoinIds[self.selectedCollectionIndex]

  if not coinId then
    self.statusMessage = "No coin is currently selected."
    return false, "no_coin_selected"
  end

  self.selectionSlots = LoadoutSystem.assignCoinToSlot(app.runState, self.selectionSlots, coinId, slotIndex)
  self.statusMessage = string.format("Assigned %s to slot %d.", app:getCoinName(coinId), slotIndex)
  return true
end

function LoadoutState:clearSelectedSlot(app, slotIndex)
  self.selectionSlots = LoadoutSystem.clearSlot(app.runState, self.selectionSlots, slotIndex)
  self.statusMessage = string.format("Cleared slot %d.", slotIndex)
  return true
end

function LoadoutState:resetSelection(app)
  self.selectionSlots, self.reconciliation = LoadoutSystem.createSelection(app.runState)
  self.statusMessage = self:getSelectionStatusMessage(app, self.reconciliation)
  return true
end

function LoadoutState:tryStartStage(app)
  app:ensureCurrentStage()

  local committedSlots, errorMessage = app:commitLoadout(self.selectionSlots)

  if committedSlots then
    self.statusMessage = string.format("Locked build %s", Loadout.toCanonicalKey(committedSlots, app.runState.maxActiveCoinSlots))
    return app.stateGraph:request("stage_ready")
  end

  self.statusMessage = errorMessage
  return false, errorMessage
end

function LoadoutState:buildCollectionButtons(app, area)
  local buttons = {}
  local gap = COLLECTION_CARD_GAP
  local overflow = #app.runState.collectionCoinIds > getVisibleCardCount(area.width)
  local listX = area.x
  local listWidth = area.width

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = area.y + math.floor((COLLECTION_CARD_HEIGHT - 42) / 2),
      width = SCROLL_BUTTON_WIDTH,
      height = 42,
      label = "<",
      variant = "warning",
      disabled = self.collectionScrollOffset <= 1,
      onClick = function()
        return self:scrollCollection(app, -1)
      end,
    })

    listX = listX + SCROLL_BUTTON_WIDTH + gap
    listWidth = listWidth - ((SCROLL_BUTTON_WIDTH + gap) * 2)
  end

  local visibleCards = getVisibleCardCount(listWidth)
  self.collectionVisibleRows = visibleCards
  self:ensureSelectedCoinVisible(app, visibleCards)

  local startIndex = self.collectionScrollOffset
  local endIndex = math.min(#app.runState.collectionCoinIds, startIndex + visibleCards - 1)

  for index = startIndex, endIndex do
    local coinId = app.runState.collectionCoinIds[index]

    local equippedMarker = ""
    local equippedSlotIndex = nil

    for slot = 1, app.runState.maxActiveCoinSlots do
      if self.selectionSlots[slot] == coinId then
        equippedMarker = string.format(" [slot %d]", slot)
        equippedSlotIndex = slot
        break
      end
    end

    table.insert(buttons, {
      x = listX + ((index - startIndex) * (COLLECTION_CARD_WIDTH + gap)),
      y = area.y,
      width = COLLECTION_CARD_WIDTH,
      height = COLLECTION_CARD_HEIGHT,
      coinId = coinId,
      equippedSlotIndex = equippedSlotIndex,
      label = string.format("%s%s", app:getCoinName(coinId), equippedMarker),
      focused = index == self.selectedCollectionIndex,
      variant = index == self.selectedCollectionIndex and "primary" or "default",
      onClick = function()
        self:selectCollectionIndex(app, index)
        return true
      end,
    })
  end

  if overflow then
    table.insert(buttons, {
      x = area.x + area.width - SCROLL_BUTTON_WIDTH,
      y = area.y + math.floor((COLLECTION_CARD_HEIGHT - 42) / 2),
      width = SCROLL_BUTTON_WIDTH,
      height = 42,
      label = ">",
      variant = "warning",
      disabled = endIndex >= #app.runState.collectionCoinIds,
      onClick = function()
        return self:scrollCollection(app, 1)
      end,
    })
  end

  self.collectionButtons = buttons
  return buttons
end

function LoadoutState:drawCollectionCards(app, buttons, mouseX, mouseY)
  for _, button in ipairs(buttons or {}) do
    if button.coinId then
      local coin = Coins.getById(button.coinId)
      local hovered = mouseX and mouseY and Button.containsPoint(button, mouseX, mouseY)
      local selected = button.focused or hovered

      love.graphics.setColor(0.04, 0.05, 0.08, 0.94)
      love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
      Theme.applyColor(selected and Theme.colors.accent or Theme.colors.panelBorder)
      love.graphics.setLineWidth(selected and 3 or 1)
      love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
      love.graphics.setLineWidth(1)

      CoinArt.draw(button.coinId, button.x + math.floor((button.width - 56) / 2), button.y + 12, 56, {
        selected = selected,
        tilt = selected and -0.05 or 0.02,
      })

      love.graphics.setFont(app.fonts.body)
      Theme.applyColor(Theme.colors.text)
      love.graphics.printf(coin and coin.name or button.coinId, button.x + 8, button.y + 74, button.width - 16, "center")

      if button.equippedSlotIndex then
        drawNumberBadge(app, button.equippedSlotIndex, button.x + button.width - 32, button.y + 8, 24)
      end
    else
      Button.drawTextButton(button.x, button.y, button.width, button.height, button.label, {
        disabled = button.disabled,
        variant = button.variant,
      })
    end
  end
end

function LoadoutState:getCoinButtonAtPoint(x, y)
  for _, button in ipairs(self.collectionButtons or {}) do
    if button.coinId and Button.containsPoint(button, x, y) then
      return button
    end
  end

  return nil
end

function LoadoutState:drawCoinDetailOverlay(app, coinId, x, y)
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
  love.graphics.printf(coin.description, overlayX + 90, overlayY + 42, width - 106, "left")
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(string.format("Tags: %s", table.concat(coin.tags or {}, ", ")), overlayX + 14, overlayY + 118, width - 28, "left")
end

function LoadoutState:buildActionButtons(app, layout)
  local padding = layout.padding
  local gap = Theme.spacing.itemGap
  local rowWidth = layout.width - (padding * 2)
  local buttonHeight = layout.footerMetrics.buttonHeight
  local actionY = layout.footerMetrics.buttonY
  local buttons = {}

  local actionWidth = math.floor((rowWidth - (gap * 2)) / 3)

  table.insert(buttons, {
    x = padding,
    y = actionY,
    width = actionWidth,
    height = buttonHeight,
    label = "< MENU",
    variant = "warning",
    onClick = function()
      return app.stateGraph:request("cancel_to_menu")
    end,
  })

  table.insert(buttons, {
    x = padding + actionWidth + gap,
    y = actionY,
    width = actionWidth,
    height = buttonHeight,
    label = "RESET",
    variant = "default",
    onClick = function()
      return self:resetSelection(app)
    end,
  })

  table.insert(buttons, {
    x = padding + ((actionWidth + gap) * 2),
    y = actionY,
    width = actionWidth,
    height = buttonHeight,
    label = "START",
    variant = "success",
    onClick = function()
      return self:tryStartStage(app)
    end,
  })

  self.actionButtons = buttons
  return buttons
end

function LoadoutState:enter(app, payload)
  self.selectionSlots, self.reconciliation = LoadoutSystem.createSelection(app.runState)
  self.collectionScrollOffset = 1
  self:selectCollectionIndex(app, self.selectedCollectionIndex)
  self.statusMessage = self:getSelectionStatusMessage(app, self.reconciliation)

  local resumeState = payload and payload.resumeLoadoutState or nil

  if resumeState and type(resumeState) == "table" then
    local resumedSelection = resumeState.selectionSlots

    if type(resumedSelection) == "table" then
      local ok = Validator.validateLoadoutSelection(app.runState, resumedSelection)

      if ok then
        self.selectionSlots = Loadout.cloneSlots(resumedSelection, app.runState.maxActiveCoinSlots)
      end
    end

    local resumedSelectionIndex = resumeState.selectedCollectionIndex

    if type(resumedSelectionIndex) ~= "number" then
      resumedSelectionIndex = resumeState.selectedCoinIndex
    end

    if type(resumedSelectionIndex) == "number" then
      self.selectedCollectionIndex = Utils.clamp(math.floor(resumedSelectionIndex), 1, #app.runState.collectionCoinIds)
    end

    if type(resumeState.collectionScrollOffset) == "number" then
      self.collectionScrollOffset = math.max(1, math.floor(resumeState.collectionScrollOffset))
    end

    self:selectCollectionIndex(app, self.selectedCollectionIndex)
    self.statusMessage = "Resumed saved run in loadout."
  end
end

function LoadoutState:keypressed(app, key)
  if key == "escape" then
    app.stateGraph:request("cancel_to_menu")
    return
  end

  if key == "left" or key == "up" then
    self:selectCollectionIndex(app, self.selectedCollectionIndex - 1)
    return
  end

  if key == "right" or key == "down" then
    self:selectCollectionIndex(app, self.selectedCollectionIndex + 1)
    return
  end

  local slotIndex = tonumber(key)

  if slotIndex and slotIndex >= 1 and slotIndex <= app.runState.maxActiveCoinSlots then
    self:assignSelectedCoinToSlot(app, slotIndex)
    return
  end

  local clearSlotMap = {
    z = 1,
    x = 2,
    c = 3,
    v = 4,
    b = 5,
  }

  local clearSlotIndex = clearSlotMap[key]

  if clearSlotIndex and clearSlotIndex <= app.runState.maxActiveCoinSlots then
    self:clearSelectedSlot(app, clearSlotIndex)
    return
  end

  if key == "r" then
    self:resetSelection(app)
    return
  end

  if key == "return" or key == "kpenter" then
    self:tryStartStage(app)
  end
end

function LoadoutState:draw(app)
  local currentCoinId = app.runState.collectionCoinIds[self.selectedCollectionIndex]
  local layout = self:getLayout(app)
  local stagePreview = app:getPlannedStagePreviewData()
  local stageDefinition = stagePreview.stageDefinition
  local selectedBuildKey = self:formatBuildSummary(self.selectionSlots, app.runState.maxActiveCoinSlots)
  local reconciledBuildKey = self.reconciliation and self:formatBuildSummary(self.reconciliation.selectionSlots, app.runState.maxActiveCoinSlots) or nil
  local stageTitle = stageDefinition and (stageDefinition.label or stageDefinition.name or stageDefinition.id) or "Loadout"

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(string.format("Round %d/%d  %s", app.runState.roundIndex, app.config.totalStageCount(), stageTitle), layout.padding, layout.headerY)
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(
    string.format(
      "Target %d  |  Flips %d",
      stageDefinition and stageDefinition.targetScore or 0,
      stagePreview.flipsPerStage or 0
    ),
    layout.padding,
    layout.headerY + 6,
    layout.contentWidth,
    "right"
  )

  Panel.draw(layout.padding, layout.panelY, layout.contentWidth, layout.topHeight, "Choose Coin")
  Panel.draw(layout.padding, layout.slotY, layout.contentWidth, layout.slotHeight, "Slots")

  local collectionArea = Panel.getContentArea(layout.padding, layout.panelY, layout.contentWidth, layout.topHeight, "Choose Coin")
  local buildArea = Panel.getContentArea(layout.padding, layout.slotY, layout.contentWidth, layout.slotHeight, "Slots")

  love.graphics.setFont(app.fonts.body)
  local mouseX, mouseY = love.mouse.getPosition()
  local collectionButtons = self:buildCollectionButtons(app, collectionArea)
  self:drawCollectionCards(app, collectionButtons, mouseX, mouseY)
  local hoveredCoinButton = self:getCoinButtonAtPoint(mouseX, mouseY)

  local slotLines = {
    string.format("%d/%d slots", Loadout.countEquipped(self.selectionSlots, app.runState.maxActiveCoinSlots), app.runState.maxActiveCoinSlots),
    "Click or drag to equip.",
  }

  if reconciledBuildKey and reconciledBuildKey ~= selectedBuildKey then
    table.insert(slotLines, string.format("Reconciled: %s", reconciledBuildKey ~= "" and reconciledBuildKey or "(empty)"))
  end

  local slotCardHeight = math.min(150, buildArea.height - 42)
  local slotGap = Theme.spacing.itemGap
  local slotCardWidth = math.floor((buildArea.width - (slotGap * math.max(0, app.runState.maxActiveCoinSlots - 1))) / app.runState.maxActiveCoinSlots)
  self.slotRects = {}
  local slotsY = buildArea.y + 34

  for slotIndex = 1, app.runState.maxActiveCoinSlots do
    local coinId = self.selectionSlots[slotIndex]
    local cardX = buildArea.x + ((slotIndex - 1) * (slotCardWidth + slotGap))
    local cardY = slotsY
    local selected = coinId ~= nil and coinId == currentCoinId

    self.slotRects[slotIndex] = { x = cardX, y = cardY, width = slotCardWidth, height = slotCardHeight }

    love.graphics.setColor(0.04, 0.05, 0.08, 0.94)
    love.graphics.rectangle("fill", cardX, cardY, slotCardWidth, slotCardHeight)
    Theme.applyColor(selected and Theme.colors.accent or Theme.colors.panelBorder)
    love.graphics.setLineWidth(selected and 3 or 2)
    love.graphics.rectangle("line", cardX, cardY, slotCardWidth, slotCardHeight)
    love.graphics.setLineWidth(1)

    if coinId then
      local coin = Coins.getById(coinId)
      local iconSize = math.min(82, slotCardHeight - 42)
      local iconX = cardX + 26
      local iconY = cardY + math.floor((slotCardHeight - iconSize) / 2)

      CoinArt.draw(coinId, iconX, iconY, iconSize, {
        selected = selected,
        tilt = selected and -0.04 or 0.025,
      })

      love.graphics.setFont(app.fonts.body)
      Theme.applyColor(Theme.colors.text)
      love.graphics.printf(coin and coin.name or coinId, cardX + 126, cardY + 48, slotCardWidth - 146, "left")
    else
      Theme.applyColor(Theme.colors.panelBorder)
      love.graphics.rectangle("line", cardX + math.floor((slotCardWidth - 44) / 2), cardY + 10, 44, 44)
      Theme.applyColor(Theme.colors.mutedText)
      love.graphics.printf("DROP", cardX, cardY + 22, slotCardWidth, "center")
    end

    drawNumberBadge(app, slotIndex, cardX + 10, cardY + 10, 24)
  end

  Layout.drawWrappedLines(slotLines, buildArea.x, buildArea.y, buildArea.width, Theme.colors.text, Theme.spacing.lineHeight, 34)

  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(self.statusMessage, layout.padding, layout.height - layout.footerMetrics.statusHeight + Theme.spacing.statusPadding, layout.width - (layout.padding * 2), "left")

  Button.drawButtons(self:buildActionButtons(app, layout), mouseX, mouseY)

  local detailCoinId = hoveredCoinButton and hoveredCoinButton.coinId or self.detailCoinId

  if detailCoinId then
    self:drawCoinDetailOverlay(app, detailCoinId, mouseX, mouseY)
  end

  if self.dragCoinId then
    local movedFarEnough = getDistanceSquared(self.dragStartX, self.dragStartY, mouseX, mouseY) > 64

    if movedFarEnough then
      CoinArt.draw(self.dragCoinId, mouseX - 28, mouseY - 28, 56, { selected = true, tilt = -0.06 })
    end
  end
end

function LoadoutState:getSlotAtPoint(x, y)
  for slotIndex, rect in ipairs(self.slotRects or {}) do
    if x >= rect.x and x <= (rect.x + rect.width) and y >= rect.y and y <= (rect.y + rect.height) then
      return slotIndex
    end
  end

  return nil
end

function LoadoutState:mousepressed(app, x, y, button)
  local layout = self:getLayout(app)
  local collectionArea = Panel.getContentArea(layout.padding, layout.panelY, layout.contentWidth, layout.topHeight, "Choose Coin")
  local collectionButtons = self:buildCollectionButtons(app, collectionArea)

  if button == 2 then
    local coinButton = self:getCoinButtonAtPoint(x, y)
    self.detailCoinId = coinButton and coinButton.coinId or nil
    return
  end

  if button ~= 1 then
    return
  end

  local slotIndex = self:getSlotAtPoint(x, y)

  if slotIndex then
    self:clearSelectedSlot(app, slotIndex)
    return
  end

  local handled, _, clickedButton = Button.handleMousePressed(collectionButtons, x, y)

  if handled then
    if clickedButton and clickedButton.coinId then
      self.dragCoinId = clickedButton.coinId
      self.dragStartX = x
      self.dragStartY = y
    end

    return
  end

  Button.handleMousePressed(self:buildActionButtons(app, layout), x, y)
end

function LoadoutState:mousereleased(app, x, y, button)
  if button ~= 1 or not self.dragCoinId then
    return
  end

  local coinId = self.dragCoinId
  local wasClick = getDistanceSquared(self.dragStartX, self.dragStartY, x, y) <= 64
  self.dragCoinId = nil
  self.dragStartX = nil
  self.dragStartY = nil
  local slotIndex = self:getSlotAtPoint(x, y)

  if slotIndex then
    self.selectionSlots = LoadoutSystem.assignCoinToSlot(app.runState, self.selectionSlots, coinId, slotIndex)
    self.statusMessage = string.format("Placed %s in slot %d.", app:getCoinName(coinId), slotIndex)
  elseif wasClick then
    self:assignCoinToNextOpenSlot(app, coinId)
  end
end

return LoadoutState
