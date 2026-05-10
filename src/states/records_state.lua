local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")
local Utils = require("src.core.utils")

local RecordsState = {}
RecordsState.__index = RecordsState

local ENTRY_BUTTON_HEIGHT = 30
local ENTRY_BUTTON_GAP = 6
local SCROLL_BUTTON_HEIGHT = 24

local function getVisibleRowCount(height)
  return math.max(1, math.floor((height + ENTRY_BUTTON_GAP) / (ENTRY_BUTTON_HEIGHT + ENTRY_BUTTON_GAP)))
end

function RecordsState.new()
  return setmetatable({
    selectedIndex = 1,
    scrollOffset = 1,
    visibleRows = 1,
    returnState = "menu",
    metaFlowContext = nil,
    entryButtons = {},
    buttons = {},
  }, RecordsState)
end

function RecordsState:getBackLabel()
  if self.returnState == "summary" then
    return "Back to Summary"
  elseif self.returnState == "meta" then
    return "Back to Meta"
  end

  return "Back to Menu"
end

function RecordsState:getBackEvent()
  if self.returnState == "summary" then
    return "back_to_summary"
  elseif self.returnState == "meta" then
    return "back_to_meta"
  end

  return "back_to_menu"
end

function RecordsState:getLayout()
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height, { statusHeight = 36 })
  local panelY = 132
  local panelHeight = math.max(320, footerMetrics.contentBottomY - panelY)
  local listWidth = math.floor((width - (padding * 2) - gap) * 0.34)
  local detailWidth = width - (padding * 2) - gap - listWidth

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    footerMetrics = footerMetrics,
    panelY = panelY,
    panelHeight = panelHeight,
    listWidth = listWidth,
    detailWidth = detailWidth,
  }
end

function RecordsState:getRecords(app)
  return app:getRunRecords()
end

function RecordsState:clampSelection(app)
  local records = self:getRecords(app)
  self.selectedIndex = Utils.clamp(self.selectedIndex, 1, math.max(1, #records))
end

function RecordsState:clampScroll(app, visibleRows)
  local records = self:getRecords(app)
  local maxOffset = math.max(1, #records - visibleRows + 1)
  self.scrollOffset = Utils.clamp(self.scrollOffset, 1, maxOffset)
end

function RecordsState:ensureSelectionVisible(app, visibleRows)
  self:clampScroll(app, visibleRows)

  if self.selectedIndex < self.scrollOffset then
    self.scrollOffset = self.selectedIndex
  elseif self.selectedIndex > (self.scrollOffset + visibleRows - 1) then
    self.scrollOffset = self.selectedIndex - visibleRows + 1
  end

  self:clampScroll(app, visibleRows)
end

function RecordsState:selectRecord(app, index)
  self.selectedIndex = index
  self:ensureSelectionVisible(app, self.visibleRows or 1)
end

function RecordsState:scrollRecords(app, direction)
  self.scrollOffset = self.scrollOffset + direction
  self:clampScroll(app, self.visibleRows or 1)

  local records = self:getRecords(app)
  if #records > 0 then
    if direction < 0 then
      self.selectedIndex = self.scrollOffset
    else
      self.selectedIndex = math.min(#records, self.scrollOffset + (self.visibleRows or 1) - 1)
    end
  end

  self:ensureSelectionVisible(app, self.visibleRows or 1)
end

function RecordsState:buildEntryButtons(app, area)
  local records = self:getRecords(app)
  local buttons = {}
  local currentY = area.y
  local overflow = #records > getVisibleRowCount(area.height)
  local listHeight = area.height

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = currentY,
      width = area.width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Up",
      variant = "warning",
      disabled = self.scrollOffset <= 1,
      onClick = function()
        self:scrollRecords(app, -1)
      end,
    })
    currentY = currentY + SCROLL_BUTTON_HEIGHT + ENTRY_BUTTON_GAP
    listHeight = listHeight - ((SCROLL_BUTTON_HEIGHT + ENTRY_BUTTON_GAP) * 2)
  end

  local visibleRows = getVisibleRowCount(listHeight)
  self.visibleRows = visibleRows
  self:clampSelection(app)
  self:ensureSelectionVisible(app, visibleRows)
  local startIndex = self.scrollOffset
  local endIndex = math.min(#records, startIndex + visibleRows - 1)

  for index = startIndex, endIndex do
    local record = records[index]
    local seedSuffix = record.seed and string.format(" [Seed %s]", tostring(record.seed)) or ""
    local label = string.format("%d. %s — %s (%d)%s", index, tostring(record.resultType or record.runStatus or "Run"), tostring(record.finalStageLabel or "n/a"), tonumber(record.runTotalScore or 0) or 0, seedSuffix)
    table.insert(buttons, {
      x = area.x,
      y = currentY,
      width = area.width,
      height = ENTRY_BUTTON_HEIGHT,
      label = label,
      focused = index == self.selectedIndex,
      variant = index == self.selectedIndex and "primary" or "default",
      onClick = function()
        self:selectRecord(app, index)
      end,
    })
    currentY = currentY + ENTRY_BUTTON_HEIGHT + ENTRY_BUTTON_GAP
  end

  if overflow then
    table.insert(buttons, {
      x = area.x,
      y = area.y + area.height - SCROLL_BUTTON_HEIGHT,
      width = area.width,
      height = SCROLL_BUTTON_HEIGHT,
      label = "Scroll Down",
      variant = "warning",
      disabled = endIndex >= #records,
      onClick = function()
        self:scrollRecords(app, 1)
      end,
    })
  end

  self.entryButtons = buttons
  return buttons
end

function RecordsState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 260
  local buttonHeight = metrics.buttonHeight
  local buttonX = math.floor((love.graphics.getWidth() - buttonWidth) / 2)
  local event = self:getBackEvent()

  self.buttons = {
    {
      x = buttonX,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = self:getBackLabel(),
      variant = "primary",
      onClick = function()
        if event == "back_to_meta" then
          return app.stateGraph:request(event, { metaFlowContext = self.metaFlowContext })
        end

        return app.stateGraph:request(event)
      end,
    },
  }

  return self.buttons
end

function RecordsState:enter(app, payload)
  payload = payload or {}
  self.returnState = payload.returnState or "menu"
  self.metaFlowContext = Utils.clone(payload.metaFlowContext or nil)
  self.scrollOffset = 1
  self.selectedIndex = 1
end

function RecordsState:keypressed(app, key)
  if key == "escape" or key == "backspace" then
    local event = self:getBackEvent()
    if event == "back_to_meta" then
      app.stateGraph:request(event, { metaFlowContext = self.metaFlowContext })
    else
      app.stateGraph:request(event)
    end
    return
  end

  if key == "up" then
    self:selectRecord(app, self.selectedIndex - 1)
    return
  end

  if key == "down" then
    self:selectRecord(app, self.selectedIndex + 1)
    return
  end
end

function RecordsState:wheelmoved(app, _, y)
  if y == 0 then
    return
  end

  local layout = self:getLayout()
  local listContent = Panel.getContentArea(layout.padding, layout.panelY, layout.listWidth, layout.panelHeight, "Records")
  local mouseX, mouseY = love.mouse.getPosition()
  if not Button.containsPoint({ x = listContent.x, y = listContent.y, width = listContent.width, height = listContent.height }, mouseX, mouseY) then
    return
  end

  local visibleRows = getVisibleRowCount(listContent.height)
  if #self:getRecords(app) > visibleRows then
    visibleRows = getVisibleRowCount(listContent.height - ((SCROLL_BUTTON_HEIGHT + ENTRY_BUTTON_GAP) * 2))
  end
  self.visibleRows = visibleRows

  self:scrollRecords(app, y > 0 and -1 or 1)
end

function RecordsState:draw(app)
  local layout = self:getLayout()
  local records = self:getRecords(app)
  self:clampSelection(app)
  local record = records[self.selectedIndex]

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Run Records", 76, app.fonts.title, Theme.colors.text)
  Layout.centeredText(string.format("%d stored run(s)", #records), 116, app.fonts.heading, Theme.colors.accent)

  Panel.draw(layout.padding, layout.panelY, layout.listWidth, layout.panelHeight, "Records")
  Panel.draw(layout.padding + layout.listWidth + layout.gap, layout.panelY, layout.detailWidth, layout.panelHeight, "Details")

  local listContent = Panel.getContentArea(layout.padding, layout.panelY, layout.listWidth, layout.panelHeight, "Records")
  local detailContent = Panel.getContentArea(layout.padding + layout.listWidth + layout.gap, layout.panelY, layout.detailWidth, layout.panelHeight, "Details")

  local detailLines = {}
  for _, line in ipairs(app:getRunRecordProgressLines()) do
    table.insert(detailLines, line)
  end
  table.insert(detailLines, "")
  for _, line in ipairs(app:getRunRecordDetailLines(record)) do
    table.insert(detailLines, line)
  end

  love.graphics.setFont(app.fonts.body)
  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildEntryButtons(app, listContent), mouseX, mouseY)
  Layout.drawWrappedLines(detailLines, detailContent.x, detailContent.y, detailContent.width, Theme.colors.text, Theme.spacing.lineHeight, detailContent.height)
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function RecordsState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout()
  local listContent = Panel.getContentArea(layout.padding, layout.panelY, layout.listWidth, layout.panelHeight, "Records")

  if Button.handleMousePressed(self:buildEntryButtons(app, listContent), x, y) then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return RecordsState
