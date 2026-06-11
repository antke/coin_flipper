local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Terminology = require("src.content.terminology")
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

function RewardPreviewState.new()
  return setmetatable({
    statusMessage = "Choose a reward, then continue to the Black Market.",
    rewardButtons = {},
    buttons = {},
  }, RewardPreviewState)
end

function RewardPreviewState:getLayout(app)
  local padding = Theme.spacing.screenPadding
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local topY = 128
  local availableHeight = math.max(260, footerMetrics.contentBottomY - topY)

  return {
    padding = padding,
    width = width,
    height = height,
    footerMetrics = footerMetrics,
    topY = topY,
    topHeight = availableHeight,
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

function RewardPreviewState:tryReroll(app)
  local ok, result = app:rerollRewardOptions()

  if ok then
    self.statusMessage = "Rerolled reward choices."
  else
    self.statusMessage = formatRewardError(result)
  end

  return ok, result
end

function RewardPreviewState:trySkip(app)
  local ok, result = app:skipRewardForCurrency()

  if ok then
    self.statusMessage = string.format("Skipped reward for +%d Influence. Continue to the Black Market.", result.amount or 0)
  else
    self.statusMessage = formatRewardError(result)
  end

  return ok, result
end

function RewardPreviewState:getRewardContentAreas(rewardArea, hasOptions)
  if not hasOptions then
    return rewardArea, nil
  end

  local gap = Theme.spacing.blockGap
  local summaryHeight = math.max(Theme.scale(86), math.min(Theme.scale(124), math.floor(rewardArea.height * 0.28)))

  return {
    x = rewardArea.x,
    y = rewardArea.y,
    width = rewardArea.width,
    height = summaryHeight,
  }, {
    x = rewardArea.x,
    y = rewardArea.y + summaryHeight + gap,
    width = rewardArea.width,
    height = math.max(0, rewardArea.height - summaryHeight - gap),
  }
end

function RewardPreviewState:getRewardCardLayout(app, area)
  local cards = app:getRewardPreviewOptionCards()
  local count = #cards

  if count == 0 or not area then
    return {}
  end

  local gap = Theme.spacing.blockGap
  local columns = math.min(3, count)
  local rows = math.max(1, math.ceil(count / columns))
  local panelWidth = math.floor((area.width - (gap * (columns - 1))) / columns)
  local panelHeight = math.max(Theme.scale(150), math.floor((area.height - (gap * (rows - 1))) / rows))
  local layout = {}

  for index, card in ipairs(cards) do
    local row = math.floor((index - 1) / columns)
    local column = (index - 1) % columns

    table.insert(layout, {
      index = card.index or index,
      option = card,
      x = area.x + (column * (panelWidth + gap)),
      y = area.y + (row * (panelHeight + gap)),
      width = panelWidth,
      height = panelHeight,
    })
  end

  return layout
end

function RewardPreviewState:buildRewardButtons(app, cardLayout)
  local session = app:ensureRewardPreview()
  local buttonHeight = 38

  self.rewardButtons = {}

  for _, entry in ipairs(cardLayout or {}) do
    local option = entry.option
    local contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, string.format("Choice %d", entry.index))

    table.insert(self.rewardButtons, {
      x = contentArea.x,
      y = contentArea.y + contentArea.height - buttonHeight,
      width = contentArea.width,
      height = buttonHeight,
      label = option.selected and "Selected" or "Choose",
      variant = option.selected and "success" or "primary",
      focused = option.selected == true,
      disabled = session and session.claimed == true,
      onClick = function()
        return self:selectRewardOption(app, entry.index)
      end,
    })
  end

  return self.rewardButtons
end

function RewardPreviewState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.itemGap
  local buttonWidth = math.floor((love.graphics.getWidth() - (padding * 2) - (gap * 2)) / 3)
  local buttonHeight = metrics.buttonHeight
  local session = app:getRewardSession()
  local rewardActionDisabled = session == nil or session.claimed == true

  self.buttons = {
    {
      x = padding,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Reroll Rewards",
      variant = "warning",
      disabled = rewardActionDisabled,
      onClick = function()
        return self:tryReroll(app)
      end,
    },
    {
      x = padding + buttonWidth + gap,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = string.format("Skip (+%d Influence)", app:getRewardSkipInfluenceAmount()),
      variant = "default",
      disabled = rewardActionDisabled,
      onClick = function()
        return self:trySkip(app)
      end,
    },
    {
      x = padding + ((buttonWidth + gap) * 2),
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

function RewardPreviewState:drawRewardCard(app, entry)
  local option = entry.option or {}
  local title = string.format("Choice %d", entry.index)
  local contentArea

  Panel.draw(entry.x, entry.y, entry.width, entry.height, title)
  contentArea = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, title)

  if option.selected then
    Theme.applyColor(Theme.colors.success)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", entry.x, entry.y, entry.width, entry.height, 8, 8)
    love.graphics.setLineWidth(1)
  end

  local buttonHeight = 38
  local artSize = math.min(Theme.scale(76), math.max(Theme.scale(48), math.floor(contentArea.width * 0.30)))
  local textX = contentArea.x + artSize + Theme.spacing.itemGap
  local textY = contentArea.y
  local textWidth = contentArea.width - artSize - Theme.spacing.itemGap
  local badge = option.type == "coin" and "C" or "T"

  love.graphics.setColor(Theme.colors.highlight[1], Theme.colors.highlight[2], Theme.colors.highlight[3], option.selected and 0.28 or 0.18)
  love.graphics.rectangle("fill", contentArea.x, contentArea.y, artSize, artSize, 10, 10)
  Theme.applyColor(option.selected and Theme.colors.success or Theme.colors.highlight)
  love.graphics.rectangle("line", contentArea.x, contentArea.y, artSize, artSize, 10, 10)
  love.graphics.setFont(app.fonts.heading)
  love.graphics.printf(badge, contentArea.x, contentArea.y + math.floor((artSize - Theme.spacing.lineHeight) / 2), artSize, "center")
  love.graphics.setFont(app.fonts.body)

  local typeLine = option.displayType or option.type or "Reward"
  if option.wildcard then
    typeLine = typeLine .. " (Wildcard)"
  end

  local lines = {
    option.name or option.contentId or "Unknown Reward",
    typeLine,
    "",
    Terminology.getMechanicRichText(option.description or ""),
  }

  Layout.drawWrappedLines(lines, textX, textY, textWidth, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height - buttonHeight - Theme.spacing.itemGap)
end

function RewardPreviewState:enter(app)
  local session = app:ensureRewardPreview()

  if session and #(session.options or {}) > 0 then
    self.statusMessage = "Choose one reward, reroll, or skip for Influence."
  else
    self.statusMessage = "No reward options remain. Continue to the Black Market."
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

  if key == "r" then
    self:tryReroll(app)
    return
  end

  if key == "s" then
    self:trySkip(app)
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryContinue(app)
  end
end

function RewardPreviewState:draw(app)
  local layout = self:getLayout(app)
  local rewardSession = app:ensureRewardPreview()
  local hasOptions = #(rewardSession and rewardSession.options or {}) > 0

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Reward Preview", 64, app.fonts.title, Theme.colors.accent)

  Panel.draw(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Reward")

  local rewardArea = Panel.getContentArea(layout.padding, layout.topY, layout.width - (layout.padding * 2), layout.topHeight, "Choose Reward")

  local rewardLines = app:getRewardPreviewLines()
  table.insert(rewardLines, "")
  table.insert(rewardLines, self.statusMessage)
  if not hasOptions then
    table.insert(rewardLines, "")
    table.insert(rewardLines, "No valid reward options remain for this stage.")
  end

  local summaryArea, cardArea = self:getRewardContentAreas(rewardArea, hasOptions)

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(rewardLines, summaryArea.x, summaryArea.y, summaryArea.width, Theme.colors.text, Theme.spacing.lineHeight, summaryArea.height)

  if hasOptions then
    local mouseX, mouseY = love.mouse.getPosition()
    local cardLayout = self:getRewardCardLayout(app, cardArea)

    for _, entry in ipairs(cardLayout) do
      self:drawRewardCard(app, entry)
    end

    Button.drawButtons(self:buildRewardButtons(app, cardLayout), mouseX, mouseY)
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
    local _, cardArea = self:getRewardContentAreas(rewardArea, true)
    local handled = select(1, Button.handleMousePressed(self:buildRewardButtons(app, self:getRewardCardLayout(app, cardArea)), x, y))

    if handled then
      return
    end
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return RewardPreviewState
