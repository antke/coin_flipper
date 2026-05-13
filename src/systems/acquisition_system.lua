local Coins = require("src.content.coins")
local ActionQueue = require("src.core.action_queue")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local AcquisitionSystem = {}

function AcquisitionSystem.canGrantCoin(runState, coinId)
  local definition = Coins.getById(coinId)

  if not definition then
    return false, "unknown_coin"
  end

  return true, definition
end

function AcquisitionSystem.canGrantUpgrade(runState, upgradeId)
  local definition = Upgrades.getById(upgradeId)

  if not definition then
    return false, "unknown_upgrade"
  end

  if Utils.contains(runState.ownedUpgradeIds, upgradeId) then
    return false, "upgrade_already_owned"
  end

  return true, definition
end

function AcquisitionSystem.canGrantByType(runState, contentType, contentId)
  if contentType == "coin" then
    return AcquisitionSystem.canGrantCoin(runState, contentId)
  end

  if contentType == "upgrade" then
    return AcquisitionSystem.canGrantUpgrade(runState, contentId)
  end

  return false, "unknown_content_type"
end

function AcquisitionSystem.grantCoin(runState, coinId, context)
  local ok, definition = AcquisitionSystem.canGrantCoin(runState, coinId)

  if not ok then
    return false, definition, context
  end

  context = context or ActionQueue.createContext("grant_coin", {
    runState = runState,
  })
  ActionQueue.applyAll(runState, nil, context, {
    { op = "grant_coin", coinId = coinId },
  })

  return true, definition, context
end

function AcquisitionSystem.grantUpgrade(runState, upgradeId, context)
  local ok, definition = AcquisitionSystem.canGrantUpgrade(runState, upgradeId)

  if not ok then
    return false, definition, context
  end

  context = context or ActionQueue.createContext("grant_upgrade", {
    runState = runState,
  })
  ActionQueue.applyAll(runState, nil, context, {
    { op = "grant_upgrade", upgradeId = upgradeId },
  })

  return true, definition, context
end

return AcquisitionSystem
