local Button = require("src.ui.button")
local CoinDetailOverlay = require("src.ui.coin_detail_overlay")
local CoinArt = require("src.ui.coin_art")
local Coins = require("src.content.coins")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local PurseView = require("src.ui.purse_view")
local Terminology = require("src.content.terminology")
local Theme = require("src.ui.theme")

local StageState = {}
StageState.__index = StageState

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function routeIfStageComplete(app)
  if not app or not app.requestStageCompletion then
    return false
  end

  return app:requestStageCompletion() == true
end

local function getCoinRevealTime(reveal, index)
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

local function getSleightAnimationProgress(animation)
  return math.min(1, animation.elapsed / math.max(0.001, animation.duration or 0.315))
end

local function easeOutCubic(progress)
  local inverse = 1 - progress
  return 1 - (inverse * inverse * inverse)
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function getUiRect(app)
  local metrics = app:getUiMetrics()
  return metrics.rect, metrics.spacing, metrics.metrics, metrics.window
end

local function getMainLoopLayout(app)
  local rect = getUiRect(app)

  return Layout.resolveGrid(rect, 12, 8, 0, {
    score = { column = 1, row = 1, columnSpan = 2, rowSpan = 2 },
    stageStats = { column = 3, row = 1, columnSpan = 9, rowSpan = 2 },
    controls = { column = 12, row = 1, columnSpan = 1, rowSpan = 2 },
    gameWindow = { column = 1, row = 3, columnSpan = 12, rowSpan = 4 },
    actions = { column = 1, row = 7, columnSpan = 12, rowSpan = 2 },
  })
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

local function drawSleightBadge(centerX, centerY, radius, disabled, hovered)
  local fill = disabled and Theme.colors.panelBorder or Theme.colors.warning
  local border = disabled and Theme.colors.panelBorder or Theme.colors.highlight
  local icon = disabled and Theme.colors.mutedText or Theme.colors.background
  local alpha = disabled and 0.40 or (hovered and 0.96 or 0.84)

  setColorWithAlpha(fill, alpha)
  love.graphics.circle("fill", centerX, centerY, radius)

  Theme.applyColor(border)
  love.graphics.setLineWidth(2)
  love.graphics.circle("line", centerX, centerY, radius)

  Theme.applyColor(icon)

  local lastX, lastY = nil, nil
  local endX, endY = nil, nil

  for step = 0, 8 do
    local progress = step / 8
    local angle = -2.45 + (progress * 4.05)
    local spiralRadius = (radius - 6) * (0.48 + (progress * 0.52))
    local pointX = centerX + math.cos(angle) * spiralRadius
    local pointY = centerY + math.sin(angle) * spiralRadius

    if lastX then
      love.graphics.line(lastX, lastY, pointX, pointY)
    end

    lastX, lastY = pointX, pointY
    endX, endY = pointX, pointY
  end

  if endX and endY then
    love.graphics.polygon("fill", endX, endY, endX - 5, endY - 1, endX - 2, endY + 5)
  end

  love.graphics.setLineWidth(1)
end

function StageState.new()
  return setmetatable({
    statusMessage = "",
    buttons = {},
    handActionButtons = {},
    helpDialogOpen = false,
    purseDialogOpen = false,
    purseDialogScrollOffset = 0,
    purseScrollButtons = {},
    logDialogOpen = false,
    logDialogScrollOffset = 0,
    logScrollButtons = {},
    coinRowReveal = nil,
    sleightAnimations = {},
    reveal = nil,
    handCardRects = {},
    coinRowVisuals = {},
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
    stageScore = batchResult.stageScore,
    targetScore = batchResult.targetScore,
    runTotalScore = batchResult.runTotalScore,
    shopPoints = batchResult.shopPoints,
    flipsRemaining = batchResult.flipsRemaining,
    stageDelta = batchResult.scoreBreakdown and batchResult.scoreBreakdown.totalStageScoreDelta or 0,
    coins = coins,
  }
end

function StageState:startCoinRowReveal(app, batchResult)
  local coinCount = #(batchResult.perCoin or {})
  local revealDuration = app.config.get("ui.batchRevealDuration", 0.75)
  local coinMotionDuration = 0.25

  self.coinRowReveal = {
    batchId = batchResult.batchId,
    batchResult = batchResult,
    elapsed = 0,
    revealDuration = revealDuration,
    coinMotionDuration = coinMotionDuration,
    displayDuration = math.max(2.7, revealDuration + coinMotionDuration + 1.1),
    coinCount = coinCount,
    nextSoundIndex = 1,
    feedbackPlayed = false,
  }
end

function StageState:completeReveal(app)
  if not self:isRevealActive() then
    return false, "reveal_not_active"
  end

  local stageShouldAdvance = app.stageState and app.stageState.stageStatus ~= "active"

  playCoinRowFeedback(app, self.coinRowReveal)
  self.reveal = nil

  if stageShouldAdvance then
    app:clearFeedback()
    routeIfStageComplete(app)
  end

  return true
end

function StageState:isStageActive(app)
  return app.stageState and app.stageState.stageStatus == "active"
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
  self.statusMessage = string.format("Call selected: %s. Reorder, Sleight, or Flip.", string.upper(call))
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

  local batchResult, errorMessage = app:resolveCurrentBatch(app.selectedCall, { deferFeedback = true })

  if not batchResult then
    self.statusMessage = errorMessage
    return false, errorMessage
  end

  if app.audioSystem then
    app.audioSystem:playCue("coin_flip")
  end

  self.statusMessage = string.format(
    "Resolved %s %d. Damage %d/%d. Flips remaining: %d.",
    Terminology.getTermLower("flip"),
    batchResult.batchId,
    app.stageState.stageScore,
    app.stageState.targetScore,
    app.stageState.flipsRemaining
  )

  self:startCoinRowReveal(app, batchResult)

  app.selectedCall = nil

  if batchResult.status == "active" then
    local _, drawWarning = app:ensureHandDrawn()

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
        self.statusMessage = string.format("Purse empty. Stage %s.", batchResult.status)
      end
    end
  end

  if batchResult.status ~= "active" then
    self:startReveal(app, batchResult)
  else
    self.reveal = nil
  end

  return true, batchResult
end

function StageState:trySleightSlot(app, slotIndex)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress."
    return false, "reveal_active"
  end

  local ok, result = app:sleightHandSlot(slotIndex)
  self.statusMessage = ok and string.format("Sleighted slot %d.", slotIndex) or tostring(result)

  if ok and result then
    self.sleightAnimations[slotIndex] = {
      elapsed = 0,
      duration = 0.315,
      returnedCoinId = result.returnedDefinitionId,
      replacementCoinId = result.replacementDefinitionId,
    }
  end

  return ok, result
end

function StageState:tryMoveSlot(app, slotIndex, direction)
  if self:isRevealActive() then
    self.statusMessage = "Reveal in progress."
    return false, "reveal_active"
  end

  local ok, result = app:moveHandSlot(slotIndex, direction)
  self.statusMessage = ok and "Reordered hand." or tostring(result)

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

  self.statusMessage = "Reordered hand."
  return true
end

function StageState:buildButtons(app, x, y, width, height)
  local _, spacing, componentMetrics = getUiRect(app)
  local gap = spacing.itemGap
  local buttonWidth = math.max(1, math.floor((width - (gap * 2)) / 3))
  local buttonHeight = math.max(1, height or componentMetrics.buttonHeight)
  local stageActive = self:isStageActive(app)
  local revealActive = self:isRevealActive()

  self.buttons = {
    {
      x = x,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "TAILS",
      variant = app.selectedCall == "tails" and "primary" or "default",
      focused = app.selectedCall == "tails",
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
      label = "FLIP HAND",
      variant = "success",
      disabled = not stageActive or revealActive or not app.selectedCall,
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
  local buttonHeight = math.min(
    math.max(componentMetrics.buttonHeight, math.floor(area.height * 0.36)),
    math.max(1, area.height - (spacing.blockGap * 2))
  )

  return {
    x = area.x + horizontalInset,
    y = area.y + area.height - spacing.blockGap - buttonHeight,
    width = math.max(1, area.width - (horizontalInset * 2)),
    height = buttonHeight,
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
  local dialog = self:getHelpDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Purse")
  local maxScrollOffset = PurseView.getMaxScrollOffset(app, contentArea, app.stageState)

  self.purseDialogScrollOffset = math.max(0, math.min((self.purseDialogScrollOffset or 0) + direction, maxScrollOffset))
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
    "Review the drawn hand, pick HEADS or TAILS, then flip the hand in order.",
    string.format("Matches and effects deal %s. %s come from coins and victory rewards.", Terminology.getTermLower("stage_score"), Terminology.getTermPlural("chip")),
    "",
    "Current Breakdown:",
  }

  for _, line in ipairs(app:getScoreBreakdownLines(10)) do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "Controls:")
  table.insert(lines, "- Click HEADS or TAILS: choose the call")
  table.insert(lines, "- Flip Hand / Enter: resolve the current hand")
  table.insert(lines, "- Sleight: replace a hand slot once before flipping")
  table.insert(lines, "- Drag coins in the hand: reorder the hand")
  table.insert(lines, "- P: inspect purse")
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
  local dialog = self:getHelpDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Purse")
  local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
  local mouseX, mouseY = love.mouse.getPosition()

  closeButton.onClick = function()
    self.purseDialogOpen = false
    return true
  end

  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, window.width, window.height)
  Panel.draw(dialog.x, dialog.y, dialog.width, dialog.height, "Purse")
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
  local stage = app.stageState
  local opponentName = stage.opponent and stage.opponent.name or "Opponent"
  local hpRemaining = math.max(0, (stage.targetScore or 0) - (stage.stageScore or 0))
  local scoreColor = stage.stageScore >= stage.targetScore and Theme.colors.success or Theme.colors.text
  local contentArea = Panel.getContentArea(area.x, area.y, area.width, area.height, "Opponent")

  Panel.draw(area.x, area.y, area.width, area.height, "Opponent")

  love.graphics.setFont(app.fonts.title)
  Theme.applyColor(scoreColor)
  love.graphics.printf(tostring(hpRemaining), contentArea.x, contentArea.y + 6, math.max(1, contentArea.width), "center")

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(opponentName, contentArea.x, contentArea.y + app.fonts.title:getHeight() + 8, math.max(1, contentArea.width), "center")
  love.graphics.printf(string.format("HP left • dealt %d/%d", stage.stageScore, stage.targetScore), contentArea.x, contentArea.y + app.fonts.title:getHeight() + 25, math.max(1, contentArea.width), "center")
end

function StageState:drawStageSummary(app, area)
  local stage = app.stageState
  local stats = {
    { label = "Chips", value = tostring(app.runState and app.runState.shopPoints or 0), color = Theme.colors.text },
    { label = "Flips", value = tostring(stage.flipsRemaining), color = Theme.colors.text },
    { label = "Call", value = app.selectedCall and string.upper(app.selectedCall) or "-", color = Theme.colors.text },
  }

  local statGap = Theme.spacing.itemGap
  local statWidth = math.max(1, math.floor((area.width - (statGap * (#stats - 1))) / #stats))
  local statHeight = math.min(56, math.max(1, area.height))
  local statY = area.y + math.floor(math.max(0, area.height - statHeight) / 2)

  for index, stat in ipairs(stats) do
    local statX = area.x + ((index - 1) * (statWidth + statGap))

    setColorWithAlpha(Theme.colors.panelBorder, 0.16)
    love.graphics.rectangle("fill", statX, statY, statWidth, statHeight, 10, 10)
    Theme.applyColor(Theme.colors.panelBorder)
    love.graphics.rectangle("line", statX, statY, statWidth, statHeight, 10, 10)

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(stat.label, statX + 8, statY + 7, math.max(1, statWidth - 16), "center")

    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(stat.color)
    love.graphics.printf(stat.value, statX + 8, statY + 24, math.max(1, statWidth - 16), "center")
  end

  if stage.stageType == "boss" then
    local pulse = app:getUiPulse(4.8, 0.10, 0.22)
    local bossCards = app:getBossModifierCards()
    local bannerY = statY + statHeight + 10
    local bannerHeight = math.min(46, math.max(0, area.y + area.height - bannerY))

    if bannerHeight > 0 then
      love.graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.16 + pulse)
      love.graphics.rectangle("fill", area.x, bannerY, area.width, bannerHeight, 10, 10)
      love.graphics.setColor(Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.95)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", area.x, bannerY, area.width, bannerHeight, 10, 10)
      love.graphics.setLineWidth(1)
      love.graphics.setFont(app.fonts.body)
      Theme.applyColor(Theme.colors.text)
      love.graphics.printf(string.format("Boss pressure active: %d modifier(s)", #bossCards), area.x + 14, bannerY + 12, area.width - 28, "center")
    end
  end
end

function StageState:getVisibleCoinStates(app)
  local batchResult = app.lastBatchResult
  local coins = {}

  if self.coinRowReveal and batchResult and batchResult.perCoin then
    for _, coinState in ipairs(batchResult.perCoin) do
      table.insert(coins, {
        coinId = coinState.coinId,
        slotIndex = coinState.slotIndex,
        result = coinState.result,
        forcedResult = coinState.forcedResult,
        didMatch = coinState.result == batchResult.call,
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
        sleightUsed = slot.sleightUsed == true,
        cannotSleight = definition and definition.cannotSleight == true,
        cannotReorder = definition and definition.cannotReorder == true,
      })
    end
  end

  return coins, nil, nil
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

function StageState:getDragInsertSlotIndex(pointerX, layout, slotCount)
  if not pointerX or not layout or (slotCount or 0) <= 0 then
    return nil
  end

  local step = layout.cardWidth + layout.cardGap
  local firstCenterX = layout.startX + math.floor(layout.cardWidth / 2)
  local insertSlotIndex = math.floor(((pointerX - firstCenterX) / math.max(1, step)) + 1.5)

  return clamp(insertSlotIndex, 1, slotCount)
end

function StageState:getDragGhostCenter(layout, insertSlotIndex, remainingCount, pushDistance)
  if not layout or not insertSlotIndex then
    return nil, nil
  end

  local count = math.max(1, remainingCount or 0)
  local step = layout.cardWidth + layout.cardGap
  local firstCenterX = layout.startX + math.floor(layout.cardWidth / 2)
  local centerY = layout.centerLineY

  if remainingCount == 0 then
    return firstCenterX, centerY
  end

  if insertSlotIndex <= 1 then
    return firstCenterX - pushDistance, centerY
  end

  if insertSlotIndex > remainingCount then
    return firstCenterX + ((count - 1) * step) + pushDistance, centerY
  end

  local leftCenterX = firstCenterX + ((insertSlotIndex - 2) * step)
  local rightCenterX = firstCenterX + ((insertSlotIndex - 1) * step)

  return math.floor((leftCenterX + rightCenterX) / 2), centerY
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

function StageState:drawCoinRow(app, x, y, width, height)
  local coins, call, batchId = self:getVisibleCoinStates(app)

  if #coins == 0 then
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("No hand drawn.", x, y + math.floor(height / 2) - 10, width, "center")
    self.handCardRects = {}
    self.coinRowVisuals = {}
    return
  end

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)

  local title = call and string.format("Last flip: %s", string.upper(call)) or "Current hand"
  local titleHeight = 20
  love.graphics.printf(title, x, y, width, "center")

  local layout = self:getCoinRowLayout(app, x, y, width, height, #coins, titleHeight)
  local cardWidth = layout.cardWidth
  local reveal = self.coinRowReveal
  local visibleCount = #coins
  local rowRevealActive = reveal and reveal.batchId == batchId

  if rowRevealActive then
    visibleCount = 0

    for index = 1, #coins do
      if reveal.elapsed >= getCoinRevealTime(reveal, index) then
        visibleCount = index
      end
    end
  end

  self.handActionButtons = {}
  self.handCardRects = {}

  local mouseX, mouseY = love.mouse.getPosition()
  local hoveredCoinId = nil
  local isDraggingHandCoin = self.draggingHandSlotIndex ~= nil
  local handHoverEnabled = not self.purseDialogOpen
  local drawCoins = coins
  local dragLayout = nil
  local dragPushDistance = 0
  local dragGhostX = nil
  local dragGhostY = nil
  local dragGhostSize = nil
  local dragTargetX = mouseX and (mouseX - (self.dragGrabOffsetX or 0)) or nil

  if isDraggingHandCoin and not rowRevealActive then
    drawCoins = {}

    for _, coin in ipairs(coins) do
      if (coin.slotIndex or #drawCoins + 1) ~= self.draggingHandSlotIndex then
        table.insert(drawCoins, coin)
      end
    end

    dragLayout = self:getCoinRowLayout(app, x, y, width, height, math.max(1, #drawCoins), titleHeight)
    dragPushDistance = math.floor(dragLayout.cardWidth * 0.32)
    self.dragInsertSlotIndex = self:getDragInsertSlotIndex(dragTargetX, dragLayout, #coins)
    dragGhostX, dragGhostY = self:getDragGhostCenter(dragLayout, self.dragInsertSlotIndex, #drawCoins, dragPushDistance)
    dragGhostSize = math.min(Theme.scale(96), math.max(Theme.scale(62), math.floor(dragLayout.cardWidth * 0.54)))
  else
    self.dragInsertSlotIndex = nil
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
    })
  end

  local activeVisualKeys = {}

  for index, coin in ipairs(drawCoins) do
    local activeLayout = dragLayout or layout
    local activeCardWidth = activeLayout.cardWidth
    local activeCardGap = activeLayout.cardGap
    local activeCardHeight = activeLayout.cardHeight
    local activeStartX = activeLayout.startX
    local activeCenterLineY = activeLayout.centerLineY
    local pushOffset = isDraggingHandCoin and self:getDragPushOffset(index, self.dragInsertSlotIndex, dragPushDistance) or 0
    local cardX = activeStartX + ((index - 1) * (activeCardWidth + activeCardGap)) + pushOffset
    local hasResult = coin.result ~= nil and index <= visibleCount
    local artSide = nil
    local artSelected = false
    local revealAge = rowRevealActive and reveal.elapsed - getCoinRevealTime(reveal, index) or nil
    local liftProgress = revealAge and revealAge >= 0 and math.min(1, revealAge / math.max(0.001, reveal.coinMotionDuration or 0.46)) or nil
    local liftOffset, motionTilt, motionScale, motionScaleX, motionScaleY, spinSide, resultSettled = getRetroCoinMotion(liftProgress, activeCardHeight)
    local impactAge = revealAge and revealAge >= 0 and revealAge - ((reveal.coinMotionDuration or 0.46) * 0.78) or nil
    local impactPunch = impactAge and impactAge >= 0 and math.max(0, 1 - (impactAge / 0.26)) or 0
    local sleightAnimation = not hasResult and not rowRevealActive and self.sleightAnimations and self.sleightAnimations[coin.slotIndex or index] or nil
    local cardDrawX = cardX
    local coinSize = math.min(Theme.scale(96), math.max(Theme.scale(62), math.floor(activeCardWidth * 0.54)))
    local animatedCoinSize = math.floor(coinSize * (motionScale + (impactPunch * 0.08)))
    local coinCenterX = cardDrawX + math.floor(activeCardWidth / 2)
    local staggerOffset = (index % 2 == 0) and 16 or -16
    local coinCenterY = activeCenterLineY + staggerOffset + liftOffset
    local visualKey = self:getCoinRowVisualKey(coin, index, batchId)
    local rowVisual = self:updateCoinRowVisual(visualKey, coinCenterX, coinCenterY, animatedCoinSize, not rowRevealActive and not hasResult)
    activeVisualKeys[visualKey] = true

    coinCenterX = rowVisual.x
    coinCenterY = rowVisual.y
    animatedCoinSize = math.floor(rowVisual.size)
    cardDrawX = coinCenterX - math.floor(activeCardWidth / 2)
    local coinDrawX = coinCenterX - math.floor(animatedCoinSize / 2)
    local coinDrawY = coinCenterY - math.floor(animatedCoinSize / 2)
    local labelY = coinDrawY + animatedCoinSize + 12
    local badgeRadius = 16
    local badgeCenterX = coinDrawX + animatedCoinSize - 7
    local badgeCenterY = coinDrawY + animatedCoinSize - 7
    local hitWidth = math.max(animatedCoinSize + 34, math.min(activeCardWidth, 112))
    local hitX = coinCenterX - math.floor(hitWidth / 2)
    local hitY = coinDrawY - 14
    local hitHeight = (labelY + app.fonts.small:getHeight() + 10) - hitY

    if hasResult then
      hitHeight = hitHeight + 34
    end

    local hovered = handHoverEnabled and not isDraggingHandCoin and mouseX and mouseY and mouseX >= hitX and mouseX <= (hitX + hitWidth) and mouseY >= hitY and mouseY <= (hitY + hitHeight)

    if hasResult then
      artSide = resultSettled and coin.result or spinSide
      artSelected = resultSettled and coin.didMatch
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
      movable = not rowRevealActive and not hasResult and not coin.cannotReorder and self:isStageActive(app) and not self:isRevealActive(),
    })

    if hasResult and resultSettled then
      local haloColor = coin.didMatch and Theme.colors.success or Theme.colors.danger

      setColorWithAlpha(haloColor, 0.15)
      love.graphics.circle("fill", coinCenterX, coinCenterY, math.floor(animatedCoinSize / 2) + 14)
      setColorWithAlpha(haloColor, 0.58)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", coinCenterX, coinCenterY, math.floor(animatedCoinSize / 2) + 9)
      love.graphics.setLineWidth(1)
    elseif hovered then
      setColorWithAlpha(Theme.colors.accent, 0.12)
      love.graphics.circle("fill", coinCenterX, coinCenterY, math.floor(animatedCoinSize / 2) + 12)
      setColorWithAlpha(Theme.colors.accent, 0.36)
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", coinCenterX, coinCenterY, math.floor(animatedCoinSize / 2) + 7)
      love.graphics.setLineWidth(1)
    end

    setColorWithAlpha(Theme.colors.shadow, 0.34)
    love.graphics.ellipse("fill", coinCenterX, coinDrawY + animatedCoinSize + 8, math.floor(animatedCoinSize * 0.42), 8)

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(app:getCoinName(coin.coinId), cardDrawX + 4, labelY, activeCardWidth - 8, "center")

    CoinArt.draw(coin.coinId, coinDrawX, coinDrawY, animatedCoinSize, {
      side = artSide,
      selected = artSelected,
      alpha = sleightAnimation and 0.16 or (hasResult and 1.0 or 0.78),
      tilt = liftProgress and motionTilt * ((index % 2 == 0) and 1 or -1) or (hasResult and ((index % 2 == 0) and 0.10 or -0.10) or 0),
      scaleX = liftProgress and motionScaleX or 1,
      scaleY = liftProgress and motionScaleY or 1,
    })

    if sleightAnimation then
      self:drawSleightSwitchAnimation(cardDrawX, coinDrawY, activeCardWidth, activeCardHeight, coinSize, sleightAnimation)
    end

    if hasResult and impactAge and impactAge >= 0 and impactAge <= 0.60 then
      self:drawRevealImpact(coinDrawX, coinDrawY, animatedCoinSize, animatedCoinSize, impactAge, coin.didMatch)
    end

    if hasResult then
      if resultSettled then
        Theme.applyColor(coin.didMatch and Theme.colors.success or Theme.colors.mutedText)
        love.graphics.printf(coin.didMatch and string.upper(Terminology.getOutcomeLabel("match")) or string.upper(Terminology.getOutcomeLabel("miss")), cardDrawX + 8, labelY + 18, activeCardWidth - 16, "center")

        if coin.forcedResult then
          Theme.applyColor(Theme.colors.warning)
          love.graphics.printf("FORCED", cardDrawX + 8, labelY + 36, activeCardWidth - 16, "center")
        end
      end
    else
      local badgeSize = badgeRadius * 2
      local buttons = {
        {
          x = badgeCenterX - badgeRadius,
          y = badgeCenterY - badgeRadius,
          width = badgeSize,
          height = badgeSize,
          label = "S",
          variant = "warning",
          disabled = coin.sleightUsed or coin.cannotSleight,
          onClick = function()
            return self:trySleightSlot(app, coin.slotIndex or index)
          end,
        },
      }

      if not rowRevealActive then
        for _, button in ipairs(buttons) do
          table.insert(self.handActionButtons, button)
          drawSleightBadge(
            badgeCenterX,
            badgeCenterY,
            badgeRadius,
            button.disabled,
            handHoverEnabled and mouseX and mouseY and Button.containsPoint(button, mouseX, mouseY)
          )
        end
      end

      if coin.cannotReorder then
        Theme.applyColor(Theme.colors.warning)
        love.graphics.printf("LOCKED", cardDrawX + 8, labelY + 18, activeCardWidth - 16, "center")
      end
    end

  end

  for key in pairs(self.coinRowVisuals or {}) do
    if not activeVisualKeys[key] and key ~= self.draggingHandVisualKey then
      self.coinRowVisuals[key] = nil
    end
  end

  if self.draggingHandCoinId then
    local baseSize = self.dragBaseSize or dragGhostSize or math.min(96, math.max(62, math.floor(cardWidth * 0.54)))
    local targetDraggedSize = (dragGhostSize or baseSize) * 1.15
    local lift = easeOutCubic(clamp(self.dragLiftProgress or 1, 0, 1))
    local draggedSize = math.floor(baseSize + ((targetDraggedSize - baseSize) * lift))
    local drawCenterX = self.dragVisualX or (mouseX and (mouseX - (self.dragGrabOffsetX or 0))) or mouseX
    local drawCenterY = self.dragVisualY or (mouseY and (mouseY - (self.dragGrabOffsetY or 0))) or mouseY

    if drawCenterX and drawCenterY then
      setColorWithAlpha(Theme.colors.shadow, 0.20 + (0.12 * lift))
      love.graphics.ellipse("fill", drawCenterX, drawCenterY + math.floor(draggedSize * 0.55), math.floor(draggedSize * 0.46), 9)
      CoinArt.draw(self.draggingHandCoinId, drawCenterX - math.floor(draggedSize / 2), drawCenterY - math.floor(draggedSize / 2), draggedSize, {
        selected = true,
        alpha = 0.78 + (0.14 * lift),
        tilt = self.dragTilt or 0,
      })
    end
  end

  return hoveredCoinId
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

function StageState:drawRevealImpact(cardX, cardY, cardWidth, cardHeight, age, didMatch)
  local progress = math.min(1, age / 0.60)
  local color = didMatch and Theme.colors.success or Theme.colors.danger
  local centerX = cardX + math.floor(cardWidth / 2)
  local centerY = cardY + math.floor(cardHeight / 2)
  local radius = math.floor(math.max(cardWidth, cardHeight) / 2)
  local padding = math.floor(8 + (30 * progress))
  local alpha = 0.68 * (1 - progress)

  Theme.applyColor({ color[1], color[2], color[3], alpha })
  love.graphics.setLineWidth(3)
  love.graphics.circle("line", centerX, centerY, radius + padding)
  love.graphics.setLineWidth(1)

  if didMatch then
    self:drawMatchParticles(cardX, cardY, cardWidth, cardHeight, age)
  else
    self:drawMissParticles(cardX, cardY, cardWidth, cardHeight, age)
  end
end

function StageState:drawSleightSwitchAnimation(cardX, coinY, cardWidth, cardHeight, coinSize, animation)
  local progress = getSleightAnimationProgress(animation)
  local eased = easeOutCubic(progress)
  local centerX = cardX + math.floor(cardWidth / 2)
  local coinX = centerX - math.floor(coinSize / 2)
  local baseY = coinY
  local travel = math.floor(cardHeight * 0.34)
  local outgoingY = baseY + math.floor(eased * travel)
  local incomingY = baseY - math.floor((1 - eased) * travel)
  local outgoingAlpha = math.max(0, 0.88 * (1 - progress))
  local incomingAlpha = math.min(1, 0.20 + (0.80 * eased))
  local pulseAlpha = math.max(0, 1 - progress)
  local streamX = centerX - 7

  love.graphics.setLineWidth(3)
  Theme.applyColor({ Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.52 * pulseAlpha })
  love.graphics.line(streamX, baseY + coinSize + 8, streamX, baseY + coinSize + travel - 4)
  love.graphics.setLineWidth(1)

  if animation.returnedCoinId then
    CoinArt.draw(animation.returnedCoinId, coinX, outgoingY, coinSize, {
      alpha = outgoingAlpha,
      tilt = 0.16 + (progress * 0.34),
    })
  end

  if animation.replacementCoinId then
    CoinArt.draw(animation.replacementCoinId, coinX, incomingY, coinSize, {
      alpha = incomingAlpha,
      tilt = -0.18 + (progress * 0.18),
    })
  end

  Theme.applyColor({ Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.84 * pulseAlpha })
  love.graphics.printf("SLEIGHT", cardX + 8, baseY + coinSize + 12, cardWidth - 16, "center")
end

function StageState:getHandCardAtPoint(x, y)
  for _, rect in ipairs(self.handCardRects or {}) do
    if x >= rect.x and x <= (rect.x + rect.width) and y >= rect.y and y <= (rect.y + rect.height) then
      return rect
    end
  end

  return nil
end

function StageState:enter(app)
  app:ensureCurrentStage()
  app.selectedCall = nil
  app:ensureHandDrawn()
  self.reveal = nil
  self.coinRowReveal = nil
  self.sleightAnimations = {}
  self.coinRowVisuals = {}
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
  self.logDialogOpen = false
  self.logDialogScrollOffset = 0
  if app.stageState and app.stageState.stageStatus ~= "active" then
    self.statusMessage = string.format("Stage %s.", app.stageState.stageStatus)
  else
    self.statusMessage = "Review your hand, then pick HEADS or TAILS."
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

  for slotIndex, animation in pairs(self.sleightAnimations or {}) do
    animation.elapsed = animation.elapsed + dt

    if animation.elapsed >= (animation.duration or 0.315) then
      self.sleightAnimations[slotIndex] = nil
    end
  end

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

    if not reveal.feedbackPlayed and reveal.elapsed >= (reveal.revealDuration + (reveal.coinMotionDuration or 0)) then
      playCoinRowFeedback(app, reveal)
    end

    if reveal.elapsed >= reveal.displayDuration then
      self.coinRowReveal = nil
    end
  end

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

function StageState:drawRevealOverlay(app)
  if not self:isRevealActive() then
    return
  end

  local reveal = self.reveal
  local rect, spacing, _, window = getUiRect(app)
  local overlayWidth = math.min(760, math.max(1, rect.width - (spacing.screenPadding * 2)))
  local overlayHeight = math.min(340, math.max(1, rect.height - (spacing.screenPadding * 2)))
  local overlayX = rect.x + math.floor((rect.width - overlayWidth) / 2)
  local overlayY = rect.y + math.floor((rect.height - overlayHeight) / 2)
  local contentArea = Panel.getContentArea(overlayX, overlayY, overlayWidth, overlayHeight, "Flip Reveal")
  local pulse = app:getUiPulse(5.2, 0.10, 0.22)
  local coinCount = math.max(1, #reveal.coins)
  local revealRatio = math.min(1, reveal.elapsed / math.max(reveal.revealDuration, 0.001))
  local visibleCount = math.min(coinCount, math.floor(revealRatio * math.max(1, coinCount - 1)) + 1)

  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, window.width, window.height)

  Panel.draw(overlayX, overlayY, overlayWidth, overlayHeight, "Flip Reveal")

  setColorWithAlpha(Theme.colors.accent, 0.14 + pulse)
  love.graphics.rectangle("fill", contentArea.x, contentArea.y, contentArea.width, 44, 10, 10)
  setColorWithAlpha(Theme.colors.highlight, 0.95)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", contentArea.x, contentArea.y, contentArea.width, 44, 10, 10)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(app.fonts.body)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(string.format("Call: %s", string.upper(reveal.call)), contentArea.x + 14, contentArea.y + 8)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(string.format("%s %d", Terminology.getTermLabel("flip"), reveal.batchId), contentArea.x + 14, contentArea.y + 10, contentArea.width - 28, "right")

  local statsY = contentArea.y + 56
  local hpRemaining = math.max(0, (reveal.targetScore or 0) - (reveal.stageScore or 0))
  local statsLines = {
    string.format("Damage dealt this flip: %+d", reveal.stageDelta),
    string.format("Opponent HP: %d/%d", hpRemaining, reveal.targetScore),
    string.format("%s: %d", Terminology.getTermPlural("chip"), reveal.shopPoints or 0),
    string.format("Flips remaining: %d", reveal.flipsRemaining),
  }

  if reveal.stageStatus ~= "active" then
    local outcome = reveal.stageStatus == "cleared" and "DEFEATED" or string.upper(reveal.stageStatus)
    table.insert(statsLines, string.format("Outcome: %s", outcome))
  end

  Layout.drawWrappedLines(statsLines, contentArea.x, statsY, contentArea.width, Theme.colors.text, Theme.spacing.lineHeight, 92)

  local cardAreaY = statsY + 104
  local cardGap = Theme.spacing.itemGap
  local cardWidth = math.floor((contentArea.width - (cardGap * (coinCount - 1))) / coinCount)
  local cardHeight = 104

  for index, coin in ipairs(reveal.coins) do
    local cardX = contentArea.x + ((index - 1) * (cardWidth + cardGap))
    local cardY = cardAreaY
    local revealed = index <= visibleCount
    local resultColor = coin.didMatch and Theme.colors.success or Theme.colors.danger

    if revealed then
      setColorWithAlpha(resultColor, 0.18 + pulse)
    else
      setColorWithAlpha(Theme.colors.panelBorder, 0.18)
    end
    love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, 10, 10)
    Theme.applyColor(revealed and resultColor or Theme.colors.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cardX, cardY, cardWidth, cardHeight, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.text)
    love.graphics.printf(app:getCoinName(coin.coinId), cardX + 8, cardY + 10, cardWidth - 16, "center")

    CoinArt.draw(coin.coinId, cardX + math.floor((cardWidth - 38) / 2), cardY + 34, 38, {
      side = revealed and coin.result or nil,
      selected = revealed and coin.didMatch,
      alpha = revealed and 1.0 or 0.55,
      tilt = revealed and ((index % 2 == 0) and 0.10 or -0.10) or 0,
    })

    if revealed then
      love.graphics.setFont(app.fonts.small)
      Theme.applyColor(coin.didMatch and Theme.colors.success or Theme.colors.mutedText)
      love.graphics.printf(coin.didMatch and string.upper(Terminology.getOutcomeLabel("match")) or string.upper(Terminology.getOutcomeLabel("miss")), cardX + 10, cardY + 78, cardWidth - 20, "center")

      if coin.forcedResult then
        Theme.applyColor(Theme.colors.warning)
        love.graphics.printf("FORCED", cardX + 10, cardY + 94, cardWidth - 20, "center")
      end
    else
      Theme.applyColor(Theme.colors.mutedText)
      love.graphics.setFont(app.fonts.heading)
      love.graphics.printf("?", cardX + 10, cardY + 60, cardWidth - 20, "center")
    end
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
      self.statusMessage = ok and string.format("Dev: granted upgrade %s.", app:getUpgradeName(result)) or tostring(result)
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

  if not self.purseDialogOpen or y == 0 then
    return
  end

  local mouseX, mouseY = love.mouse.getPosition()
  local dialog = self:getHelpDialogLayout(app)
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Purse")

  if Button.containsPoint(contentArea, mouseX, mouseY) then
    self:scrollPurseDialog(app, y > 0 and -1 or 1)
  end
end

function StageState:draw(app)
  local _, spacing = getUiRect(app)
  local layout = getMainLoopLayout(app)
  local scoreArea = insetRect(layout.score, spacing.itemGap)
  local statsArea = insetRect(layout.stageStats, spacing.itemGap)
  local controlsArea = insetRect(layout.controls, spacing.itemGap)
  local gameArea = insetRect(layout.gameWindow, spacing.itemGap)
  local actionsArea = insetRect(layout.actions, spacing.itemGap)
  local buttonLayout = self:getButtonLayout(app)
  local mouseX, mouseY = love.mouse.getPosition()

  self:drawScorePanel(app, scoreArea)

  Panel.draw(statsArea.x, statsArea.y, statsArea.width, statsArea.height, app.currentStageDefinition.label)

  local stageArea = Panel.getContentArea(statsArea.x, statsArea.y, statsArea.width, statsArea.height, app.currentStageDefinition.label)

  self:drawStageSummary(app, stageArea)

  Panel.draw(controlsArea.x, controlsArea.y, controlsArea.width, controlsArea.height)

  Panel.draw(gameArea.x, gameArea.y, gameArea.width, gameArea.height, "Hand")

  local coinRowArea = Panel.getContentArea(gameArea.x, gameArea.y, gameArea.width, gameArea.height, "Hand")

  local hoveredCoinId = self:drawCoinRow(app, coinRowArea.x, coinRowArea.y, coinRowArea.width, coinRowArea.height)

  Panel.draw(actionsArea.x, actionsArea.y, actionsArea.width, actionsArea.height)

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(self.statusMessage, actionsArea.x + spacing.itemGap, actionsArea.y + spacing.itemGap, math.max(1, actionsArea.width - (spacing.itemGap * 2)), "center")

  Button.drawButtons(self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width, buttonLayout.height), mouseX, mouseY)

  Button.drawButtons({ self:getLogButtonLayout(app), self:getPurseButtonLayout(app), self:getHelpButtonLayout(app) }, mouseX, mouseY)
  if hoveredCoinId and not self.draggingHandCoinId then
    self:drawCoinDetailOverlay(app, hoveredCoinId, mouseX, mouseY)
  end
  self:drawHelpDialog(app)
  self:drawPurseDialog(app)
  self:drawLogDialog(app)
end

function StageState:mousepressed(app, x, y, button)
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
    local dialog = self:getHelpDialogLayout(app)
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

  handled = Button.handleMousePressed({ self:getLogButtonLayout(app), self:getPurseButtonLayout(app), self:getHelpButtonLayout(app) }, x, y)

  if handled then
    return
  end

  if Button.handleMousePressed(self.handActionButtons, x, y) then
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

  if toSlotIndex and toSlotIndex ~= fromSlotIndex then
    self:tryMoveSlotTo(app, fromSlotIndex, toSlotIndex)
    return
  end

  local targetCard = self:getHandCardAtPoint(x, y)

  if targetCard and targetCard.movable and targetCard.slotIndex ~= fromSlotIndex then
    self:tryMoveSlotTo(app, fromSlotIndex, targetCard.slotIndex)
  end
end

return StageState
