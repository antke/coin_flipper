local GameConfig = require("src.app.config")

local ProgressionSystem = {}

function ProgressionSystem.getTotalStageCount()
  return GameConfig.totalStageCount()
end

function ProgressionSystem.isBossRound(roundIndex)
  return roundIndex > GameConfig.get("run.normalRoundCount")
end

function ProgressionSystem.advanceToNextRound(runState)
  if runState.roundIndex >= ProgressionSystem.getTotalStageCount() then
    return false
  end

  runState.roundIndex = runState.roundIndex + 1
  return true
end

function ProgressionSystem.determineRunStatus(runState, stageState)
  if not runState or not stageState then
    return "active"
  end

  if stageState.stageStatus == "failed" then
    return "lost"
  end

  if stageState.stageStatus == "cleared" and stageState.stageType == "boss" and runState.roundIndex >= ProgressionSystem.getTotalStageCount() then
    return "won"
  end

  return "active"
end

return ProgressionSystem
