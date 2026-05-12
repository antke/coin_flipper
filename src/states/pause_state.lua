local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local PauseState = {}
PauseState.__index = PauseState

function PauseState.new()
  return setmetatable({
    statusMessage = "Run paused. Resume, save and quit, or abandon the run.",
    buttons = {},
    confirmAbandon = false,
  }, PauseState)
end

function PauseState:getSummaryLines(app)
  local lines = {}

  if app.stageState then
    table.insert(lines, string.format("Stage: %s", app.stageState.stageLabel or app.stageState.stageId or "n/a"))
  elseif app.runState then
    table.insert(lines, string.format("Round: %d", app.runState.roundIndex or 0))
  end

  if app.runState then
    table.insert(lines, string.format("Run score: %d", app.runState.runTotalScore or 0))
  end

  table.insert(lines, "")
  table.insert(lines, self.statusMessage)

  return lines
end

function PauseState:tryResume(app)
  self.confirmAbandon = false
  return app.stateGraph:request("resume")
end

function PauseState:trySaveQuit(app)
  self.confirmAbandon = false
  return app.stateGraph:request("save_quit_to_menu")
end

function PauseState:tryAbandon(app)
  if not self.confirmAbandon then
    self.confirmAbandon = true
    self.statusMessage = "Press Abandon Run again (or A) to confirm. This clears the saved run."
    return false, "abandon_confirmation_required"
  end

  return app.stateGraph:request("abandon_run")
end

function PauseState:buildButtons(app)
  local width = love.graphics.getWidth()
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 240
  local buttonHeight = metrics.buttonHeight
  local gap = Theme.spacing.itemGap
  local totalWidth = (buttonWidth * 3) + (gap * 2)
  local startX = math.floor((width - totalWidth) * 0.5)

  self.buttons = {
    {
      x = startX,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Resume",
      variant = "primary",
      onClick = function()
        return self:tryResume(app)
      end,
    },
    {
      x = startX + buttonWidth + gap,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Save & Quit to Menu",
      variant = "warning",
      onClick = function()
        return self:trySaveQuit(app)
      end,
    },
    {
      x = startX + ((buttonWidth + gap) * 2),
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = self.confirmAbandon and "Confirm Abandon" or "Abandon Run",
      variant = "danger",
      onClick = function()
        return self:tryAbandon(app)
      end,
    },
  }

  return self.buttons
end

function PauseState:enter(app)
  self.confirmAbandon = false
  self.statusMessage = "Run paused. Resume, save and quit, or abandon the run."
end

function PauseState:keypressed(app, key)
  if key == "escape" or key == "p" or key == "backspace" then
    self:tryResume(app)
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryResume(app)
    return
  end

  if key == "s" then
    self:trySaveQuit(app)
    return
  end

  if key == "a" then
    self:tryAbandon(app)
  end
end

function PauseState:draw(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelWidth = math.min(860, width - (padding * 2))
  local panelX = math.floor((width - panelWidth) * 0.5)
  local panelY = 160
  local panelHeight = math.max(220, footerMetrics.contentBottomY - panelY)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Run Paused", 92, app.fonts.title, Theme.colors.text)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, "Pause Menu")
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Pause Menu")

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(self:getSummaryLines(app), contentArea.x, contentArea.y, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height - footerMetrics.buttonsHeight - Theme.spacing.itemGap)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function PauseState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return PauseState
