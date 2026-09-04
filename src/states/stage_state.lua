local Button = require("src.ui.button")
local CoinDetailOverlay = require("src.ui.coin_detail_overlay")
local CoinArt = require("src.ui.coin_art")
local Coins = require("src.content.coins")
local Layout = require("src.ui.layout")
local LuckSystem = require("src.systems.luck_system")
local OpponentHpFeedback = require("src.ui.opponent_hp_feedback")
local Panel = require("src.ui.panel")
local PurseSystem = require("src.systems.purse_system")
local PurseView = require("src.ui.purse_view")
local RevealEffects = require("src.ui.reveal_effects")
local RevealTimeline = require("src.ui.reveal_timeline")
local ScoreFeed = require("src.ui.score_feed")
local ScoreFloaty = require("src.ui.score_floaty")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")
local ThreeCupsEffect = require("src.ui.three_cups_effect")
local TrickCallout = require("src.ui.trick_callout")
local TrickCharm = require("src.ui.trick_charm")
local TrickCharmDrawer = require("src.ui.trick_charm_drawer")
local TrickBoardSystem = require("src.systems.trick_board_system")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local BossTrickSystem = require("src.systems.boss_trick_system")
local Box = require("src.ui.box")

local StageState = {}
StageState.__index = StageState

local COIN_ARCHETYPE_ORDER = {
  bent = 1,
  hollow = 2,
  blank = 3,
  marked = 4,
  lucky = 5,
  weighted = 6,
}

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function routeIfStageComplete(app)
  if not app or not app.requestStageCompletion then
    return false
  end

  return app:requestStageCompletion() == true
end

local function getCoinRevealTime(reveal, index, resolutionIndex)
  local timelineStart = RevealTimeline.getCoinStart(reveal and reveal.revealTimeline or nil, index, resolutionIndex)

  if timelineStart then
    return timelineStart
  end

  if not reveal or (reveal.coinCount or 0) <= 1 then
    return 0
  end

  return (index - 1) * (reveal.revealDuration / math.max(1, reveal.coinCount - 1))
end

local function playCoinRowFeedback(app, reveal)
  if not reveal or reveal.feedbackPlayed then
    return false
  end

  reveal.feedbackPlayed = true
  app:triggerBatchFeedback(reveal.batchResult)
  return true
end

local function getRetroCoinMotion(progress, cardHeight)
  if not progress then
    return 0, 0, 1, 1, 1, nil, true
  end

  local maxLift = math.floor(cardHeight * 0.21)
  local arc = math.sin(progress * math.pi)
  local settled = progress >= 0.78
  local flipProgress = math.min(1, progress / 0.78)
  local spinProgress = flipProgress * 3
  local edgeFactor = math.abs(math.cos(spinProgress * math.pi))
  local liftOffset = -math.floor(arc * maxLift)
  local tilt = math.sin(flipProgress * math.pi * 2) * 0.16
  local scale = 1 + (arc * 0.05)
  local scaleX = 1
  local scaleY = 0.18 + (edgeFactor * 0.82)
  local spinSide = (math.floor(spinProgress * 2) % 2 == 0) and "heads" or "tails"

  return liftOffset, tilt, scale, scaleX, scaleY, spinSide, settled
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function easeInCubic(progress)
  return progress * progress * progress
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function lerp(startValue, endValue, progress)
  return startValue + ((endValue - startValue) * progress)
end

-- Stable visual scatter avoids per-frame random jitter in draw().
local function getStableSignedValue(key, salt)
  local source = string.format("%s:%s:%s", salt, tostring(key or "coin"), salt)
  local hash = 17

  for index = 1, #source do
    hash = ((hash * 131) + string.byte(source, index) + (index * 17)) % 1000003
  end

  return ((hash / 1000003) * 2) - 1
end

local function formatSignedScore(value)
  local amount = tonumber(value) or 0

  if math.abs(amount - math.floor(amount + 0.5)) < 0.001 then
    amount = math.floor(amount + 0.5)
    return amount >= 0 and string.format("+%d", amount) or tostring(amount)
  end

  return amount >= 0 and string.format("+%.1f", amount) or string.format("%.1f", amount)
end

local function didCoinScore(coin)
  return (tonumber(coin and coin.scoreContribution) or 0) > 0
end

local function getScoreBounceIntensity(scoreContribution, chainDepth, triggerCount)
  local score = math.max(0, tonumber(scoreContribution) or 0)
  local chain = math.max(0, tonumber(chainDepth) or 0)
  local triggers = math.max(0, tonumber(triggerCount) or 0)

  return clamp(1 + (math.min(score, 8) * 0.11) + (math.min(chain, 5) * 0.13) + (math.min(triggers, 4) * 0.10), 1, 2.45)
end

local function getScoreBounceTiming(coinMotionDuration)
  local motionDuration = math.max(0.001, coinMotionDuration or 0.22)

  return motionDuration * 0.78, 0.13, 0.31
end

local function getScoreBounceOffsetFromAge(age, coinMotionDuration, coinSize, cardWidth, visualKey, intensity, salt)
  local _, riseDuration, fallDuration = getScoreBounceTiming(coinMotionDuration)
  local clampedIntensity = clamp(tonumber(intensity) or 1, 1, 2.45)
  local reboundDuration = clampedIntensity > 1.28 and 0.16 or 0
  local totalDuration = riseDuration + fallDuration + reboundDuration

  if not age or age < 0 or age > totalDuration then
    return 0, 0
  end

  local size = coinSize or Theme.scale(72)
  local height = math.floor(size * clamp(0.28 + ((clampedIntensity - 1) * 0.10), 0.28, 0.45))

  if age <= riseDuration then
    return 0, -math.floor(easeOutCubic(age / riseDuration) * height)
  end

  if age <= (riseDuration + fallDuration) then
    return 0, -math.floor((1 - easeInCubic((age - riseDuration) / fallDuration)) * height)
  end

  local reboundProgress = (age - riseDuration - fallDuration) / math.max(0.001, reboundDuration)
  local reboundHeight = height * 0.16 * clamp(clampedIntensity - 1, 0, 1.2)

  return 0, -math.floor(math.sin(reboundProgress * math.pi) * reboundHeight)
end

local function getScoreBounceOffset(revealAge, coinMotionDuration, coinSize, cardWidth, visualKey, shouldBounce, scoreContribution, chainDepth)
  if not shouldBounce or not revealAge then
    return 0, 0
  end

  local startTime = getScoreBounceTiming(coinMotionDuration)
  return getScoreBounceOffsetFromAge(
    revealAge - startTime,
    coinMotionDuration,
    coinSize,
    cardWidth,
    visualKey,
    getScoreBounceIntensity(scoreContribution, chainDepth, 0),
    "score-bounce-x"
  )
end

local function getScoreBounceApexDelay(coinMotionDuration)
  local startTime, riseDuration = getScoreBounceTiming(coinMotionDuration)
  return startTime + riseDuration
end

local function getTriggeredScoreBounceOffset(timeline, resolutionIndex, elapsed, coinMotionDuration, coinSize, cardWidth, visualKey, scoreContribution, chainDepth)
  local offsetX = 0
  local offsetY = 0
  local targetResolutionIndex = tonumber(resolutionIndex)
  local triggerCount = 0

  for _, bounce in ipairs(timeline and timeline.scoreBounces or {}) do
    if tonumber(bounce.resolutionIndex) == targetResolutionIndex then
      triggerCount = triggerCount + 1
      local bounceX, bounceY = getScoreBounceOffsetFromAge(
        (elapsed or 0) - (bounce.startTime or 0),
        coinMotionDuration,
        coinSize,
        cardWidth,
        visualKey,
        getScoreBounceIntensity(scoreContribution, chainDepth, triggerCount) * 0.86,
        string.format("score-trigger-%d", triggerCount)
      )
      offsetX = offsetX + bounceX
      offsetY = math.min(offsetY, bounceY)
    end
  end

  return offsetX, offsetY
end

local function getPerCoinScoreEntry(batchResult, coinState)
  local perCoin = batchResult and batchResult.scoreBreakdown and batchResult.scoreBreakdown.perCoin or {}

  for _, entry in ipairs(perCoin) do
    if coinState.resolutionIndex and entry.resolutionIndex == coinState.resolutionIndex then
      return entry
    end
  end

  for _, entry in ipairs(perCoin) do
    if entry.slotIndex == coinState.slotIndex and entry.coinId == coinState.coinId then
      return entry
    end
  end

  return nil
end

local COIN_ROW_JITTER_X_RANGE = 0.14
local COIN_ROW_JITTER_Y_RANGE = 0.38
local DEALT_PILE_JITTER_X_RANGE = 0.18
local DEALT_PILE_JITTER_Y_RANGE = 0.14
local HAND_THROW_DURATION = 0.34
local HAND_THROW_STAGGER = 0.055
local HAND_THROW_SETTLE_PADDING = 0.10
local HAND_THROW_IMPACT_DURATION = 0.24
local DEALT_REFILL_DURATION = 0.36
local DEALT_REFILL_STAGGER = 0.045
local DEALT_REFILL_SETTLE_PADDING = 0.08
local DEALT_REFILL_AFTER_SCORE_DELAY = 0.32
local SELECT_COIN_TRAVEL_DURATION = 0.28
local LUCK_METER_FILL_DURATION = 0.16
local LUCK_METER_STEP_GAP = 0.09

local function getShortCoinName(coinId)
  local definition = Coins.getById(coinId)
  local name = tostring(definition and definition.name or coinId or "Coin")
  return (name:gsub("%s+[Cc]oin$", ""))
end

local function getCoinGroupSortKey(coinId)
  local definition = Coins.getById(coinId)
  return COIN_ARCHETYPE_ORDER[definition and definition.archetype] or 999
end

local function getDealtCoinGroups(coins, slots, runState)
  local groupsByCoinId = {}
  local groups = {}
  local instanceOrder = {}

  local function ensureGroup(coinId)
    local key = tostring(coinId or "coin")
    local group = groupsByCoinId[key]

    if not group then
      group = {
        coinId = key,
        name = getShortCoinName(key),
        coins = {},
      }
      groupsByCoinId[key] = group
      table.insert(groups, group)
    end

    return group
  end

  for instanceIndex, instance in ipairs(runState and runState.coinInstances or {}) do
    if instance.instanceId then
      instanceOrder[instance.instanceId] = instanceIndex
    end

    if instance.definitionId then
      ensureGroup(instance.definitionId)
    end
  end

  for _, slot in ipairs(slots or {}) do
    if slot.instanceId and slot.definitionId then
      ensureGroup(slot.definitionId)
    end
  end

  for _, coin in ipairs(coins or {}) do
    local group = ensureGroup(coin.coinId)
    table.insert(group.coins, coin)
  end

  for _, group in ipairs(groups) do
    table.sort(group.coins, function(left, right)
      local leftOrder = instanceOrder[left.instanceId] or left.dealtIndex or 9999
      local rightOrder = instanceOrder[right.instanceId] or right.dealtIndex or 9999
      return leftOrder < rightOrder
    end)
  end

  return groups
end

local function getNewlyDealtSlots(slots, refillEvent)
  local returnedSet = {}

  for _, instanceId in ipairs(refillEvent and refillEvent.returnedInstanceIds or {}) do
    returnedSet[instanceId] = true
  end

  local newlyDealt = {}

  for _, slot in ipairs(slots or {}) do
    if slot.instanceId and not returnedSet[slot.instanceId] then
      table.insert(newlyDealt, slot)
    end
  end

  return newlyDealt
end

local function appendLuckMeterEvents(events, startTime, amount)
  local remaining = math.max(0, tonumber(amount) or 0)
  local stepIndex = 0

  while remaining > 0.000001 do
    local chunk = math.min(1, remaining)
    table.insert(events, {
      time = (startTime or 0) + (stepIndex * LUCK_METER_STEP_GAP),
      amount = chunk,
    })
    remaining = remaining - chunk
    stepIndex = stepIndex + 1
  end
end


local function getUiRect(app)
  local metrics = app:getUiMetrics()
  return metrics.rect, metrics.spacing, metrics.metrics, metrics.window
end

local function getMainLoopLayout(app)
  local rect = getUiRect(app)
  local topHeight = math.max(1, math.floor(rect.height * 0.175))
  local gameHeight = math.max(1, math.floor(rect.height * 0.4))
  local actionsHeight = math.max(1, rect.height - topHeight - gameHeight)
  local topLayout = Layout.resolveGrid({
    x = rect.x,
    y = rect.y,
    width = rect.width,
    height = topHeight,
  }, 12, 1, 0, {
    score = { column = 1, row = 1, columnSpan = 2, rowSpan = 1 },
    stageStats = { column = 3, row = 1, columnSpan = 9, rowSpan = 1 },
    controls = { column = 12, row = 1, columnSpan = 1, rowSpan = 1 },
  })

  return {
    score = topLayout.score,
    stageStats = topLayout.stageStats,
    controls = topLayout.controls,
    gameWindow = {
      x = rect.x,
      y = rect.y + topHeight,
      width = rect.width,
      height = gameHeight,
    },
    actions = {
      x = rect.x,
      y = rect.y + topHeight + gameHeight,
      width = rect.width,
      height = actionsHeight,
    },
  }
end

local function insetRect(rect, inset)
  local amount = math.max(0, inset or 0)

  return {
    x = rect.x + amount,
    y = rect.y + amount,
    width = math.max(1, rect.width - (amount * 2)),
    height = math.max(1, rect.height - (amount * 2)),
  }
end

local function getControlButtonFrame(app, index, count)
  local layout = getMainLoopLayout(app)
  local _, spacing = getUiRect(app)
  local area = layout.controls
  local gap = spacing.itemGap
  local size = math.max(1, math.min(40, area.width - (gap * 2), math.floor((area.height - (gap * (count - 1))) / count)))
  local groupHeight = (size * count) + (gap * (count - 1))
  local startY = area.y + math.floor((area.height - groupHeight) / 2)

  return {
    x = area.x + math.floor((area.width - size) / 2),
    y = startY + ((index - 1) * (size + gap)),
    width = size,
    height = size,
  }
end

function StageState.new()
  return setmetatable({
    statusMessage = "",
    buttons = {},
    helpDialogOpen = false,
    purseDialogOpen = false,
    purseDialogScrollOffset = 0,
    purseScrollButtons = {},
    trickCharmDrawerOpen = false,
    trickCharmDrawerScrollOffset = 0,
    trickCharmDrawerScrollButtons = {},
    trickCharmDrawerTriggerRect = nil,
    trickCharmDrawerRect = nil,
    logDialogOpen = false,
    logDialogScrollOffset = 0,
    logScrollButtons = {},
    coinRowReveal = nil,
    trickCalloutStyle = nil,
    handThrowAnimation = nil,
    pendingHandThrow = false,
    dealtRefillAnimation = nil,
    selectionTravelAnimations = {},
    reveal = nil,
    handCardRects = {},
    dealtCardRects = {},
    coinSlotTargets = {},
    revealCoinPositions = nil,
    threeCupsRenderContext = nil,
    coinRowVisuals = {},
    coinRowJitters = {},
    luckMeterAnimation = nil,
    scoreFloaties = {},
    spawnedScoreFloatyKeys = {},
    opponentDamageFloatyAnchor = nil,
    lastDt = 1 / 60,
    draggingHandSlotIndex = nil,
    draggingHandCoinId = nil,
    draggingHandVisualKey = nil,
    dragInsertSlotIndex = nil,
    dragPointerX = nil,
    dragPointerY = nil,
    dragGrabOffsetX = 0,
    dragGrabOffsetY = 0,
    dragVisualX = nil,
    dragVisualY = nil,
    dragBaseSize = nil,
    dragLiftProgress = 0,
    dragTilt = 0,
  }, StageState)
end

function StageState:isRevealActive()
  return self.reveal ~= nil and self.reveal.active == true
end

function StageState:startReveal(app, batchResult)
  if app.stageState and app.stageState.stageStatus == "active" then
    TrickBoardSystem.setPhase(app.stageState, "reveal")
  end
  local revealDuration = app.config.get("ui.batchRevealDuration", 0.75)
  local revealEndDuration = app.config.get("ui.batchRevealEndDuration", 1.05)
  local coins = {}

  for _, coinState in ipairs(batchResult.perCoin or {}) do
      table.insert(coins, {
        coinId = coinState.coinId,
        slotIndex = coinState.slotIndex,
        resolutionIndex = coinState.resolutionIndex,
        result = coinState.result,
        forcedResult = coinState.forcedResult,
        foretold = coinState.foretold == true,
        foretoldResult = coinState.foretoldResult,
        foretoldBy = coinState.foretoldBy,
        smuggled = coinState.smuggled == true,
        smuggledBy = coinState.smuggledBy,
        boardSlotIndex = coinState.boardSlotIndex,
        overloadSlotIndex = coinState.overloadSlotIndex,
        anchorSelectedSlotIndex = coinState.anchorSelectedSlotIndex,
        anchorInstanceId = coinState.anchorInstanceId,
        anchorCoinId = coinState.anchorCoinId,
        anchorOverloadIndex = coinState.anchorOverloadIndex,
        palmed = coinState.palmed == true,
        sleightSaved = coinState.sleightSaved == true,
        forged = coinState.forged == true,
        forgedBy = coinState.forgedBy,
        forgedCoinId = coinState.forgedCoinId,
        chained = coinState.chained == true,
        chainedBy = coinState.chainedBy,
        chainDepth = coinState.chainDepth,
        didMatch = coinState.result == batchResult.call,
      })
  end

  self.reveal = {
    active = true,
    elapsed = 0,
    revealDuration = revealDuration,
    finishDuration = math.max(revealDuration, revealEndDuration),
    batchId = batchResult.batchId,
    call = batchResult.call,
    stageStatus = batchResult.status,
    scoreAppliedToHp = batchResult.scoreAppliedToHp,
    opponentHp = batchResult.opponentHp,
    stageScore = batchResult.stageScore,
    targetScore = batchResult.targetScore,
    runTotalScore = batchResult.runTotalScore,
    influence = batchResult.influence,
    shopPoints = batchResult.shopPoints,
    flipsRemaining = batchResult.flipsRemaining,
    stageDelta = batchResult.scoreBreakdown and batchResult.scoreBreakdown.totalStageScoreDelta or 0,
    coins = coins,
  }
end

function StageState:startCoinRowReveal(app, batchResult)
  local coinCount = #(batchResult.perCoin or {})
  local trickCallouts = TrickCallout.buildStacks(batchResult)
  local revealTimeline = RevealTimeline.build(batchResult, {
    trickCallouts = trickCallouts,
    coinMotionDuration = app.config.get("ui.coinRevealMotionDuration", 0.32),
    baseHoldDuration = app.config.get("ui.coinRevealBaseHoldDuration", 0.22),
    effectHoldDuration = app.config.get("ui.coinRevealEffectHoldDuration", 0.28),
    scoreHoldDuration = app.config.get("ui.coinRevealScoreHoldDuration", 0.12),
    linkDuration = app.config.get("ui.coinRevealLinkDuration", 0.42),
    sleightMoveDuration = app.config.get("ui.coinRevealSleightMoveDuration", 0.16),
    threeCupsDuration = app.config.get("ui.threeCupsRevealDuration", ThreeCupsEffect.DURATION),
  })
  local revealDuration = revealTimeline.revealDuration or app.config.get("ui.batchRevealDuration", 0.75)
  local coinMotionDuration = revealTimeline.coinMotionDuration or app.config.get("ui.coinRevealMotionDuration", 0.32)
  local displayDuration = math.max(1.35, revealTimeline.displayDuration or (revealDuration + coinMotionDuration + 0.82))
  local feedbackTime = math.max(revealDuration + coinMotionDuration, displayDuration - 0.82)
  local opponentHpImpact = OpponentHpFeedback.build(batchResult, {
    feedbackTime = feedbackTime,
    duration = app.config.get("ui.opponentHpHitDuration", 0.68),
  })

  self.coinRowReveal = {
    batchId = batchResult.batchId,
    batchResult = batchResult,
    elapsed = 0,
    revealDuration = revealDuration,
    coinMotionDuration = coinMotionDuration,
    feedbackTime = feedbackTime,
    displayDuration = displayDuration,
    coinCount = coinCount,
    nextSoundIndex = 1,
    feedbackPlayed = false,
    opponentHpImpact = opponentHpImpact,
    trickCallouts = trickCallouts,
    revealTimeline = revealTimeline,
  }
  self:startLuckMeterAnimation(self.coinRowReveal)
  self.spawnedScoreFloatyKeys = {}
end

function StageState:getTrickCalloutStyle(app)
  local configuredStyle = app and app.config and app.config.get("ui.trickCalloutStyle", "combo") or "combo"
  return TrickCallout.normalizeStyle(self.trickCalloutStyle or configuredStyle)
end

function StageState:cycleTrickCalloutStyle(app)
  self.trickCalloutStyle = TrickCallout.nextStyle(self:getTrickCalloutStyle(app))
  self.statusMessage = string.format("Trick callouts: %s.", TrickCallout.getStyleLabel(self.trickCalloutStyle))
end

function StageState:startLuckMeterAnimation(reveal)
  local batchResult = reveal and reveal.batchResult or nil
  local trace = batchResult and batchResult.trace and batchResult.trace.luck or nil
  local before = trace and trace.before or nil

  if not before or type(trace.deltas) ~= "table" then
    self.luckMeterAnimation = nil
    return
  end

  local events = {}
  local matchEvents = {}

  for index, coinState in ipairs(batchResult.perCoin or {}) do
    if coinState.result == batchResult.call then
      table.insert(matchEvents, {
        time = getCoinRevealTime(reveal, index) + ((reveal.coinMotionDuration or 0.25) * 0.78),
      })
    end
  end

  for _, delta in ipairs(trace.deltas or {}) do
    local amount = tonumber(delta.appliedAmount) or 0

    if amount > 0 then
      if delta.source == "base_match" and #matchEvents > 0 then
        local perMatchAmount = amount / #matchEvents

        for _, matchEvent in ipairs(matchEvents) do
          appendLuckMeterEvents(events, matchEvent.time, perMatchAmount)
        end
      else
        appendLuckMeterEvents(events, (reveal.revealDuration or 0) + (reveal.coinMotionDuration or 0.25), amount)
      end
    end
  end

  if #events <= 0 then
    self.luckMeterAnimation = nil
    return
  end

  table.sort(events, function(left, right)
    return (left.time or 0) < (right.time or 0)
  end)

  self.luckMeterAnimation = {
    beforeValue = tonumber(before.value) or 0,
    max = math.max(1, tonumber(before.max) or 1),
    events = events,
  }
end

function StageState:getDisplayedLuckMeter(app)
  local animation = self.luckMeterAnimation
  local reveal = self.coinRowReveal

  if not animation or not reveal then
    local meter = LuckSystem.getMeter(app.runState)
    local ratio, _ = LuckSystem.getMeterProgress(app.runState)
    return meter, ratio
  end

  local value = animation.beforeValue or 0

  for _, event in ipairs(animation.events or {}) do
    local elapsed = (reveal.elapsed or 0) - (event.time or 0)

    if elapsed >= LUCK_METER_FILL_DURATION then
      value = value + (event.amount or 0)
    elseif elapsed > 0 then
      value = value + ((event.amount or 0) * easeOutCubic(elapsed / LUCK_METER_FILL_DURATION))
    end
  end

  local maxValue = math.max(1, animation.max or 1)
  value = clamp(value, 0, maxValue)

  return {
    value = value,
    max = maxValue,
    fatedFlipActive = value >= maxValue,
  }, clamp(value / maxValue, 0, 1)
end

function StageState:completeReveal(app)
  if not self:isRevealActive() then
    return false, "reveal_not_active"
  end

  local stageShouldAdvance = app.stageState and app.stageState.stageStatus ~= "active"

  playCoinRowFeedback(app, self.coinRowReveal)
  self.reveal = nil
  self.luckMeterAnimation = nil

  if app.stageState and app.stageState.stageStatus == "active" then
    TrickBoardSystem.setPhase(app.stageState, "setup")
  end

  if stageShouldAdvance then
    app:clearFeedback()
    routeIfStageComplete(app)
  end

  return true
end

function StageState:isStageActive(app)
  return app.stageState and app.stageState.stageStatus == "active"
end

function StageState:getSelectedFlipSlotCount(app)
  return #(app.stageState and app.stageState.purse and app.stageState.purse.handSlots or {})
end

function StageState:getMaxFlipSlots(app)
  return PurseSystem.getMaxFlipSlots(app and app.runState or nil)
end

function StageState:getSelectionStatusMessage(app)
  return ""
end

function StageState:getSelectionErrorMessage(app, reason)
  if reason == "flip_slots_full" then
    return string.format("All %d slots are filled.", self:getMaxFlipSlots(app))
  end

  if reason == "select at least one coin before flipping" then
    return self:getSelectionStatusMessage(app)
  end

  return tostring(reason)
end

function StageState:getUnselectedDealtCoinStates(app)
  local coins = {}
  local slots = app.stageState and app.stageState.purse and app.stageState.purse.dealtHandSlots or {}

  for dealtIndex, slot in ipairs(slots) do
    if slot.instanceId and slot.definitionId and slot.selectedSlotIndex == nil and slot.smuggled ~= true then
      table.insert(coins, {
        coinId = slot.definitionId,
        instanceId = slot.instanceId,
        dealtIndex = dealtIndex,
        foretold = slot.foretold == true,
        foretoldResult = slot.foretoldResult,
      })
    end
  end

  return coins
end

function StageState:tryToggleDealtCoin(app, dealtIndex)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress."
    return false, "reveal_active"
  end

  if not self:isStageActive(app) then
    self.statusMessage = "This stage is no longer active."
    return false, "stage_not_active"
  end

  local sourceRect = self:getDealtCardByDealtIndex(dealtIndex)
  local ok, result, action = app:toggleDealtCoinSelection(dealtIndex)

  if not ok then
    self.statusMessage = self:getSelectionErrorMessage(app, result)
    return false, result
  end

  self.statusMessage = self:getSelectionStatusMessage(app)

  if app.audioSystem then
    app.audioSystem:playCue("coin_whoosh")
  end

  if action == "select" then
    self:startSelectionTravelAnimation(sourceRect, result, "to_slot")
  end

  return true, result
end

function StageState:tryDeselectFlipSlot(app, slotIndex, sourceRect)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress."
    return false, "reveal_active"
  end

  sourceRect = sourceRect or self:getHandCardBySlotIndex(slotIndex)

  local ok, result = app:deselectFlipSlot(slotIndex)

  if not ok then
    self.statusMessage = self:getSelectionErrorMessage(app, result)
    return false, result
  end

  self.statusMessage = self:getSelectionStatusMessage(app)

  if app.audioSystem then
    app.audioSystem:playCue("coin_whoosh")
  end

  self:startSelectionTravelAnimation(sourceRect, result, "to_hand")

  return true, result
end

function StageState:selectCall(app, call)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress. Click Skip Reveal or press Enter to continue."
    return false, "reveal_active"
  end

  if not self:isStageActive(app) then
    self.statusMessage = "This stage is no longer active."
    return false, "stage_not_active"
  end

  app.selectedCall = call
  if app:isFatedFlipActive() then
    self.statusMessage = string.format("TWIST OF FATE: %s selected. All coins will land on your call.", string.upper(call))
  elseif self:getSelectedFlipSlotCount(app) == 0 then
    self.statusMessage = self:getSelectionStatusMessage(app)
  else
    self.statusMessage = ""
  end
  return true
end

function StageState:callAndResolve(app, call)
  local ok, reason = self:selectCall(app, call)

  if not ok then
    return false, reason
  end

  return self:tryResolveBatch(app)
end

function StageState:tryResolveBatch(app)
  if self:isRevealActive() then
    return self:completeReveal(app)
  end

  if not self:isStageActive(app) then
    self.statusMessage = "This stage is no longer active."
    return false, "stage_not_active"
  end

  if not app.selectedCall then
    self.statusMessage = "Choose HEADS or TAILS before flipping."
    return false, "call_required"
  end

  if self:getSelectedFlipSlotCount(app) == 0 then
    self.statusMessage = self:getSelectionStatusMessage(app)
    return false, "selection_required"
  end

  local batchResult, errorMessage = app:resolveCurrentBatch(app.selectedCall, { deferFeedback = true })

  if not batchResult then
    self.statusMessage = errorMessage
    return false, errorMessage
  end

  if app.audioSystem then
    app.audioSystem:playCue("coin_flip")
  end

  self.statusMessage = ""

  self:startCoinRowReveal(app, batchResult)

  app.selectedCall = nil

  if batchResult.status == "active" then
    local dealtSlots, drawWarning = app:ensureHandDrawn()

    if dealtSlots and drawWarning ~= "purse_empty" then
      local refillSlots = getNewlyDealtSlots(dealtSlots, batchResult.trace and batchResult.trace.refillEvent or nil)
      self:startDealtRefillAnimation(refillSlots, (self.coinRowReveal and self.coinRowReveal.feedbackTime or 0) + DEALT_REFILL_AFTER_SCORE_DELAY)
    end

    if app.stageState and app.stageState.stageStatus ~= "active" then
      batchResult.status = app.stageState.stageStatus
      batchResult.flipsRemaining = app.stageState.flipsRemaining

      if batchResult.trace then
        batchResult.trace.stageStatusAfter = app.stageState.stageStatus
        batchResult.trace.flipsRemainingAfter = app.stageState.flipsRemaining
      end

      local lastHistoryBatch = app.runState and app.runState.history and app.runState.history.flipBatches[#app.runState.history.flipBatches] or nil

      if lastHistoryBatch and lastHistoryBatch.batchId == batchResult.batchId and lastHistoryBatch.trace then
        lastHistoryBatch.trace.stageStatusAfter = app.stageState.stageStatus
        lastHistoryBatch.trace.flipsRemainingAfter = app.stageState.flipsRemaining
      end

      if drawWarning == "purse_empty" then
        self.statusMessage = string.format("Pouch empty. Stage %s.", batchResult.status)
      end
    end

    if app.stageState and app.stageState.stageStatus == "active" and not drawWarning then
      self.statusMessage = self:getSelectionStatusMessage(app)
    end
  end

  if batchResult.status ~= "active" then
    self:startReveal(app, batchResult)
  else
    self.reveal = nil
  end

  return true, batchResult
end

function StageState:tryMoveSlot(app, slotIndex, direction)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress."
    return false, "reveal_active"
  end

  local ok, result = app:moveHandSlot(slotIndex, direction)

  if not ok then
    self.statusMessage = tostring(result)
  end

  if ok and app.audioSystem then
    app.audioSystem:playCue("coin_whoosh")
  end

  return ok, result
end

function StageState:tryMoveSlotTo(app, fromSlotIndex, toSlotIndex)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress."
    return false, "reveal_active"
  end

  if fromSlotIndex == toSlotIndex then
    return true
  end

  local direction = toSlotIndex > fromSlotIndex and 1 or -1
  local currentSlotIndex = fromSlotIndex
  local finalResult = nil

  while currentSlotIndex ~= toSlotIndex do
    local ok, result = app:moveHandSlot(currentSlotIndex, direction, { suppressReorderHook = true })

    if not ok then
      self.statusMessage = tostring(result)
      return false, result
    end

    finalResult = result
    currentSlotIndex = currentSlotIndex + direction
  end

  if finalResult then
    app:applyHandReorderHook(finalResult)
    app:assertRuntimeInvariants("stage_state.tryMoveSlotTo", { history = true })
    app:saveActiveRun("move_hand_slot", "stage")

    if app.audioSystem then
      app.audioSystem:playCue("coin_whoosh")
    end
  end

  return true
end

function StageState:buildButtons(app, x, y, width, height)
  local _, spacing, componentMetrics = getUiRect(app)
  local gap = spacing.itemGap
  local buttonWidth = math.max(1, math.floor((width - (gap * 2)) / 3))
  local buttonHeight = math.max(1, height or componentMetrics.buttonHeight)
  local stageActive = self:isStageActive(app)
  local revealActive = self:isRevealActive()
  local fatedActive = stageActive and not revealActive and app:isFatedFlipActive()
  local selectedCount = self:getSelectedFlipSlotCount(app)

  self.buttons = {
    {
      x = x,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "TAILS",
      variant = app.selectedCall == "tails" and "primary" or "default",
      focused = app.selectedCall == "tails",
      active = app.selectedCall == "tails",
      disabled = not stageActive or revealActive,
      onClick = function()
        return self:selectCall(app, "tails")
      end,
    },
    {
      x = x + buttonWidth + gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = fatedActive and "TWIST OF FATE" or "FLIP",
      variant = fatedActive and "warning" or "success",
      focused = fatedActive,
      glow = fatedActive,
      disabled = not stageActive or revealActive or not app.selectedCall or selectedCount == 0,
      onClick = function()
        return self:tryResolveBatch(app)
      end,
    },
    {
      x = x + ((buttonWidth + gap) * 2),
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "HEADS",
      variant = app.selectedCall == "heads" and "primary" or "default",
      focused = app.selectedCall == "heads",
      active = app.selectedCall == "heads",
      disabled = not stageActive or revealActive,
      onClick = function()
        return self:selectCall(app, "heads")
      end,
    },
  }

  if revealActive then
    self.buttons = {
      {
        x = x,
        y = y,
        width = width,
        height = buttonHeight,
        label = self.reveal and self.reveal.stageStatus ~= "active" and "CONTINUE" or "CONTINUE",
        variant = "warning",
        onClick = function()
          return self:tryResolveBatch(app)
        end,
      },
    }
  end

  return self.buttons
end

function StageState:getButtonLayout(app)
  local layout = getMainLoopLayout(app)
  local _, spacing, componentMetrics = getUiRect(app)
  local area = layout.actions
  local horizontalInset = spacing.blockGap
  local baseButtonHeight = math.min(
    math.max(componentMetrics.buttonHeight, math.floor(area.height * 0.36)),
    math.max(1, area.height - (spacing.blockGap * 2))
  )
  local buttonHeight = math.max(1, math.floor(baseButtonHeight * 0.75))

  return {
    x = area.x + horizontalInset,
    y = area.y + area.height - spacing.blockGap - buttonHeight,
    width = math.max(1, area.width - (horizontalInset * 2)),
    height = buttonHeight,
  }
end

function StageState:getDealtCoinsLayout(app)
  local layout = getMainLoopLayout(app)
  local _, spacing = getUiRect(app)
  local actionsArea = insetRect(layout.actions, spacing.itemGap)
  local buttonLayout = self:getButtonLayout(app)
  local hasStatus = tostring(self.statusMessage or "") ~= ""
  local statusHeight = hasStatus and ((app.fonts.small and app.fonts.small:getHeight() or Theme.spacing.lineHeight) + spacing.itemGap) or 0
  local y = actionsArea.y + spacing.itemGap + statusHeight

  return {
    x = buttonLayout.x,
    y = y,
    width = buttonLayout.width,
    height = math.max(Theme.scale(38), buttonLayout.y - y - spacing.itemGap),
  }
end

function StageState:getHelpButtonLayout(app)
  local frame = getControlButtonFrame(app, 3, 3)

  return {
    x = frame.x,
    y = frame.y,
    width = frame.width,
    height = frame.height,
    label = "?",
    variant = self.helpDialogOpen and "primary" or "default",
    onClick = function()
      self.helpDialogOpen = not self.helpDialogOpen
      return true
    end,
  }
end

function StageState:getPurseButtonLayout(app)
  local frame = getControlButtonFrame(app, 2, 3)

  return {
    x = frame.x,
    y = frame.y,
    width = frame.width,
    height = frame.height,
    label = "P",
    variant = self.purseDialogOpen and "primary" or "default",
    onClick = function()
      if not self.purseDialogOpen then
        self.purseDialogScrollOffset = 0
      end

      self.purseDialogOpen = not self.purseDialogOpen
      return true
    end,
  }
end

function StageState:scrollPurseDialog(app, direction)
  local dialog = self:getPurseDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")
  local maxScrollOffset = PurseView.getMaxScrollOffset(app, contentArea, app.stageState)

  self.purseDialogScrollOffset = math.max(0, math.min((self.purseDialogScrollOffset or 0) + direction, maxScrollOffset))
  return true
end

function StageState:getTrickCharmDrawerLayout(app)
  local uiRect = getUiRect(app)

  return TrickCharmDrawer.getDrawerLayout(uiRect)
end

function StageState:scrollTrickCharmDrawer(app, direction)
  local drawer = self:getTrickCharmDrawerLayout(app)
  local contentArea = TrickCharmDrawer.getContentArea(drawer)
  local charms = app.getTrickCharmData and app:getTrickCharmData() or {}
  local maxScrollOffset = TrickCharmDrawer.getMaxScrollOffset(app, contentArea, charms)

  self.trickCharmDrawerScrollOffset = math.max(0, math.min((self.trickCharmDrawerScrollOffset or 0) + direction, maxScrollOffset))
  return true
end

function StageState:getLogButtonLayout(app)
  local frame = getControlButtonFrame(app, 1, 3)

  return {
    x = frame.x,
    y = frame.y,
    width = frame.width,
    height = frame.height,
    label = "L",
    variant = self.logDialogOpen and "primary" or "default",
    onClick = function()
      if not self.logDialogOpen then
        self.logDialogScrollOffset = 0
      end

      self.logDialogOpen = not self.logDialogOpen
      return true
    end,
  }
end

function StageState:getWrappedLogLineCount(lines, width)
  local font = love.graphics.getFont()
  local totalLineCount = 0

  for _, line in ipairs(lines or {}) do
    local content = tostring(line or "")

    if content == "" then
      totalLineCount = totalLineCount + 1
    else
      local _, wrapped = font:getWrap(content, width)
      totalLineCount = totalLineCount + math.max(1, #wrapped)
    end
  end

  return totalLineCount
end

function StageState:getLogMaxScrollOffset(lines, contentArea)
  local visibleLineCount = math.max(1, math.floor(contentArea.height / Theme.spacing.lineHeight))
  local totalLineCount = self:getWrappedLogLineCount(lines, contentArea.width)

  return math.max(0, totalLineCount - visibleLineCount)
end

function StageState:scrollLogDialog(app, direction)
  love.graphics.setFont(app.fonts.body)

  local dialog = self:getHelpDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Flip Log")
  local maxScrollOffset = self:getLogMaxScrollOffset(app:getFlipLogLines(), contentArea)

  self.logDialogScrollOffset = math.max(0, math.min((self.logDialogScrollOffset or 0) + direction, maxScrollOffset))
  return true
end

function StageState:drawLogLines(lines, contentArea, scrollOffset)
  local font = love.graphics.getFont()
  local lineHeight = Theme.spacing.lineHeight
  local currentY = contentArea.y
  local visualLineIndex = 0

  Theme.applyColor(Theme.colors.text)

  for _, line in ipairs(lines or {}) do
    local content = tostring(line or "")
    local wrapped = nil

    if content == "" then
      wrapped = { "" }
    else
      local _, wrappedLines = font:getWrap(content, contentArea.width)
      wrapped = wrappedLines
    end

    for _, wrappedLine in ipairs(wrapped) do
      visualLineIndex = visualLineIndex + 1

      if visualLineIndex > scrollOffset then
        if currentY + lineHeight > contentArea.y + contentArea.height then
          return
        end

        love.graphics.printf(wrappedLine, contentArea.x, currentY, contentArea.width, "left")
        currentY = currentY + lineHeight
      end
    end
  end
end

function StageState:getHelpDialogLines(app)
  local lines = {
    "You are trying to defeat the opponent before flips run out.",
    "Move coins from Hand into Flip, arrange them, pick HEADS or TAILS, then flip.",
  }

  table.insert(lines, "")
  table.insert(lines, "Controls:")
  table.insert(lines, "- Click Hand coins: move them into Flip")
  table.insert(lines, "- Click HEADS or TAILS: choose the call")
  table.insert(lines, "- Flip / Enter: resolve selected coins")
  table.insert(lines, "- Drag coins in Flip: reorder the slots")
  table.insert(lines, "- Click a selected coin: move it back to Hand")
  table.insert(lines, "- Click the charm link: inspect Trick Charms")
  table.insert(lines, "- P: inspect pouch")
  table.insert(lines, "- L: inspect flip log")
  table.insert(lines, "- Space / Enter: skip reveal")
  table.insert(lines, "- Esc: close this dialog")

  if app:isDevControlsEnabled() then
    table.insert(lines, "- F3: toggle debug overlay")
  end

  for _, line in ipairs(app:getDebugControlLines()) do
    table.insert(lines, line)
  end

  return lines
end

function StageState:getHelpDialogLayout(app)
  local rect, spacing = getUiRect(app)
  local dialogWidth = math.min(Theme.scale(700), math.max(1, rect.width - (spacing.screenPadding * 2)))
  local dialogHeight = math.min(Theme.scale(460), math.max(1, rect.height - (spacing.screenPadding * 2)))

  return {
    x = rect.x + math.floor((rect.width - dialogWidth) / 2),
    y = rect.y + math.floor((rect.height - dialogHeight) / 2),
    width = dialogWidth,
    height = dialogHeight,
  }
end

function StageState:getPurseDialogLayout(app)
  local rect, spacing = getUiRect(app)
  local inset = math.max(Theme.scale(8), math.floor(spacing.screenPadding / 2))

  return {
    x = rect.x + inset,
    y = rect.y + inset,
    width = math.max(Theme.scale(280), rect.width - (inset * 2)),
    height = math.max(Theme.scale(260), rect.height - (inset * 2)),
  }
end

function StageState:drawHelpDialog(app)
  if not self.helpDialogOpen then
    return
  end

  local _, _, _, window = getUiRect(app)
  local dialog = self:getHelpDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Help")
  local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
  local mouseX, mouseY = love.mouse.getPosition()

  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, window.width, window.height)

  Panel.draw(dialog.x, dialog.y, dialog.width, dialog.height, "Help")
  Button.drawButtons({ closeButton }, mouseX, mouseY)

  love.graphics.setFont(app.fonts.body)
  Layout.drawWrappedLines(
    self:getHelpDialogLines(app),
    contentArea.x,
    contentArea.y,
    contentArea.width,
    Theme.colors.text,
    Theme.spacing.lineHeight,
    contentArea.height
  )
end

function StageState:drawPurseDialog(app)
  if not self.purseDialogOpen then
    return
  end

  local _, _, _, window = getUiRect(app)
  local dialog = self:getPurseDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")
  local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
  local mouseX, mouseY = love.mouse.getPosition()

  closeButton.onClick = function()
    self.purseDialogOpen = false
    return true
  end

  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, window.width, window.height)
  Panel.draw(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")
  Button.drawButtons({ closeButton }, mouseX, mouseY)
  local maxPurseScrollOffset = PurseView.getMaxScrollOffset(app, contentArea, app.stageState)
  self.purseDialogScrollOffset = math.max(0, math.min(self.purseDialogScrollOffset or 0, maxPurseScrollOffset))

  PurseView.draw(app, contentArea, app.stageState, {
    scrollOffset = self.purseDialogScrollOffset,
  })
  self.purseScrollButtons = PurseView.getScrollButtons(
    contentArea,
    self.purseDialogScrollOffset,
    maxPurseScrollOffset,
    function()
      return self:scrollPurseDialog(app, -1)
    end,
    function()
      return self:scrollPurseDialog(app, 1)
    end
  )
  Button.drawButtons(self.purseScrollButtons, mouseX, mouseY)
end

function StageState:drawTrickCharmDrawer(app)
  if not self.trickCharmDrawerOpen then
    return nil
  end

  local drawer = self:getTrickCharmDrawerLayout(app)
  local contentArea = TrickCharmDrawer.getContentArea(drawer)
  local charms = app.getTrickCharmData and app:getTrickCharmData() or {}
  local mouseX, mouseY = love.mouse.getPosition()
  local maxScrollOffset = TrickCharmDrawer.getMaxScrollOffset(app, contentArea, charms)

  self.trickCharmDrawerRect = drawer
  self.trickCharmDrawerScrollOffset = math.max(0, math.min(self.trickCharmDrawerScrollOffset or 0, maxScrollOffset))

  local hoveredCharm = TrickCharmDrawer.drawDrawer(app, drawer, charms, {
    scrollOffset = self.trickCharmDrawerScrollOffset,
  })

  local closeButton = TrickCharmDrawer.getCloseButton(drawer, function()
    self.trickCharmDrawerOpen = false
    return true
  end)

  Button.drawButtons({ closeButton }, mouseX, mouseY)

  self.trickCharmDrawerScrollButtons = TrickCharmDrawer.getScrollButtons(
    contentArea,
    self.trickCharmDrawerScrollOffset,
    maxScrollOffset,
    function()
      return self:scrollTrickCharmDrawer(app, -1)
    end,
    function()
      return self:scrollTrickCharmDrawer(app, 1)
    end
  )
  Button.drawButtons(self.trickCharmDrawerScrollButtons, mouseX, mouseY)

  return hoveredCharm
end

function StageState:drawLogDialog(app)
  if not self.logDialogOpen then
    return
  end

  local _, _, _, window = getUiRect(app)
  local dialog = self:getHelpDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Flip Log")
  local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
  local mouseX, mouseY = love.mouse.getPosition()

  closeButton.onClick = function()
    self.logDialogOpen = false
    return true
  end

  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, window.width, window.height)
  Panel.draw(dialog.x, dialog.y, dialog.width, dialog.height, "Flip Log")
  Button.drawButtons({ closeButton }, mouseX, mouseY)
  love.graphics.setFont(app.fonts.body)
  local lines = app:getFlipLogLines()
  local maxLogScrollOffset = self:getLogMaxScrollOffset(lines, contentArea)
  self.logDialogScrollOffset = math.max(0, math.min(self.logDialogScrollOffset or 0, maxLogScrollOffset))

  self:drawLogLines(lines, contentArea, self.logDialogScrollOffset)
  self.logScrollButtons = PurseView.getScrollButtons(
    contentArea,
    self.logDialogScrollOffset,
    maxLogScrollOffset,
    function()
      return self:scrollLogDialog(app, -1)
    end,
    function()
      return self:scrollLogDialog(app, 1)
    end
  )
  Button.drawButtons(self.logScrollButtons, mouseX, mouseY)
end

function StageState:drawCoinDetailOverlay(app, coinId, x, y)
  local coin = coinId and Coins.getById(coinId) or nil
  local rect, spacing = getUiRect(app)
  CoinDetailOverlay.draw(app, coin, x, y, {
    compact = true,
    bounds = {
      x = rect.x,
      y = rect.y,
      width = rect.width,
      height = rect.height,
      screenPadding = spacing.screenPadding,
    },
  })
end

function StageState:getHelpDialogCloseButton(dialogX, dialogY, dialogWidth)
  local size = Theme.scale(32)

  return {
    x = dialogX + dialogWidth - Theme.spacing.panelPadding - size,
    y = dialogY + Theme.spacing.panelPadding - Theme.scale(4),
    width = size,
    height = size,
    label = "X",
    variant = "default",
    onClick = function()
      self.helpDialogOpen = false
      return true
    end,
  }
end

function StageState:drawScorePanel(app, area)
  local reveal = self.coinRowReveal

  self.opponentDamageFloatyAnchor = OpponentHpFeedback.drawPanel(
    app.stageState,
    area,
    app.fonts,
    reveal and reveal.opponentHpImpact or nil,
    reveal and reveal.elapsed or nil
  )
end

function StageState:drawStageSummary(app, area)
  local stage = app.stageState
  local luckMeter, luckProgress = self:getDisplayedLuckMeter(app)
  local fatedActive = luckMeter and luckMeter.fatedFlipActive == true
  local stats = {
    { label = "Flips", value = tostring(stage.flipsRemaining), color = Theme.colors.text },
    { label = "Luck", kind = "progress", progress = luckProgress, color = fatedActive and Theme.colors.warning or Theme.colors.text },
  }
  local enemySkill = EnemySkillSystem.getDefinition(stage)
  if enemySkill then
    table.insert(stats, {
      label = "Enemy Trick",
      value = enemySkill.name,
      color = Theme.colors.danger,
    })
  end
  local bossTrick = self:getVisibleBossTrickSnapshot(app)
  if bossTrick and bossTrick.trickId then
    local intentValue = bossTrick.trickId == "centre_stage"
      and string.format("SLOT %s", tostring(bossTrick.spotlightSlotIndex or "?"))
      or bossTrick.trickId == "full_throttle"
        and (bossTrick.leadSlotIndex == 1 and "LEFT →" or "← RIGHT")
      or bossTrick.trickId == "stolen_identity"
        and string.format("S%s → S%s", tostring(bossTrick.victimSlotIndex or "?"), tostring(bossTrick.impostorSlotIndex or "?"))
      or bossTrick.trickId == "three_cups"
        and "HIDDEN ON FLIP"
      or bossTrick.trickId == "nothing_to_declare"
        and string.format("SLOT %s SAFE", tostring(bossTrick.offTheBooksSlotIndex or "?"))
      or bossTrick.trickId == "written_in_stone"
        and table.concat((function()
          local labels = {}
          for _, result in ipairs(bossTrick.writtenSlotResults or {}) do
            table.insert(labels, result == "heads" and "H" or "T")
          end
          return labels
        end)(), " / ")
      or string.upper(bossTrick.favouriteSide or "?")
    table.insert(stats, {
      label = bossTrick.trickName or "Boss Trick",
      value = intentValue,
      color = Theme.colors.danger,
    })
  end

  local statGap = Theme.spacing.itemGap
  local statWidth = math.max(1, math.floor((area.width - (statGap * (#stats - 1))) / #stats))
  local statHeight = math.min(56, math.max(1, area.height))
  local statY = area.y + math.floor(math.max(0, area.height - statHeight) / 2)

  for index, stat in ipairs(stats) do
    local statX = area.x + ((index - 1) * (statWidth + statGap))

    Box.drawFrame(statX, statY, statWidth, statHeight, {
      fill = { Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 0.16 },
      border = Theme.colors.panelBorder,
    })

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(stat.label, statX + 8, statY + 7, math.max(1, statWidth - 16), "center")

    if stat.kind == "progress" then
      local barX = statX + 12
      local barY = statY + 26
      local barWidth = math.max(1, statWidth - 24)
      local barHeight = 14
      local fillWidth = math.floor(barWidth * clamp(stat.progress or 0, 0, 1))

      setColorWithAlpha(Theme.colors.panelBorder, 0.35)
      love.graphics.rectangle("fill", barX, barY, barWidth, barHeight, 7, 7)
      setColorWithAlpha(fatedActive and Theme.colors.warning or Theme.colors.accent, fatedActive and 0.90 or 0.78)
      love.graphics.rectangle("fill", barX, barY, fillWidth, barHeight, 7, 7)
      Theme.applyColor(Theme.colors.panelBorder)
      love.graphics.rectangle("line", barX, barY, barWidth, barHeight, 7, 7)
    else
      love.graphics.setFont(app.fonts.body)
      Theme.applyColor(stat.color)
      love.graphics.printf(stat.value, statX + 8, statY + 24, math.max(1, statWidth - 16), "center")
    end
  end

end

function StageState:drawFatedButtonGlow(app, buttons)
  if not app:isFatedFlipActive() then
    return
  end

  for _, button in ipairs(buttons or {}) do
    if button.glow then
      local pulse = app:getUiPulse(6.0, 0.30, 0.55)
      love.graphics.setColor(Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], pulse)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", button.x - 6, button.y - 6, button.width + 12, button.height + 12, 10, 10)
      love.graphics.setLineWidth(1)
    end
  end
end

function StageState:getVisibleCoinStates(app)
  local batchResult = self.coinRowReveal and self.coinRowReveal.batchResult or app.lastBatchResult
  local coins = {}

  if self.coinRowReveal and batchResult and batchResult.perCoin then
    for _, coinState in ipairs(batchResult.perCoin) do
      local scoreEntry = getPerCoinScoreEntry(batchResult, coinState)
      local baseScoreContribution = scoreEntry and scoreEntry.baseScoreContribution or nil

      table.insert(coins, {
        coinId = coinState.coinId,
        instanceId = coinState.instanceId,
        slotIndex = coinState.slotIndex,
        resolutionIndex = coinState.resolutionIndex,
        result = coinState.result,
        forcedResult = coinState.forcedResult,
        foretold = coinState.foretold == true,
        foretoldResult = coinState.foretoldResult,
        foretoldBy = coinState.foretoldBy,
        smuggled = coinState.smuggled == true,
        smuggledBy = coinState.smuggledBy,
        boardSlotIndex = coinState.boardSlotIndex,
        overloadSlotIndex = coinState.overloadSlotIndex,
        anchorSelectedSlotIndex = coinState.anchorSelectedSlotIndex,
        anchorInstanceId = coinState.anchorInstanceId,
        anchorCoinId = coinState.anchorCoinId,
        anchorOverloadIndex = coinState.anchorOverloadIndex,
        palmed = coinState.palmed == true,
        sleightSaved = coinState.sleightSaved == true,
        forged = coinState.forged == true,
        forgedBy = coinState.forgedBy,
        forgedCoinId = coinState.forgedCoinId,
        chained = coinState.chained == true,
        chainedBy = coinState.chainedBy,
        chainDepth = coinState.chainDepth,
        didMatch = coinState.result == batchResult.call,
        scoreContribution = baseScoreContribution or (coinState.result == batchResult.call and 1 or 0),
      })
    end

    return coins, batchResult.call, batchResult.batchId
  end

  for slotIndex, slot in ipairs(app.stageState and app.stageState.purse and app.stageState.purse.handSlots or {}) do
    local coinId = slot.definitionId
    local definition = coinId and Coins.getById(coinId) or nil

    if coinId and slot.instanceId then
      table.insert(coins, {
        coinId = coinId,
        instanceId = slot.instanceId,
        slotIndex = slotIndex,
        foretold = slot.foretold == true,
        foretoldResult = slot.foretoldResult,
        foretoldBy = slot.foretoldBy,
        smuggled = slot.smuggled == true,
        smuggledBy = slot.smuggledBy,
        boardSlotIndex = slot.boardSlotIndex,
        overloadSlotIndex = slot.overloadSlotIndex,
        anchorSelectedSlotIndex = slot.anchorSelectedSlotIndex,
        anchorInstanceId = slot.anchorInstanceId,
        anchorCoinId = slot.anchorCoinId,
        anchorOverloadIndex = slot.anchorOverloadIndex,
        forged = slot.forged == true,
        forgedBy = slot.forgedBy,
        forgedCoinId = slot.forgedCoinId,
        chained = slot.chained == true,
        chainedBy = slot.chainedBy,
        chainDepth = slot.chainDepth,
        cannotReorder = definition and definition.cannotReorder == true,
      })
    end
  end

  return coins, nil, nil
end

function StageState:getCurrentHandSignature(app)
  local slots = app.stageState and app.stageState.purse and app.stageState.purse.handSlots or {}
  local parts = {}

  for slotIndex, slot in ipairs(slots) do
    if slot.instanceId then
      table.insert(parts, string.format("%d:%s", slotIndex, tostring(slot.instanceId)))
    end
  end

  if #parts == 0 then
    return nil, 0
  end

  return table.concat(parts, "|"), #parts
end

function StageState:startHandThrow(app)
  local signature, coinCount = self:getCurrentHandSignature(app)

  if not signature then
    self.handThrowAnimation = nil
    self.pendingHandThrow = false
    return false
  end

  self.handThrowAnimation = {
    signature = signature,
    elapsed = 0,
    duration = HAND_THROW_DURATION,
    stagger = HAND_THROW_STAGGER,
    coinCount = coinCount,
  }
  self.pendingHandThrow = false
  return true
end

function StageState:queueHandThrow(app)
  local signature = self:getCurrentHandSignature(app)

  if not signature then
    self.pendingHandThrow = false
    return false
  end

  if self.coinRowReveal then
    self.pendingHandThrow = true
    return true
  end

  return self:startHandThrow(app)
end

function StageState:updateHandThrow(app, dt)
  local animation = self.handThrowAnimation

  if animation then
    local signature = self:getCurrentHandSignature(app)

    if signature ~= animation.signature then
      self.handThrowAnimation = nil
    else
      animation.elapsed = animation.elapsed + (dt or 0)

      local totalDuration = (animation.duration or HAND_THROW_DURATION)
        + (math.max(0, (animation.coinCount or 1) - 1) * (animation.stagger or HAND_THROW_STAGGER))
        + HAND_THROW_SETTLE_PADDING

      if animation.elapsed >= totalDuration then
        self.handThrowAnimation = nil
      end
    end
  end

  if self.pendingHandThrow and not self.coinRowReveal then
    self:startHandThrow(app)
  end
end

function StageState:startDealtRefillAnimation(slots, startDelay)
  local instanceOrder = {}
  local instanceSet = {}

  for _, slot in ipairs(slots or {}) do
    if slot.instanceId then
      table.insert(instanceOrder, slot.instanceId)
      instanceSet[slot.instanceId] = #instanceOrder
    end
  end

  if #instanceOrder == 0 then
    self.dealtRefillAnimation = nil
    return false
  end

  self.dealtRefillAnimation = {
    elapsed = -(startDelay or 0),
    duration = DEALT_REFILL_DURATION,
    stagger = DEALT_REFILL_STAGGER,
    coinCount = #instanceOrder,
    instanceSet = instanceSet,
  }
  return true
end

function StageState:updateDealtRefillAnimation(dt)
  local animation = self.dealtRefillAnimation

  if not animation then
    return
  end

  animation.elapsed = animation.elapsed + (dt or 0)

  local totalDuration = (animation.duration or DEALT_REFILL_DURATION)
    + (math.max(0, (animation.coinCount or 1) - 1) * (animation.stagger or DEALT_REFILL_STAGGER))
    + DEALT_REFILL_SETTLE_PADDING

  if animation.elapsed >= totalDuration then
    self.dealtRefillAnimation = nil
  end
end

function StageState:startSelectionTravelAnimation(sourceRect, slotEntry, direction)
  if not sourceRect or not slotEntry or not slotEntry.instanceId or not slotEntry.coinId then
    return false
  end

  self.selectionTravelAnimations = self.selectionTravelAnimations or {}

  table.insert(self.selectionTravelAnimations, {
    elapsed = 0,
    duration = SELECT_COIN_TRAVEL_DURATION,
    direction = direction or "to_slot",
    instanceId = slotEntry.instanceId,
    coinId = slotEntry.coinId,
    startX = sourceRect.coinCenterX or (sourceRect.x + math.floor(sourceRect.width / 2)),
    startY = sourceRect.coinCenterY or (sourceRect.y + math.floor(sourceRect.height / 2)),
    startSize = sourceRect.coinSize or math.max(Theme.scale(24), math.min(sourceRect.width or 0, sourceRect.height or 0)),
  })

  return true
end

function StageState:updateSelectionTravelAnimations(dt)
  local animations = self.selectionTravelAnimations

  if not animations or #animations == 0 then
    return
  end

  for index = #animations, 1, -1 do
    local animation = animations[index]
    animation.elapsed = (animation.elapsed or 0) + (dt or 0)

    if animation.elapsed >= (animation.duration or SELECT_COIN_TRAVEL_DURATION) then
      table.remove(animations, index)
    end
  end
end

function StageState:getSelectionTravelAnimation(instanceId, direction)
  if not instanceId then
    return nil
  end

  for _, animation in ipairs(self.selectionTravelAnimations or {}) do
    if animation.instanceId == instanceId and (not direction or animation.direction == direction) then
      return animation
    end
  end

  return nil
end

function StageState:getDealtRefillCoinVisual(animation, coin, targetX, targetY, coinSize, windowBottom)
  local order = animation and animation.instanceSet and animation.instanceSet[coin and coin.instanceId]

  if not order then
    return targetX, targetY, 1, 1, 0
  end

  local age = (animation.elapsed or 0) - ((order - 1) * (animation.stagger or DEALT_REFILL_STAGGER))
  local duration = math.max(0.001, animation.duration or DEALT_REFILL_DURATION)
  local rawProgress = clamp(age / duration, 0, 1)
  local moveProgress = easeOutCubic(rawProgress)
  local startY = (windowBottom or targetY) + coinSize + math.floor(coinSize * 0.45)
  local slideX = getStableSignedValue(coin.instanceId, "dealt-refill-x") * coinSize * 0.22 * (1 - moveProgress)
  local settleProgress = clamp((rawProgress - 0.72) / 0.28, 0, 1)
  local settleLift = math.sin(settleProgress * math.pi) * coinSize * 0.07 * (1 - settleProgress)
  local alpha = clamp(rawProgress * 3.2, 0, 1)
  local scale = 0.88 + (0.12 * moveProgress)
  local tilt = getStableSignedValue(coin.instanceId, "dealt-refill-tilt") * 0.34 * (1 - moveProgress)

  return math.floor(targetX + slideX), math.floor(lerp(startY, targetY, moveProgress) - settleLift), alpha, scale, tilt
end

function StageState:getDealtRefillMessageAlpha()
  local animation = self.dealtRefillAnimation

  if not animation or (animation.elapsed or 0) < 0 then
    return 0
  end

  local totalDuration = (animation.duration or DEALT_REFILL_DURATION)
    + (math.max(0, (animation.coinCount or 1) - 1) * (animation.stagger or DEALT_REFILL_STAGGER))

  return clamp(math.min((animation.elapsed or 0) / 0.12, (totalDuration - (animation.elapsed or 0)) / 0.18), 0, 1)
end

function StageState:getHandThrowCoinVisual(animation, key, index, targetX, targetY, targetSize, layout)
  if not animation or not layout then
    return targetX, targetY, targetSize, 0, 1, 1, nil
  end

  local age = (animation.elapsed or 0) - ((index - 1) * (animation.stagger or HAND_THROW_STAGGER))
  local duration = math.max(0.001, animation.duration or HAND_THROW_DURATION)
  local rawProgress = clamp(age / duration, 0, 1)
  local moveProgress = easeOutCubic(rawProgress)
  local dealOriginX = layout.startX + math.floor(targetSize * 0.20)
  local dealOriginY = layout.centerLineY + math.floor(targetSize * 0.70)
  local startX = dealOriginX + math.floor(targetSize * 0.08 * getStableSignedValue(key, "throw-start-x"))
  local startY = dealOriginY + math.floor(targetSize * 0.07 * getStableSignedValue(key, "throw-start-y"))
  local directionX = targetX - startX
  local directionY = targetY - startY
  local directionLength = math.max(1, math.sqrt((directionX * directionX) + (directionY * directionY)))
  local outwardX = directionX / directionLength
  local outwardY = directionY / directionLength
  local slideCurve = math.sin(rawProgress * math.pi) * targetSize * 0.08
  local settleProgress = clamp((rawProgress - 0.72) / 0.28, 0, 1)
  local overshoot = math.sin(settleProgress * math.pi) * targetSize * 0.08 * (1 - settleProgress)
  local x = lerp(startX, targetX, moveProgress) + (-outwardY * slideCurve) + (outwardX * overshoot)
  local y = lerp(startY, targetY, moveProgress) + (outwardX * slideCurve * 0.34) + (outwardY * overshoot)
  local spinDirection = getStableSignedValue(key, "throw-spin") >= 0 and 1 or -1
  local impactAge = age - (duration * 0.76)
  local impactPunch = impactAge >= 0 and clamp(1 - (impactAge / 0.16), 0, 1) or 0
  local tilt = spinDirection * (0.44 * (1 - moveProgress)) + (math.sin(rawProgress * math.pi * 2) * 0.05 * (1 - rawProgress))
  local scale = 0.88 + (0.12 * moveProgress) + (impactPunch * 0.05)
  local alpha = clamp(rawProgress * 3.0, 0, 1)
  local labelAlpha = clamp((rawProgress - 0.48) / 0.52, 0, 1)

  return math.floor(x), math.floor(y), math.floor(targetSize * scale), tilt, alpha, labelAlpha, impactAge
end

function StageState:getCoinRowLayout(app, x, y, width, height, coinCount, titleHeight)
  local _, _, componentMetrics = getUiRect(app)
  local count = math.max(1, coinCount or 1)
  local cardGap = Theme.spacing.itemGap
  local maxCardHeight = math.max(Theme.scale(132), height - (titleHeight or 0) - Theme.scale(18))
  local cardHeight = math.min(Theme.scale(230), maxCardHeight)
  local availableCardWidth = math.floor((width - (cardGap * (count - 1))) / count)
  local cardWidth = math.min(componentMetrics.cardMaxWidth, availableCardWidth, math.floor(cardHeight * 0.92))
  cardWidth = math.max(componentMetrics.cardMinWidth, cardWidth)
  cardHeight = math.max(Theme.scale(132), cardHeight)

  local totalWidth = (cardWidth * count) + (cardGap * (count - 1))

  return {
    cardGap = cardGap,
    cardWidth = cardWidth,
    cardHeight = cardHeight,
    totalWidth = totalWidth,
    startX = x + math.floor((width - totalWidth) / 2),
    centerLineY = y + math.floor(height / 2),
  }
end

function StageState:getVisibleEnemySkillSnapshot(app)
  if self:isRevealActive() and app.lastBatchResult and app.lastBatchResult.trace
    and app.lastBatchResult.trace.enemySkillSnapshot then
    return app.lastBatchResult.trace.enemySkillSnapshot
  end
  return EnemySkillSystem.snapshot(app and app.stageState or nil)
end

function StageState:getVisibleBossTrickSnapshot(app)
  if self:isRevealActive() and app.lastBatchResult and app.lastBatchResult.trace
    and app.lastBatchResult.trace.bossTrickSnapshot then
    return app.lastBatchResult.trace.bossTrickSnapshot
  end
  return BossTrickSystem.snapshot(app and app.stageState or nil)
end

function StageState:drawFlipSlotPlaceholders(app, layout, slotCount, occupiedCount)
  local count = math.max(0, slotCount or 0)
  local occupied = math.max(0, occupiedCount or 0)
  local forecast = app and app.stageState and app.stageState.predictionSlot or nil
  local enemySkillSnapshot = self:getVisibleEnemySkillSnapshot(app)
  local bossTrickSnapshot = self:getVisibleBossTrickSnapshot(app)

  for slotIndex = 1, count do
    local cardX = layout.startX + ((slotIndex - 1) * (layout.cardWidth + layout.cardGap))
    local slotHeight = layout.cardHeight
    local slotY = layout.centerLineY - math.floor(slotHeight / 2)
    local filled = slotIndex <= occupied
    local predicted = forecast and forecast.slotIndex == slotIndex
    local slotPressure = EnemySkillSystem.getSnapshotSlotPressure(enemySkillSnapshot, slotIndex)
    local spotlighted = bossTrickSnapshot and bossTrickSnapshot.trickId == "centre_stage"
      and bossTrickSnapshot.spotlightSlotIndex == slotIndex
    local fullThrottle = bossTrickSnapshot and bossTrickSnapshot.trickId == "full_throttle"
    local throttleScaling = fullThrottle
      and BossTrickSystem.getSlotScaling(bossTrickSnapshot, slotIndex, count) or nil
    local throttleLead = fullThrottle and bossTrickSnapshot.leadSlotIndex == slotIndex
    local throttleFinish = fullThrottle and throttleScaling == bossTrickSnapshot.finishingScaling
    local stolenIdentity = bossTrickSnapshot and bossTrickSnapshot.trickId == "stolen_identity"
    local identityVictim = stolenIdentity and bossTrickSnapshot.victimSlotIndex == slotIndex
    local identityImpostor = stolenIdentity and bossTrickSnapshot.impostorSlotIndex == slotIndex
    local taxman = bossTrickSnapshot and bossTrickSnapshot.trickId == "nothing_to_declare"
    local offTheBooks = taxman and bossTrickSnapshot.offTheBooksSlotIndex == slotIndex
    local taxed = taxman and not offTheBooks
    local writtenInStone = bossTrickSnapshot and bossTrickSnapshot.trickId == "written_in_stone"
    local writtenResult = writtenInStone and bossTrickSnapshot.writtenSlotResults
      and bossTrickSnapshot.writtenSlotResults[slotIndex] or nil
    local offTheBooksFill = offTheBooks and {
      lerp(Theme.colors.panel[1], Theme.colors.success[1], 0.18),
      lerp(Theme.colors.panel[2], Theme.colors.success[2], 0.18),
      lerp(Theme.colors.panel[3], Theme.colors.success[3], 0.18),
      1,
    } or nil
    local taxedFill = taxed and {
      lerp(Theme.colors.panel[1], Theme.colors.danger[1], 0.12),
      lerp(Theme.colors.panel[2], Theme.colors.danger[2], 0.12),
      lerp(Theme.colors.panel[3], Theme.colors.danger[3], 0.12),
      1,
    } or nil
    local predictionColor = forecast and Theme.colors.tag[forecast.result] or Theme.colors.accent
    local spotlightColor = Theme.colors.warning
    local writtenColor = Theme.colors.tag[writtenResult] or Theme.colors.warning
    local writtenFill = writtenInStone and {
      lerp(Theme.colors.panel[1], writtenColor[1], filled and 0.16 or 0.22),
      lerp(Theme.colors.panel[2], writtenColor[2], filled and 0.16 or 0.22),
      lerp(Theme.colors.panel[3], writtenColor[3], filled and 0.16 or 0.22),
      1,
    } or nil

    Box.drawFrame(cardX, slotY, layout.cardWidth, slotHeight, {
      fill = slotPressure
        and { Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], filled and 0.10 or 0.16 }
        or writtenInStone
        and writtenFill
        or spotlighted
        and { spotlightColor[1], spotlightColor[2], spotlightColor[3], filled and 0.12 or 0.18 }
        or fullThrottle
        and { spotlightColor[1], spotlightColor[2], spotlightColor[3], filled and 0.08 or 0.13 }
        or stolenIdentity
        and { spotlightColor[1], spotlightColor[2], spotlightColor[3], filled and 0.08 or 0.13 }
        or offTheBooks
        and offTheBooksFill
        or taxed
        and taxedFill
        or predicted
        and { predictionColor[1], predictionColor[2], predictionColor[3], filled and 0.10 or 0.16 }
        or { Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], filled and 0.045 or 0.075 },
      border = slotPressure
        and { Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.92 }
        or writtenInStone
        and { writtenColor[1], writtenColor[2], writtenColor[3], 0.96 }
        or spotlighted
        and { spotlightColor[1], spotlightColor[2], spotlightColor[3], 0.96 }
        or fullThrottle
        and { spotlightColor[1], spotlightColor[2], spotlightColor[3], 0.82 }
        or stolenIdentity
        and { spotlightColor[1], spotlightColor[2], spotlightColor[3], 0.82 }
        or offTheBooks
        and { Theme.colors.success[1], Theme.colors.success[2], Theme.colors.success[3], 0.96 }
        or taxed
        and { Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.82 }
        or predicted
        and { predictionColor[1], predictionColor[2], predictionColor[3], 0.88 }
        or { Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], filled and 0.22 or 0.34 },
    })

    if writtenInStone then
      love.graphics.setFont(app.fonts.small)
      Theme.applyColor(Theme.colors.text)
      love.graphics.printf(
        string.format("WRITTEN %s", string.upper(writtenResult or "?")),
        cardX + Theme.scale(5),
        slotY + Theme.scale(7),
        layout.cardWidth - Theme.scale(10),
        "center"
      )
    end

    if spotlighted then
      love.graphics.setFont(app.fonts.small)
      love.graphics.setColor(spotlightColor)
      love.graphics.printf(
        "SPOTLIGHT",
        cardX + Theme.scale(5),
        slotY + Theme.scale(7),
        layout.cardWidth - Theme.scale(10),
        "center"
      )
    end

    if fullThrottle then
      local throttleLabel = throttleLead and "LEAD 50%"
        or (throttleFinish and "FINISH 150%" or "100%")
      love.graphics.setFont(app.fonts.small)
      love.graphics.setColor(spotlightColor)
      love.graphics.printf(
        throttleLabel,
        cardX + Theme.scale(5),
        slotY + Theme.scale(7),
        layout.cardWidth - Theme.scale(10),
        "center"
      )
    end

    if identityVictim or identityImpostor then
      love.graphics.setFont(app.fonts.small)
      love.graphics.setColor(spotlightColor)
      love.graphics.printf(
        identityVictim and "VICTIM" or "IMPOSTOR",
        cardX + Theme.scale(5),
        slotY + Theme.scale(7),
        layout.cardWidth - Theme.scale(10),
        "center"
      )
    end

    if taxman then
      love.graphics.setFont(app.fonts.small)
      Theme.applyColor(offTheBooks and Theme.colors.success or Theme.colors.danger)
      love.graphics.printf(
        offTheBooks and "OFF THE BOOKS" or string.format(
          "TAX %d%%",
          math.floor((bossTrickSnapshot.taxRate or 0.30) * 100 + 0.5)
        ),
        cardX + Theme.scale(4),
        slotY + slotHeight - app.fonts.small:getHeight() - Theme.scale(6),
        layout.cardWidth - Theme.scale(8),
        "center"
      )
    end

    if predicted and not spotlighted and not fullThrottle and not stolenIdentity and not writtenInStone then
      love.graphics.setFont(app.fonts.small)
      love.graphics.setColor(predictionColor)
      love.graphics.printf(
        string.format("PREDICTED %s", string.upper(forecast.result)),
        cardX + Theme.scale(5),
        slotY + Theme.scale(7),
        layout.cardWidth - Theme.scale(10),
        "center"
      )
    end

    if slotPressure then
      local label = slotPressure.kind == "lifesteal"
        and string.format("LEECH %d%%", math.floor((slotPressure.healMaxHpOnMatch or 0.05) * 100 + 0.5))
        or string.format("TARNISHED %d%%", math.floor((1 - (slotPressure.multiplier or 0.75)) * 100 + 0.5))
      love.graphics.setFont(app.fonts.small)
      Theme.applyColor(Theme.colors.danger)
      love.graphics.printf(
        label,
        cardX + Theme.scale(4),
        slotY + slotHeight - app.fonts.small:getHeight() - Theme.scale(6),
        layout.cardWidth - Theme.scale(8),
        "center"
      )
    end
  end

  love.graphics.setLineWidth(1)
end

function StageState:drawPredictionSlotOverlay(app, layout)
  local forecast = app and app.stageState and app.stageState.predictionSlot or nil
  local bossTrick = self:getVisibleBossTrickSnapshot(app)
  if bossTrick and bossTrick.trickId == "written_in_stone" then
    return
  end
  if not forecast or not layout then
    return
  end

  local cardX = layout.startX + ((forecast.slotIndex - 1) * (layout.cardWidth + layout.cardGap))
  local slotY = layout.centerLineY - math.floor(layout.cardHeight / 2)
  local color = Theme.colors.tag[forecast.result] or Theme.colors.accent
  local badgeHeight = Theme.scale(24)
  local badgeWidth = math.min(layout.cardWidth - Theme.scale(10), Theme.scale(112))
  local badgeX = cardX + math.floor((layout.cardWidth - badgeWidth) / 2)
  local badgeY = slotY + Theme.scale(5)

  Box.drawFrame(badgeX, badgeY, badgeWidth, badgeHeight, {
    fill = { Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.94 },
    border = { color[1], color[2], color[3], 0.95 },
  })
  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(color)
  love.graphics.printf(
    string.format("PREDICTED %s", string.upper(forecast.result)),
    badgeX + Theme.scale(3),
    badgeY + Theme.scale(4),
    badgeWidth - Theme.scale(6),
    "center"
  )
end

function StageState:getDragInsertSlotIndex(pointerX, layout, slotCount)
  if not pointerX or not layout or (slotCount or 0) <= 0 then
    return nil
  end

  local step = layout.cardWidth + layout.cardGap
  local firstCenterX = layout.startX + math.floor(layout.cardWidth / 2)
  local insertSlotIndex = math.floor(((pointerX - firstCenterX) / math.max(1, step)) + 1.5)

  return clamp(insertSlotIndex, 1, slotCount)
end

function StageState:getDragGhostCenter(layout, insertSlotIndex)
  if not layout or not insertSlotIndex then
    return nil, nil
  end

  local step = layout.cardWidth + layout.cardGap
  local firstCenterX = layout.startX + math.floor(layout.cardWidth / 2)
  local centerY = layout.centerLineY

  return firstCenterX + ((insertSlotIndex - 1) * step), centerY
end

function StageState:getDragPushOffset(displayIndex, insertSlotIndex, pushDistance)
  if not insertSlotIndex then
    return 0
  end

  local distance = displayIndex < insertSlotIndex and (insertSlotIndex - displayIndex) or (displayIndex - insertSlotIndex + 1)
  local weight = math.max(0, 1 - ((distance - 1) * 0.45))

  if displayIndex < insertSlotIndex then
    return -math.floor(pushDistance * weight)
  end

  return math.floor(pushDistance * weight)
end

function StageState:getCoinRowVisualKey(coin, index, batchId)
  if coin.instanceId then
    return string.format("hand:%s", tostring(coin.instanceId))
  end

  return string.format("%s:%d:%s", tostring(batchId or "hand"), index, tostring(coin.coinId or "coin"))
end

function StageState:updateCoinRowVisual(key, targetX, targetY, targetSize, animate)
  self.coinRowVisuals = self.coinRowVisuals or {}

  local visual = self.coinRowVisuals[key]

  if not visual or not animate then
    visual = {
      x = targetX,
      y = targetY,
      size = targetSize,
    }
    self.coinRowVisuals[key] = visual
    return visual
  end

  local follow = 1 - math.exp(-(self.lastDt or (1 / 60)) * 14)
  visual.x = visual.x + ((targetX - visual.x) * follow)
  visual.y = visual.y + ((targetY - visual.y) * follow)
  visual.size = visual.size + ((targetSize - visual.size) * follow)

  return visual
end

function StageState:getCoinRowJitter(key, cardWidth, coinSize)
  self.coinRowJitters = self.coinRowJitters or {}

  local jitter = self.coinRowJitters[key]

  if not jitter then
    jitter = {
      x = getStableSignedValue(key, "x"),
      y = getStableSignedValue(key, "y"),
    }
    self.coinRowJitters[key] = jitter
  end

  return math.floor(jitter.x * math.floor(cardWidth * COIN_ROW_JITTER_X_RANGE)),
    math.floor(jitter.y * math.floor(coinSize * COIN_ROW_JITTER_Y_RANGE))
end

function StageState:spawnScoreFloatyOnce(key, label, x, y, options)
  self.spawnedScoreFloatyKeys = self.spawnedScoreFloatyKeys or {}

  if not key or self.spawnedScoreFloatyKeys[key] then
    return false
  end

  self.spawnedScoreFloatyKeys[key] = true
  self.scoreFloaties = self.scoreFloaties or {}
  table.insert(self.scoreFloaties, ScoreFloaty.new(label, x, y, options))
  return true
end

function StageState:spawnCoinScoreFloaty(reveal, coin, index, coinCenterX, coinDrawY)
  local contribution = tonumber(coin.scoreContribution) or 0

  if not reveal or contribution <= 0 then
    return false
  end

  local key = string.format("%s:coin:%s:%s", tostring(reveal.batchId or "batch"), tostring(coin.resolutionIndex or index), tostring(coin.coinId or "coin"))

  return self:spawnScoreFloatyOnce(key, formatSignedScore(contribution), coinCenterX, coinDrawY - Theme.scale(8), {
    color = Theme.colors.success,
    direction = "up",
    fontName = "heading",
  })
end

function StageState:spawnFlipSummaryFloaties(reveal, rowCenterX, rowY)
  if not reveal or reveal.elapsed < (reveal.feedbackTime or ((reveal.revealDuration or 0) + (reveal.coinMotionDuration or 0))) then
    return
  end

  local batchResult = reveal.batchResult
  local scoreBreakdown = batchResult and batchResult.scoreBreakdown or {}
  local baseDisplayed = tonumber(scoreBreakdown.baseScore) or 0
  local totalDamage = tonumber(scoreBreakdown.totalStageScoreDelta) or 0
  local endDelta = totalDamage - baseDisplayed
  local batchKey = tostring(reveal.batchId or "batch")

  if math.abs(endDelta) > 0.001 then
    self:spawnScoreFloatyOnce(string.format("%s:summary", batchKey), formatSignedScore(endDelta), rowCenterX, rowY + Theme.scale(34), {
      color = endDelta >= 0 and Theme.colors.success or Theme.colors.danger,
      direction = endDelta >= 0 and "up" or "down",
      fontName = "title",
      distance = endDelta >= 0 and Theme.scale(64) or Theme.scale(48),
    })
  end

  if totalDamage > 0 and self.opponentDamageFloatyAnchor then
    self:spawnScoreFloatyOnce(string.format("%s:damage", batchKey), formatSignedScore(-totalDamage), self.opponentDamageFloatyAnchor.x, self.opponentDamageFloatyAnchor.y, {
      color = Theme.colors.danger,
      direction = "down",
      fontName = "title",
      distance = Theme.scale(66),
      duration = 1.35,
      popScale = 1.58,
    })
  end
end

function StageState:spawnTaxFloaties(reveal, layout)
  if not reveal or not layout or reveal.elapsed < (reveal.feedbackTime or 0) then return end
  local effect = nil
  for _, candidate in ipairs(reveal.batchResult and reveal.batchResult.trace
    and reveal.batchResult.trace.bossTrickEffects or {}) do
    if candidate.kind == "tax_collected" then effect = candidate end
  end
  if not effect then return end

  local batchKey = tostring(reveal.batchId or "batch")
  for slotIndex = 1, math.max(1, tonumber(effect.slotCount) or 1) do
    local cardX = layout.startX + ((slotIndex - 1) * (layout.cardWidth + layout.cardGap))
    local centerX = cardX + math.floor(layout.cardWidth / 2)
    local slotScore = tonumber((effect.slotScoreTotals or {})[slotIndex]) or 0
    local slotTax = tonumber((effect.slotTaxes or {})[slotIndex]) or 0
    if slotIndex == effect.offTheBooksSlotIndex and slotScore > 0 then
      self:spawnScoreFloatyOnce(
        string.format("%s:tax:protected:%d", batchKey, slotIndex),
        "PROTECTED",
        centerX,
        layout.centerLineY - Theme.scale(76),
        {
          color = Theme.colors.success,
          direction = "up",
          fontName = "small",
          distance = Theme.scale(44),
          duration = 1.15,
          popScale = 1.28,
        }
      )
    elseif slotTax > 0 then
      self:spawnScoreFloatyOnce(
        string.format("%s:tax:slot:%d", batchKey, slotIndex),
        string.format("-%d TAX", slotTax),
        centerX,
        layout.centerLineY + Theme.scale(62),
        {
          color = Theme.colors.danger,
          direction = "down",
          fontName = "heading",
          distance = Theme.scale(46),
          duration = 1.20,
          popScale = 1.38,
        }
      )
    end
  end
end

local function isOverflowCoin(coin)
  return coin and (coin.smuggled == true or coin.overloadSlotIndex ~= nil)
end

local function splitCoinRowCoins(coins)
  local regularCoins = {}
  local overflowCoins = {}

  for _, coin in ipairs(coins or {}) do
    if isOverflowCoin(coin) then
      table.insert(overflowCoins, coin)
    else
      table.insert(regularCoins, coin)
    end
  end

  return regularCoins, overflowCoins
end

function StageState:getOverflowLaneLayout(x, y, width, height, baseLayout, overflowCount)
  local count = math.max(0, overflowCount or 0)
  local coinSize = math.min(Theme.scale(62), math.max(Theme.scale(42), math.floor((baseLayout and baseLayout.cardWidth or Theme.scale(96)) * 0.56)))
  local gap = math.max(Theme.scale(12), Theme.spacing.itemGap)
  local totalWidth = (coinSize * count) + (gap * math.max(0, count - 1))
  local laneWidth = math.max(coinSize, totalWidth)
  local laneX = x + width - laneWidth - Theme.scale(10)
  local laneY = y + math.floor((height - coinSize) / 2)

  return {
    x = laneX,
    y = laneY,
    width = laneWidth,
    height = coinSize,
    coinSize = coinSize,
    gap = gap,
    centerY = laneY + math.floor(coinSize / 2),
  }
end

function StageState:getCoinRowDrawPlacement(coin, displayIndex, layout, overflowLayout)
  if isOverflowCoin(coin) then
    local overflowIndex = coin.overflowDisplayIndex or 1
    local anchorIndex = coin.anchorOverloadIndex or overflowIndex
    local coinSize = overflowLayout.coinSize
    local anchorSlotIndex = coin.anchorSelectedSlotIndex
    local cardX = overflowLayout.x + ((overflowIndex - 1) * (coinSize + overflowLayout.gap))
    local centerY = overflowLayout.centerY

    if anchorSlotIndex then
      local anchorCardX = layout.startX + ((anchorSlotIndex - 1) * (layout.cardWidth + layout.cardGap))
      local anchorCenterX = anchorCardX + math.floor(layout.cardWidth / 2)
      local fanStep = math.max(Theme.scale(14), math.floor(coinSize * 0.38))
      cardX = anchorCenterX + (anchorIndex * fanStep) - math.floor(coinSize / 2)
      centerY = layout.centerLineY + math.min(Theme.scale(18), anchorIndex * Theme.scale(6))
    end

    return {
      layout = {
        cardWidth = coinSize,
        cardGap = overflowLayout.gap,
        cardHeight = coinSize,
        startX = overflowLayout.x,
        centerLineY = centerY,
      },
      cardX = cardX,
      coinSize = coinSize,
      overflow = true,
    }
  end

  local slotIndex = coin.slotIndex or displayIndex
  return {
    layout = layout,
    cardX = layout.startX + ((slotIndex - 1) * (layout.cardWidth + layout.cardGap)),
    coinSize = nil,
    overflow = false,
  }
end

function StageState:drawOverflowLane(app, overflowLayout, overflowCoins)
  if #(overflowCoins or {}) == 0 then
    return
  end

  for index = 1, #overflowCoins do
    local coin = overflowCoins[index]
    local coinSize = overflowLayout.coinSize
    local coinX = overflowLayout.x + ((index - 1) * (coinSize + overflowLayout.gap))
    local centerX = coinX + math.floor(coinSize / 2)
    local centerY = overflowLayout.centerY

    if coin.anchorSelectedSlotIndex then
      local anchorCardX = overflowLayout.baseLayout.startX
        + ((coin.anchorSelectedSlotIndex - 1) * (overflowLayout.baseLayout.cardWidth + overflowLayout.baseLayout.cardGap))
      local anchorCenterX = anchorCardX + math.floor(overflowLayout.baseLayout.cardWidth / 2)
      local anchorIndex = coin.anchorOverloadIndex or index
      local fanStep = math.max(Theme.scale(14), math.floor(coinSize * 0.38))
      centerX = anchorCenterX + (anchorIndex * fanStep)
      centerY = overflowLayout.baseLayout.centerLineY + math.min(Theme.scale(18), anchorIndex * Theme.scale(6))
    end

    local shadowY = centerY + math.floor(coinSize * 0.55)

    setColorWithAlpha(Theme.colors.shadow, 0.24)
    love.graphics.ellipse("fill", centerX, shadowY, math.floor(coinSize * 0.38), Theme.scale(5))
  end
end

function StageState:spawnRevealEventFloaties(reveal, revealPositions, rowCenterX, rowY, anchors)
  if not reveal or not reveal.revealTimeline then
    return
  end

  for eventIndex, event in ipairs(reveal.revealTimeline.eventFeed or {}) do
    if reveal.elapsed >= (event.startTime or 0) then
      local position = revealPositions and revealPositions[event.resolutionIndex] or nil
      local handBorderAnchor = event.kind == "smuggle_coin_from_hand" and anchors and anchors.handBorder or nil
      local label = tostring(event.label or "SPECIAL EVENT")
      local key = string.format("%s:event:%d:%s:%s", tostring(reveal.batchId or "batch"), eventIndex, tostring(event.kind), tostring(event.instanceId or event.coinId))
      local floatyX = handBorderAnchor and handBorderAnchor.x or (position and position.x or rowCenterX)
      local floatyY = handBorderAnchor and handBorderAnchor.y or ((position and position.y or rowY) - Theme.scale(28))

      self:spawnScoreFloatyOnce(key, label, floatyX, floatyY, {
        color = Theme.colors.warning,
        direction = "up",
        fontName = "title",
        distance = Theme.scale(54),
        duration = 1.15,
        popScale = 1.38,
      })
    end
  end
end

function StageState:drawCoinRow(app, x, y, width, height, anchors)
  local coins, _, batchId = self:getVisibleCoinStates(app)
  local regularCoins, overflowCoins = splitCoinRowCoins(coins)
  local maxSlots = self:getMaxFlipSlots(app)
  local titleHeight = 0

  local layout = self:getCoinRowLayout(app, x, y, width, height, maxSlots, titleHeight)
  self.threeCupsRenderContext = {
    layout = layout,
    area = { x = x, y = y, width = width, height = height },
    anchors = anchors,
  }
  local overflowLayout = self:getOverflowLaneLayout(x, y, width, height, layout, #overflowCoins)
  overflowLayout.baseLayout = layout
  self:drawFlipSlotPlaceholders(app, layout, maxSlots, #regularCoins)
  self:drawOverflowLane(app, overflowLayout, overflowCoins)

  if #coins == 0 then
    self.handCardRects = {}
    self.coinSlotTargets = {}
    self.revealCoinPositions = nil
    self.coinRowVisuals = {}
    self.coinRowJitters = {}
    return
  end

  local cardWidth = layout.cardWidth
  local reveal = self.coinRowReveal
  local visibleCount = #coins
  local rowRevealActive = reveal and reveal.batchId == batchId
  local handThrowActive = self.handThrowAnimation ~= nil
  local forgeryAssignmentByInstanceId = {}
  local forgeryAssignments = rowRevealActive and reveal.batchResult and reveal.batchResult.trace
    and reveal.batchResult.trace.forgeryAssignments
    or TrickBoardSystem.getForgeryAssignmentPreview(app.runState, app.stageState)
  for _, assignment in ipairs(forgeryAssignments or {}) do
    if assignment.instanceId then forgeryAssignmentByInstanceId[assignment.instanceId] = assignment end
  end

  if handThrowActive then
    local handSignature = self:getCurrentHandSignature(app)

    if not handSignature or handSignature ~= self.handThrowAnimation.signature then
      self.handThrowAnimation = nil
      handThrowActive = false
    end
  end

  if rowRevealActive then
    visibleCount = 0

    for index = 1, #coins do
      if reveal.elapsed >= getCoinRevealTime(reveal, index) then
        visibleCount = index
      end
    end
  end

  self.handCardRects = {}
  self.coinSlotTargets = {}

  local mouseX, mouseY = love.mouse.getPosition()
  local hoveredCoinId = nil
  local isDraggingHandCoin = self.draggingHandSlotIndex ~= nil
  local handHoverEnabled = not self.purseDialogOpen and not handThrowActive
  local drawCoins = coins
  local dragLayout = nil
  local dragPushDistance = 0
  local dragGhostX = nil
  local dragGhostY = nil
  local dragGhostSize = nil
  local dragTargetX = mouseX and (mouseX - (self.dragGrabOffsetX or 0)) or nil

  if isDraggingHandCoin and not rowRevealActive then
    drawCoins = {}

    for _, coin in ipairs(regularCoins) do
      if (coin.slotIndex or #drawCoins + 1) ~= self.draggingHandSlotIndex then
        table.insert(drawCoins, coin)
      end
    end

    dragLayout = self:getCoinRowLayout(app, x, y, width, height, maxSlots, titleHeight)
    dragPushDistance = math.floor(dragLayout.cardWidth * 0.32)
    self.dragInsertSlotIndex = self:getDragInsertSlotIndex(dragTargetX, dragLayout, #coins)
    dragGhostX, dragGhostY = self:getDragGhostCenter(dragLayout, self.dragInsertSlotIndex)
    dragGhostSize = math.min(Theme.scale(96), math.max(Theme.scale(62), math.floor(dragLayout.cardWidth * 0.54)))
  else
    self.dragInsertSlotIndex = nil
    drawCoins = {}

    for _, coin in ipairs(regularCoins) do
      table.insert(drawCoins, coin)
    end

    local anchored = {}
    local unanchored = {}
    for overflowIndex, coin in ipairs(overflowCoins) do
      coin.overflowDisplayIndex = overflowIndex
      if coin.anchorSelectedSlotIndex then
        anchored[coin.anchorSelectedSlotIndex] = anchored[coin.anchorSelectedSlotIndex] or {}
        table.insert(anchored[coin.anchorSelectedSlotIndex], coin)
      else
        table.insert(unanchored, coin)
      end
    end

    drawCoins = {}
    for _, coin in ipairs(regularCoins) do
      table.insert(drawCoins, coin)
      for _, cargo in ipairs(anchored[coin.slotIndex] or {}) do
        table.insert(drawCoins, cargo)
      end
    end
    for _, coin in ipairs(unanchored) do
      table.insert(drawCoins, coin)
    end
  end

  if dragGhostX and dragGhostY and dragGhostSize then
    setColorWithAlpha(Theme.colors.shadow, 0.28)
    love.graphics.ellipse("fill", dragGhostX, dragGhostY + math.floor(dragGhostSize * 0.58), math.floor(dragGhostSize * 0.48), 9)
    setColorWithAlpha(Theme.colors.accent, 0.13)
    love.graphics.circle("fill", dragGhostX, dragGhostY, math.floor(dragGhostSize * 0.56))
    setColorWithAlpha(Theme.colors.accent, 0.42)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", dragGhostX, dragGhostY, math.floor(dragGhostSize * 0.56))
    love.graphics.setLineWidth(1)
    CoinArt.draw(self.draggingHandCoinId, dragGhostX - math.floor(dragGhostSize / 2), dragGhostY - math.floor(dragGhostSize / 2), dragGhostSize, {
      alpha = 0.18,
      tilt = -0.05,
      glow = false,
      shadow = false,
    })
  end

  local activeVisualKeys = {}
  local revealPositions = {}

  for index, coin in ipairs(drawCoins) do
    local placement = self:getCoinRowDrawPlacement(coin, index, dragLayout or layout, overflowLayout)
    local activeLayout = placement.layout
    local activeCardWidth = activeLayout.cardWidth
    local activeCardHeight = activeLayout.cardHeight
    local activeCenterLineY = activeLayout.centerLineY
    local pushOffset = isDraggingHandCoin and not placement.overflow and self:getDragPushOffset(index, self.dragInsertSlotIndex, dragPushDistance) or 0
    local cardX = placement.cardX + pushOffset
    local resolutionIndex = coin.resolutionIndex or index
    local hasResult = coin.result ~= nil and (not rowRevealActive or reveal.elapsed >= getCoinRevealTime(reveal, index, resolutionIndex))
    local artSide = nil
    local artSelected = false
    local revealAge = rowRevealActive and reveal.elapsed - getCoinRevealTime(reveal, index, resolutionIndex) or nil
    local liftProgress = revealAge and revealAge >= 0 and math.min(1, revealAge / math.max(0.001, reveal.coinMotionDuration or 0.46)) or nil
    local liftOffset, motionTilt, motionScale, motionScaleX, motionScaleY, spinSide, resultSettled = getRetroCoinMotion(liftProgress, activeCardHeight)
    local coinSize = placement.coinSize or math.min(Theme.scale(96), math.max(Theme.scale(62), math.floor(activeCardWidth * 0.54)))
    local coinScored = didCoinScore(coin)
    local coinMotionDuration = reveal and reveal.coinMotionDuration or nil
    local impactAge = revealAge and revealAge >= 0 and revealAge - ((reveal.coinMotionDuration or 0.46) * 0.78) or nil
    local impactPunch = impactAge and impactAge >= 0 and math.max(0, 1 - (impactAge / 0.26)) or 0
    local animatedCoinSize = math.floor(coinSize * (motionScale + (impactPunch * 0.08)))
    local visualKey = self:getCoinRowVisualKey(coin, index, batchId)
    local jitterX, jitterY = self:getCoinRowJitter(visualKey, activeCardWidth, coinSize)
    local _, bounceY = getScoreBounceOffset(
      revealAge,
      coinMotionDuration,
      coinSize,
      activeCardWidth,
      visualKey,
      coinScored,
      coin.scoreContribution,
      coin.chainDepth
    )
    local _, triggeredBounceY = getTriggeredScoreBounceOffset(
      reveal and reveal.revealTimeline or nil,
      resolutionIndex,
      reveal and reveal.elapsed or 0,
      coinMotionDuration,
      coinSize,
      activeCardWidth,
      visualKey,
      coin.scoreContribution,
      coin.chainDepth
    )
    local coinCenterX = cardX + math.floor(activeCardWidth / 2) + jitterX
    local coinCenterY = activeCenterLineY + jitterY + liftOffset + math.min(bounceY, triggeredBounceY)
    local rowVisual = self:updateCoinRowVisual(visualKey, coinCenterX, coinCenterY, animatedCoinSize, not rowRevealActive and not hasResult)
    activeVisualKeys[visualKey] = true

    if coin.instanceId then
      self.coinSlotTargets[coin.instanceId] = {
        x = coinCenterX,
        y = coinCenterY,
        size = animatedCoinSize,
      }
    end

    coinCenterX = rowVisual.x
    coinCenterY = rowVisual.y
    animatedCoinSize = math.floor(rowVisual.size)
    local selectionTravel = self:getSelectionTravelAnimation(coin.instanceId, "to_slot")
    local selectionTravelProgress = selectionTravel and clamp((selectionTravel.elapsed or 0) / math.max(0.001, selectionTravel.duration or SELECT_COIN_TRAVEL_DURATION), 0, 1) or nil
    local selectionTravelAlpha = selectionTravelProgress and clamp((selectionTravelProgress - 0.70) / 0.30, 0, 1) or 1

    local throwTilt = 0
    local throwAlpha = 1
    local labelAlpha = 1
    local throwImpactAge = nil

    if handThrowActive and not hasResult and not rowRevealActive and not isDraggingHandCoin then
      coinCenterX, coinCenterY, animatedCoinSize, throwTilt, throwAlpha, labelAlpha, throwImpactAge = self:getHandThrowCoinVisual(
        self.handThrowAnimation,
        visualKey,
        index,
        coinCenterX,
        coinCenterY,
        animatedCoinSize,
        activeLayout
      )
    end

    local coinDrawX = coinCenterX - math.floor(animatedCoinSize / 2)
    local coinDrawY = coinCenterY - math.floor(animatedCoinSize / 2)
    local labelY = coinDrawY + animatedCoinSize + 8
    local hitWidth = math.max(animatedCoinSize + 34, math.min(activeCardWidth, 112))
    local hitX = coinCenterX - math.floor(hitWidth / 2)
    local hitY = coinDrawY - 14
    local hitHeight = (labelY + 10) - hitY

    local hovered = handHoverEnabled and not isDraggingHandCoin and mouseX and mouseY and mouseX >= hitX and mouseX <= (hitX + hitWidth) and mouseY >= hitY and mouseY <= (hitY + hitHeight)

    if hasResult then
      artSide = resultSettled and coin.result or spinSide
      artSelected = false
    end

    if hovered then
      hoveredCoinId = coin.coinId
    end

    table.insert(self.handCardRects, {
      x = hitX,
      y = hitY,
      width = hitWidth,
      height = hitHeight,
      slotIndex = coin.slotIndex or index,
      coinId = coin.coinId,
      visualKey = visualKey,
      coinCenterX = coinCenterX,
      coinCenterY = coinCenterY,
      coinSize = animatedCoinSize,
      movable = not placement.overflow and not handThrowActive and not rowRevealActive and not hasResult and not coin.cannotReorder and self:isStageActive(app) and not self:isRevealActive(),
    })

    revealPositions[resolutionIndex] = {
      x = coinCenterX,
      y = coinCenterY,
      size = animatedCoinSize,
      didMatch = coin.didMatch,
      hasResult = hasResult,
    }

    local hoverScale = hovered and 1.10 or 1.0
    local visualCoinSize = math.floor(animatedCoinSize * hoverScale)
    local visualCoinDrawX = coinCenterX - math.floor(visualCoinSize / 2)
    local visualCoinDrawY = coinCenterY - math.floor(visualCoinSize / 2)

    if not handThrowActive then
      setColorWithAlpha(Theme.colors.shadow, 0.34 * throwAlpha * selectionTravelAlpha)
      love.graphics.ellipse("fill", coinCenterX, visualCoinDrawY + visualCoinSize + 8, math.floor(visualCoinSize * 0.42), 8)
    end

    if throwImpactAge and throwImpactAge >= 0 and throwImpactAge <= HAND_THROW_IMPACT_DURATION then
      self:drawHandThrowImpact(coinCenterX, coinCenterY, animatedCoinSize, throwImpactAge, throwAlpha)
    end

    CoinArt.draw(coin.coinId, visualCoinDrawX, visualCoinDrawY, visualCoinSize, {
      side = artSide,
      selected = artSelected,
      alpha = (hasResult and 1.0 or 0.78) * throwAlpha * selectionTravelAlpha,
      tilt = throwTilt + (liftProgress and motionTilt * ((index % 2 == 0) and 1 or -1) or (hasResult and ((index % 2 == 0) and 0.10 or -0.10) or 0)),
      scaleX = liftProgress and motionScaleX or 1,
      scaleY = liftProgress and motionScaleY or 1,
      glow = false,
      shadow = false,
    })

    local forgeryAssignment = coin.instanceId and forgeryAssignmentByInstanceId[coin.instanceId] or nil
    if forgeryAssignment and forgeryAssignment.actingFamily then
      local badgeText = string.format("← %s", string.upper(forgeryAssignment.actingFamily))
      local badgeWidth = math.min(activeCardWidth - Theme.scale(8), Theme.scale(96))
      local badgeHeight = Theme.scale(18)
      local badgeX = coinCenterX - math.floor(badgeWidth / 2)
      local badgeY = visualCoinDrawY - Theme.scale(21)
      Box.drawFrame(badgeX, badgeY, badgeWidth, badgeHeight, {
        fill = { Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.94 * throwAlpha },
        border = { Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.92 * throwAlpha },
      })
      love.graphics.setFont(app.fonts.small)
      setColorWithAlpha(Theme.colors.warning, throwAlpha * selectionTravelAlpha)
      love.graphics.printf(badgeText, badgeX + Theme.scale(2), badgeY + Theme.scale(2), badgeWidth - Theme.scale(4), "center")
    end

    if hasResult and impactAge and impactAge >= 0 and impactAge <= 0.60 then
      self:drawRevealImpact(coinDrawX, coinDrawY, animatedCoinSize, animatedCoinSize, impactAge, coin.didMatch)
    end

    if rowRevealActive and hasResult then
      TrickCallout.drawStack(
        reveal.trickCallouts and reveal.trickCallouts[coin.resolutionIndex or index],
        app.fonts,
        coinCenterX,
        coinDrawY - Theme.scale(28),
        {
          style = self:getTrickCalloutStyle(app),
          revealAge = revealAge,
          maxWidth = activeCardWidth + Theme.scale(64),
          coinSize = animatedCoinSize,
          coinMotionDuration = reveal.coinMotionDuration,
          startDelay = coinScored and getScoreBounceApexDelay(reveal.coinMotionDuration) or nil,
        }
      )
    end

    if hasResult then
      if resultSettled then
        if rowRevealActive then
          self:spawnCoinScoreFloaty(reveal, coin, index, coinCenterX, coinDrawY)
        end

      end
    end

  end

  if rowRevealActive then
    self:spawnRevealEventFloaties(reveal, revealPositions, x + math.floor(width / 2), y, anchors)
    RevealEffects.drawLinks(reveal.revealTimeline, reveal.elapsed, revealPositions, app.fonts)
    self:spawnTaxFloaties(reveal, layout)
  end

  if rowRevealActive then
    self:spawnFlipSummaryFloaties(reveal, x + math.floor(width / 2), y)
  end

  self.revealCoinPositions = rowRevealActive and revealPositions or nil

  for key in pairs(self.coinRowVisuals or {}) do
    if not activeVisualKeys[key] and key ~= self.draggingHandVisualKey then
      self.coinRowVisuals[key] = nil
    end
  end

  for key in pairs(self.coinRowJitters or {}) do
    if not activeVisualKeys[key] and key ~= self.draggingHandVisualKey then
      self.coinRowJitters[key] = nil
    end
  end

  self:drawPredictionSlotOverlay(app, layout)

  return hoveredCoinId
end

function StageState:drawDraggedHandCoin()
  if not self.draggingHandCoinId then
    return
  end

  local mouseX, mouseY = love.mouse.getPosition()
  local baseSize = self.dragBaseSize or Theme.scale(64)
  local targetDraggedSize = baseSize * 1.15
  local lift = easeOutCubic(clamp(self.dragLiftProgress or 1, 0, 1))
  local draggedSize = math.floor(baseSize + ((targetDraggedSize - baseSize) * lift))
  local drawCenterX = self.dragVisualX or (mouseX and (mouseX - (self.dragGrabOffsetX or 0))) or mouseX
  local drawCenterY = self.dragVisualY or (mouseY and (mouseY - (self.dragGrabOffsetY or 0))) or mouseY

  if not drawCenterX or not drawCenterY then
    return
  end

  setColorWithAlpha(Theme.colors.shadow, 0.20 + (0.12 * lift))
  love.graphics.ellipse("fill", drawCenterX, drawCenterY + math.floor(draggedSize * 0.55), math.floor(draggedSize * 0.46), 9)
  CoinArt.draw(self.draggingHandCoinId, drawCenterX - math.floor(draggedSize / 2), drawCenterY - math.floor(draggedSize / 2), draggedSize, {
    selected = true,
    alpha = 0.78 + (0.14 * lift),
    tilt = self.dragTilt or 0,
    glow = false,
    shadow = false,
  })
end

local function drawTravelingCoin(coinId, source, target, progress, options)
  if not coinId or not source or not target then
    return false
  end

  options = options or {}
  local clampedProgress = clamp(progress or 0, 0, 1)
  local eased = easeOutCubic(clampedProgress)
  local startX = source.x or target.x
  local startY = source.y or target.y
  local startSize = source.size or target.size or Theme.scale(58)
  local targetSize = target.size or startSize
  local arcHeight = math.max(Theme.scale(22), math.abs((target.y or startY) - startY) * 0.18)
  local landingCurveScale = clampedProgress > 0.60 and lerp(1, 0.60, (clampedProgress - 0.60) / 0.40) or 1
  local arc = math.sin(clampedProgress * math.pi) * arcHeight * landingCurveScale
  local x = lerp(startX, target.x or startX, eased)
  local y = lerp(startY, target.y or startY, eased) - arc
  local size = math.floor(lerp(startSize, targetSize, eased) * (1 + (math.sin(clampedProgress * math.pi) * 0.10)))
  local alpha = options.alpha or 0.94
  local shadowAlpha = (options.shadowAlpha or 0.18) + (0.12 * clampedProgress)

  setColorWithAlpha(Theme.colors.shadow, shadowAlpha * alpha)
  love.graphics.ellipse("fill", x, y + math.floor(size * 0.55), math.floor(size * 0.42), Theme.scale(7))
  CoinArt.draw(coinId, x - math.floor(size / 2), y - math.floor(size / 2), size, {
    selected = options.selected == true,
    alpha = alpha,
    tilt = math.sin(clampedProgress * math.pi * 2) * 0.18,
    glow = false,
    shadow = false,
  })

  return true
end

function StageState:getSleightHandAnchor(anchors, fallbackSize)
  local anchor = anchors and (anchors.handCenter or anchors.handBorder) or nil

  if not anchor then
    return nil
  end

  return {
    x = anchor.x,
    y = anchor.y,
    size = anchor.size or fallbackSize or Theme.scale(58),
  }
end

function StageState:getSleightTravelEndpoint(travel, endpoint, positions, anchors)
  local kind = endpoint == "source" and travel.sourceKind or travel.targetKind

  if kind == "hand" then
    return self:getSleightHandAnchor(anchors, Theme.scale(58))
  end

  local resolutionIndex = endpoint == "source" and travel.sourceResolutionIndex or travel.targetResolutionIndex
  local position = positions and positions[resolutionIndex] or nil

  if not position then
    return nil
  end

  return {
    x = position.x,
    y = position.y,
    size = position.size,
  }
end

function StageState:drawSleightTravelAnimations(anchors)
  local reveal = self.coinRowReveal
  local timeline = reveal and reveal.revealTimeline or nil
  local activeTravels = RevealTimeline.getActiveSleightTravels(timeline, reveal and reveal.elapsed or 0)

  if #activeTravels == 0 then
    return
  end

  local positions = self.revealCoinPositions or {}

  for _, travel in ipairs(activeTravels) do
    drawTravelingCoin(
      travel.coinId,
      self:getSleightTravelEndpoint(travel, "source", positions, anchors),
      self:getSleightTravelEndpoint(travel, "target", positions, anchors),
      travel.progress,
      {
        selected = travel.targetKind ~= "hand",
        alpha = 0.94,
      }
    )
  end
end

function StageState:drawSelectionTravelAnimations()
  for _, animation in ipairs(self.selectionTravelAnimations or {}) do
    local target = self.coinSlotTargets and self.coinSlotTargets[animation.instanceId] or nil

    if animation.direction == "to_hand" then
      local rect = self:getDealtCardByInstanceId(animation.instanceId)
      target = rect and {
        x = rect.coinCenterX,
        y = rect.coinCenterY,
        size = rect.coinSize,
      } or nil
    end

    if target then
      drawTravelingCoin(animation.coinId, {
        x = animation.startX,
        y = animation.startY,
        size = animation.startSize,
      }, target, clamp((animation.elapsed or 0) / math.max(0.001, animation.duration or SELECT_COIN_TRAVEL_DURATION), 0, 1), {
        selected = animation.direction ~= "to_hand",
      })
    end
  end
end

function StageState:drawDealtCoinWindow(app, x, y, width, height)
  local coins = self:getUnselectedDealtCoinStates(app)
  local slots = app.stageState and app.stageState.purse and app.stageState.purse.dealtHandSlots or {}
  local selectedCount = self:getSelectedFlipSlotCount(app)
  local maxSlots = self:getMaxFlipSlots(app)
  local mouseX, mouseY = love.mouse.getPosition()
  local titleHeight = math.min(Theme.scale(20), math.max(Theme.scale(14), math.floor(height * 0.34)))
  local hoveredCoinId = nil
  local groups = getDealtCoinGroups(coins, slots, app.runState)

  self.dealtCardRects = {}

  Box.drawFrame(x, y, width, height, {
    fill = Theme.colors.panel,
    border = { Theme.colors.panelBorder[1], Theme.colors.panelBorder[2], Theme.colors.panelBorder[3], 0.88 },
  })

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.accent)
  love.graphics.printf("Hand", x + 10, y + 4, math.max(1, width - 20), "left")
  Theme.applyColor(Theme.colors.mutedText)
  local replacements = app.stageState and app.stageState.trickBoard and app.stageState.trickBoard.replacementsRemaining or 0
  love.graphics.printf(string.format("%d/%d slots  •  %d replacements", selectedCount, maxSlots, replacements), x + 10, y + 4, math.max(1, width - 20), "right")

  local contentY = y + titleHeight
  local contentHeight = math.max(1, height - titleHeight - 4)

  if #groups == 0 then
    local message = selectedCount > 0 and "Selected coins moved to Flip." or "No coins in hand."
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(message, x + 8, contentY + math.floor(contentHeight / 2) - 7, math.max(1, width - 16), "center")
    return nil
  end

  local groupCount = math.max(1, #groups)
  local gap = math.max(Theme.scale(8), math.floor(Theme.spacing.itemGap * 0.7))
  local sidePadding = Theme.scale(12)
  local availableWidth = math.max(1, width - (sidePadding * 2))
  local groupWidth = math.floor((availableWidth - (gap * (groupCount - 1))) / groupCount)
  groupWidth = math.max(Theme.scale(38), groupWidth)
  local totalWidth = (groupWidth * groupCount) + (gap * (groupCount - 1))
  local startX = x + math.floor((width - totalWidth) / 2)
  local labelHeight = app.fonts.small:getHeight()
  local pileHeight = math.max(Theme.scale(30), contentHeight - labelHeight - Theme.scale(6))
  local maxCoinSize = math.max(Theme.scale(26), math.min(Theme.scale(72), groupWidth - Theme.scale(8), pileHeight - Theme.scale(4)))
  local minCoinSize = math.min(maxCoinSize, Theme.scale(34))
  local coinSize = clamp(math.floor(math.min(groupWidth * 0.72, pileHeight * 0.86)), minCoinSize, maxCoinSize)
  local canSelectMore = selectedCount < maxSlots
  local restockAlpha = self:getDealtRefillMessageAlpha()

  if restockAlpha > 0 then
    love.graphics.setFont(app.fonts.heading)
    setColorWithAlpha(Theme.colors.warning, restockAlpha)
    love.graphics.printf("RESTOCK", x + Theme.scale(8), contentY + Theme.scale(2), math.max(1, width - Theme.scale(16)), "center")
  end

  for groupIndex, group in ipairs(groups) do
    local cellX = startX + ((groupIndex - 1) * (groupWidth + gap))
    local pileCenterX = cellX + math.floor(groupWidth / 2)
    local pileCenterY = contentY + math.floor(pileHeight * 0.48)
    local labelY = contentY + pileHeight + Theme.scale(2)

    for coinIndex, coin in ipairs(group.coins) do
      local key = coin.instanceId or string.format("%s:%d", tostring(coin.coinId), coin.dealtIndex or coinIndex)
      local stackOffset = coinIndex - 1
      local maxOffsetX = math.min(groupWidth * DEALT_PILE_JITTER_X_RANGE, math.max(0, (groupWidth - coinSize) / 2))
      local maxOffsetY = math.min(coinSize * DEALT_PILE_JITTER_Y_RANGE, math.max(0, (pileHeight - coinSize) / 2))
      local offsetX = (getStableSignedValue(key, "hand-pile-x") * maxOffsetX) + (stackOffset * math.min(Theme.scale(5), coinSize * 0.08))
      local offsetY = (getStableSignedValue(key, "hand-pile-y") * maxOffsetY) - (stackOffset * math.min(Theme.scale(3), coinSize * 0.05))
      local tilt = getStableSignedValue(key, "hand-pile-tilt") * 0.14
      local coinX = math.floor(pileCenterX - (coinSize / 2) + offsetX)
      local coinY = math.floor(pileCenterY - (coinSize / 2) + offsetY)
      local refillAlpha = 1
      local refillScale = 1
      local refillTilt = 0

      coinX, coinY, refillAlpha, refillScale, refillTilt = self:getDealtRefillCoinVisual(
        self.dealtRefillAnimation,
        coin,
        coinX,
        coinY,
        coinSize,
        y + height
      )

      local drawCoinSize = math.floor(coinSize * refillScale)
      coinX = coinX + math.floor((coinSize - drawCoinSize) / 2)
      coinY = coinY + math.floor((coinSize - drawCoinSize) / 2)
      local hitPadding = Theme.scale(5)
      local hitRect = {
        x = coinX - hitPadding,
        y = coinY - hitPadding,
        width = drawCoinSize + (hitPadding * 2),
        height = drawCoinSize + (hitPadding * 2),
        dealtIndex = coin.dealtIndex,
        instanceId = coin.instanceId,
        coinId = coin.coinId,
        coinCenterX = coinX + math.floor(drawCoinSize / 2),
        coinCenterY = coinY + math.floor(drawCoinSize / 2),
        coinSize = drawCoinSize,
        selectable = canSelectMore,
      }
      local hovered = mouseX and mouseY and Button.containsPoint(hitRect, mouseX, mouseY)

      table.insert(self.dealtCardRects, hitRect)

      if hovered then
        hoveredCoinId = coin.coinId
      end

      local hoverScale = hovered and 1.10 or 1.0
      local visualCoinSize = math.floor(drawCoinSize * hoverScale)
      local visualCoinX = coinX - math.floor((visualCoinSize - drawCoinSize) / 2)
      local visualCoinY = coinY - math.floor((visualCoinSize - drawCoinSize) / 2)
      local selectionTravel = self:getSelectionTravelAnimation(coin.instanceId, "to_hand")
      local selectionTravelProgress = selectionTravel and clamp((selectionTravel.elapsed or 0) / math.max(0.001, selectionTravel.duration or SELECT_COIN_TRAVEL_DURATION), 0, 1) or nil
      local selectionTravelAlpha = selectionTravelProgress and clamp((selectionTravelProgress - 0.70) / 0.30, 0, 1) or 1

      setColorWithAlpha(Theme.colors.shadow, 0.24 * refillAlpha * selectionTravelAlpha)
      love.graphics.ellipse("fill", coinX + math.floor(drawCoinSize / 2), visualCoinY + visualCoinSize + Theme.scale(5), math.floor(visualCoinSize * 0.38), Theme.scale(5))
      CoinArt.draw(coin.coinId, visualCoinX, visualCoinY, visualCoinSize, {
        alpha = (canSelectMore and 0.90 or 0.42) * refillAlpha * selectionTravelAlpha,
        glow = false,
        shadow = false,
        tilt = tilt + refillTilt,
      })

      if coin.foretold and coin.foretoldResult then
        local badgeSize = math.max(Theme.scale(14), math.floor(visualCoinSize * 0.34))
        local badgeX = visualCoinX + visualCoinSize - math.floor(badgeSize * 0.75)
        local badgeY = visualCoinY - math.floor(badgeSize * 0.15)

        setColorWithAlpha(Theme.colors.warning, 0.88 * refillAlpha)
        love.graphics.circle("fill", badgeX, badgeY, math.floor(badgeSize / 2))
        setColorWithAlpha(Theme.colors.background, refillAlpha)
        love.graphics.printf(string.upper(string.sub(coin.foretoldResult, 1, 1)), badgeX - math.floor(badgeSize / 2), badgeY - math.floor(app.fonts.small:getHeight() / 2), badgeSize, "center")
      end
    end

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    local label = #group.coins > 1 and string.format("%s ×%d", group.name, #group.coins) or group.name
    love.graphics.printf(label, cellX, labelY, groupWidth, "center")
  end

  return hoveredCoinId
end

function StageState:drawTrickCharmStrip(app, area)
  local charms = app.getTrickCharmData and app:getTrickCharmData() or {}
  local preview = TrickBoardSystem.getActivationPreview(app.runState, app.stageState)
  local revealSnapshot = self:isRevealActive()
    and app.lastBatchResult and app.lastBatchResult.trace
    and app.lastBatchResult.trace.trickBoardSnapshot or nil
  for index, charm in ipairs(charms) do
    local activation = preview[index] or {}
    if revealSnapshot and revealSnapshot[index] then
      activation = {
        activationCount = activation.activationCount,
        forgedActivationCount = activation.forgedActivationCount,
        pressure = revealSnapshot[index].pressure,
        effectiveness = revealSnapshot[index].pressure
          and revealSnapshot[index].pressure.kind == "blocked" and 0
          or (revealSnapshot[index].pressure
            and revealSnapshot[index].pressure.kind == "weakened"
            and (revealSnapshot[index].pressure.multiplier or 0.5) or 1),
      }
    end
    charm.activationCount = activation.activationCount or 0
    charm.forgedActivationCount = activation.forgedActivationCount or 0
    charm.pressure = activation.pressure
    charm.effectiveness = activation.effectiveness or 1
    if charm.forgedActivationCount > 0 then
      charm.description = string.format("FORGED +%d activation%s. %s",
        charm.forgedActivationCount,
        charm.forgedActivationCount == 1 and "" or "s",
        charm.description or "")
    end
    if activation.pressure then
      local label = activation.pressure.kind == "blocked" and "BLOCKED: does not activate."
        or (activation.pressure.kind == "weakened"
          and string.format("WEAKENED: effects resolve at %d%%.", math.floor((activation.pressure.multiplier or 0.75) * 100 + 0.5))
          or (activation.pressure.kind == "poisoned"
            and string.format("POISONED: lose %d%% of this Flip's Score per activation, up to %d%%.",
              math.floor((activation.pressure.scoreLossPerActivation or 0.10) * 100 + 0.5),
              math.floor((activation.pressure.scoreLossPerActivation or 0.10)
                * (activation.pressure.maxStacks or 3) * 100 + 0.5))
            or "JAMMED: only its first activation resolves."))
      charm.description = label .. " " .. (charm.description or "")
    end
  end
  local result = TrickCharmDrawer.drawTrigger(app, area, charms, {
    open = self.trickCharmDrawerOpen,
  })

  self.trickCharmDrawerTriggerRect = result.triggerRect

  return result.hoveredCharm
end

function StageState:drawMatchParticles(cardX, cardY, cardWidth, cardHeight, age)
  local alpha = math.max(0, 1 - (age / 0.60))
  local centerX = cardX + math.floor(cardWidth / 2)
  local centerY = cardY + math.floor(cardHeight / 2)
  local particles = {
    { -44, -28 },
    { -28, 34 },
    { 36, -32 },
    { 48, 22 },
    { -8, -52 },
    { 10, 48 },
    { -58, 2 },
    { 58, -4 },
    { -20, -44 },
    { 26, 42 },
    { 0, -66 },
    { 0, 62 },
    { -70, -20 },
    { 72, 24 },
  }

  Theme.applyColor({ Theme.colors.success[1], Theme.colors.success[2], Theme.colors.success[3], alpha })

  for index, particle in ipairs(particles) do
    local drift = math.floor(age * 82)
    local sparkleSize = index % 2 == 0 and 6 or 4
    local px = centerX + particle[1] + (particle[1] >= 0 and drift or -drift)
    local py = centerY + particle[2] + (particle[2] >= 0 and drift or -drift)

    love.graphics.rectangle("fill", px, py, sparkleSize, sparkleSize)
    love.graphics.rectangle("fill", px - 3, py + math.floor(sparkleSize / 2), sparkleSize + 6, 2)
    love.graphics.rectangle("fill", px + math.floor(sparkleSize / 2), py - 3, 2, sparkleSize + 6)
  end
end

function StageState:drawMissParticles(cardX, cardY, cardWidth, cardHeight, age)
  local alpha = math.max(0, 1 - (age / 0.60))
  local centerX = cardX + math.floor(cardWidth / 2)
  local centerY = cardY + math.floor(cardHeight / 2)
  local particles = {
    { -34, -18 },
    { -14, 26 },
    { 24, -24 },
    { 42, 16 },
    { -44, 18 },
    { 6, -42 },
    { 48, -6 },
    { -52, -8 },
    { 18, 34 },
    { -70, 10 },
    { 68, 8 },
    { -8, -58 },
    { 10, 54 },
  }

  Theme.applyColor({ Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], alpha })

  for index, particle in ipairs(particles) do
    local fall = math.floor(age * 96)
    local spread = math.floor(age * 36)
    local px = centerX + particle[1]
    local py = centerY + particle[2] + fall

    love.graphics.rectangle("fill", px + (particle[1] >= 0 and spread or -spread), py, index % 2 == 0 and 12 or 8, 4)
    love.graphics.rectangle("fill", px + 2, py + 4, 4, 4)
  end
end

function StageState:drawHandThrowImpact(centerX, centerY, coinSize, age, alphaMultiplier)
  local progress = clamp(age / HAND_THROW_IMPACT_DURATION, 0, 1)
  local alpha = 0.72 * (1 - progress) * (alphaMultiplier or 1)
  local radius = math.floor(coinSize * (0.56 + (progress * 0.38)))

  if alpha <= 0 then
    return
  end

  setColorWithAlpha(Theme.colors.accent, alpha * 0.16)
  love.graphics.circle("fill", centerX, centerY, radius)
  setColorWithAlpha(Theme.colors.accent, alpha)
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", centerX, centerY, radius)
  love.graphics.setLineWidth(1)
end

function StageState:drawRevealImpact(cardX, cardY, cardWidth, cardHeight, age, didMatch)
  if didMatch then
    self:drawMatchParticles(cardX, cardY, cardWidth, cardHeight, age)
  else
    self:drawMissParticles(cardX, cardY, cardWidth, cardHeight, age)
  end
end

function StageState:getHandCardAtPoint(x, y)
  for _, rect in ipairs(self.handCardRects or {}) do
    if x >= rect.x and x <= (rect.x + rect.width) and y >= rect.y and y <= (rect.y + rect.height) then
      return rect
    end
  end

  return nil
end

function StageState:getHandCardBySlotIndex(slotIndex)
  for _, rect in ipairs(self.handCardRects or {}) do
    if rect.slotIndex == slotIndex then
      return rect
    end
  end

  return nil
end

function StageState:getDealtCardAtPoint(x, y)
  for index = #(self.dealtCardRects or {}), 1, -1 do
    local rect = self.dealtCardRects[index]
    if x >= rect.x and x <= (rect.x + rect.width) and y >= rect.y and y <= (rect.y + rect.height) then
      return rect
    end
  end

  return nil
end

function StageState:getDealtCardByDealtIndex(dealtIndex)
  for _, rect in ipairs(self.dealtCardRects or {}) do
    if rect.dealtIndex == dealtIndex then
      return rect
    end
  end

  return nil
end

function StageState:getDealtCardByInstanceId(instanceId)
  for _, rect in ipairs(self.dealtCardRects or {}) do
    if rect.instanceId == instanceId then
      return rect
    end
  end

  return nil
end

function StageState:enter(app, payload, previousName)
  app:ensureCurrentStage()
  app.selectedCall = nil
  app:ensureHandDrawn()
  self.reveal = nil
  self.coinRowReveal = nil
  self.luckMeterAnimation = nil
  self.handThrowAnimation = nil
  self.pendingHandThrow = false
  self.dealtRefillAnimation = nil
  self.selectionTravelAnimations = {}
  self.dealtCardRects = {}
  self.coinSlotTargets = {}
  self.revealCoinPositions = nil
  self.threeCupsRenderContext = nil
  self.coinRowVisuals = {}
  self.coinRowJitters = {}
  self.scoreFloaties = {}
  self.spawnedScoreFloatyKeys = {}
  self.opponentDamageFloatyAnchor = nil
  self.lastDt = 1 / 60
  self.draggingHandSlotIndex = nil
  self.draggingHandCoinId = nil
  self.draggingHandVisualKey = nil
  self.dragInsertSlotIndex = nil
  self.dragPointerX = nil
  self.dragPointerY = nil
  self.dragGrabOffsetX = 0
  self.dragGrabOffsetY = 0
  self.dragVisualX = nil
  self.dragVisualY = nil
  self.dragBaseSize = nil
  self.dragLiftProgress = 0
  self.dragTilt = 0
  self.helpDialogOpen = false
  self.purseDialogOpen = false
  self.purseDialogScrollOffset = 0
  self.trickCharmDrawerOpen = false
  self.trickCharmDrawerScrollOffset = 0
  self.trickCharmDrawerScrollButtons = {}
  self.trickCharmDrawerTriggerRect = nil
  self.trickCharmDrawerRect = nil
  self.logDialogOpen = false
  self.logDialogScrollOffset = 0

  if previousName ~= "pause" and self:getSelectedFlipSlotCount(app) > 0 then
    self:startHandThrow(app)
  end

  if app.stageState and app.stageState.stageStatus ~= "active" then
    self.statusMessage = string.format("Stage %s.", app.stageState.stageStatus)
  elseif app:isFatedFlipActive() then
    self.statusMessage = "TWIST OF FATE ready: fill Flip and pick a call. All coins will land on it."
  else
    self.statusMessage = self:getSelectionStatusMessage(app)
  end
end

function StageState:updateDragVisual(dt)
  if not self.draggingHandSlotIndex then
    return
  end

  self.dragLiftProgress = math.min(1, (self.dragLiftProgress or 0) + ((dt or 0) / 0.16))

  local mouseX, mouseY = love.mouse.getPosition()
  self.dragPointerX = mouseX
  self.dragPointerY = mouseY

  local targetX = mouseX - (self.dragGrabOffsetX or 0)
  local targetY = mouseY - (self.dragGrabOffsetY or 0)

  self.dragVisualX = self.dragVisualX or targetX
  self.dragVisualY = self.dragVisualY or targetY

  local pullX = targetX - self.dragVisualX
  local pullY = targetY - self.dragVisualY
  local follow = 1 - math.exp(-(dt or 0) * 18)

  self.dragVisualX = self.dragVisualX + (pullX * follow)
  self.dragVisualY = self.dragVisualY + (pullY * follow)

  local targetTilt = clamp(pullX * 0.006, -0.30, 0.30)
  local tiltFollow = math.min(1, (dt or 0) * 16)
  self.dragTilt = (self.dragTilt or 0) + ((targetTilt - (self.dragTilt or 0)) * tiltFollow)
end

function StageState:update(app, dt)
  self.lastDt = dt or self.lastDt or (1 / 60)
  self:updateDragVisual(dt)
  self.scoreFloaties = ScoreFloaty.updateAll(self.scoreFloaties, dt)

  if self.coinRowReveal then
    local reveal = self.coinRowReveal
    reveal.elapsed = reveal.elapsed + dt

    while reveal.nextSoundIndex and reveal.nextSoundIndex <= (reveal.coinCount or 0) and reveal.elapsed >= getCoinRevealTime(reveal, reveal.nextSoundIndex) do
      local coinState = reveal.batchResult and reveal.batchResult.perCoin and reveal.batchResult.perCoin[reveal.nextSoundIndex]

      if coinState and app.audioSystem then
        app.audioSystem:playCue(coinState.result == reveal.batchResult.call and "coin_reveal_match" or "coin_reveal_miss")
      end

      reveal.nextSoundIndex = reveal.nextSoundIndex + 1
    end

    if not reveal.feedbackPlayed and reveal.elapsed >= (reveal.feedbackTime or (reveal.revealDuration + (reveal.coinMotionDuration or 0))) then
      local feedbackPlayed = playCoinRowFeedback(app, reveal)

      if feedbackPlayed and reveal.opponentHpImpact and app.audioSystem then
        app.audioSystem:playCue("opponent_hit")
      end
    end

    if reveal.elapsed >= reveal.displayDuration then
      self.coinRowReveal = nil
      self.luckMeterAnimation = nil
    end
  end

  self:updateHandThrow(app, dt)
  self:updateDealtRefillAnimation(dt)
  self:updateSelectionTravelAnimations(dt)

  if not self:isRevealActive() then
    if not self.coinRowReveal then
      routeIfStageComplete(app)
    end

    return
  end

  self.reveal.elapsed = self.reveal.elapsed + dt

  if self.reveal.elapsed >= self.reveal.finishDuration and not self.coinRowReveal then
    self:completeReveal(app)
  end
end

function StageState:keypressed(app, key)
  if self.logDialogOpen then
    if key == "escape" or key == "return" or key == "kpenter" or key == "l" then
      self.logDialogOpen = false
    elseif key == "up" then
      self:scrollLogDialog(app, -1)
    elseif key == "down" then
      self:scrollLogDialog(app, 1)
    end

    return
  end

  if self.purseDialogOpen then
    if key == "escape" or key == "return" or key == "kpenter" or key == "p" then
      self.purseDialogOpen = false
    elseif key == "up" then
      self:scrollPurseDialog(app, -1)
    elseif key == "down" then
      self:scrollPurseDialog(app, 1)
    end

    return
  end

  if self.helpDialogOpen then
    if key == "escape" or key == "return" or key == "kpenter" then
      self.helpDialogOpen = false
    end

    return
  end

  if self.trickCharmDrawerOpen and not self.purseDialogOpen then
    if key == "escape" or key == "return" or key == "kpenter" then
      self.trickCharmDrawerOpen = false
    elseif key == "up" then
      self:scrollTrickCharmDrawer(app, -1)
    elseif key == "down" then
      self:scrollTrickCharmDrawer(app, 1)
    end

    return
  end

  if key == "/" then
    self.helpDialogOpen = true
    return
  end

  if key == "p" then
    self.purseDialogScrollOffset = 0
    self.purseDialogOpen = true
    return
  end

  if key == "l" then
    self.logDialogScrollOffset = 0
    self.logDialogOpen = true
    return
  end

  if app:isDevControlsEnabled() then
    local function blockRevealMutation()
      if self:isRevealActive() then
        self.statusMessage = "Finish or skip the current reveal first."
        return true
      end

      return false
    end

    if key == "f1" then
      local ok, result = app:debugForceNextCoinResult("heads")
      self.statusMessage = ok and "Dev: next coin forced to HEADS." or tostring(result)
      return
    end

    if key == "f2" then
      local ok, result = app:debugForceNextCoinResult("tails")
      self.statusMessage = ok and "Dev: next coin forced to TAILS." or tostring(result)
      return
    end

    if key == "f4" then
      self:cycleTrickCalloutStyle(app)
      return
    end

    if key == "f5" then
      local ok, result = app:debugGrantShopPoints()
      self.statusMessage = ok and string.format("Dev: granted +%d %s.", result, Terminology.getTermPlural("chip")) or tostring(result)
      return
    end

    if key == "f6" then
      if blockRevealMutation() then
        return
      end

      local ok, result = app:debugGrantNextUpgrade()
      self.statusMessage = ok and string.format("Dev: granted Trick %s.", app:getUpgradeName(result)) or tostring(result)
      return
    end

    if key == "f7" then
      if blockRevealMutation() then
        return
      end

      local ok, result = app:debugJumpToBossRound()
      self.statusMessage = ok and string.format("Dev: jumped to %s.", result) or tostring(result)
      return
    end

    if key == "f8" then
      if blockRevealMutation() then
        return
      end

      local ok, result = app:debugResolveMultipleBatches()

      if not ok then
        self.statusMessage = tostring(result)
        return
      end

      self.statusMessage = string.format("Dev: simulated %d %s.", result.resolvedCount or 0, Terminology.getTermPlural("flip"))
      routeIfStageComplete(app)
      return
    end

    if key == "f9" then
      local ok, result = app:debugPrintFullBatchTrace()
      self.statusMessage = ok and string.format("Dev: dumped %s %s trace to logs.", Terminology.getTermLower("flip"), tostring(result)) or tostring(result)
      return
    end

    if key == "f10" then
      if blockRevealMutation() then
        return
      end

      local ok, result = app:debugForceStageOutcome("clear")
      self.statusMessage = ok and "Dev: forced stage clear." or tostring(result)
      routeIfStageComplete(app)
      return
    end

    if key == "f11" then
      if blockRevealMutation() then
        return
      end

      local ok, result = app:debugForceStageOutcome("fail")
      self.statusMessage = ok and "Dev: forced stage failure." or tostring(result)
      routeIfStageComplete(app)
      return
    end
  end

  if key == "left" or key == "h" then
    self:selectCall(app, "heads")
    return
  end

  if key == "right" or key == "t" then
    self:selectCall(app, "tails")
    return
  end

  if key == "space" or key == "return" or key == "kpenter" then
    self:tryResolveBatch(app)
  end
end

function StageState:wheelmoved(app, _, y)
  if self.logDialogOpen then
    if y == 0 then
      return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local dialog = self:getHelpDialogLayout(app)
    local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Flip Log")

    if Button.containsPoint(contentArea, mouseX, mouseY) then
      self:scrollLogDialog(app, y > 0 and -1 or 1)
    end

    return
  end

  if self.trickCharmDrawerOpen then
    if y == 0 then
      return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local drawer = self:getTrickCharmDrawerLayout(app)
    local contentArea = TrickCharmDrawer.getContentArea(drawer)

    if Button.containsPoint(contentArea, mouseX, mouseY) then
      self:scrollTrickCharmDrawer(app, y > 0 and -1 or 1)
    end

    return
  end

  if not self.purseDialogOpen or y == 0 then
    return
  end

  local mouseX, mouseY = love.mouse.getPosition()
  local dialog = self:getPurseDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Pouch")

  if Button.containsPoint(contentArea, mouseX, mouseY) then
    self:scrollPurseDialog(app, y > 0 and -1 or 1)
  end
end

function StageState:draw(app)
  local uiRect, spacing = getUiRect(app)
  local layout = getMainLoopLayout(app)
  local scoreArea = insetRect(layout.score, spacing.itemGap)
  local statsArea = insetRect(layout.stageStats, spacing.itemGap)
  local controlsArea = insetRect(layout.controls, spacing.itemGap)
  local gameArea = insetRect(layout.gameWindow, spacing.itemGap)
  local actionsArea = insetRect(layout.actions, spacing.itemGap)
  local buttonLayout = self:getButtonLayout(app)
  local dealtCoinsLayout = self:getDealtCoinsLayout(app)
  local mouseX, mouseY = love.mouse.getPosition()

  self:drawScorePanel(app, scoreArea)

  Panel.draw(statsArea.x, statsArea.y, statsArea.width, statsArea.height, app.currentStageDefinition.label)

  local stageArea = Panel.getContentArea(statsArea.x, statsArea.y, statsArea.width, statsArea.height, app.currentStageDefinition.label)

  self:drawStageSummary(app, stageArea)

  Panel.draw(controlsArea.x, controlsArea.y, controlsArea.width, controlsArea.height)

  Panel.draw(gameArea.x, gameArea.y, gameArea.width, gameArea.height)

  local coinRowArea = Panel.getContentArea(gameArea.x, gameArea.y, gameArea.width, gameArea.height)
  local charmStripWidth = math.min(Theme.scale(68), math.max(Theme.scale(48), math.floor(coinRowArea.width * 0.12)))
  local charmGap = Theme.spacing.itemGap
  local charmStripArea = {
    x = coinRowArea.x + coinRowArea.width - charmStripWidth,
    y = coinRowArea.y,
    width = charmStripWidth,
    height = coinRowArea.height,
  }
  local coinPlayArea = {
    x = coinRowArea.x,
    y = coinRowArea.y,
    width = math.max(1, coinRowArea.width - charmStripWidth - charmGap),
    height = coinRowArea.height,
  }
  local revealTimeline = self.coinRowReveal and self.coinRowReveal.revealTimeline or nil
  local scoreFeedArea = nil

  if revealTimeline then
    local scoreFeedWidth = math.max(Theme.scale(124), math.min(Theme.scale(190), math.floor(coinPlayArea.width * 0.24)))

    scoreFeedArea = {
      x = coinPlayArea.x,
      y = coinPlayArea.y,
      width = scoreFeedWidth,
      height = coinPlayArea.height,
    }
  end

  local revealAnchors = {
    handBorder = {
      x = dealtCoinsLayout.x + math.floor(dealtCoinsLayout.width / 2),
      y = dealtCoinsLayout.y - Theme.scale(8),
    },
    handCenter = {
      x = dealtCoinsLayout.x + math.floor(dealtCoinsLayout.width / 2),
      y = dealtCoinsLayout.y + math.floor(dealtCoinsLayout.height / 2),
      size = Theme.scale(58),
    },
  }

  local hoveredCoinId = self:drawCoinRow(app, coinPlayArea.x, coinPlayArea.y, coinPlayArea.width, coinPlayArea.height, revealAnchors)

  local hoveredTrickCharm = self:drawTrickCharmStrip(app, charmStripArea)

  Panel.draw(actionsArea.x, actionsArea.y, actionsArea.width, actionsArea.height)

  if tostring(self.statusMessage or "") ~= "" then
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(self.statusMessage, actionsArea.x + spacing.itemGap, actionsArea.y + spacing.itemGap, math.max(1, actionsArea.width - (spacing.itemGap * 2)), "center")
  end

  local hoveredDealtCoinId = self:drawDealtCoinWindow(app, dealtCoinsLayout.x, dealtCoinsLayout.y, dealtCoinsLayout.width, dealtCoinsLayout.height)

  local buttons = self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width, buttonLayout.height)
  self:drawFatedButtonGlow(app, buttons)
  Button.drawButtons(buttons, mouseX, mouseY)

  Button.drawButtons({ self:getLogButtonLayout(app), self:getPurseButtonLayout(app), self:getHelpButtonLayout(app) }, mouseX, mouseY)
  ScoreFloaty.drawAll(self.scoreFloaties, app.fonts)

  if ThreeCupsEffect.isActive(self.coinRowReveal) and self.threeCupsRenderContext then
    ThreeCupsEffect.draw(
      self.coinRowReveal,
      self.threeCupsRenderContext.layout,
      self.threeCupsRenderContext.area,
      self.threeCupsRenderContext.anchors,
      app.fonts
    )
  end

  if scoreFeedArea then
    ScoreFeed.draw(revealTimeline.scoreFeed, app.fonts, scoreFeedArea.x, scoreFeedArea.y + Theme.scale(8), scoreFeedArea.width, {
      elapsed = self.coinRowReveal.elapsed,
      height = scoreFeedArea.height - Theme.scale(8),
      maxVisible = 5,
    })
  end

  self:drawSleightTravelAnimations(revealAnchors)
  self:drawSelectionTravelAnimations()
  self:drawDraggedHandCoin()

  local hoveredDetailCoinId = hoveredCoinId or hoveredDealtCoinId
  local dialogOpen = self.helpDialogOpen or self.purseDialogOpen or self.logDialogOpen or self.trickCharmDrawerOpen
  if hoveredDetailCoinId and not self.draggingHandCoinId and not dialogOpen then
    self:drawCoinDetailOverlay(app, hoveredDetailCoinId, mouseX, mouseY)
  elseif hoveredTrickCharm and not self.draggingHandCoinId and not dialogOpen then
    TrickCharm.drawDetailOverlay(app, hoveredTrickCharm, mouseX, mouseY, {
      bounds = {
        x = gameArea.x,
        y = gameArea.y,
        width = gameArea.width,
        height = gameArea.height,
        screenPadding = Theme.scale(8),
      },
    })
  end

  local hoveredDrawerCharm = self:drawTrickCharmDrawer(app)
  if hoveredDrawerCharm and not self.helpDialogOpen and not self.purseDialogOpen and not self.logDialogOpen then
    TrickCharm.drawDetailOverlay(app, hoveredDrawerCharm, mouseX, mouseY, {
      bounds = {
        x = uiRect.x,
        y = uiRect.y,
        width = uiRect.width,
        height = uiRect.height,
        screenPadding = Theme.scale(8),
      },
    })
  end

  self:drawHelpDialog(app)
  self:drawPurseDialog(app)
  self:drawLogDialog(app)
end

function StageState:mousepressed(app, x, y, button)
  if button == 2 then
    local dealtCard = self:getDealtCardAtPoint(x, y)
    if dealtCard then
      local ok, result = app:replaceHeldCoin(dealtCard.dealtIndex)
      if ok then
        self.statusMessage = string.format("Replaced coin. %d replacement(s) remain.", result.replacementsRemaining or 0)
      else
        self.statusMessage = tostring(result)
      end
    end
    return
  end

  if button ~= 1 then
    return
  end

  local handled = false

  if self.logDialogOpen then
    local dialog = self:getHelpDialogLayout(app)
    local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
    closeButton.onClick = function()
      self.logDialogOpen = false
      return true
    end

    handled = Button.handleMousePressed({ closeButton }, x, y)

    if not handled then
      handled = Button.handleMousePressed(self.logScrollButtons, x, y)
    end

    if not handled and (x < dialog.x or x > dialog.x + dialog.width or y < dialog.y or y > dialog.y + dialog.height) then
      self.logDialogOpen = false
    end

    return
  end

  if self.purseDialogOpen then
    local dialog = self:getPurseDialogLayout(app)
    local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
    closeButton.onClick = function()
      self.purseDialogOpen = false
      return true
    end

    handled = Button.handleMousePressed({ closeButton }, x, y)

    if not handled then
      handled = Button.handleMousePressed(self.purseScrollButtons, x, y)
    end

    if not handled and (x < dialog.x or x > dialog.x + dialog.width or y < dialog.y or y > dialog.y + dialog.height) then
      self.purseDialogOpen = false
    end

    return
  end

  if self.helpDialogOpen then
    local dialog = self:getHelpDialogLayout(app)

    handled = Button.handleMousePressed({ self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width) }, x, y)

    if not handled and (x < dialog.x or x > dialog.x + dialog.width or y < dialog.y or y > dialog.y + dialog.height) then
      self.helpDialogOpen = false
    end

    return
  end

  if self.trickCharmDrawerOpen then
    local drawer = self.trickCharmDrawerRect or self:getTrickCharmDrawerLayout(app)
    local closeButton = TrickCharmDrawer.getCloseButton(drawer, function()
      self.trickCharmDrawerOpen = false
      return true
    end)

    handled = Button.handleMousePressed({ closeButton }, x, y)

    if not handled then
      handled = Button.handleMousePressed(self.trickCharmDrawerScrollButtons, x, y)
    end

    if not handled and not Button.containsPoint(drawer, x, y) then
      self.trickCharmDrawerOpen = false
    end

    return
  end

  if self.trickCharmDrawerTriggerRect and Button.containsPoint(self.trickCharmDrawerTriggerRect, x, y) then
    self.trickCharmDrawerOpen = true
    self.trickCharmDrawerScrollOffset = 0
    return
  end

  handled = Button.handleMousePressed({ self:getLogButtonLayout(app), self:getPurseButtonLayout(app), self:getHelpButtonLayout(app) }, x, y)

  if handled then
    return
  end

  local dealtCard = self:getDealtCardAtPoint(x, y)

  if dealtCard then
    if dealtCard.selectable then
      self:tryToggleDealtCoin(app, dealtCard.dealtIndex)
    else
      self.statusMessage = self:getSelectionErrorMessage(app, "flip_slots_full")
    end

    return
  end

  local handCard = self:getHandCardAtPoint(x, y)

  if handCard and handCard.movable then
    self.draggingHandSlotIndex = handCard.slotIndex
    self.draggingHandCoinId = handCard.coinId
    self.draggingHandVisualKey = handCard.visualKey
    self.dragInsertSlotIndex = handCard.slotIndex
    self.dragPointerX = x
    self.dragPointerY = y
    self.dragVisualX = handCard.coinCenterX or x
    self.dragVisualY = handCard.coinCenterY or y
    self.dragGrabOffsetX = x - self.dragVisualX
    self.dragGrabOffsetY = y - self.dragVisualY
    self.dragBaseSize = handCard.coinSize or 64
    self.dragLiftProgress = 0
    self.dragTilt = 0
    return
  end

  local buttonLayout = self:getButtonLayout(app)
  Button.handleMousePressed(self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width, buttonLayout.height), x, y)
end

function StageState:mousereleased(app, x, y, button)
  if button ~= 1 or not self.draggingHandSlotIndex then
    return
  end

  local fromSlotIndex = self.draggingHandSlotIndex
  local toSlotIndex = self.dragInsertSlotIndex
  local visualKey = self.draggingHandVisualKey
  local dealtCoinsLayout = self:getDealtCoinsLayout(app)
  local droppedOnHand = Button.containsPoint(dealtCoinsLayout, x, y)
  local deselectSourceRect = {
    coinCenterX = self.dragVisualX or x,
    coinCenterY = self.dragVisualY or y,
    coinSize = math.floor((self.dragBaseSize or 64) * 1.15),
  }

  if visualKey and self.dragVisualX and self.dragVisualY then
    self.coinRowVisuals = self.coinRowVisuals or {}
    self.coinRowVisuals[visualKey] = {
      x = self.dragVisualX,
      y = self.dragVisualY,
      size = (self.dragBaseSize or 64) * 1.15,
    }
  end

  self.draggingHandSlotIndex = nil
  self.draggingHandCoinId = nil
  self.draggingHandVisualKey = nil
  self.dragInsertSlotIndex = nil
  self.dragPointerX = nil
  self.dragPointerY = nil
  self.dragGrabOffsetX = 0
  self.dragGrabOffsetY = 0
  self.dragVisualX = nil
  self.dragVisualY = nil
  self.dragBaseSize = nil
  self.dragLiftProgress = 0
  self.dragTilt = 0

  if droppedOnHand then
    self:tryDeselectFlipSlot(app, fromSlotIndex, deselectSourceRect)
    return
  end

  if toSlotIndex and toSlotIndex ~= fromSlotIndex then
    self:tryMoveSlotTo(app, fromSlotIndex, toSlotIndex)
    return
  end

  local targetCard = self:getHandCardAtPoint(x, y)

  if targetCard and targetCard.slotIndex == fromSlotIndex then
    self:tryDeselectFlipSlot(app, fromSlotIndex, deselectSourceRect)
    return
  end

  if targetCard and targetCard.movable and targetCard.slotIndex ~= fromSlotIndex then
    self:tryMoveSlotTo(app, fromSlotIndex, targetCard.slotIndex)
  end
end

return StageState
