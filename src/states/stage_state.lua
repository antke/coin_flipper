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
    helpDialogOpen = false,
    coinRowReveal = nil,
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
    betResult = batchResult.betResult,
    coins = coins,
  }
end

function StageState:startCoinRowReveal(app, batchResult)
  local coinCount = #(batchResult.perCoin or {})

  self.coinRowReveal = {
    batchId = batchResult.batchId,
    elapsed = 0,
    revealDuration = app.config.get("ui.batchRevealDuration", 0.75),
    coinCount = coinCount,
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

  local batchResult, errorMessage = app:resolveCurrentBatch(app.selectedCall)

  if not batchResult then
    self.statusMessage = errorMessage
    return false, errorMessage
  end

  self.statusMessage = string.format(
    "Resolved batch %d. Stage score %d/%d. Flips remaining: %d.",
    batchResult.batchId,
    app.stageState.stageScore,
    app.stageState.targetScore,
    app.stageState.flipsRemaining
  )

  self:startCoinRowReveal(app, batchResult)

  if batchResult.status ~= "active" then
    self:startReveal(app, batchResult)
  else
    self.reveal = nil
  end

  return true, batchResult
end

function StageState:buildButtons(app, x, y, width)
  local gap = Theme.spacing.itemGap
  local buttonWidth = math.floor((width - gap) / 2)
  local buttonHeight = 42
  local stageActive = self:isStageActive(app)
  local revealActive = self:isRevealActive()

  self.buttons = {
    {
      x = x,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "HEADS",
      variant = app.selectedCall == "heads" and "primary" or "default",
      focused = app.selectedCall == "heads",
      disabled = not stageActive or revealActive,
      onClick = function()
        return self:callAndResolve(app, "heads")
      end,
    },
    {
      x = x + buttonWidth + gap,
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = "TAILS",
      variant = app.selectedCall == "tails" and "primary" or "default",
      focused = app.selectedCall == "tails",
      disabled = not stageActive or revealActive,
      onClick = function()
        return self:callAndResolve(app, "tails")
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

function StageState:buildBetButtons(app, x, y, width)
  local bets = app:getBetOptions()
  local gap = Theme.spacing.itemGap
  local buttonCount = math.max(1, #bets)
  local buttonWidth = math.floor((width - (gap * (buttonCount - 1))) / buttonCount)
  local buttonHeight = 34
  local stageActive = self:isStageActive(app)
  local revealActive = self:isRevealActive()
  local selectedBet = app:getSelectedBet()
  local buttons = {}

  for index, bet in ipairs(bets) do
    local canSelect = app:canSelectBet(bet.id)
    local label = bet.shortLabel or string.upper(bet.name or bet.id)

    if bet.stake and bet.stake > 0 then
      label = string.format("%s (-%d/+%d)", label, bet.stake, bet.winAmount or 0)
    end

    table.insert(buttons, {
      x = x + ((index - 1) * (buttonWidth + gap)),
      y = y,
      width = buttonWidth,
      height = buttonHeight,
      label = label,
      variant = selectedBet and selectedBet.id == bet.id and "accent" or "default",
      focused = selectedBet and selectedBet.id == bet.id,
      disabled = not stageActive or revealActive or not canSelect,
      onClick = function()
        local ok, result = app:selectBet(bet.id)
        self.statusMessage = ok and string.format("Selected bet: %s.", result.name or bet.name or bet.id) or tostring(result)
        return ok, result
      end,
    })
  end

  return buttons
end

function StageState:getButtonLayout(app)
  local padding = Theme.spacing.screenPadding
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()

  return {
    x = padding,
    y = height - padding - 42,
    width = width - (padding * 2),
  }
end

function StageState:getHelpButtonLayout()
  local padding = Theme.spacing.screenPadding
  local size = 40
  local width = love.graphics.getWidth()

  return {
    x = width - padding - size,
    y = padding,
    width = size,
    height = size,
    label = "?",
    variant = self.helpDialogOpen and "primary" or "default",
    onClick = function()
      self.helpDialogOpen = not self.helpDialogOpen
      return true
    end,
  }
end

function StageState:getHelpDialogLines(app)
  local lines = {
    "You are trying to hit the target score before flips run out.",
    "Pick HEADS or TAILS. Each pick resolves the full equipped coin batch.",
    "Stage score also becomes chips for the shop.",
    "Optional bets can add or lose chips after scoring.",
    "",
    "Current Breakdown:",
  }

  for _, line in ipairs(app:getScoreBreakdownLines(10)) do
    table.insert(lines, line)
  end

  table.insert(lines, "")
  table.insert(lines, "Controls:")
  table.insert(lines, "- Click HEADS or TAILS: call and flip")
  table.insert(lines, "- Left / H: call HEADS and flip")
  table.insert(lines, "- Right / T: call TAILS and flip")
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

function StageState:getHelpDialogLayout()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local padding = Theme.spacing.screenPadding
  local dialogWidth = math.min(700, math.max(280, width - (padding * 4)))
  local dialogHeight = math.min(460, math.max(260, height - (padding * 4)))

  return {
    x = math.floor((width - dialogWidth) / 2),
    y = math.floor((height - dialogHeight) / 2),
    width = dialogWidth,
    height = dialogHeight,
  }
end

function StageState:drawHelpDialog(app)
  if not self.helpDialogOpen then
    return
  end

  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local dialog = self:getHelpDialogLayout()
  local contentArea = Panel.getContentArea(dialog.x, dialog.y, dialog.width, dialog.height, "Help")
  local closeButton = self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width)
  local mouseX, mouseY = love.mouse.getPosition()

  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, width, height)

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

function StageState:getHelpDialogCloseButton(dialogX, dialogY, dialogWidth)
  local size = 32

  return {
    x = dialogX + dialogWidth - Theme.spacing.panelPadding - size,
    y = dialogY + Theme.spacing.panelPadding - 4,
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

function StageState:drawStageSummary(app, area)
  local stage = app.stageState
  local scoreColor = stage.stageScore >= stage.targetScore and Theme.colors.success or Theme.colors.text
  local stats = {
    { label = "Score", value = string.format("%d/%d", stage.stageScore, stage.targetScore), color = scoreColor },
    { label = "Chips", value = tostring(app.runState and app.runState.shopPoints or 0), color = Theme.colors.text },
    { label = "Flips", value = tostring(stage.flipsRemaining), color = Theme.colors.text },
    { label = "Call", value = string.upper(app.selectedCall), color = Theme.colors.text },
  }

  local statGap = Theme.spacing.itemGap
  local statWidth = math.floor((area.width - (statGap * (#stats - 1))) / #stats)
  local statHeight = 48
  local statY = area.y

  for index, stat in ipairs(stats) do
    local statX = area.x + ((index - 1) * (statWidth + statGap))

    setColorWithAlpha(Theme.colors.panelBorder, 0.16)
    love.graphics.rectangle("fill", statX, statY, statWidth, statHeight, 10, 10)
    Theme.applyColor(Theme.colors.panelBorder)
    love.graphics.rectangle("line", statX, statY, statWidth, statHeight, 10, 10)

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf(stat.label, statX + 8, statY + 7, statWidth - 16, "center")

    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(stat.color)
    love.graphics.printf(stat.value, statX + 8, statY + 24, statWidth - 16, "center")
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

  if batchResult and batchResult.perCoin then
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

  for slotIndex = 1, app.runState.maxActiveCoinSlots do
    local coinId = app.runState.equippedCoinSlots[slotIndex]

    if coinId then
      table.insert(coins, {
        coinId = coinId,
        slotIndex = slotIndex,
      })
    end
  end

  return coins, nil, nil
end

function StageState:drawCoinRow(app, x, y, width, height)
  local coins, call, batchId = self:getVisibleCoinStates(app)

  if #coins == 0 then
    love.graphics.setFont(app.fonts.body)
    Theme.applyColor(Theme.colors.mutedText)
    love.graphics.printf("No coins equipped.", x, y + math.floor(height / 2) - 10, width, "center")
    return
  end

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)

  local title = call and string.format("Last flip: %s", string.upper(call)) or "Ready coins"
  local titleHeight = 20
  love.graphics.printf(title, x, y, width, "center")

  local cardGap = Theme.spacing.itemGap
  local maxCardHeight = math.max(132, height - titleHeight - 18)
  local cardHeight = math.min(210, maxCardHeight)
  local availableCardWidth = math.floor((width - (cardGap * (#coins - 1))) / #coins)
  local cardWidth = math.min(190, availableCardWidth, math.floor(cardHeight * 0.92))
  cardWidth = math.max(82, cardWidth)
  cardHeight = math.max(132, cardHeight)
  local totalWidth = (cardWidth * #coins) + (cardGap * (#coins - 1))
  local startX = x + math.floor((width - totalWidth) / 2)
  local cardY = y + titleHeight + math.floor((height - titleHeight - cardHeight) / 2)
  local reveal = self.coinRowReveal
  local visibleCount = #coins

  if reveal and reveal.batchId == batchId then
    local revealRatio = math.min(1, reveal.elapsed / math.max(reveal.revealDuration, 0.001))
    visibleCount = math.min(#coins, math.floor(revealRatio * math.max(1, #coins - 1)) + 1)
  end

  for index, coin in ipairs(coins) do
    local cardX = startX + ((index - 1) * (cardWidth + cardGap))
    local hasResult = coin.result ~= nil and index <= visibleCount
    local borderColor = Theme.colors.panelBorder
    local fillColor = Theme.colors.panel
    local artSide = nil
    local artSelected = false
    local revealAge = reveal and reveal.batchId == batchId and reveal.elapsed - ((index - 1) * (reveal.revealDuration / math.max(1, #coins))) or nil

    if hasResult then
      borderColor = coin.didMatch and Theme.colors.success or Theme.colors.danger
      fillColor = borderColor
      artSide = coin.result
      artSelected = coin.didMatch
      setColorWithAlpha(fillColor, 0.16)
    else
      setColorWithAlpha(fillColor, 0.82)
    end

    love.graphics.rectangle("fill", cardX, cardY, cardWidth, cardHeight, 12, 12)
    Theme.applyColor(borderColor)
    love.graphics.setLineWidth(hasResult and 2 or 1)
    love.graphics.rectangle("line", cardX, cardY, cardWidth, cardHeight, 12, 12)
    love.graphics.setLineWidth(1)

    local coinSize = math.min(84, math.max(58, math.floor(cardWidth * 0.46)))
    CoinArt.draw(coin.coinId, cardX + math.floor((cardWidth - coinSize) / 2), cardY + 34, coinSize, {
      side = artSide,
      selected = artSelected,
      alpha = hasResult and 1.0 or 0.72,
      tilt = hasResult and ((index % 2 == 0) and 0.08 or -0.08) or 0,
    })

    if hasResult and coin.didMatch and revealAge and revealAge >= 0 and revealAge <= 0.42 then
      self:drawMatchParticles(cardX, cardY, cardWidth, cardHeight, revealAge)
    end

    love.graphics.setFont(app.fonts.small)
    Theme.applyColor(Theme.colors.text)
    love.graphics.printf(app:getCoinName(coin.coinId), cardX + 8, cardY + cardHeight - 60, cardWidth - 16, "center")

    if hasResult then
      Theme.applyColor(coin.didMatch and Theme.colors.success or Theme.colors.mutedText)
      love.graphics.printf(coin.didMatch and "MATCH" or "MISS", cardX + 8, cardY + cardHeight - 36, cardWidth - 16, "center")

      if coin.forcedResult then
        Theme.applyColor(Theme.colors.warning)
        love.graphics.printf("FORCED", cardX + 8, cardY + cardHeight - 18, cardWidth - 16, "center")
      end
    else
      Theme.applyColor(Theme.colors.mutedText)
      love.graphics.printf("waiting", cardX + 8, cardY + cardHeight - 36, cardWidth - 16, "center")
    end
  end
end

function StageState:drawMatchParticles(cardX, cardY, cardWidth, cardHeight, age)
  local alpha = math.max(0, 1 - (age / 0.42))
  local centerX = cardX + math.floor(cardWidth / 2)
  local centerY = cardY + math.floor(cardHeight / 2)
  local particles = {
    { -44, -28 },
    { -28, 34 },
    { 36, -32 },
    { 48, 22 },
    { -8, -52 },
    { 10, 48 },
  }

  Theme.applyColor({ Theme.colors.success[1], Theme.colors.success[2], Theme.colors.success[3], alpha })

  for index, particle in ipairs(particles) do
    local drift = math.floor(age * 46)
    local sparkleSize = index % 2 == 0 and 4 or 3
    local px = centerX + particle[1] + (particle[1] >= 0 and drift or -drift)
    local py = centerY + particle[2] + (particle[2] >= 0 and drift or -drift)

    love.graphics.rectangle("fill", px, py, sparkleSize, sparkleSize)
  end
end

function StageState:enter(app)
  app:ensureCurrentStage()
  self.reveal = nil
  self.helpDialogOpen = false
  self.statusMessage = "Pick HEADS or TAILS. One click resolves the full batch."
end

function StageState:update(app, dt)
  if self.coinRowReveal then
    self.coinRowReveal.elapsed = self.coinRowReveal.elapsed + dt

    if self.coinRowReveal.elapsed >= self.coinRowReveal.revealDuration + 0.45 then
      self.coinRowReveal = nil
    end
  end

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
    string.format("Chips: %d", reveal.shopPoints or 0),
    string.format("Flips remaining: %d", reveal.flipsRemaining),
  }

  if reveal.betResult and reveal.betResult.id ~= "none" then
    table.insert(statsLines, string.format("Bet: %s (%s %+d)", reveal.betResult.name or reveal.betResult.id, reveal.betResult.outcome or "none", reveal.betResult.amount or 0))
  end

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

end

function StageState:keypressed(app, key)
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
    self:callAndResolve(app, "heads")
    return
  end

  if key == "right" or key == "t" then
    self:callAndResolve(app, "tails")
    return
  end

  if key == "space" or key == "return" or key == "kpenter" then
    self:tryResolveBatch(app)
  end
end

function StageState:draw(app)
  local padding = Theme.spacing.screenPadding
  local gap = Theme.spacing.blockGap
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local topY = 72
  local availableHeight = height - topY - padding
  local topHeight = app.stageState and app.stageState.stageType == "boss" and 150 or 112
  topHeight = math.min(topHeight, math.max(80, math.floor((availableHeight - gap) * 0.35)))
  local panelWidth = width - (padding * 2)
  local buttonLayout = self:getButtonLayout(app)
  local coinRowY = topY + topHeight + gap
  local betButtonY = buttonLayout.y - 44
  local coinRowBottom = betButtonY - 42
  local coinRowHeight = math.max(120, coinRowBottom - coinRowY)
  local mouseX, mouseY = love.mouse.getPosition()

  love.graphics.setFont(app.fonts.heading)
  Theme.applyColor(Theme.colors.text)
  love.graphics.print(app.currentStageDefinition.label, padding, padding + 4)

  Panel.draw(padding, topY, panelWidth, topHeight, "Stage")

  local stageArea = Panel.getContentArea(padding, topY, panelWidth, topHeight, "Stage")

  self:drawStageSummary(app, stageArea)
  self:drawCoinRow(app, padding, coinRowY, panelWidth, coinRowHeight)

  love.graphics.setFont(app.fonts.small)
  Theme.applyColor(Theme.colors.mutedText)
  love.graphics.printf(self.statusMessage, padding, betButtonY - 26, panelWidth, "center")

  Button.drawButtons(self:buildBetButtons(app, buttonLayout.x, betButtonY, buttonLayout.width), mouseX, mouseY)
  Button.drawButtons(self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width), mouseX, mouseY)

  Button.drawButtons({ self:getHelpButtonLayout() }, mouseX, mouseY)
  self:drawHelpDialog(app)
end

function StageState:mousepressed(app, x, y, button)
  if button ~= 1 then
    return
  end

  local handled = false

  if self.helpDialogOpen then
    local dialog = self:getHelpDialogLayout()

    handled = Button.handleMousePressed({ self:getHelpDialogCloseButton(dialog.x, dialog.y, dialog.width) }, x, y)

    if not handled and (x < dialog.x or x > dialog.x + dialog.width or y < dialog.y or y > dialog.y + dialog.height) then
      self.helpDialogOpen = false
    end

    return
  end

  handled = Button.handleMousePressed({ self:getHelpButtonLayout() }, x, y)

  if handled then
    return
  end

  local buttonLayout = self:getButtonLayout(app)
  local betButtonY = buttonLayout.y - 44
  local handledBet = Button.handleMousePressed(self:buildBetButtons(app, buttonLayout.x, betButtonY, buttonLayout.width), x, y)

  if handledBet then
    return
  end

  Button.handleMousePressed(self:buildButtons(app, buttonLayout.x, buttonLayout.y, buttonLayout.width), x, y)
end

return StageState
