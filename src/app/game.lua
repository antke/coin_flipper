local Bosses = require("src.content.bosses")
local AudioSystem = require("src.systems.audio_system")
local Coins = require("src.content.coins")
local EncounterSystem = require("src.systems.encounter_system")
local DebugOverlay = require("src.ui.debug_overlay")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local Loadout = require("src.domain.loadout")
local LoadoutSystem = require("src.systems.loadout_system")
local Log = require("src.core.log")
local MetaProgressionSystem = require("src.systems.meta_progression_system")
local MetaState = require("src.domain.meta_state")
local MetaUpgrades = require("src.content.meta_upgrades")
local ProgressionSystem = require("src.systems.progression_system")
local RNG = require("src.core.rng")
local RewardSystem = require("src.systems.reward_system")
local RunHistorySystem = require("src.systems.run_history_system")
local RunInitializer = require("src.systems.run_initializer")
local SaveSystem = require("src.systems.save_system")
local FlipResolver = require("src.systems.flip_resolver")
local ShopFlowSystem = require("src.systems.shop_flow_system")
local ShopSystem = require("src.systems.shop_system")
local StageModifiers = require("src.content.stage_modifiers")
local Stages = require("src.content.stages")
local StateGraph = require("src.app.state_graph")
local StepBuilder = require("src.app.step_builder")
local SummarySystem = require("src.systems.summary_system")
local Theme = require("src.ui.theme")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local Game = {}
Game.__index = Game

local function createFonts()
  return {
    title = love.graphics.newFont(Theme.fontSizes.title),
    heading = love.graphics.newFont(Theme.fontSizes.heading),
    body = love.graphics.newFont(Theme.fontSizes.body),
    small = love.graphics.newFont(Theme.fontSizes.small),
  }
end

local function createMenuMetaFlowContext()
  return {
    source = "menu",
    returnState = "menu",
    allowStartRun = false,
  }
end

local function createSummaryMetaFlowContext()
  return {
    source = "summary",
    returnState = "summary",
    allowStartRun = true,
  }
end

function Game.new()
  local logger = Log.new({
    enabled = GameConfig.get("debug.logEnabled"),
    overlayEnabled = GameConfig.get("debug.overlayEnabled"),
    maxEntries = GameConfig.get("debug.maxLogEntries"),
  })

  local self = setmetatable({
    config = GameConfig,
    logger = logger,
    fonts = nil,
    stateGraph = nil,
    debugOverlay = nil,
    audioSystem = AudioSystem.new(GameConfig.get("audio", {})),
    metaState = MetaState.new(),
    metaProjection = nil,
    runState = nil,
    runRng = nil,
    stageState = nil,
    currentStageDefinition = nil,
    selectedCall = "heads",
    lastBatchResult = nil,
    lastStageResult = nil,
    rewardPreviewSession = nil,
    encounterSession = nil,
    shopOffers = {},
    shopSession = nil,
    lastShopGenerationTrace = nil,
    lastShopPurchaseTrace = nil,
    metaFlowContext = createMenuMetaFlowContext(),
    feedbackClock = 0,
    activeFeedback = nil,
    screenFlash = {
      color = Theme.colors.accent,
      alpha = 0,
    },
    metaSaveStatus = {
      level = "info",
      message = "Meta save not loaded yet.",
    },
    activeRunArtifact = nil,
    activeRunSaveAvailable = false,
  }, Game)

  self.stateGraph = StateGraph.new(self, StepBuilder, logger)
  self.debugOverlay = DebugOverlay.new(self)

  return self
end

function Game:registerStates()
  self.stateGraph:register("boot", require("src.states.boot_state").new())
  self.stateGraph:register("menu", require("src.states.menu_state").new())
  self.stateGraph:register("loadout", require("src.states.loadout_state").new())
  self.stateGraph:register("boss_warning", require("src.states.boss_warning_state").new())
  self.stateGraph:register("stage", require("src.states.stage_state").new())
  self.stateGraph:register("result", require("src.states.result_state").new())
  self.stateGraph:register("post_stage_analytics", require("src.states.post_stage_analytics_state").new())
  self.stateGraph:register("reward_preview", require("src.states.reward_preview_state").new())
  self.stateGraph:register("boss_reward", require("src.states.boss_reward_state").new())
  self.stateGraph:register("encounter", require("src.states.encounter_state").new())
  self.stateGraph:register("shop", require("src.states.shop_state").new())
  self.stateGraph:register("summary", require("src.states.summary_state").new())
  self.stateGraph:register("meta", require("src.states.meta_state").new())
end

function Game:validateContentRegistries()
  local registries = {
    coins = Coins.getAll(),
    upgrades = Upgrades.getAll(),
    bosses = Bosses.getAll(),
    stage_modifiers = StageModifiers.getAll(),
    stages = Stages.getAll(),
    meta_upgrades = MetaUpgrades.getAll(),
  }

  for name, definitions in pairs(registries) do
    local ok, errorMessage = Validator.validateContentRegistry(name, definitions)

    if not ok then
      error(errorMessage)
    end

    self.logger:info("Validated content registry", { registry = name, count = #definitions })
  end

  self.logger:info("Hook phases ready", { count = #HookRegistry.PHASES })
end

function Game:updateMetaSaveStatus(level, message)
  self.metaSaveStatus = {
    level = level or "info",
    message = message or "",
  }
end

function Game:loadMetaState()
  local metaState, errorMessage = SaveSystem.loadMetaState()

  if metaState then
    self.metaState = metaState
    self:updateMetaSaveStatus("info", "Loaded meta save from disk.")
    self.logger:info("Loaded meta save", { path = SaveSystem.META_STATE_PATH })
    return true
  end

  if errorMessage == "not_found" then
    self.metaState = MetaState.new()
    self:updateMetaSaveStatus("info", "No meta save found yet; starting fresh.")
    self.logger:info("No meta save found; using defaults", { path = SaveSystem.META_STATE_PATH })
    return false
  end

  self.metaState = MetaState.new()
  self:updateMetaSaveStatus("warn", "Meta save load failed; using defaults.")
  self.logger:warn("Failed to load meta save", { error = errorMessage or "unknown", path = SaveSystem.META_STATE_PATH })
  return false
end

function Game:saveMetaState(reason)
  local ok, errorMessage = SaveSystem.saveMetaState(self.metaState)

  if ok then
    self:updateMetaSaveStatus("info", string.format("Autosaved meta progress (%s).", reason or "manual"))
    self.logger:info("Saved meta state", { reason = reason or "manual", path = SaveSystem.META_STATE_PATH })
    return true
  end

  self:updateMetaSaveStatus("warn", string.format("Meta save failed (%s).", reason or "manual"))
  self.logger:warn("Failed to save meta state", { reason = reason or "manual", error = errorMessage or "unknown" })
  return false, errorMessage
end

function Game:hasActiveRunSave()
  return self.activeRunSaveAvailable == true and self.activeRunArtifact ~= nil
end

function Game:getContinueRunStateName()
  return self.activeRunArtifact and self.activeRunArtifact.currentState or nil
end

function Game:getContinueRunPayload()
  return self.activeRunArtifact and Utils.clone(self.activeRunArtifact.screenState or {}) or {}
end

function Game:getCurrentStateResumePayload()
  local currentName = self.stateGraph and self.stateGraph:getCurrentName() or nil
  local currentState = self.stateGraph and self.stateGraph:getCurrentState() or nil

  if currentName ~= "loadout" or type(currentState) ~= "table" then
    return nil
  end

  return {
    resumeLoadoutState = {
      selectionSlots = Utils.clone(currentState.selectionSlots or {}),
      selectedCollectionIndex = currentState.selectedCollectionIndex,
      collectionScrollOffset = currentState.collectionScrollOffset,
    },
  }
end

function Game:buildActiveRunSnapshot(currentStateName)
  if not self.runState then
    return nil, "run_not_initialized"
  end

  local resumableState = currentStateName or (self.stateGraph and self.stateGraph:getCurrentName()) or nil
  local resumableStates = {
    loadout = true,
    boss_warning = true,
    stage = true,
    result = true,
    post_stage_analytics = true,
    reward_preview = true,
    boss_reward = true,
    shop = true,
  }

  if not resumableStates[resumableState] then
    return nil, "state_not_resumable"
  end

  return {
    artifactType = SaveSystem.ACTIVE_RUN_ARTIFACT_TYPE,
    version = SaveSystem.ACTIVE_RUN_VERSION,
    currentState = resumableState,
    runState = Utils.clone(self.runState),
    stageState = Utils.clone(self.stageState),
    runRngSeed = self.runRng and self.runRng:getSeed() or nil,
    selectedCall = self.selectedCall,
    lastBatchResult = Utils.clone(self.lastBatchResult),
    lastStageResult = Utils.clone(self.lastStageResult),
    rewardPreviewSession = Utils.clone(self.rewardPreviewSession),
    encounterSession = Utils.clone(self.encounterSession),
    shopOffers = Utils.clone(self.shopOffers or {}),
    shopSession = Utils.clone(self.shopSession),
    lastShopGenerationTrace = Utils.clone(self.lastShopGenerationTrace),
    lastShopPurchaseTrace = Utils.clone(self.lastShopPurchaseTrace),
    currentStageDefinitionId = self.currentStageDefinition and (self.currentStageDefinition.variantId or self.currentStageDefinition.id) or nil,
    screenState = self:getCurrentStateResumePayload(),
  }
end

function Game:loadActiveRunArtifact()
  local artifact, errorMessage = SaveSystem.loadActiveRun()

  if artifact then
    self.activeRunArtifact = artifact
    self.activeRunSaveAvailable = true
    self.logger:info("Loaded active run save", { state = artifact.currentState, seed = artifact.runState and artifact.runState.seed or "n/a" })
    return true
  end

  self.activeRunArtifact = nil
  self.activeRunSaveAvailable = false

  if errorMessage ~= "not_found" then
    self.logger:warn("Failed to load active run save", { error = errorMessage or "unknown" })
  end

  return false, errorMessage
end

function Game:saveActiveRun(reason, currentStateName)
  local snapshot, errorMessage = self:buildActiveRunSnapshot(currentStateName)

  if not snapshot then
    return false, errorMessage
  end

  local ok, saveError = SaveSystem.saveActiveRun(snapshot)

  if ok then
    self.activeRunArtifact = snapshot
    self.activeRunSaveAvailable = true
    self.logger:debug("Saved active run", { reason = reason or "manual", state = snapshot.currentState })
    return true
  end

  self.logger:warn("Failed to save active run", { reason = reason or "manual", error = saveError or "unknown" })
  return false, saveError
end

function Game:clearActiveRunSave(reason)
  local ok, errorMessage = SaveSystem.clearActiveRun()

  if ok then
    self.activeRunArtifact = nil
    self.activeRunSaveAvailable = false
    self.logger:debug("Cleared active run save", { reason = reason or "manual" })
    return true
  end

  self.logger:warn("Failed to clear active run save", { reason = reason or "manual", error = errorMessage or "unknown" })
  return false, errorMessage
end

function Game:resumeSavedRun()
  local artifact = self.activeRunArtifact

  if not artifact then
    return false, "continue_run_unavailable"
  end

  self.runState = Utils.clone(artifact.runState)
  self.metaProjection = self.runState and self.runState.metaProjection or nil
  self.runRng = RNG.new(artifact.runRngSeed)
  self.stageState = Utils.clone(artifact.stageState)
  self.currentStageDefinition = nil

  if self.runState then
    self.currentStageDefinition = Stages.getForRound(self.runState.roundIndex, self.runState)
  elseif artifact.currentStageDefinitionId then
    self.currentStageDefinition = Stages.getById(artifact.currentStageDefinitionId)
  elseif self.stageState then
    self.currentStageDefinition = Stages.getById(self.stageState.stageId)
  end

  self.selectedCall = artifact.selectedCall or "heads"
  self.lastBatchResult = Utils.clone(artifact.lastBatchResult)
  self.lastStageResult = Utils.clone(artifact.lastStageResult)
  self.rewardPreviewSession = Utils.clone(artifact.rewardPreviewSession)
  self.encounterSession = Utils.clone(artifact.encounterSession)
  self.shopOffers = Utils.clone(artifact.shopOffers or {})
  self.shopSession = Utils.clone(artifact.shopSession)
  self.lastShopGenerationTrace = Utils.clone(artifact.lastShopGenerationTrace)
  self.lastShopPurchaseTrace = Utils.clone(artifact.lastShopPurchaseTrace)
  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:assertRuntimeInvariants("game.resumeSavedRun", { history = true })
  self.logger:info("Resumed active run", { state = artifact.currentState, seed = self.runState and self.runState.seed or "n/a" })
  return true
end

function Game:load()
  self.fonts = createFonts()
  love.graphics.setFont(self.fonts.body)

  self:registerStates()
  self:validateContentRegistries()
  self:loadMetaState()
  self:loadActiveRunArtifact()

  self.logger:info("Booting application", { version = self.config.app.version })
  self.stateGraph:start("boot")
  self.stateGraph:request("boot_complete")
end

function Game:update(dt)
  self.feedbackClock = self.feedbackClock + dt
  self:updateFeedback(dt)
  self.stateGraph:update(dt)
end

function Game:draw()
  Theme.clearColor(Theme.colors.background)
  self.stateGraph:draw()
  self:drawFeedbackOverlay()
  self.debugOverlay:draw()
end

function Game:keypressed(key, scancode, isRepeat)
  if key == "f3" and self:isDevControlsEnabled() then
    self.logger:toggleOverlay()
    return
  end

  self.stateGraph:keypressed(key, scancode, isRepeat)
end

function Game:mousepressed(x, y, button, istouch, presses)
  self.stateGraph:mousepressed(x, y, button, istouch, presses)
end

function Game:resize(width, height)
  self.stateGraph:resize(width, height)
end

function Game:quit()
  local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil

  if self.runState and currentStateName then
    self:saveActiveRun("quit", currentStateName)
  else
    self:clearActiveRunSave("quit")
  end

  self:saveMetaState("quit")
end

function Game:getUiPulse(speed, minValue, maxValue, phase)
  local normalized = (math.sin((self.feedbackClock + (phase or 0)) * (speed or 1)) + 1) * 0.5
  return (minValue or 0) + ((maxValue or 1) - (minValue or 0)) * normalized
end

function Game:getFeedbackColor(kind)
  if kind == "success" then
    return Theme.colors.success
  end

  if kind == "danger" or kind == "boss" then
    return Theme.colors.danger
  end

  if kind == "warning" then
    return Theme.colors.warning
  end

  return Theme.colors.accent
end

function Game:showFeedback(kind, title, message, options)
  local color = self:getFeedbackColor(kind)
  local feedbackOptions = options or {}

  self.activeFeedback = {
    kind = kind or "accent",
    title = title or "",
    message = message or "",
    duration = feedbackOptions.duration or 1.45,
    elapsed = 0,
    color = { color[1], color[2], color[3], color[4] or 1.0 },
  }

  local flashAlpha = feedbackOptions.flashAlpha
  if flashAlpha == nil then
    flashAlpha = (kind == "danger" or kind == "boss") and 0.10 or 0.07
  end

  if flashAlpha > 0 then
    self.screenFlash = {
      color = { color[1], color[2], color[3], color[4] or 1.0 },
      alpha = math.max(self.screenFlash.alpha or 0, flashAlpha),
    }
  end

  if feedbackOptions.soundCue and self.audioSystem then
    self.audioSystem:playCue(feedbackOptions.soundCue)
  end
end

function Game:clearFeedback(options)
  local clearOptions = options or {}

  self.activeFeedback = nil

  if clearOptions.keepFlash then
    return
  end

  self.screenFlash = {
    color = Theme.colors.accent,
    alpha = 0,
  }
end

function Game:updateFeedback(dt)
  if self.audioSystem then
    self.audioSystem:update(dt)
  end

  if self.activeFeedback then
    self.activeFeedback.elapsed = self.activeFeedback.elapsed + dt

    if self.activeFeedback.elapsed >= self.activeFeedback.duration then
      self.activeFeedback = nil
    end
  end

  if (self.screenFlash.alpha or 0) > 0 then
    self.screenFlash.alpha = math.max(0, self.screenFlash.alpha - (dt * 0.32))
  end
end

function Game:drawFeedbackOverlay()
  local width = love.graphics.getWidth()
  local height = love.graphics.getHeight()
  local previousLineWidth = love.graphics.getLineWidth()

  if (self.screenFlash.alpha or 0) > 0 then
    local flashColor = self.screenFlash.color or Theme.colors.accent
    love.graphics.setColor(flashColor[1], flashColor[2], flashColor[3], self.screenFlash.alpha)
    love.graphics.rectangle("fill", 0, 0, width, height)
  end

  if not self.activeFeedback then
    return
  end

  local feedback = self.activeFeedback
  local padding = Theme.spacing.screenPadding
  local progress = math.min(1, feedback.elapsed / math.min(0.12, feedback.duration))
  local remaining = math.max(0, feedback.duration - feedback.elapsed)
  local fadeOut = remaining < 0.22 and (remaining / 0.22) or 1
  local alpha = math.min(1, progress) * fadeOut
  local availableWidth = width - (padding * 2)

  if availableWidth < 220 then
    return
  end

  local bannerWidth = math.max(220, math.min(560, availableWidth))
  local bannerX = math.floor((width - bannerWidth) * 0.5)
  local currentFont = love.graphics.getFont()
  local headingFont = self.fonts.heading or currentFont
  local bodyFont = self.fonts.body or currentFont
  local headingWidth = bannerWidth - 44
  local _, wrappedTitle = headingFont:getWrap(feedback.title or "", headingWidth)
  local titleLines = math.max(1, #wrappedTitle)
  local messageLines = 0

  if feedback.message ~= "" then
    local _, wrappedMessage = bodyFont:getWrap(feedback.message or "", headingWidth)
    messageLines = math.max(1, #wrappedMessage)
  end

  local bannerY = padding + 6 - math.floor((1 - alpha) * 18)
  local bannerHeight = 22 + (titleLines * headingFont:getHeight()) + (messageLines > 0 and ((messageLines * bodyFont:getHeight()) + 10) or 0)
  local pulseBorder = self:getUiPulse(6.0, 0.70, 1.0)

  love.graphics.setColor(0, 0, 0, 0.16 * alpha)
  love.graphics.rectangle("fill", bannerX + 4, bannerY + 6, bannerWidth, bannerHeight, 12, 12)

  love.graphics.setColor(Theme.colors.panel[1], Theme.colors.panel[2], Theme.colors.panel[3], 0.96 * alpha)
  love.graphics.rectangle("fill", bannerX, bannerY, bannerWidth, bannerHeight, 12, 12)

  love.graphics.setColor(feedback.color[1], feedback.color[2], feedback.color[3], 0.95 * alpha)
  love.graphics.rectangle("fill", bannerX, bannerY, 10, bannerHeight, 12, 12)

  love.graphics.setColor(feedback.color[1], feedback.color[2], feedback.color[3], pulseBorder * alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bannerX, bannerY, bannerWidth, bannerHeight, 12, 12)
  love.graphics.setLineWidth(previousLineWidth)

  love.graphics.setFont(headingFont)
  love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
  love.graphics.printf(feedback.title, bannerX + 22, bannerY + 12, bannerWidth - 44, "left")

  if feedback.message ~= "" then
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(Theme.colors.mutedText[1], Theme.colors.mutedText[2], Theme.colors.mutedText[3], alpha)
    love.graphics.printf(feedback.message, bannerX + 22, bannerY + 18 + (titleLines * headingFont:getHeight()), bannerWidth - 44, "left")
  end

  love.graphics.setFont(currentFont)
  Theme.applyColor(Theme.colors.text)
  love.graphics.setLineWidth(previousLineWidth)
end

function Game:triggerBatchFeedback(batchResult)
  if not batchResult then
    return
  end

  local matchCount = 0
  for _, coinState in ipairs(batchResult.perCoin or {}) do
    if coinState.result == batchResult.call then
      matchCount = matchCount + 1
    end
  end

  local shopDelta = batchResult.scoreBreakdown and batchResult.scoreBreakdown.totalShopPointDelta or 0
  local stageGain = batchResult.scoreBreakdown and batchResult.scoreBreakdown.totalStageScoreDelta or 0
  local runGain = batchResult.scoreBreakdown and batchResult.scoreBreakdown.totalRunScoreDelta or 0
  local isBossStage = batchResult.batch and batchResult.batch.stageType == "boss"

  if batchResult.status == "cleared" then
    local title = isBossStage and "Boss Defeated!" or "Stage Cleared!"
    local message = string.format("+%d score | %d/%d reached", stageGain, batchResult.stageScore or 0, batchResult.targetScore or 0)
    self:showFeedback(isBossStage and "boss" or "success", title, message, {
      duration = isBossStage and 1.9 or 1.5,
      flashAlpha = isBossStage and 0.12 or 0.08,
      soundCue = isBossStage and "boss_defeat" or "stage_clear",
    })
    return
  end

  if batchResult.status == "failed" then
    self:showFeedback("danger", isBossStage and "Boss Holds the Table" or "Stage Failed", "No flips remain. Regroup and try a new path.", {
      duration = 1.6,
      flashAlpha = 0.11,
      soundCue = "stage_fail",
    })
    return
  end

  if matchCount > 0 then
    local title = matchCount == #(batchResult.perCoin or {}) and "Perfect Call!" or string.format("Matched %d coin(s)", matchCount)
    local message = string.format("+%d stage score | %d flips left", stageGain, batchResult.flipsRemaining or 0)
    self:showFeedback(matchCount == #(batchResult.perCoin or {}) and "success" or "accent", title, message, {
      duration = 1.15,
      flashAlpha = 0.05,
      soundCue = matchCount == #(batchResult.perCoin or {}) and "batch_perfect" or "batch_match",
    })
    return
  end

  if shopDelta > 0 then
    local message = string.format("Banked %+d shop point(s) for the next stop.", shopDelta)

    if runGain > 0 then
      message = string.format("Banked %+d shop point(s) and %+d run score.", shopDelta, runGain)
    end

    self:showFeedback("warning", "Miss — but not empty-handed", message, {
      duration = 1.2,
      flashAlpha = 0.05,
      soundCue = "shop_gain",
    })
    return
  end

  self:showFeedback("warning", "Missed the Call", string.format("No score this batch. %d flips remain.", batchResult.flipsRemaining or 0), {
    duration = 0.95,
    flashAlpha = 0.03,
    soundCue = "batch_miss",
  })
end

function Game:getBossModifierCards(modifierIds)
  local cards = {}

  for _, modifierId in ipairs(modifierIds or (self.stageState and self.stageState.activeBossModifierIds) or {}) do
    table.insert(cards, {
      id = modifierId,
      name = self:getBossModifierName(modifierId),
      description = self:getBossModifierDescription(modifierId),
    })
  end

  return cards
end

function Game:getStageModifierCards(modifierIds)
  local cards = {}

  for _, modifierId in ipairs(modifierIds or {}) do
    table.insert(cards, {
      id = modifierId,
      name = self:getStageModifierName(modifierId),
      description = self:getStageModifierDescription(modifierId),
    })
  end

  return cards
end

function Game:assertRuntimeInvariants(label, options)
  if not self.runState then
    return
  end

  Validator.assertRuntimeInvariants(label, self.runState, self.stageState, options or {})
end

function Game:executeMacroAction(actionName, payload)
  if actionName == "start_new_run" then
    self:startNewRun()
    return true
  end

  if actionName == "resume_run" then
    return self:resumeSavedRun()
  end

  if actionName == "finalize_current_stage" then
    local stageRecord, errorMessage = self:finalizeCurrentStage()
    return stageRecord ~= nil, errorMessage
  end

  if actionName == "prepare_shop" then
    return self:prepareShopOffers()
  end

  if actionName == "claim_reward_choice" then
    return self:claimSelectedReward()
  end

  if actionName == "prepare_encounter" then
    return self:prepareEncounterEvent()
  end

  if actionName == "claim_encounter_choice" then
    return self:claimSelectedEncounterChoice()
  end

  if actionName == "advance_after_shop" then
    return self:advanceAfterShop()
  end

  if actionName == "return_to_menu" then
    self:returnToMenu()
    return true
  end

  error(string.format("Unknown macro action: %s", tostring(actionName)))
end

function Game:setMetaFlowContext(context)
  context = context or {}
  local returnState = context.returnState or "menu"

  if returnState ~= "menu" and returnState ~= "summary" then
    returnState = "menu"
  end

  self.metaFlowContext = {
    source = context.source or "menu",
    returnState = returnState,
    allowStartRun = context.allowStartRun == true,
  }
end

function Game:getMetaFlowContext()
  return self.metaFlowContext or createMenuMetaFlowContext()
end

function Game:createMenuMetaFlowContext()
  return createMenuMetaFlowContext()
end

function Game:createSummaryMetaFlowContext()
  return createSummaryMetaFlowContext()
end

function Game:canStartRunFromMeta()
  return self:getMetaFlowContext().allowStartRun == true
end

function Game:getMetaBackLabel()
  return self:getMetaFlowContext().returnState == "summary" and "Return to Summary" or "Back to Menu"
end

function Game:getMacroInsertedSteps(slot)
  local steps = {}

  if slot == "pre_stage" and self:shouldShowBossWarning() then
    table.insert(steps, { type = "state", state = "boss_warning", terminal = true })
  end

  if slot == "post_result" and self:shouldShowPostStageAnalytics() then
    table.insert(steps, { type = "state", state = "post_stage_analytics", terminal = true })
  end

  if slot == "pre_shop" and self:shouldUseEncounterEvent() then
    table.insert(steps, { type = "action", action = "prepare_encounter" })
    table.insert(steps, { type = "state", state = "encounter", terminal = true })
  end

  return steps
end

function Game:buildMacroContext(currentStateName, transitionPayload)
  local metaFlowContext = self:getMetaFlowContext()

  return {
    currentStateName = currentStateName,
    event = transitionPayload and transitionPayload.event or nil,
    postResultDestinationState = self:getPostResultDestinationState(),
    metaReturnState = metaFlowContext.returnState,
    metaAllowStartRun = metaFlowContext.allowStartRun,
    continueRunState = self:getContinueRunStateName(),
    continueRunPayload = self:getContinueRunPayload(),
    insertedSteps = {
      pre_stage = self:getMacroInsertedSteps("pre_stage"),
      post_result = self:getMacroInsertedSteps("post_result"),
      pre_shop = self:getMacroInsertedSteps("pre_shop"),
    },
  }
end

function Game:createShopFlow()
  if not self.shopSession then
    assert(
      self.lastStageResult and self.lastStageResult.status == "cleared",
      "Cannot create a new shop flow without a finalized cleared stage result"
    )
  end

  return ShopFlowSystem.createVisit(self.runState, self.stageState, self.metaProjection, self.runRng, {
    shopSession = self.shopSession,
    offers = self.shopOffers,
    lastGenerationTrace = self.lastShopGenerationTrace,
    lastPurchaseTrace = self.lastShopPurchaseTrace,
    sourceStageId = self.lastStageResult and self.lastStageResult.stageId or nil,
    roundIndex = self.lastStageResult and self.lastStageResult.roundIndex or nil,
  })
end

function Game:applyShopFlow(shopFlow)
  self.shopSession = shopFlow.shopSession
  self.shopOffers = shopFlow.offers or {}
  self.lastShopGenerationTrace = shopFlow.lastGenerationTrace
  self.lastShopPurchaseTrace = shopFlow.lastPurchaseTrace
end

function Game:startNewRun()
  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:clearActiveRunSave("start_new_run")
  local seed = math.floor(love.timer.getTime() * 100000) % 2147483646 + 1
  self.runState, self.metaProjection = RunInitializer.createNewRun(self.metaState, {
    seed = seed,
  })
  self.runRng = RNG.new(seed)
  self.stageState = nil
  self.currentStageDefinition = nil
  self.selectedCall = "heads"
  self.lastBatchResult = nil
  self.lastStageResult = nil
   self.rewardPreviewSession = nil
   self.encounterSession = nil
   self.shopOffers = {}
  self.shopSession = nil
  self.lastShopGenerationTrace = nil
  self.lastShopPurchaseTrace = nil
  self:assertRuntimeInvariants("game.startNewRun", { history = true })
  self.logger:info("Started new run", { seed = seed })
  return true
end

function Game:clearRunState()
  self.runState = nil
  self.runRng = nil
  self.metaProjection = nil
  self.stageState = nil
  self.currentStageDefinition = nil
  self.lastBatchResult = nil
  self.lastStageResult = nil
  self.rewardPreviewSession = nil
  self.encounterSession = nil
  self.shopOffers = {}
  self.shopSession = nil
  self.lastShopGenerationTrace = nil
  self.lastShopPurchaseTrace = nil
  self.selectedCall = "heads"
end

function Game:returnToMenu()
  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:clearRunState()
  self:clearActiveRunSave("return_to_menu")
  return true
end

function Game:onStateChanged(currentStateName, previousName, payload)
  local resumableStates = {
    loadout = true,
    boss_warning = true,
    stage = true,
    result = true,
    post_stage_analytics = true,
    reward_preview = true,
    boss_reward = true,
    encounter = true,
    shop = true,
  }

  if self.runState and resumableStates[currentStateName] then
    self:saveActiveRun("state_change", currentStateName)
  else
    self:clearActiveRunSave("state_change")
  end
end

function Game:ensureCurrentStage()
  if not self.runState then
    return nil
  end

  if self.stageState and self.currentStageDefinition and self.stageState.stageId == self.currentStageDefinition.id then
    return self.stageState, self.currentStageDefinition
  end

  self.stageState, self.currentStageDefinition = RunInitializer.createStageForCurrentRound(self.runState)
  self.logger:info("Prepared stage", { stage = self.currentStageDefinition.id, round = self.runState.roundIndex })
  return self.stageState, self.currentStageDefinition
end

function Game:getPlannedStageDefinition()
  if not self.runState then
    return nil
  end

  if self.currentStageDefinition and self.currentStageDefinition.roundIndex == self.runState.roundIndex then
    return self.currentStageDefinition
  end

  return Stages.getForRound(self.runState.roundIndex, self.runState)
end

function Game:buildStagePreviewData(stageDefinition, options)
  options = options or {}

  if not self.runState or not stageDefinition then
    return {
      title = options.emptyTitle or options.title or "Upcoming Stage",
      stageDefinition = nil,
      flipsPerStage = 0,
      isBoss = false,
      lines = { options.emptyMessage or "No stage is currently planned." },
      cards = {},
    }
  end

  local flipsPerStage = EffectiveValueSystem.getEffectiveValue("stage.flipsPerStage", self.runState, nil, {
    metaProjection = (self.runState and self.runState.metaProjection) or self.metaProjection,
    stageDefinition = stageDefinition,
  })
  local isBoss = stageDefinition.stageType == "boss"
  local cards = isBoss
    and self:getBossModifierCards(stageDefinition.bossModifierIds or {})
    or self:getStageModifierCards(stageDefinition.activeStageModifierIds or {})
  local lines = {
    string.format("Stage: %s", stageDefinition.label or stageDefinition.name or stageDefinition.id),
    string.format("Type: %s", isBoss and "Boss" or "Standard"),
    string.format("Target Score: %d", stageDefinition.targetScore or 0),
    string.format("Flips Available: %d", flipsPerStage or 0),
  }

  if #cards > 0 then
    table.insert(lines, string.format("Active rules: %d", #cards))
  else
    table.insert(lines, "Active rules: none")
  end

  local footerNote = options.footerNote

  if footerNote then
    table.insert(lines, footerNote)
  elseif isBoss then
    table.insert(lines, "Boss warning will appear before the stage starts.")
  else
    table.insert(lines, "Adapt your build before locking it in.")
  end

  return {
    title = options.title or (isBoss and "Upcoming Boss" or "Upcoming Stage"),
    stageDefinition = stageDefinition,
    flipsPerStage = flipsPerStage,
    isBoss = isBoss,
    lines = lines,
    cards = cards,
  }
end

function Game:getPlannedStagePreviewData()
  return self:buildStagePreviewData(self:getPlannedStageDefinition(), {
    title = "Upcoming Stage",
    emptyTitle = "Upcoming Stage",
    emptyMessage = "No stage is currently planned.",
  })
end

function Game:getUpcomingStagePreviewData()
  return self:buildStagePreviewData(self:getUpcomingStageDefinition(), {
    title = "After the Shop",
    emptyTitle = "After the Shop",
    emptyMessage = "No next stage is queued after this shop.",
    footerNote = "Use the shop to prepare for this next round.",
  })
end

function Game:commitLoadout(selectionSlots)
  local committedSlots, errorMessage = LoadoutSystem.commitLoadout(self.runState, selectionSlots)

  if not committedSlots then
    self.logger:warn("Rejected loadout", { error = errorMessage })
    return nil, errorMessage
  end

  if self.runState and not self.runState.runStartRecorded then
    self.runState.runStartRecorded = true
    self.metaState.stats.runsStarted = (self.metaState.stats.runsStarted or 0) + 1
    self:saveMetaState("run_start")
    self.logger:info("Recorded run start", { seed = self.runState.seed, round = self.runState.roundIndex })
  end

  self.logger:info("Committed loadout", { key = Loadout.toCanonicalKey(committedSlots, self.runState.maxActiveCoinSlots) })
  self:assertRuntimeInvariants("game.commitLoadout", { history = true })
  self:saveActiveRun("commit_loadout", "loadout")
  return committedSlots
end

function Game:resolveCurrentBatch(call)
  if not self.runState or not self.stageState then
    return nil, "run or stage has not been initialized"
  end

  local batchResult, errorMessage = FlipResolver.resolveBatch(
    self.runState,
    self.stageState,
    self.metaProjection,
    call,
    self.runRng
  )

  if not batchResult then
    self.logger:warn("Batch resolution rejected", { error = errorMessage })
    return nil, errorMessage
  end

  self.lastBatchResult = batchResult
  table.insert(self.runState.history.flipBatches, Utils.clone(batchResult.batch))
  self:assertRuntimeInvariants("game.resolveCurrentBatch", { batchResult = batchResult, history = true })
  self.logger:info("Resolved batch", { batch = batchResult.batchId, status = batchResult.status, call = call })
  self.logger:debug(self:formatBatchLogLine(batchResult))
  self:triggerBatchFeedback(batchResult)
  self:saveActiveRun("resolve_batch", "stage")
  return batchResult
end

function Game:isDevControlsEnabled()
  return self.config.get("debug.devControlsEnabled") == true
end

function Game:getDebugControlLines()
  if not self:isDevControlsEnabled() then
    return {}
  end

  return {
    "- F1: next coin Heads",
    "- F2: next coin Tails",
    string.format("- F5: +%d shop points", self.config.get("debug.grantShopPointsAmount", 5)),
    "- F6: grant next upgrade",
    "- F7: jump to boss round",
    string.format("- F8: simulate %d batch(es)", self.config.get("debug.fastSimBatchCount", 3)),
    "- F9: print full batch trace",
    "- F10: force clear stage",
    "- F11: force fail stage",
  }
end

function Game:debugForceNextCoinResult(result)
  if not self.runState then
    return false, "run_not_initialized"
  end

  if result ~= "heads" and result ~= "tails" then
    return false, "invalid_forced_result"
  end

  self.runState.pendingForcedCoinResults = { result }
  self:assertRuntimeInvariants("game.debugForceNextCoinResult", { history = true })
  self.logger:info("Dev control armed forced next coin result", {
    result = result,
    queued = #self.runState.pendingForcedCoinResults,
  })
  return true, result
end

function Game:debugGrantShopPoints(amount)
  if not self.runState then
    return false, "run_not_initialized"
  end

  amount = amount or self.config.get("debug.grantShopPointsAmount", 5)
  self.runState.shopPoints = self.runState.shopPoints + amount
  self:assertRuntimeInvariants("game.debugGrantShopPoints", { history = true })
  self.logger:info("Dev control granted shop points", { amount = amount, total = self.runState.shopPoints })
  return true, amount
end

function Game:debugGrantNextUpgrade()
  if not self.runState then
    return false, "run_not_initialized"
  end

  local nextUpgradeId = nil

  for _, definition in ipairs(Upgrades.getAll()) do
    if not Utils.contains(self.runState.ownedUpgradeIds, definition.id) then
      nextUpgradeId = definition.id
      break
    end
  end

  if not nextUpgradeId then
    return false, "all_upgrades_owned"
  end

  local ok, result = ShopSystem.grantUpgrade(self.runState, nextUpgradeId)

  if not ok then
    return false, result
  end

  self:assertRuntimeInvariants("game.debugGrantNextUpgrade", { history = true })
  self.logger:info("Dev control granted upgrade", { id = nextUpgradeId })
  return true, nextUpgradeId
end

function Game:debugJumpToBossRound()
  if not self.runState then
    return false, "run_not_initialized"
  end

  local bossRoundIndex = self.config.get("run.normalRoundCount") + 1
  self.runState.roundIndex = bossRoundIndex
  self.runState.pendingForcedCoinResults = {}
  self.stageState = nil
  self.currentStageDefinition = nil
  self.lastBatchResult = nil
  self:ensureCurrentStage()
  self:assertRuntimeInvariants("game.debugJumpToBossRound", { history = true })
  self.logger:info("Dev control jumped to boss round", { round = bossRoundIndex, stage = self.currentStageDefinition and self.currentStageDefinition.id or "n/a" })
  return true, self.currentStageDefinition and self.currentStageDefinition.label or "boss"
end

function Game:debugResolveMultipleBatches(batchCount)
  if not self.runState or not self.stageState then
    return false, "run_or_stage_not_initialized"
  end

  local resolvedCount = 0
  local lastBatchResult = nil
  local targetCount = batchCount or self.config.get("debug.fastSimBatchCount", 3)

  for _ = 1, targetCount do
    if self.stageState.stageStatus ~= "active" then
      break
    end

    local batchResult, errorMessage = self:resolveCurrentBatch(self.selectedCall)

    if not batchResult then
      return false, errorMessage
    end

    resolvedCount = resolvedCount + 1
    lastBatchResult = batchResult
  end

  return true, {
    resolvedCount = resolvedCount,
    stageEnded = self.stageState and self.stageState.stageStatus ~= "active" or false,
    lastBatchResult = lastBatchResult,
  }
end

function Game:debugPrintFullBatchTrace()
  if not self.lastBatchResult then
    return false, "no_batch_resolved"
  end

  self.logger:debug("=== Full Batch Trace ===", { batch = self.lastBatchResult.batchId })

  for _, line in ipairs(self:getLastBatchSummaryLines()) do
    self.logger:debug(line)
  end

  for _, line in ipairs(self:getScoreBreakdownLines()) do
    self.logger:debug(line)
  end

  if self.lastBatchResult.trace then
    self.logger:debug("Trace terminal state", {
      stageStatus = self.lastBatchResult.trace.stageStatusAfter or "n/a",
      stageScore = self.lastBatchResult.trace.stageScoreAfter or "n/a",
      runScore = self.lastBatchResult.trace.runScoreAfter or "n/a",
      shopPoints = self.lastBatchResult.trace.shopPointsAfter or "n/a",
      flipsRemaining = self.lastBatchResult.trace.flipsRemainingAfter or "n/a",
    })
  end

  return true, self.lastBatchResult.batchId
end

function Game:debugForceStageOutcome(outcome)
  if not self.stageState then
    return false, "stage_not_initialized"
  end

  if outcome == "clear" then
    self.stageState.stageScore = math.max(self.stageState.stageScore, self.stageState.targetScore)
    self.stageState.stageStatus = "cleared"
  elseif outcome == "fail" then
    self.stageState.flipsRemaining = 0
    self.stageState.stageStatus = "failed"
  else
    return false, "unknown_outcome"
  end

  self.stageState.lastBatchResults = nil
  self.lastBatchResult = nil

  if self.runState then
    self.runState.pendingForcedCoinResults = {}
  end

  self:assertRuntimeInvariants("game.debugForceStageOutcome", { history = true })
  self.logger:info("Dev control forced stage outcome", { outcome = outcome, stage = self.stageState.stageId })
  return true, outcome
end

function Game:getPendingForcedResultLines()
  if not self.runState or #(self.runState.pendingForcedCoinResults or {}) == 0 then
    return { "Forced next coin: none" }
  end

  return {
    string.format("Forced next coin: %s", string.upper(self.runState.pendingForcedCoinResults[1])),
  }
end

function Game:getStageEndEvaluationLines()
  local batchResult = self.lastBatchResult

  if batchResult and batchResult.trace then
    local stageScoreAfter = batchResult.trace.stageScoreAfter
    local targetScore = batchResult.targetScore or batchResult.stageScore or 0
    local flipsRemainingAfter = batchResult.trace.flipsRemainingAfter
    local statusAfter = batchResult.trace.stageStatusAfter or batchResult.status or "n/a"
    local lines = {
      string.format("Stage end evaluation: %s", tostring(statusAfter)),
      string.format("Score check: %s/%s", tostring(stageScoreAfter or "n/a"), tostring(targetScore or "n/a")),
      string.format("Flips after batch: %s", tostring(flipsRemainingAfter or "n/a")),
    }

    if #(batchResult.trace.forcedResults or {}) > 0 then
      local forced = {}

      for _, entry in ipairs(batchResult.trace.forcedResults or {}) do
        table.insert(forced, string.format("%s@slot%s", string.upper(entry.result or "?"), tostring(entry.slotIndex or "?")))
      end

      table.insert(lines, "Forced results used: " .. table.concat(forced, ", "))
    end

    return lines
  end

  if self.stageState and self.stageState.stageStatus ~= "active" then
    return {
      string.format("Stage end evaluation: %s", tostring(self.stageState.stageStatus)),
      string.format("Score check: %s/%s", tostring(self.stageState.stageScore or "n/a"), tostring(self.stageState.targetScore or "n/a")),
      string.format("Flips after batch: %s", tostring(self.stageState.flipsRemaining or "n/a")),
      "Source: dev-forced or no batch trace",
    }
  end

  return { "Stage end evaluation: n/a" }
end

function Game:finalizeCurrentStage()
  if not self.runState or not self.stageState then
    return nil, "stage_not_initialized"
  end

  local stageRecord, finalizeMeta = RunHistorySystem.finalizeStage(self.runState, self.stageState, self.metaState)

  if finalizeMeta.metaReward > 0 then
    self.logger:info("Granted meta reward", { amount = finalizeMeta.metaReward, runStatus = self.runState.runStatus })
  end

  if finalizeMeta.shouldPersistMeta then
    self:saveMetaState("run_complete")
  end

  self.lastStageResult = stageRecord

  if self:shouldUseRewardPreview() or self:shouldUseBossRewardEvent() then
    self:ensureRewardSession()
  end

  self:assertRuntimeInvariants("game.finalizeCurrentStage", { history = true })
  self.logger:info("Finalized stage", { stage = stageRecord.stageId, status = stageRecord.status, runStatus = stageRecord.runStatus })
  return stageRecord, finalizeMeta
end

function Game:prepareShopOffers()
  if not self.runState then
    return false, "run_not_initialized"
  end

  if not self.lastStageResult or self.lastStageResult.status ~= "cleared" then
    return false, "cleared_stage_required"
  end

  if self.lastStageResult.stageType == "boss" then
    return false, "boss_stage_has_no_shop"
  end

  local rewardSession = self:ensureRewardPreview()
  if rewardSession and rewardSession.claimed ~= true then
    if #(rewardSession.options or {}) > 0 then
      return false, "reward_choice_required"
    end

    local claimOk, claimError = self:claimSelectedReward()
    if claimOk ~= true then
      return false, claimError or "reward_choice_required"
    end
  end

  local shopFlow = self:createShopFlow()
  self:applyShopFlow(shopFlow)

  if self.shopOffers and #self.shopOffers > 0 then
    return true
  end

  ShopFlowSystem.ensureOffers(shopFlow)
  self:applyShopFlow(shopFlow)
  self:assertRuntimeInvariants("game.prepareShopOffers", { shopOffers = self.shopOffers, history = true })
  self.logger:info("Generated shop offers", { count = #self.shopOffers, triggers = #(self.lastShopGenerationTrace and self.lastShopGenerationTrace.triggeredSources or {}) })
  self:saveActiveRun("prepare_shop", "shop")
  return true
end

function Game:recordCurrentShopOfferSet(reason)
  RunHistorySystem.recordShopOfferSet(self.shopSession, self.shopOffers, reason)
end

function Game:serializeShopOffer(offer)
  return RunHistorySystem.serializeShopOffer(offer)
end

function Game:refreshShopOffers(reason)
  local shopFlow = self:createShopFlow()
  ShopFlowSystem.refreshOffers(shopFlow, reason)
  self:applyShopFlow(shopFlow)
end

function Game:rerollShopOffers()
  local prepared, prepareError = self:prepareShopOffers()
  if prepared == false then
    return false, prepareError
  end

  local shopFlow = self:createShopFlow()

  local rerollMode, errorMessage = ShopFlowSystem.reroll(shopFlow)

  if not rerollMode then
    self:applyShopFlow(shopFlow)
    self.logger:warn("Shop reroll rejected", { error = errorMessage })
    self:assertRuntimeInvariants("game.rerollShopOffers.rejected", { shopOffers = self.shopOffers, history = true })
    return false, errorMessage
  end

  self:applyShopFlow(shopFlow)
  self:assertRuntimeInvariants("game.rerollShopOffers", { shopOffers = self.shopOffers, history = true })
  self.logger:info("Rerolled shop offers", { mode = rerollMode, rerollsUsed = self.shopSession and self.shopSession.rerollsUsed or 0 })
  self:showFeedback("warning", "Shop Rerolled", string.format("A %s reroll refreshed the offers.", rerollMode), {
    duration = 1.05,
    flashAlpha = 0.04,
    soundCue = "shop_reroll",
  })
  self:saveActiveRun("reroll_shop", "shop")
  return true, rerollMode
end

function Game:purchaseShopOffer(index)
  local prepared, prepareError = self:prepareShopOffers()
  if prepared == false then
    return false, prepareError
  end

  local shopFlow = self:createShopFlow()
  local ok, result, offer = ShopFlowSystem.purchase(shopFlow, index)
  self:applyShopFlow(shopFlow)

  if not ok then
    self:assertRuntimeInvariants("game.purchaseShopOffer.rejected", { shopOffers = self.shopOffers, history = true })

    self.logger:warn("Purchase rejected", { error = result and result.reason or "purchase_failed", index = index })
    return false, result and result.reason or "purchase_failed"
  end

  self:assertRuntimeInvariants("game.purchaseShopOffer", { shopOffers = self.shopOffers, history = true })
  self.logger:info("Purchased shop offer", { contentId = offer.contentId, type = offer.type, price = result.finalPrice, triggers = #(result.trace and result.trace.triggeredSources or {}) })
  self:showFeedback("accent", "Purchase Complete", string.format("%s joined the run for %d point(s).", offer.name, result.finalPrice or offer.price or 0), {
    duration = 1.2,
    flashAlpha = 0.05,
    soundCue = "shop_purchase",
  })
  self:saveActiveRun("purchase_shop", "shop")
  return true, result
end

function Game:advanceAfterShop()
  if not self.runState then
    return false, "run_not_initialized"
  end

  if not self.lastStageResult or self.lastStageResult.status ~= "cleared" then
    return false, "cleared_stage_required"
  end

  if self.lastStageResult.stageType == "boss" then
    return false, "boss_stage_has_no_shop"
  end

  local advanced = ProgressionSystem.advanceToNextRound(self.runState)
  if not advanced then
    return false, "round_advance_failed"
  end

  self.runState.currentStageId = nil
  self.stageState = nil
  self.currentStageDefinition = nil
  self.lastBatchResult = nil
  self.lastStageResult = nil
  self.rewardPreviewSession = nil
  self.encounterSession = nil
  self.shopOffers = {}
  self.shopSession = nil
  self.lastShopGenerationTrace = nil
  self.lastShopPurchaseTrace = nil
  self:assertRuntimeInvariants("game.advanceAfterShop", { history = true })
  self:saveActiveRun("advance_after_shop", "loadout")
  return true
end

function Game:buildSummary()
  return SummarySystem.buildRunSummary(self.runState, self.stageState)
end

function Game:buildPostStageAnalyticsReport()
  return AnalyticsSystem.buildPostStageReport(self.runState, self.lastStageResult, self.lastBatchResult)
end

function Game:getMetaUpgradeName(metaUpgradeId)
  local definition = MetaUpgrades.getById(metaUpgradeId)
  return definition and definition.name or tostring(metaUpgradeId)
end

function Game:getMetaUpgradeOptions()
  return MetaProgressionSystem.getUpgradeOptions(self.metaState)
end

function Game:getCurrentMetaProjection()
  return RunInitializer.createMetaProjection(self.metaState)
end

function Game:formatRunModifier(key, value)
  if key == "shopPointMultiplier" then
    return string.format("Shop point gain x%.2f", value)
  end

  if key == "bonusCoinSlots" then
    return string.format("+%d active coin slot(s)", value)
  end

  if key == "bonusRerolls" then
    return string.format("+%d free shop reroll(s)", value)
  end

  if key == "startingShopPoints" then
    return string.format("+%d starting shop point(s)", value)
  end

  if key == "bonusStartingCoins" then
    return string.format("+%d starting coin(s)", value)
  end

  return string.format("%s = %s", tostring(key), tostring(value))
end

function Game:getRunModifierLines(modifierTable)
  local lines = {}

  for _, key in ipairs(Utils.sortedKeys(modifierTable or {})) do
    local value = modifierTable[key]

    if type(value) == "number" then
      local isNeutralMultiplier = string.match(key, "Multiplier$") and math.abs(value - 1.0) < 0.00001
      if not isNeutralMultiplier and value ~= 0 then
        table.insert(lines, self:formatRunModifier(key, value))
      end
    end
  end

  if #lines == 0 then
    return { "No persistent run modifiers yet." }
  end

  return lines
end

function Game:getEffectiveValueLines(effectiveValues)
  local lines = {}

  local function formatSignedNumber(value)
    if math.abs(value - math.floor(value)) < 0.00001 then
      return string.format("%+d", value)
    end

    return string.format("%+.2f", value)
  end

  local function describeEntry(path, rawEntry)
    local keyDefinition = EffectiveValueSystem.KNOWN_KEYS[path] or {}
    local mode = keyDefinition.defaultMode or "override"
    local value = rawEntry

    if type(rawEntry) == "table" then
      mode = rawEntry.mode or mode
      value = rawEntry.value
    end

    if type(value) ~= "number" then
      return string.format("%s = %s", tostring(path), tostring(value))
    end

    if path == "economy.shopPointMultiplier" then
      if mode == "add" then
        return string.format("Shop point gain %s", formatSignedNumber(value))
      end

      return string.format("Shop point gain x%.2f", value)
    end

    if path == "run.maxActiveCoinSlots" then
      if mode == "override" then
        return string.format("Active coin slots = %d", value)
      end

      return string.format("%s active coin slot(s)", formatSignedNumber(value))
    end

    if path == "run.startingShopRerolls" then
      if mode == "override" then
        return string.format("Free shop rerolls = %d", value)
      end

      return string.format("%s free shop reroll(s)", formatSignedNumber(value))
    end

    if path == "run.startingShopPoints" then
      if mode == "override" then
        return string.format("Starting shop points = %d", value)
      end

      return string.format("%s starting shop point(s)", formatSignedNumber(value))
    end

    if path == "run.startingCollectionSize" then
      if mode == "override" then
        return string.format("Starting collection size = %d", value)
      end

      return string.format("%s starting coin(s)", formatSignedNumber(value))
    end

    if path == "stage.flipsPerStage" then
      return mode == "override"
        and string.format("Stage flips = %d", value)
        or string.format("Stage flips %s", formatSignedNumber(value))
    end

    if path == "shop.offerCount" then
      return mode == "override"
        and string.format("Shop offer count = %d", value)
        or string.format("Shop offer count %s", formatSignedNumber(value))
    end

    if path == "shop.guaranteedCoinOffers" then
      return mode == "override"
        and string.format("Guaranteed coin offers = %d", value)
        or string.format("Guaranteed coin offers %s", formatSignedNumber(value))
    end

    if path == "shop.guaranteedUpgradeOffers" then
      return mode == "override"
        and string.format("Guaranteed upgrade offers = %d", value)
        or string.format("Guaranteed upgrade offers %s", formatSignedNumber(value))
    end

    if path == "shop.rerollCost" then
      return mode == "override"
        and string.format("Shop reroll cost = %d", value)
        or string.format("Shop reroll cost %s", formatSignedNumber(value))
    end

    if path == "shop.rarityWeight.common" or path == "shop.rarityWeight.uncommon" or path == "shop.rarityWeight.rare" then
      local rarity = string.match(path, "shop%.rarityWeight%.(.+)") or "unknown"
      return string.format("%s offer weight x%.2f", rarity:gsub("^%l", string.upper), value)
    end

    if path == "flip.baseHeadsWeight" or path == "flip.baseTailsWeight" then
      local label = path == "flip.baseHeadsWeight" and "Base Heads weight" or "Base Tails weight"

      if mode == "override" then
        return string.format("%s = %.2f", label, value)
      end

      return string.format("%s %s", label, formatSignedNumber(value))
    end

    if mode == "multiply" then
      return string.format("%s x%.2f", path, value)
    end

    if mode == "add" then
      return string.format("%s %s", path, formatSignedNumber(value))
    end

    return string.format("%s = %s", path, tostring(value))
  end

  for _, path in ipairs(Utils.sortedKeys(effectiveValues or {})) do
    local rawEntry = effectiveValues[path]
    local mode = type(rawEntry) == "table" and rawEntry.mode or (EffectiveValueSystem.KNOWN_KEYS[path] and EffectiveValueSystem.KNOWN_KEYS[path].defaultMode) or "override"
    local value = type(rawEntry) == "table" and rawEntry.value or rawEntry

    if type(value) == "number" then
      local isNeutralMultiplier = mode == "multiply" and math.abs(value - 1.0) < 0.00001
      local isNeutralAdd = mode == "add" and value == 0

      if not isNeutralMultiplier and not isNeutralAdd then
        table.insert(lines, describeEntry(path, rawEntry))
      end
    end
  end

  if #lines == 0 then
    return { "No persistent run modifiers yet." }
  end

  return lines
end

function Game:getMetaStatusLines()
  local unlockedCoinCount = #(Coins.getUnlockedIds(self.metaState.unlockedCoinIds or {}) or {})
  local unlockedUpgradeCount = #(Upgrades.getUnlockedIds(self.metaState.unlockedUpgradeIds or {}) or {})

  return {
    string.format("Meta Points: %d", self.metaState.metaPoints or 0),
    string.format("Lifetime Meta Points: %d", self.metaState.lifetimeMetaPointsEarned or 0),
    string.format("Purchased Meta Upgrades: %d", #(self.metaState.purchasedMetaUpgradeIds or {})),
    string.format("Unlocked Coins: %d/%d", unlockedCoinCount, #(Coins.getAll() or {})),
    string.format("Unlocked Upgrades: %d/%d", unlockedUpgradeCount, #(Upgrades.getAll() or {})),
    string.format("Runs Started: %d", self.metaState.stats.runsStarted or 0),
    string.format("Runs Won: %d", self.metaState.stats.runsWon or 0),
    string.format("Best Run Score: %d", self.metaState.stats.bestRunScore or 0),
    string.format("Bosses Defeated: %d", self.metaState.stats.bossesDefeated or 0),
  }
end

function Game:getContentUnlockNames(unlockCoinIds, unlockUpgradeIds)
  local names = {}

  for _, coinId in ipairs(unlockCoinIds or {}) do
    table.insert(names, self:getCoinName(coinId))
  end

  for _, upgradeId in ipairs(unlockUpgradeIds or {}) do
    table.insert(names, self:getUpgradeName(upgradeId))
  end

  table.sort(names)
  return names
end

function Game:getMetaSaveLines()
  return {
    string.format("Save File: %s", SaveSystem.META_STATE_PATH),
    string.format("Save Status: %s", self.metaSaveStatus and self.metaSaveStatus.message or "unknown"),
  }
end

function Game:getMetaProjectionLines()
  local projection = self:getCurrentMetaProjection()
  return self:getEffectiveValueLines(projection.effectiveValues)
end

function Game:getMetaUpgradeDetailLines(metaUpgradeId)
  local definition = MetaUpgrades.getById(metaUpgradeId)

  if not definition then
    return { "Unknown meta upgrade." }
  end

  local lines = {
    definition.description,
    "",
    string.format("Cost: %d meta point(s)", definition.cost or 0),
    Utils.contains(self.metaState.purchasedMetaUpgradeIds, metaUpgradeId) and "Status: purchased" or "Status: available",
  }

  if #(definition.tags or {}) > 0 then
    table.insert(lines, string.format("Tags: %s", table.concat(definition.tags, ", ")))
  end

  if #(definition.unlockCoinIds or {}) > 0 or #(definition.unlockUpgradeIds or {}) > 0 then
    table.insert(lines, "")
    table.insert(lines, "Unlocks:")

    for _, coinId in ipairs(definition.unlockCoinIds or {}) do
      table.insert(lines, "- Coin: " .. self:getCoinName(coinId))
    end

    for _, upgradeId in ipairs(definition.unlockUpgradeIds or {}) do
      table.insert(lines, "- Upgrade: " .. self:getUpgradeName(upgradeId))
    end
  end

  local effectLines = self:getEffectiveValueLines(EffectiveValueSystem.getDefinitionEffectiveValues(definition))
  if #effectLines > 0 and not (#effectLines == 1 and effectLines[1] == "No persistent run modifiers yet.") then
    table.insert(lines, "")
    table.insert(lines, "Run effect:")

    for _, line in ipairs(effectLines) do
      table.insert(lines, "- " .. line)
    end
  end

  return lines
end

function Game:purchaseMetaUpgrade(metaUpgradeId)
  local ok, result = MetaProgressionSystem.purchase(self.metaState, metaUpgradeId)

  if not ok then
    self.logger:warn("Meta upgrade purchase rejected", { error = result, id = metaUpgradeId })
    return false, result
  end

  self:saveMetaState("meta_purchase")
  self.logger:info("Purchased meta upgrade", { id = metaUpgradeId, cost = result.cost or 0 })
  local unlockedNames = self:getContentUnlockNames(result.unlockCoinIds, result.unlockUpgradeIds)
  local unlockedCount = #unlockedNames
  local message = unlockedCount > 0
    and string.format("%s unlocked %s.", self:getMetaUpgradeName(metaUpgradeId), table.concat(unlockedNames, ", "))
    or string.format("%s is now active for future runs.", self:getMetaUpgradeName(metaUpgradeId))
  self:showFeedback("accent", "Meta Upgrade Purchased", message, {
    duration = 1.25,
    flashAlpha = 0.04,
    soundCue = "meta_purchase",
  })
  return true, result
end

function Game:getCoinName(coinId)
  local definition = Coins.getById(coinId)
  return definition and definition.name or tostring(coinId)
end

function Game:getPersistedLoadoutKey()
  if not self.runState then
    return "n/a"
  end

  return Loadout.toCanonicalKey(self.runState.persistedLoadoutSlots, self.runState.maxActiveCoinSlots)
end

function Game:getCurrentLoadoutKey()
  if not self.runState then
    return "n/a"
  end

  return Loadout.toCanonicalKey(self.runState.equippedCoinSlots, self.runState.maxActiveCoinSlots)
end

function Game:getEquippedCoinNames()
  local names = {}

  if not self.runState or not self.runState.maxActiveCoinSlots then
    return names
  end

  for slotIndex = 1, self.runState.maxActiveCoinSlots do
    local coinId = self.runState.equippedCoinSlots[slotIndex]

    if coinId then
      table.insert(names, self:getCoinName(coinId))
    end
  end

  return names
end

function Game:getUpgradeName(upgradeId)
  local definition = Upgrades.getById(upgradeId)
  return definition and definition.name or tostring(upgradeId)
end

function Game:getUpgradeDescription(upgradeId)
  local definition = Upgrades.getById(upgradeId)
  return definition and definition.description or tostring(upgradeId)
end

function Game:getStageModifierName(modifierId)
  local definition = StageModifiers.getById(modifierId)
  return definition and definition.name or tostring(modifierId)
end

function Game:getStageModifierDescription(modifierId)
  local definition = StageModifiers.getById(modifierId)
  return definition and definition.description or tostring(modifierId)
end

function Game:getBossModifierName(modifierId)
  local definition = Bosses.getById(modifierId)
  return definition and definition.name or tostring(modifierId)
end

function Game:getBossModifierDescription(modifierId)
  local definition = Bosses.getById(modifierId)
  return definition and definition.description or tostring(modifierId)
end

function Game:getActiveUpgradeNames()
  local names = {}

  for _, upgradeId in ipairs(self.runState and self.runState.ownedUpgradeIds or {}) do
    table.insert(names, self:getUpgradeName(upgradeId))
  end

  return names
end

function Game:getActiveModifierNames()
  local names = {}

  for _, modifierId in ipairs(self.stageState and self.stageState.activeStageModifierIds or {}) do
    table.insert(names, self:getStageModifierName(modifierId))
  end

  for _, modifierId in ipairs(self.stageState and self.stageState.activeBossModifierIds or {}) do
    table.insert(names, self:getBossModifierName(modifierId))
  end

  return names
end

function Game:getActiveModifierDetailLines()
  local lines = {}

  if #(self.stageState and self.stageState.activeStageModifierIds or {}) > 0 then
    table.insert(lines, "Stage Effects:")

    for _, modifierId in ipairs(self.stageState.activeStageModifierIds or {}) do
      table.insert(lines, string.format("- %s: %s", self:getStageModifierName(modifierId), self:getStageModifierDescription(modifierId)))
    end
  end

  if #(self.stageState and self.stageState.activeBossModifierIds or {}) > 0 then
    if #lines > 0 then
      table.insert(lines, "")
    end

    table.insert(lines, "Boss Effects:")

    for _, modifierId in ipairs(self.stageState.activeBossModifierIds or {}) do
      table.insert(lines, string.format("- %s: %s", self:getBossModifierName(modifierId), self:getBossModifierDescription(modifierId)))
    end
  end

  return lines
end

function Game:getActiveTemporaryEffectLines()
  local lines = {}

  for _, effect in ipairs(self.runState and self.runState.temporaryRunEffects or {}) do
    local label = effect.name or effect.baseEffectId or effect.id or "Temporary Effect"
    local description = effect.description or ""

    if description ~= "" then
      table.insert(lines, string.format("- %s: %s", label, description))
    else
      table.insert(lines, string.format("- %s", label))
    end
  end

  return lines
end

function Game:getUpcomingStageDefinition()
  if not self.runState then
    return nil
  end

  return Stages.getForRound(self.runState.roundIndex + 1, self.runState)
end

function Game:getOfferDescription(offer)
  if not offer then
    return ""
  end

  local definition

  if offer.type == "coin" then
    definition = Coins.getById(offer.contentId)
  else
    definition = Upgrades.getById(offer.contentId)
  end

  return definition and definition.description or ""
end

function Game:getShopStatusLines()
  local shopRules = EffectiveValueSystem.getShopRules(self.runState, self.stageState, {
    metaProjection = self.runState and self.runState.metaProjection or nil,
  })
  local lines = {
    string.format("Free rerolls remaining: %d", self.runState and self.runState.shopRerollsRemaining or 0),
    string.format("Paid reroll cost: %d shop point(s)", shopRules.rerollCost),
    string.format("Unlocked coin pool: %d/%d", #(Coins.getUnlockedIds(self.runState and self.runState.unlockedCoinIds or {}) or {}), #(Coins.getAll() or {})),
    string.format("Unlocked upgrade pool: %d/%d", #(Upgrades.getUnlockedIds(self.runState and self.runState.unlockedUpgradeIds or {}) or {}), #(Upgrades.getAll() or {})),
  }

  if shopRules.rarityWeights then
    table.insert(lines, string.format("Quality bias: common x%.2f • uncommon x%.2f • rare x%.2f", shopRules.rarityWeights.common or 1.0, shopRules.rarityWeights.uncommon or 1.0, shopRules.rarityWeights.rare or 1.0))
  end

  if self.shopSession then
    table.insert(lines, string.format("Visit rerolls used: %d", self.shopSession.rerollsUsed or 0))
    table.insert(lines, string.format("Purchases this visit: %d", #(self.shopSession.purchases or {})))
  end

  return lines
end

function Game:getShopTraceLines(limit)
  local lines = {}

  if self.lastShopGenerationTrace then
    for _, message in ipairs(self.lastShopGenerationTrace.messages or {}) do
      table.insert(lines, "Generation: " .. message)
    end

    if #(self.lastShopGenerationTrace.triggeredSources or {}) > 0 then
      table.insert(lines, string.format("Generation triggers: %d", #(self.lastShopGenerationTrace.triggeredSources or {})))
    end
  end

  if self.lastShopPurchaseTrace then
    for _, message in ipairs(self.lastShopPurchaseTrace.messages or {}) do
      table.insert(lines, "Purchase: " .. message)
    end

    if #(self.lastShopPurchaseTrace.triggeredSources or {}) > 0 then
      table.insert(lines, string.format("Purchase triggers: %d", #(self.lastShopPurchaseTrace.triggeredSources or {})))
    end
  end

  if limit and #lines > limit then
    local trimmed = {}

    for index = 1, limit do
      trimmed[index] = lines[index]
    end

    return trimmed
  end

  return lines
end

function Game:getOfferMetaLines(offer)
  local lines = {}

  if offer and offer.injectedBy then
    table.insert(lines, "Bonus offer")
  end

  if offer and offer.priceAdjustments and #offer.priceAdjustments > 0 then
    local totalDelta = 0

    for _, adjustment in ipairs(offer.priceAdjustments) do
      totalDelta = totalDelta + (adjustment.delta or 0)
    end

    table.insert(lines, string.format("Hook price delta: %+d", totalDelta))
  end

  return lines
end

function Game:getPurchaseName(record)
  if not record then
    return "n/a"
  end

  if record.type == "coin" then
    return self:getCoinName(record.contentId)
  end

  return self:getUpgradeName(record.contentId)
end

function Game:getPurchaseHistoryLines(limit)
  local lines = {}

  for _, record in ipairs(self.runState and self.runState.history.purchases or {}) do
    table.insert(lines, string.format("- %s (%s) for %d", self:getPurchaseName(record), record.type, record.price or 0))
  end

  if #lines == 0 then
    lines = { "- No purchases recorded." }
  end

  if limit and #lines > limit then
    local trimmed = {}

    for index = 1, limit do
      trimmed[index] = lines[index]
    end

    return trimmed
  end

  return lines
end

function Game:getPostResultDestinationState()
  if not self.lastStageResult then
    return "summary"
  end

  if self:shouldUseBossRewardEvent() then
    return "boss_reward"
  end

  if self:shouldUseRewardPreview() then
    return "reward_preview"
  end

  return "summary"
end

function Game:shouldShowPostStageAnalytics()
  return self.config.get("debug.postStageAnalyticsEnabled") == true
    and self.config.get("debug.devControlsEnabled") == true
    and self.lastStageResult ~= nil
end

function Game:getPostResultNextState()
  if self:shouldShowPostStageAnalytics() then
    return "post_stage_analytics"
  end

  return self:getPostResultDestinationState()
end

function Game:getPostResultDestinationLabel()
  local destination = self:getPostResultNextState()

  if destination == "reward_preview" then
    return "reward preview"
  end

  if destination == "post_stage_analytics" then
    return "analytics review"
  end

  if destination == "boss_reward" then
    return "victory reward"
  end

  return destination
end

function Game:shouldShowBossWarning()
  local stageDefinition = self:getPlannedStageDefinition()
  return stageDefinition ~= nil and stageDefinition.stageType == "boss"
end

function Game:getBossWarningLines()
  local lines = {
    "You are about to enter a boss encounter.",
    "",
    string.format("Target Score: %d", self.stageState and self.stageState.targetScore or 0),
    string.format("Flips Available: %d", self.stageState and self.stageState.flipsRemaining or 0),
    string.format("Current Build: %s", self:getCurrentLoadoutKey()),
  }

  local equippedNames = self:getEquippedCoinNames()
  if #equippedNames > 0 then
    table.insert(lines, "")
    table.insert(lines, "Equipped Coins:")

    for _, coinName in ipairs(equippedNames) do
      table.insert(lines, "- " .. coinName)
    end
  end

  local modifierLines = self:getActiveModifierDetailLines()
  if #modifierLines > 0 then
    table.insert(lines, "")

    for _, line in ipairs(modifierLines) do
      table.insert(lines, line)
    end
  end

  return lines
end

function Game:getRewardPreviewLines()
  local result = self.lastStageResult or {}
  local lines = {
    string.format("Stage Cleared: %s", result.stageLabel or "n/a"),
    string.format("Run Total Score: %d", result.runTotalScore or (self.runState and self.runState.runTotalScore or 0)),
    string.format("Shop Points Ready: %d", result.shopPoints or (self.runState and self.runState.shopPoints or 0)),
    string.format("Free Shop Rerolls: %d", result.shopRerollsRemaining or (self.runState and self.runState.shopRerollsRemaining or 0)),
    string.format("Loadout Key: %s", result.loadoutKey or self:getCurrentLoadoutKey()),
    string.format("Owned Upgrades: %d", #(self.runState and self.runState.ownedUpgradeIds or {})),
  }

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Meta Reward Banked: %d", result.metaRewardEarned))
  end

  table.insert(lines, "")
  table.insert(lines, "Use this stop to plan the shop and the round after it.")

  local rewardSession = self.rewardPreviewSession
  if rewardSession and rewardSession.claimed and rewardSession.choice then
    table.insert(lines, string.format("Chosen Reward: %s", rewardSession.choice.name or rewardSession.choice.contentId or "n/a"))
  elseif rewardSession and #(rewardSession.options or {}) == 0 then
    table.insert(lines, "Reward Choice: no valid rewards remain; continue directly to the shop.")
  else
    table.insert(lines, "Reward Choice: choose one reward before continuing.")
  end

  return lines
end

function Game:getProjectedRewardOutcome()
  if not self.runState then
    return nil
  end

  local session = self:getRewardSession()

  if not session then
    return nil
  end

  local projectedOutcome, errorMessage = RewardSystem.buildProjectedOutcome(self.runState, session)

  if not projectedOutcome then
    self.logger:warn("Projected reward outcome unavailable", { error = errorMessage or "unknown" })
    return nil, errorMessage
  end

  return projectedOutcome
end

function Game:buildStagePreviewDataForRun(runState, stageDefinition, options)
  local previewOptions = options or {}

  if not runState or not stageDefinition then
    return {
      title = previewOptions.emptyTitle or "Upcoming Stage",
      stageDefinition = nil,
      flipsPerStage = 0,
      isBoss = false,
      lines = { previewOptions.emptyMessage or "No stage is currently planned." },
      cards = {},
    }
  end

  local flipsPerStage = EffectiveValueSystem.getEffectiveValue("stage.flipsPerStage", runState, nil, {
    metaProjection = runState.metaProjection,
    stageDefinition = stageDefinition,
  })
  local isBoss = stageDefinition.stageType == "boss"
  local cards = isBoss
    and self:getBossModifierCards(stageDefinition.bossModifierIds or {})
    or self:getStageModifierCards(stageDefinition.activeStageModifierIds or {})
  local lines = {
    string.format("Stage: %s", stageDefinition.label or stageDefinition.name or stageDefinition.id),
    string.format("Type: %s", isBoss and "Boss" or "Standard"),
    string.format("Target Score: %d", stageDefinition.targetScore or 0),
    string.format("Flips Available: %d", flipsPerStage or 0),
  }

  if #cards > 0 then
    table.insert(lines, string.format("Active rules: %d", #cards))
  else
    table.insert(lines, "Active rules: none")
  end

  table.insert(lines, "")
  table.insert(lines, previewOptions.footerNote or (isBoss
    and "Boss warning will appear before the stage starts."
    or "Adapt your build before locking it in."))

  return {
    title = previewOptions.title or (isBoss and "Upcoming Boss" or "Upcoming Stage"),
    stageDefinition = stageDefinition,
    flipsPerStage = flipsPerStage,
    isBoss = isBoss,
    lines = lines,
    cards = cards,
  }
end

function Game:getProjectedRewardImpactLines(options, projected)
  local previewOptions = options or {}
  local projectedOutcome = projected
  local errorMessage = nil

  if projectedOutcome == nil then
    projectedOutcome, errorMessage = self:getProjectedRewardOutcome()
  end
  local session = self:getRewardSession()

  if not projectedOutcome then
    return { string.format("Projected reward impact unavailable: %s", tostring(errorMessage or "n/a")) }
  end

  local lines = {}
  local option = projectedOutcome.option

  if option then
    table.insert(lines, string.format("Selected Reward: %s — %s", string.upper(option.type or "?"), option.name or option.contentId or "Unknown"))
  elseif session and #(session.options or {}) > 0 and session.claimed ~= true then
    table.insert(lines, "Selected Reward: pending choice")
  else
    table.insert(lines, "Selected Reward: none")
  end

  table.insert(lines, string.format(
    "Collection Size: %d → %d (%+d)",
    projectedOutcome.collectionSizeBefore,
    projectedOutcome.collectionSizeAfter,
    projectedOutcome.collectionSizeAfter - projectedOutcome.collectionSizeBefore
  ))
  table.insert(lines, string.format(
    "Owned Upgrades: %d → %d (%+d)",
    projectedOutcome.upgradeCountBefore,
    projectedOutcome.upgradeCountAfter,
    projectedOutcome.upgradeCountAfter - projectedOutcome.upgradeCountBefore
  ))

  if projectedOutcome.shopPointsAfter ~= projectedOutcome.shopPointsBefore then
    table.insert(lines, string.format(
      "Shop Points: %d → %d (%+d)",
      projectedOutcome.shopPointsBefore,
      projectedOutcome.shopPointsAfter,
      projectedOutcome.shopPointsAfter - projectedOutcome.shopPointsBefore
    ))
  end

  if projectedOutcome.shopRerollsAfter ~= projectedOutcome.shopRerollsBefore then
    table.insert(lines, string.format(
      "Shop Rerolls: %d → %d (%+d)",
      projectedOutcome.shopRerollsBefore,
      projectedOutcome.shopRerollsAfter,
      projectedOutcome.shopRerollsAfter - projectedOutcome.shopRerollsBefore
    ))
  end

  if projectedOutcome.maxSlotsAfter ~= projectedOutcome.maxSlotsBefore then
    table.insert(lines, string.format(
      "Max Active Slots: %d → %d (%+d)",
      projectedOutcome.maxSlotsBefore,
      projectedOutcome.maxSlotsAfter,
      projectedOutcome.maxSlotsAfter - projectedOutcome.maxSlotsBefore
    ))
  end

  table.insert(lines, "")

  if option == nil then
    if session and #(session.options or {}) > 0 and session.claimed ~= true then
      if previewOptions.finalReward == true then
        table.insert(lines, "Choose a final reward to preview its completed-run impact.")
      else
        table.insert(lines, "Choose a reward to preview how it changes the upcoming shop and next stage.")
      end
    elseif previewOptions.finalReward == true then
      table.insert(lines, "No reward will be added; the completed run record remains unchanged.")
    else
      table.insert(lines, "No reward will be added; the run continues unchanged.")
    end
  elseif option.type == "coin" then
    if previewOptions.finalReward == true then
      table.insert(lines, "On continue, the coin is added to the completed run record for this victory.")
    else
      table.insert(lines, "On continue, the coin is added to your collection but is not auto-equipped for the next round.")
    end
  else
    if previewOptions.finalReward == true then
      table.insert(lines, "On continue, the upgrade is recorded on the completed run.")
    else
      table.insert(lines, "On continue, the upgrade becomes active for the next shop/loadout steps.")
    end
  end

  if previewOptions.finalReward == true and (
    projectedOutcome.shopPointsAfter ~= projectedOutcome.shopPointsBefore
    or projectedOutcome.shopRerollsAfter ~= projectedOutcome.shopRerollsBefore
    or projectedOutcome.maxSlotsAfter ~= projectedOutcome.maxSlotsBefore
  ) then
    table.insert(lines, "If claimed, these changes are recorded on the completed run, but no further shop or loadout step follows.")
  end

  return lines
end

function Game:getShopPreviewLinesForRun(runState)
  if not runState then
    return { "Next stop: shop", "Shop preview unavailable." }
  end

  local shopRules = EffectiveValueSystem.getShopRules(runState, self.stageState, {
    metaProjection = runState.metaProjection,
  })
  local unlockedCoinCount = #(Coins.getUnlockedIds(runState.unlockedCoinIds or {}) or {})
  local unlockedUpgradeCount = #(Upgrades.getUnlockedIds(runState.unlockedUpgradeIds or {}) or {})
  local lines = {
    "Next stop: shop",
    string.format("Offer Count: %d", shopRules.offerCount),
    string.format("Guaranteed Coin Offers: %d", shopRules.guaranteedCoinOffers),
    string.format("Guaranteed Upgrade Offers: %d", shopRules.guaranteedUpgradeOffers),
    string.format("Paid Reroll Cost: %d", shopRules.rerollCost),
    string.format("Unlocked Coin Pool: %d", unlockedCoinCount),
    string.format("Unlocked Upgrade Pool: %d", unlockedUpgradeCount),
    string.format(
      "Quality bias: common x%.2f • uncommon x%.2f • rare x%.2f",
      shopRules.rarityWeights.common,
      shopRules.rarityWeights.uncommon,
      shopRules.rarityWeights.rare
    ),
  }

  local upcomingStage = nil

  if self.getUpcomingStageDefinitionForRun then
    upcomingStage = self:getUpcomingStageDefinitionForRun(runState)
  else
    upcomingStage = Stages.getForRound(runState.roundIndex + 1, runState)
  end

  if upcomingStage then
    table.insert(lines, "")
    table.insert(lines, string.format("After the shop: %s", upcomingStage.label))

    if upcomingStage.stageType == "boss" then
      table.insert(lines, "A boss warning will appear before the fight starts.")
    end
  end

  return lines
end

function Game:getProjectedShopPreviewLines(projected)
  local projectedOutcome, projectionError = projected, nil

  if projectedOutcome == nil then
    projectedOutcome, projectionError = self:getProjectedRewardOutcome()
  end

  if projectionError and not projectedOutcome then
    return {
      "Next stop: shop",
      string.format("Projected shop outlook unavailable: %s", tostring(projectionError)),
    }
  end

  return self:getShopPreviewLinesForRun(projectedOutcome and projectedOutcome.projectedRunState or self.runState)
end

function Game:getProjectedUpcomingStagePreviewData(projected)
  local projectedOutcome, projectionError = projected, nil

  if projectedOutcome == nil then
    projectedOutcome, projectionError = self:getProjectedRewardOutcome()
  end

  if projectionError and not projectedOutcome then
    return {
      title = "After the Shop",
      stageDefinition = nil,
      flipsPerStage = 0,
      isBoss = false,
      lines = { string.format("Projected next-stage preview unavailable: %s", tostring(projectionError)) },
      cards = {},
    }
  end

  local projectedRunState = projectedOutcome and projectedOutcome.projectedRunState or self.runState
  local stageDefinition = projectedRunState and Stages.getForRound(projectedRunState.roundIndex + 1, projectedRunState) or nil

  return self:buildStagePreviewDataForRun(projectedRunState, stageDefinition, {
    title = "After the Shop",
    emptyTitle = "After the Shop",
    emptyMessage = "No next stage is queued after this shop.",
    footerNote = "Use the shop to prepare for this next round.",
  })
end

function Game:getRewardSession()
  return self.rewardPreviewSession
end

function Game:shouldUseBossRewardEvent()
  return self.lastStageResult ~= nil
    and self.lastStageResult.stageType == "boss"
    and self.lastStageResult.status == "cleared"
    and self.runState ~= nil
    and self.runState.runStatus == "won"
end

function Game:ensureRewardSession()
  if not (self:shouldUseRewardPreview() or self:shouldUseBossRewardEvent()) then
    return nil
  end

  if self.rewardPreviewSession then
    return self.rewardPreviewSession
  end

  self.rewardPreviewSession = RewardSystem.buildPreview(self.runState, self.runRng)
  RunHistorySystem.recordStageRewardPreview(self.lastStageResult, self.rewardPreviewSession)
  self:assertRuntimeInvariants("game.ensureRewardSession", { history = true })
  return self.rewardPreviewSession
end

function Game:shouldUseRewardPreview()
  return self.lastStageResult ~= nil
    and self.lastStageResult.stageType ~= "boss"
    and self.lastStageResult.status == "cleared"
    and self.runState ~= nil
    and self.runState.runStatus == "active"
end

function Game:ensureRewardPreview()
  if not self:shouldUseRewardPreview() then
    return nil
  end

  return self:ensureRewardSession()
end

function Game:ensureBossRewardEvent()
  if not self:shouldUseBossRewardEvent() then
    return nil
  end

  return self:ensureRewardSession()
end

function Game:selectRewardOption(index)
  local session = self:getRewardSession()

  if not session then
    return false, "reward_preview_unavailable"
  end

  local ok, result = RewardSystem.selectOption(session, index)

  if ok then
    local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
    if currentStateName == "reward_preview" or currentStateName == "boss_reward" then
      self:saveActiveRun("reward_selection", currentStateName)
    end
  end

  return ok, result
end

function Game:canContinueRewardPreview()
  local session = self:getRewardSession()
  return RewardSystem.canContinue(session)
end

function Game:getRewardPreviewOptionCards()
  local session = self:getRewardSession()
  local cards = {}

  for index, option in ipairs(session and session.options or {}) do
    table.insert(cards, {
      index = index,
      type = option.type,
      contentId = option.contentId,
      name = option.name,
      rarity = option.rarity,
      description = option.description,
      selected = session.selectedIndex == index,
      claimed = session.claimed == true and session.choice and session.choice.contentId == option.contentId,
    })
  end

  return cards
end

function Game:getRewardPreviewContinueLabel()
  local session = self:getRewardSession()

  if not session or #(session.options or {}) == 0 then
    return "Continue to Shop"
  end

  if session.claimed == true then
    return "Continue to Shop"
  end

  return "Claim Reward & Continue"
end

function Game:getBossRewardContinueLabel()
  local session = self:getRewardSession()

  if not session or #(session.options or {}) == 0 then
    return "Continue to Summary"
  end

  if session.claimed == true then
    return "Continue to Summary"
  end

  return "Claim Final Reward & Continue"
end

function Game:getBossRewardLines()
  local result = self.lastStageResult or {}
  local session = self:getRewardSession()
  local lines = {
    string.format("Boss Cleared: %s", result.stageLabel or "n/a"),
    string.format("Final Run Score: %d", result.runTotalScore or (self.runState and self.runState.runTotalScore or 0)),
    string.format("Final Loadout: %s", result.loadoutKey or self:getCurrentLoadoutKey()),
  }

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Meta Reward Banked: %d", result.metaRewardEarned))
  end

  table.insert(lines, "")
  table.insert(lines, "Choose one final reward before the run summary.")

  if session and session.claimed and session.choice then
    table.insert(lines, string.format("Chosen Reward: %s", session.choice.name or session.choice.contentId or "n/a"))
  elseif session and #(session.options or {}) == 0 then
    table.insert(lines, "Reward Choice: no valid rewards remain; continue to the summary.")
  else
    table.insert(lines, "Reward Choice: choose one reward before continuing.")
  end

  return lines
end

function Game:getBossRewardSummaryLines()
  local result = self.lastStageResult or {}
  local lines = {
    string.format("Boss Cleared: %s", result.stageLabel or "n/a"),
    string.format("Final Run Score: %d", result.runTotalScore or (self.runState and self.runState.runTotalScore or 0)),
    string.format("Final Loadout: %s", result.loadoutKey or self:getCurrentLoadoutKey()),
  }

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Meta Reward Banked: %d", result.metaRewardEarned))
  end

  table.insert(lines, "")
  table.insert(lines, "Review the victory reward, then continue to the final summary.")

  return lines
end

function Game:claimSelectedReward()
  local session = self:getRewardSession()

  if not session then
    return false, "reward_preview_unavailable"
  end

  local ok, result = RewardSystem.claimSelection(self.runState, session)

  if not ok then
    return false, result
  end

  RunHistorySystem.recordStageRewardChoice(self.lastStageResult, result)
  self:assertRuntimeInvariants("game.claimSelectedReward", { history = true })

  if result then
    self.logger:info("Claimed stage reward", {
      type = result.type,
      contentId = result.contentId,
    })
    local feedbackMessage = string.format("%s joined the run.", result.name or result.contentId or "Reward")

    if self:shouldUseBossRewardEvent() then
      feedbackMessage = string.format("%s was recorded for this victory.", result.name or result.contentId or "Reward")
    end

    self:showFeedback("success", "Reward Claimed", feedbackMessage, {
      duration = 1.05,
      flashAlpha = 0.05,
      soundCue = "shop_purchase",
    })
  else
    self.logger:info("No reward claim available; continuing to shop")
  end

  local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
  if currentStateName == "reward_preview" or currentStateName == "boss_reward" then
    self:saveActiveRun("claim_reward", currentStateName)
  end

  return true, result
end

function Game:getShopPreviewLines()
  return self:getShopPreviewLinesForRun(self.runState)
end

function Game:getSummaryMetaHandoffLines()
  local summary = self:buildSummary()
  local lines = {
    string.format("Meta Points Available: %d", self.metaState and self.metaState.metaPoints or 0),
    string.format("Purchased Meta Upgrades: %d", #(self.metaState and self.metaState.purchasedMetaUpgradeIds or {})),
  }

  if (summary.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Meta Reward Ready to Spend: %d", summary.metaRewardEarned))
    table.insert(lines, "Open Meta Progression from here to invest it immediately.")
    table.insert(lines, "From Meta Progression you can start the next run directly.")
  else
    table.insert(lines, "Open Meta Progression to review persistent upgrades before the next run.")
    table.insert(lines, "From Meta Progression you can return here or jump straight into the next run.")
  end

  return lines
end

function Game:describeTriggeredSource(source)
  if not source then
    return "n/a"
  end

  local label = source.sourceName or source.sourceId

  if source.sourceType == "equipped coin" then
    label = self:getCoinName(source.sourceId)
  elseif source.sourceType == "run upgrade" then
    label = self:getUpgradeName(source.sourceId)
  elseif source.sourceType == "stage modifier" then
    label = self:getStageModifierName(source.sourceId)
  elseif source.sourceType == "boss modifier" then
    label = self:getBossModifierName(source.sourceId)
  end

  if source.coinId and source.coinId ~= source.sourceId then
    return string.format("%s (%s on %s)", source.phase, label, self:getCoinName(source.coinId))
  end

  return string.format("%s (%s)", source.phase, label)
end

function Game:describeAction(action)
  if not action then
    return "n/a"
  end

  if action.op == "add_stage_score" or action.op == "add_run_score" or action.op == "add_shop_points" then
    local amount = action.appliedAmount or action.amount
    return string.format("%s %+d", action.op, amount)
  end

  if action.op == "modify_coin_weight" then
    return string.format("%s %s %+0.2f", action.op, action.side, action.amount)
  end

  if action.op == "apply_score_multiplier" then
    return string.format("%s x%.2f", action.op, action.value)
  end

  if action.op == "grant_coin" then
    return string.format("%s %s", action.op, self:getCoinName(action.coinId))
  end

  if action.op == "grant_upgrade" then
    return string.format("%s %s", action.op, self:getUpgradeName(action.upgradeId))
  end

  if action.op == "grant_temporary_effect" then
    return string.format("%s %s", action.op, action.effect and action.effect.name or action.effect and action.effect.id or "temporary effect")
  end

  if action.op == "consume_effect" then
    return string.format("%s %s", action.op, tostring(action.effectId or "temporary effect"))
  end

  if action.op == "queue_actions" then
    return string.format("%s -> %s (%d)", action.op, tostring(action.phase), #(action.actions or {}))
  end

  return action.op
end

function Game:formatBatchLogLine(batchResult)
  local coinSummaries = {}

  for _, coinState in ipairs(batchResult.perCoin or {}) do
    table.insert(
      coinSummaries,
      string.format(
        "%s@S%d/R%d roll=%.2f H%.2f/T%.2f => %s%s",
        self:getCoinName(coinState.coinId),
        coinState.slotIndex or 0,
        coinState.resolutionIndex or 0,
        coinState.rngRoll or 0,
        coinState.headsWeight or 0,
        coinState.tailsWeight or 0,
        string.upper(coinState.result or "?"),
        coinState.forcedResult and " [FORCED]" or ""
      )
    )
  end

  return string.format(
    "R%d B%d | call=%s | %s | stage %d/%d | run %d | shop %d | status=%s",
    self.runState and self.runState.roundIndex or 0,
    batchResult.batchId,
    string.upper(batchResult.call or "?"),
    table.concat(coinSummaries, " ; "),
    batchResult.stageScore or 0,
    batchResult.targetScore or 0,
    batchResult.runTotalScore or 0,
    batchResult.shopPoints or 0,
    batchResult.status or "active"
  )
end

function Game:getLastBatchSummaryLines(limit)
  local lines = {}
  local batchResult = self.lastBatchResult

  if not batchResult then
    return { "No batch resolved yet." }
  end

  table.insert(lines, string.format("Batch %d | call %s", batchResult.batchId, string.upper(batchResult.call)))

  for _, coinState in ipairs(batchResult.perCoin or {}) do
    table.insert(
      lines,
      string.format(
        "%s @ slot %d / order %d | H%.2f/T%.2f | %.2f => %s%s",
        self:getCoinName(coinState.coinId),
        coinState.slotIndex or 0,
        coinState.resolutionIndex or 0,
        coinState.headsWeight,
        coinState.tailsWeight,
        coinState.rngRoll or 0,
        string.upper(coinState.result or "?"),
        coinState.forcedResult and " [FORCED]" or ""
      )
    )
  end

  for _, forced in ipairs(batchResult.trace and batchResult.trace.forcedResults or {}) do
    table.insert(lines, string.format("Forced: %s -> %s (slot %s / order %s)", self:getCoinName(forced.coinId), string.upper(forced.result or "?"), tostring(forced.slotIndex or "?"), tostring(forced.resolutionIndex or "?")))
  end

  for _, source in ipairs(batchResult.trace and batchResult.trace.triggeredSources or {}) do
    table.insert(lines, "Trigger: " .. self:describeTriggeredSource(source))
  end

  for _, action in ipairs(batchResult.trace and batchResult.trace.actions or {}) do
    table.insert(lines, "Action: " .. self:describeAction(action))
  end

  for _, effect in ipairs(batchResult.trace and batchResult.trace.temporaryEffectsGranted or {}) do
    table.insert(lines, string.format("Temp granted: %s", effect.name or effect.baseEffectId or effect.id))
  end

  for _, effectId in ipairs(batchResult.trace and batchResult.trace.temporaryEffectsConsumed or {}) do
    table.insert(lines, string.format("Temp consumed: %s", tostring(effectId)))
  end

  for _, queued in ipairs(batchResult.trace and batchResult.trace.queuedActions or {}) do
    table.insert(lines, string.format("Queued: %s x%d (depth %d)", tostring(queued.phase), queued.actionCount or 0, queued.chainDepth or 0))
  end

  for _, warning in ipairs(batchResult.trace and batchResult.trace.warnings or {}) do
    table.insert(lines, "Warning: " .. tostring(warning))
  end

  if limit and #lines > limit then
    local trimmed = {}
    for index = 1, limit do
      trimmed[index] = lines[index]
    end
    return trimmed
  end

  return lines
end

function Game:getScoreBreakdownLines(limit)
  local lines = {}
  local breakdown = self.lastBatchResult and self.lastBatchResult.scoreBreakdown or nil

  if not breakdown then
    return { "No score breakdown yet." }
  end

  local stageBonusDelta = 0
  local runBonusDelta = 0

  for _, bonus in ipairs(breakdown.additiveBonuses or {}) do
    if bonus.scoreTarget == "stage" then
      stageBonusDelta = stageBonusDelta + (bonus.amount or 0)
    elseif bonus.scoreTarget == "run" then
      runBonusDelta = runBonusDelta + (bonus.amount or 0)
    end
  end

  table.insert(lines, string.format("Base score: %d", breakdown.baseScore or 0))
  table.insert(lines, string.format("After multipliers: %d", breakdown.finalBaseScore or breakdown.baseScore or 0))
  table.insert(lines, string.format("Stage bonus delta: %+d", stageBonusDelta))
  table.insert(lines, string.format("Run bonus delta: %+d", runBonusDelta))
  table.insert(lines, string.format("Stage total gained: %+d", breakdown.totalStageScoreDelta or 0))
  table.insert(lines, string.format("Run total gained: %+d", breakdown.totalRunScoreDelta or 0))
  table.insert(lines, string.format("Triggered sources: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.triggeredSources or {})))
  table.insert(lines, string.format("Emitted actions: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.actions or {})))
  table.insert(lines, string.format("Queued follow-ups: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.queuedActions or {})))

  if #(self.lastBatchResult.trace and self.lastBatchResult.trace.temporaryEffectsGranted or {}) > 0 then
    table.insert(lines, string.format("Temp effects granted: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.temporaryEffectsGranted or {})))
  end

  if (breakdown.totalShopPointDelta or 0) ~= 0 then
    table.insert(lines, string.format("Shop point delta: %+d", breakdown.totalShopPointDelta or 0))
  end

  for _, multiplier in ipairs(breakdown.multipliers or {}) do
    table.insert(lines, string.format("Multiplier: x%.2f", multiplier.value or 1.0))
  end

  for _, bonus in ipairs(breakdown.additiveBonuses or {}) do
    local amount = bonus.amount or bonus.value or 0
    table.insert(lines, string.format("Bonus: %s %+d", bonus.op or "effect", amount))
  end

  for _, note in ipairs(breakdown.notes or {}) do
    table.insert(lines, "Note: " .. tostring(note))
  end

  if limit and #lines > limit then
    local trimmed = {}
    for index = 1, limit do
      trimmed[index] = lines[index]
    end
    return trimmed
  end

  return lines
end

return Game
