local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local SECTIONS = {
  {
    title = "Run Objective",
    lines = {
      "Call Heads or Tails, then flip your equipped coins.",
      "Clear stages, improve the run, and beat the final boss.",
    },
  },
  {
    title = "Stage Loop",
    lines = {
      "Loadout → Stage → Reward → Shop.",
      "Meta progress persists after the run.",
    },
  },
  {
    title = "Resources",
    lines = {
      "Score clears stages before flips run out.",
      "Chips buy coins and upgrades between stages.",
    },
  },
  {
    title = "Controls",
    lines = {
      "Click buttons to choose actions.",
      "Esc pauses or backs out where available.",
    },
  },
}

local HelpState = {}
HelpState.__index = HelpState

function HelpState.new()
  return setmetatable({
    pageIndex = 1,
    buttons = {},
  }, HelpState)
end

function HelpState:enter()
  self.pageIndex = math.max(1, math.min(self.pageIndex or 1, #SECTIONS))
end

function HelpState:selectPage(index)
  self.pageIndex = math.max(1, math.min(index, #SECTIONS))
end

function HelpState:buildButtons(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local buttonHeight = footerMetrics.buttonHeight
  local buttonWidth = 220
  local gap = Theme.spacing.itemGap
  local totalWidth = (buttonWidth * 3) + (gap * 2)
  local startX = math.floor((width - totalWidth) / 2)
  local buttonY = footerMetrics.buttonY

  self.buttons = {
    {
      x = startX,
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Previous",
      variant = "default",
      disabled = self.pageIndex <= 1,
      onClick = function()
        self:selectPage(self.pageIndex - 1)
        return true
      end,
    },
    {
      x = startX + buttonWidth + gap,
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Back to Menu",
      variant = "primary",
      onClick = function()
        return app.stateGraph:request("back")
      end,
    },
    {
      x = startX + ((buttonWidth + gap) * 2),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Next",
      variant = "default",
      disabled = self.pageIndex >= #SECTIONS,
      onClick = function()
        self:selectPage(self.pageIndex + 1)
        return true
      end,
    },
  }

  return self.buttons
end

function HelpState:keypressed(app, key)
  if key == "escape" or key == "backspace" then
    app.stateGraph:request("back")
    return
  end

  if key == "left" or key == "up" then
    self:selectPage(self.pageIndex - 1)
    return
  end

  if key == "right" or key == "down" then
    self:selectPage(self.pageIndex + 1)
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    app.stateGraph:request("back")
  end
end

function HelpState:draw(app)
  local section = SECTIONS[self.pageIndex]
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelX = padding
  local panelY = 110
  local panelWidth = width - (padding * 2)
  local panelHeight = math.max(260, footerMetrics.contentBottomY - panelY)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("How to Play", 56, app.fonts.title, Theme.colors.text)
  love.graphics.setFont(app.fonts.heading)
  Layout.centeredText(string.format("%d / %d — %s", self.pageIndex, #SECTIONS, section.title), 94, app.fonts.heading, Theme.colors.accent)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, section.title)
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, section.title)

  local lines = {}
  for _, line in ipairs(section.lines) do
    table.insert(lines, line)
    table.insert(lines, "")
  end
  if #lines > 0 then
    table.remove(lines, #lines)
  end
  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(lines, contentArea.x, contentArea.y, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function HelpState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return HelpState
