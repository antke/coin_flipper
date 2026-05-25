local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
  return setmetatable({
    buttons = {},
    returnState = "menu",
    statusMessage = "Choose the logical resolution the UI is designed against.",
  }, SettingsState)
end

function SettingsState:enter(_, payload)
  self.returnState = payload and payload.returnState or "menu"
  self.statusMessage = "Choose the logical resolution the UI is designed against."
end

function SettingsState:getBackLabel()
  return self.returnState == "pause" and "Back to Pause" or "Back to Menu"
end

function SettingsState:selectTarget(app, targetId)
  local ok, errorMessage = app:setDisplayTarget(targetId)

  if ok then
    local target = app:getDisplayTarget()
    self.statusMessage = string.format("Resolution set to %s %dx%d.", target.label, target.width, target.height)
  else
    self.statusMessage = string.format("Resolution change failed: %s", tostring(errorMessage))
  end

  return ok, errorMessage
end

function SettingsState:buildButtons(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local targets = app:getDisplayTargets()
  local buttonHeight = footerMetrics.buttonHeight
  local buttonWidth = 360
  local gap = Theme.spacing.itemGap
  local totalHeight = (#targets * (buttonHeight + gap)) + buttonHeight
  local startX = math.floor((width - buttonWidth) * 0.5)
  local startY = math.floor((height - totalHeight) * 0.5)

  self.buttons = {}

  for index, target in ipairs(targets) do
    table.insert(self.buttons, {
      x = startX,
      y = startY + ((index - 1) * (buttonHeight + gap)),
      width = buttonWidth,
      height = buttonHeight,
      label = string.format("%s %dx%d", target.label, target.width, target.height),
      variant = app:getDisplayTargetId() == target.id and "primary" or "default",
      onClick = function()
        return self:selectTarget(app, target.id)
      end,
    })
  end

  table.insert(self.buttons, {
    x = startX,
    y = startY + (#targets * (buttonHeight + gap)),
    width = buttonWidth,
    height = buttonHeight,
    label = self:getBackLabel(),
    variant = "warning",
    onClick = function()
      return app.stateGraph:request("back", { returnState = self.returnState })
    end,
  })

  return self.buttons
end

function SettingsState:keypressed(app, key)
  if key == "escape" or key == "backspace" then
    app.stateGraph:request("back", { returnState = self.returnState })
  end
end

function SettingsState:draw(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local panelWidth = math.min(860, width - (padding * 2))
  local panelHeight = math.min(520, height - (padding * 4))
  local panelX = math.floor((width - panelWidth) * 0.5)
  local panelY = math.floor((height - panelHeight) * 0.5)
  local target = app:getDisplayTarget()

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Settings", panelY - 72, app.fonts.title, Theme.colors.text)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, "Target Resolution")
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Target Resolution")

  love.graphics.setFont(app.fonts.body)
  local lines = {
    string.format("Current target: %s %dx%d", target.label, target.width, target.height),
    "The game lays out UI at this logical resolution and scales the result to the window.",
    self.statusMessage,
  }
  Layout.drawWrappedLines(lines, contentArea.x, contentArea.y, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, math.floor(contentArea.height * 0.34))

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function SettingsState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return SettingsState
