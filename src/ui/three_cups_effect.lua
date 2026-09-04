local CoinArt = require("src.ui.coin_art")
local Theme = require("src.ui.theme")

local ThreeCupsEffect = {
  DURATION = 1.48,
}

local COVER_END = 0.22
local SHUFFLE_END = 0.92
local LIFT_START = 1.02
local LIFT_END = 1.27
local PALM_START = 1.16

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function lerp(startValue, endValue, progress)
  return startValue + ((endValue - startValue) * progress)
end

local function smoothstep(progress)
  local value = clamp(progress, 0, 1)
  return value * value * (3 - (2 * value))
end

local function easeOutCubic(progress)
  local inverse = 1 - clamp(progress, 0, 1)
  return 1 - (inverse * inverse * inverse)
end

local function setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * (alpha or 1))
end

local function slotCenter(layout, slotIndex)
  local x = layout.startX
    + ((math.max(1, slotIndex or 1) - 1) * (layout.cardWidth + layout.cardGap))
    + math.floor(layout.cardWidth / 2)
  return x, layout.centerLineY
end

local function drawCup(centerX, centerY, size, alpha, lift)
  local width = size * 0.92
  local height = size * 1.08
  local y = centerY - (lift or 0)
  local left = centerX - (width * 0.5)
  local right = centerX + (width * 0.5)
  local top = y - (height * 0.5)
  local bottom = y + (height * 0.5)

  setColor(Theme.colors.shadow, 0.62 * alpha)
  love.graphics.ellipse("fill", centerX, bottom + Theme.scale(7), width * 0.54, Theme.scale(9))

  setColor(Theme.colors.deepMagic, alpha)
  love.graphics.polygon("fill",
    left + (width * 0.18), top,
    right - (width * 0.18), top,
    right, bottom,
    left, bottom
  )

  setColor(Theme.colors.magic, 0.34 * alpha)
  love.graphics.polygon("fill",
    left + (width * 0.25), top + Theme.scale(6),
    centerX - (width * 0.04), top + Theme.scale(6),
    centerX - (width * 0.18), bottom - Theme.scale(8),
    left + (width * 0.10), bottom - Theme.scale(8)
  )

  love.graphics.setLineWidth(Theme.scale(2))
  setColor(Theme.colors.warning, 0.96 * alpha)
  love.graphics.line(
    left + (width * 0.18), top,
    right - (width * 0.18), top,
    right, bottom,
    left, bottom,
    left + (width * 0.18), top
  )
  love.graphics.line(left, bottom, right, bottom)

  setColor(Theme.colors.warning, alpha)
  love.graphics.rectangle(
    "fill",
    centerX - (width * 0.16),
    top - Theme.scale(7),
    width * 0.32,
    Theme.scale(7)
  )
  love.graphics.setLineWidth(1)
end

local function drawLabel(label, font, x, y, width, color, alpha)
  love.graphics.setFont(font)
  setColor(Theme.colors.shadow, 0.88 * alpha)
  love.graphics.printf(label, x + Theme.scale(2), y + Theme.scale(2), width, "center")
  setColor(color, alpha)
  love.graphics.printf(label, x, y, width, "center")
end

function ThreeCupsEffect.getPlan(reveal)
  return reveal and reveal.batchResult and reveal.batchResult.trace
    and reveal.batchResult.trace.threeCups or nil
end

function ThreeCupsEffect.isActive(reveal)
  local plan = ThreeCupsEffect.getPlan(reveal)
  return plan and plan.palmed ~= nil
    and (reveal.elapsed or 0) < (reveal.revealTimeline and reveal.revealTimeline.threeCupsDuration
      or ThreeCupsEffect.DURATION)
end

function ThreeCupsEffect.draw(reveal, layout, area, anchors, fonts)
  local plan = ThreeCupsEffect.getPlan(reveal)
  if not plan or not plan.palmed or not layout or not area then return false end

  local duration = reveal.revealTimeline and reveal.revealTimeline.threeCupsDuration
    or ThreeCupsEffect.DURATION
  local elapsed = clamp(reveal.elapsed or 0, 0, duration)
  if elapsed >= duration then return false end

  local coverProgress = easeOutCubic(elapsed / COVER_END)
  local shuffleProgress = smoothstep((elapsed - COVER_END) / (SHUFFLE_END - COVER_END))
  local liftProgress = easeOutCubic((elapsed - LIFT_START) / (LIFT_END - LIFT_START))
  local palmProgress = easeOutCubic((elapsed - PALM_START) / math.max(0.01, duration - PALM_START))
  local scrimAlpha = elapsed < LIFT_START and coverProgress
    or (1 - liftProgress)
  local coinSize = math.min(Theme.scale(96), math.max(Theme.scale(62), math.floor(layout.cardWidth * 0.54)))
  local cupSize = coinSize * 1.18

  setColor(Theme.colors.panel, 0.96 * scrimAlpha)
  love.graphics.rectangle("fill", area.x, area.y, area.width, area.height)

  if elapsed < COVER_END then
    for _, coin in ipairs(plan.originalCoins or {}) do
      local centerX, centerY = slotCenter(layout, coin.sourceSlotIndex)
      CoinArt.draw(
        coin.coinId,
        centerX - math.floor(coinSize / 2),
        centerY - math.floor(coinSize / 2),
        coinSize,
        { alpha = 1, selected = true, glow = false, shadow = false }
      )
    end
  end

  for moveIndex, move in ipairs(plan.moves or {}) do
    local sourceX, sourceY = slotCenter(layout, move.sourceSlotIndex)
    local targetX, targetY = slotCenter(layout, move.targetSlotIndex)
    local centerX = lerp(sourceX, targetX, shuffleProgress)
    local centerY = lerp(sourceY, targetY, shuffleProgress)
    local crossing = math.sin(shuffleProgress * math.pi)
    local crossingDirection = moveIndex % 2 == 0 and 1 or -1
    centerY = centerY + (crossing * Theme.scale(22) * crossingDirection)

    local descendLift = (1 - coverProgress) * cupSize * 0.82
    local revealLift = liftProgress * cupSize * 0.92
    drawCup(centerX, centerY, cupSize, 1 - (liftProgress * 0.18), descendLift + revealLift)
  end

  local titleAlpha = clamp(1 - (elapsed / 0.78), 0, 1)
  if titleAlpha > 0 then
    drawLabel(
      "THREE CUPS",
      fonts and fonts.heading or love.graphics.getFont(),
      area.x,
      area.y + Theme.scale(8),
      area.width,
      Theme.colors.warning,
      titleAlpha
    )
  end

  if elapsed >= LIFT_START then
    local palmedX, palmedY = slotCenter(layout, plan.palmed.targetSlotIndex)
    local labelAlpha = clamp((elapsed - LIFT_START) / 0.12, 0, 1)
      * clamp((duration - elapsed) / 0.10, 0, 1)
    drawLabel(
      "PALMED",
      fonts and fonts.small or love.graphics.getFont(),
      palmedX - math.floor(layout.cardWidth * 0.75),
      palmedY - cupSize * 0.86,
      layout.cardWidth * 1.5,
      Theme.colors.warning,
      labelAlpha
    )

    if elapsed >= PALM_START then
      local hand = anchors and (anchors.handCenter or anchors.handBorder) or nil
      if hand then
        local travelX = lerp(palmedX, hand.x, palmProgress)
        local travelY = lerp(palmedY, hand.y, palmProgress)
          - (math.sin(palmProgress * math.pi) * Theme.scale(42))
        local travelSize = math.floor(lerp(coinSize, hand.size or Theme.scale(58), palmProgress))
        CoinArt.draw(
          plan.palmed.coinId,
          travelX - math.floor(travelSize / 2),
          travelY - math.floor(travelSize / 2),
          travelSize,
          {
            alpha = clamp(1 - ((palmProgress - 0.86) / 0.14), 0.35, 1),
            tilt = math.sin(palmProgress * math.pi * 2) * 0.16,
            glow = false,
            shadow = true,
          }
        )
      end
    end
  end

  return true
end

return ThreeCupsEffect
