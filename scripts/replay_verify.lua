package.path = "./?.lua;./?/init.lua;" .. package.path

local FlipResolver = require("src.systems.flip_resolver")
local LoadoutSystem = require("src.systems.loadout_system")
local MetaState = require("src.domain.meta_state")
local ReplaySystem = require("src.systems.replay_system")
local RNG = require("src.core.rng")
local RunHistorySystem = require("src.systems.run_history_system")
local RunInitializer = require("src.systems.run_initializer")
local SimulationSystem = require("src.systems.simulation_system")
local Utils = require("src.core.utils")

local function parseArg(index, defaultValue)
  return tonumber(arg[index]) or defaultValue
end

local runCount = parseArg(1, 5)
local baseSeed = parseArg(2, 1001)
local seedStep = parseArg(3, 1)
local passCount = 0
local failures = {}

local function buildTargetedQueueReplayRun(baseSeed)
  for offset = 0, 31 do
    local seed = baseSeed + offset
    local metaState = MetaState.new()
    local runState, metaProjection = RunInitializer.createNewRun(metaState, {
      seed = seed,
      starterCollection = { "weighted_shell" },
      ownedUpgradeIds = { "heads_varnish", "echo_cache", "reserve_fuse" },
    })
    local stageState = RunInitializer.createStageForCurrentRound(runState)
    local selection, errorMessage = LoadoutSystem.commitLoadout(runState, { [1] = "weighted_shell" })
    assert(selection, errorMessage)

    local rng = RNG.new(seed)
    local sawQueue = false
    local sawGrant = false
    local sawConsume = false

    while stageState.stageStatus == "active" do
      local batchResult, batchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, "heads", rng)
      assert(batchResult, batchError)
      table.insert(runState.history.flipBatches, Utils.clone(batchResult.batch))

      sawQueue = sawQueue or #(batchResult.trace.queuedActions or {}) > 0
      sawGrant = sawGrant or #(batchResult.trace.temporaryEffectsGranted or {}) > 0
      sawConsume = sawConsume or #(batchResult.trace.temporaryEffectsConsumed or {}) > 0
    end

    RunHistorySystem.finalizeStage(runState, stageState, metaState)

    if sawQueue and sawGrant and sawConsume then
      return seed, runState
    end
  end

  error("targeted_queue_effect_replay_scenario_not_found")
end

local function buildTargetedForcedReplayRun(seed)
  local metaState = MetaState.new()
  local runState, metaProjection = RunInitializer.createNewRun(metaState, {
    seed = seed,
    starterCollection = { "match_spark" },
  })
  local stageState = RunInitializer.createStageForCurrentRound(runState)
  local selection, errorMessage = LoadoutSystem.commitLoadout(runState, { [1] = "match_spark" })
  assert(selection, errorMessage)

  local rng = RNG.new(seed)
  table.insert(runState.pendingForcedCoinResults, "tails")

  local sawForced = false

  while stageState.stageStatus == "active" do
    local batchResult, batchError = FlipResolver.resolveBatch(runState, stageState, metaProjection, "heads", rng)
    assert(batchResult, batchError)
    table.insert(runState.history.flipBatches, Utils.clone(batchResult.batch))

    if #(batchResult.trace.forcedResults or {}) > 0 then
      sawForced = true
      assert(batchResult.trace.forcedResults[1].result == "tails", "forced result should be tails")
      assert(batchResult.batch.forcedResults[1].result == "tails", "batch forced result should be tails")
    end
  end

  RunHistorySystem.finalizeStage(runState, stageState, metaState)
  assert(sawForced, "forced-result replay scenario did not consume forced result")
  return seed, runState
end

for index = 1, runCount do
  local seed = baseSeed + ((index - 1) * seedStep)
  local ok, resultOrError = pcall(function()
    local result = SimulationSystem.simulateRun({ seed = seed })
    local transcript, transcriptError = ReplaySystem.buildTranscript(result.runState)

    if not transcript then
      error(transcriptError or "transcript_build_failed")
    end

    return ReplaySystem.replayTranscript(transcript)
  end)

  if not ok then
    table.insert(failures, string.format("seed %d replay crashed: %s", seed, tostring(resultOrError)))
  else
    if resultOrError.ok then
      passCount = passCount + 1
    else
      table.insert(failures, string.format("seed %d replay mismatch: %s", seed, table.concat(resultOrError.mismatches or {}, " | ")))
    end
  end
end

local targetedOk, targetedResult = pcall(function()
  local scenarioSeed, runState = buildTargetedQueueReplayRun(baseSeed + (runCount * seedStep) + 211)
  local transcript, transcriptError = ReplaySystem.buildTranscript(runState)
  assert(transcript, transcriptError)

  local sawDetailedSignature = false
  local sawSlotMetadata = false
  local sawSlotAwareTraceSignature = false
  for _, batchSignature in ipairs(transcript.expected.batchSignatures or {}) do
    if #(batchSignature.queuedActions or {}) > 0
      and #(batchSignature.temporaryEffectsGranted or {}) > 0
      and #(batchSignature.temporaryEffectsConsumed or {}) > 0 then
      sawDetailedSignature = true
    end

    for _, coinRoll in ipairs(batchSignature.coinRolls or {}) do
      if coinRoll.slotIndex ~= nil and coinRoll.resolutionIndex ~= nil then
        sawSlotAwareTraceSignature = true
        break
      end
    end

    if not sawSlotAwareTraceSignature then
      for _, source in ipairs(batchSignature.triggeredSources or {}) do
        if source.slotIndex ~= nil and source.resolutionIndex ~= nil then
          sawSlotAwareTraceSignature = true
          break
        end
      end
    end

    if not sawSlotAwareTraceSignature then
      for _, action in ipairs(batchSignature.actions or {}) do
        if (action.slotIndex ~= nil and action.resolutionIndex ~= nil)
          or (action.trace and action.trace.slotIndex ~= nil and action.trace.resolutionIndex ~= nil) then
          sawSlotAwareTraceSignature = true
          break
        end
      end
    end
  end

  for _, stageEntry in ipairs(transcript.stages or {}) do
    for _, batchEntry in ipairs(stageEntry.batches or {}) do
      local resolutionEntries = batchEntry.resolutionEntries or {}

      if #resolutionEntries > 0 then
        local firstEntry = resolutionEntries[1]

        if firstEntry and firstEntry.slotIndex ~= nil and firstEntry.resolutionIndex ~= nil then
          sawSlotMetadata = true
          break
        end
      end
    end

    if sawSlotMetadata then
      break
    end
  end

  assert(sawDetailedSignature, "targeted transcript missing queued action / temporary effect trace signature")
  assert(sawSlotMetadata, "targeted transcript missing slot-aware resolution metadata")
  assert(sawSlotAwareTraceSignature, "targeted transcript missing slot-aware trace/action signature")

  local replay = ReplaySystem.replayTranscript(transcript)
  assert(replay.ok, table.concat(replay.mismatches or {}, " | "))

  return scenarioSeed
end)

if targetedOk then
  passCount = passCount + 1
  runCount = runCount + 1
else
  table.insert(failures, string.format("targeted replay scenario failed: %s", tostring(targetedResult)))
  runCount = runCount + 1
end

local forcedOk, forcedResult = pcall(function()
  local scenarioSeed, runState = buildTargetedForcedReplayRun(baseSeed + (runCount * seedStep) + 307)
  local transcript, transcriptError = ReplaySystem.buildTranscript(runState)
  assert(transcript, transcriptError)

  local sawForcedSignature = false
  for _, batchSignature in ipairs(transcript.expected.batchSignatures or {}) do
    if #(batchSignature.forcedResults or {}) > 0 then
      sawForcedSignature = true
      break
    end
  end

  assert(sawForcedSignature, "targeted transcript missing forced-result signature")

  local replay = ReplaySystem.replayTranscript(transcript)
  assert(replay.ok, table.concat(replay.mismatches or {}, " | "))

  return scenarioSeed
end)

if forcedOk then
  passCount = passCount + 1
  runCount = runCount + 1
else
  table.insert(failures, string.format("targeted forced-result scenario failed: %s", tostring(forcedResult)))
  runCount = runCount + 1
end

print(string.format("Replay verification: %d/%d passed", passCount, runCount))

if #failures > 0 then
  for _, failure in ipairs(failures) do
    print("- " .. failure)
  end
  os.exit(1)
end
