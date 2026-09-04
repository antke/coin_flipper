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
    coinRevealMotionDuration = 0.176,
    coinRevealBaseHoldDuration = 0.096,
    coinRevealEffectHoldDuration = 0.128,
    coinRevealScoreHoldDuration = 0.056,
    coinRevealLinkDuration = 0.208,
    coinRevealSleightMoveDuration = 0.160,
    threeCupsRevealDuration = 1.48,
    opponentHpHitDuration = 0.68,
    trickCalloutStyle = "combo",
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
    startingFlipSlots = 3,
    startingCoinSlots = 3,
    startingFlipsPerStage = 3,
    startingCollectionSize = 5,
  },

  purse = {
    handSize = 5,
    replacementsPerEncounter = 3,
  },

  tricks = {
    activeCapacity = 5,
    maxActivationEventsPerFlip = 24,
  },

  shop = {
    offerCount = 3,
    guaranteedCoinOffers = 2,
    guaranteedUpgradeOffers = 0,
    rerollCost = 1,
    rarityWeights = {
      common = 0.50,
      uncommon = 0.35,
      rare = 0.15,
    },
  },

  economy = {
    startingInfluence = 0,
    startingShopPoints = 0,
    startingShopRerolls = 0,
    influenceMultiplier = 1.0,
    shopPointMultiplier = 1.0,
  },

  luck = {
    fatedFlipThreshold = 7,
    baseMatchGain = 1,
    generationMultiplier = 1.0,
    fatedFlipGeneratesLuck = false,
    fountainFavorByRarity = {
      common = 0.25,
      uncommon = 0.5,
      rare = 0.75,
    },
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
    policy = "strategic",
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
