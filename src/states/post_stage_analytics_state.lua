local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local PostStageAnalyticsState = {}
PostStageAnalyticsState.__index = PostStageAnalyticsState

local function trimLines(lines, limit)
  if not limit or #lines <= limit then
    return lines
  end

  local trimmed = {}

  for index = 1, limit - 1 do
    trimmed[index] = lines[index]
  end

  trimmed[limit] = string.format("... (%d more line%s)", #lines - (limit - 1), (#lines - (limit - 1)) == 1 and "" or "s")
  return trimmed
end

function PostStageAnalyticsState.new()
  return setmetatable({ buttons = {} }, PostStageAnalyticsState)
end

function PostStageAnalyticsState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local destination = app:getPostResultDestinationState()
  local label = "Continue to Summary"

  if destination == "reward_preview" then
    label = "Continue to Reward Preview"
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
  local report = app:buildPostStageAnalyticsReport()
  local stageRecord = app.lastStageResult or {}
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelY = 116
  local contentBottomY = footerMetrics.contentBottomY
  local availableHeight = math.max(340, contentBottomY - panelY)
  local topHeight = math.min(196, math.max(150, math.floor((availableHeight - gap) * 0.34)))
  local bottomY = panelY + topHeight + gap
  local bottomHeight = math.max(190, contentBottomY - bottomY)
  local halfWidth = math.floor((width - (padding * 2) - gap) / 2)
  local titleColor = stageRecord.status == "cleared" and Theme.colors.accent or Theme.colors.warning

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Post-Stage Analytics", 68, app.fonts.title, titleColor)

  Panel.draw(padding, panelY, width - (padding * 2), topHeight, "Stage Snapshot")
  Panel.draw(padding, bottomY, halfWidth, bottomHeight, "Batch + Coin Stats")
  Panel.draw(padding + halfWidth + gap, bottomY, halfWidth, bottomHeight, "Trace + Follow-up")

  local topContent = Panel.getContentArea(padding, panelY, width - (padding * 2), topHeight, "Stage Snapshot")
  local bottomLeftContent = Panel.getContentArea(padding, bottomY, halfWidth, bottomHeight, "Batch + Coin Stats")
  local bottomRightContent = Panel.getContentArea(padding + halfWidth + gap, bottomY, halfWidth, bottomHeight, "Trace + Follow-up")
  local distributionHeight = math.max(90, math.min(math.floor(bottomLeftContent.height * 0.34), bottomLeftContent.height - (Theme.spacing.lineHeight * 4)))
  local lastBatchY = bottomLeftContent.y + distributionHeight + Theme.spacing.itemGap
  local lastBatchHeight = math.max(0, bottomLeftContent.height - distributionHeight - Theme.spacing.itemGap)

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(trimLines(report.stageLines or { "No stage analytics available." }, 10), topContent.x, topContent.y, topContent.width, Theme.colors.text, Theme.spacing.lineHeight, topContent.height)
  Layout.drawWrappedLines(trimLines(report.distributionLines or { "No distribution data available." }, 7), bottomLeftContent.x, bottomLeftContent.y, bottomLeftContent.width, Theme.colors.text, Theme.spacing.lineHeight, distributionHeight)
  Layout.drawWrappedLines(trimLines(report.lastBatchLines or { "No batch data available." }, 8), bottomLeftContent.x, lastBatchY, bottomLeftContent.width, Theme.colors.mutedText, Theme.spacing.lineHeight, lastBatchHeight)
  Layout.drawWrappedLines(trimLines(report.traceLines or { "No trace data available." }, 10), bottomRightContent.x, bottomRightContent.y, bottomRightContent.width, Theme.colors.text, Theme.spacing.lineHeight, bottomRightContent.height)

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
