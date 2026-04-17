local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local BossRewardState = {}
BossRewardState.__index = BossRewardState

local function getWrappedLineCount(text, width)
  local font = love.graphics.getFont()
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped)
end

local function getRewardCardHeight(card, width)
  local descriptionLines = getWrappedLineCount(card.description, math.max(1, width - 18))
  return 24 + (descriptionLines * Theme.spacing.lineHeight) + 8
end

function BossRewardState.new()
  return setmetatable({
    statusMessage = "Choose one final reward, then continue to the summary.",
    rewardButtons = {},
    buttons = {},
  }, BossRewardState)
end

function BossRewardState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local topY = 128
  local availableHeight = math.max(260, footerMetrics.contentBottomY - topY)
  local topHeight = math.max(180, math.floor((availableHeight - gap) * 0.38))
  local bottomY = topY + topHeight + gap
  local bottomHeight = math.max(160, footerMetrics.contentBottomY - bottomY)
  local columnWidth = math.floor((width - (padding * 2) - (gap * 2)) / 3)
  local middleX = padding + columnWidth + gap
  local rightX = middleX + columnWidth + gap
  local rightWidth = width - rightX - padding

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    footerMetrics = footerMetrics,
    topY = topY,
    topHeight = topHeight,
    bottomY = bottomY,
    bottomHeight = bottomHeight,
    columnWidth = columnWidth,
    middleX = middleX,
    rightX = rightX,
    rightWidth = rightWidth,
  }
end

function BossRewardState:selectRewardOption(app, index)
  local ok, result = app:selectRewardOption(index)

  if ok and result then
    self.statusMessage = string.format("Selected reward: %s.", result.name or result.contentId or tostring(index))
  elseif not ok then
    self.statusMessage = tostring(result)
  end

  return ok, result
end

function BossRewardState:tryContinue(app)
  if not app:canContinueRewardPreview() then
    self.statusMessage = "Choose a final reward before continuing."
    return false, "reward_choice_required"
  end

  return app.stateGraph:request("continue")
end

function BossRewardState:buildRewardButtons(app, area)
  local session = app:ensureBossRewardEvent()
  local buttonHeight = 38
  local gap = Theme.spacing.itemGap

  self.rewardButtons = {}

  for index, option in ipairs(app:getRewardPreviewOptionCards()) do
    table.insert(self.rewardButtons, {
      x = area.x,
      y = area.y + ((index - 1) * (buttonHeight + gap)),
      width = area.width,
      height = buttonHeight,
      label = string.format("%s Reward: %s", string.upper(option.type or "?"), option.name or option.contentId or "Unknown"),
      variant = option.selected and "success" or "default",
      focused = option.selected == true,
      disabled = session and session.claimed == true,
      onClick = function()
        return self:selectRewardOption(app, index)
      end,
    })
  end

  return self.rewardButtons
end

function BossRewardState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 320

  self.buttons = {
    {
      x = math.floor((love.graphics.getWidth() - buttonWidth) / 2),
      y = metrics.buttonY,
      width = buttonWidth,
      height = metrics.buttonHeight,
      label = app:getBossRewardContinueLabel(),
      variant = "success",
      disabled = not app:canContinueRewardPreview(),
      onClick = function()
        return self:tryContinue(app)
      end,
    },
  }

  return self.buttons
end

function BossRewardState:enter(app)
  local session = app:ensureBossRewardEvent()

  if session and #(session.options or {}) > 0 then
    self.statusMessage = "Choose one final reward, then continue to the summary."
  else
    self.statusMessage = "No final rewards remain. Continue to the summary."
  end
end

function BossRewardState:keypressed(app, key)
  local session = app:ensureBossRewardEvent()

  if key == "1" or key == "2" then
    self:selectRewardOption(app, tonumber(key))
    return
  end

  if key == "left" or key == "up" then
    if session and #(session.options or {}) > 0 then
      if session.selectedIndex == nil then
        self:selectRewardOption(app, 1)
      else
        self:selectRewardOption(app, math.max(1, session.selectedIndex - 1))
      end
    end
    return
  end

  if key == "right" or key == "down" then
    if session and #(session.options or {}) > 0 then
      if session.selectedIndex == nil then
        self:selectRewardOption(app, 1)
      else
        self:selectRewardOption(app, math.min(#session.options, session.selectedIndex + 1))
      end
    end
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryContinue(app)
  end
end

function BossRewardState:draw(app)
  local layout = self:getLayout(app)
  local rewardSession = app:ensureBossRewardEvent()
  local rewardLines = app:getBossRewardLines()
  local projectedOutcome = app:getProjectedRewardOutcome()
  local projectedImpactLines = app:getProjectedRewardImpactLines({ finalReward = true }, projectedOutcome)
  local summaryLines = app:getBossRewardSummaryLines()
  local handoffLines = app:getSummaryMetaHandoffLines()

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Victory Reward", 64, app.fonts.title, Theme.colors.success)

  Panel.draw(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Final Reward")
  Panel.draw(layout.padding, layout.bottomY, layout.columnWidth, layout.bottomHeight, "Projected Impact")
  Panel.draw(layout.middleX, layout.bottomY, layout.columnWidth, layout.bottomHeight, "Run Complete")
  Panel.draw(layout.rightX, layout.bottomY, layout.rightWidth, layout.bottomHeight, "Meta Handoff")

  local rewardArea = Panel.getContentArea(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Final Reward")
  local projectedArea = Panel.getContentArea(layout.padding, layout.bottomY, layout.columnWidth, layout.bottomHeight, "Projected Impact")
  local summaryArea = Panel.getContentArea(layout.middleX, layout.bottomY, layout.columnWidth, layout.bottomHeight, "Run Complete")
  local handoffArea = Panel.getContentArea(layout.rightX, layout.bottomY, layout.rightWidth, layout.bottomHeight, "Meta Handoff")

  table.insert(rewardLines, "")
  table.insert(rewardLines, self.statusMessage)

  local rewardButtonsHeight = 0
  if #(rewardSession and rewardSession.options or {}) > 0 then
    rewardButtonsHeight = (#rewardSession.options * 38) + math.max(0, (#rewardSession.options - 1) * Theme.spacing.itemGap) + Theme.spacing.itemGap
    table.insert(rewardLines, "")
    table.insert(rewardLines, "Reward Options:")
    table.insert(rewardLines, "Use 1/2, arrow keys, or click to choose.")
  else
    table.insert(rewardLines, "")
    table.insert(rewardLines, "Reward Options:")
    table.insert(rewardLines, "No final rewards remain for this victory.")
  end

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(rewardLines, rewardArea.x, rewardArea.y, rewardArea.width, Theme.colors.text, Theme.spacing.lineHeight, math.max(0, rewardArea.height - rewardButtonsHeight))
  Layout.drawWrappedLines(projectedImpactLines, projectedArea.x, projectedArea.y, projectedArea.width, Theme.colors.text, Theme.spacing.lineHeight, projectedArea.height)
  Layout.drawWrappedLines(handoffLines, handoffArea.x, handoffArea.y, handoffArea.width, Theme.colors.text, Theme.spacing.lineHeight, handoffArea.height)

  if rewardButtonsHeight > 0 then
    local mouseX, mouseY = love.mouse.getPosition()
    local rewardButtonsY = rewardArea.y + rewardArea.height - rewardButtonsHeight + Theme.spacing.itemGap
    local rewardButtonArea = { x = rewardArea.x, y = rewardButtonsY, width = rewardArea.width }
    Button.drawButtons(self:buildRewardButtons(app, rewardButtonArea), mouseX, mouseY)
  end

  local summaryTextHeight = 0
  for _, line in ipairs(summaryArea.height > 0 and summaryLines or {}) do
    summaryTextHeight = summaryTextHeight + (getWrappedLineCount(line, summaryArea.width) * Theme.spacing.lineHeight)
  end

  local summaryLinesHeight = math.min(summaryArea.height, summaryTextHeight)
  Layout.drawWrappedLines(summaryLines, summaryArea.x, summaryArea.y, summaryArea.width, Theme.colors.text, Theme.spacing.lineHeight, summaryLinesHeight)

  local cardY = summaryArea.y + summaryLinesHeight + Theme.spacing.itemGap
  local remainingHeight = summaryArea.height - summaryLinesHeight - Theme.spacing.itemGap

  for _, card in ipairs(app:getBossModifierCards((app.lastStageResult and app.lastStageResult.bossModifierIds) or {})) do
    local cardHeight = getRewardCardHeight(card, summaryArea.width)
    if cardY + cardHeight > (summaryArea.y + summaryArea.height) then
      break
    end

    love.graphics.setColor(Theme.colors.danger)
    love.graphics.rectangle("fill", summaryArea.x, cardY, 6, cardHeight, 4, 4)
    love.graphics.setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", summaryArea.x + 8, cardY, summaryArea.width - 8, cardHeight, 8, 8)
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("line", summaryArea.x + 8, cardY, summaryArea.width - 8, cardHeight, 8, 8)

    love.graphics.setColor(Theme.colors.text)
    love.graphics.print(card.name, summaryArea.x + 18, cardY + 8)
    Layout.drawWrappedText(card.description or "", summaryArea.x + 18, cardY + 26, summaryArea.width - 28, Theme.colors.mutedText, Theme.spacing.lineHeight)
    cardY = cardY + cardHeight + Theme.spacing.itemGap
    remainingHeight = remainingHeight - cardHeight - Theme.spacing.itemGap

    if remainingHeight <= 0 then
      break
    end
  end

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function BossRewardState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)
  local rewardArea = Panel.getContentArea(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Final Reward")
  local rewardSession = app:ensureBossRewardEvent()

  if #(rewardSession and rewardSession.options or {}) > 0 then
    local rewardButtonsHeight = (#rewardSession.options * 38) + math.max(0, (#rewardSession.options - 1) * Theme.spacing.itemGap) + Theme.spacing.itemGap
    local rewardButtonsY = rewardArea.y + rewardArea.height - rewardButtonsHeight + Theme.spacing.itemGap
    local rewardButtonArea = { x = rewardArea.x, y = rewardButtonsY, width = rewardArea.width }
    local handled = select(1, Button.handleMousePressed(self:buildRewardButtons(app, rewardButtonArea), x, y))

    if handled then
      return
    end
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return BossRewardState
