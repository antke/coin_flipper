local Validator = require("src.core.validator")
local Utils = require("src.core.utils")

local Common = {}

function Common.assertRuntime(env, label, options)
  if env.runState then
    Validator.assertRuntimeInvariants(label, env.runState, env.stageState, options or { history = true })
  end
end

function Common.cloneStepOptions(step)
  return Utils.clone(step or {})
end

function Common.mergeTable(target, source)
  for key, value in pairs(source or {}) do
    target[key] = value
  end

  return target
end

function Common.mergeHandlers(...)
  local merged = {}

  for index = 1, select("#", ...) do
    local handlers = select(index, ...)

    for key, value in pairs(handlers or {}) do
      assert(merged[key] == nil, string.format("duplicate fixture step handler registered for op %s", tostring(key)))
      merged[key] = value
    end
  end

  return merged
end

return Common
