local EnemySkills = require("src.content.enemy_skills")
local RNG = require("src.core.rng")
local Utils = require("src.core.utils")

local EnemySkillSystem = {}

local function activeTrickCount(runState)
  return #(runState and (runState.ownedTrickIds or runState.ownedUpgradeIds) or {})
end

local function slotCount(runState)
  return math.max(1, tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1)
end

local function seedParts(runState, stageState, suffix)
  return table.concat({
    tostring(runState and runState.seed or 1),
    tostring(stageState and stageState.stageId or "stage"),
    tostring(stageState and stageState.variantId or ""),
    "enemy_skill",
    tostring(suffix or "assignment"),
  }, ":")
end

local function baseState()
  return {
    revision = 1,
    skillId = nil,
    targetIndex = nil,
    intentIndex = 0,
    slotPressure = {},
  }
end

local function clearState(stageState, state)
  if not state then return end
  state.skillId = nil
  state.targetIndex = nil
  state.intentIndex = 0
  state.slotPressure = {}
  state.difficultyRank = nil
  state.minRound = nil
  state.surface = nil
  if stageState and stageState.trickBoard then
    stageState.trickBoard.pressure = {}
  end
end

function EnemySkillSystem.ensureState(stageState)
  if not stageState then return nil end
  stageState.enemySkill = stageState.enemySkill or baseState()
  stageState.enemySkill.revision = stageState.enemySkill.revision or 1
  stageState.enemySkill.slotPressure = stageState.enemySkill.slotPressure or {}
  return stageState.enemySkill
end

function EnemySkillSystem.getDefinition(stageStateOrId)
  local id = type(stageStateOrId) == "table"
    and stageStateOrId.enemySkill and stageStateOrId.enemySkill.skillId
    or stageStateOrId
  return EnemySkills.getById(id)
end

function EnemySkillSystem.isEligibleEncounter(stageState)
  return stageState ~= nil and stageState.stageType ~= "boss"
end

function EnemySkillSystem.assignSkill(runState, stageState, requestedSkillId)
  local state = EnemySkillSystem.ensureState(stageState)
  if not EnemySkillSystem.isEligibleEncounter(stageState) then
    clearState(stageState, state)
    return nil
  end

  local existing = EnemySkills.getById(state.skillId)
  local currentRound = math.max(1, tonumber(runState and runState.roundIndex) or 1)
  local existingIsCompatible = existing
    and existing.minRound <= currentRound
    and (existing.surface ~= "trick" or activeTrickCount(runState) > 0)
  if existingIsCompatible and requestedSkillId == nil then
    return existing
  end

  if existing and not existingIsCompatible then
    clearState(stageState, state)
  end

  local requested = requestedSkillId and EnemySkills.getById(requestedSkillId) or nil
  local definition = requested
  if not definition then
    local eligible = EnemySkills.getEligible(runState and runState.roundIndex, {
      hasActiveTricks = activeTrickCount(runState) > 0,
    })
    if #eligible == 0 then return nil end
    local rng = RNG.newFromText(seedParts(runState, stageState, "assignment"))
    definition = eligible[rng:nextInt(1, #eligible)]
  end

  state.skillId = definition.id
  state.targetIndex = nil
  state.intentIndex = 0
  state.slotPressure = {}
  state.difficultyRank = definition.difficultyRank
  state.minRound = definition.minRound
  state.surface = definition.surface
  return definition
end

function EnemySkillSystem.prepareIntent(runState, stageState, options)
  options = options or {}
  local state = EnemySkillSystem.ensureState(stageState)
  local definition = EnemySkillSystem.assignSkill(runState, stageState, options.skillId)
  stageState.trickBoard.pressure = {}
  state.slotPressure = {}
  state.targetIndex = nil

  if not definition then return nil end

  local intentIndex = math.max(1, tonumber(options.intentIndex)
    or ((tonumber(stageState.batchIndex) or 0) + 1))
  local targetLimit = definition.surface == "trick" and activeTrickCount(runState) or slotCount(runState)
  if targetLimit <= 0 then return nil end

  local targetIndex = tonumber(options.targetIndex)
  if not targetIndex or targetIndex < 1 or targetIndex > targetLimit then
    local rng = RNG.newFromText(seedParts(runState, stageState, table.concat({
      definition.id,
      tostring(intentIndex),
      "target",
    }, ":")))
    targetIndex = rng:nextInt(1, targetLimit)
  end

  local pressure = Utils.clone(definition.effect or {})
  pressure.skillId = definition.id
  pressure.skillName = definition.name
  pressure.description = definition.description
  pressure.surface = definition.surface
  pressure.difficultyRank = definition.difficultyRank
  pressure.minRound = definition.minRound
  pressure.sourceId = stageState.opponent and stageState.opponent.id or stageState.stageId
  pressure.telegraphed = true
  pressure.intentIndex = intentIndex

  state.targetIndex = targetIndex
  state.intentIndex = intentIndex
  state.surface = definition.surface
  state.difficultyRank = definition.difficultyRank
  state.minRound = definition.minRound

  if definition.surface == "trick" then
    stageState.trickBoard.pressure[targetIndex] = pressure
  else
    state.slotPressure[targetIndex] = pressure
  end

  stageState.trickBoard.revision = (stageState.trickBoard.revision or 0) + 1
  return EnemySkillSystem.snapshot(stageState)
end

function EnemySkillSystem.ensureIntent(runState, stageState)
  local state = EnemySkillSystem.ensureState(stageState)
  local definition = EnemySkillSystem.assignSkill(runState, stageState)
  if not definition then return nil end

  local targetIndex = tonumber(state.targetIndex)
  local targetLimit = definition.surface == "trick" and activeTrickCount(runState) or slotCount(runState)
  local pressure = definition.surface == "trick"
    and stageState.trickBoard.pressure[targetIndex]
    or state.slotPressure[targetIndex]
  local pressureIsCurrent = pressure
    and pressure.skillId == definition.id
    and pressure.surface == definition.surface

  if not targetIndex or targetIndex < 1 or targetIndex > targetLimit or not pressureIsCurrent then
    return EnemySkillSystem.prepareIntent(runState, stageState)
  end

  return EnemySkillSystem.snapshot(stageState)
end

function EnemySkillSystem.snapshot(stageState)
  local state = EnemySkillSystem.ensureState(stageState)
  local definition = EnemySkills.getById(state and state.skillId)
  return {
    revision = state and state.revision or 1,
    skillId = state and state.skillId or nil,
    name = definition and definition.name or nil,
    description = definition and definition.description or nil,
    surface = definition and definition.surface or state and state.surface or nil,
    difficultyRank = definition and definition.difficultyRank or state and state.difficultyRank or nil,
    minRound = definition and definition.minRound or state and state.minRound or nil,
    targetIndex = state and state.targetIndex or nil,
    intentIndex = state and state.intentIndex or 0,
    effect = definition and Utils.clone(definition.effect) or nil,
    slotPressure = Utils.clone(state and state.slotPressure or {}),
  }
end

function EnemySkillSystem.getSlotPressure(stageState, slotIndex)
  local state = stageState and stageState.enemySkill or nil
  return state and state.slotPressure and state.slotPressure[slotIndex] or nil
end

function EnemySkillSystem.getSnapshotSlotPressure(snapshot, slotIndex)
  return snapshot and snapshot.slotPressure and snapshot.slotPressure[slotIndex] or nil
end

function EnemySkillSystem.buildCoinScoreActions(context, coinState)
  local snapshot = context and context.enemySkillSnapshot or nil
  if not snapshot or snapshot.surface ~= "slot" then return {} end
  local pressure = EnemySkillSystem.getSnapshotSlotPressure(snapshot,
    coinState and (coinState.selectedSlotIndex or coinState.anchorSelectedSlotIndex))
  if not pressure or pressure.kind ~= "tarnished" then return {} end

  context.trace.enemySkillEffects = context.trace.enemySkillEffects or {}
  table.insert(context.trace.enemySkillEffects, {
    skillId = snapshot.skillId,
    kind = pressure.kind,
    targetIndex = snapshot.targetIndex,
    coinId = coinState.coinId,
    instanceId = coinState.instanceId,
    resolutionIndex = coinState.resolutionIndex,
    multiplier = pressure.multiplier,
  })
  return {
    {
      op = "apply_score_scaling",
      value = tonumber(pressure.multiplier) or 0.75,
      target = "current_coin_score",
      _trace = {
        phase = "before_coin_score",
        sourceId = snapshot.skillId,
        sourceType = "enemy_skill",
      },
    },
  }
end

function EnemySkillSystem.recordTrickActivation(context, source, activation)
  local snapshot = context and context.enemySkillSnapshot or nil
  if not snapshot or snapshot.skillId ~= "poisoned_charm" or snapshot.surface ~= "trick"
    or tonumber(source and source.boardPosition) ~= tonumber(snapshot.targetIndex) then
    return false
  end

  local activationId = activation and activation.activationId or "no_activation"
  local key = table.concat({ tostring(activationId), tostring(source.boardPosition) }, "|")
  context.enemySkillActivationKeys = context.enemySkillActivationKeys or {}
  if context.enemySkillActivationKeys[key] then return false end
  context.enemySkillActivationKeys[key] = true
  context.enemySkillActivationCount = (context.enemySkillActivationCount or 0) + 1
  context.trace.enemySkillEffects = context.trace.enemySkillEffects or {}
  table.insert(context.trace.enemySkillEffects, {
    skillId = snapshot.skillId,
    kind = "poison_stack",
    targetIndex = snapshot.targetIndex,
    activationId = activationId,
    trickId = source.sourceId,
    trickPosition = source.boardPosition,
    stack = context.enemySkillActivationCount,
  })
  return true
end

local function physicalSlotIndex(coinState)
  return coinState and (coinState.selectedSlotIndex or coinState.anchorSelectedSlotIndex) or nil
end

function EnemySkillSystem.buildAfterEffectsActions(context, stageState)
  local snapshot = context and context.enemySkillSnapshot or nil
  if not snapshot or not snapshot.skillId then return {} end

  local actions = {}
  if snapshot.skillId == "poisoned_charm" then
    local effect = snapshot.effect or {}
    local stacks = math.min(
      math.max(0, tonumber(context.enemySkillActivationCount) or 0),
      math.max(1, tonumber(effect.maxStacks) or 3)
    )
    local batchScore = math.max(0, (stageState.scoreAppliedToHp or 0) - (context.scoreAppliedToHpBefore or 0))
    local lossRate = math.min(1, stacks * (tonumber(effect.scoreLossPerActivation) or 0.10))
    local scoreLoss = math.min(batchScore, math.ceil((batchScore * lossRate) - 0.00001))
    if scoreLoss > 0 then
      table.insert(actions, {
        op = "add_stage_score",
        amount = -scoreLoss,
        category = "enemy_skill",
        label = "Poisoned Charm",
        poisonStacks = stacks,
        poisonRate = lossRate,
        _trace = {
          phase = "enemy_skill_resolution",
          sourceId = snapshot.skillId,
          sourceType = "enemy_skill",
        },
      })
    end
  elseif snapshot.skillId == "lifesteal_slot" then
    local effect = snapshot.effect or {}
    local matches = 0
    for _, coinState in ipairs(context.perCoin or {}) do
      if physicalSlotIndex(coinState) == snapshot.targetIndex
        and coinState.result == context.call
        and coinState.palmed ~= true then
        matches = matches + 1
      end
    end
    local healPerMatch = math.ceil((stageState.opponentHp or 0)
      * (tonumber(effect.healMaxHpOnMatch) or 0.05) - 0.00001)
    local healing = matches * math.max(0, healPerMatch)
    if healing > 0 then
      table.insert(actions, {
        op = "heal_opponent",
        amount = healing,
        category = "enemy_skill",
        label = "Leeching Slot",
        matchCount = matches,
        targetIndex = snapshot.targetIndex,
        _trace = {
          phase = "enemy_skill_resolution",
          sourceId = snapshot.skillId,
          sourceType = "enemy_skill",
        },
      })
    end
  end

  return actions
end

return EnemySkillSystem
