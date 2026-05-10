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

local COLLECTION_BUTTON_HEIGHT = 30
local COLLECTION_BUTTON_GAP = 6
local SCROLL_BUTTON_HEIGHT = 24

local function getWrappedLineCount(text, width)
  local font = love.graphics.getFont()
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped)
end

local function getPreviewCardHeight(card, width)
  local descriptionLines = getWrappedLineCount(card.description, math.max(1, width - 18))
  return 24 + (descriptionLines * Theme.spacing.lineHeight) + 8
end

function LoadoutState.new()
  return setmetatable({
    selectedCollectionIndex = 1,
    collectionScrollOffset = 1,
    selectionSlots = {},
    reconciliation = nil,
    statusMessage = "",
    collectionButtons = {},
    actionButtons = {},
  }, LoadoutState)
end

local function getVisibleRowCount(height)
  return math.max(1, math.floor((height + COLLECTION_BUTTON_GAP) / (COLLECTION_BUTTON_HEIGHT + COLLECTION_BUTTON_GAP)))
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
  local panelY = 96
  local footerMetrics = Layout.getFooterMetrics(height, {
    buttonHeight = 38,
    buttonRows = 3,
    statusHeight = 44,
    extraSpacing = Theme.spacing.statusPadding,
  })
  local availableHeight = math.max(220, footerMetrics.contentBottomY - panelY)
  local collectionWidth = 420
  local rightX = padding + collectionWidth + gap
  local rightWidth = width - rightX - padding
  local topRightHeight = math.floor((availableHeight - gap) * 0.56)
  local bottomRightY = panelY + topRightHeight + gap
  local bottomRightHeight = availableHeight - topRightHeight - gap
  local bottomPanelWidth = math.floor((rightWidth - gap) / 2)

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    headerY = padding,
    panelY = panelY,
    footerMetrics = footerMetrics,
    availableHeight = availableHeight,
    collectionWidth = collectionWidth,
    rightX = rightX,
    rightWidth = rightWidth,
    topRightHeight = topRightHeight,
    bottomRightY = bottomRightY,
    bottomRightHeight = bottomRightHeight,
    bottomPanelWidth = bottomPanelWidth,
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

  return string.format(
    "Click a coin or use arrow keys, then use slot buttons or 1-%d to assign. Enter starts the stage.",
    app.runState.maxActiveCoinSlots
  )
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
  local buttonHeight = COLLECTION_BUTTON_HEIGHT
  local gap = COLLECTION_BUTTON_GAP
  local overflow = #app.runState.collectionCoinIds > getVisibleRowCount(area.height)
  local currentY = area.y
  local listHeight = area.height

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = currentY,
      width = area.width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Up",
      variant = "warning",
      disabled = self.collectionScrollOffset <= 1,
      onClick = function()
        return self:scrollCollection(app, -1)
      end,
    })

    currentY = currentY + SCROLL_BUTTON_HEIGHT + gap
    listHeight = listHeight - ((SCROLL_BUTTON_HEIGHT + gap) * 2)
  end

  local visibleRows = getVisibleRowCount(listHeight)
  self.collectionVisibleRows = visibleRows
  self:ensureSelectedCoinVisible(app, visibleRows)

  local startIndex = self.collectionScrollOffset
  local endIndex = math.min(#app.runState.collectionCoinIds, startIndex + visibleRows - 1)

  for index = startIndex, endIndex do
    local coinId = app.runState.collectionCoinIds[index]

    local equippedMarker = ""

    for slot = 1, app.runState.maxActiveCoinSlots do
      if self.selectionSlots[slot] == coinId then
        equippedMarker = string.format(" [slot %d]", slot)
        break
      end
    end

    table.insert(buttons, {
      x = area.x,
      y = currentY,
      width = area.width,
      height = buttonHeight,
      label = string.format("%s%s", app:getCoinName(coinId), equippedMarker),
      focused = index == self.selectedCollectionIndex,
      variant = index == self.selectedCollectionIndex and "primary" or "default",
      onClick = function()
        self:selectCollectionIndex(app, index)
        return true
      end,
    })

    currentY = currentY + buttonHeight + gap
  end

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = area.y + area.height - SCROLL_BUTTON_HEIGHT,
      width = area.width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Down",
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

function LoadoutState:buildActionButtons(app, layout)
  local padding = layout.padding
  local gap = Theme.spacing.itemGap
  local maxSlots = app.runState.maxActiveCoinSlots
  local rowWidth = layout.width - (padding * 2)
  local slotButtonWidth = math.floor((rowWidth - (gap * math.max(0, maxSlots - 1))) / maxSlots)
  local buttonHeight = layout.footerMetrics.buttonHeight
  local actionY = layout.footerMetrics.buttonY
  local clearY = actionY - layout.footerMetrics.rowGap - buttonHeight
  local assignY = clearY - layout.footerMetrics.rowGap - buttonHeight
  local buttons = {}
  local selectedCoinId = app.runState.collectionCoinIds[self.selectedCollectionIndex]

  for slotIndex = 1, maxSlots do
    local buttonX = padding + ((slotIndex - 1) * (slotButtonWidth + gap))

    table.insert(buttons, {
      x = buttonX,
      y = assignY,
      width = slotButtonWidth,
      height = buttonHeight,
      label = string.format("Set Slot %d", slotIndex),
      variant = "primary",
      disabled = not selectedCoinId,
      onClick = function()
        return self:assignSelectedCoinToSlot(app, slotIndex)
      end,
    })

    table.insert(buttons, {
      x = buttonX,
      y = clearY,
      width = slotButtonWidth,
      height = buttonHeight,
      label = string.format("Clear %d", slotIndex),
      variant = "warning",
      onClick = function()
        return self:clearSelectedSlot(app, slotIndex)
      end,
    })
  end

  local actionWidth = math.floor((rowWidth - (gap * 2)) / 3)

  table.insert(buttons, {
    x = padding,
    y = actionY,
    width = actionWidth,
    height = buttonHeight,
    label = "Back to Menu",
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
    label = "Reset Build",
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
    label = "Start Stage",
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
  local currentCoin = Coins.getById(currentCoinId)
  local layout = self:getLayout(app)
  local stagePreview = app:getPlannedStagePreviewData()
  local stageDefinition = stagePreview.stageDefinition
  local selectedBuildKey = self:formatBuildSummary(self.selectionSlots, app.runState.maxActiveCoinSlots)
  local reconciledBuildKey = self.reconciliation and self:formatBuildSummary(self.reconciliation.selectionSlots, app.runState.maxActiveCoinSlots) or nil

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(stageDefinition and stageDefinition.label or "Loadout", layout.padding, layout.headerY)
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.print(string.format("Round %d of %d", app.runState.roundIndex, app.config.totalStageCount()), layout.padding, layout.headerY + 30)

  Panel.draw(layout.padding, layout.panelY, layout.collectionWidth, layout.availableHeight, "Collection")
  Panel.draw(layout.rightX, layout.panelY, layout.rightWidth, layout.topRightHeight, "Current Build")
  Panel.draw(layout.rightX, layout.bottomRightY, layout.bottomPanelWidth, layout.bottomRightHeight, "Coin Details")
  Panel.draw(layout.rightX + layout.bottomPanelWidth + layout.gap, layout.bottomRightY, layout.bottomPanelWidth, layout.bottomRightHeight, stagePreview.title)

  local collectionArea = Panel.getContentArea(layout.padding, layout.panelY, layout.collectionWidth, layout.availableHeight, "Collection")
  local buildArea = Panel.getContentArea(layout.rightX, layout.panelY, layout.rightWidth, layout.topRightHeight, "Current Build")
  local detailArea = Panel.getContentArea(layout.rightX, layout.bottomRightY, layout.bottomPanelWidth, layout.bottomRightHeight, "Coin Details")
  local previewArea = Panel.getContentArea(layout.rightX + layout.bottomPanelWidth + layout.gap, layout.bottomRightY, layout.bottomPanelWidth, layout.bottomRightHeight, stagePreview.title)

  love.graphics.setFont(app.fonts.body)
  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildCollectionButtons(app, collectionArea), mouseX, mouseY)

  local slotLines = {
    string.format("Max active slots: %d", app.runState.maxActiveCoinSlots),
    string.format("Current selection: %s", selectedBuildKey ~= "" and selectedBuildKey or "(empty)"),
    string.format("Filled slots: %d", Loadout.countEquipped(self.selectionSlots, app.runState.maxActiveCoinSlots)),
    "",
  }

  if reconciledBuildKey and reconciledBuildKey ~= selectedBuildKey then
    table.insert(slotLines, 2, string.format("Starting build after reconciliation: %s", reconciledBuildKey ~= "" and reconciledBuildKey or "(empty)"))
  end

  for _, line in ipairs(self:getReconciliationLines(app)) do
    table.insert(slotLines, line)
  end

  table.insert(slotLines, "")

  for slotIndex = 1, app.runState.maxActiveCoinSlots do
    local coinId = self.selectionSlots[slotIndex]
    table.insert(slotLines, string.format("Slot %d: %s", slotIndex, coinId and app:getCoinName(coinId) or "(empty)"))
  end

  local slotCardHeight = 92
  local slotGap = Theme.spacing.itemGap
  local slotCardWidth = math.floor((buildArea.width - (slotGap * math.max(0, app.runState.maxActiveCoinSlots - 1))) / app.runState.maxActiveCoinSlots)

  for slotIndex = 1, app.runState.maxActiveCoinSlots do
    local coinId = self.selectionSlots[slotIndex]
    local cardX = buildArea.x + ((slotIndex - 1) * (slotCardWidth + slotGap))
    local cardY = buildArea.y
    local selected = coinId ~= nil and coinId == currentCoinId

    love.graphics.setColor(Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.88)
    love.graphics.rectangle("fill", cardX, cardY, slotCardWidth, slotCardHeight, 10, 10)
    Theme.applyColor(selected and Theme.colors.accent or Theme.colors.panelBorder)
    love.graphics.setLineWidth(selected and 2 or 1)
    love.graphics.rectangle("line", cardX, cardY, slotCardWidth, slotCardHeight, 10, 10)
    love.graphics.setLineWidth(1)

    if coinId then
      CoinArt.drawCard(coinId, cardX + math.floor((slotCardWidth - 62) / 2), cardY + 6, 62, 62, {
        selected = selected,
        tilt = selected and -0.04 or 0.025,
      })
    else
      Theme.applyColor(Theme.colors.panelBorder)
      love.graphics.rectangle("line", cardX + math.floor((slotCardWidth - 44) / 2), cardY + 10, 44, 44, 8, 8)
      Theme.applyColor(Theme.colors.mutedText)
      love.graphics.printf("?", cardX, cardY + 22, slotCardWidth, "center")
    end

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(string.format("Slot %d", slotIndex), cardX + 6, cardY + 60, slotCardWidth - 12, "center")
  end

  Layout.drawWrappedLines(
    slotLines,
    buildArea.x,
    buildArea.y + slotCardHeight + Theme.spacing.itemGap,
    buildArea.width,
    Theme.colors.text,
    Theme.spacing.lineHeight,
    buildArea.height - slotCardHeight - Theme.spacing.itemGap
  )

  local detailLines = {}

  if currentCoin then
    detailLines = {
      string.format("%s (%s)", currentCoin.name, currentCoin.rarity),
      currentCoin.description,
      "",
      string.format("Tags: %s", table.concat(currentCoin.tags or {}, ", ")),
    }
  else
    detailLines = { "No coin highlighted." }
  end

  local detailTextY = detailArea.y
  local detailTextHeight = detailArea.height

  if currentCoin then
    local artSize = math.min(96, math.max(60, math.floor(detailArea.width * 0.28)))
    CoinArt.draw(currentCoin, detailArea.x + math.floor((detailArea.width - artSize) / 2), detailArea.y, artSize, {
      selected = true,
      tilt = -0.08,
    })
    detailTextY = detailArea.y + artSize + Theme.spacing.itemGap
    detailTextHeight = detailArea.height - artSize - Theme.spacing.itemGap
  end

  Layout.drawWrappedLines(
    detailLines,
    detailArea.x,
    detailTextY,
    detailArea.width,
    Theme.colors.text,
    Theme.spacing.lineHeight,
    detailTextHeight
  )

  local previewLinesHeight = 0
  for _, line in ipairs(stagePreview.lines or {}) do
    previewLinesHeight = previewLinesHeight + (getWrappedLineCount(line, previewArea.width) * Theme.spacing.lineHeight)
  end

  previewLinesHeight = previewLinesHeight + Theme.spacing.itemGap
  local previewTextBottom = math.min(previewArea.height, previewLinesHeight)

  Layout.drawWrappedLines(
    stagePreview.lines,
    previewArea.x,
    previewArea.y,
    previewArea.width,
    Theme.colors.text,
    Theme.spacing.lineHeight,
    math.min(previewArea.height, previewTextBottom)
  )

  local cardY = previewArea.y + previewTextBottom
  local remainingCardHeight = previewArea.height - previewTextBottom

  for _, card in ipairs(stagePreview.cards or {}) do
    local cardHeight = getPreviewCardHeight(card, previewArea.width)

    if cardY + cardHeight > (previewArea.y + previewArea.height) then
      break
    end

    love.graphics.setColor(Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.98)
    love.graphics.rectangle("fill", previewArea.x, cardY, previewArea.width, cardHeight, 10, 10)
    love.graphics.setColor(Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 1.0)
    love.graphics.rectangle("line", previewArea.x, cardY, previewArea.width, cardHeight, 10, 10)
    Theme.applyColor(stagePreview.isBoss and Theme.colors.danger or Theme.colors.accent)
    love.graphics.rectangle("fill", previewArea.x, cardY, 8, cardHeight, 10, 10)
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.text)
    love.graphics.print(card.name, previewArea.x + 16, cardY + 6)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(card.description, previewArea.x + 16, cardY + 24, previewArea.width - 24, "left")

    cardY = cardY + cardHeight + Theme.spacing.itemGap
    remainingCardHeight = previewArea.height - (cardY - previewArea.y)

    if remainingCardHeight <= 0 then
      break
    end
  end

  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(self.statusMessage, layout.padding, layout.height - layout.footerMetrics.statusHeight + Theme.spacing.statusPadding, layout.width - (layout.padding * 2), "left")

  Button.drawButtons(self:buildActionButtons(app, layout), mouseX, mouseY)
end

function LoadoutState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)
  local collectionArea = Panel.getContentArea(layout.padding, layout.panelY, layout.collectionWidth, layout.availableHeight, "Collection")

  if Button.handleMousePressed(self:buildCollectionButtons(app, collectionArea), x, y) then
    return
  end

  Button.handleMousePressed(self:buildActionButtons(app, layout), x, y)
end

return LoadoutState
