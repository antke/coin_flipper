local Button = require("src.ui.button")
local DevBuilds = require("src.content.dev_builds")
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
    return "Back to Tattoos"
  end

  return "Back to Menu"
end

function RunSetupState:getBackEvent()
  if self.returnState == "meta" then
    return "back_to_meta"
  end

  return "back_to_menu"
end

function RunSetupState:getLayout()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local footerMetrics = Layout.getFooterMetrics(height)
  local panelX = padding
  local panelY = 126
  local panelWidth = width - (padding * 2)
  local panelHeight = math.max(280, footerMetrics.contentBottomY - panelY)
  local content = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Seeded Run")

  return {
    width = width,
    height = height,
    footerMetrics = footerMetrics,
    panel = {
      x = panelX,
      y = panelY,
      width = panelWidth,
      height = panelHeight,
    },
    content = content,
    preparedBuildsY = content.y + math.floor(content.height * 0.36),
  }
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

function RunSetupState:tryStartPreparedBuild(app, buildId)
  local seedValue = self:getPreviewSeedText()
  return app.stateGraph:request("start_run", { seed = seedValue, devBuildId = buildId })
end

function RunSetupState:buildPreparedBuildButtons(app, layout)
  if not layout or not layout.content then
    return {}
  end

  local builds = DevBuilds.getAll()
  local buttons = {}
  local gap = Theme.spacing.itemGap
  local buttonHeight = Theme.componentMetrics.buttonHeight or 42
  local columnCount = math.min(2, math.max(1, #builds))
  local buttonWidth = math.floor((layout.content.width - (gap * (columnCount - 1))) / columnCount)
  local rowHeight = buttonHeight + Theme.spacing.lineHeight + gap
  local startY = layout.preparedBuildsY + Theme.spacing.lineHeight + gap

  for index, build in ipairs(builds) do
    local columnIndex = (index - 1) % columnCount
    local rowIndex = math.floor((index - 1) / columnCount)

    table.insert(buttons, {
      x = layout.content.x + (columnIndex * (buttonWidth + gap)),
      y = startY + (rowIndex * rowHeight),
      width = buttonWidth,
      height = buttonHeight,
      label = build.label,
      description = build.description,
      variant = "accent",
      onClick = function()
        return self:tryStartPreparedBuild(app, build.id)
      end,
    })
  end

  return buttons
end

function RunSetupState:buildButtons(app, layout)
  local metrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local buttonHeight = metrics.buttonHeight
  local gap = Theme.spacing.itemGap
  local buttonWidth = 220
  local totalWidth = (buttonWidth * 3) + (gap * 2)
  local startX = math.floor((love.graphics.getWidth() - totalWidth) / 2)

  local buttons = {
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

  for _, button in ipairs(self:buildPreparedBuildButtons(app, layout)) do
    table.insert(buttons, button)
  end

  self.buttons = buttons

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
  local layout = self:getLayout()

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Run Setup", 70, app.fonts.title, Theme.colors.text)

  Panel.draw(layout.panel.x, layout.panel.y, layout.panel.width, layout.panel.height, "Seeded Run")
  local content = layout.content

  local warningLines = app:getRunSetupWarningLines()
  local lines = {
    string.format("Seed Input: %s", self.seedText ~= "" and self.seedText or "(using generated seed)"),
    self.statusMessage,
  }

  for _, line in ipairs(warningLines) do
    table.insert(lines, line)
  end

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(lines, content.x, content.y, content.width, Theme.colors.text, Theme.spacing.lineHeight, layout.preparedBuildsY - content.y - Theme.spacing.itemGap)

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.print("Prepared Builds", content.x, layout.preparedBuildsY)

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  for _, button in ipairs(self:buildPreparedBuildButtons(app, layout)) do
    love.graphics.printf(button.description or "", button.x, button.y + button.height + 4, button.width, "left")
  end

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app, layout), mouseX, mouseY)
end

function RunSetupState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app, self:getLayout()), x, y)
end

return RunSetupState
