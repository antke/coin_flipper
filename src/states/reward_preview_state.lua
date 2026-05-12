local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local RewardPreviewState = {}
RewardPreviewState.__index = RewardPreviewState

local function formatRewardError(errorCode)
  if errorCode == "invalid_reward_option" then
    return "That reward option is no longer available."
  end

  if errorCode == "reward_preview_not_initialized" or errorCode == "reward_preview_unavailable" then
    return "No reward preview is currently active."
  end

  if errorCode == "reward_option_not_selected" or errorCode == "reward_choice_required" then
    return "Choose a reward before continuing."
  end

  if errorCode == "reward_already_claimed" then
    return "That reward has already been claimed."
  end

  return tostring(errorCode)
end

local function getWrappedLineCount(text, width)
  local font = love.graphics.getFont()
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped)
end

local function getPreviewCardHeight(card, width)
  return 32
end

function RewardPreviewState.new()
  return setmetatable({
    statusMessage = "Choose a reward, then continue to the shop.",
    rewardButtons = {},
    buttons = {},
  }, RewardPreviewState)
end

function RewardPreviewState:getLayout(app)
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
  local columnWidth = math.floor((width - (padding * 2) - gap) / 2)
  local middleX = padding + columnWidth + gap
  local rightX = middleX
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

function RewardPreviewState:selectRewardOption(app, index)
  local ok, result = app:selectRewardOption(index)

  if ok and result then
    self.statusMessage = string.format("Selected reward: %s.", result.name or result.contentId or tostring(index))
  elseif not ok then
    self.statusMessage = formatRewardError(result)
  end

  return ok, result
end

function RewardPreviewState:tryContinue(app)
  if not app:canContinueRewardPreview() then
    self.statusMessage = "Choose a reward before continuing."
    return false, "reward_choice_required"
  end

  return app.stateGraph:request("continue")
end

function RewardPreviewState:buildRewardButtons(app, area)
  local session = app:ensureRewardPreview()
  local buttonHeight = 44
  local gap = Theme.spacing.itemGap

  self.rewardButtons = {}

  for index, option in ipairs(app:getRewardPreviewOptionCards()) do
    table.insert(self.rewardButtons, {
      x = area.x,
      y = area.y + ((index - 1) * (buttonHeight + gap)),
      width = area.width,
      height = buttonHeight,
      label = string.format("%d. %s", index, option.name or option.contentId or "Unknown"),
      variant = option.selected and "primary" or "default",
      focused = option.selected == true,
      disabled = session and session.claimed == true,
      onClick = function()
        return self:selectRewardOption(app, index)
      end,
    })
  end

  return self.rewardButtons
end

function RewardPreviewState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 300
  local buttonHeight = metrics.buttonHeight

  self.buttons = {
    {
      x = math.floor((love.graphics.getWidth() - buttonWidth) / 2),
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = app:getRewardPreviewContinueLabel(),
      variant = "primary",
      disabled = not app:canContinueRewardPreview(),
      onClick = function()
        return self:tryContinue(app)
      end,
    },
  }

  return self.buttons
end

function RewardPreviewState:enter(app)
  local session = app:ensureRewardPreview()

  if session and #(session.options or {}) > 0 then
    self.statusMessage = "Choose one reward, then continue to the shop."
  else
    self.statusMessage = "No reward options remain. Continue to the shop."
  end
end

function RewardPreviewState:keypressed(app, key)
  local session = app:ensureRewardPreview()
  local numericIndex = tonumber(key)

  if numericIndex and numericIndex >= 1 then
    self:selectRewardOption(app, numericIndex)
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

function RewardPreviewState:draw(app)
  local layout = self:getLayout(app)
  local rewardSession = app:ensureRewardPreview()
  local projectedOutcome = app:getProjectedRewardOutcome()
  local projectedImpactLines = app:getProjectedRewardImpactLines({}, projectedOutcome)
  local stagePreview = app:getProjectedUpcomingStagePreviewData(projectedOutcome)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Reward Preview", 64, app.fonts.title, Theme.colors.accent)

  Panel.draw(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Reward")
  Panel.draw(layout.padding, layout.bottomY, layout.columnWidth, layout.bottomHeight, "Projected Impact")
  Panel.draw(layout.rightX, layout.bottomY, layout.rightWidth, layout.bottomHeight, stagePreview.title or "After the Shop")

  local rewardArea = Panel.getContentArea(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Reward")
  local impactArea = Panel.getContentArea(layout.padding, layout.bottomY, layout.columnWidth, layout.bottomHeight, "Projected Impact")
  local stageArea = Panel.getContentArea(layout.rightX, layout.bottomY, layout.rightWidth, layout.bottomHeight, stagePreview.title or "After the Shop")

  local rewardLines = app:getRewardPreviewLines()
  table.insert(rewardLines, "")
  table.insert(rewardLines, self.statusMessage)
  local rewardButtonsHeight = 0
  if #(rewardSession and rewardSession.options or {}) > 0 then
    rewardButtonsHeight = (#rewardSession.options * 44) + math.max(0, (#rewardSession.options - 1) * Theme.spacing.itemGap) + Theme.spacing.itemGap
  else
    table.insert(rewardLines, "")
    table.insert(rewardLines, "No valid reward options remain for this stage.")
  end

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(rewardLines, rewardArea.x, rewardArea.y, rewardArea.width, Theme.colors.text, Theme.spacing.lineHeight, math.max(0, rewardArea.height - rewardButtonsHeight))
  Layout.drawWrappedLines(projectedImpactLines, impactArea.x, impactArea.y, impactArea.width, Theme.colors.text, Theme.spacing.lineHeight, impactArea.height)

  if rewardButtonsHeight > 0 then
    local mouseX, mouseY = love.mouse.getPosition()
    local rewardButtonsY = rewardArea.y + rewardArea.height - rewardButtonsHeight + Theme.spacing.itemGap
    local rewardButtonArea = { x = rewardArea.x, y = rewardButtonsY, width = rewardArea.width }
    Button.drawButtons(self:buildRewardButtons(app, rewardButtonArea), mouseX, mouseY)
  end

  local previewLinesHeight = 0
  for _, line in ipairs(stagePreview.lines or {}) do
    previewLinesHeight = previewLinesHeight + (getWrappedLineCount(line, stageArea.width) * Theme.spacing.lineHeight)
  end

  local stageLineHeight = math.min(stageArea.height, previewLinesHeight)
  Layout.drawWrappedLines(stagePreview.lines or {}, stageArea.x, stageArea.y, stageArea.width, Theme.colors.text, Theme.spacing.lineHeight, stageLineHeight)

  local cardY = stageArea.y + stageLineHeight + Theme.spacing.itemGap
  local remainingHeight = stageArea.height - stageLineHeight - Theme.spacing.itemGap

  for _, card in ipairs(stagePreview.cards or {}) do
    local cardHeight = getPreviewCardHeight(card, stageArea.width)
    if cardY + cardHeight > (stageArea.y + stageArea.height) then
      break
    end

    love.graphics.setColor(stagePreview.isBoss and Theme.colors.danger or Theme.colors.accent)
    love.graphics.rectangle("fill", stageArea.x, cardY, 6, cardHeight, 4, 4)
    love.graphics.setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", stageArea.x + 8, cardY, stageArea.width - 8, cardHeight, 8, 8)
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("line", stageArea.x + 8, cardY, stageArea.width - 8, cardHeight, 8, 8)

    love.graphics.setColor(Theme.colors.text)
    love.graphics.print(card.name, stageArea.x + 18, cardY + 8)
    cardY = cardY + cardHeight + Theme.spacing.itemGap
    remainingHeight = remainingHeight - cardHeight - Theme.spacing.itemGap

    if remainingHeight <= 0 then
      break
    end
  end

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function RewardPreviewState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local layout = self:getLayout(app)
  local rewardArea = Panel.getContentArea(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Reward")
  local rewardSession = app:ensureRewardPreview()

  if #(rewardSession and rewardSession.options or {}) > 0 then
    local rewardButtonsHeight = (#rewardSession.options * 44) + math.max(0, (#rewardSession.options - 1) * Theme.spacing.itemGap) + Theme.spacing.itemGap
    local rewardButtonsY = rewardArea.y + rewardArea.height - rewardButtonsHeight + Theme.spacing.itemGap
    local rewardButtonArea = { x = rewardArea.x, y = rewardButtonsY, width = rewardArea.width }
    local handled = select(1, Button.handleMousePressed(self:buildRewardButtons(app, rewardButtonArea), x, y))

    if handled then
      return
    end
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return RewardPreviewState
