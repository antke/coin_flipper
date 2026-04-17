local Utils = require("src.core.utils")

local StateGraph = {}
StateGraph.__index = StateGraph

function StateGraph.new(app, stepBuilder, logger)
  return setmetatable({
    app = app,
    stepBuilder = stepBuilder,
    logger = logger,
    states = {},
    current = nil,
    currentName = nil,
    lastTransition = nil,
  }, StateGraph)
end

function StateGraph:register(name, state)
  assert(type(name) == "string" and name ~= "", "StateGraph.register requires a non-empty name")
  assert(type(state) == "table", "StateGraph.register requires a state table")
  self.states[name] = state
end

function StateGraph:getCurrentName()
  return self.currentName
end

function StateGraph:getCurrentState()
  return self.current
end

function StateGraph:start(name, payload)
  return self:_switchState(name, payload or {})
end

function StateGraph:_switchState(name, payload)
  local nextState = self.states[name]
  assert(nextState, string.format("Unknown state: %s", tostring(name)))

  local previousName = self.currentName
  local previousState = self.current

  if previousState and previousState.exit then
    previousState:exit(self.app, payload, name)
  end

  self.current = nextState
  self.currentName = name
  self.lastTransition = {
    from = previousName,
    to = name,
    payload = Utils.clone(payload or {}),
  }

  if self.logger then
    self.logger:info("State transition", {
      from = previousName or "none",
      to = name,
      event = payload and payload.event or "start",
    })
  end

  if nextState.enter then
    nextState:enter(self.app, payload, previousName)
  end

  if self.app and self.app.onStateChanged then
    self.app:onStateChanged(name, previousName, payload)
  end

  return true
end

function StateGraph:request(eventName, payload)
  local transitionPayload = Utils.clone(payload or {})
  transitionPayload.event = eventName

  local steps = self.stepBuilder.buildNextSteps(self.currentName, transitionPayload, self.app)

  if not steps or #steps == 0 then
    if self.logger then
      self.logger:warn("Rejected transition request", {
        state = self.currentName or "none",
        event = eventName,
      })
    end

    return false, "no_transition"
  end

  for _, step in ipairs(steps) do
    if step.type == "action" then
      local ok, errorMessage = self.app:executeMacroAction(step.action, step.payload or transitionPayload)

      if ok == false then
        if self.logger then
          self.logger:warn("Rejected action step", {
            state = self.currentName or "none",
            event = eventName,
            action = step.action,
            error = errorMessage or "action_failed",
          })
        end

        return false, errorMessage or "action_failed"
      end
    elseif step.type == "state" then
      self:_switchState(step.state, step.payload or transitionPayload)
    else
      error(string.format("Unsupported step type: %s", tostring(step.type)))
    end
  end

  return true
end

function StateGraph:update(dt)
  if self.current and self.current.update then
    self.current:update(self.app, dt)
  end
end

function StateGraph:draw()
  if self.current and self.current.draw then
    self.current:draw(self.app)
  end
end

function StateGraph:keypressed(key, scancode, isRepeat)
  if self.current and self.current.keypressed then
    self.current:keypressed(self.app, key, scancode, isRepeat)
  end
end

function StateGraph:mousepressed(x, y, button, istouch, presses)
  if self.current and self.current.mousepressed then
    self.current:mousepressed(self.app, x, y, button, istouch, presses)
  end
end

function StateGraph:resize(width, height)
  if self.current and self.current.resize then
    self.current:resize(self.app, width, height)
  end
end

return StateGraph
