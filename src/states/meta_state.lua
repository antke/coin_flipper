local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")
local Utils = require("src.core.utils")

local MetaState = {}
MetaState.__index = MetaState

local OPTION_BUTTON_HEIGHT = 30
local OPTION_BUTTON_GAP = 6
local SCROLL_BUTTON_HEIGHT = 24

local function formatPurchaseError(errorCode)
  if errorCode == "already_purchased" then
    return "That upgrade has already been purchased."
  end

  if errorCode == "not_enough_meta_points" then
    return "Not enough meta points for that upgrade yet."
  end

  if errorCode == "unknown_meta_upgrade" then
    return "The selected meta upgrade could not be found."
  end

  return tostring(errorCode)
end

function MetaState.new()
  return setmetatable({
    selectedIndex = 1,
    optionScrollOffset = 1,
    statusMessage = "",
    optionButtons = {},
    actionButtons = {},
  }, MetaState)
end

local function getVisibleRowCount(height)
  return math.max(1, math.floor((height + OPTION_BUTTON_GAP) / (OPTION_BUTTON_HEIGHT + OPTION_BUTTON_GAP)))
end

function MetaState:clampOptionOffset(app, visibleRows)
  local options = app:getMetaUpgradeOptions()
  local maxOffset = math.max(1, #options - visibleRows + 1)
  self.optionScrollOffset = math.max(1, math.min(self.optionScrollOffset, maxOffset))
end

function MetaState:ensureSelectedOptionVisible(app, visibleRows)
  self:clampOptionOffset(app, visibleRows)

  if self.selectedIndex < self.optionScrollOffset then
    self.optionScrollOffset = self.selectedIndex
  elseif self.selectedIndex > (self.optionScrollOffset + visibleRows - 1) then
    self.optionScrollOffset = self.selectedIndex - visibleRows + 1
  end

  self:clampOptionOffset(app, visibleRows)
end

function MetaState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height, {
    buttonRows = 0,
    statusHeight = 44,
    extraSpacing = Theme.spacing.statusPadding,
  })
  local topPanelY = 132
  local topPanelHeight = 214
  local bottomPanelY = topPanelY + topPanelHeight + gap
  local bottomPanelHeight = math.max(180, footerMetrics.contentBottomY - bottomPanelY)
  local leftPanelWidth = math.floor((width - (padding * 2) - gap) * 0.42)
  local rightPanelWidth = width - (padding * 2) - gap - leftPanelWidth

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    footerMetrics = footerMetrics,
    topPanelY = topPanelY,
    topPanelHeight = topPanelHeight,
    bottomPanelY = bottomPanelY,
    bottomPanelHeight = bottomPanelHeight,
    leftPanelWidth = leftPanelWidth,
    rightPanelWidth = rightPanelWidth,
  }
end

function MetaState:selectOptionIndex(app, index)
  local options = app:getMetaUpgradeOptions()
  self.selectedIndex = Utils.clamp(index, 1, math.max(1, #options))
  self:ensureSelectedOptionVisible(app, self.optionVisibleRows or 1)
  return true
end

function MetaState:scrollOptions(app, direction)
  self.optionScrollOffset = self.optionScrollOffset + direction
  self:clampOptionOffset(app, self.optionVisibleRows or 1)
  return true
end

function MetaState:getSelectedOption(app)
  local options = app:getMetaUpgradeOptions()
  return options[self.selectedIndex]
end

function MetaState:tryPurchaseSelectedUpgrade(app)
  local selected = self:getSelectedOption(app)

  if not selected then
    self.statusMessage = "No meta upgrade is currently selected."
    return false, "no_selection"
  end

  if selected.purchased then
    self.statusMessage = formatPurchaseError("already_purchased")
    return false, "already_purchased"
  end

  if (app.metaState.metaPoints or 0) < (selected.cost or 0) then
    self.statusMessage = formatPurchaseError("not_enough_meta_points")
    return false, "not_enough_meta_points"
  end

  local ok, result = app:purchaseMetaUpgrade(selected.id)
  self.statusMessage = ok and string.format("Purchased %s for %d meta point(s).", result.name, result.cost or 0) or formatPurchaseError(result)
  return ok, result
end

function MetaState:saveNow(app)
  local ok, errorMessage = app:saveMetaState("manual")
  self.statusMessage = app.metaSaveStatus.message
  return ok, errorMessage
end

function MetaState:tryStartNextRun(app)
  if not app:canStartRunFromMeta() then
    self.statusMessage = "Start Next Run is only available from the post-run handoff."
    return false, "start_next_run_unavailable"
  end

  return app.stateGraph:request("start_next_run")
end

function MetaState:goBack(app)
  return app.stateGraph:request("back")
end

function MetaState:buildOptionButtons(app, x, y, width, height)
  local options = app:getMetaUpgradeOptions()
  local buttons = {}
  local buttonHeight = OPTION_BUTTON_HEIGHT
  local gap = OPTION_BUTTON_GAP
  local currentY = y
  local overflow = #options > getVisibleRowCount(height)
  local listHeight = height

  if overflow then
    table.insert(buttons, {
      x = x,
      y = currentY,
      width = width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Up",
      variant = "warning",
      disabled = self.optionScrollOffset <= 1,
      onClick = function()
        return self:scrollOptions(app, -1)
      end,
    })

    currentY = currentY + SCROLL_BUTTON_HEIGHT + gap
    listHeight = listHeight - ((SCROLL_BUTTON_HEIGHT + gap) * 2)
  end

  local visibleRows = getVisibleRowCount(listHeight)
  self.optionVisibleRows = visibleRows
  self:ensureSelectedOptionVisible(app, visibleRows)
  local startIndex = self.optionScrollOffset
  local endIndex = math.min(#options, startIndex + visibleRows - 1)

  for index = startIndex, endIndex do
    local option = options[index]

    local status = option.purchased and "owned" or string.format("cost %d", option.cost)
    table.insert(buttons, {
      x = x,
      y = currentY,
      width = width,
      height = buttonHeight,
      label = string.format("%s [%s]", option.name, status),
      focused = index == self.selectedIndex,
      variant = index == self.selectedIndex and "primary" or "default",
      onClick = function()
        return self:selectOptionIndex(app, index)
      end,
    })

    currentY = currentY + buttonHeight + gap
  end

  if overflow then
    table.insert(buttons, {
      x = x,
      y = y + height - SCROLL_BUTTON_HEIGHT,
      width = width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Down",
      variant = "warning",
      disabled = endIndex >= #options,
      onClick = function()
        return self:scrollOptions(app, 1)
      end,
    })
  end

  self.optionButtons = buttons
  return buttons
end

function MetaState:buildActionButtons(app, x, y, width)
  local options = app:getMetaUpgradeOptions()
  local selected = options[self.selectedIndex]
  local allowStartRun = app:canStartRunFromMeta()
  local buttonCount = allowStartRun and 6 or 5
  local gap = Theme.spacing.itemGap
  local buttonWidth = math.floor((width - (gap * (buttonCount - 1))) / buttonCount)
  local buttonHeight = 42
  local purchased = selected and selected.purchased or false
  local affordable = selected and (app.metaState.metaPoints or 0) >= (selected.cost or 0) or false
  local buttons = {
    {
      x = x,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Purchase",
      variant = "primary",
      disabled = not selected or purchased or not affordable,
      onClick = function()
        return self:tryPurchaseSelectedUpgrade(app)
      end,
    },
    {
      x = x + buttonWidth + gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Save Now",
      variant = "default",
      onClick = function()
        return self:saveNow(app)
      end,
    },
    {
      x = x + ((buttonWidth + gap) * 2),
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Collection",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_collection")
      end,
    },
  }

  local nextX = x + (buttonWidth * 3) + (gap * 3)

  table.insert(buttons, {
    x = nextX,
    y = y,
    width = buttonWidth,
    height = buttonHeight,
    label = "Records",
    variant = "default",
    onClick = function()
      return app.stateGraph:request("open_records")
    end,
  })

  nextX = nextX + buttonWidth + gap

  if allowStartRun then
    table.insert(buttons, {
      x = nextX,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Start Next Run",
      variant = "success",
      onClick = function()
        return self:tryStartNextRun(app)
      end,
    })

    nextX = nextX + buttonWidth + gap
  end

  table.insert(buttons, {
      x = nextX,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = app:getMetaBackLabel(),
      variant = "warning",
      onClick = function()
        return self:goBack(app)
      end,
    })

  self.actionButtons = buttons
  return buttons
end

function MetaState:enter(app, payload)
  app:setMetaFlowContext(payload and payload.metaFlowContext or app:createMenuMetaFlowContext())
  local options = app:getMetaUpgradeOptions()
  self.optionScrollOffset = 1
  self.selectedIndex = Utils.clamp(self.selectedIndex, 1, math.max(1, #options))
  self.statusMessage = app:canStartRunFromMeta()
    and "Review upgrades, invest meta points, then start the next run or return to summary."
    or "Use arrows or click an upgrade row, then purchase with the button or Enter."
end

function MetaState:keypressed(app, key)
  local options = app:getMetaUpgradeOptions()

  if key == "escape" or key == "backspace" then
    self:goBack(app)
    return
  end

  if key == "up" or key == "left" then
    self:selectOptionIndex(app, self.selectedIndex - 1)
    return
  end

  if key == "down" or key == "right" then
    self:selectOptionIndex(app, self.selectedIndex + 1)
    return
  end

  if key == "s" then
    self:saveNow(app)
    return
  end

  if key == "n" then
    self:tryStartNextRun(app)
    return
  end

  if key == "b" then
    app.stateGraph:request("open_collection")
    return
  end

  if key == "r" then
    app.stateGraph:request("open_records")
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryPurchaseSelectedUpgrade(app)
  end
end

function MetaState:draw(app)
  local options = app:getMetaUpgradeOptions()
  local selected = options[self.selectedIndex]
  local layout = self:getLayout(app)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Meta Progression", 70, app.fonts.title, Theme.colors.text)

  Panel.draw(layout.padding, layout.topPanelY, layout.leftPanelWidth, layout.topPanelHeight, "Persistent Progress")
  Panel.draw(layout.padding + layout.leftPanelWidth + layout.gap, layout.topPanelY, layout.rightPanelWidth, layout.topPanelHeight, "Save + Next Run Projection")
  Panel.draw(layout.padding, layout.bottomPanelY, layout.leftPanelWidth, layout.bottomPanelHeight, "Meta Upgrade Catalog")
  Panel.draw(layout.padding + layout.leftPanelWidth + layout.gap, layout.bottomPanelY, layout.rightPanelWidth, layout.bottomPanelHeight, "Selected Upgrade")

  local statsContent = Panel.getContentArea(layout.padding, layout.topPanelY, layout.leftPanelWidth, layout.topPanelHeight, "Persistent Progress")
  local projectionContent = Panel.getContentArea(layout.padding + layout.leftPanelWidth + layout.gap, layout.topPanelY, layout.rightPanelWidth, layout.topPanelHeight, "Save + Next Run Projection")
  local listContent = Panel.getContentArea(layout.padding, layout.bottomPanelY, layout.leftPanelWidth, layout.bottomPanelHeight, "Meta Upgrade Catalog")
  local detailContent = Panel.getContentArea(layout.padding + layout.leftPanelWidth + layout.gap, layout.bottomPanelY, layout.rightPanelWidth, layout.bottomPanelHeight, "Selected Upgrade")

  local statusLines = app:getMetaStatusLines()
  local projectionLines = {
    string.format("Save Status: %s", app.metaSaveStatus and app.metaSaveStatus.message or "unknown"),
  }

  local detailLines = selected and app:getMetaUpgradeDetailLines(selected.id) or { "No upgrade selected." }

  local actionButtonY = detailContent.y + detailContent.height - 46
  local actionButtons = self:buildActionButtons(app, detailContent.x, actionButtonY, detailContent.width)
  local optionButtons = self:buildOptionButtons(app, listContent.x, listContent.y, listContent.width, listContent.height)

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines({ statusLines[1], statusLines[3], statusLines[4], statusLines[5] }, statsContent.x, statsContent.y, statsContent.width, Theme.colors.text, Theme.spacing.lineHeight, statsContent.height)
  Layout.drawWrappedLines(projectionLines, projectionContent.x, projectionContent.y, projectionContent.width, Theme.colors.text, Theme.spacing.lineHeight, projectionContent.height)
  Button.drawButtons(optionButtons, love.mouse.getX(), love.mouse.getY())
  Layout.drawWrappedLines(detailLines, detailContent.x, detailContent.y, detailContent.width, Theme.colors.text, Theme.spacing.lineHeight, detailContent.height - 58)
  Button.drawButtons(actionButtons, love.mouse.getX(), love.mouse.getY())

  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(self.statusMessage, layout.padding, layout.height - layout.footerMetrics.statusHeight + Theme.spacing.statusPadding, layout.width - (layout.padding * 2), "left")
end

function MetaState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)
  local listContent = Panel.getContentArea(layout.padding, layout.bottomPanelY, layout.leftPanelWidth, layout.bottomPanelHeight, "Meta Upgrade Catalog")
  local detailContent = Panel.getContentArea(layout.padding + layout.leftPanelWidth + layout.gap, layout.bottomPanelY, layout.rightPanelWidth, layout.bottomPanelHeight, "Selected Upgrade")
  local actionButtonY = detailContent.y + detailContent.height - 46

  if Button.handleMousePressed(self:buildOptionButtons(app, listContent.x, listContent.y, listContent.width, listContent.height), x, y) then
    return
  end

  Button.handleMousePressed(self:buildActionButtons(app, detailContent.x, actionButtonY, detailContent.width), x, y)
end

return MetaState
