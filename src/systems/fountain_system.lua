local Coins = require("src.content.coins")
local GameConfig = require("src.app.config")
local LuckSystem = require("src.systems.luck_system")
local PurseSystem = require("src.systems.purse_system")

local FountainSystem = {}

local function getFavorForRarity(rarity)
  local values = GameConfig.get("luck.fountainFavorByRarity", {}) or {}
  return math.max(0, tonumber(values[rarity or "common"] or values.common or 0.25) or 0.25)
end

local function formatFavor(amount)
  return LuckSystem.formatAmount(amount)
end

function FountainSystem.buildSession(runState, lastStageResult)
  return {
    sourceStageId = lastStageResult and lastStageResult.stageId or nil,
    roundIndex = lastStageResult and lastStageResult.roundIndex or (runState and runState.roundIndex or nil),
    sacrificed = false,
    selectedInstanceId = nil,
    sacrificedInstanceId = nil,
    sacrificedCoinId = nil,
    favorGained = 0,
    message = "Sacrifice up to one coin for permanent Fountain Favor.",
  }
end

function FountainSystem.getOptions(runState)
  local options = {}
  local canSacrifice = #(runState and runState.coinInstances or {}) > 1

  for _, instance in ipairs(runState and runState.coinInstances or {}) do
    local definition = Coins.getById(instance.definitionId)

    if definition then
      table.insert(options, {
        instanceId = instance.instanceId,
        coinId = instance.definitionId,
        name = definition.name,
        rarity = definition.rarity or "common",
        description = definition.description,
        favor = getFavorForRarity(definition.rarity),
        disabled = not canSacrifice,
        disabledReason = canSacrifice and nil or "last_coin_required",
      })
    end
  end

  return options
end

function FountainSystem.sacrifice(runState, stageState, session, instanceId)
  if not runState then
    return false, "run_not_initialized"
  end

  if not session then
    return false, "fountain_not_prepared"
  end

  if session.sacrificed == true then
    return false, "fountain_already_used"
  end

  if type(instanceId) ~= "string" or instanceId == "" then
    return false, "coin_required"
  end

  local instance = PurseSystem.getInstance(runState, instanceId)
  if not instance then
    return false, "coin_not_found"
  end

  local definition = Coins.getById(instance.definitionId)
  if not definition then
    return false, "coin_not_found"
  end

  local favor = getFavorForRarity(definition.rarity)
  local removed, result = PurseSystem.removeInstance(runState, stageState, instanceId)

  if not removed then
    return false, result
  end

  LuckSystem.addFountainFavor(runState, favor)

  session.sacrificed = true
  session.selectedInstanceId = nil
  session.sacrificedInstanceId = instanceId
  session.sacrificedCoinId = definition.id
  session.favorGained = favor
  session.message = string.format("Sacrificed %s for +%s Fountain Favor.", definition.name, formatFavor(favor))

  return true, {
    instanceId = instanceId,
    coinId = definition.id,
    name = definition.name,
    rarity = definition.rarity,
    favorGained = favor,
    removal = result,
  }
end

return FountainSystem
