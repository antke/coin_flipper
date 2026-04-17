local Layout = require("src.ui.layout")
local Theme = require("src.ui.theme")

local BootState = {}
BootState.__index = BootState

function BootState.new()
  return setmetatable({}, BootState)
end

function BootState:draw(app)
  love.graphics.setFont(app.fonts.heading)
  Layout.centeredText("Bootstrapping systems...", love.graphics.getHeight() * 0.45, app.fonts.heading, Theme.colors.text)
end

return BootState
