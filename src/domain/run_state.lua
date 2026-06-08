local Loadout = require("src.domain.loadout")
local GameConfig = require("src.app.config")
local PurseSystem = require("src.systems.purse_system")
local Utils = require("src.core.utils")

local RunState = {}

local RUN_STATE_ALIASES = {
  equippedCoinSlots = "flipSlots",
  maxActiveCoinSlots = "maxFlipSlots",
  persistedLoadoutSlots = "persistedFlipSlots",
  shopPoints = "influence",
}

local RUN_STATE_METATABLE = {
  __index = function(runState, key)
    local canonicalKey = RUN_STATE_ALIASES[key]

    if canonicalKey then
      return rawget(runState, canonicalKey)
    end

    return nil
  end,
  __newindex = function(runState, key, value)
    local canonicalKey = RUN_STATE_ALIASES[key]

    if canonicalKey then
      rawset(runState, canonicalKey, value)
      return
    end

    rawset(runState, key, value)
  end,
}

function RunState.new(options)
  options = options or {}
  local maxFlipSlots = math.max(1, tonumber(options.maxFlipSlots or options.maxActiveCoinSlots) or 1)
  local ownedTrickIds = Utils.copyArray(options.ownedTrickIds or options.ownedUpgradeIds or {})
  local unlockedTrickIds = Utils.copyArray(options.unlockedTrickIds or options.unlockedUpgradeIds or {})
  local flipSlots = options.flipSlots or options.equippedCoinSlots
  local persistedFlipSlots = options.persistedFlipSlots or options.persistedLoadoutSlots
  local startingInfluence = options.startingInfluence

  if startingInfluence == nil then
    startingInfluence = options.startingShopPoints
  end

  local runState = {
    seed = options.seed or 1,
    roundIndex = 1,
    currentStageId = nil,
    runStatus = "active",

    collectionCoinIds = Utils.copyArray(options.starterCollection or {}),
    coinInstances = {},
    flipSlots = Loadout.normalizeSlots(flipSlots, maxFlipSlots),
    persistedFlipSlots = Loadout.normalizeSlots(persistedFlipSlots, maxFlipSlots),
    ownedTrickIds = ownedTrickIds,
    ownedUpgradeIds = ownedTrickIds,
    unlockedCoinIds = Utils.copyArray(options.unlockedCoinIds or {}),
    unlockedTrickIds = unlockedTrickIds,
    unlockedUpgradeIds = unlockedTrickIds,

    metaProjection = Utils.clone(options.metaProjection),
    maxFlipSlots = maxFlipSlots,
    baseFlipsPerStage = math.max(1, tonumber(options.baseFlipsPerStage) or 1),
    resolvedValues = Utils.clone(options.resolvedValues or {}),

    influence = math.max(0, tonumber(startingInfluence) or 0),
    shopRerollsRemaining = math.max(0, tonumber(options.startingShopRerolls) or 0),
    runTotalScore = 0,
    luck = {
      value = 0,
      max = math.max(1, tonumber(GameConfig.get("luck.fatedFlipThreshold", 12)) or 12),
      fatedFlipActive = false,
      fatedFlipGeneratesLuck = GameConfig.get("luck.fatedFlipGeneratesLuck", false) == true,
      fountainFavor = 0,
    },
    metaRewardEarned = 0,
    metaRewardGranted = false,
    runStartRecorded = false,
    runRecordSaved = options.runRecordSaved == true,

    history = {
      loadoutCommits = {},
      stageResults = {},
      purchases = {},
      shopVisits = {},
      flipBatches = {},
    },

    counters = {
      totalFlips = 0,
      totalMatches = 0,
      totalMisses = 0,
      headsCalls = 0,
      tailsCalls = 0,
      temporaryEffectInstances = 0,
      coinInstancesCreated = 0,
      totalSleights = 0,
    },

    flags = {},
    temporaryRunEffects = {},
    pendingForcedCoinResults = {},
  }

  PurseSystem.createInstancesFromDefinitionIds(runState, options.starterPurse or options.starterCollection or {})

  return setmetatable(runState, RUN_STATE_METATABLE)
end

return RunState
