local Log = {}
Log.__index = Log

local function formatFields(fields)
  if not fields then
    return ""
  end

  local parts = {}

  for key, value in pairs(fields) do
    table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
  end

  table.sort(parts)

  if #parts == 0 then
    return ""
  end

  return " | " .. table.concat(parts, ", ")
end

function Log.new(options)
  local self = setmetatable({}, Log)
  self.enabled = options.enabled ~= false
  self.overlayEnabled = options.overlayEnabled == true
  self.maxEntries = options.maxEntries or 20
  self.entries = {}
  return self
end

function Log:setEnabled(enabled)
  self.enabled = enabled == true
end

function Log:toggleOverlay()
  self.overlayEnabled = not self.overlayEnabled
  self:info("Toggled debug overlay", { enabled = self.overlayEnabled })
end

function Log:push(level, message, fields)
  local entry = {
    level = level,
    message = message,
    fields = fields,
    timestamp = os.date("%H:%M:%S"),
  }

  table.insert(self.entries, 1, entry)

  while #self.entries > self.maxEntries do
    table.remove(self.entries)
  end

  if self.enabled then
    print(string.format("[%s] %s%s", level, message, formatFields(fields)))
  end

  return entry
end

function Log:debug(message, fields)
  return self:push("DEBUG", message, fields)
end

function Log:info(message, fields)
  return self:push("INFO", message, fields)
end

function Log:warn(message, fields)
  return self:push("WARN", message, fields)
end

function Log:error(message, fields)
  return self:push("ERROR", message, fields)
end

function Log:getEntries()
  return self.entries
end

return Log
