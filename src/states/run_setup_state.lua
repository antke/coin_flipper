local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local RunSetupState = {}
RunSetupState.__index = RunSetupState

function RunSetupState.new()
  return setmetatable({
    seedText = "",
    previewSeed = nil,
    returnState = "menu",
    metaFlowContext = nil,
    buttons = {},
    statusMessage = "Use this seeded route, regenerate it, or type your own numeric seed.",
  }, RunSetupState)
end

function RunSetupState:enter(app, payload)
  self.returnState = payload and payload.returnState or "menu"
  self.metaFlowContext = payload and payload.metaFlowContext or nil
  self.previewSeed = app:generateRunSeed()
  self.seedText = ""
  self.statusMessage = "Use the generated route, regenerate it, or type your own numeric seed."
end

function RunSetupState:setSeedText(text)
  self.seedText = text or ""
end

function RunSetupState:appendSeedText(text)
  self.seedText = (self.seedText or "") .. text
end

function RunSetupState:backspaceSeed()
  local current = self.seedText or ""
  self.seedText = current:sub(1, math.max(0, #current - 1))
end

function RunSetupState:getPreviewSeedText()
  if (self.seedText or "") ~= "" then
    return self.seedText
  end

  return tostring(self.previewSeed or "")
end

function RunSetupState:getBackLabel()
  if self.returnState == "meta" then
    return "Back to Meta"
  end

  return "Back to Menu"
end

function RunSetupState:getBackEvent()
  if self.returnState == "meta" then
    return "back_to_meta"
  end

  return "back_to_menu"
end

function RunSetupState:randomizeSeed(app)
  self.previewSeed = app:generateRunSeed()
  self:setSeedText("")
  self.statusMessage = "Generated a new random seed."
end

function RunSetupState:tryStartRun(app)
  local seedValue = self:getPreviewSeedText()
  return app.stateGraph:request("start_run", { seed = seedValue })
end

function RunSetupState:buildButtons(app)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonHeight = metrics.buttonHeight
  local gap = Theme.spacing.itemGap
  local buttonWidth = 220
  local totalWidth = (buttonWidth * 3) + (gap * 2)
  local startX = math.floor((love.graphics.getWidth() - totalWidth) / 2)

  self.buttons = {
    {
        x = startX,
        y = metrics.buttonY,
        width = buttonWidth,
        height = buttonHeight,
        label = self:getBackLabel(),
        variant = "default",
        onClick = function()
          return app.stateGraph:request(self:getBackEvent(), {
            metaFlowContext = self.metaFlowContext,
          })
        end,
      },
    {
      x = startX + buttonWidth + gap,
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Regenerate Seed",
      variant = "warning",
      onClick = function()
        self:randomizeSeed(app)
        return true
      end,
    },
    {
      x = startX + ((buttonWidth + gap) * 2),
      y = metrics.buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Start Run",
      variant = "primary",
      onClick = function()
        return self:tryStartRun(app)
      end,
    },
  }

  return self.buttons
end

function RunSetupState:keypressed(app, key)
  if key == "escape" or key == "backspace" then
    if key == "backspace" and (self.seedText or "") ~= "" then
      self:backspaceSeed()
      return
    end

    app.stateGraph:request(self:getBackEvent(), {
      metaFlowContext = self.metaFlowContext,
    })
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    self:tryStartRun(app)
    return
  end

  if key == "r" then
    self:randomizeSeed(app)
  end
end

function RunSetupState:textinput(_, text)
  if text:match("%d") then
    self:appendSeedText(text:gsub("%D", ""))
  end
end

function RunSetupState:draw(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelX = padding
  local panelY = 126
  local panelWidth = width - (padding * 2)
  local panelHeight = math.max(280, footerMetrics.contentBottomY - panelY)

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Run Setup", 70, app.fonts.title, Theme.colors.text)
  Layout.centeredText("Choose or generate a seed before the run begins", 108, app.fonts.heading, Theme.colors.accent)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, "Seeded Run")
  local content = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Seeded Run")

  local seedValue = self:getPreviewSeedText()
  local previewLines = app:getRunSetupPreviewLines(seedValue)
  local warningLines = app:getRunSetupWarningLines()
  local lines = {
    string.format("Seed Input: %s", self.seedText ~= "" and self.seedText or "(using generated seed)"),
    self.statusMessage,
    "",
  }

  for _, line in ipairs(warningLines) do
    table.insert(lines, line)
  end

  table.insert(lines, "")

  for _, line in ipairs(previewLines) do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "Type digits to set a seed, press R to regenerate, or press Enter to begin.")
  table.insert(lines, "Clearing the field keeps the currently generated route preview until you regenerate again.")

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(lines, content.x, content.y, content.width, Theme.colors.text, Theme.spacing.lineHeight, content.height)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function RunSetupState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return RunSetupState
