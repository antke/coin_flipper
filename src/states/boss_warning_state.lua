local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local BossWarningState = {}
BossWarningState.__index = BossWarningState

local function getWrappedLineCount(text, width)
  local font = love.graphics.getFont()
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped)
end

local function getBossCardHeight(card, width, compact)
  if compact then
    return 30
  end

  local descriptionLines = getWrappedLineCount(card.description, math.max(1, width - 30))
  return 24 + (descriptionLines * Theme.spacing.lineHeight) + 8
end

local function getWrappedLinesHeight(lines, width)
  local total = 0

  for _, line in ipairs(lines or {}) do
    total = total + (getWrappedLineCount(line, width) * Theme.spacing.lineHeight)
  end

  return total
end

function BossWarningState.new()
  return setmetatable({
    statusMessage = "Click Face the Boss or Back to Loadout, or use Enter / Esc.",
    buttons = {},
  }, BossWarningState)
end

function BossWarningState:buildButtons(app)
  local width = love.graphics.getWidth()
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonWidth = 220
  local buttonHeight = metrics.buttonHeight
  local gap = Theme.spacing.itemGap
  local totalWidth = (buttonWidth * 2) + gap
  local startX = math.floor((width - totalWidth) / 2)
  local y = metrics.buttonY

  self.buttons = {
    {
      x = startX,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Back to Loadout",
      variant = "warning",
      onClick = function()
        return app.stateGraph:request("back")
      end,
    },
    {
      x = startX + buttonWidth + gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Face the Boss",
      variant = "danger",
      onClick = function()
        return app.stateGraph:request("continue")
      end,
    },
  }

  return self.buttons
end

function BossWarningState:enter(app)
  app:ensureCurrentStage()
  self.statusMessage = "Click Face the Boss or Back to Loadout, or use Enter / Esc."
  app:showFeedback("boss", "Boss Incoming", app.currentStageDefinition and app.currentStageDefinition.label or "A dangerous table waits ahead.", {
    duration = 1.8,
    flashAlpha = 0.06,
    soundCue = "boss_warning",
  })
end

function BossWarningState:exit(app)
  app:clearFeedback()
end

function BossWarningState:keypressed(app, key)
  if key == "return" or key == "space" or key == "kpenter" then
    app.stateGraph:request("continue")
    return
  end

  if key == "escape" or key == "backspace" then
    app.stateGraph:request("back")
  end
end

function BossWarningState:draw(app)
  local padding = Theme.spacing.screenPadding
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelX = padding
  local panelY = 128
  local panelWidth = width - (padding * 2)
  local panelHeight = math.max(180, footerMetrics.contentBottomY - panelY)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Boss Warning", 64, app.fonts.title, Theme.colors.danger)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, app.currentStageDefinition and app.currentStageDefinition.label or "Boss")
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, app.currentStageDefinition and app.currentStageDefinition.label or "Boss")
  local pulse = app:getUiPulse(4.0, 0.12, 0.24)
  local bannerHeight = 62
  local bannerY = contentArea.y
  local cards = app:getBossModifierCards()
  local cardGap = 10
  local keyLines = {
    string.format("Target Score: %d", app.stageState and app.stageState.targetScore or 0),
    string.format("Flips Available: %d", app.stageState and app.stageState.flipsRemaining or 0),
    string.format("Current Build: %s", app:getCurrentLoadoutKey()),
  }
  local equippedNames = app:getEquippedCoinNames()

  if #equippedNames > 0 then
    table.insert(keyLines, string.format("Equipped: %s", table.concat(equippedNames, ", ")))
  end

  table.insert(keyLines, self.statusMessage)

  love.graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.18 + pulse)
  love.graphics.rectangle("fill", contentArea.x, bannerY, contentArea.width, bannerHeight, 12, 12)
  love.graphics.setColor(Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", contentArea.x, bannerY, contentArea.width, bannerHeight, 12, 12)

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print("THREAT LEVEL: HIGH", contentArea.x + 16, bannerY + 10)
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.print(string.format("%d boss modifier(s) active", #cards), contentArea.x + 16, bannerY + 34)

  local infoY = bannerY + bannerHeight + 12
  local infoHeight = getWrappedLinesHeight(keyLines, contentArea.width) + 6
  local buttonsReserve = footerMetrics.buttonsHeight + Theme.spacing.itemGap + 12
  local remainingHeight = math.max(0, contentArea.height - (infoY - contentArea.y) - infoHeight - buttonsReserve)
  local compactCards = false
  local cardsHeight = 0

  local function computeCardsHeight(compact)
    local total = 0

    for index, card in ipairs(cards) do
      total = total + getBossCardHeight(card, contentArea.width, compact)

      if index < #cards then
        total = total + cardGap
      end
    end

    return total
  end

  cardsHeight = computeCardsHeight(false)
  if cardsHeight > remainingHeight then
    compactCards = true
    cardsHeight = computeCardsHeight(true)
  end

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(keyLines, contentArea.x, infoY, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, infoHeight)

  local cardsY = infoY + infoHeight + 10
  local currentY = cardsY
  for _, card in ipairs(cards) do
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

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function BossWarningState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return BossWarningState
