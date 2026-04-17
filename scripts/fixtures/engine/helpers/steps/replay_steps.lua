local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local ReplaySteps = {}
local handlers = {}

local function buildTranscript(env)
  local transcript, errorMessage = ReplaySystem.buildTranscript(env.runState)
  assert(transcript, errorMessage)
  env.transcript = transcript
  return transcript
end

local function replayTranscript(env, step)
  local replay = ReplaySystem.replayTranscript(step.transcript or env.transcript)

  if step.expectOk == false then
    assert(not replay.ok, "expected replay failure")
  else
    assert(replay.ok, Utils.joinNonNil(replay.mismatches or {}, " | "))
  end

  env.replay = replay
  return replay
end

handlers.build_transcript = buildTranscript
handlers.replay_transcript = replayTranscript

ReplaySteps.handlers = handlers

return ReplaySteps
