local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local PostStageAnalyticsState = {}
PostStageAnalyticsState.__index = PostStageAnalyticsState

function PostStageAnalyticsState.new()
  return setmetatable({ buttons = {} }, PostStageAnalyticsState)
end

function PostStageAnalyticsState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local destination = app:getPostResultDestinationState()
  local label = "Continue to Summary"

  if destination == "reward_preview" then
    label = "Continue to Reward Preview"
  elseif destination == "shop" then
    label = "Continue to Shop"
  elseif destination == "boss_reward" then
    label = "Continue to Victory Reward"
  end
  local buttonWidth = 300

  self.buttons = {
    {
      x = math.floor((love.graphics.getWidth() - buttonWidth) / 2),
      y = metrics.buttonY,
      width = buttonWidth,
      height = metrics.buttonHeight,
      label = label,
      variant = "primary",
      onClick = function()
        return app.stateGraph:request("continue")
      end,
    },
  }

  return self.buttons
end

function PostStageAnalyticsState:keypressed(app, key)
  if key == "return" or key == "space" or key == "kpenter" then
    app.stateGraph:request("continue")
  end
end

function PostStageAnalyticsState:draw(app)
  local stageRecord = app.lastStageResult or {}
  local padding = Theme.spacing.screenPadding
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelY = 116
  local panelHeight = math.max(180, footerMetrics.contentBottomY - panelY)
  local titleColor = stageRecord.status == "cleared" and Theme.colors.accent or Theme.colors.warning

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Stage Review", 68, app.fonts.title, titleColor)

  Panel.draw(padding, panelY, width - (padding * 2), panelHeight, "Stage")
  local content = Panel.getContentArea(padding, panelY, width - (padding * 2), panelHeight, "Stage")
  local lines = {
    string.format("Stage: %s", stageRecord.stageLabel or stageRecord.stageId or "n/a"),
    string.format("Status: %s", tostring(stageRecord.status or "n/a")),
    string.format("Score: %d / %d", stageRecord.stageScore or 0, stageRecord.targetScore or 0),
    string.format("Run Total Score: %d", stageRecord.runTotalScore or (app.runState and app.runState.runTotalScore or 0)),
    app:getPostStageReviewFollowupLine(),
  }

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(lines, content.x, content.y, content.width, Theme.colors.text, Theme.spacing.lineHeight, content.height)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function PostStageAnalyticsState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return PostStageAnalyticsState
