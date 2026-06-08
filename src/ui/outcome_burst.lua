local Theme = require("src.ui.theme")

local OutcomeBurst = {}

local function copyColor(color)
  local source = color or Theme.colors.accent
  return { source[1], source[2], source[3], source[4] or 1.0 }
end

local function getConfig(config)
  return config or Theme.outcomeBurst or {}
end

local function getMatchLabel(matchCount, coinCount, config)
  local count = matchCount or 0
  local total = coinCount or 0
  local labels = getConfig(config).labels or {}

  if total <= 0 then
    return nil
  end

  if count == 0 then
    return labels[0]
  end

  if count < 2 then
    return nil
  end

  return labels[count] or labels.default
end

function OutcomeBurst.getMatchLabel(matchCount, coinCount, config)
  return getMatchLabel(matchCount, coinCount, config)
end

function OutcomeBurst.getMatchStats(batchResult)
  local matchCount = 0
  local perCoin = batchResult and batchResult.perCoin or {}

  for _, coinState in ipairs(perCoin) do
    if coinState.result == batchResult.call then
      matchCount = matchCount + 1
    end
  end

  return matchCount, #perCoin
end

function OutcomeBurst.getBatchLabel(batchResult, config)
  if not batchResult then
    return nil
  end

  local labels = getConfig(config).labels or {}
  local matchCount, coinCount = OutcomeBurst.getMatchStats(batchResult)

  if coinCount <= 0 then
    return nil
  end

  if batchResult.batchFlags and batchResult.batchFlags.combo_matched then
    return labels.combo or getMatchLabel(matchCount, coinCount, config), "success"
  end

  if matchCount == 0 then
    return labels[0], "danger"
  end

  if batchResult.status == "cleared" then
    if batchResult.flipsRemaining == 0 then
      return labels.clutch or getMatchLabel(matchCount, coinCount, config), "success"
    end

    if (batchResult.scoreAppliedToHp or batchResult.stageScore or 0) > (batchResult.opponentHp or batchResult.targetScore or 0) then
      return labels.overkill or getMatchLabel(matchCount, coinCount, config), "success"
    end
  end

  if matchCount == coinCount then
    return labels.jackpot or getMatchLabel(matchCount, coinCount, config), "success"
  end

  return getMatchLabel(matchCount, coinCount, config), "accent"
end

function OutcomeBurst.new(label, options)
  local burstOptions = options or {}
  local config = getConfig(burstOptions.config)

  return {
    label = label or "",
    elapsed = 0,
    duration = burstOptions.duration or config.duration or 1.05,
    flashInDuration = config.flashInDuration or 0.12,
    fadeOutDuration = config.fadeOutDuration or 0.32,
    popScale = config.popScale or 1.28,
    color = copyColor(burstOptions.color),
    textColor = copyColor(config.textColor or Theme.colors.text),
  }
end

function OutcomeBurst.update(burst, dt)
  if not burst then
    return nil
  end

  burst.elapsed = burst.elapsed + dt

  if burst.elapsed >= burst.duration then
    return nil
  end

  return burst
end

local function getAlpha(burst)
  local flashInDuration = math.max(0.01, burst.flashInDuration or 0.12)
  local fadeOutDuration = math.max(0.01, burst.fadeOutDuration or 0.32)
  local flashIn = math.min(1, burst.elapsed / flashInDuration)
  local remaining = math.max(0, burst.duration - burst.elapsed)
  local fadeOut = remaining < fadeOutDuration and (remaining / fadeOutDuration) or 1
  return flashIn * fadeOut
end

local function getScale(burst)
  local flashInDuration = math.max(0.01, burst.flashInDuration or 0.12)
  local progress = math.min(1, burst.elapsed / flashInDuration)
  return 1 + ((burst.popScale or 1.28) - 1) * (1 - progress)
end

local function drawTextPass(label, width, offsetX, offsetY, color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * alpha)
  love.graphics.printf(label, offsetX - width * 0.5, offsetY, width, "center")
end

function OutcomeBurst.draw(burst, fonts, viewportRect)
  if not burst or burst.label == "" then
    return
  end

  local rect = viewportRect or { x = 0, y = 0, width = love.graphics.getWidth(), height = love.graphics.getHeight() }
  local currentFont = love.graphics.getFont()
  local font = fonts and (fonts.outcomeBurst or fonts.title) or currentFont
  local labelWidth = math.max(font:getWidth(burst.label), 1)
  local drawWidth = math.min(math.max(1, rect.width - 32), labelWidth + 48)
  local alpha = getAlpha(burst)
  local scale = getScale(burst)
  local x = rect.x + math.floor(rect.width * 0.5)
  local y = rect.y + math.floor((rect.height - font:getHeight()) * 0.5)
  local outline = math.max(3, math.floor(font:getHeight() * 0.08))

  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(scale, scale)
  love.graphics.setFont(font)

  drawTextPass(burst.label, drawWidth, outline, outline + 4, { 0, 0, 0, 0.70 }, alpha)
  drawTextPass(burst.label, drawWidth, -outline, 0, burst.color, alpha * 0.85)
  drawTextPass(burst.label, drawWidth, outline, 0, burst.color, alpha * 0.85)
  drawTextPass(burst.label, drawWidth, 0, -outline, burst.color, alpha * 0.85)
  drawTextPass(burst.label, drawWidth, 0, outline, burst.color, alpha * 0.85)
  drawTextPass(burst.label, drawWidth, 0, 0, burst.textColor, alpha)

  love.graphics.pop()
  love.graphics.setFont(currentFont)
  Theme.applyColor(Theme.colors.text)
end

return OutcomeBurst
