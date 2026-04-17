local Loadout = require("src.domain.loadout")
local Utils = require("src.core.utils")

local RunState = {}

function RunState.new(options)
  options = options or {}
  local maxActiveCoinSlots = math.max(1, tonumber(options.maxActiveCoinSlots) or 1)

  return {
    seed = options.seed or 1,
    roundIndex = 1,
    currentStageId = nil,
    runStatus = "active",

    collectionCoinIds = Utils.copyArray(options.starterCollection or {}),
    equippedCoinSlots = Loadout.normalizeSlots(options.equippedCoinSlots, maxActiveCoinSlots),
    persistedLoadoutSlots = Loadout.normalizeSlots(options.persistedLoadoutSlots, maxActiveCoinSlots),
    ownedUpgradeIds = Utils.copyArray(options.ownedUpgradeIds or {}),
    unlockedCoinIds = Utils.copyArray(options.unlockedCoinIds or {}),
    unlockedUpgradeIds = Utils.copyArray(options.unlockedUpgradeIds or {}),

    metaProjection = Utils.clone(options.metaProjection),
    maxActiveCoinSlots = maxActiveCoinSlots,
    baseFlipsPerStage = math.max(1, tonumber(options.baseFlipsPerStage) or 1),
    resolvedValues = Utils.clone(options.resolvedValues or {}),

    shopPoints = math.max(0, tonumber(options.startingShopPoints) or 0),
    shopRerollsRemaining = math.max(0, tonumber(options.startingShopRerolls) or 0),
    runTotalScore = 0,
    metaRewardEarned = 0,
    metaRewardGranted = false,
    runStartRecorded = false,

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
    },

    flags = {},
    temporaryRunEffects = {},
    pendingForcedCoinResults = {},
  }
end

return RunState
