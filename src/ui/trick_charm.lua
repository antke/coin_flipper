local Layout = require("src.ui.layout")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")
local Upgrades = require("src.content.upgrades")

local TrickCharm = {}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function capitalize(value)
  local text = tostring(value or "common")
  return (text:gsub("^%l", string.upper))
end

local function containsPoint(rect, x, y)
  return x >= rect.x and x <= rect.x + rect.width and y >= rect.y and y <= rect.y + rect.height
end

local function getBounds(options)
  local bounds = options and options.bounds or nil

  if bounds then
    return {
      x = bounds.x or 0,
      y = bounds.y or 0,
      width = bounds.width or love.graphics.getWidth(),
      height = bounds.height or love.graphics.getHeight(),
      screenPadding = bounds.screenPadding,
    }
  end

  return {
    x = 0,
    y = 0,
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight(),
    screenPadding = nil,
  }
end

local function hasText(text)
  return type(text) == "string" and text ~= ""
end

function TrickCharm.getFamilyLabel(charmOrCategory)
  local category = type(charmOrCategory) == "table" and charmOrCategory.category or charmOrCategory
  local categoryLabel = category and Terminology.getTagLabel(category) or nil

  if hasText(categoryLabel) then
    return categoryLabel .. " Charm"
  end

  return Terminology.getTermLabel("trick_charm")
end

local function getWrappedHeight(font, text, width, lineHeight)
  local _, wrapped = font:getWrap(tostring(text or ""), math.max(1, width))
  return math.max(1, #wrapped) * lineHeight
end

local function getMetadataLine(charm)
  local parts = { charm.familyLabel or TrickCharm.getFamilyLabel(charm) }

  if charm.rarity then
    table.insert(parts, capitalize(charm.rarity))
  end

  return table.concat(parts, " - ")
end

local function buildTagLabels(tags)
  local labels = {}

  for _, tag in ipairs(tags or {}) do
    table.insert(labels, Terminology.getTagLabel(tag))
  end

  return labels
end

function TrickCharm.buildData(runState)
  local charms = {}

  for index, trickId in ipairs(runState and (runState.ownedTrickIds or runState.ownedUpgradeIds) or {}) do
    local definition = Upgrades.getById(trickId)
    local trick = definition and definition.trick or nil
    local category = trick and trick.category or nil
    local tags = trick and trick.tags or definition and definition.tags or {}

    table.insert(charms, {
      kind = "trick_charm",
      type = "trick_charm",
      trickId = trickId,
      upgradeId = trickId,
      name = definition and definition.name or tostring(trickId),
      description = Terminology.formatText(definition and definition.description or ""),
      rarity = definition and definition.rarity or "common",
      category = category,
      categoryLabel = category and Terminology.getTagLabel(category) or nil,
      familyLabel = TrickCharm.getFamilyLabel(category),
      tags = tags,
      tagLabels = buildTagLabels(tags),
      tier = trick and trick.tier or nil,
      acquiredIndex = index,
    })
  end

  return charms
end

function TrickCharm.draw(app, charm, x, y, size, options)
  options = options or {}

  local hovered = options.hovered == true
  local activationCount = tonumber(charm and charm.activationCount) or 0
  local forgedActivationCount = tonumber(charm and charm.forgedActivationCount) or 0
  local pressure = charm and charm.pressure or nil
  local active = activationCount > 0 and not (pressure and pressure.kind == "blocked")
  local edge = math.max(1, Theme.scale(2))
  local shadowOffset = math.max(1, Theme.scale(3))
  local innerX = x + edge
  local innerY = y + edge
  local innerSize = math.max(1, size - (edge * 2))

  setColorWithAlpha(Theme.colors.shadow, 0.30)
  love.graphics.rectangle("fill", x + shadowOffset, y + shadowOffset, size, size)

  Theme.applyColor(active and Theme.colors.success or (hovered and Theme.colors.warning or Theme.colors.accent))
  love.graphics.rectangle("fill", x, y, size, size)

  setColorWithAlpha(Theme.colors.highlight, hovered and 0.30 or 0.18)
  love.graphics.rectangle("fill", innerX, innerY, innerSize, innerSize)

  local notchSize = math.max(2, math.floor(size * 0.18))
  Theme.applyColor(Theme.colors.background)
  love.graphics.rectangle("fill", innerX, innerY, notchSize, notchSize)
  love.graphics.rectangle("fill", innerX + innerSize - notchSize, innerY + innerSize - notchSize, notchSize, notchSize)

  local inset = math.max(2, math.floor(size * 0.24))
  setColorWithAlpha(Theme.colors.accent, 0.42)
  love.graphics.rectangle("fill", x + inset, y + inset, math.max(1, size - (inset * 2)), edge)
  love.graphics.rectangle("fill", x + inset, y + size - inset - edge, math.max(1, size - (inset * 2)), edge)
  love.graphics.rectangle("fill", x + inset, y + inset, edge, math.max(1, size - (inset * 2)))
  love.graphics.rectangle("fill", x + size - inset - edge, y + inset, edge, math.max(1, size - (inset * 2)))

  local font = app.fonts and (size <= Theme.scale(28) and app.fonts.small or app.fonts.body) or love.graphics.getFont()
  love.graphics.setFont(font)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf("T", x, y + math.floor((size - font:getHeight()) / 2), size, "center")

  if activationCount > 0 then
    local badge = string.format("×%d", activationCount)
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.background)
    love.graphics.rectangle("fill", x + size - Theme.scale(22), y - Theme.scale(2), Theme.scale(24), Theme.scale(16), 4, 4)
    Theme.applyColor(active and Theme.colors.success or Theme.colors.danger)
    love.graphics.printf(badge, x + size - Theme.scale(24), y - Theme.scale(1), Theme.scale(26), "center")
  end

  if forgedActivationCount > 0 then
    local badge = string.format("F+%d", forgedActivationCount)
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.background)
    love.graphics.rectangle("fill", x - Theme.scale(2), y - Theme.scale(2), Theme.scale(28), Theme.scale(16), 4, 4)
    Theme.applyColor(Theme.colors.warning)
    love.graphics.printf(badge, x - Theme.scale(2), y - Theme.scale(1), Theme.scale(28), "center")
  end

  if pressure then
    local pressureLabel = pressure.kind == "blocked" and "X"
      or (pressure.kind == "weakened" and "%"
        or (pressure.kind == "poisoned" and "P" or "!"))
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.danger)
    love.graphics.printf(pressureLabel, x, y + size - app.fonts.small:getHeight(), size, "center")
  end

  return containsPoint({ x = x, y = y, width = size, height = size }, love.mouse.getPosition())
end

function TrickCharm.drawDetailOverlay(app, charm, x, y, options)
  if not charm then
    return
  end

  options = options or {}

  local bounds = getBounds(options)
  local margin = bounds.screenPadding or Theme.spacing.screenPadding
  local availableWidth = math.max(1, bounds.width - (margin * 2))
  local availableHeight = math.max(1, bounds.height - (margin * 2))
  local width = math.min(options.width or Theme.scale(320), availableWidth)
  local padding = Theme.scale(12)
  local contentWidth = math.max(1, width - (padding * 2))
  local nameLineHeight = app.fonts.body:getHeight() + Theme.scale(2)
  local bodyLineHeight = app.fonts.small:getHeight() + Theme.scale(4)
  local description = charm.description or ""
  local tagsText = #(charm.tagLabels or {}) > 0 and ("Tags: " .. table.concat(charm.tagLabels, ", ")) or nil
  local metadataLine = getMetadataLine(charm)
  local nameHeight = getWrappedHeight(app.fonts.body, charm.name or charm.trickId or "Trick", contentWidth, nameLineHeight)
  local metadataHeight = getWrappedHeight(app.fonts.small, metadataLine, contentWidth, bodyLineHeight)
  local tagsHeight = tagsText and getWrappedHeight(app.fonts.small, tagsText, contentWidth, bodyLineHeight) or 0
  local descriptionHeight = hasText(description) and getWrappedHeight(app.fonts.small, description, contentWidth, bodyLineHeight) or 0
  local height = math.min(padding + nameHeight + metadataHeight + tagsHeight + descriptionHeight + padding + Theme.scale(12), availableHeight)
  local overlayX = math.min(x + Theme.scale(18), bounds.x + bounds.width - width - margin)
  local overlayY = math.min(y + Theme.scale(18), bounds.y + bounds.height - height - margin)

  overlayX = math.max(bounds.x + margin, overlayX)
  overlayY = math.max(bounds.y + margin, overlayY)

  local shadowOffset = Theme.scale(4)

  love.graphics.setColor(0.03, 0.04, 0.07, 0.96)
  love.graphics.rectangle("fill", overlayX + shadowOffset, overlayY + shadowOffset, width, height)
  Theme.applyColor(Theme.colors.highlight)
  love.graphics.rectangle("fill", overlayX, overlayY, width, height)
  love.graphics.setColor(0.08, 0.10, 0.15, 0.98)
  love.graphics.rectangle("fill", overlayX + Theme.scale(2), overlayY + Theme.scale(2), width - Theme.scale(4), height - Theme.scale(4))

  local contentX = overlayX + padding
  local currentY = overlayY + padding

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.printf(charm.name or charm.trickId or "Trick", contentX, currentY, contentWidth, "left")
  currentY = currentY + nameHeight + Theme.scale(4)

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.warning)
  love.graphics.printf(metadataLine, contentX, currentY, contentWidth, "left")
  currentY = currentY + metadataHeight

  if tagsText then
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(tagsText, contentX, currentY, contentWidth, "left")
    currentY = currentY + tagsHeight
  end

  if hasText(description) then
    Layout.drawRichWrappedText(
      Terminology.getMechanicRichText(description),
      contentX,
      currentY + Theme.scale(4),
      contentWidth,
      Theme.colors.mutedText,
      bodyLineHeight,
      math.max(1, height - (currentY - overlayY) - padding - Theme.scale(4))
    )
  end
end

return TrickCharm
