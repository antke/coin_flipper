package.path = "./?.lua;./?/init.lua;" .. package.path

local MetaState = require("src.domain.meta_state")
local ReplaySystem = require("src.systems.replay_system")
local SaveSystem = require("src.systems.save_system")
local SimulationSystem = require("src.systems.simulation_system")
local Utils = require("src.core.utils")

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

print(string.format("Artifact verification: %d/%d passed", checksPassed, checksRun))

if #failures > 0 then
  for _, failure in ipairs(failures) do
    print("- " .. failure)
  end
  os.exit(1)
end
