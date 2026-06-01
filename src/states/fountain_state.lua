local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local LuckSystem = require("src.systems.luck_system")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local FountainState = {}
FountainState.__index = FountainState

function FountainState.new()
  return setmetatable({
    statusMessage = "",
    optionButtons = {},
    footerButtons = {},
  }, FountainState)
end

function FountainState:getLayout()
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local infoY = padding + 34
  local infoHeight = 86
  local optionsY = infoY + infoHeight + gap
  local footerMetrics = Layout.getFooterMetrics(height, {
    statusHeight = 74,
  })

  return {
    padding = padding,
    gap = gap,
    width = width,
    height = height,
    infoY = infoY,
    infoHeight = infoHeight,
    optionsY = optionsY,
    optionsHeight = math.max(120, footerMetrics.contentBottomY - optionsY),
    footerMetrics = footerMetrics,
  }
end

function FountainState:trySacrifice(app, option)
  if not option then
    self.statusMessage = "Choose a coin to sacrifice."
    return false, "option_required"
  end

  if option.disabled then
    self.statusMessage = option.disabledReason == "last_coin_required"
      and "The fountain will not take your final coin."
      or "That coin cannot be sacrificed."
    return false, option.disabledReason or "option_disabled"
  end

  local ok, result = app:sacrificeFountainCoin(option.instanceId)

  if ok then
    self.statusMessage = string.format("Sacrificed %s for +%s Fountain Favor.", result.name, LuckSystem.formatAmount(result.favorGained))
  else
    self.statusMessage = tostring(result)
  end

  return ok, result
end

function FountainState:tryContinue(app)
  return app.stateGraph:request("continue")
end

function FountainState:buildOptionButtons(app, optionLayouts)
  local buttons = {}
  local session = app:getFountainSession()
  local alreadySacrificed = session and session.sacrificed == true

  for _, entry in ipairs(optionLayouts or {}) do
    local buttonHeight = 34
    local buttonY = entry.y + entry.height - buttonHeight - Theme.spacing.itemGap
    table.insert(buttons, {
      x = entry.x + Theme.spacing.itemGap,
      y = buttonY,
      width = entry.width - (Theme.spacing.itemGap * 2),
      height = buttonHeight,
      label = alreadySacrificed and "Fountain Spent" or string.format("Sacrifice (+%d)", entry.option.favor),
      variant = "warning",
      disabled = alreadySacrificed or entry.option.disabled,
      onClick = function()
        return self:trySacrifice(app, entry.option)
      end,
    })
  end

  self.optionButtons = buttons
  return buttons
end

function FountainState:buildFooterButtons(app, layout)
  local padding = layout.padding
  local buttonHeight = layout.footerMetrics.buttonHeight
  local y = layout.footerMetrics.buttonY
  local session = app:getFountainSession()
  local label = session and session.sacrificed and "Continue" or "Skip Fountain"

  self.footerButtons = {
    {
      x = padding,
      y = y,
      width = layout.width - (padding * 2),
      height = buttonHeight,
      label = label,
      variant = "success",
      onClick = function()
        return self:tryContinue(app)
      end,
    },
  }

  return self.footerButtons
end

function FountainState:buildOptionLayouts(app, layout)
  local options = app:getFountainOptions()
  local count = math.max(1, #options)
  local columns = math.min(3, count)
  local rows = math.max(1, math.ceil(count / columns))
  local gap = Theme.spacing.itemGap
  local panelWidth = math.floor((layout.width - (layout.padding * 2) - (gap * (columns - 1))) / columns)
  local panelHeight = math.max(154, math.floor((layout.optionsHeight - (gap * (rows - 1))) / rows))
  local entries = {}

  for index, option in ipairs(options) do
    local row = math.floor((index - 1) / columns)
    local column = (index - 1) % columns
    table.insert(entries, {
      option = option,
      x = layout.padding + (column * (panelWidth + gap)),
      y = layout.optionsY + (row * (panelHeight + gap)),
      width = panelWidth,
      height = panelHeight,
    })
  end

  return entries
end

function FountainState:enter(app)
  local session = app:getFountainSession()
  self.statusMessage = session and session.message or "Sacrifice up to one coin, or continue to the shop."
end

function FountainState:drawInfo(app, layout)
  Panel.draw(layout.padding, layout.infoY, layout.width - (layout.padding * 2), layout.infoHeight, "Fountain")

  local area = Panel.getContentArea(layout.padding, layout.infoY, layout.width - (layout.padding * 2), layout.infoHeight, "Fountain")
  local meter = app:getLuckMeter()
  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf("Sacrifice up to one coin. Removed coins leave your pouch; Fountain Favor permanently boosts future Luck gains.", area.x, area.y, area.width, "left")
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(string.format("Luck: %s • Fountain Favor: +%s", meter.fatedFlipActive and "FATE READY" or "Charging", LuckSystem.formatAmount(meter.fountainFavor or 0)), area.x, area.y + 36, area.width, "left")
end

function FountainState:drawOption(app, entry)
  local option = entry.option
  local title = option.name or option.coinId
  Panel.draw(entry.x, entry.y, entry.width, entry.height, title)

  local area = Panel.getContentArea(entry.x, entry.y, entry.width, entry.height, title)
  local coinSize = math.min(70, math.max(44, math.floor(area.height * 0.34)))
  CoinArt.draw(option.coinId, area.x, area.y + 4, coinSize)

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(string.format("%s • +%s Favor", option.rarity or "common", LuckSystem.formatAmount(option.favor or 0)), area.x + coinSize + 12, area.y + 8, math.max(1, area.width - coinSize - 12), "left")

  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(Terminology.formatText(option.description or ""), area.x, area.y + coinSize + 10, area.width, "left")
end

function FountainState:draw(app)
  local layout = self:getLayout()
  local mouseX, mouseY = love.mouse.getPosition()
  local optionLayouts = self:buildOptionLayouts(app, layout)

  self:drawInfo(app, layout)

  for _, entry in ipairs(optionLayouts) do
    self:drawOption(app, entry)
  end

  Button.drawButtons(self:buildOptionButtons(app, optionLayouts), mouseX, mouseY)

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(self.statusMessage, layout.padding, layout.footerMetrics.buttonY + layout.footerMetrics.buttonHeight + Theme.spacing.statusPadding, layout.width - (layout.padding * 2), "center")

  Button.drawButtons(self:buildFooterButtons(app, layout), mouseX, mouseY)
end

function FountainState:keypressed(app, key)
  if key == "return" or key == "space" then
    return self:tryContinue(app)
  end
end

function FountainState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local handled = Button.handleMousePressed(self.optionButtons, x, y)
  if handled then
    return true
  end

  handled = Button.handleMousePressed(self.footerButtons, x, y)
  return handled
end

return FountainState
