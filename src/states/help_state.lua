local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local SECTIONS = {
  {
    title = "Run Objective",
    lines = {
      "Call Heads or Tails, then resolve every equipped coin as a full batch.",
      "Score enough points before you run out of flips to clear the stage.",
      "Clear normal stages to earn a reward, visit the shop, and prepare for the next round.",
      "Clear the final boss to win the run and bank meta progress.",
    },
  },
  {
    title = "Stage Loop",
    lines = {
      "Loadout: choose which coins are equipped for the next stage.",
      "Stage: call a side, resolve the full batch, and react to the result.",
      "Result / Review: see what happened, why it paid out, and where the flow goes next.",
      "Reward / Encounter / Shop: claim gains, take side events, and improve the run.",
      "Summary / Meta: close the run, spend meta points, and unlock future variety.",
    },
  },
  {
    title = "Resources",
    lines = {
      "Stage Score: score for the current stage only.",
      "Run Total Score: your total score across the run.",
      "Flips Remaining: how many more batches you can resolve this stage.",
      "Shop Points: currency for the shop after a cleared stage.",
      "Shop Rerolls: free shop refreshes that do not cost points.",
    },
  },
  {
    title = "Controls",
    lines = {
      "Menu: Start Run opens Run Setup, Continue Run resumes a save, and Collection / Records / Meta / Help stay available.",
      "Loadout: click a coin for the next slot, drag to a slot, or click a filled slot to clear it.",
      "Stage: click Heads or Tails once to call and flip the full batch.",
      "Reward / Encounter / Shop / Meta: click options or use number keys plus the labeled shortcuts on screen.",
      "Pause: press Esc or P during a run to resume, save and quit, or abandon the run.",
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
  table.insert(lines, "")
  table.insert(lines, "Use Left/Right/Up/Down or click Previous/Next to change sections.")
  table.insert(lines, "Press Enter, Esc, or Backspace, or click Back to Menu when you are ready.")

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
