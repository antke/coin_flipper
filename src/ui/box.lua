local Box = {}

local Theme = require("src.ui.theme")

Box.frameStyle = {
  edge = 2,
  radius = 8,
  shadow = 3,
}

local function snap(value)
  return math.floor((value or 0) + 0.5)
end

local function normalizeInsets(value)
  if type(value) == "table" then
    return {
      left = value.left or value.x or 0,
      right = value.right or value.x or 0,
      top = value.top or value.y or 0,
      bottom = value.bottom or value.y or 0,
    }
  end

  return {
    left = value or 0,
    right = value or 0,
    top = value or 0,
    bottom = value or 0,
  }
end

function Box.rect(x, y, width, height)
  return {
    x = snap(x),
    y = snap(y),
    width = math.max(0, snap(width)),
    height = math.max(0, snap(height)),
  }
end

function Box.inset(rect, insets)
  local resolved = normalizeInsets(insets)
  local left = snap(resolved.left)
  local right = snap(resolved.right)
  local top = snap(resolved.top)
  local bottom = snap(resolved.bottom)

  return Box.rect(
    rect.x + left,
    rect.y + top,
    math.max(0, rect.width - left - right),
    math.max(0, rect.height - top - bottom)
  )
end

function Box.contentRect(x, y, width, height, options)
  options = options or {}
  local rect = Box.rect(x, y, width, height)
  local border = normalizeInsets(options.border or 0)
  local padding = normalizeInsets(options.padding or 0)

  return Box.inset(Box.inset(rect, border), padding)
end

function Box.splitBottom(rect, height, gap)
  local bottomHeight = math.min(rect.height, math.max(0, snap(height)))
  local resolvedGap = math.min(math.max(0, snap(gap or 0)), math.max(0, rect.height - bottomHeight))
  local topHeight = math.max(0, rect.height - bottomHeight - resolvedGap)

  return Box.rect(rect.x, rect.y, rect.width, topHeight), Box.rect(rect.x, rect.y + topHeight + resolvedGap, rect.width, bottomHeight)
end

function Box.drawFrame(x, y, width, height, options)
  options = options or {}

  local style = options.style or Box.frameStyle
  local edge = math.max(1, Theme.scale(options.edge or style.edge))
  local radius = Theme.scale(options.radius or style.radius)
  local shadowOffset = math.max(1, Theme.scale(options.shadow or style.shadow))
  local rect = Box.rect(x, y, width, height)
  local inner = Box.inset(rect, edge)

  Theme.applyColor(options.shadowColor or Theme.colors.shadow)
  love.graphics.rectangle("fill", rect.x + shadowOffset, rect.y + shadowOffset, rect.width, rect.height, radius, radius)

  Theme.applyColor(options.border or Theme.colors.panelBorder)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, radius, radius)

  Theme.applyColor(options.fill or Theme.colors.panel)
  love.graphics.rectangle("fill", inner.x, inner.y, inner.width, inner.height, radius, radius)

  return rect, inner, edge, radius
end

return Box
