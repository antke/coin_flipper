local Button = require("src.ui.button")
local CoinArt = require("src.ui.coin_art")
local Layout = require("src.ui.layout")
local Panel = require("src.ui.panel")
local Theme = require("src.ui.theme")

local StageState = {}
StageState.__index = StageState

local function setColorWithAlpha(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function routeIfStageComplete(app)
  if app.stageState and app.stageState.stageStatus ~= "active" then
    app.stateGraph:request("stage_complete")
    return true
  end

  return false
end

function StageState.new()
  return setmetatable({
    statusMessage = "",
    buttons = {},
    reveal = nil,
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

function StageState:completeReveal(app)
  if not self:isRevealActive() then
    return false, "reveal_not_active"
  end

  local stageShouldAdvance = app.stageState and app.stageState.stageStatus ~= "active"
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
  return true
end

function StageState:tryResolveBatch(app)
  if self:isRevealActive() then
    return self:completeReveal(app)
  end

  if not self:isStageActive(app) then
    self.statusMessage = "This stage is no longer active."
    return false, "stage_not_active"
  end

  local batchResult, errorMessage = app:resolveCurrentBatch(app.selectedCall)

  if not batchResult then
    self.statusMessage = errorMessage
    return false, errorMessage
  end

  self.statusMessage = string.format(
    "Resolved batch %d. Reveal in progress. Stage score %d/%d. Flips remaining: %d.",
    batchResult.batchId,
    app.stageState.stageScore,
    app.stageState.targetScore,
    app.stageState.flipsRemaining
  )

  self:startReveal(app, batchResult)
  return true, batchResult
end

function StageState:buildButtons(app, x, y, width)
  local gap = Theme.spacing.itemGap
  local buttonWidth = math.floor((width - (gap * 2)) / 3)
  local buttonHeight = 42
  local stageActive = self:isStageActive(app)
  local revealActive = self:isRevealActive()

  self.buttons = {
    {
      x = x,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Call Heads",
      variant = app.selectedCall == "heads" and "primary" or "default",
      focused = app.selectedCall == "heads",
      disabled = not stageActive or revealActive,
      onClick = function()
        return self:selectCall(app, "heads")
      end,
    },
    {
      x = x + buttonWidth + gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "Call Tails",
      variant = app.selectedCall == "tails" and "primary" or "default",
      focused = app.selectedCall == "tails",
      disabled = not stageActive or revealActive,
      onClick = function()
        return self:selectCall(app, "tails")
      end,
    },
    {
      x = x + ((buttonWidth + gap) * 2),
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = revealActive and (self.reveal and self.reveal.stageStatus ~= "active" and "Continue" or "Skip Reveal") or "Resolve Batch",
      variant = revealActive and "warning" or "success",
      disabled = not stageActive and not revealActive,
      onClick = function()
        return self:tryResolveBatch(app)
      end,
    },
  }

  return self.buttons
end

function StageState:getButtonLayout(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local topY = 84
  local availableHeight = height - topY - padding
  local topHeight = math.floor((availableHeight - gap) * 0.44)
  local bottomY = topY + topHeight + gap
  local bottomHeight = availableHeight - topHeight - gap
  local bottomArea = Panel.getContentArea(padding, bottomY, width - (padding * 2), bottomHeight, "Breakdown + Controls")
  local footerMetrics = Layout.getFooterMetrics(bottomArea.height, {
    bottomPadding = 0,
    extraSpacing = 0,
  })

  return {
    x = bottomArea.x,
    y = bottomArea.y + footerMetrics.buttonY,
    width = bottomArea.width,
    textHeight = math.max(0, footerMetrics.contentBottomY),
  }
end

function StageState:enter(app)
  app:ensureCurrentStage()
  self.reveal = nil
  self.statusMessage = "Choose Heads or Tails with buttons or Left/Right (H/T), then resolve with the button or Space."
end

function StageState:update(app, dt)
  if not self:isRevealActive() then
    return
  end

  self.reveal.elapsed = self.reveal.elapsed + dt

  if self.reveal.elapsed >= self.reveal.finishDuration then
    self:completeReveal(app)
  end
end

function StageState:drawRevealOverlay(app)
  if not self:isRevealActive() then
    return
  end

  local reveal = self.reveal
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local overlayWidth = math.min(760, width - (padding * 4))
  local overlayHeight = math.min(340, height - (padding * 6))
  local overlayX = math.floor((width - overlayWidth) / 2)
  local overlayY = math.floor((height - overlayHeight) / 2)
  local contentArea = Panel.getContentArea(overlayX, overlayY, overlayWidth, overlayHeight, "Batch Reveal")
  local pulse = app:getUiPulse(5.2, 0.10, 0.22)
  local coinCount = math.max(1, #reveal.coins)
  local revealRatio = math.min(1, reveal.elapsed / math.max(reveal.revealDuration, 0.001))
  local visibleCount = math.min(coinCount, math.floor(revealRatio * math.max(1, coinCount - 1)) + 1)

  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, width, height)

  Panel.draw(overlayX, overlayY, overlayWidth, overlayHeight, "Batch Reveal")

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
  love.graphics.printf(string.format("Batch %d", reveal.batchId), contentArea.x + 14, contentArea.y + 10, contentArea.width - 28, "right")

  local statsY = contentArea.y + 56
  local statsLines = {
    string.format("Stage delta: %+d", reveal.stageDelta),
    string.format("Stage score: %d/%d", reveal.stageScore, reveal.targetScore),
    string.format("Run total: %d", reveal.runTotalScore),
    string.format("Flips remaining: %d", reveal.flipsRemaining),
  }

  if reveal.stageStatus ~= "active" then
    table.insert(statsLines, string.format("Outcome: %s", string.upper(reveal.stageStatus)))
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
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.print(string.format("Slot %d • Order %d", coin.slotIndex or 0, coin.resolutionIndex or 0), cardX + 10, cardY + 8)
    CoinArt.draw(coin.coinId, cardX + math.floor((cardWidth - 38) / 2), cardY + 28, 38, {
      side = revealed and coin.result or nil,
      selected = revealed and coin.didMatch,
      alpha = revealed and 1.0 or 0.55,
      tilt = revealed and ((index % 2 == 0) and 0.10 or -0.10) or 0,
    })
    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.text)
    love.graphics.printf(app:getCoinName(coin.coinId), cardX + 8, cardY + 68, cardWidth - 16, "center")

    if revealed then
      love.graphics.setFont(app.fonts.small)
      Theme.applyColor(coin.didMatch and Theme.colors.success or Theme.colors.mutedText)
      love.graphics.printf(coin.didMatch and "MATCH" or "MISS", cardX + 10, cardY + 86, cardWidth - 20, "center")

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

  local footerY = overlayY + overlayHeight - 34
  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  local footerText = reveal.stageStatus ~= "active"
    and "Press Enter, Space, or click Continue to finish the reveal."
    or "Press Enter, Space, or click Skip Reveal to continue immediately."
  love.graphics.printf(footerText, overlayX + padding, footerY, overlayWidth - (padding * 2), "center")
end

function StageState:keypressed(app, key)
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
      self.statusMessage = ok and string.format("Dev: granted +%d shop points.", result) or tostring(result)
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

      self.statusMessage = string.format("Dev: simulated %d batch(es).", result.resolvedCount or 0)
      routeIfStageComplete(app)
      return
    end

    if key == "f9" then
      local ok, result = app:debugPrintFullBatchTrace()
      self.statusMessage = ok and string.format("Dev: dumped batch %s trace to logs.", tostring(result)) or tostring(result)
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

function StageState:draw(app)
  local activeUpgradeNames = app:getActiveUpgradeNames()
  local activeModifierNames = app:getActiveModifierNames()
  local activeModifierDetailLines = app:getActiveModifierDetailLines()
  local activeTemporaryEffectLines = app:getActiveTemporaryEffectLines()
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local topY = 84
  local availableHeight = height - topY - padding
  local columnWidth = math.floor((width - (padding * 2) - (gap * 2)) / 3)
  local topHeight = math.floor((availableHeight - gap) * 0.44)
  local bottomY = topY + topHeight + gap
  local bottomHeight = availableHeight - topHeight - gap
  local leftX = padding
  local middleX = leftX + columnWidth + gap
  local rightX = middleX + columnWidth + gap
  local rightWidth = width - rightX - padding

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(app.currentStageDefinition.label, padding, padding)

  Panel.draw(leftX, topY, columnWidth, topHeight, "Stage")
  Panel.draw(middleX, topY, columnWidth, topHeight, "Build + Modifiers")
  Panel.draw(rightX, topY, rightWidth, topHeight, "Last Batch")
  Panel.draw(padding, bottomY, width - (padding * 2), bottomHeight, "Breakdown + Controls")

  local stageArea = Panel.getContentArea(leftX, topY, columnWidth, topHeight, "Stage")
  local buildArea = Panel.getContentArea(middleX, topY, columnWidth, topHeight, "Build + Modifiers")
  local batchArea = Panel.getContentArea(rightX, topY, rightWidth, topHeight, "Last Batch")
  local bottomArea = Panel.getContentArea(padding, bottomY, width - (padding * 2), bottomHeight, "Breakdown + Controls")

  local stageLines = {
    string.format("Target Score: %d", app.stageState.targetScore),
    string.format("Stage Score: %d", app.stageState.stageScore),
    string.format("Run Total Score: %d", app.runState.runTotalScore),
    string.format("Flips Remaining: %d", app.stageState.flipsRemaining),
    string.format("Shop Points: %d", app.runState.shopPoints),
    string.format("Current Call: %s", string.upper(app.selectedCall)),
    string.format("Batch Index: %d", app.stageState.batchIndex),
  }

  local stageTextY = stageArea.y
  local stageTextHeight = stageArea.height

  if app.stageState.stageType == "boss" then
    local pulse = app:getUiPulse(4.8, 0.10, 0.22)
    local bannerHeight = 56
    local bossCards = app:getBossModifierCards()

    love.graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.16 + pulse)
    love.graphics.rectangle("fill", stageArea.x, stageArea.y, stageArea.width, bannerHeight, 10, 10)
    love.graphics.setColor(Theme.colors.warning[1], Theme.colors.warning[2], Theme.colors.warning[3], 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", stageArea.x, stageArea.y, stageArea.width, bannerHeight, 10, 10)
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.text)
    love.graphics.print("BOSS PRESSURE ACTIVE", stageArea.x + 14, stageArea.y + 8)
    Theme.applyColor(Theme.colors.warning)
    love.graphics.printf(string.format("%d boss modifier(s) active", #bossCards), stageArea.x + 14, stageArea.y + 28, stageArea.width - 28, "left")

    stageTextY = stageArea.y + bannerHeight + 10
    stageTextHeight = math.max(0, stageArea.height - bannerHeight - 10)
    table.insert(stageLines, 1, string.format("Boss Modifiers: %d", #bossCards))
  end

  Layout.drawWrappedLines(stageLines, stageArea.x, stageTextY, stageArea.width, Theme.colors.text, Theme.spacing.lineHeight, stageTextHeight)

  local buildLines = {
    string.format("Equipped: %s", app:getCurrentLoadoutKey()),
    "",
  }

  for _, coinName in ipairs(app:getEquippedCoinNames()) do
    table.insert(buildLines, string.format("- %s", coinName))
  end

  if #activeUpgradeNames > 0 then
    table.insert(buildLines, "")
    table.insert(buildLines, "Upgrades:")

    for _, upgradeName in ipairs(activeUpgradeNames) do
      table.insert(buildLines, string.format("- %s", upgradeName))
    end
  end

  if #activeModifierNames > 0 then
    table.insert(buildLines, "")
    table.insert(buildLines, "Modifiers:")

    for _, modifierName in ipairs(activeModifierNames) do
      table.insert(buildLines, string.format("- %s", modifierName))
    end
  end

  if #activeModifierDetailLines > 0 then
    table.insert(buildLines, "")

    for _, line in ipairs(activeModifierDetailLines) do
      table.insert(buildLines, line)
    end
  end

  if #activeTemporaryEffectLines > 0 then
    table.insert(buildLines, "")
    table.insert(buildLines, "Temporary Effects:")

    for _, line in ipairs(activeTemporaryEffectLines) do
      table.insert(buildLines, line)
    end
  end

  Layout.drawWrappedLines(buildLines, buildArea.x, buildArea.y, buildArea.width, Theme.colors.text, Theme.spacing.lineHeight, buildArea.height)

  Layout.drawWrappedLines(
    app:getLastBatchSummaryLines(14),
    batchArea.x,
    batchArea.y,
    batchArea.width,
    Theme.colors.text,
    Theme.spacing.lineHeight,
    batchArea.height
  )

  local controlLines = {
    "Breakdown:",
  }

  for _, line in ipairs(app:getScoreBreakdownLines(8)) do
    table.insert(controlLines, line)
  end

  table.insert(controlLines, "")
  table.insert(controlLines, "Controls:")

  local controls = {
    "- Left / H: choose Heads",
    "- Right / T: choose Tails",
    "- Space / Enter: resolve batch",
  }

  if app:isDevControlsEnabled() then
    table.insert(controls, "- F3: toggle debug overlay")
  end

  for _, line in ipairs(app:getDebugControlLines()) do
    table.insert(controls, line)
  end

  for _, line in ipairs(controls) do
    table.insert(controlLines, line)
  end

  table.insert(controlLines, "")
  table.insert(controlLines, self.statusMessage)

  local buttonLayout = self:getButtonLayout(app)
  local textHeight = buttonLayout.textHeight

  Layout.drawWrappedLines(
    controlLines,
    bottomArea.x,
    bottomArea.y,
    bottomArea.width,
    Theme.colors.text,
    Theme.spacing.lineHeight,
    textHeight
  )

  local mouseX, mouseY = love.mouse.getPosition()
  Button.drawButtons(self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width), mouseX, mouseY)

  self:drawRevealOverlay(app)
end

function StageState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local buttonLayout = self:getButtonLayout(app)
  Button.handleMousePressed(self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width), x, y)
end

return StageState
