local Utils = require("src.core.utils")
local PurseSystem = require("src.systems.purse_system")

local StageState = {}

function StageState.new(stageDefinition, runState, options)
  options = options or {}
  local activeBossModifierIds = {}
  local opponent = Utils.clone(stageDefinition.opponent or {})
  opponent.id = opponent.id or (stageDefinition.id .. "_opponent")
  opponent.name = opponent.name or stageDefinition.name or stageDefinition.label or "Opponent"
  opponent.description = opponent.description or "Defeat this opponent with your coin flips."
  opponent.hp = opponent.hp or stageDefinition.targetScore or 0

  if stageDefinition.bossModifierIds then
    for _, modifierId in ipairs(stageDefinition.bossModifierIds) do
      table.insert(activeBossModifierIds, modifierId)
    end
  elseif stageDefinition.bossModifierId then
    activeBossModifierIds = { stageDefinition.bossModifierId }
  end

  local stageState = {
    stageId = stageDefinition.id,
    stageLabel = stageDefinition.label,
    stageType = stageDefinition.stageType or "normal",
    variantId = stageDefinition.variantId,
    variantName = stageDefinition.variantName,
    opponent = opponent,
    targetScore = opponent.hp,
    stageScore = 0,
    flipsRemaining = math.max(1, tonumber(options.flipsPerStage) or runState.baseFlipsPerStage),
    stageStatus = "active",

    activeBossModifierIds = activeBossModifierIds,
    activeStageModifierIds = stageDefinition.activeStageModifierIds or {},
    effectiveValues = Utils.clone(stageDefinition.effectiveValues or {}),
    resolvedValues = Utils.clone(options.resolvedValues or {}),

    batchIndex = 0,

    lastCall = nil,
    lastBatchResults = nil,
    flags = {},
  }

  PurseSystem.initializeStagePurse(runState, stageState)

  return stageState
end

return StageState
