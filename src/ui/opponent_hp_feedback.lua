local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")
local TextBox = require("src.ui.text_box")

local OpponentHpFeedback = {}

local DEFAULT_DURATION = 0.68
local COUNT_DELAY = 0.06
local FLASH_DURATION = 0.24
local SHAKE_DURATION = 0.30
local SPARK_DURATION = 0.36
local HP_NUMBER_SCALE = 2.0

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function lerp(startValue, endValue, progress)
  return startValue + ((endValue - startValue) * progress)
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * (alpha or 1.0))
end

local function getStageScoreAfter(batchResult)
  if not batchResult then
    return 0
  end

  local trace = batchResult.trace or {}
  return tonumber(batchResult.scoreAppliedToHp or batchResult.stageScore or trace.scoreAppliedToHpAfter or trace.stageScoreAfter) or 0
end

local function getStageScoreDelta(batchResult)
  local scoreBreakdown = batchResult and batchResult.scoreBreakdown or nil
  return tonumber(scoreBreakdown and scoreBreakdown.totalStageScoreDelta) or 0
end

local function drawCenteredScaled(label, font, centerX, centerY, width, color, alpha, scale, outlineAlpha)
  local textWidth = math.max(1, width)
  local effectiveScale = math.max(0.01, scale or 1)
  local scaledWidth = math.max(1, textWidth / effectiveScale)
  local textHeight = font:getHeight()
  local outline = math.max(1, Theme.scale(2))

  love.graphics.push()
  love.graphics.translate(centerX, centerY)
  love.graphics.scale(effectiveScale, effectiveScale)
  love.graphics.setFont(font)

  if outlineAlpha and outlineAlpha > 0 then
    for _, offset in ipairs({
      { -outline, 0 },
      { outline, 0 },
      { 0, -outline },
      { 0, outline },
      { -outline, -outline },
      { outline, -outline },
      { -outline, outline },
      { outline, outline },
    }) do
      love.graphics.setColor(0, 0, 0, 0.82 * outlineAlpha)
      love.graphics.printf(label, -scaledWidth / 2 + offset[1], -textHeight / 2 + offset[2], scaledWidth, "center")
    end
  end

  setColor(color, alpha)
  love.graphics.printf(label, -scaledWidth / 2, -textHeight / 2, scaledWidth, "center")
  love.graphics.pop()
end

local function drawHitSparks(centerX, centerY, width, age)
  if age < 0 or age > SPARK_DURATION then
    return
  end

  local progress = clamp(age / SPARK_DURATION, 0, 1)
  local alpha = (1 - progress) * 0.82
  local radius = math.max(Theme.scale(16), width * 0.22)
  local travel = Theme.scale(16) * easeOutCubic(progress)
  local previousWidth = love.graphics.getLineWidth()

  love.graphics.setLineWidth(math.max(1, Theme.scale(2)))

  for index = 1, 7 do
    local angle = (-0.85 + (index - 1) * 0.29) * math.pi
    local inner = radius + travel
    local outer = radius + travel + Theme.scale(10 + (index % 3) * 3)
    local x1 = centerX + math.cos(angle) * inner
    local y1 = centerY + math.sin(angle) * inner * 0.42
    local x2 = centerX + math.cos(angle) * outer
    local y2 = centerY + math.sin(angle) * outer * 0.42
    local color = index % 2 == 0 and Theme.colors.warning or Theme.colors.danger

    setColor(color, alpha)
    love.graphics.line(x1, y1, x2, y2)
  end

  love.graphics.setLineWidth(previousWidth)
end

local function drawPanelFlash(x, y, width, height, state)
  if not state or state.age < 0 then
    return
  end

  local flashProgress = clamp(state.age / FLASH_DURATION, 0, 1)
  local flashAlpha = (1 - flashProgress) * 0.34
  local ringAlpha = (1 - clamp(state.age / 0.44, 0, 1)) * 0.72
  local previousWidth = love.graphics.getLineWidth()

  if flashAlpha > 0 then
    setColor(Theme.colors.danger, flashAlpha)
    love.graphics.rectangle("fill", x, y, width, height)
  end

  if ringAlpha > 0 then
    love.graphics.setLineWidth(math.max(2, Theme.scale(3)))
    setColor(Theme.colors.danger, ringAlpha)
    love.graphics.rectangle("line", x - Theme.scale(2), y - Theme.scale(2), width + Theme.scale(4), height + Theme.scale(4))
    love.graphics.setLineWidth(previousWidth)
  end
end

function OpponentHpFeedback.build(batchResult, options)
  local opponentHp = tonumber(batchResult and (batchResult.opponentHp or batchResult.targetScore)) or 0
  local scoreAfter = getStageScoreAfter(batchResult)
  local scoreDelta = getStageScoreDelta(batchResult)

  if opponentHp <= 0 or scoreDelta <= 0 then
    return nil
  end

  local scoreBefore = math.max(0, scoreAfter - scoreDelta)
  local beforeHp = math.max(0, opponentHp - scoreBefore)
  local afterHp = math.max(0, opponentHp - scoreAfter)

  if beforeHp <= afterHp then
    return nil
  end

  return {
    feedbackTime = options and options.feedbackTime or 0,
    duration = options and options.duration or DEFAULT_DURATION,
    beforeHp = beforeHp,
    afterHp = afterHp,
    hpDamage = beforeHp - afterHp,
    totalDamage = scoreDelta,
  }
end

function OpponentHpFeedback.getState(impact, elapsed)
  if not impact then
    return nil
  end

  local age = (elapsed or 0) - (impact.feedbackTime or 0)

  if age < 0 then
    return {
      age = age,
      displayHp = impact.beforeHp,
      color = Theme.colors.text,
      shakeX = 0,
      shakeY = 0,
      scale = 1,
      outlineAlpha = 0,
    }
  end

  local duration = math.max(0.01, impact.duration or DEFAULT_DURATION)
  local countProgress = clamp((age - COUNT_DELAY) / math.max(0.01, duration - COUNT_DELAY), 0, 1)
  local easedCount = easeOutCubic(countProgress)
  local rawHp = lerp(impact.beforeHp or 0, impact.afterHp or 0, easedCount)
  local displayHp = countProgress >= 1 and (impact.afterHp or 0) or math.ceil(rawHp)
  local shakeProgress = clamp(age / SHAKE_DURATION, 0, 1)
  local shakeStrength = (1 - shakeProgress) * Theme.scale(6)
  local pulseProgress = clamp(age / 0.28, 0, 1)

  return {
    age = age,
    displayHp = displayHp,
    color = displayHp <= 0 and Theme.colors.success or Theme.colors.danger,
    shakeX = math.floor(math.sin(age * 76) * shakeStrength),
    shakeY = math.floor(math.sin((age * 61) + 0.7) * shakeStrength * 0.55),
    scale = 1 + ((1 - pulseProgress) * 0.20),
    outlineAlpha = 1 - clamp(age / 0.52, 0, 1),
  }
end

function OpponentHpFeedback.drawPanel(stage, area, fonts, impact, elapsed)
  local hpState = OpponentHpFeedback.getState(impact, elapsed)
  local opponentHp = stage and (stage.opponentHp or stage.targetScore) or 0
  local scoreAppliedToHp = stage and (stage.scoreAppliedToHp or stage.stageScore) or 0
  local finalHp = math.max(0, (opponentHp or 0) - (scoreAppliedToHp or 0))
  local displayHp = hpState and hpState.displayHp or finalHp
  local scoreColor = hpState and hpState.color or (scoreAppliedToHp >= opponentHp and Theme.colors.success or Theme.colors.text)
  local shakeX = hpState and hpState.shakeX or 0
  local shakeY = hpState and hpState.shakeY or 0
  local drawX = area.x + shakeX
  local drawY = area.y + shakeY
  local currentFont = love.graphics.getFont()
  local contentArea = Panel.getContentArea(drawX, drawY, area.width, area.height)
  local titleFont = fonts and fonts.title or currentFont
  local hpScale = HP_NUMBER_SCALE * (hpState and hpState.scale or 1)

  Panel.draw(drawX, drawY, area.width, area.height)
  drawPanelFlash(drawX, drawY, area.width, area.height, hpState)
  drawHitSparks(contentArea.x + math.floor(contentArea.width / 2), contentArea.y + math.floor(contentArea.height / 2), contentArea.width, hpState and hpState.age or -1)

  local hpBounds = TextBox.drawOutlined(tostring(displayHp), contentArea, {
    font = titleFont,
    color = scoreColor,
    align = "center",
    valign = "center",
    fit = "shrink",
    minScale = 0.5,
    maxScale = hpScale,
    outline = hpState and math.max(1, Theme.scale(2)) or 0,
    outlineColor = { 0, 0, 0, 0.82 * (hpState and hpState.outlineAlpha or 0) },
  })

  love.graphics.setFont(currentFont)
  Theme.applyColor(Theme.colors.text)

  return {
    x = hpBounds.centerX,
    y = hpBounds.centerY,
  }
end

return OpponentHpFeedback
