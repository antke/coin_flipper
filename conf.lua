function love.conf(t)
  t.identity = "coin_flip_roguelike_prototype"
  t.console = true

  t.window.title = "Coin-Flip Roguelike Prototype"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.vsync = 1
  t.window.msaa = 0

  t.modules.joystick = false
  t.modules.physics = false
end
