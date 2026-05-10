local RewardSystem = require("src.systems.reward_system")
local RunHistorySystem = require("src.systems.run_history_system")

local Common = require("scripts.fixtures.engine.helpers.steps.common")

local RewardSteps = {}
local handlers = {}

local function buildRewardPreview(env)
  assert(env.runState, "reward preview requires run state")
  assert(env.stageRecord, "reward preview requires finalized stage record")

  env.rewardPreviewSession = RewardSystem.buildPreviewForStage(env.runState, env.stageRecord)
  RunHistorySystem.recordStageRewardPreview(env.stageRecord, env.rewardPreviewSession)
  Common.assertRuntime(env, "fixtures.build_reward_preview", { history = true })
  return env.rewardPreviewSession
end

local function claimRewardChoice(env, step)
  assert(env.runState, "reward claim requires run state")
  assert(env.stageRecord, "reward claim requires finalized stage record")

  local session = env.rewardPreviewSession or buildRewardPreview(env)
  local choiceIndex = step.index

  if choiceIndex == nil and #(session.options or {}) > 0 then
    choiceIndex = 1
  end

  if choiceIndex ~= nil then
    local ok, errorMessage = RewardSystem.selectOption(session, choiceIndex)
    assert(ok, errorMessage)
  end

  local ok, choiceOrError = RewardSystem.claimSelection(env.runState, session)
  assert(ok, choiceOrError)
  RunHistorySystem.recordStageRewardChoice(env.stageRecord, choiceOrError)
  Common.assertRuntime(env, "fixtures.claim_reward_choice", { history = true })
  return choiceOrError
end

handlers.build_reward_preview = buildRewardPreview
handlers.claim_reward_choice = claimRewardChoice

RewardSteps.handlers = handlers

return RewardSteps
