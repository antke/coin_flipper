local MetaProgressionContent = {
  runCompletionReward = {
    base = 1,
    runDamageDivisor = 12,
    bossClearBonus = 1,
    runWinBonus = 1,
    minimum = 1,
  },
}

function MetaProgressionContent.calculateRunReward(runState, stageRecord)
  local config = MetaProgressionContent.runCompletionReward
  local reward = config.base

  if runState then
    reward = reward + math.floor((runState.runTotalScore or 0) / config.runDamageDivisor)
  end

  if stageRecord and stageRecord.stageType == "boss" and stageRecord.status == "cleared" then
    reward = reward + config.bossClearBonus
  end

  if stageRecord and stageRecord.runStatus == "won" then
    reward = reward + config.runWinBonus
  end

  return math.max(config.minimum, reward)
end

return MetaProgressionContent
