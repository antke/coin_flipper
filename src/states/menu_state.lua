local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local MenuState = {}
MenuState.__index = MenuState

function MenuState.new()
  return setmetatable({
    buttons = {},
  }, MenuState)
end

function MenuState:buildButtons(app)
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local footerMetrics = Layout.getFooterMetrics(height)
  local buttonHeight = footerMetrics.buttonHeight
  local gap = Theme.spacing.itemGap
  local hasContinue = app:hasActiveRunSave()
  local buttonCount = hasContinue and 6 or 5
  local buttonWidth = math.min(240, math.floor((width - (Theme.spacing.screenPadding * 2) - (gap * math.max(0, buttonCount - 1))) / buttonCount))
  local totalWidth = (buttonWidth * buttonCount) + (gap * (buttonCount - 1))
  local startX = math.floor((width - totalWidth) / 2)
  local buttonY = footerMetrics.buttonY

  self.buttons = {}

  if hasContinue then
    table.insert(self.buttons, {
      x = startX,
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Continue Run",
      variant = "success",
      onClick = function()
        return app.stateGraph:request("continue_run")
      end,
    })

    table.insert(self.buttons, {
      x = startX + buttonWidth + gap,
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Start Run",
      variant = "primary",
      onClick = function()
        return app.stateGraph:request("start_run")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 2),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Collection",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_collection")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 3),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Records",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_records")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 4),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "How to Play",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_help")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 5),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Meta Progression",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_meta")
      end,
    })
  else
    table.insert(self.buttons, {
      x = startX,
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Start Run",
      variant = "primary",
      onClick = function()
        return app.stateGraph:request("start_run")
      end,
    })

    table.insert(self.buttons, {
      x = startX + buttonWidth + gap,
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Collection",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_collection")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 2),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Records",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_records")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 3),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "How to Play",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_help")
      end,
    })

    table.insert(self.buttons, {
      x = startX + ((buttonWidth + gap) * 4),
      y = buttonY,
      width = buttonWidth,
      height = buttonHeight,
      label = "Meta Progression",
      variant = "default",
      onClick = function()
        return app.stateGraph:request("open_meta")
      end,
    })
  end

  return self.buttons
end

function MenuState:enter(app)
  app.logger:debug("Entered menu state")
end

function MenuState:keypressed(app, key)
  if app:hasActiveRunSave() and (key == "return" or key == "space" or key == "kpenter" or key == "c") then
    app.stateGraph:request("continue_run")
    return
  end

  if app:hasActiveRunSave() and key == "n" then
    app.stateGraph:request("start_run")
    return
  end

  if key == "b" then
    app.stateGraph:request("open_collection")
    return
  end

  if key == "r" then
    app.stateGraph:request("open_records")
    return
  end

  if key == "return" or key == "space" or key == "kpenter" then
    app.stateGraph:request("start_run")
    return
  end

  if key == "m" then
    app.stateGraph:request("open_meta")
    return
  end

  if key == "h" then
    app.stateGraph:request("open_help")
  end
end

function MenuState:draw(app)
  local panelX = 80
  local panelY = 180
  local footerMetrics = Layout.getFooterMetrics(love.graphics.getHeight())
  local panelWidth = love.graphics.getWidth() - 160
  local panelHeight = math.max(220, math.min(280, footerMetrics.contentBottomY - panelY - 24))

  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("Coin-Flip Roguelike", 76, app.fonts.title, Theme.colors.text)
  Layout.centeredText("Prototype Build", 116, app.fonts.heading, Theme.colors.accent)

  Panel.draw(panelX, panelY, panelWidth, panelHeight, "Current Build")
  local contentArea = Panel.getContentArea(panelX, panelY, panelWidth, panelHeight, "Current Build")

  love.graphics.setFont(app.fonts.body)
  local lines = {
    "This prototype now has a playable run loop plus persistent meta progression.",
    "",
    "Implemented now:",
    "- deterministic stage resolution and traceable hook/action flow",
    "- loadout, stage, result, shop, summary, and meta screens",
    "- save/load for MetaState via love.filesystem",
    string.format("- current meta points: %d", app.metaState.metaPoints or 0),
    string.format("- save status: %s", app.metaSaveStatus and app.metaSaveStatus.message or "unknown"),
    "",
    "Controls:",
  }

  if app:hasActiveRunSave() then
    table.insert(lines, "- Click Continue Run or press Enter / Space / C")
    table.insert(lines, "- Click Start Run or press N to open Run Setup")
  else
    table.insert(lines, "- Click Start Run or press Enter / Space / KPEnter to open Run Setup")
  end

  table.insert(lines, "- Click Collection or press B")
  table.insert(lines, "- Click Records or press R")
  table.insert(lines, "- Click How to Play or press H")
  table.insert(lines, "- Click Meta Progression or press M")

  if app:isDevControlsEnabled() then
    table.insert(lines, "- F3: Toggle debug overlay")
  end

  Layout.drawWrappedLines(lines, contentArea.x, contentArea.y, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, contentArea.height)

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app), mouseX, mouseY)
end

function MenuState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  Button.handleMousePressed(self:buildButtons(app), x, y)
end

return MenuState
