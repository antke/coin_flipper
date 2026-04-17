local Utils = require("src.core.utils")

local Assertions = {}

local function valuesEqual(left, right, seen)
  if left == right then
    return true
  end

  if type(left) ~= type(right) then
    return false
  end

  if type(left) ~= "table" then
    return false
  end

  seen = seen or {}

  if seen[left] and seen[left] == right then
    return true
  end

  seen[left] = right

  for key, value in pairs(left) do
    if not valuesEqual(value, right[key], seen) then
      return false
    end
  end

  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end

  return true
end

local function matchValue(actual, matcher)
  if type(matcher) == "function" then
    return matcher(actual)
  end

  if type(matcher) == "table" then
    for key, value in pairs(matcher) do
      if not valuesEqual(actual and actual[key], value) then
        return false
      end
    end

    return true
  end

  return valuesEqual(actual, matcher)
end

local function stringify(value)
  if type(value) == "table" then
    return tostring(value)
  end

  return tostring(value)
end

function Assertions.new(env)
  local A = {}

  function A.getResult(label)
    return env.results[label]
  end

  function A.equal(actual, expected, label)
    if not valuesEqual(actual, expected) then
      error(string.format("%s expected %s, got %s", label or "assert.equal failed", stringify(expected), stringify(actual)), 0)
    end

    return actual
  end

  function A.truthy(value, label)
    if not value then
      error(label or "expected truthy value", 0)
    end

    return value
  end

  function A.falsy(value, label)
    if value then
      error(label or "expected falsy value", 0)
    end

    return value
  end

  function A.findMatching(list, matcher)
    for _, entry in ipairs(list or {}) do
      if matchValue(entry, matcher) then
        return entry
      end
    end

    return nil
  end

  function A.contains(list, matcher, label)
    local match = A.findMatching(list, matcher)

    if not match then
      error(label or "expected matching entry", 0)
    end

    return match
  end

  function A.notContains(list, matcher, label)
    local match = A.findMatching(list, matcher)

    if match then
      error(label or "unexpected matching entry", 0)
    end
  end

  function A.traceHasAction(trace, matcher, label)
    return A.contains(trace and trace.actions or {}, matcher, label or "expected matching trace action")
  end

  function A.traceHasTriggeredSource(trace, matcher, label)
    return A.contains(trace and trace.triggeredSources or {}, matcher, label or "expected matching triggered source")
  end

  function A.replayOk(replay, label)
    if not replay or not replay.ok then
      local mismatchText = replay and Utils.joinNonNil(replay.mismatches or {}, " | ") or "nil replay result"
      error(string.format("%s: %s", label or "expected replay ok", mismatchText), 0)
    end

    return replay
  end

  return A
end

return Assertions
