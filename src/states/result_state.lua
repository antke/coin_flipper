local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local ResultState = {}
ResultState.__index = ResultState

function ResultState.new()
  return setmetatable({
    buttons = {},
  }, ResultState)
end

function ResultState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 260
  local buttonHeight = metrics.buttonHeight

  self.buttons = {
    {
      x = math.floor((love.graphics.getWidth() - buttonWidth) / 2),
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Continue",
      variant = "primary",
      onClick = function()
        return app.stateGraph:request("continue")
      end,
    },
  }

  return self.buttons
end

function ResultState:keypressed(app, key)
  if key == "return" or key == "space" or key == "kpenter" then
    app.stateGraph:request("continue")
  end
end

function ResultState:draw(app)
  local result = app.lastStageResult or {}
  local titleColor = result.status == "cleared" and Theme.colors.success or Theme.colors.danger
  local destination = app:getPostResultDestinationLabel()
  local padding = Theme.spacing.screenPadding
  local footerMetrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local panelX = padding
  local panelY = 156
  local panelWidth = love.graphics.getWidth() - (padding * 2)
  local panelHeight = math.max(160, footerMetrics.contentBottomY - panelY)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText(string.upper(result.status or "stage result"), 72, app.fonts.title, titleColor)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, "Result")
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Result")
  local lines = {}

  local victoryChipLine = app:formatVictoryChipRewardLine(result)
  if victoryChipLine then
    table.insert(lines, victoryChipLine)
  end

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Reputation +%d", result.metaRewardEarned))
  end

  if #lines > 0 then
    table.insert(lines, "")
  end

  table.insert(lines, string.format("Next: %s", destination))

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(lines, contentArea.x, contentArea.y, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function ResultState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return ResultState
