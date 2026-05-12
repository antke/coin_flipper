local Button = require("src.ui.button")
local Layout = require("src.ui.layout")
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
  love.graphics.setFont(app.fonts.title)
  Layout.centeredText("coin flipper", 76, app.fonts.title, Theme.colors.text)

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
