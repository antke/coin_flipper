package.path = "./?.lua;./?/init.lua;" .. package.path

local MetaState = require("src.domain.meta_state")
local ReplaySystem = require("src.systems.replay_system")
local RunHistorySystem = require("src.systems.run_history_system")
local SaveSystem = require("src.systems.save_system")
local SimulationSystem = require("src.systems.simulation_system")
local Utils = require("src.core.utils")
local EncounterSystem = require("src.systems.encounter_system")

local checksRun = 0
local checksPassed = 0
local failures = {}

local function runCheck(name, callback)
  checksRun = checksRun + 1

  local ok, errorMessage = pcall(callback)

  if ok then
    checksPassed = checksPassed + 1
  else
    table.insert(failures, string.format("%s failed: %s", name, tostring(errorMessage)))
  end
end

local function encodeTable(value)
  return "return " .. SaveSystem.serializeValue(value)
end

runCheck("current_meta_save_roundtrip", function()
  local metaState = MetaState.new({
    metaPoints = 4,
    purchasedMetaUpgradeIds = { "meta_bonus_slot_1" },
    effectiveValues = {
      ["run.maxActiveCoinSlots"] = { mode = "add", value = 1 },
    },
    stats = {
      runsStarted = 2,
    },
  })

  local encoded = SaveSystem.encodeMetaState(metaState)
  local artifact, artifactError = SaveSystem.decodeMetaArtifactString(encoded)
  assert(artifact, artifactError)
  assert(artifact.artifactType == SaveSystem.SAVE_ARTIFACT_TYPE)
  assert(artifact.version == SaveSystem.SAVE_VERSION)

  local decoded, decodeError = SaveSystem.decodeMetaStateString(encoded)
  assert(decoded, decodeError)
  assert(decoded.metaPoints == 4)
  assert(decoded.stats.runsStarted == 2)
  assert(decoded.effectiveValues["run.maxActiveCoinSlots"].value == 1)
end)

runCheck("legacy_raw_meta_save_migrates", function()
  local decoded, decodeError = SaveSystem.decodeMetaStateString(encodeTable({
    metaPoints = 3,
    modifiers = {
      startingShopPoints = 2,
    },
    stats = {
      runsStarted = 1,
    },
  }))

  assert(decoded, decodeError)
  assert(decoded.effectiveValues["run.startingShopPoints"].value == 2)
  assert(decoded.stats.runsStarted == 1)
end)

runCheck("legacy_v1_meta_save_migrates", function()
  local decoded, decodeError = SaveSystem.decodeMetaStateString(encodeTable({
    version = 1,
    metaState = {
      metaPoints = 5,
      modifiers = {
        bonusCoinSlots = 1,
      },
      stats = {
        runsWon = 1,
      },
    },
  }))

  assert(decoded, decodeError)
  assert(decoded.effectiveValues["run.maxActiveCoinSlots"].value == 1)
  assert(decoded.stats.runsWon == 1)
end)

runCheck("invalid_meta_save_rejected", function()
  local decoded, decodeError = SaveSystem.decodeMetaStateString(encodeTable({
    metaPoints = 1,
    badField = true,
  }))

  assert(decoded == nil)
  assert(type(decodeError) == "string" and decodeError:match("unknown field"))
end)

runCheck("unsupported_meta_save_version_rejected", function()
  local decoded, decodeError = SaveSystem.decodeMetaStateString(encodeTable({
    artifactType = SaveSystem.SAVE_ARTIFACT_TYPE,
    version = 999,
    metaState = {},
  }))

  assert(decoded == nil)
  assert(decodeError == "unsupported_save_version:999")
end)

runCheck("current_transcript_roundtrip", function()
  local result = SimulationSystem.simulateRun({ seed = 77 })
  local transcript, transcriptError = ReplaySystem.buildTranscript(result.runState)
  assert(transcript, transcriptError)
  assert(transcript.artifactType == ReplaySystem.TRANSCRIPT_ARTIFACT_TYPE)
  assert(transcript.version == ReplaySystem.TRANSCRIPT_VERSION)

  local replay = ReplaySystem.replayTranscript(transcript)
  assert(replay.ok, table.concat(replay.mismatches or {}, " | "))
end)

runCheck("legacy_v1_transcript_migrates", function()
  local result = SimulationSystem.simulateRun({ seed = 78 })
  local transcript, transcriptError = ReplaySystem.buildTranscript(result.runState)
  assert(transcript, transcriptError)

  local legacyTranscript = Utils.clone(transcript)
  legacyTranscript.artifactType = nil
  legacyTranscript.version = 1
  legacyTranscript.bootstrap.resolvedValues = {
    startingCollectionSize = transcript.bootstrap.resolvedValues["run.startingCollectionSize"],
    maxActiveCoinSlots = transcript.bootstrap.resolvedValues["run.maxActiveCoinSlots"],
    baseFlipsPerStage = transcript.bootstrap.resolvedValues["stage.flipsPerStage"],
    startingShopPoints = transcript.bootstrap.resolvedValues["run.startingShopPoints"],
    startingShopRerolls = transcript.bootstrap.resolvedValues["run.startingShopRerolls"],
  }

  local replay = ReplaySystem.replayTranscript(legacyTranscript)
  assert(replay.ok, table.concat(replay.mismatches or {}, " | "))
end)

runCheck("save_artifact_unknown_field_rejected", function()
  local artifact, artifactError = SaveSystem.decodeMetaArtifactString(encodeTable({
    artifactType = SaveSystem.SAVE_ARTIFACT_TYPE,
    version = SaveSystem.SAVE_VERSION,
    metaState = {},
    extra = true,
  }))

  assert(artifact == nil)
  assert(type(artifactError) == "string" and artifactError:match("unknown field"))
end)

runCheck("conflicting_meta_state_payload_rejected", function()
  local decoded, decodeError = SaveSystem.decodeMetaStateString(encodeTable({
    metaPoints = 1,
    effectiveValues = {
      ["run.maxActiveCoinSlots"] = { mode = "add", value = 1 },
    },
    modifiers = {
      bonusCoinSlots = 2,
    },
  }))

  assert(decoded == nil)
  assert(type(decodeError) == "string" and decodeError:match("conflict"))
end)

runCheck("purchased_meta_effect_drift_rejected", function()
  local decoded, decodeError = SaveSystem.decodeMetaStateString(encodeTable({
    metaPoints = 1,
    purchasedMetaUpgradeIds = { "meta_shop_quality_1" },
    effectiveValues = {},
    unlockedCoinIds = {},
    unlockedUpgradeIds = {},
  }))

  assert(decoded == nil)
  assert(type(decodeError) == "string" and decodeError:match("missing purchased effect"))
end)

runCheck("invalid_transcript_rejected", function()
  local replay = ReplaySystem.replayTranscript({
    artifactType = ReplaySystem.TRANSCRIPT_ARTIFACT_TYPE,
    version = ReplaySystem.TRANSCRIPT_VERSION,
    stages = {},
    expected = {},
  })

  assert(not replay.ok)
  assert(replay.error == "invalid_transcript_schema")
end)

runCheck("unsupported_transcript_version_rejected", function()
  local replay = ReplaySystem.replayTranscript({
    artifactType = ReplaySystem.TRANSCRIPT_ARTIFACT_TYPE,
    version = 999,
    bootstrap = {},
    stages = {},
    expected = {},
  })

  assert(not replay.ok)
  assert(replay.error == "unsupported_transcript_version:999")
end)

runCheck("transcript_bad_loadout_canonical_key_rejected", function()
  local result = SimulationSystem.simulateRun({ seed = 79 })
  local transcript, transcriptError = ReplaySystem.buildTranscript(result.runState)
  assert(transcript, transcriptError)

  transcript.stages[1].loadout.canonicalKey = transcript.stages[1].loadout.canonicalKey .. "|tampered"

  local replay = ReplaySystem.replayTranscript(transcript)
  assert(not replay.ok)
  assert(replay.error == "invalid_transcript_schema")
end)

runCheck("transcript_trailing_stage_rejected", function()
  local result = SimulationSystem.simulateRun({ seed = 80 })
  local transcript, transcriptError = ReplaySystem.buildTranscript(result.runState)
  assert(transcript, transcriptError)

  table.insert(transcript.stages, Utils.clone(transcript.stages[#transcript.stages]))

  local replay = ReplaySystem.replayTranscript(transcript)
  assert(not replay.ok)
  assert(replay.error == "trailing_transcript_stages")
end)

runCheck("active_run_encounter_roundtrip", function()
  local result = SimulationSystem.simulateRun({ seed = 91 })
  local stageRecord = nil
  local stageHistoryIndex = nil

  for index, record in ipairs(result.runState.history.stageResults or {}) do
    if record.stageType == "normal" and record.status == "cleared" and record.runStatus == "active" then
      stageRecord = record
      stageHistoryIndex = index
      break
    end
  end

  assert(stageRecord ~= nil, "expected at least one active cleared normal stage")

  local runState = Utils.clone(result.runState)
  runState.roundIndex = stageRecord.roundIndex
  runState.runStatus = "active"
  runState.currentStageId = stageRecord.stageId
  runState.history.stageResults = {}

  for index = 1, stageHistoryIndex do
    table.insert(runState.history.stageResults, Utils.clone(result.runState.history.stageResults[index]))
  end

  local function keepStageScoped(entry)
    if not entry then
      return false
    end

    if entry.roundIndex == nil or entry.roundIndex < stageRecord.roundIndex then
      return true
    end

    if entry.roundIndex == stageRecord.roundIndex then
      return entry.stageId == stageRecord.stageId
    end

    return false
  end

  local function filterHistoryEntries(source)
    local filtered = {}

    for _, entry in ipairs(source or {}) do
      if keepStageScoped(entry) then
        table.insert(filtered, Utils.clone(entry))
      end
    end

    return filtered
  end

  runState.history.loadoutCommits = filterHistoryEntries(runState.history.loadoutCommits)
  runState.history.flipBatches = filterHistoryEntries(runState.history.flipBatches)
  runState.history.shopVisits = filterHistoryEntries(runState.history.shopVisits)
  local latestStageRecord = runState.history.stageResults[#runState.history.stageResults]
  local session = EncounterSystem.buildSession(runState)
  RunHistorySystem.recordStageEncounterPreview(latestStageRecord, session)
  local fakeFilesystem = {
    storage = {},
  }

  function fakeFilesystem.getInfo(path)
    if path == "save" then
      return { type = "directory" }
    end

    return fakeFilesystem.storage[path] and { type = "file" } or nil
  end

  function fakeFilesystem.createDirectory(_)
    return true
  end

  function fakeFilesystem.write(path, contents)
    fakeFilesystem.storage[path] = contents
    return true
  end

  function fakeFilesystem.read(path)
    if fakeFilesystem.storage[path] == nil then
      return nil, "not_found"
    end

    return fakeFilesystem.storage[path]
  end

  function fakeFilesystem.remove(path)
    fakeFilesystem.storage[path] = nil
    return true
  end

  local artifactOk, artifactError = SaveSystem.saveActiveRun({
    artifactType = SaveSystem.ACTIVE_RUN_ARTIFACT_TYPE,
    version = SaveSystem.ACTIVE_RUN_VERSION,
    currentState = "encounter",
    runState = runState,
    stageState = {
      stageId = latestStageRecord.stageId,
      stageLabel = latestStageRecord.stageLabel,
      stageType = latestStageRecord.stageType,
      variantId = latestStageRecord.variantId,
      variantName = latestStageRecord.variantName,
      targetScore = latestStageRecord.targetScore,
      stageScore = latestStageRecord.stageScore,
      flipsRemaining = 0,
      stageStatus = latestStageRecord.status,
      activeBossModifierIds = Utils.copyArray(latestStageRecord.bossModifierIds or {}),
      activeStageModifierIds = {},
      effectiveValues = {},
      resolvedValues = {},
      batchIndex = 0,
      streak = {},
      lastCall = nil,
      lastBatchResults = nil,
      flags = {},
    },
    runRngSeed = runState.seed,
    selectedCall = "heads",
    lastBatchResult = nil,
    lastStageResult = latestStageRecord,
    rewardPreviewSession = {
      options = {},
      selectedIndex = nil,
      choice = nil,
      claimed = true,
    },
    encounterSession = session,
    shopOffers = {},
    shopSession = nil,
    lastShopGenerationTrace = nil,
    lastShopPurchaseTrace = nil,
    currentStageDefinitionId = latestStageRecord.variantId or latestStageRecord.stageId,
    screenState = nil,
  }, fakeFilesystem)

  assert(artifactOk, artifactError)

  local artifact, loadError = SaveSystem.loadActiveRun(fakeFilesystem)
  assert(artifact, loadError)
  assert(artifact.currentState == "encounter")
  assert(artifact.encounterSession ~= nil)
  assert(artifact.encounterSession.encounterId == session.encounterId)
  assert(type(artifact.encounterSession.name) == "string" and artifact.encounterSession.name == session.name)
  assert(type(artifact.encounterSession.description) == "string" and artifact.encounterSession.description == session.description)
  assert(type(artifact.encounterSession.choices) == "table")
  assert(#artifact.encounterSession.choices == #session.choices)
  assert(artifact.encounterSession.selectedIndex == session.selectedIndex)
  assert(artifact.encounterSession.choice == nil)
  assert(artifact.encounterSession.claimed == false)
end)

print(string.format("Artifact verification: %d/%d passed", checksPassed, checksRun))

if #failures > 0 then
  for _, failure in ipairs(failures) do
    print("- " .. failure)
  end
  os.exit(1)
end
