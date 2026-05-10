local Game = require("src.app.game")

local app

function love.load(args)
  app = Game.new()
  app:load(args or {})
end

function love.update(dt)
  if app then
    app:update(dt)
  end
end

function love.draw()
  if app then
    app:draw()
  end
end

function love.keypressed(key, scancode, isRepeat)
  if app then
    app:keypressed(key, scancode, isRepeat)
  end
end

function love.mousepressed(x, y, button, istouch, presses)
  if app then
    app:mousepressed(x, y, button, istouch, presses)
  end
end

function love.mousereleased(x, y, button, istouch, presses)
  if app and app.mousereleased then
    app:mousereleased(x, y, button, istouch, presses)
  end
end

function love.textinput(text)
  if app and app.textinput then
    app:textinput(text)
  end
end

function love.wheelmoved(x, y)
  if app and app.wheelmoved then
    app:wheelmoved(x, y)
  end
end

function love.resize(width, height)
  if app then
    app:resize(width, height)
  end
end

function love.quit()
  if app and app.quit then
    app:quit()
  end
end
