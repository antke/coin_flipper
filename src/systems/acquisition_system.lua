local Coins = require("src.content.coins")
local ActionQueue = require("src.core.action_queue")
local Upgrades = require("src.content.upgrades")
local TrickBoardSystem = require("src.systems.trick_board_system")

local AcquisitionSystem = {}

local function isTrickType(contentType)
  return contentType == "trick" or contentType == "upgrade"
end

function AcquisitionSystem.canGrantCoin(runState, coinId)
  local definition = Coins.getById(coinId)

  if not definition then
    return false, "unknown_coin"
  end

  return true, definition
end

function AcquisitionSystem.canGrantUpgrade(runState, upgradeId)
  runState.ownedTrickIds = runState.ownedTrickIds or runState.ownedUpgradeIds or {}
  runState.ownedUpgradeIds = runState.ownedTrickIds

  local definition = Upgrades.getById(upgradeId)
  if not definition then return false, "unknown_upgrade" end

  local ok, result = TrickBoardSystem.canAcquire(runState, upgradeId)
  if ok then return true, definition, result end
  if type(result) == "table" and result.code == "trick_board_full" then
    return true, definition, result
  end
  return false, result
end

function AcquisitionSystem.canGrantByType(runState, contentType, contentId)
  if contentType == "coin" then
    return AcquisitionSystem.canGrantCoin(runState, contentId)
  end

  if isTrickType(contentType) then
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

function AcquisitionSystem.grantUpgrade(runState, upgradeId, context, options)
  local ok, definition = AcquisitionSystem.canGrantUpgrade(runState, upgradeId)

  if not ok then
    return false, definition, context
  end

  context = context or ActionQueue.createContext("grant_trick", {
    runState = runState,
  })
  local action = { op = "grant_trick", trickId = upgradeId, replacePosition = options and options.replacePosition }
  ActionQueue.applyAll(runState, nil, context, { action })
  if action.skipped then
    return false, action.replacementRequired or action.skipReason, context
  end

  return true, definition, context
end

function AcquisitionSystem.grantTrick(runState, trickId, context, options)
  return AcquisitionSystem.grantUpgrade(runState, trickId, context, options)
end

return AcquisitionSystem
