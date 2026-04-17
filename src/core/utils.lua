local Utils = {}

function Utils.copyArray(values)
  local copy = {}

  for index, value in ipairs(values or {}) do
    copy[index] = value
  end

  return copy
end

function Utils.clone(value, seen)
  if type(value) ~= "table" then
    return value
  end

  seen = seen or {}

  if seen[value] then
    return seen[value]
  end

  local copy = {}
  seen[value] = copy

  for key, nestedValue in pairs(value) do
    copy[Utils.clone(key, seen)] = Utils.clone(nestedValue, seen)
  end

  return setmetatable(copy, getmetatable(value))
end

function Utils.appendAll(target, values)
  for _, value in ipairs(values or {}) do
    table.insert(target, value)
  end

  return target
end

function Utils.contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then
      return true
    end
  end

  return false
end

function Utils.indexOf(values, expected)
  for index, value in ipairs(values or {}) do
    if value == expected then
      return index
    end
  end

  return nil
end

function Utils.removeValue(values, expected)
  local index = Utils.indexOf(values, expected)

  if index then
    table.remove(values, index)
  end

  return values
end

function Utils.clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

function Utils.round(value, decimals)
  local multiplier = 10 ^ (decimals or 0)
  return math.floor((value * multiplier) + 0.5) / multiplier
end

function Utils.sortedKeys(values)
  local keys = {}

  for key in pairs(values or {}) do
    table.insert(keys, key)
  end

  table.sort(keys)
  return keys
end

function Utils.joinNonNil(values, separator)
  local parts = {}

  for _, value in ipairs(values or {}) do
    if value ~= nil and value ~= "" then
      table.insert(parts, tostring(value))
    end
  end

  return table.concat(parts, separator or ", ")
end

function Utils.getPathValue(root, path)
  if not root or not path or path == "" then
    return root
  end

  local current = root

  for segment in string.gmatch(path, "[^%.]+") do
    if type(current) ~= "table" then
      return nil
    end

    current = current[segment]

    if current == nil then
      return nil
    end
  end

  return current
end

return Utils
