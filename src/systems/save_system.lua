local MetaState = require("src.domain.meta_state")
local TrickBoardSystem = require("src.systems.trick_board_system")
local PredictionSlotSystem = require("src.systems.prediction_slot_system")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local BossTrickSystem = require("src.systems.boss_trick_system")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local SaveSystem = {
  SAVE_VERSION = 2,
  SAVE_ARTIFACT_TYPE = "meta_state",
  META_STATE_PATH = "save/meta_state.lua",
  DISPLAY_SETTINGS_VERSION = 1,
  DISPLAY_SETTINGS_ARTIFACT_TYPE = "display_settings",
  DISPLAY_SETTINGS_PATH = "save/display_settings.lua",
  ACTIVE_RUN_VERSION = 1,
  ACTIVE_RUN_ARTIFACT_TYPE = "active_run",
  ACTIVE_RUN_PATH = "save/active_run.lua",
}

local Parser = {}
Parser.__index = Parser

local function getFilesystem(providedFilesystem)
  if providedFilesystem then
    return providedFilesystem
  end

  return love and love.filesystem or nil
end

local function collectSortedKeys(value)
  local keys = {}

  for key in pairs(value) do
    table.insert(keys, key)
  end

  table.sort(keys, function(left, right)
    if type(left) == type(right) then
      return left < right
    end

    return tostring(type(left)) < tostring(type(right))
  end)

  return keys
end

function Parser.new(source)
  return setmetatable({
    source = source or "",
    position = 1,
    length = #(source or ""),
  }, Parser)
end

function Parser:peek(offset)
  return self.source:sub(self.position + (offset or 0), self.position + (offset or 0))
end

function Parser:skipWhitespace()
  while self.position <= self.length do
    local character = self:peek()

    if character == " " or character == "\n" or character == "\r" or character == "\t" then
      self.position = self.position + 1
    else
      break
    end
  end
end

function Parser:consume(expected)
  self:skipWhitespace()

  if self.source:sub(self.position, self.position + #expected - 1) ~= expected then
    error(string.format("Expected '%s' at position %d", expected, self.position))
  end

  self.position = self.position + #expected
end

function Parser:parseString()
  self:skipWhitespace()
  local quote = self:peek()

  if quote ~= '"' and quote ~= "'" then
    error(string.format("Expected string at position %d", self.position))
  end

  self.position = self.position + 1
  local parts = {}

  while self.position <= self.length do
    local character = self:peek()

    if character == quote then
      self.position = self.position + 1
      return table.concat(parts)
    end

    if character == "\\" then
      local escaped = self:peek(1)

      if escaped == "a" then
        table.insert(parts, "\a")
        self.position = self.position + 2
      elseif escaped == "b" then
        table.insert(parts, "\b")
        self.position = self.position + 2
      elseif escaped == "f" then
        table.insert(parts, "\f")
        self.position = self.position + 2
      elseif escaped == "n" then
        table.insert(parts, "\n")
        self.position = self.position + 2
      elseif escaped == "r" then
        table.insert(parts, "\r")
        self.position = self.position + 2
      elseif escaped == "t" then
        table.insert(parts, "\t")
        self.position = self.position + 2
      elseif escaped == "v" then
        table.insert(parts, "\v")
        self.position = self.position + 2
      elseif escaped == "\\" or escaped == '"' or escaped == "'" then
        table.insert(parts, escaped)
        self.position = self.position + 2
      elseif escaped:match("%d") then
        local digits = self.source:sub(self.position + 1, self.position + 3):match("^%d%d?%d?")
        table.insert(parts, string.char(tonumber(digits)))
        self.position = self.position + 1 + #digits
      else
        error(string.format("Unsupported escape sequence at position %d", self.position))
      end
    else
      table.insert(parts, character)
      self.position = self.position + 1
    end
  end

  error("Unterminated string in save payload")
end

function Parser:parseNumber()
  self:skipWhitespace()
  local remainder = self.source:sub(self.position)
  local literal = remainder:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*")

  if not literal or literal == "" then
    error(string.format("Expected number at position %d", self.position))
  end

  local numericValue = tonumber(literal)

  if numericValue == nil then
    error(string.format("Invalid numeric literal '%s'", literal))
  end

  self.position = self.position + #literal
  return numericValue
end

function Parser:parseIdentifier()
  self:skipWhitespace()
  local remainder = self.source:sub(self.position)
  local identifier = remainder:match("^[%a_][%w_]*")

  if not identifier then
    error(string.format("Expected identifier at position %d", self.position))
  end

  self.position = self.position + #identifier

  if identifier == "true" then
    return true
  end

  if identifier == "false" then
    return false
  end

  if identifier == "nil" then
    return nil
  end

  return identifier
end

function Parser:parseValue()
  self:skipWhitespace()
  local character = self:peek()

  if character == "{" then
    return self:parseTable()
  end

  if character == '"' or character == "'" then
    return self:parseString()
  end

  if character == "-" or character:match("%d") then
    return self:parseNumber()
  end

  return self:parseIdentifier()
end

function Parser:parseTable()
  self:consume("{")
  local result = {}
  local arrayIndex = 1

  while true do
    self:skipWhitespace()

    if self:peek() == "}" then
      self.position = self.position + 1
      return result
    end

    local key
    local hasExplicitKey = false

    if self:peek() == "[" then
      self.position = self.position + 1
      key = self:parseValue()
      self:skipWhitespace()
      self:consume("]")
      self:skipWhitespace()
      self:consume("=")
      hasExplicitKey = true
    else
      local checkpoint = self.position
      local parsedIdentifier = self:parseIdentifier()
      self:skipWhitespace()

      if self:peek() == "=" and type(parsedIdentifier) == "string" then
        self.position = checkpoint + #parsedIdentifier
        self:consume("=")
        key = parsedIdentifier
        hasExplicitKey = true
      else
        self.position = checkpoint
      end
    end

    local value = self:parseValue()

    if hasExplicitKey then
      result[key] = value
    else
      result[arrayIndex] = value
      arrayIndex = arrayIndex + 1
    end

    self:skipWhitespace()

    if self:peek() == "," then
      self.position = self.position + 1
    elseif self:peek() ~= "}" then
      error(string.format("Expected ',' or '}' at position %d", self.position))
    end
  end
end

function SaveSystem.parseTablePayload(contents)
  local parser = Parser.new(contents)
  parser:skipWhitespace()

  if parser.source:sub(parser.position, parser.position + 5) == "return" then
    parser.position = parser.position + 6
  end

  local ok, payload = pcall(function()
    local value = parser:parseValue()
    parser:skipWhitespace()

    if parser.position <= parser.length then
      error(string.format("Unexpected trailing content at position %d", parser.position))
    end

    return value
  end)

  if not ok then
    return nil, payload
  end

  return payload
end

function SaveSystem.serializeValue(value, indentLevel)
  indentLevel = indentLevel or 0
  local valueType = type(value)

  if valueType == "nil" then
    return "nil"
  end

  if valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end

  if valueType == "string" then
    return string.format("%q", value)
  end

  if valueType ~= "table" then
    error(string.format("Cannot serialize value of type %s", valueType))
  end

  local keys = collectSortedKeys(value)

  if #keys == 0 then
    return "{}"
  end

  local indent = string.rep("  ", indentLevel)
  local childIndent = string.rep("  ", indentLevel + 1)
  local parts = { "{" }

  for _, key in ipairs(keys) do
    local serializedKey = string.format("[%s]", SaveSystem.serializeValue(key, indentLevel + 1))
    local serializedValue = SaveSystem.serializeValue(value[key], indentLevel + 1)
    table.insert(parts, string.format("\n%s%s = %s,", childIndent, serializedKey, serializedValue))
  end

  table.insert(parts, string.format("\n%s}", indent))
  return table.concat(parts)
end

function SaveSystem.normalizeMetaStateForSave(metaState)
  local ok, errorMessage = Validator.validateMetaState(metaState)

  if not ok then
    return nil, errorMessage
  end

  return {
    metaPoints = metaState.metaPoints,
    lifetimeMetaPointsEarned = metaState.lifetimeMetaPointsEarned,
    unlockedCoinIds = Utils.copyArray(metaState.unlockedCoinIds or {}),
    unlockedTrickIds = Utils.copyArray(metaState.unlockedTrickIds or metaState.unlockedUpgradeIds or {}),
    purchasedTattooIds = Utils.copyArray(metaState.purchasedTattooIds or metaState.purchasedMetaUpgradeIds or {}),
    equippedTattooIds = Utils.copyArray(metaState.equippedTattooIds or {}),
    tattooLoadoutLimit = metaState.tattooLoadoutLimit,
    runRecords = Utils.clone(metaState.runRecords or {}),
    effectiveValues = Utils.clone(metaState.effectiveValues or {}),
    stats = Utils.clone(metaState.stats or {}),
  }
end

function SaveSystem.normalizeActiveRunForSave(snapshot)
  local candidate = Utils.clone(snapshot)
  if type(candidate.runState) == "table" then
    candidate.runState.maxActiveTricks = candidate.runState.maxActiveTricks or 5
    local _, removed = TrickBoardSystem.sanitizeActiveTricks(candidate.runState)
    if #removed > 0 and type(candidate.stageState) == "table"
      and type(candidate.stageState.trickBoard) == "table" then
      candidate.stageState.trickBoard.pressure = {}
    end
  end
  if type(candidate.stageState) == "table" then
    candidate.stageState.trickBoard = candidate.stageState.trickBoard or {
      phase = candidate.stageState.stageStatus == "active" and "setup" or "complete",
      revision = 1,
      pressure = {},
      replacementsRemaining = 3,
      replacementHistory = {},
    }
    if type(candidate.stageState.purse) == "table" then
      candidate.stageState.purse.replacementHistory = candidate.stageState.purse.replacementHistory or {}
    end
    PredictionSlotSystem.ensure(candidate.runState, candidate.stageState)
    EnemySkillSystem.ensureState(candidate.stageState)
    BossTrickSystem.ensureState(candidate.stageState)
    if candidate.stageState.stageType == "boss" then
      EnemySkillSystem.assignSkill(candidate.runState, candidate.stageState)
      if candidate.stageState.stageStatus == "active"
        and candidate.stageState.trickBoard.phase == "setup" then
        BossTrickSystem.ensureIntent(candidate.runState, candidate.stageState)
      end
    elseif candidate.stageState.stageStatus == "active"
      and candidate.stageState.trickBoard.phase == "setup" then
      EnemySkillSystem.ensureIntent(candidate.runState, candidate.stageState)
      BossTrickSystem.ensureIntent(candidate.runState, candidate.stageState)
    end
  end

  local ok, errorMessage = Validator.validateActiveRunArtifactPayload(candidate)

  if not ok then
    return nil, errorMessage
  end

  return {
    currentState = candidate.currentState,
    runState = Utils.clone(candidate.runState),
    stageState = Utils.clone(candidate.stageState),
    runRngSeed = candidate.runRngSeed,
    selectedCall = candidate.selectedCall,
    lastBatchResult = Utils.clone(candidate.lastBatchResult),
    lastStageResult = Utils.clone(candidate.lastStageResult),
    postResultNextState = candidate.postResultNextState,
    rewardPreviewSession = Utils.clone(candidate.rewardPreviewSession),
    encounterSession = Utils.clone(candidate.encounterSession),
    shopOffers = Utils.clone(candidate.shopOffers or {}),
    shopSession = Utils.clone(candidate.shopSession),
    lastShopGenerationTrace = Utils.clone(candidate.lastShopGenerationTrace),
    lastShopPurchaseTrace = Utils.clone(candidate.lastShopPurchaseTrace),
    currentStageDefinitionId = candidate.currentStageDefinitionId,
    screenState = Utils.clone(candidate.screenState),
  }
end

local function buildMetaArtifact(metaState)
  local normalizedMetaState, errorMessage = SaveSystem.normalizeMetaStateForSave(metaState)

  if not normalizedMetaState then
    return nil, errorMessage
  end

  return {
    artifactType = SaveSystem.SAVE_ARTIFACT_TYPE,
    version = SaveSystem.SAVE_VERSION,
    metaState = normalizedMetaState,
  }
end

local function buildActiveRunArtifact(snapshot)
  local normalizedSnapshot, errorMessage = SaveSystem.normalizeActiveRunForSave(snapshot)

  if not normalizedSnapshot then
    return nil, errorMessage
  end

  return {
    artifactType = SaveSystem.ACTIVE_RUN_ARTIFACT_TYPE,
    version = SaveSystem.ACTIVE_RUN_VERSION,
    activeRun = normalizedSnapshot,
  }
end

local function buildCanonicalMetaArtifactFromPayload(metaStateTable)
  local ok, errorMessage = Validator.validateMetaStatePayload(metaStateTable)

  if not ok then
    return nil, errorMessage
  end

  local metaState = MetaState.new(metaStateTable)
  return buildMetaArtifact(metaState)
end

local function migrateMetaArtifactPayload(payload)
  if type(payload) ~= "table" then
    return nil, "save payload was not a table"
  end

  if payload.artifactType ~= nil then
    local ok, errorMessage = Validator.validateSaveArtifactPayload(payload)

    if not ok then
      return nil, errorMessage
    end

    if payload.artifactType ~= SaveSystem.SAVE_ARTIFACT_TYPE then
      return nil, string.format("unsupported_save_artifact_type:%s", tostring(payload.artifactType))
    end

    if payload.version ~= SaveSystem.SAVE_VERSION then
      return nil, string.format("unsupported_save_version:%s", tostring(payload.version))
    end

    return buildCanonicalMetaArtifactFromPayload(payload.metaState)
  end

  if payload.version == 1 and type(payload.metaState) == "table" then
    return buildCanonicalMetaArtifactFromPayload(payload.metaState)
  end

  if payload.version ~= nil then
    return nil, string.format("unsupported_save_version:%s", tostring(payload.version))
  end

  if type(payload.metaState) == "table" then
    return buildCanonicalMetaArtifactFromPayload(payload.metaState)
  end

  return buildCanonicalMetaArtifactFromPayload(payload)
end

function SaveSystem.decodeMetaArtifactString(contents)
  local payload, parseError = SaveSystem.parseTablePayload(contents)

  if not payload then
    return nil, parseError
  end

  return migrateMetaArtifactPayload(payload)
end

function SaveSystem.encodeMetaState(metaState)
  local payload, errorMessage = buildMetaArtifact(metaState)

  if not payload then
    error(errorMessage)
  end

  return "return " .. SaveSystem.serializeValue(payload)
end

function SaveSystem.decodeMetaStateString(contents)
  local artifact, artifactError = SaveSystem.decodeMetaArtifactString(contents)

  if not artifact then
    return nil, artifactError
  end

  local ok, metaState = pcall(MetaState.new, artifact.metaState)

  if not ok then
    return nil, metaState
  end

  local valid, errorMessage = Validator.validateMetaState(metaState)

  if not valid then
    return nil, errorMessage
  end

  return metaState
end

function SaveSystem.loadMetaState(providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return nil, "filesystem_unavailable"
  end

  if not filesystem.getInfo(SaveSystem.META_STATE_PATH) then
    return nil, "not_found"
  end

  local contents, readError = filesystem.read(SaveSystem.META_STATE_PATH)

  if not contents then
    return nil, readError or "read_failed"
  end

  return SaveSystem.decodeMetaStateString(contents)
end

function SaveSystem.decodeDisplaySettingsString(contents)
  local payload, parseError = SaveSystem.parseTablePayload(contents)

  if not payload then
    return nil, parseError
  end

  if type(payload) ~= "table" then
    return nil, "display settings payload was not a table"
  end

  if payload.artifactType ~= SaveSystem.DISPLAY_SETTINGS_ARTIFACT_TYPE then
    return nil, string.format("unsupported_display_settings_artifact_type:%s", tostring(payload.artifactType))
  end

  if payload.version ~= SaveSystem.DISPLAY_SETTINGS_VERSION then
    return nil, string.format("unsupported_display_settings_version:%s", tostring(payload.version))
  end

  if type(payload.targetResolutionId) ~= "string" or payload.targetResolutionId == "" then
    return nil, "display settings targetResolutionId must be a non-empty string"
  end

  return {
    targetResolutionId = payload.targetResolutionId,
  }
end

function SaveSystem.loadDisplaySettings(providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return nil, "filesystem_unavailable"
  end

  if not filesystem.getInfo(SaveSystem.DISPLAY_SETTINGS_PATH) then
    return nil, "not_found"
  end

  local contents, readError = filesystem.read(SaveSystem.DISPLAY_SETTINGS_PATH)

  if not contents then
    return nil, readError or "read_failed"
  end

  return SaveSystem.decodeDisplaySettingsString(contents)
end

function SaveSystem.decodeActiveRunArtifactString(contents)
  local payload, parseError = SaveSystem.parseTablePayload(contents)

  if not payload then
    return nil, parseError
  end

  if type(payload) ~= "table" then
    return nil, "active run payload was not a table"
  end

  if payload.artifactType ~= SaveSystem.ACTIVE_RUN_ARTIFACT_TYPE then
    return nil, string.format("unsupported_active_run_artifact_type:%s", tostring(payload.artifactType))
  end

  if payload.version ~= SaveSystem.ACTIVE_RUN_VERSION then
    return nil, string.format("unsupported_active_run_version:%s", tostring(payload.version))
  end

  if type(payload.activeRun) ~= "table" then
    return nil, "active run artifact missing activeRun table"
  end

  local artifact = {
    artifactType = payload.artifactType,
    version = payload.version,
  }

  for key, value in pairs(payload.activeRun) do
    artifact[key] = value
  end

  artifact.draftSession = nil

  if artifact.currentState == "coin_draft" then
    artifact.currentState = "loadout"
    artifact.screenState = nil
  end

  if type(artifact.runState) == "table" then
    artifact.runState.influence = artifact.runState.influence or artifact.runState.shopPoints
    artifact.runState.maxFlipSlots = artifact.runState.maxFlipSlots or artifact.runState.maxActiveCoinSlots
    artifact.runState.maxActiveCoinSlots = artifact.runState.maxActiveCoinSlots or artifact.runState.maxFlipSlots
    artifact.runState.flipSlots = artifact.runState.flipSlots or artifact.runState.equippedCoinSlots
    artifact.runState.persistedFlipSlots = artifact.runState.persistedFlipSlots or artifact.runState.persistedLoadoutSlots
    artifact.runState.ownedTrickIds = artifact.runState.ownedTrickIds or artifact.runState.ownedUpgradeIds
    artifact.runState.unlockedTrickIds = artifact.runState.unlockedTrickIds or artifact.runState.unlockedUpgradeIds
    artifact.runState.maxActiveTricks = artifact.runState.maxActiveTricks or 5
    local _, removed = TrickBoardSystem.sanitizeActiveTricks(artifact.runState)
    if #removed > 0 and type(artifact.stageState) == "table"
      and type(artifact.stageState.trickBoard) == "table" then
      artifact.stageState.trickBoard.pressure = {}
    end
  end

  if type(artifact.stageState) == "table" then
    artifact.stageState.scoreAppliedToHp = artifact.stageState.scoreAppliedToHp or artifact.stageState.stageScore
    artifact.stageState.opponentHp = artifact.stageState.opponentHp or artifact.stageState.targetScore
    artifact.stageState.trickBoard = artifact.stageState.trickBoard or {
      phase = "setup",
      revision = 1,
      pressure = {},
      replacementsRemaining = 3,
      replacementHistory = {},
    }
    artifact.stageState.trickBoard.phase = artifact.stageState.trickBoard.phase or "setup"
    artifact.stageState.trickBoard.pressure = artifact.stageState.trickBoard.pressure or {}
    artifact.stageState.trickBoard.replacementsRemaining = artifact.stageState.trickBoard.replacementsRemaining or 3
    artifact.stageState.trickBoard.replacementHistory = artifact.stageState.trickBoard.replacementHistory or {}
    if type(artifact.stageState.purse) == "table" then
      artifact.stageState.purse.replacementHistory = artifact.stageState.purse.replacementHistory or {}
    end
    PredictionSlotSystem.ensure(artifact.runState, artifact.stageState)
    EnemySkillSystem.ensureState(artifact.stageState)
    BossTrickSystem.ensureState(artifact.stageState)
    if artifact.stageState.stageType == "boss" then
      EnemySkillSystem.assignSkill(artifact.runState, artifact.stageState)
      if artifact.stageState.stageStatus == "active"
        and artifact.stageState.trickBoard.phase == "setup" then
        BossTrickSystem.ensureIntent(artifact.runState, artifact.stageState)
      end
    elseif artifact.stageState.stageStatus == "active"
      and artifact.stageState.trickBoard.phase == "setup" then
      EnemySkillSystem.ensureIntent(artifact.runState, artifact.stageState)
      BossTrickSystem.ensureIntent(artifact.runState, artifact.stageState)
    end
  end

  local ok, errorMessage = Validator.validateActiveRunArtifactPayload(artifact)

  if not ok then
    return nil, errorMessage
  end

  return artifact
end

function SaveSystem.loadActiveRun(providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return nil, "filesystem_unavailable"
  end

  if not filesystem.getInfo(SaveSystem.ACTIVE_RUN_PATH) then
    return nil, "not_found"
  end

  local contents, readError = filesystem.read(SaveSystem.ACTIVE_RUN_PATH)

  if not contents then
    return nil, readError or "read_failed"
  end

  return SaveSystem.decodeActiveRunArtifactString(contents)
end

function SaveSystem.saveMetaState(metaState, providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return false, "filesystem_unavailable"
  end

  if filesystem.createDirectory then
    filesystem.createDirectory("save")
  end

  local artifact, artifactError = buildMetaArtifact(metaState)

  if not artifact then
    return false, artifactError
  end

  local ok, writeError = filesystem.write(SaveSystem.META_STATE_PATH, "return " .. SaveSystem.serializeValue(artifact))

  if not ok then
    return false, writeError or "write_failed"
  end

  return true
end

function SaveSystem.saveDisplaySettings(settings, providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return false, "filesystem_unavailable"
  end

  if type(settings) ~= "table" or type(settings.targetResolutionId) ~= "string" or settings.targetResolutionId == "" then
    return false, "invalid_display_settings"
  end

  if filesystem.createDirectory then
    filesystem.createDirectory("save")
  end

  local artifact = {
    artifactType = SaveSystem.DISPLAY_SETTINGS_ARTIFACT_TYPE,
    version = SaveSystem.DISPLAY_SETTINGS_VERSION,
    targetResolutionId = settings.targetResolutionId,
  }
  local ok, writeError = filesystem.write(SaveSystem.DISPLAY_SETTINGS_PATH, "return " .. SaveSystem.serializeValue(artifact))

  if not ok then
    return false, writeError or "write_failed"
  end

  return true
end

function SaveSystem.saveActiveRun(snapshot, providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return false, "filesystem_unavailable"
  end

  if filesystem.createDirectory then
    filesystem.createDirectory("save")
  end

  local artifact, artifactError = buildActiveRunArtifact(snapshot)

  if not artifact then
    return false, artifactError
  end

  local ok, writeError = filesystem.write(SaveSystem.ACTIVE_RUN_PATH, "return " .. SaveSystem.serializeValue(artifact))

  if not ok then
    return false, writeError or "write_failed"
  end

  return true
end

function SaveSystem.clearActiveRun(providedFilesystem)
  local filesystem = getFilesystem(providedFilesystem)

  if not filesystem then
    return false, "filesystem_unavailable"
  end

  if not filesystem.getInfo(SaveSystem.ACTIVE_RUN_PATH) then
    return true
  end

  if filesystem.remove then
    local ok, errorMessage = filesystem.remove(SaveSystem.ACTIVE_RUN_PATH)

    if ok == false then
      return false, errorMessage or "remove_failed"
    end

    return true
  end

  local ok, writeError = filesystem.write(SaveSystem.ACTIVE_RUN_PATH, "")

  if not ok then
    return false, writeError or "clear_failed"
  end

  return true
end

return SaveSystem
