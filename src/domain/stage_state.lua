local Utils = require("src.core.utils")

local StageState = {}

function StageState.new(stageDefinition, runState, options)
  options = options or {}
  local activeBossModifierIds = {}

  if stageDefinition.bossModifierIds then
    for _, modifierId in ipairs(stageDefinition.bossModifierIds) do
      table.insert(activeBossModifierIds, modifierId)
    end
  elseif stageDefinition.bossModifierId then
    activeBossModifierIds = { stageDefinition.bossModifierId }
  end

  return {
    stageId = stageDefinition.id,
    stageLabel = stageDefinition.label,
    stageType = stageDefinition.stageType or "normal",
    variantId = stageDefinition.variantId,
    variantName = stageDefinition.variantName,
    targetScore = stageDefinition.targetScore or 0,
    stageScore = 0,
    flipsRemaining = math.max(1, tonumber(options.flipsPerStage) or runState.baseFlipsPerStage),
    stageStatus = "active",

    activeBossModifierIds = activeBossModifierIds,
    activeStageModifierIds = stageDefinition.activeStageModifierIds or {},
    effectiveValues = Utils.clone(stageDefinition.effectiveValues or {}),
    resolvedValues = Utils.clone(options.resolvedValues or {}),

    batchIndex = 0,
    streak = {
      consecutiveHeadsCalls = 0,
      consecutiveTailsCalls = 0,
      consecutiveMatches = 0,
      consecutiveMisses = 0,
    },

    lastCall = nil,
    lastBatchResults = nil,
    flags = {},
  }
end

return StageState
