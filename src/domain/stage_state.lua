local Utils = require("src.core.utils")
local PurseSystem = require("src.systems.purse_system")
local PredictionSlotSystem = require("src.systems.prediction_slot_system")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local BossTrickSystem = require("src.systems.boss_trick_system")
local GameConfig = require("src.app.config")

local StageState = {}

local STAGE_STATE_ALIASES = {
  stageScore = "scoreAppliedToHp",
  targetScore = "opponentHp",
}

local STAGE_STATE_METATABLE = {
  __index = function(stageState, key)
    local canonicalKey = STAGE_STATE_ALIASES[key]

    if canonicalKey then
      return rawget(stageState, canonicalKey)
    end

    return nil
  end,
  __newindex = function(stageState, key, value)
    local canonicalKey = STAGE_STATE_ALIASES[key]

    if canonicalKey then
      rawset(stageState, canonicalKey, value)
      return
    end

    rawset(stageState, key, value)
  end,
}

function StageState.new(stageDefinition, runState, options)
  options = options or {}
  local activeBossModifierIds = {}
  local opponent = Utils.clone(stageDefinition.opponent or {})
  opponent.id = opponent.id or (stageDefinition.id .. "_opponent")
  opponent.name = opponent.name or stageDefinition.name or stageDefinition.label or "Opponent"
  opponent.description = opponent.description or "Defeat this opponent with your coin flips."
  opponent.hp = opponent.hp or stageDefinition.opponentHp or stageDefinition.targetScore or 0

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
    opponentHp = opponent.hp,
    scoreAppliedToHp = 0,
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
    trickBoard = {
      phase = "setup",
      revision = 1,
      pressure = {},
      replacementsRemaining = math.max(0, tonumber(options.replacementsPerEncounter)
        or GameConfig.get("purse.replacementsPerEncounter", 3)),
      replacementHistory = {},
    },
    enemySkill = {
      revision = 1,
      skillId = nil,
      targetIndex = nil,
      intentIndex = 0,
      slotPressure = {},
    },
    bossTrick = {
      revision = 1,
      bossId = nil,
      trickId = nil,
      favouriteSide = nil,
      spotlightSlotIndex = nil,
      leadSlotIndex = nil,
      victimSlotIndex = nil,
      impostorSlotIndex = nil,
      shuffleSeed = nil,
      offTheBooksSlotIndex = nil,
      writtenSlotResults = nil,
      intentIndex = 0,
      rngRoll = nil,
    },
  }

  PurseSystem.initializeStagePurse(runState, stageState)
  PredictionSlotSystem.ensure(runState, stageState)
  EnemySkillSystem.ensureState(stageState)
  BossTrickSystem.ensureState(stageState)

  return setmetatable(stageState, STAGE_STATE_METATABLE)
end

return StageState
