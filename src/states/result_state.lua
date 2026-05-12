local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local ResultState = {}
ResultState.__index = ResultState

local function getWrappedLineCount(text, width)
  local font = love.graphics.getFont()
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped)
end

local function getBossCardHeight(card, width, compact)
  if compact then
    return 32
  end

  local bodyWidth = math.max(1, width - 30)
  local descriptionLines = getWrappedLineCount(card.description, bodyWidth)
  return 24 + (descriptionLines * Theme.spacing.lineHeight) + 8
end

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
  local isBossStage = result.stageType == "boss"

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText(string.upper(result.status or "stage result"), 72, app.fonts.title, titleColor)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, "Stage Summary")
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Stage Summary")
  local textStartY = contentArea.y
  local availableTextHeight = contentArea.height

  if isBossStage then
    local cards = app:getBossModifierCards(result.bossModifierIds)
    local pulse = app:getUiPulse(4.6, 0.10, 0.22)
    local bannerHeight = 58
    local cardsY = contentArea.y + bannerHeight + 12
    local cardGap = 10
    local compactCards = true
    local cardsHeight = 0

    local function computeCardsHeight(isCompact)
      local total = 0

      for index, card in ipairs(cards) do
        total = total + getBossCardHeight(card, contentArea.width, isCompact)

        if index < #cards then
          total = total + cardGap
        end
      end

      if #cards > 0 then
        total = total + 10
      end

      return total
    end

    cardsHeight = computeCardsHeight(compactCards)

    love.graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.16 + pulse)
    love.graphics.rectangle("fill", contentArea.x, contentArea.y, contentArea.width, bannerHeight, 12, 12)
    love.graphics.setColor(Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", contentArea.x, contentArea.y, contentArea.width, bannerHeight, 12, 12)

    love.graphics.setFont(app.fonts.heading)
    Theme.applyColor(Theme.colors.text)
    love.graphics.print(result.status == "cleared" and "BOSS TABLE BROKEN" or "BOSS PRESSURE HELD", contentArea.x + 16, contentArea.y + 10)

    local currentY = cardsY
    for index, card in ipairs(cards) do
      local cardHeight = getBossCardHeight(card, contentArea.width, compactCards)
      local y = currentY
      love.graphics.setColor(Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.98)
      love.graphics.rectangle("fill", contentArea.x, y, contentArea.width, cardHeight, 10, 10)
      love.graphics.setColor(Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 1.0)
      love.graphics.rectangle("line", contentArea.x, y, contentArea.width, cardHeight, 10, 10)
      Theme.applyColor(Theme.colors.danger)
      love.graphics.rectangle("fill", contentArea.x, y, 8, cardHeight, 10, 10)
      love.graphics.setFont(app.fonts.body)
      Theme.applyColor(Theme.colors.text)
      love.graphics.print(card.name, contentArea.x + 18, y + 8)

      if not compactCards then
        Theme.applyColor(Theme.colors.mutedText)
        love.graphics.printf(card.description, contentArea.x + 18, y + 26, contentArea.width - 30, "left")
      end

      currentY = currentY + cardHeight + cardGap
    end

    textStartY = cardsY + cardsHeight + (#cards > 0 and 8 or 0)
    availableTextHeight = math.max(0, contentArea.height - (textStartY - contentArea.y))
  end

  local lines = {
    string.format("Stage: %s", result.stageLabel or "n/a"),
    string.format("Score: %s / %s", tostring(result.stageScore or 0), tostring(result.targetScore or 0)),
    string.format("Run Total Score: %s", tostring(result.runTotalScore or (app.runState and app.runState.runTotalScore or 0))),
    string.format("Run Status: %s", tostring(result.runStatus or "active")),
    string.format("Chips: %s", tostring(result.shopPoints or (app.runState and app.runState.shopPoints or 0))),
    string.format("Next step: %s", destination),
  }

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, 7, string.format("Meta Reward Banked: %d", result.metaRewardEarned))
  end

  if isBossStage then
    table.insert(lines, 3, string.format("Boss Modifiers: %d", #(app:getBossModifierCards(result.bossModifierIds))))
  end

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(lines, contentArea.x, textStartY, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, availableTextHeight)

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
