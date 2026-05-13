local Utils = require("src.core.utils")

local GameConfig = {
  app = {
    title = "Coin-Flip Roguelike Prototype",
    version = "0.1.0",
  },

  debug = {
    logEnabled = false,
    overlayEnabled = false,
    maxLogEntries = 12,
    devControlsEnabled = false,
    postStageAnalyticsEnabled = true,
    grantShopPointsAmount = 5,
    fastSimBatchCount = 3,
  },

  ui = {
    width = 1280,
    height = 720,
    screenPadding = 24,
    lineHeight = 22,
    batchRevealDuration = 0.75,
    batchRevealEndDuration = 1.05,
  },

  audio = {
    enabled = true,
    masterVolume = 0.45,
    sampleRate = 22050,
    maxVoices = 8,
  },

  run = {
    normalRoundCount = 3,
    bossRoundCount = 1,
    startingCoinSlots = 3,
    startingFlipsPerStage = 3,
    startingCollectionSize = 5,
  },

  purse = {
    handSize = 5,
  },

  shop = {
    offerCount = 3,
    guaranteedCoinOffers = 1,
    guaranteedUpgradeOffers = 1,
    rerollCost = 1,
    rarityWeights = {
      common = 1.0,
      uncommon = 1.0,
      rare = 1.0,
    },
  },

  economy = {
    startingShopPoints = 0,
    startingShopRerolls = 0,
    shopPointMultiplier = 1.0,
    stageClearShopPoints = 3,
  },

  flip = {
    baseHeadsWeight = 0.5,
    baseTailsWeight = 0.5,
    orderMode = "unordered",
  },

  engine = {
    maxAppliedActionsPerBatch = 128,
    maxPendingActionDepth = 6,
  },

  simulation = {
    runCount = 25,
    baseSeed = 1001,
    seedStep = 1,
    maxBatchesPerStage = 12,
    maxShopActionsPerVisit = 4,
    maxRerollsPerVisit = 2,
  },

  analytics = {
    topItemCount = 5,
  },

  scoring = {
    clearOnThresholdAtBatchEnd = true,
  },
}

function GameConfig.get(path, defaultValue)
  local value = Utils.getPathValue(GameConfig, path)

  if value == nil then
    return defaultValue
  end

  return value
end

function GameConfig.totalStageCount()
  return GameConfig.run.normalRoundCount + GameConfig.run.bossRoundCount
end

return GameConfig
