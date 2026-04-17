local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local SummaryState = {}
SummaryState.__index = SummaryState

function SummaryState.new()
  return setmetatable({
    buttons = {},
  }, SummaryState)
end

function SummaryState:enter(app, payload, previousName)
  local summary = app:buildSummary()
  local won = summary and summary.runStatus == "won"

  if previousName == "meta" then
    return
  end

  app:showFeedback(
    won and "success" or "danger",
    won and "Run Won" or "Run Ended",
    won and "The table is yours. Review the run summary below." or "The run is over. Review the run summary below.",
    {
      duration = 1.5,
      flashAlpha = won and 0.07 or 0.05,
      soundCue = won and "run_win" or "run_loss",
    }
  )
end

function SummaryState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 260
  local buttonHeight = metrics.buttonHeight
  local gap = Theme.spacing.itemGap
  local totalWidth = (buttonWidth * 2) + gap
  local startX = math.floor((love.graphics.getWidth() - totalWidth) / 2)

  self.buttons = {
    {
      x = startX,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Open Meta Progression",
      variant = "accent",
      onClick = function()
        return app.stateGraph:request("open_meta")
      end,
    },
    {
      x = startX + buttonWidth + gap,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Return to Menu",
      variant = "primary",
      onClick = function()
        return app.stateGraph:request("return_to_menu")
      end,
    },
  }

  return self.buttons
end

function SummaryState:keypressed(app, key)
  if key == "m" then
    app.stateGraph:request("open_meta")
    return
  end

  if key == "return" or key == "space" or key == "kpenter" or key == "escape" then
    app.stateGraph:request("return_to_menu")
  end
end

function SummaryState:draw(app)
  local summary = app:buildSummary()
  local color = summary.runStatus == "won" and Theme.colors.success or Theme.colors.text
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local statsPanelX = padding
  local statsPanelY = 132
  local statsPanelWidth = width - (padding * 2)
  local availableContentHeight = math.max(320, footerMetrics.contentBottomY - statsPanelY)
  local statsPanelHeight = math.min(220, math.max(140, math.floor((availableContentHeight - gap) * 0.42)))
  local historyPanelY = statsPanelY + statsPanelHeight + gap
  local historyPanelHeight = math.max(140, footerMetrics.contentBottomY - historyPanelY)
  local historyPanelWidth = math.floor((statsPanelWidth - gap) / 2)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Run Summary", 76, app.fonts.title, color)

  Panel.draw(statsPanelX, statsPanelY, statsPanelWidth, statsPanelHeight, "Summary")
  Panel.draw(statsPanelX, historyPanelY, historyPanelWidth, historyPanelHeight, "Stage History")
  Panel.draw(statsPanelX + historyPanelWidth + gap, historyPanelY, historyPanelWidth, historyPanelHeight, "Shop History")

  local statsContent = Panel.getContentArea(statsPanelX, statsPanelY, statsPanelWidth, statsPanelHeight, "Summary")
  local stageHistoryContent = Panel.getContentArea(statsPanelX, historyPanelY, historyPanelWidth, historyPanelHeight, "Stage History")
  local shopHistoryContent = Panel.getContentArea(statsPanelX + historyPanelWidth + gap, historyPanelY, historyPanelWidth, historyPanelHeight, "Shop History")

  local summaryLines = {
    string.format("Run Status: %s", summary.runStatus),
    string.format("Final Round Reached: %d", summary.roundIndex),
    string.format("Run Total Score: %d", summary.runTotalScore),
    string.format("Shop Points Remaining: %d", summary.shopPoints),
    string.format("Collection Size: %d", summary.collectionSize),
    string.format("Upgrade Count: %d", summary.upgradeCount),
    string.format("Shop Visits: %d", summary.shopVisitCount or 0),
    string.format("Total Rerolls Used: %d", summary.totalRerollsUsed or 0),
    string.format("Meta Reward Earned: %d", summary.metaRewardEarned or 0),
    string.format("Total Flips: %d", summary.totalFlips),
    string.format("Matches / Misses: %d / %d", summary.totalMatches, summary.totalMisses),
    string.format("Final Stage: %s", summary.finalStageLabel),
    string.format("Final Stage Status: %s", summary.finalStageStatus),
    "",
  }

  for _, line in ipairs(app:getSummaryMetaHandoffLines()) do
    table.insert(summaryLines, line)
  end

  table.insert(summaryLines, "")
  table.insert(summaryLines, "Click Open Meta Progression or press M, or Return to Menu with Enter.")

  local stageHistoryLines = {}
  for _, stageRecord in ipairs(summary.stageHistory or {}) do
    local line = string.format("- R%d %s => %s (%d/%d)", stageRecord.roundIndex, stageRecord.stageLabel, stageRecord.status, stageRecord.stageScore, stageRecord.targetScore)

    if stageRecord.rewardChoice then
      line = string.format("%s | Reward: %s", line, stageRecord.rewardChoice.name or stageRecord.rewardChoice.contentId or "n/a")
    elseif stageRecord.rewardOptions then
      line = string.format("%s | Reward: none available", line)
    end

    table.insert(stageHistoryLines, line)
  end

  if #stageHistoryLines == 0 then
    stageHistoryLines = { "- No stage history recorded." }
  end

  local shopHistoryLines = app:getPurchaseHistoryLines(14)
  table.insert(shopHistoryLines, 1, string.format("Rerolls Used: %d", summary.totalRerollsUsed or 0))
  table.insert(shopHistoryLines, 1, string.format("Shop Visits: %d", summary.shopVisitCount or 0))

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(summaryLines, statsContent.x, statsContent.y, statsContent.width, Theme.colors.text, Theme.spacing.lineHeight, statsContent.height)
  Layout.drawWrappedLines(stageHistoryLines, stageHistoryContent.x, stageHistoryContent.y, stageHistoryContent.width, Theme.colors.text, Theme.spacing.lineHeight, stageHistoryContent.height)
  Layout.drawWrappedLines(shopHistoryLines, shopHistoryContent.x, shopHistoryContent.y, shopHistoryContent.width, Theme.colors.text, Theme.spacing.lineHeight, shopHistoryContent.height)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function SummaryState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return SummaryState
