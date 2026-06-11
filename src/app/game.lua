local Bosses = require("src.content.bosses")
local AnalyticsSystem = require("src.systems.analytics_system")
local AudioSystem = require("src.systems.audio_system")
local Button = require("src.ui.button")
local CoinDetailContent = require("src.content.coin_detail_content")
local Coins = require("src.content.coins")
local EncounterSystem = require("src.systems.encounter_system")
local DebugOverlay = require("src.ui.debug_overlay")
local DevBuilds = require("src.content.dev_builds")
local EffectiveValueSystem = require("src.systems.effective_value_system")
local FountainSystem = require("src.systems.fountain_system")
local GameConfig = require("src.app.config")
local HookRegistry = require("src.core.hook_registry")
local Layout = require("src.ui.layout")
local Loadout = require("src.domain.loadout")
local LoadoutSystem = require("src.systems.loadout_system")
local LuckSystem = require("src.systems.luck_system")
local Log = require("src.core.log")
local MetaProgressionSystem = require("src.systems.meta_progression_system")
local MetaState = require("src.domain.meta_state")
local MetaUpgrades = require("src.content.meta_upgrades")
local OutcomeBurst = require("src.ui.outcome_burst")
local ProgressionSystem = require("src.systems.progression_system")
local PurseHookSystem = require("src.systems.purse_hook_system")
local PurseSystem = require("src.systems.purse_system")
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
local Terminology = require("src.content.terminology")
local TrickCharm = require("src.ui.trick_charm")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local Game = {}
Game.__index = Game

local function createConfiguredFont(name, size)
  local fontPath = Theme.getFontPath(name)
  local fontSize = Theme.getFontSize(name, size)
  local font = fontPath and love.graphics.newFont(fontPath, fontSize) or love.graphics.newFont(fontSize)

  if font.setFilter then
    font:setFilter("nearest", "nearest")
  end

  return font
end

local function createFonts(fontSizes)
  fontSizes = fontSizes or Theme.fontSizes

  return {
    title = createConfiguredFont("title", fontSizes.title),
    heading = createConfiguredFont("heading", fontSizes.heading),
    body = createConfiguredFont("body", fontSizes.body),
    small = createConfiguredFont("small", fontSizes.small),
    outcomeBurst = createConfiguredFont("outcomeBurst", fontSizes.outcomeBurst),
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

local function createPauseFlowContext(returnState, returnPayload)
  return {
    returnState = returnState,
    returnPayload = Utils.clone(returnPayload or {}),
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
    selectedCall = nil,
    lastBatchResult = nil,
    lastStageResult = nil,
    postResultNextState = nil,
    rewardPreviewSession = nil,
    encounterSession = nil,
    fountainSession = nil,
    shopOffers = {},
    shopSession = nil,
    lastShopGenerationTrace = nil,
    lastShopPurchaseTrace = nil,
    metaFlowContext = createMenuMetaFlowContext(),
    pauseFlowContext = nil,
    preserveActiveRunSaveOnce = false,
    feedbackClock = 0,
    activeFeedback = nil,
    activeOutcomeBurst = nil,
    outcomeBurstQueue = {},
    screenFlash = {
      color = Theme.colors.accent,
      alpha = 0,
    },
    metaSaveStatus = {
      level = "info",
      message = "Reputation save not loaded yet.",
    },
    activeRunArtifact = nil,
    activeRunSaveAvailable = false,
    displayTargetId = Layout.getDefaultDisplayTargetId(),
    displaySettingsStatus = {
      level = "info",
      message = "Display settings not loaded yet.",
    },
    uiMetrics = nil,
  }, Game)

  self.stateGraph = StateGraph.new(self, StepBuilder, logger)
  self.debugOverlay = DebugOverlay.new(self)

  return self
end

function Game:refreshUiMetrics(width, height)
  local target = Layout.getDisplayTargetById(self.displayTargetId) or Layout.getDisplayTargetById(Layout.getDefaultDisplayTargetId())
  local nextMetrics = Layout.resolveViewport(width or target.width, height or target.height)
  local previousTier = self.uiMetrics and self.uiMetrics.tier or nil

  self.uiMetrics = nextMetrics
  Theme.applyViewportMetrics(nextMetrics)

  if not self.fonts or previousTier ~= nextMetrics.tier then
    self.fonts = createFonts(nextMetrics.fontSizes)
    Button.setDefaultFont(self.fonts.body)
    love.graphics.setFont(self.fonts.body)
  end

  return nextMetrics
end

function Game:getUiMetrics()
  return self.uiMetrics or self:refreshUiMetrics()
end

function Game:getDisplayTargets()
  return Layout.getDisplayTargets()
end

function Game:getDisplayTarget()
  return Layout.getDisplayTargetById(self.displayTargetId) or Layout.getDisplayTargetById(Layout.getDefaultDisplayTargetId())
end

function Game:getDisplayTargetId()
  return self.displayTargetId
end

function Game:getDisplayTransform()
  local target = self:getDisplayTarget()
  local physicalWidth, physicalHeight = love.graphics.getDimensions()
  local scale = math.min(physicalWidth / target.width, physicalHeight / target.height)

  if scale <= 0 then
    scale = 1
  end

  local scaledWidth = target.width * scale
  local scaledHeight = target.height * scale

  return {
    x = math.floor((physicalWidth - scaledWidth) * 0.5),
    y = math.floor((physicalHeight - scaledHeight) * 0.5),
    scale = scale,
    width = target.width,
    height = target.height,
  }
end

function Game:toLogicalPoint(x, y)
  local transform = self:getDisplayTransform()

  return (x - transform.x) / transform.scale, (y - transform.y) / transform.scale
end

function Game:getLogicalMousePosition()
  local x, y = love.mouse.getPosition()

  return self:toLogicalPoint(x, y)
end

function Game:pushDisplayTargetContext()
  local target = self:getDisplayTarget()
  local originalGetWidth = love.graphics.getWidth
  local originalGetHeight = love.graphics.getHeight
  local originalMouseGetPosition = love.mouse.getPosition

  love.graphics.getWidth = function()
    return target.width
  end
  love.graphics.getHeight = function()
    return target.height
  end
  love.mouse.getPosition = function()
    local x, y = originalMouseGetPosition()
    return self:toLogicalPoint(x, y)
  end

  return function()
    love.graphics.getWidth = originalGetWidth
    love.graphics.getHeight = originalGetHeight
    love.mouse.getPosition = originalMouseGetPosition
  end
end

function Game:registerStates()
  self.stateGraph:register("boot", require("src.states.boot_state").new())
  self.stateGraph:register("menu", require("src.states.menu_state").new())
  self.stateGraph:register("settings", require("src.states.settings_state").new())
  self.stateGraph:register("run_setup", require("src.states.run_setup_state").new())
  self.stateGraph:register("help", require("src.states.help_state").new())
  self.stateGraph:register("collection", require("src.states.collection_state").new())
  self.stateGraph:register("records", require("src.states.records_state").new())
  self.stateGraph:register("pause", require("src.states.pause_state").new())
  self.stateGraph:register("loadout", require("src.states.loadout_state").new())
  self.stateGraph:register("boss_warning", require("src.states.boss_warning_state").new())
  self.stateGraph:register("stage", require("src.states.stage_state").new())
  self.stateGraph:register("result", require("src.states.result_state").new())
  self.stateGraph:register("post_stage_analytics", require("src.states.post_stage_analytics_state").new())
  self.stateGraph:register("reward_preview", require("src.states.reward_preview_state").new())
  self.stateGraph:register("boss_reward", require("src.states.boss_reward_state").new())
  self.stateGraph:register("encounter", require("src.states.encounter_state").new())
  self.stateGraph:register("fountain", require("src.states.fountain_state").new())
  self.stateGraph:register("shop", require("src.states.shop_state").new())
  self.stateGraph:register("summary", require("src.states.summary_state").new())
  self.stateGraph:register("meta", require("src.states.meta_state").new())
end

function Game:applyDisplayTargetWindow()
  local target = self:getDisplayTarget()
  local _, _, flags = love.window.getMode()
  local desktopWidth, desktopHeight = love.window.getDesktopDimensions()
  local windowWidth = math.min(target.width, desktopWidth)
  local windowHeight = math.min(target.height, desktopHeight)
  local ok, errorMessage = love.window.setMode(windowWidth, windowHeight, {
    resizable = true,
    vsync = flags and flags.vsync or 1,
    msaa = flags and flags.msaa or 0,
  })

  if ok == false then
    return false, errorMessage or "set_mode_failed"
  end

  return true
end

function Game:loadDisplaySettings()
  local settings, errorMessage = SaveSystem.loadDisplaySettings()

  if settings then
    if Layout.getDisplayTargetById(settings.targetResolutionId) then
      self.displayTargetId = settings.targetResolutionId
      self.displaySettingsStatus = {
        level = "success",
        message = "Display settings loaded.",
      }
      return true
    end

    errorMessage = "unknown_display_target"
  end

  self.displaySettingsStatus = {
    level = errorMessage == "not_found" and "info" or "warning",
    message = errorMessage == "not_found" and "Using default display settings." or string.format("Display settings not loaded: %s", tostring(errorMessage)),
  }
  return false, errorMessage
end

function Game:saveDisplaySettings(reason)
  local ok, errorMessage = SaveSystem.saveDisplaySettings({
    targetResolutionId = self.displayTargetId,
  })

  self.displaySettingsStatus = {
    level = ok and "success" or "warning",
    message = ok and string.format("Display settings saved (%s).", reason or "manual") or string.format("Display settings save failed: %s", tostring(errorMessage)),
  }

  return ok, errorMessage
end

function Game:setDisplayTarget(targetId)
  local target = Layout.getDisplayTargetById(targetId)

  if not target then
    return false, "unknown_display_target"
  end

  local previousTargetId = self.displayTargetId
  self.displayTargetId = target.id
  self:refreshUiMetrics(target.width, target.height)

  local ok, errorMessage = self:applyDisplayTargetWindow()
  if ok == false then
    self.displayTargetId = previousTargetId
    self:refreshUiMetrics()
    return false, errorMessage
  end

  self:saveDisplaySettings("settings")
  return true
end

function Game:validateContentRegistries()
  local registries = {
    coins = Coins.getAll(),
    upgrades = Upgrades.getAll(),
    bosses = Bosses.getAll(),
    encounters = require("src.content.encounters").getAll(),
    stage_modifiers = StageModifiers.getAll(),
    stages = Stages.getAll(),
    meta_upgrades = MetaUpgrades.getAll(),
  }

  for name, definitions in pairs(registries) do
    local ok, errorMessage

    if name == "encounters" then
      ok, errorMessage = Validator.validateEncounterRegistry(definitions)
    else
      ok, errorMessage = Validator.validateContentRegistry(name, definitions)
    end

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
    self:updateMetaSaveStatus("info", "Loaded Reputation save from disk.")
    self.logger:info("Loaded meta save", { path = SaveSystem.META_STATE_PATH })
    return true
  end

  if errorMessage == "not_found" then
    self.metaState = MetaState.new()
    self:updateMetaSaveStatus("info", "No Reputation save found yet; starting fresh.")
    self.logger:info("No meta save found; using defaults", { path = SaveSystem.META_STATE_PATH })
    return false
  end

  self.metaState = MetaState.new()
  self:updateMetaSaveStatus("warn", "Reputation save load failed; using defaults.")
  self.logger:warn("Failed to load meta save", { error = errorMessage or "unknown", path = SaveSystem.META_STATE_PATH })
  return false
end

function Game:saveMetaState(reason)
  local ok, errorMessage = SaveSystem.saveMetaState(self.metaState)

  if ok then
    self:updateMetaSaveStatus("info", string.format("Autosaved Reputation progress (%s).", reason or "manual"))
    self.logger:info("Saved meta state", { reason = reason or "manual", path = SaveSystem.META_STATE_PATH })
    return true
  end

  self:updateMetaSaveStatus("warn", string.format("Reputation save failed (%s).", reason or "manual"))
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

function Game:createPauseFlowContext(returnState, returnPayload)
  return createPauseFlowContext(returnState, returnPayload)
end

function Game:setPauseFlowContext(context)
  if context == nil then
    self.pauseFlowContext = nil
    return
  end

  self.pauseFlowContext = createPauseFlowContext(context.returnState, context.returnPayload)
end

function Game:getPauseFlowContext()
  local context = self.pauseFlowContext
  return context and createPauseFlowContext(context.returnState, context.returnPayload) or nil
end

function Game:getPauseResumeStateName()
  local context = self.pauseFlowContext
  return context and context.returnState or nil
end

function Game:getPauseResumePayload()
  local context = self.pauseFlowContext
  return context and Utils.clone(context.returnPayload or {}) or {}
end

function Game:buildActiveRunSnapshot(currentStateName, screenStateOverride)
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
    encounter = true,
    fountain = true,
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
    postResultNextState = self.postResultNextState,
    rewardPreviewSession = Utils.clone(self.rewardPreviewSession),
    encounterSession = Utils.clone(self.encounterSession),
    fountainSession = Utils.clone(self.fountainSession),
    shopOffers = Utils.clone(self.shopOffers or {}),
    shopSession = Utils.clone(self.shopSession),
    lastShopGenerationTrace = Utils.clone(self.lastShopGenerationTrace),
    lastShopPurchaseTrace = Utils.clone(self.lastShopPurchaseTrace),
    currentStageDefinitionId = self.currentStageDefinition and self.currentStageDefinition.id or nil,
    screenState = Utils.clone(screenStateOverride ~= nil and screenStateOverride or self:getCurrentStateResumePayload()),
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

function Game:saveActiveRun(reason, currentStateName, screenStateOverride)
  local snapshot, errorMessage = self:buildActiveRunSnapshot(currentStateName, screenStateOverride)

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

  self.selectedCall = artifact.selectedCall
  self.lastBatchResult = Utils.clone(artifact.lastBatchResult)
  self.lastStageResult = Utils.clone(artifact.lastStageResult)
  self.postResultNextState = artifact.postResultNextState or self:computePostResultNextState()
  self.rewardPreviewSession = Utils.clone(artifact.rewardPreviewSession)
  self.encounterSession = Utils.clone(artifact.encounterSession)
  self.fountainSession = Utils.clone(artifact.fountainSession)
  self.shopOffers = Utils.clone(artifact.shopOffers or {})
  self.shopSession = Utils.clone(artifact.shopSession)
  self.lastShopGenerationTrace = Utils.clone(artifact.lastShopGenerationTrace)
  self.lastShopPurchaseTrace = Utils.clone(artifact.lastShopPurchaseTrace)
  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:setPauseFlowContext(nil)
  self:assertRuntimeInvariants("game.resumeSavedRun", { history = true })
  self.logger:info("Resumed active run", { state = artifact.currentState, seed = self.runState and self.runState.seed or "n/a" })
  return true
end

function Game:preparePause(returnState, returnPayload)
  if not self.runState then
    return false, "run_not_initialized"
  end

  local targetState = returnState or (self.stateGraph and self.stateGraph:getCurrentName()) or nil

  if not targetState then
    return false, "pause_return_state_unavailable"
  end

  self:setPauseFlowContext({
    returnState = targetState,
    returnPayload = returnPayload or self:getCurrentStateResumePayload(),
  })
  local ok, errorMessage = self:saveActiveRun("pause_open", targetState, self:getPauseResumePayload())

  if not ok then
    self.preserveActiveRunSaveOnce = false
    return false, errorMessage
  end

  self.preserveActiveRunSaveOnce = true
  return true
end

function Game:saveAndQuitToMenu()
  if self.runState then
    local pauseContext = self.pauseFlowContext
    local targetState = pauseContext and pauseContext.returnState or (self.stateGraph and self.stateGraph:getCurrentName()) or nil
    local ok, errorMessage = self:saveActiveRun("save_quit_to_menu", targetState, self:getPauseResumePayload())

    if not ok then
      return false, errorMessage or "save_quit_failed"
    end
  end

  self.preserveActiveRunSaveOnce = true
  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:clearRunState()
  return true
end

function Game:abandonRun()
  if self.runState then
    local recordResultType = self.runState.runStatus ~= "active" and self.runState.runStatus or "abandoned"
    local appended, appendError = self:appendRunRecord(recordResultType, self.stageState)

    if appended == false and self.runState.runRecordSaved ~= true then
      return false, appendError or "run_record_save_failed"
    end

    local ok, errorMessage = self:clearActiveRunSave("abandon_run")

    if not ok then
      return false, errorMessage
    end
  end

  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:clearRunState()
  return true
end

function Game:load()
  self:loadDisplaySettings()
  self:applyDisplayTargetWindow()
  self:refreshUiMetrics()
  love.graphics.setFont(self.fonts.body)
  Button.setSoundPlayer(function(cueName)
    if self.audioSystem then
      self.audioSystem:playCue(cueName)
    end
  end)

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
  self:refreshUiMetrics()
  Theme.clearColor(Theme.colors.background)
  local transform = self:getDisplayTransform()
  local restoreDisplayTargetContext = self:pushDisplayTargetContext()

  local pushed = false
  local ok, errorMessage = xpcall(function()
    love.graphics.push()
    pushed = true
    love.graphics.translate(transform.x, transform.y)
    love.graphics.scale(transform.scale, transform.scale)
    self.stateGraph:draw()
    self:drawFeedbackOverlay()
    self:drawOutcomeBurst()
    self.debugOverlay:draw()
  end, debug.traceback)

  if pushed then
    love.graphics.pop()
  end

  restoreDisplayTargetContext()

  if not ok then
    error(errorMessage, 0)
  end
end

function Game:keypressed(key, scancode, isRepeat)
  if key == "f3" and self:isDevControlsEnabled() then
    self.logger:toggleOverlay()
    return
  end

  local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
  local pausableStates = {
    loadout = true,
    boss_warning = true,
    stage = true,
    result = true,
    post_stage_analytics = true,
    reward_preview = true,
    boss_reward = true,
    encounter = true,
    fountain = true,
    shop = true,
  }

  if (key == "escape" or key == "p") and currentStateName ~= "pause" and self.runState and pausableStates[currentStateName] then
    self.stateGraph:request("open_pause")
    return
  end

  self.stateGraph:keypressed(key, scancode, isRepeat)
end

function Game:mousepressed(x, y, button, istouch, presses)
  local logicalX, logicalY = self:toLogicalPoint(x, y)
  local restoreDisplayTargetContext = self:pushDisplayTargetContext()
  local ok, errorMessage = xpcall(function()
    self.stateGraph:mousepressed(logicalX, logicalY, button, istouch, presses)
  end, debug.traceback)

  restoreDisplayTargetContext()

  if not ok then
    error(errorMessage, 0)
  end
end

function Game:mousereleased(x, y, button, istouch, presses)
  local logicalX, logicalY = self:toLogicalPoint(x, y)
  local restoreDisplayTargetContext = self:pushDisplayTargetContext()
  local ok, errorMessage = xpcall(function()
    self.stateGraph:mousereleased(logicalX, logicalY, button, istouch, presses)
  end, debug.traceback)

  restoreDisplayTargetContext()

  if not ok then
    error(errorMessage, 0)
  end
end

function Game:textinput(text)
  self.stateGraph:textinput(text)
end

function Game:wheelmoved(x, y)
  local restoreDisplayTargetContext = self:pushDisplayTargetContext()
  local ok, errorMessage = xpcall(function()
    self.stateGraph:wheelmoved(x, y)
  end, debug.traceback)

  restoreDisplayTargetContext()

  if not ok then
    error(errorMessage, 0)
  end
end

function Game:resize(width, height)
  self:refreshUiMetrics()
  self.stateGraph:resize(width, height)
end

function Game:quit()
  local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil

  if self.runState and currentStateName then
    self:saveActiveRun("quit", currentStateName)
  elseif not self:hasActiveRunSave() then
    self:clearActiveRunSave("quit")
  end

  self:saveMetaState("quit")
  self:saveDisplaySettings("quit")
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

function Game:showOutcomeBurst(label, kind, options)
  if not label or label == "" then
    return
  end

  local color = self:getFeedbackColor(kind)
  local burstOptions = options or {}
  burstOptions.config = burstOptions.config or Theme.outcomeBurst
  burstOptions.color = burstOptions.color or color
  self.activeOutcomeBurst = OutcomeBurst.new(label, burstOptions)
end

function Game:queueOutcomeBurst(label, kind, options)
  if not label or label == "" then
    return
  end

  if not self.activeOutcomeBurst then
    self:showOutcomeBurst(label, kind, options)
    return
  end

  self.outcomeBurstQueue = self.outcomeBurstQueue or {}
  table.insert(self.outcomeBurstQueue, {
    label = label,
    kind = kind,
    options = options,
  })
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

  self.activeOutcomeBurst = OutcomeBurst.update(self.activeOutcomeBurst, dt)

  if not self.activeOutcomeBurst and self.outcomeBurstQueue and #self.outcomeBurstQueue > 0 then
    local nextBurst = table.remove(self.outcomeBurstQueue, 1)
    self:showOutcomeBurst(nextBurst.label, nextBurst.kind, nextBurst.options)
  end

  if (self.screenFlash.alpha or 0) > 0 then
    self.screenFlash.alpha = math.max(0, self.screenFlash.alpha - (dt * 0.32))
  end
end

function Game:drawFeedbackOverlay()
  local ui = self:getUiMetrics()
  local rect = ui.rect
  local window = ui.window
  local previousLineWidth = love.graphics.getLineWidth()

  if (self.screenFlash.alpha or 0) > 0 then
    local flashColor = self.screenFlash.color or Theme.colors.accent
    love.graphics.setColor(flashColor[1], flashColor[2], flashColor[3], self.screenFlash.alpha)
    love.graphics.rectangle("fill", 0, 0, window.width, window.height)
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
  local availableWidth = rect.width - (padding * 2)

  if availableWidth < 220 then
    return
  end

  local bannerWidth = math.max(220, math.min(560, availableWidth))
  local bannerX = rect.x + math.floor((rect.width - bannerWidth) * 0.5)
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

  local bannerY = rect.y + padding + 6 - math.floor((1 - alpha) * 18)
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

function Game:drawOutcomeBurst()
  OutcomeBurst.draw(self.activeOutcomeBurst, self.fonts, self:getUiMetrics().rect)
end

function Game:triggerBatchFeedback(batchResult)
  if not batchResult then
    return
  end

  local label, kind = OutcomeBurst.getBatchLabel(batchResult, Theme.outcomeBurst)

  self:showOutcomeBurst(label, kind)

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
    self:startNewRun(payload)
    return true
  end

  if actionName == "resume_run" then
    return self:resumeSavedRun()
  end

  if actionName == "prepare_pause" then
    return self:preparePause(payload and payload.returnState or nil, payload and payload.returnPayload or nil)
  end

  if actionName == "save_quit_to_menu" then
    return self:saveAndQuitToMenu()
  end

  if actionName == "abandon_run" then
    return self:abandonRun()
  end

  if actionName == "finalize_current_stage" then
    local stageRecord, errorMessage = self:finalizeCurrentStage()
    return stageRecord ~= nil, errorMessage
  end

  if actionName == "prepare_fountain" then
    return self:prepareFountain()
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
    return self:returnToMenu()
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
  local pauseFlowContext = self:getPauseFlowContext()
  local postResultDestinationState = self:getPostResultNextState()

  if currentStateName == "reward_preview" and postResultDestinationState == "reward_preview" then
    postResultDestinationState = "shop"
  end

  return {
    currentStateName = currentStateName,
    payload = Utils.clone(transitionPayload or {}),
    event = transitionPayload and transitionPayload.event or nil,
    postResultDestinationState = postResultDestinationState,
    metaReturnState = metaFlowContext.returnState,
    metaAllowStartRun = metaFlowContext.allowStartRun,
    continueRunState = self:getContinueRunStateName(),
    continueRunPayload = self:getContinueRunPayload(),
    pauseReturnState = pauseFlowContext and pauseFlowContext.returnState or nil,
    pauseReturnPayload = pauseFlowContext and pauseFlowContext.returnPayload or {},
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
      "Cannot create a new Black Market flow without a finalized cleared stage result"
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

function Game:generateRunSeed()
  return math.floor(love.timer.getTime() * 100000) % 2147483646 + 1
end

function Game:normalizeRunSeed(seed)
  if type(seed) == "string" then
    local digits = seed:match("%d+")

    if not digits or digits == "" then
      return self:generateRunSeed()
    end

    local modulus = 2147483646
    local numericSeed = 0

    for i = 1, #digits do
      numericSeed = ((numericSeed * 10) + tonumber(digits:sub(i, i))) % modulus
    end

    if numericSeed == 0 then
      return self:generateRunSeed()
    end

    return ((numericSeed - 1) % modulus) + 1
  end

  local numericSeed = tonumber(seed)

  if not numericSeed then
    return self:generateRunSeed()
  end

  numericSeed = math.floor(math.abs(numericSeed))

  if numericSeed == 0 then
    return self:generateRunSeed()
  end

  return ((numericSeed - 1) % 2147483646) + 1
end

function Game:getRunSetupPreviewLines(seed)
  local normalizedSeed = self:normalizeRunSeed(seed)
  local normalRoundCount = self.config.get("run.normalRoundCount") or 3
  local totalStageCount = normalRoundCount + (self.config.get("run.bossRoundCount") or 1)
  local lines = {
    string.format("Seed: %d", normalizedSeed),
    "",
    "Upcoming route:",
  }

  for roundIndex = 1, totalStageCount do
    local stageDefinition = Stages.getForRound(roundIndex, normalizedSeed)

    if stageDefinition then
      local variantLabel = stageDefinition.variantName and string.format(" (%s)", stageDefinition.variantName) or ""
      table.insert(lines, string.format("- Round %d: %s%s", roundIndex, stageDefinition.label or stageDefinition.name or stageDefinition.id, variantLabel))
    end
  end

  return lines
end

function Game:getRunSetupWarningLines()
  local lines = {
    "Use the generated seed, regenerate it, or enter a numeric seed to replay a known route.",
  }

  if self:hasActiveRunSave() then
    table.insert(lines, "Starting a fresh run will replace the current Continue Run save.")
  end

  return lines
end

function Game:startNewRun(options)
  options = options or {}
  local seed = self:normalizeRunSeed(options.seed)
  local runOptions = { seed = seed }

  if options.devBuildId then
    local resolvedOptions, resolveError = DevBuilds.resolve(options.devBuildId, seed)

    if not resolvedOptions then
      return false, resolveError
    end

    runOptions = resolvedOptions
  end

  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:setPauseFlowContext(nil)
  local cleared, clearError = self:clearActiveRunSave("start_new_run")

  if not cleared then
    return false, clearError
  end

  self.runState, self.metaProjection = RunInitializer.createNewRun(self.metaState, runOptions)
  self.runRng = RNG.new(seed)
  self.stageState = nil
  self.currentStageDefinition = nil
  self.selectedCall = nil
  self.lastBatchResult = nil
  self.lastStageResult = nil
  self.postResultNextState = nil
  self.rewardPreviewSession = nil
  self.encounterSession = nil
  self.fountainSession = nil
  self.shopOffers = {}
  self.shopSession = nil
  self.lastShopGenerationTrace = nil
  self.lastShopPurchaseTrace = nil
  self:assertRuntimeInvariants("game.startNewRun", { history = true })
  self.logger:info("Started new run", { seed = seed, devBuildId = options.devBuildId })
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
  self.postResultNextState = nil
  self.rewardPreviewSession = nil
  self.encounterSession = nil
  self.fountainSession = nil
  self.shopOffers = {}
  self.shopSession = nil
  self.lastShopGenerationTrace = nil
  self.lastShopPurchaseTrace = nil
  self.selectedCall = nil
  self.pauseFlowContext = nil
end

function Game:returnToMenu()
  self:setMetaFlowContext(self:createMenuMetaFlowContext())
  self:setPauseFlowContext(nil)
  local ok, errorMessage = self:clearActiveRunSave("return_to_menu")

  if not ok then
    return false, errorMessage
  end

  self:clearRunState()

  return true
end

function Game:getRunRecords()
  return self.metaState and self.metaState.runRecords or {}
end

function Game:getRunRecordProgressLines()
  local records = self:getRunRecords()
  local wins = 0
  local losses = 0
  local abandoned = 0

  for _, record in ipairs(records) do
    if record.resultType == "won" then
      wins = wins + 1
    elseif record.resultType == "lost" then
      losses = losses + 1
    elseif record.resultType == "abandoned" then
      abandoned = abandoned + 1
    end
  end

  return {
    string.format("Stored Runs: %d/%d", #records, SummarySystem.MAX_RUN_RECORDS or #records),
    string.format("Wins / Losses / Abandoned: %d / %d / %d", wins, losses, abandoned),
    string.format("Reputation: %d", self.metaState and (self.metaState.metaPoints or 0) or 0),
    "Browse saved runs to compare score applied to HP, stage progress, and rewards.",
  }
end

function Game:getRunRecordDetailLines(record)
  if not record then
    return { "No run record selected." }
  end

  local lines = {
    string.format("Result: %s", tostring(record.resultType or record.runStatus or "n/a")),
    string.format("Seed: %s", tostring(record.seed or "n/a")),
    string.format("Final Round: %s", tostring(record.finalRound or "n/a")),
    string.format("Final Stage: %s", tostring(record.finalStageLabel or "n/a")),
    string.format("Final Stage Status: %s", tostring(record.finalStageStatus or "n/a")),
    string.format("Total Score: %s", tostring(record.runTotalScore or 0)),
    string.format("Reputation Earned: %s", tostring(record.metaRewardEarned or 0)),
    string.format("Black Market Visits / Rerolls: %s / %s", tostring(record.shopVisitCount or 0), tostring(record.totalRerollsUsed or 0)),
    string.format("Collection Size: %s", tostring(record.collectionSize or 0)),
    string.format("Trick Count: %s", tostring(record.upgradeCount or 0)),
    "",
    "Stage History:",
  }

  if record.resultType ~= "abandoned" then
    table.insert(lines, 2, string.format("Run Status: %s", tostring(record.runStatus or "n/a")))
  end

  for _, stageRecord in ipairs(record.stageHistory or {}) do
    local line = string.format("- R%s %s => %s score to HP %s/%s", tostring(stageRecord.roundIndex or "?"), tostring(stageRecord.opponentName or stageRecord.stageLabel or "n/a"), tostring(stageRecord.status or "n/a"), tostring(stageRecord.scoreAppliedToHp or stageRecord.stageScore or 0), tostring(stageRecord.opponentHp or stageRecord.targetScore or 0))

    if stageRecord.rewardChoice then
      line = string.format("%s | Reward: %s", line, tostring(stageRecord.rewardChoice.name or stageRecord.rewardChoice.contentId or "n/a"))
    elseif (stageRecord.rewardOptionsCount or 0) > 0 then
      line = string.format("%s | Reward options: %d", line, stageRecord.rewardOptionsCount)
    end

    table.insert(lines, line)
  end

  if #(record.stageHistory or {}) == 0 then
    table.insert(lines, "- No stage history recorded.")
  end

  table.insert(lines, "")
  table.insert(lines, "Purchase History:")

  for _, purchase in ipairs(record.purchaseHistory or {}) do
    local purchaseType = (purchase.type == "trick" or purchase.type == "upgrade") and "Trick" or tostring(purchase.type or "?")
    table.insert(lines, string.format("- %s %s (%d)", purchaseType, tostring(purchase.contentId or "n/a"), tonumber(purchase.price or 0) or 0))
  end

  if #(record.purchaseHistory or {}) == 0 then
    table.insert(lines, "- No purchases recorded.")
  end

  return lines
end

function Game:appendRunRecord(resultType, stageState)
  if not self.runState or self.runState.runRecordSaved == true then
    return false
  end

  local record = SummarySystem.buildRunRecord(self.runState, resultType, stageState)
  local previousRecords = Utils.clone(self.metaState.runRecords or {})
  local nextMetaState = {
    runRecords = Utils.clone(previousRecords),
  }

  SummarySystem.appendRunRecord(nextMetaState, record)
  self.metaState.runRecords = nextMetaState.runRecords

  local ok, errorMessage = self:saveMetaState("run_record")

  if not ok then
    self.metaState.runRecords = previousRecords
    return false, errorMessage or "run_record_save_failed"
  end

  self.runState.runRecordSaved = true
  self.logger:info("Appended run record", { resultType = resultType or record.runStatus, total = #(self.metaState.runRecords or {}) })
  return true
end

function Game:onStateChanged(currentStateName, previousName, payload)
  if self.preserveActiveRunSaveOnce then
    self.preserveActiveRunSaveOnce = false
    return
  end

  local resumableStates = {
    loadout = true,
    boss_warning = true,
    stage = true,
    result = true,
    post_stage_analytics = true,
    reward_preview = true,
    boss_reward = true,
    encounter = true,
    fountain = true,
    shop = true,
  }

  if self.runState and (currentStateName == "result" or currentStateName == "post_stage_analytics") then
    if (self:shouldUseRewardPreview() or self:shouldUseBossRewardEvent()) and not self.rewardPreviewSession then
      self:ensureRewardSession()
    end
  end

  if self.runState and resumableStates[currentStateName] then
    self:saveActiveRun("state_change", currentStateName)
  elseif currentStateName == "pause" then
    return
  elseif currentStateName == "menu" or currentStateName == "help" or currentStateName == "meta" or currentStateName == "collection" or currentStateName == "records" then
    return
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
  local lines = {}

  local opponent = stageDefinition.opponent or {}

  if not options.hideStageIdentity then
    table.insert(lines, string.format("Stage: %s", stageDefinition.label or stageDefinition.name or stageDefinition.id))
    table.insert(lines, string.format("Opponent: %s", opponent.name or stageDefinition.name or stageDefinition.id))
    table.insert(lines, string.format("Type: %s", isBoss and "Boss" or "Standard"))
  end

  table.insert(lines, string.format("Opponent HP: %d", opponent.hp or stageDefinition.opponentHp or stageDefinition.targetScore or 0))
  table.insert(lines, string.format("Flips Available: %d", flipsPerStage or 0))

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
    hideStageIdentity = true,
  })
end

function Game:getUpcomingStagePreviewData()
  return self:buildStagePreviewData(self:getUpcomingStageDefinition(), {
    title = "After the Black Market",
    emptyTitle = "After the Black Market",
    emptyMessage = "No next stage is queued after this Black Market.",
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

  self.logger:info("Committed loadout", { key = Loadout.toCanonicalKey(committedSlots, self.runState.maxFlipSlots) })
  self:assertRuntimeInvariants("game.commitLoadout", { history = true })
  self:saveActiveRun("commit_loadout", "loadout")
  return committedSlots
end

function Game:recordRunStartIfNeeded()
  if self.runState and not self.runState.runStartRecorded then
    self.runState.runStartRecorded = true
    self.metaState.stats.runsStarted = (self.metaState.stats.runsStarted or 0) + 1
    self:saveMetaState("run_start")
    self.logger:info("Recorded run start", { seed = self.runState.seed, round = self.runState.roundIndex })
  end

  return true
end

function Game:syncLatestBatchTerminalState()
  local stageState = self.stageState

  if not stageState then
    return false
  end

  local batchResult = self.lastBatchResult
  local changed = false

  local function syncTrace(trace)
    if not trace then
      return
    end

    trace.stageStatusAfter = stageState.stageStatus
    trace.scoreAppliedToHpAfter = stageState.scoreAppliedToHp
    trace.stageScoreAfter = stageState.scoreAppliedToHp
    trace.runScoreAfter = self.runState and self.runState.runTotalScore or trace.runScoreAfter
    trace.influenceAfter = self.runState and self.runState.influence or trace.influenceAfter
    trace.shopPointsAfter = self.runState and self.runState.influence or trace.shopPointsAfter
    trace.flipsRemainingAfter = stageState.flipsRemaining
    changed = true
  end

  if batchResult then
    batchResult.status = stageState.stageStatus
    batchResult.scoreAppliedToHp = stageState.scoreAppliedToHp
    batchResult.opponentHp = stageState.opponentHp
    batchResult.stageScore = stageState.scoreAppliedToHp
    batchResult.targetScore = stageState.opponentHp
    batchResult.runTotalScore = self.runState and self.runState.runTotalScore or batchResult.runTotalScore
    batchResult.influence = self.runState and self.runState.influence or batchResult.influence
    batchResult.shopPoints = self.runState and self.runState.influence or batchResult.shopPoints
    batchResult.flipsRemaining = stageState.flipsRemaining
    syncTrace(batchResult.trace)

    if batchResult.batch then
      batchResult.batch.trace = batchResult.trace
      batchResult.batch.scoreBreakdown = batchResult.scoreBreakdown
    end
  end

  syncTrace(stageState.lastBatchResults)

  local flipBatches = self.runState and self.runState.history and self.runState.history.flipBatches or nil
  local lastHistoryBatch = flipBatches and flipBatches[#flipBatches] or nil

  if batchResult and lastHistoryBatch and lastHistoryBatch.batchId == batchResult.batchId then
    syncTrace(lastHistoryBatch.trace)
  end

  return changed
end

function Game:normalizeStageCompletion()
  local stageState = self.stageState

  if not stageState then
    return false, nil, false
  end

  local previousStatus = stageState.stageStatus
  local previousFlipsRemaining = stageState.flipsRemaining
  local purse = self.runState and PurseSystem.getStagePurse(self.runState, stageState) or stageState.purse
  local purseExhausted = purse ~= nil
    and #(purse.handSlots or {}) == 0
    and #(purse.selectedSlots or {}) == 0
    and #(purse.dealtHandSlots or {}) == 0
    and #(purse.availableInstanceIds or {}) == 0

  if stageState.stageStatus == "active" then
    if stageState.opponentHp ~= nil and (stageState.scoreAppliedToHp or 0) >= stageState.opponentHp then
      stageState.stageStatus = "cleared"
    elseif stageState.flipsRemaining ~= nil and stageState.flipsRemaining <= 0 then
      stageState.flipsRemaining = 0
      stageState.stageStatus = "failed"
    elseif purseExhausted then
      if stageState.opponentHp ~= nil and (stageState.scoreAppliedToHp or 0) >= stageState.opponentHp then
        stageState.stageStatus = "cleared"
      else
        stageState.flipsRemaining = 0
        stageState.stageStatus = "failed"
      end

      table.insert(purse.exhaustionEvents, {
        batchIndex = stageState.batchIndex,
        flipsRemaining = stageState.flipsRemaining,
        status = stageState.stageStatus,
      })
    end
  elseif stageState.stageStatus == "failed" and (stageState.flipsRemaining or 0) > 0 then
    stageState.flipsRemaining = 0
  end

  local changed = stageState.stageStatus ~= previousStatus or stageState.flipsRemaining ~= previousFlipsRemaining

  if changed or stageState.stageStatus ~= "active" then
    self:syncLatestBatchTerminalState()
  end

  return stageState.stageStatus ~= "active", stageState.stageStatus, changed
end

function Game:requestStageCompletion()
  local isComplete = self:normalizeStageCompletion()

  if not isComplete then
    return false, "stage_active"
  end

  if not self.stateGraph then
    return false, "state_graph_unavailable"
  end

  return self.stateGraph:request("stage_complete")
end

function Game:ensureHandDrawn()
  if not self.runState or not self.stageState or self.stageState.stageStatus ~= "active" then
    return nil, "stage_not_active"
  end

  local dealtSlots, dealWarning = PurseSystem.dealHand(self.runState, self.stageState, self.runRng)

  PurseHookSystem.runAfterDealBeforeSelection(self.runState, self.stageState, self.metaProjection, { call = self.selectedCall, rng = self.runRng })

  if dealWarning == "purse_empty" then
    self:normalizeStageCompletion()
    return nil, dealWarning
  end

  self:assertRuntimeInvariants("game.ensureHandDrawn", { history = true })
  return dealtSlots, dealWarning
end

function Game:selectDealtCoin(selector)
  if not self.runState or not self.stageState then
    return false, "run or stage has not been initialized"
  end

  local ok, result = PurseSystem.selectDealtSlot(self.runState, self.stageState, selector)

  if not ok then
    return false, result
  end

  self:assertRuntimeInvariants("game.selectDealtCoin", { history = true })
  self:saveActiveRun("select_dealt_coin", "stage")
  return true, result
end

function Game:deselectFlipSlot(selector)
  if not self.runState or not self.stageState then
    return false, "run or stage has not been initialized"
  end

  local ok, result = PurseSystem.deselectSelectedSlot(self.runState, self.stageState, selector)

  if not ok then
    return false, result
  end

  self:assertRuntimeInvariants("game.deselectFlipSlot", { history = true })
  self:saveActiveRun("deselect_flip_slot", "stage")
  return true, result
end

function Game:toggleDealtCoinSelection(selector)
  if not self.runState or not self.stageState then
    return false, "run or stage has not been initialized"
  end

  local ok, result, action = PurseSystem.toggleDealtSelection(self.runState, self.stageState, selector)

  if not ok then
    return false, result
  end

  self:assertRuntimeInvariants("game.toggleDealtCoinSelection", { history = true })
  self:saveActiveRun("toggle_dealt_coin_selection", "stage")
  return true, result, action
end

function Game:applyHandReorderHook(reorderResult)
  if not reorderResult then
    return nil
  end

  local movedCoin = PurseHookSystem.buildCoinState(self.runState, nil, reorderResult.toIndex, {
    instanceId = reorderResult.movedInstanceId,
    definitionId = reorderResult.movedDefinitionId,
    slotIndex = reorderResult.toIndex,
  })

  if movedCoin then
    return PurseHookSystem.runImmediatePhase(self.runState, self.stageState, self.metaProjection, "after_hand_reorder", { movedCoin }, { call = self.selectedCall })
  end

  return nil
end

function Game:moveHandSlot(slotIndex, direction, options)
  options = options or {}

  if not self.stageState then
    return false, "stage_not_initialized"
  end

  local ok, result = PurseSystem.moveHandSlot(self.stageState, slotIndex, direction)

  if not ok then
    return false, result
  end

  if not options.suppressReorderHook then
    self:applyHandReorderHook(result)
  end

  self:assertRuntimeInvariants("game.moveHandSlot", { history = true })
  self:saveActiveRun("move_hand_slot", "stage")
  return true, result
end

function Game:getPurseInspectionLines(stageState)
  if not self.runState then
    return { "No active run." }
  end

  local counts = PurseSystem.countZonesByDefinition(self.runState, stageState)
  local lines = {
    string.format("Pouch size: %d coin(s)", #(self.runState.coinInstances or {})),
    string.format("Deal: %d coin(s)", PurseSystem.getHandSize(self.runState)),
  }

  local ids = {}
  for definitionId in pairs(counts) do
    table.insert(ids, definitionId)
  end
  table.sort(ids)

  for _, definitionId in ipairs(ids) do
    local count = counts[definitionId]
    local name = self:getCoinName(definitionId)

    if stageState and stageState.purse then
      table.insert(lines, string.format(
        "- %s x%d (available %d, dealt %d, Flip Slots %d, used %d)",
        name,
        count.total,
        count.available,
        count.dealt or 0,
        count.selected or count.hand or 0,
        count.exhausted
      ))
    else
      table.insert(lines, string.format("- %s x%d", name, count.total))
    end
  end

  return lines
end

function Game:getPurseCardData(stageState)
  if not self.runState then
    return {}, { purseSize = 0, handSize = 0, dealSize = 0 }
  end

  local counts = PurseSystem.countZonesByDefinition(self.runState, stageState)
  local cards = {}
  local ids = {}

  for definitionId in pairs(counts) do
    table.insert(ids, definitionId)
  end

  table.sort(ids, function(left, right)
    return self:getCoinName(left) < self:getCoinName(right)
  end)

  for _, definitionId in ipairs(ids) do
    local count = counts[definitionId]
    local definition = Coins.getById(definitionId)
    local detail = CoinDetailContent.build(definition)

    table.insert(cards, {
      coinId = definitionId,
      name = detail and detail.title or definitionId,
      chanceText = detail and detail.chanceText or "50/50 Heads/Tails",
      effectDescription = detail and detail.effectText or "",
      description = detail and detail.description or "",
      rarity = definition and definition.rarity or "common",
      count = count.total,
      available = count.available,
      dealt = count.dealt or 0,
      selected = count.selected or count.hand or 0,
      hand = count.hand,
      exhausted = count.exhausted,
    })
  end

  return cards, {
    purseSize = #(self.runState.coinInstances or {}),
    handSize = PurseSystem.getHandSize(self.runState),
    dealSize = PurseSystem.getHandSize(self.runState),
  }
end

function Game:getTrickCharmData()
  return TrickCharm.buildData(self.runState)
end

function Game:resolveCurrentBatch(call, options)
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
  self:normalizeStageCompletion()
  batchResult = self.lastBatchResult
  self:assertRuntimeInvariants("game.resolveCurrentBatch", { batchResult = batchResult, history = true })
  self.logger:info("Resolved batch", { batch = batchResult.batchId, status = batchResult.status, call = call })
  self.logger:debug(self:formatBatchLogLine(batchResult))
  if not (options and options.deferFeedback) then
    self:triggerBatchFeedback(batchResult)
  end

  if self.stageState.stageStatus == "active" then
    self:saveActiveRun("resolve_batch", "stage")
  end

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
    "- F4: cycle Trick callouts",
    string.format("- F5: +%d %s", self.config.get("debug.grantShopPointsAmount", 5), Terminology.getTermPlural("chip")),
    "- F6: grant next Trick",
    "- F7: jump to boss round",
    string.format("- F8: simulate %d %s", self.config.get("debug.fastSimBatchCount", 3), Terminology.getTermPlural("flip")),
    "- F9: print full flip trace",
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
  self.runState.influence = self.runState.influence + amount
  self:assertRuntimeInvariants("game.debugGrantShopPoints", { history = true })
    self.logger:info("Dev control granted Influence", { amount = amount, total = self.runState.influence })
  return true, amount
end

function Game:debugGrantNextUpgrade()
  if not self.runState then
    return false, "run_not_initialized"
  end

  local nextUpgradeId = nil

  for _, definition in ipairs(Upgrades.getAll()) do
    if not Utils.contains(self.runState.ownedTrickIds or self.runState.ownedUpgradeIds, definition.id) then
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

  self.logger:debug("=== Full Flip Trace ===", { batch = self.lastBatchResult.batchId })

  for _, line in ipairs(self:getLastBatchSummaryLines()) do
    self.logger:debug(line)
  end

  for _, line in ipairs(self:getScoreBreakdownLines()) do
    self.logger:debug(line)
  end

  if self.lastBatchResult.trace then
    self.logger:debug("Trace terminal state", {
      stageStatus = self.lastBatchResult.trace.stageStatusAfter or "n/a",
      scoreAppliedToHp = self.lastBatchResult.trace.scoreAppliedToHpAfter or self.lastBatchResult.trace.stageScoreAfter or "n/a",
      runScore = self.lastBatchResult.trace.runScoreAfter or "n/a",
      influence = self.lastBatchResult.trace.influenceAfter or self.lastBatchResult.trace.shopPointsAfter or "n/a",
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
    self.stageState.scoreAppliedToHp = math.max(self.stageState.scoreAppliedToHp, self.stageState.opponentHp)
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
    local scoreAppliedToHpAfter = batchResult.trace.scoreAppliedToHpAfter or batchResult.trace.stageScoreAfter
    local opponentHp = batchResult.opponentHp or batchResult.targetScore or batchResult.scoreAppliedToHp or batchResult.stageScore or 0
    local flipsRemainingAfter = batchResult.trace.flipsRemainingAfter
    local statusAfter = batchResult.trace.stageStatusAfter or batchResult.status or "n/a"
    local lines = {
      string.format("Opponent evaluation: %s", tostring(statusAfter == "cleared" and "defeated" or statusAfter)),
      string.format("Score applied to HP: %s/%s", tostring(scoreAppliedToHpAfter or "n/a"), tostring(opponentHp or "n/a")),
      string.format("Flips after %s: %s", Terminology.getTermLower("flip"), tostring(flipsRemainingAfter or "n/a")),
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
      string.format("Opponent evaluation: %s", tostring(self.stageState.stageStatus == "cleared" and "defeated" or self.stageState.stageStatus)),
      string.format("Score applied to HP: %s/%s", tostring(self.stageState.scoreAppliedToHp or "n/a"), tostring(self.stageState.opponentHp or "n/a")),
      string.format("Flips after %s: %s", Terminology.getTermLower("flip"), tostring(self.stageState.flipsRemaining or "n/a")),
      "Source: dev-forced or no flip trace",
    }
  end

  return { "Opponent evaluation: n/a" }
end

function Game:finalizeCurrentStage()
  if not self.runState or not self.stageState then
    return nil, "stage_not_initialized"
  end

  self:normalizeStageCompletion()

  if self.stageState.stageStatus == "active" then
    return nil, "stage_still_active"
  end

  if self.lastStageResult
    and self.lastStageResult.roundIndex == self.runState.roundIndex
    and self.lastStageResult.stageId == self.stageState.stageId
    and self.lastStageResult.status == self.stageState.stageStatus then
    self.postResultNextState = self.postResultNextState or self:computePostResultNextState()

    if self:shouldUseRewardPreview() or self:shouldUseBossRewardEvent() then
      self:ensureRewardSession()
    end

    return self.lastStageResult, {
      alreadyFinalized = true,
      shouldPersistMeta = false,
      metaReward = 0,
    }
  end

  local stageRecord, finalizeMeta = RunHistorySystem.finalizeStage(self.runState, self.stageState, self.metaState)

  if finalizeMeta.metaReward > 0 then
    self.logger:info("Granted meta reward", { amount = finalizeMeta.metaReward, runStatus = self.runState.runStatus })
  end

  if finalizeMeta.shouldPersistMeta then
    self:saveMetaState("run_complete")
  end

  self.lastStageResult = stageRecord
  self.postResultNextState = self:computePostResultNextState()

  if self:shouldUseRewardPreview() or self:shouldUseBossRewardEvent() then
    self:ensureRewardSession()
  end

  if self.runState.runStatus ~= "active" and not self:shouldUseBossRewardEvent() then
    local appended, appendError = self:appendRunRecord(self.runState.runStatus, self.stageState)

    if appended == false and self.runState.runRecordSaved ~= true then
      return nil, appendError or "run_record_save_failed"
    end
  end

  self:assertRuntimeInvariants("game.finalizeCurrentStage", { history = true })
  self.logger:info("Finalized stage", { stage = stageRecord.stageId, status = stageRecord.status, runStatus = stageRecord.runStatus })
  return stageRecord, finalizeMeta
end

function Game:ensureDirectShopHistoryData()
  if not self.lastStageResult then
    return
  end

  if self.lastStageResult.rewardOptions == nil then
    RunHistorySystem.recordStageRewardPreview(self.lastStageResult, { options = {} })
  end

  if self.lastStageResult.encounter == nil then
    RunHistorySystem.recordStageEncounterPreview(self.lastStageResult, {
      encounterId = "direct_shop",
      name = "Direct Black Market",
      description = "No encounter is active for this stop.",
      choices = {},
    })
  end
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

  self:ensureDirectShopHistoryData()

  local shopFlow = self:createShopFlow()
  self:applyShopFlow(shopFlow)

  if self.shopOffers and #self.shopOffers > 0 then
    return true
  end

  ShopFlowSystem.ensureOffers(shopFlow)
  self:applyShopFlow(shopFlow)
  self:assertRuntimeInvariants("game.prepareShopOffers", { shopOffers = self.shopOffers, history = true })
  self.logger:info("Generated Black Market offers", { count = #self.shopOffers, triggers = #(self.lastShopGenerationTrace and self.lastShopGenerationTrace.triggeredSources or {}) })
  self:saveActiveRun("prepare_shop", "shop")
  return true
end

function Game:getLuckMeter()
  return LuckSystem.getMeter(self.runState)
end

function Game:isFatedFlipActive()
  return self.runState ~= nil and LuckSystem.isFatedFlipActive(self.runState)
end

function Game:prepareFountain(currentStateName)
  if not self.runState then
    return false, "run_not_initialized"
  end

  if not self.lastStageResult or self.lastStageResult.status ~= "cleared" then
    return false, "cleared_stage_required"
  end

  if self.lastStageResult.stageType == "boss" then
    return false, "boss_stage_has_no_fountain"
  end

  if not self.fountainSession
    or self.fountainSession.sourceStageId ~= self.lastStageResult.stageId
    or self.fountainSession.roundIndex ~= self.lastStageResult.roundIndex then
    self.fountainSession = FountainSystem.buildSession(self.runState, self.lastStageResult)
  end

  self:assertRuntimeInvariants("game.prepareFountain", { history = true })
  self:saveActiveRun("prepare_fountain", currentStateName or "fountain")
  return true
end

function Game:getFountainSession()
  return self.fountainSession
end

function Game:getFountainOptions()
  return FountainSystem.getOptions(self.runState)
end

function Game:selectFountainCoin(instanceId, currentStateName)
  if not self.fountainSession then
    return false, "fountain_not_prepared"
  end

  self.fountainSession.selectedInstanceId = instanceId
  self:saveActiveRun("select_fountain_coin", currentStateName or "fountain")
  return true
end

function Game:sacrificeFountainCoin(instanceId, currentStateName)
  local selectedInstanceId = instanceId or (self.fountainSession and self.fountainSession.selectedInstanceId) or nil
  local ok, result = FountainSystem.sacrifice(self.runState, self.stageState, self.fountainSession, selectedInstanceId)

  if not ok then
    return false, result
  end

  self:assertRuntimeInvariants("game.sacrificeFountainCoin", { history = true })
  self:showFeedback("warning", "Fountain Favor", string.format("%s became +%s Luck generation.", result.name, LuckSystem.formatAmount(result.favorGained)), {
    duration = 1.2,
    flashAlpha = 0.05,
  })
  self:saveActiveRun("sacrifice_fountain_coin", currentStateName or "fountain")
  return true, result
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
    self.logger:warn("Black Market reroll rejected", { error = errorMessage })
    self:assertRuntimeInvariants("game.rerollShopOffers.rejected", { shopOffers = self.shopOffers, history = true })
    return false, errorMessage
  end

  self:applyShopFlow(shopFlow)
  self:assertRuntimeInvariants("game.rerollShopOffers", { shopOffers = self.shopOffers, history = true })
  self.logger:info("Rerolled Black Market offers", { mode = rerollMode, rerollsUsed = self.shopSession and self.shopSession.rerollsUsed or 0 })
  self:showFeedback("warning", "Black Market Rerolled", string.format("A %s reroll refreshed the offers.", rerollMode), {
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
  self.logger:info("Purchased Black Market offer", { contentId = offer.contentId, type = offer.type, price = result.finalPrice, triggers = #(result.trace and result.trace.triggeredSources or {}) })
  self:showFeedback("accent", "Purchase Complete", string.format("%s joined the run for %d Influence.", offer.name, result.finalPrice or offer.price or 0), {
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
  self.postResultNextState = nil
  self.rewardPreviewSession = nil
  self.encounterSession = nil
  self.fountainSession = nil
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
  return AnalyticsSystem.buildPostStageReport(self.runState, self.lastStageResult, self.lastBatchResult, self:getPostStageReviewFollowupLine())
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
  if key == "influenceMultiplier" or key == "shopPointMultiplier" then
    return string.format("%s gain x%.2f", Terminology.getTermLabel("chip"), value)
  end

  if key == "bonusCoinSlots" then
    return string.format("+%d %s", value, value == 1 and Terminology.getTermLabel("active_coin_slot") or Terminology.getTermPlural("active_coin_slot"))
  end

  if key == "bonusRerolls" then
    return string.format("+%d %s(s)", value, Terminology.getTermLabel("free_reroll"))
  end

  if key == "startingInfluence" or key == "startingShopPoints" then
    return string.format("+%d starting %s", value, Terminology.getTermLabel("chip"))
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

    if path == "economy.influenceMultiplier" or path == "economy.shopPointMultiplier" then
      if mode == "add" then
        return string.format("%s gain %s", Terminology.getTermLabel("chip"), formatSignedNumber(value))
      end

      return string.format("%s gain x%.2f", Terminology.getTermLabel("chip"), value)
    end

    if path == "run.maxFlipSlots" or path == "run.maxActiveCoinSlots" then
      if mode == "override" then
        return string.format("%s = %d", Terminology.getTermLabel("active_coin_slot"), value)
      end

      return string.format("%s %s", formatSignedNumber(value), math.abs(value) == 1 and Terminology.getTermLabel("active_coin_slot") or Terminology.getTermPlural("active_coin_slot"))
    end

    if path == "run.startingShopRerolls" then
      if mode == "override" then
        return string.format("%s = %d", Terminology.getTermLabel("free_reroll"), value)
      end

      return string.format("%s %s(s)", formatSignedNumber(value), Terminology.getTermLabel("free_reroll"))
    end

    if path == "run.startingInfluence" or path == "run.startingShopPoints" then
      if mode == "override" then
        return string.format("Starting %s = %d", Terminology.getTermLabel("chip"), value)
      end

      return string.format("%s starting %s", formatSignedNumber(value), Terminology.getTermLabel("chip"))
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
        and string.format("Black Market offer count = %d", value)
        or string.format("Black Market offer count %s", formatSignedNumber(value))
    end

    if path == "shop.guaranteedCoinOffers" then
      return mode == "override"
        and string.format("Guaranteed coin offers = %d", value)
        or string.format("Guaranteed coin offers %s", formatSignedNumber(value))
    end

    if path == "shop.guaranteedUpgradeOffers" then
      return mode == "override"
        and string.format("Guaranteed Trick offers = %d", value)
        or string.format("Guaranteed Trick offers %s", formatSignedNumber(value))
    end

    if path == "shop.rerollCost" then
      return mode == "override"
        and string.format("Black Market reroll cost = %d", value)
        or string.format("Black Market reroll cost %s", formatSignedNumber(value))
    end

    if path == "shop.rarityWeight.common" or path == "shop.rarityWeight.uncommon" or path == "shop.rarityWeight.rare" then
      local rarity = string.match(path, "shop%.rarityWeight%.(.+)") or "unknown"
      return string.format("%s offer weight x%.2f", rarity:gsub("^%l", string.upper), value)
    end

    if path == "flip.baseHeadsWeight" or path == "flip.baseTailsWeight" then
      local label = path == "flip.baseHeadsWeight" and "Base Heads chance" or "Base Tails chance"

      if mode == "override" then
        return string.format("%s = %.0f%%", label, value * 100)
      end

      return string.format("%s %+0.0f%%", label, value * 100)
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
  local unlockedUpgradeCount = #(Upgrades.getUnlockedIds(self.metaState.unlockedTrickIds or self.metaState.unlockedUpgradeIds or {}) or {})
  local equippedTattooCount = #(self.metaState.equippedTattooIds or {})
  local tattooLoadoutLimit = self.metaState.tattooLoadoutLimit or MetaUpgrades.getEquipLimit()

  return {
    string.format("Reputation: %d", self.metaState.metaPoints or 0),
    string.format("Lifetime Reputation: %d", self.metaState.lifetimeMetaPointsEarned or 0),
    string.format("Purchased Tattoos: %d", #(self.metaState.purchasedTattooIds or self.metaState.purchasedMetaUpgradeIds or {})),
    string.format("Equipped Tattoos: %d/%d", equippedTattooCount, tattooLoadoutLimit),
    string.format("Unlocked Coins: %d/%d", unlockedCoinCount, #(Coins.getAll() or {})),
    string.format("Unlocked Tricks: %d/%d", unlockedUpgradeCount, #(Upgrades.getAll() or {})),
    string.format("Runs Started: %d", self.metaState.stats.runsStarted or 0),
    string.format("Runs Won: %d", self.metaState.stats.runsWon or 0),
    string.format("Best Total Score: %d", self.metaState.stats.bestRunScore or 0),
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
    return { "Unknown Tattoo." }
  end

  local lines = {
    Terminology.getMechanicRichText(definition.description),
    "",
    string.format("Cost: %d Reputation", definition.cost or 0),
    Utils.contains(self.metaState.purchasedTattooIds or self.metaState.purchasedMetaUpgradeIds, metaUpgradeId) and "Status: purchased" or "Status: available",
  }

  if MetaUpgrades.isEquipEligible(definition) then
    table.insert(lines, Utils.contains(self.metaState.equippedTattooIds, metaUpgradeId) and "Tattoo Slot: equipped" or "Tattoo Slot: unequipped")
    table.insert(lines, string.format("Tattoo Slots: %d/%d", #(self.metaState.equippedTattooIds or {}), self.metaState.tattooLoadoutLimit or MetaUpgrades.getEquipLimit()))
  else
    table.insert(lines, "Tattoo Slot: not used")
  end

  if #(definition.tags or {}) > 0 then
    table.insert(lines, string.format("Tags: %s", Terminology.formatTagList(definition.tags)))
  end

  if #(definition.unlockCoinIds or {}) > 0 or #(definition.unlockUpgradeIds or {}) > 0 then
    table.insert(lines, "")
    table.insert(lines, "Unlocks:")

    for _, coinId in ipairs(definition.unlockCoinIds or {}) do
      table.insert(lines, "- Coin: " .. self:getCoinName(coinId))
    end

    for _, upgradeId in ipairs(definition.unlockUpgradeIds or {}) do
      table.insert(lines, "- Trick: " .. self:getUpgradeName(upgradeId))
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

function Game:equipMetaTattoo(metaUpgradeId)
  local ok, result = MetaProgressionSystem.equipTattoo(self.metaState, metaUpgradeId)

  if not ok then
    return false, result
  end

  self:saveMetaState("tattoo_equip")
  self:showFeedback("accent", "Tattoo Equipped", string.format("%s is equipped for future runs.", self:getMetaUpgradeName(metaUpgradeId)), {
    duration = 1.1,
    flashAlpha = 0.04,
    soundCue = "meta_purchase",
  })
  return true, result
end

function Game:unequipMetaTattoo(metaUpgradeId)
  local ok, result = MetaProgressionSystem.unequipTattoo(self.metaState, metaUpgradeId)

  if not ok then
    return false, result
  end

  self:saveMetaState("tattoo_unequip")
  self:showFeedback("accent", "Tattoo Unequipped", string.format("%s is no longer equipped.", self:getMetaUpgradeName(metaUpgradeId)), {
    duration = 1.1,
    flashAlpha = 0.04,
    soundCue = "meta_purchase",
  })
  return true, result
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
  local autoEquipped = Utils.contains(self.metaState.equippedTattooIds, metaUpgradeId)
  local message = unlockedCount > 0
    and string.format("%s unlocked %s.", self:getMetaUpgradeName(metaUpgradeId), table.concat(unlockedNames, ", "))
    or (autoEquipped
      and string.format("%s is purchased and equipped for future runs.", self:getMetaUpgradeName(metaUpgradeId))
      or string.format("%s is purchased. Equip it to affect future runs.", self:getMetaUpgradeName(metaUpgradeId)))
  self:showFeedback("accent", "Tattoo Purchased", message, {
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

  return Loadout.toCanonicalKey(self.runState.persistedFlipSlots, self.runState.maxFlipSlots)
end

function Game:getCurrentLoadoutKey()
  if not self.runState then
    return "n/a"
  end

  return Loadout.toCanonicalKey(self.runState.flipSlots, self.runState.maxFlipSlots)
end

function Game:getEquippedCoinNames()
  local names = {}

  if not self.runState or not self.runState.maxFlipSlots then
    return names
  end

  for slotIndex = 1, self.runState.maxFlipSlots do
    local coinId = self.runState.flipSlots[slotIndex]

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
  return definition and Terminology.formatText(definition.description) or tostring(upgradeId)
end

function Game:getStageModifierName(modifierId)
  local definition = StageModifiers.getById(modifierId)
  return definition and definition.name or tostring(modifierId)
end

function Game:getStageModifierDescription(modifierId)
  local definition = StageModifiers.getById(modifierId)
  return definition and Terminology.formatText(definition.description) or tostring(modifierId)
end

function Game:getBossModifierName(modifierId)
  local definition = Bosses.getById(modifierId)
  return definition and definition.name or tostring(modifierId)
end

function Game:getBossModifierDescription(modifierId)
  local definition = Bosses.getById(modifierId)
  return definition and Terminology.formatText(definition.description) or tostring(modifierId)
end

function Game:getActiveUpgradeNames()
  local names = {}

  for _, upgradeId in ipairs(self.runState and (self.runState.ownedTrickIds or self.runState.ownedUpgradeIds) or {}) do
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
    local description = Terminology.formatText(effect.description or "")

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

  return definition and Terminology.formatText(definition.description) or ""
end

function Game:getShopStatusLines()
  local shopRules = EffectiveValueSystem.getShopRules(self.runState, self.stageState, {
    metaProjection = self.runState and self.runState.metaProjection or nil,
  })
  local lines = {
    string.format("Free rerolls remaining: %d", self.runState and self.runState.shopRerollsRemaining or 0),
    string.format("Paid reroll cost: %d Influence", shopRules.rerollCost),
    string.format("Unlocked coin pool: %d/%d", #(Coins.getUnlockedIds(self.runState and self.runState.unlockedCoinIds or {}) or {}), #(Coins.getAll() or {})),
    string.format("Unlocked Trick pool: %d/%d", #(Upgrades.getUnlockedIds(self.runState and (self.runState.unlockedTrickIds or self.runState.unlockedUpgradeIds) or {}) or {}), #(Upgrades.getAll() or {})),
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
    local purchaseType = (record.type == "trick" or record.type == "upgrade") and "Trick" or tostring(record.type or "?")
    table.insert(lines, string.format("- %s (%s) for %d", self:getPurchaseName(record), purchaseType, record.price or 0))
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

  if self.lastStageResult.stageType ~= "boss"
    and self.lastStageResult.status == "cleared"
    and self.runState ~= nil
    and self.runState.runStatus == "active" then
    if self:shouldUseRewardPreview() then
      return "reward_preview"
    end

    return "shop"
  end

  return "summary"
end

function Game:computePostResultNextState()
  return self:getPostResultDestinationState()
end

function Game:shouldShowPostStageAnalytics()
  return self.lastStageResult ~= nil and self:getPostResultNextState() == "post_stage_analytics"
end

function Game:getPostResultNextState()
  if self.postResultNextState ~= nil then
    return self.postResultNextState
  end

  return self:computePostResultNextState()
end

function Game:getPostResultDestinationLabel()
  local destination = self:getPostResultNextState()

  if destination == "reward_preview" then
    return "reward preview"
  end

  if destination == "post_stage_analytics" then
    return "stage review"
  end

  if destination == "boss_reward" then
    return "victory reward"
  end

  if destination == "fountain" then
    return "fountain"
  end

  return destination
end

function Game:getPostStageReviewFollowupLine()
  local destination = self:getPostResultNextState()

  if destination == "boss_reward" then
    return "Victory reward follows."
  end

  if destination == "shop" then
    return "Black Market follows."
  end

  if destination == "fountain" then
    return "Fountain follows."
  end

  return "Run summary follows."
end

function Game:shouldShowBossWarning()
  local stageDefinition = self:getPlannedStageDefinition()
  return stageDefinition ~= nil and stageDefinition.stageType == "boss"
end

function Game:getBossWarningLines()
  local opponent = self.stageState and self.stageState.opponent or {}
  local lines = {
    "You are about to enter a boss encounter.",
    "",
    string.format("Opponent: %s", opponent.name or "Boss"),
    string.format("Opponent HP: %d", self.stageState and self.stageState.opponentHp or 0),
    string.format("Flips Available: %d", self.stageState and self.stageState.flipsRemaining or 0),
    string.format("Current Build: %s", self:getCurrentLoadoutKey()),
  }

  local equippedNames = self:getEquippedCoinNames()
  if #equippedNames > 0 then
    table.insert(lines, "")
    table.insert(lines, "Coins in Flip Slots:")

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
  local rewardSession = self.rewardPreviewSession
  local lines = {
    string.format("Defeated: %s", result.opponentName or result.stageLabel or "n/a"),
  }

  local victoryChipLine = self:formatVictoryChipRewardLine(result)
  if victoryChipLine then
    table.insert(lines, victoryChipLine)
  end

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Reputation +%d", result.metaRewardEarned))
  end

  table.insert(lines, "")

  if rewardSession and rewardSession.claimed and rewardSession.choice then
    table.insert(lines, string.format("Chosen: %s", rewardSession.choice.name or rewardSession.choice.contentId or "n/a"))
  elseif rewardSession and #(rewardSession.options or {}) == 0 then
    table.insert(lines, "No rewards remain.")
  else
    table.insert(lines, "Choose one reward.")
  end

  return lines
end

function Game:formatVictoryChipRewardLine(stageRecord)
  local reward = stageRecord and stageRecord.victoryShopPointReward or nil
  local total = reward and reward.total or 0

  if total <= 0 then
    return nil
  end

  return string.format("Influence +%d", total)
end

function Game:shouldUseEncounterEvent()
  return false
end

function Game:prepareEncounterEvent()
  if not self:shouldUseEncounterEvent() then
    return false, "encounter_unavailable"
  end

  local session = self:ensureEncounterSession()

  if not session then
    return false, "encounter_unavailable"
  end

  return true, session
end

function Game:getEncounterSession()
  return self.encounterSession
end

function Game:ensureEncounterSession()
  if not self:shouldUseEncounterEvent() then
    return nil
  end

  if not self.encounterSession then
    self.encounterSession = EncounterSystem.buildSession(self.runState)

    if self.lastStageResult then
      RunHistorySystem.recordStageEncounterPreview(self.lastStageResult, self.encounterSession)
    end

    self:assertRuntimeInvariants("game.ensureEncounterSession", { history = true })
  end

  return self.encounterSession
end

function Game:selectEncounterChoice(index)
  local session = self:getEncounterSession()

  if not session then
    return false, "encounter_unavailable"
  end

  local ok, result = EncounterSystem.selectChoice(session, index)

  if ok then
    local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
    if currentStateName == "encounter" then
      self:saveActiveRun("encounter_selection", currentStateName)
    end
  end

  return ok, result
end

function Game:canContinueEncounter()
  local session = self:getEncounterSession()
  return EncounterSystem.canContinue(session)
end

function Game:getEncounterOptionCards()
  local cards = {}
  local session = self:getEncounterSession()

  for index, option in ipairs(session and session.choices or {}) do
    table.insert(cards, {
      index = index,
      id = option.id,
      type = option.type,
      contentId = option.contentId,
      amount = option.amount,
      name = option.label,
      description = Terminology.formatText(option.description),
      selected = session.selectedIndex == index,
      claimed = session.claimed == true,
    })
  end

  return cards
end

function Game:getEncounterContinueLabel()
  local session = self:getEncounterSession()

  if session and (#(session.choices or {}) == 0 or session.claimed == true) then
    return "Continue to Black Market"
  end

  return "Claim Choice & Continue"
end

function Game:getEncounterLines()
  local session = self:getEncounterSession()

  if not session then
    return { "No encounter is active for this stop." }
  end

  local lines = {
    session.name or "Encounter",
    Terminology.formatText(session.description or ""),
    "",
  }

  if session.claimed and session.choice then
    table.insert(lines, string.format("Chosen Option: %s", session.choice.label or session.choice.id or "n/a"))
  elseif #(session.choices or {}) == 0 then
    table.insert(lines, "No valid encounter choices remain; continue directly to the Black Market.")
  else
    table.insert(lines, "Choose one encounter option before continuing.")
  end

  return lines
end

function Game:getProjectedEncounterOutcome(projected)
  if projected ~= nil then
    return projected
  end

  if not self.runState then
    return nil
  end

  local session = self:getEncounterSession()

  if not session then
    return nil
  end

  local projectedOutcome, errorMessage = EncounterSystem.buildProjectedOutcome(self.runState, session)

  if not projectedOutcome then
    self.logger:warn("Projected encounter outcome unavailable", { error = errorMessage or "unknown" })
    return nil, errorMessage
  end

  return projectedOutcome
end

function Game:getProjectedEncounterImpactLines(projected)
  local projectedOutcome = projected
  local errorMessage = nil
  local session = self:getEncounterSession()

  if projectedOutcome == nil then
    projectedOutcome, errorMessage = self:getProjectedEncounterOutcome()
  end

  if not projectedOutcome then
    return { string.format("Projected encounter impact unavailable: %s", tostring(errorMessage or "n/a")) }
  end

  local lines = {}
  local choice = projectedOutcome.choice

  if choice then
    table.insert(lines, string.format("Selected Option: %s", choice.label or choice.id or "Unknown"))
  elseif session and #(session.choices or {}) > 0 and session.claimed ~= true then
    table.insert(lines, "Selected Option: pending choice")
  else
    table.insert(lines, "Selected Option: none")
  end

  if projectedOutcome.influenceAfter ~= projectedOutcome.influenceBefore then
    table.insert(lines, string.format(
      "Influence: %d → %d (%+d)",
      projectedOutcome.influenceBefore,
      projectedOutcome.influenceAfter,
      projectedOutcome.influenceAfter - projectedOutcome.influenceBefore
    ))
  end

  if projectedOutcome.shopRerollsAfter ~= projectedOutcome.shopRerollsBefore then
    table.insert(lines, string.format(
      "Black Market Rerolls: %d → %d (%+d)",
      projectedOutcome.shopRerollsBefore,
      projectedOutcome.shopRerollsAfter,
      projectedOutcome.shopRerollsAfter - projectedOutcome.shopRerollsBefore
    ))
  end

  if projectedOutcome.collectionSizeAfter ~= projectedOutcome.collectionSizeBefore then
    table.insert(lines, string.format(
      "Collection Size: %d → %d (%+d)",
      projectedOutcome.collectionSizeBefore,
      projectedOutcome.collectionSizeAfter,
      projectedOutcome.collectionSizeAfter - projectedOutcome.collectionSizeBefore
    ))
  end

  if projectedOutcome.upgradeCountAfter ~= projectedOutcome.upgradeCountBefore then
    table.insert(lines, string.format(
      "Owned Tricks: %d → %d (%+d)",
      projectedOutcome.upgradeCountBefore,
      projectedOutcome.upgradeCountAfter,
      projectedOutcome.upgradeCountAfter - projectedOutcome.upgradeCountBefore
    ))
  end

  if choice and choice.type == "coin" then
    table.insert(lines, "On continue, the coin is added to your collection before the Black Market opens.")
  elseif choice and (choice.type == "trick" or choice.type == "upgrade") then
    table.insert(lines, "On continue, the Trick becomes active immediately before the Black Market opens.")
  elseif #(session and session.choices or {}) == 0 then
    table.insert(lines, "No encounter reward will be added; the Black Market continues unchanged.")
  end

  return lines
end

function Game:getProjectedEncounterShopPreviewLines(projected)
  local projectedOutcome = projected
  local errorMessage = nil

  if projectedOutcome == nil then
    projectedOutcome, errorMessage = self:getProjectedEncounterOutcome()
  end

  if not projectedOutcome then
    return {
      "Next stop: Black Market",
      string.format("Projected Black Market outlook unavailable: %s", tostring(errorMessage or "n/a")),
    }
  end

  return self:getShopPreviewLinesForRun(projectedOutcome.projectedRunState or self.runState)
end

function Game:claimSelectedEncounterChoice()
  local session = self:getEncounterSession()

  if not session then
    return false, "encounter_unavailable"
  end

  local ok, choiceOrError = EncounterSystem.claimChoice(self.runState, session)

  if not ok then
    return false, choiceOrError
  end

  if self.lastStageResult then
    RunHistorySystem.recordStageEncounterChoice(self.lastStageResult, choiceOrError)
  end

  self:assertRuntimeInvariants("game.claimSelectedEncounterChoice", { history = true })
  self.logger:info("Claimed encounter choice", {
    id = choiceOrError and choiceOrError.id or "none",
    type = choiceOrError and choiceOrError.type or "none",
  })

  if choiceOrError then
    self:showFeedback(
      "accent",
      "Encounter Choice Taken",
      string.format("%s is now active for the upcoming Black Market.", choiceOrError.label or choiceOrError.id or "Choice"),
      { soundCue = "shop_purchase" }
    )
  end

  local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
  if currentStateName == "encounter" then
    self:saveActiveRun("claim_encounter_choice", currentStateName)
  end

  return true, choiceOrError
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
  local opponent = stageDefinition.opponent or {}
  local cards = isBoss
    and self:getBossModifierCards(stageDefinition.bossModifierIds or {})
    or self:getStageModifierCards(stageDefinition.activeStageModifierIds or {})
  local lines = {
    string.format("Stage: %s", stageDefinition.label or stageDefinition.name or stageDefinition.id),
    string.format("Opponent: %s", opponent.name or stageDefinition.name or stageDefinition.id),
    string.format("Opponent HP: %d", opponent.hp or stageDefinition.opponentHp or stageDefinition.targetScore or 0),
    string.format("Flips Available: %d", flipsPerStage or 0),
  }

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
    table.insert(lines, string.format("Selected: %s", option.name or option.contentId or "Unknown"))
  elseif session and #(session.options or {}) > 0 and session.claimed ~= true then
    table.insert(lines, previewOptions.finalReward == true and "Choose a final reward." or "Choose a reward.")
  else
    table.insert(lines, "No reward will be added.")
  end

  if option and option.type == "coin" then
    if previewOptions.finalReward == true then
      table.insert(lines, "Coin recorded for this victory.")
    else
      table.insert(lines, "Coin joins the pouch.")
    end
  elseif option then
    if previewOptions.finalReward == true then
      table.insert(lines, "Trick recorded for this victory.")
    else
      table.insert(lines, "Trick becomes active.")
    end
  end

  return lines
end

function Game:getShopPreviewLinesForRun(runState)
  if not runState then
    return { "Next stop: Black Market", "Black Market preview unavailable." }
  end

  local lines = {
    "Next stop: Black Market",
    string.format("Influence: %d", runState.influence or 0),
    string.format("Free rerolls: %d", runState.shopRerollsRemaining or 0),
  }

  local upcomingStage = nil

  if self.getUpcomingStageDefinitionForRun then
    upcomingStage = self:getUpcomingStageDefinitionForRun(runState)
  else
    upcomingStage = Stages.getForRound(runState.roundIndex + 1, runState)
  end

  if upcomingStage then
    table.insert(lines, string.format("Next stage: %s", upcomingStage.label))

    if upcomingStage.stageType == "boss" then
      table.insert(lines, "Boss ahead.")
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
      "Next stop: Black Market",
      string.format("Projected Black Market outlook unavailable: %s", tostring(projectionError)),
    }
  end

  local lines = self:getShopPreviewLinesForRun(projectedOutcome and projectedOutcome.projectedRunState or self.runState)

  if self:shouldUseEncounterEvent() and #lines > 0 then
    lines[1] = "Black Market outlook after the encounter"
  end

  return lines
end

function Game:getProjectedUpcomingStagePreviewData(projected)
  local projectedOutcome, projectionError = projected, nil

  if projectedOutcome == nil then
    projectedOutcome, projectionError = self:getProjectedRewardOutcome()
  end

  if projectionError and not projectedOutcome then
    return {
      title = "After the Black Market",
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
    title = "After the Black Market",
    emptyTitle = "After the Black Market",
    emptyMessage = "No next stage is queued after this Black Market.",
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

    self.rewardPreviewSession = RewardSystem.buildPreviewForStage(self.runState, self.lastStageResult)
  RunHistorySystem.recordStageRewardPreview(self.lastStageResult, self.rewardPreviewSession)
  self:assertRuntimeInvariants("game.ensureRewardSession", { history = true })
  return self.rewardPreviewSession
end

function Game:shouldUseRewardPreview()
  return self.lastStageResult ~= nil
    and self.lastStageResult.stageType == "normal"
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

function Game:rerollRewardOptions()
  local session = self:getRewardSession()

  if not session then
    return false, "reward_preview_unavailable"
  end

  local ok, result = RewardSystem.rerollPreview(self.runState, session, self.lastStageResult)

  if ok then
    RunHistorySystem.recordStageRewardPreview(self.lastStageResult, session)

    local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
    if currentStateName == "reward_preview" or currentStateName == "boss_reward" then
      self:saveActiveRun("reward_reroll", currentStateName)
    end
  end

  return ok, result
end

function Game:getRewardSkipInfluenceAmount()
  return RewardSystem.getSkipInfluenceReward()
end

function Game:skipRewardForCurrency()
  local session = self:getRewardSession()

  if not session then
    return false, "reward_preview_unavailable"
  end

  local ok, result = RewardSystem.claimSkip(self.runState, session)

  if ok then
    RunHistorySystem.recordStageRewardChoice(self.lastStageResult, result)

    local currentStateName = self.stateGraph and self.stateGraph:getCurrentName() or nil
    if currentStateName == "reward_preview" or currentStateName == "boss_reward" then
      self:saveActiveRun("skip_reward", currentStateName)
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
    local displayType = tostring(option.type or "Reward")

    if option.type == "trick" or option.type == "upgrade" then
      displayType = TrickCharm.getFamilyLabel(option.trickCategory)
    elseif option.type == "coin" then
      displayType = "Coin"
    end

    table.insert(cards, {
      index = index,
      type = option.type,
      displayType = displayType,
      contentId = option.contentId,
      name = option.name,
      rarity = option.rarity,
      description = Terminology.formatText(option.description),
      rewardSource = option.rewardSource,
      enemyClassLabel = option.enemyClassLabel,
      wildcard = option.wildcard == true,
      trickCategory = option.trickCategory,
      selected = session.selectedIndex == index,
      claimed = session.claimed == true and session.choice and session.choice.contentId == option.contentId,
    })
  end

  return cards
end

function Game:getRewardPreviewContinueLabel()
  local session = self:getRewardSession()

  if not session or #(session.options or {}) == 0 then
    return self:shouldUseEncounterEvent() and "Continue to Encounter" or "Continue to Black Market"
  end

  if session.claimed == true then
    return self:shouldUseEncounterEvent() and "Continue to Encounter" or "Continue to Black Market"
  end

  return self:shouldUseEncounterEvent() and "Claim Reward & Continue to Encounter" or "Claim Reward & Continue"
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
    string.format("Boss defeated: %s", result.opponentName or result.stageLabel or "n/a"),
  }

  local victoryChipLine = self:formatVictoryChipRewardLine(result)
  if victoryChipLine then
    table.insert(lines, victoryChipLine)
  end

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Reputation +%d", result.metaRewardEarned))
  end

  table.insert(lines, "")

  if session and session.claimed and session.choice then
    table.insert(lines, string.format("Chosen: %s", session.choice.name or session.choice.contentId or "n/a"))
  elseif session and #(session.options or {}) == 0 then
    table.insert(lines, "No final rewards remain.")
  else
    table.insert(lines, "Choose one final reward.")
  end

  return lines
end

function Game:getBossRewardSummaryLines()
  local result = self.lastStageResult or {}
  local lines = {
    string.format("Boss Defeated: %s", result.opponentName or result.stageLabel or "n/a"),
    string.format("Final Pouch: %s", result.loadoutKey or self:getCurrentLoadoutKey()),
  }

  local victoryChipLine = self:formatVictoryChipRewardLine(result)
  if victoryChipLine then
    table.insert(lines, 2, victoryChipLine)
  end

  if (result.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Reputation Banked: %d", result.metaRewardEarned))
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

  if self:shouldUseBossRewardEvent() then
    local appended, appendError = self:appendRunRecord(self.runState and self.runState.runStatus or "won", self.stageState)

    if appended == false and self.runState and self.runState.runRecordSaved ~= true then
      return false, appendError or "run_record_save_failed"
    end
  end

  self:assertRuntimeInvariants("game.claimSelectedReward", { history = true })

  if result then
    self.logger:info("Claimed stage reward", {
      type = result.type,
      contentId = result.contentId,
    })
    local feedbackMessage = string.format("%s joined the run.", result.name or result.contentId or "Reward")

    if result.type == "currency" and result.currency == "influence" then
      feedbackMessage = string.format("Skipped reward for +%d Influence.", result.amount or 0)
    end

    if self:shouldUseBossRewardEvent() then
      feedbackMessage = string.format("%s was recorded for this victory.", result.name or result.contentId or "Reward")
    end

    self:showFeedback("success", "Reward Claimed", feedbackMessage, {
      duration = 1.05,
      flashAlpha = 0.05,
      soundCue = "shop_purchase",
    })
  else
    self.logger:info("No reward claim available; continuing to Black Market")
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
    string.format("Reputation Available: %d", self.metaState and self.metaState.metaPoints or 0),
    string.format("Purchased Tattoos: %d", #(self.metaState and (self.metaState.purchasedTattooIds or self.metaState.purchasedMetaUpgradeIds) or {})),
  }

  if (summary.metaRewardEarned or 0) > 0 then
    table.insert(lines, string.format("Reputation Ready to Spend: %d", summary.metaRewardEarned))
    table.insert(lines, "Open Tattoos from here to invest it immediately.")
    table.insert(lines, "From Tattoos you can start the next run directly.")
  else
    table.insert(lines, "Open Tattoos to review persistent progression before the next run.")
    table.insert(lines, "From Tattoos you can return here or jump straight into the next run.")
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
  elseif source.sourceType == "trick" or source.sourceType == "run upgrade" then
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

  if action.op == "add_stage_score" or action.op == "add_run_score" or action.op == "add_influence" or action.op == "add_shop_points" or action.op == "add_luck" then
    local amount = action.appliedAmount or action.amount
    return string.format("%s %+d", action.op, amount)
  end

  if action.op == "modify_coin_weight" then
    return string.format("%s %s %+0.0f%% chance%s", action.op, action.side, (action.amount or 0) * 100, action.persistent and " permanent" or "")
  end

  if action.op == "add_weight" then
    return string.format("%s %s %+0.0f%% Weight", action.op, action.side or "call", (action.amount or 0) * 100)
  end

  if action.op == "set_call_match_chance" then
    return string.format("%s %.0f%% call match", action.op, (action.chance or 0) * 100)
  end

  if action.op == "foretell_coin_result" then
    return string.format("%s %s", action.op, string.upper(action.foretoldResult or "?"))
  end

  if action.op == "forge_identity" then
    return string.format("%s S%d<-S%d", action.op, action.targetSlotIndex or action.slotIndex or 0, action.sourceSlotIndex or 0)
  end

  if action.op == "redirect_score_credit" then
    return string.format("%s S%d->S%d", action.op, action.sourceSlotIndex or action.slotIndex or 0, action.spotlightSlotIndex or action.targetSlotIndex or 0)
  end

  if action.op == "swap_coins" then
    return string.format("%s S%d<->S%d", action.op, action.failedSlotIndex or 0, action.successSlotIndex or 0)
  end

  if action.op == "smuggle_coin_from_hand" then
    return string.format("%s B%d", action.op, action.boardSlotIndex or 0)
  end

  if action.op == "replay_resolution_packet" then
    return string.format("%s %s +%d", action.op, tostring(action.packetId or "packet"), action.replayedScore or action.amount or 0)
  end

  if action.op == "trigger_random_neighbor" then
    return string.format("%s S%d->S%d", action.op, action.sourceSlotIndex or action.slotIndex or 0, action.chainedSlotIndex or action.targetSlotIndex or 0)
  end

  if action.op == "apply_score_scaling" or action.op == "apply_score_multiplier" then
    return string.format("apply_score_scaling x%.2f", action.value)
  end

  if action.op == "grant_coin" then
    return string.format("%s %s", action.op, self:getCoinName(action.coinId))
  end

  if action.op == "grant_trick" or action.op == "grant_upgrade" then
    return string.format("grant_trick %s", self:getUpgradeName(action.trickId or action.upgradeId))
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
        "%s@S%d/R%d roll=%.2f H%.0f%%/T%.0f%% => %s%s",
        self:getCoinName(coinState.coinId),
        coinState.slotIndex or 0,
        coinState.resolutionIndex or 0,
        coinState.rngRoll or 0,
        (coinState.headsWeight or 0) * 100,
        (coinState.tailsWeight or 0) * 100,
        string.upper(coinState.result or "?"),
        coinState.forcedResult and " [FORCED]" or ""
      )
    )
  end

  return string.format(
    "R%d B%d | call=%s | %s | score to HP %d/%d | run %d | Influence %d | status=%s",
    self.runState and self.runState.roundIndex or 0,
    batchResult.batchId,
    string.upper(batchResult.call or "?"),
    table.concat(coinSummaries, " ; "),
    batchResult.scoreAppliedToHp or batchResult.stageScore or 0,
    batchResult.opponentHp or batchResult.targetScore or 0,
    batchResult.runTotalScore or 0,
    batchResult.influence or batchResult.shopPoints or 0,
    batchResult.status or "active"
  )
end

function Game:getLastBatchSummaryLines(limit)
  local lines = {}
  local batchResult = self.lastBatchResult

  if not batchResult then
    return { "No " .. Terminology.getTermLower("flip") .. " resolved yet." }
  end

  table.insert(lines, string.format("%s %d | %s %s", Terminology.getTermLabel("flip"), batchResult.batchId, Terminology.getTermLower("call"), string.upper(batchResult.call)))

  for _, coinState in ipairs(batchResult.perCoin or {}) do
    table.insert(
      lines,
      string.format(
        "%s @ slot %d / order %d | H%.0f%%/T%.0f%% | %.2f => %s%s",
        self:getCoinName(coinState.coinId),
        coinState.slotIndex or 0,
        coinState.resolutionIndex or 0,
        (coinState.headsWeight or 0) * 100,
        (coinState.tailsWeight or 0) * 100,
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

local function formatWeightPair(headsWeight, tailsWeight)
  return string.format("H%.0f%% / T%.0f%%", (headsWeight or 0) * 100, (tailsWeight or 0) * 100)
end

local function formatScoreValue(value)
  local numericValue = tonumber(value) or 0

  if math.abs(numericValue - math.floor(numericValue + 0.00001)) < 0.00001 then
    return string.format("%d", math.floor(numericValue + 0.00001))
  end

  return string.format("%.2f", numericValue)
end

function Game:getFlipLogLines(limit)
  local batchResult = self.lastBatchResult

  if not batchResult then
    return { "No flip logged yet." }
  end

  local lines = {}
  local coinNames = {}
  local perCoinScore = {}

  for _, scoreEntry in ipairs(batchResult.scoreBreakdown and batchResult.scoreBreakdown.perCoin or {}) do
    perCoinScore[scoreEntry.resolutionIndex or #perCoinScore + 1] = scoreEntry
  end

  for _, coinState in ipairs(batchResult.perCoin or {}) do
    table.insert(coinNames, self:getCoinName(coinState.coinId))
  end

  table.insert(lines, string.format("%s %d | %s %s", Terminology.getTermLabel("flip"), batchResult.batchId or 0, Terminology.getTermLower("call"), string.upper(batchResult.call or "?")))
  table.insert(lines, "Coins used: " .. (#coinNames > 0 and table.concat(coinNames, ", ") or "none"))
  table.insert(lines, "")

  for index, coinState in ipairs(batchResult.perCoin or {}) do
    local scoreEntry = perCoinScore[coinState.resolutionIndex or index] or {}
    local headsWeight = coinState.headsWeight or 0
    local tailsWeight = coinState.tailsWeight or 0
    local outcome = string.upper(coinState.result or "?")
    local matchLabel = string.upper(Terminology.getOutcomeLabel(coinState.result == batchResult.call and "match" or "miss"))

    table.insert(lines, string.format(
      "%d. %s @ slot %s / order %s",
      index,
      self:getCoinName(coinState.coinId),
      tostring(coinState.slotIndex or "?"),
      tostring(coinState.resolutionIndex or "?")
    ))
    table.insert(lines, string.format(
      "   basic chance: %s | final chance: %s",
      formatWeightPair(coinState.baseHeadsWeight or scoreEntry.baseHeadsWeight or headsWeight, coinState.baseTailsWeight or scoreEntry.baseTailsWeight or tailsWeight),
      formatWeightPair(headsWeight, tailsWeight)
    ))

    table.insert(lines, string.format(
      "   base score: %s | final score: %s | outcome: %s %s%s",
      formatScoreValue(scoreEntry.baseScoreContribution),
      formatScoreValue(scoreEntry.finalScoreContribution),
      outcome,
      matchLabel,
      coinState.forcedResult and " [FORCED]" or ""
    ))
  end

  local specialLines = {}
  local seenSpecialEvents = {}

  local function addSmuggleLine(coinId, instanceId, overloadSlotIndex, sourceName)
    local key = string.format("smuggle:%s:%s:%s", tostring(instanceId), tostring(coinId), tostring(overloadSlotIndex))

    if seenSpecialEvents[key] then
      return
    end

    seenSpecialEvents[key] = true
    table.insert(specialLines, string.format(
      "COIN SMUGGLED: %s added to overload slot %s%s",
      self:getCoinName(coinId),
      tostring(overloadSlotIndex or "?"),
      sourceName and string.format(" by %s", sourceName) or ""
    ))
  end

  for _, move in ipairs(batchResult.trace and batchResult.trace.smugglingMoves or {}) do
    addSmuggleLine(move.coinId, move.instanceId, move.overloadSlotIndex, move.sourceName)
  end

  for _, action in ipairs(batchResult.trace and batchResult.trace.actions or {}) do
    if action.op == "smuggle_coin_from_hand" then
      local trace = action._trace or {}
      addSmuggleLine(action.smuggledCoinId or action.coinId, action.smuggledInstanceId or action.instanceId, action.overloadSlotIndex, trace.sourceName)
    end
  end

  if #specialLines > 0 then
    table.insert(lines, "")
    table.insert(lines, "Special events:")

    for _, line in ipairs(specialLines) do
      table.insert(lines, "- " .. line)
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

function Game:getScoreBreakdownLines(limit)
  local lines = {}
  local breakdown = self.lastBatchResult and self.lastBatchResult.scoreBreakdown or nil

  if not breakdown then
    return { "No score breakdown yet." }
  end

  local stageBonusDelta = 0

  for _, bonus in ipairs(breakdown.additiveBonuses or {}) do
    if bonus.scoreTarget == "stage" then
      stageBonusDelta = stageBonusDelta + (bonus.amount or 0)
    end
  end

  table.insert(lines, string.format("Base score: %d", breakdown.baseScore or 0))
  table.insert(lines, string.format("After score scaling: %d", breakdown.finalBaseScore or breakdown.baseScore or 0))
  table.insert(lines, string.format("Score bonus delta: %+d", stageBonusDelta))
  table.insert(lines, string.format("Score applied to HP gained: %+d", breakdown.totalStageScoreDelta or 0))
  table.insert(lines, string.format("Triggered sources: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.triggeredSources or {})))
  table.insert(lines, string.format("Emitted actions: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.actions or {})))
  table.insert(lines, string.format("Queued follow-ups: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.queuedActions or {})))

  if #(self.lastBatchResult.trace and self.lastBatchResult.trace.temporaryEffectsGranted or {}) > 0 then
    table.insert(lines, string.format("Temp effects granted: %d", #(self.lastBatchResult.trace and self.lastBatchResult.trace.temporaryEffectsGranted or {})))
  end

  if (breakdown.totalShopPointDelta or 0) ~= 0 then
    table.insert(lines, string.format("%s delta: %+d", Terminology.getTermLabel("chip"), breakdown.totalShopPointDelta or 0))
  end

  for _, scoreScaling in ipairs(breakdown.scoreScalings or breakdown.multipliers or {}) do
    table.insert(lines, string.format("Score Scaling: x%.2f", scoreScaling.value or 1.0))
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
