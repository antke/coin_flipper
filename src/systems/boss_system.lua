local BossSystem = {}

function BossSystem.describeBoss(stageState)
  if not stageState or stageState.stageType ~= "boss" then
    return nil
  end

  return stageState.activeBossModifierIds or {}
end

return BossSystem
