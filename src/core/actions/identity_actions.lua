local CoinTraits = require("src.core.coin_traits")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local IdentityActions = {}

local IDENTITY_OPS = {
  forge_identity = true,
  redirect_score_credit = true,
  swap_coins = true,
}

local function recordWarning(options, context, message)
  if options and options.recordWarning then
    options.recordWarning(context, message)
  end
end

local function claimOnce(options, context, action, defaultKey, warning)
  if options and options.claimOnce then
    local key = defaultKey

    if options.getOnceKey then
      key = options.getOnceKey(action, defaultKey)
    elseif type(action.onceKey) == "string" and action.onceKey ~= "" then
      key = action.onceKey
    end

    return options.claimOnce(context, key, warning)
  end

  return true
end

local function findByResolutionIndex(entries, resolutionIndex)
  for _, entry in ipairs(entries or {}) do
    if entry.resolutionIndex == resolutionIndex then
      return entry
    end
  end

  return nil
end

local function contextWithFields(context, fields)
  return setmetatable(fields or {}, { __index = context })
end

local function findSlotOneSource(context)
  if context.currentCoin and context.currentCoin.selectedSlotIndex == 1 then
    return context.currentCoin
  end

  for _, coinState in ipairs(context.perCoin or {}) do
    if coinState.selectedSlotIndex == 1 then
      return coinState
    end
  end

  return context.currentCoin
end

local function chooseBorrowedNameTarget(context, source, family)
  local target = nil
  local targetBaseScore = nil
  local specializedTarget = nil
  local specializedTargetBaseScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local isSource = source and coinState.instanceId == source.instanceId
    local isSelected = coinState.selectedSlotIndex ~= nil
    local isFailure = coinState.result ~= context.call

    if isSelected and isFailure and not isSource then
      local baseScore = CoinTraits.baseScore(coinState.coinId)

      if target == nil or baseScore < targetBaseScore then
        target = coinState
        targetBaseScore = baseScore
      end

      if CoinTraits.hasFamily(coinState.coinId, family)
        and (specializedTarget == nil or baseScore < specializedTargetBaseScore) then
        specializedTarget = coinState
        specializedTargetBaseScore = baseScore
      end
    end
  end

  return specializedTarget or target
end

local function applyForgeIdentity(context, action, options)
  local source = nil

  if type(action.target) == "table" and type(action.target.source) == "table" then
    source = TargetSelectors.resolveSlot(nil, nil, action.target.source, context)
  else
    source = findSlotOneSource(context)
  end

  if not source then
    recordWarning(options, context, "forge_identity ignored without a slot 1 source coin.")
    return
  end

  local target = nil

  if type(action.target) == "table" and type(action.target.target) == "table" then
    target = TargetSelectors.resolveSlot(nil, nil, action.target.target, context)
  else
    target = chooseBorrowedNameTarget(context, source, action.specializedFamily)
  end

  if not target then
    recordWarning(options, context, "forge_identity had no eligible failed selected coin.")
    return
  end

  local sourceId = action._trace and action._trace.sourceId or nil
  local originalCoinId = target.coinId
  local overlay = {
    mode = "replace_identity",
    scope = "one_payout_only",
    sourceId = sourceId,
    sourceCoinId = source.coinId,
    sourceInstanceId = source.instanceId,
    sourceSlotIndex = source.slotIndex,
    sourceResolutionIndex = source.resolutionIndex,
    targetCoinId = originalCoinId,
    targetInstanceId = target.instanceId,
    targetSlotIndex = target.slotIndex,
    targetResolutionIndex = target.resolutionIndex,
    forgedCoinId = source.coinId,
  }

  target.forged = true
  target.forgedBy = sourceId
  target.forgedIdentity = Utils.clone(overlay)
  target.forgedCoinId = source.coinId
  target.identitySourceCoinId = source.coinId
  target.identitySourceInstanceId = source.instanceId
  target.scoringCoinId = source.coinId

  local targetRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, target.resolutionIndex)
  if targetRoll then
    targetRoll.forged = true
    targetRoll.forgedBy = sourceId
    targetRoll.forgedCoinId = source.coinId
    targetRoll.identitySourceCoinId = source.coinId
    targetRoll.identitySourceInstanceId = source.instanceId
  end

  action.coinId = target.coinId
  action.instanceId = target.instanceId
  action.slotIndex = target.slotIndex
  action.selectedSlotIndex = target.selectedSlotIndex
  action.dealtIndex = target.dealtIndex
  action.boardSlotIndex = target.boardSlotIndex
  action.overloadSlotIndex = target.overloadSlotIndex
  action.resolutionIndex = target.resolutionIndex
  action.targetCoinId = target.coinId
  action.targetInstanceId = target.instanceId
  action.targetSlotIndex = target.slotIndex
  action.targetResolutionIndex = target.resolutionIndex
  action.sourceCoinId = source.coinId
  action.sourceInstanceId = source.instanceId
  action.sourceSlotIndex = source.slotIndex
  action.sourceResolutionIndex = source.resolutionIndex
  action.forged = true
  action.forgedBy = sourceId
  action.forgedCoinId = source.coinId
  action.identitySourceCoinId = source.coinId
  action.identitySourceInstanceId = source.instanceId
  action.forgeMode = overlay.mode
  action.forgeScope = overlay.scope

  context.trace.forgedIdentities = context.trace.forgedIdentities or {}
  table.insert(context.trace.forgedIdentities, overlay)
end

local function chooseCrookedSpotlightPair(context)
  local spotlight = nil
  local spotlightScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local isSelected = coinState.selectedSlotIndex ~= nil
    local didMatch = coinState.result == context.call

    if isSelected and didMatch then
      local baseScore = CoinTraits.baseScore(coinState.scoringCoinId or coinState.forgedCoinId or coinState.coinId)

      if spotlight == nil or baseScore > spotlightScore then
        spotlight = coinState
        spotlightScore = baseScore
      end
    end
  end

  if not spotlight then
    return nil, nil
  end

  local source = nil
  local sourceScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local isSelected = coinState.selectedSlotIndex ~= nil
    local didMatch = coinState.result == context.call
    local isSpotlight = coinState.resolutionIndex == spotlight.resolutionIndex

    if isSelected and didMatch and not isSpotlight and coinState.redirectedCredit ~= true then
      local baseScore = CoinTraits.baseScore(coinState.scoringCoinId or coinState.forgedCoinId or coinState.coinId)

      if source == nil or baseScore < sourceScore then
        source = coinState
        sourceScore = baseScore
      end
    end
  end

  return source, spotlight
end

local function applyScoreCreditRedirectToRoll(roll, source, spotlight, sourceId)
  if not roll then
    return
  end

  if roll.resolutionIndex == spotlight.resolutionIndex then
    roll.spotlight = true
    roll.spotlightBy = sourceId
  end

  if roll.resolutionIndex == source.resolutionIndex then
    roll.redirectedCredit = true
    roll.redirectedCreditBy = sourceId
    roll.redirectedCreditTargetCoinId = spotlight.coinId
    roll.redirectedCreditTargetInstanceId = spotlight.instanceId
    roll.redirectedCreditTargetSlotIndex = spotlight.slotIndex
    roll.redirectedCreditTargetResolutionIndex = spotlight.resolutionIndex
    roll.spotlightCoinId = spotlight.coinId
    roll.spotlightInstanceId = spotlight.instanceId
  end
end

local function applyRedirectScoreCredit(context, action, options)
  local source = nil
  local spotlight = nil

  if type(action.target) == "table" then
    spotlight = TargetSelectors.resolveSlot(nil, nil, action.target.target, context)
    source = TargetSelectors.resolveSlot(nil, nil, action.target.source, contextWithFields(context, {
      selectorExcludedInstanceId = spotlight and spotlight.instanceId or nil,
    }))
  else
    source, spotlight = chooseCrookedSpotlightPair(context)
  end

  if not spotlight or not source then
    recordWarning(options, context, "redirect_score_credit had no eligible successful source and Spotlight pair.")
    return
  end

  if not claimOnce(
    options,
    context,
    action,
    "redirect_score_credit",
    "redirect_score_credit ignored because a redirect already resolved this flip."
  ) then
    return
  end

  local sourceId = action._trace and action._trace.sourceId or nil

  spotlight.spotlight = true
  spotlight.spotlightBy = sourceId
  spotlight.spotlightRedirectCount = (spotlight.spotlightRedirectCount or 0) + 1

  source.redirectedCredit = true
  source.redirectedCreditBy = sourceId
  source.redirectedCreditTargetCoinId = spotlight.coinId
  source.redirectedCreditTargetInstanceId = spotlight.instanceId
  source.redirectedCreditTargetSlotIndex = spotlight.slotIndex
  source.redirectedCreditTargetSelectedSlotIndex = spotlight.selectedSlotIndex
  source.redirectedCreditTargetDealtIndex = spotlight.dealtIndex
  source.redirectedCreditTargetBoardSlotIndex = spotlight.boardSlotIndex
  source.redirectedCreditTargetOverloadSlotIndex = spotlight.overloadSlotIndex
  source.redirectedCreditTargetResolutionIndex = spotlight.resolutionIndex
  source.scoreCreditCoinId = spotlight.coinId
  source.scoreCreditInstanceId = spotlight.instanceId
  source.scoreCreditSlotIndex = spotlight.slotIndex
  source.scoreCreditSelectedSlotIndex = spotlight.selectedSlotIndex
  source.scoreCreditDealtIndex = spotlight.dealtIndex
  source.scoreCreditBoardSlotIndex = spotlight.boardSlotIndex
  source.scoreCreditOverloadSlotIndex = spotlight.overloadSlotIndex
  source.scoreCreditResolutionIndex = spotlight.resolutionIndex

  local sourceRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, source.resolutionIndex)
  local spotlightRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, spotlight.resolutionIndex)
  applyScoreCreditRedirectToRoll(sourceRoll, source, spotlight, sourceId)
  applyScoreCreditRedirectToRoll(spotlightRoll, source, spotlight, sourceId)

  action.coinId = source.coinId
  action.instanceId = source.instanceId
  action.slotIndex = source.slotIndex
  action.selectedSlotIndex = source.selectedSlotIndex
  action.dealtIndex = source.dealtIndex
  action.boardSlotIndex = source.boardSlotIndex
  action.overloadSlotIndex = source.overloadSlotIndex
  action.resolutionIndex = source.resolutionIndex
  action.sourceCoinId = source.coinId
  action.sourceInstanceId = source.instanceId
  action.sourceSlotIndex = source.slotIndex
  action.sourceResolutionIndex = source.resolutionIndex
  action.targetCoinId = spotlight.coinId
  action.targetInstanceId = spotlight.instanceId
  action.targetSlotIndex = spotlight.slotIndex
  action.targetResolutionIndex = spotlight.resolutionIndex
  action.spotlightCoinId = spotlight.coinId
  action.spotlightInstanceId = spotlight.instanceId
  action.spotlightSlotIndex = spotlight.slotIndex
  action.spotlightResolutionIndex = spotlight.resolutionIndex
  action.scoreCreditCoinId = spotlight.coinId
  action.scoreCreditInstanceId = spotlight.instanceId
  action.scoreCreditSlotIndex = spotlight.slotIndex
  action.scoreCreditResolutionIndex = spotlight.resolutionIndex
  action.redirectedCredit = true
  action.redirectedCreditBy = sourceId
  action.redirectMode = "score_credit"
  action.redirectScope = "one_redirect_only"

  local redirect = {
    mode = "score_credit",
    scope = "one_redirect_only",
    sourceId = sourceId,
    sourceCoinId = source.coinId,
    sourceInstanceId = source.instanceId,
    sourceSlotIndex = source.slotIndex,
    sourceResolutionIndex = source.resolutionIndex,
    spotlightCoinId = spotlight.coinId,
    spotlightInstanceId = spotlight.instanceId,
    spotlightSlotIndex = spotlight.slotIndex,
    spotlightResolutionIndex = spotlight.resolutionIndex,
    redirectedCredit = true,
  }

  context.trace.redirectedScoreCredits = context.trace.redirectedScoreCredits or {}
  table.insert(context.trace.redirectedScoreCredits, redirect)

  if context.scoreBreakdown then
    context.scoreBreakdown.redirectedScoreCredits = context.scoreBreakdown.redirectedScoreCredits or {}
    table.insert(context.scoreBreakdown.redirectedScoreCredits, Utils.clone(redirect))
  end
end

local SWAPPED_BODY_FIELDS = {
  "coinId",
  "instanceId",
  "originalDrawIndex",
  "dealtIndex",
  "foretold",
  "foretoldResult",
  "foretoldBy",
  "foretoldRngRoll",
}

local function swapBodyFields(left, right)
  if not left or not right then
    return
  end

  for _, field in ipairs(SWAPPED_BODY_FIELDS) do
    left[field], right[field] = right[field], left[field]
  end
end

local function chooseSwitcherooPair(context)
  local failed = nil
  local failedScore = nil
  local successful = nil
  local successfulScore = nil

  for _, coinState in ipairs(context.perCoin or {}) do
    local baseScore = CoinTraits.baseScore(coinState.coinId)
    local didMatch = coinState.result == context.call

    if didMatch then
      if successful == nil or baseScore < successfulScore then
        successful = coinState
        successfulScore = baseScore
      end
    else
      if failed == nil or baseScore > failedScore then
        failed = coinState
        failedScore = baseScore
      end
    end
  end

  if not failed or not successful then
    return nil, nil
  end

  return failed, successful
end

local function applySwitcherooSwap(context, action, options)
  if not context.perCoin or #context.perCoin == 0 then
    recordWarning(options, context, "swap_coins ignored without resolved coins.")
    return
  end

  local failed = nil
  local successful = nil

  if type(action.target) == "table" then
    failed = TargetSelectors.resolveSlot(nil, nil, action.target.source, context)
    successful = TargetSelectors.resolveSlot(nil, nil, action.target.target, contextWithFields(context, {
      selectorExcludedInstanceId = failed and failed.instanceId or nil,
    }))
  else
    failed, successful = chooseSwitcherooPair(context)
  end

  if not failed or not successful then
    recordWarning(options, context, "swap_coins had no failed/successful slot pair.")
    return
  end

  local failedBefore = Utils.clone(failed)
  local successfulBefore = Utils.clone(successful)
  local failedEntry = findByResolutionIndex(context.resolutionOrder, failed.resolutionIndex)
  local successfulEntry = findByResolutionIndex(context.resolutionOrder, successful.resolutionIndex)
  local failedRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, failed.resolutionIndex)
  local successfulRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, successful.resolutionIndex)

  swapBodyFields(failed, successful)
  swapBodyFields(failedEntry, successfulEntry)
  swapBodyFields(failedRoll, successfulRoll)

  action.failedSlotIndex = failedBefore.slotIndex
  action.successSlotIndex = successfulBefore.slotIndex
  action.failedResolutionIndex = failedBefore.resolutionIndex
  action.successResolutionIndex = successfulBefore.resolutionIndex
  action.failedInstanceId = failedBefore.instanceId
  action.successInstanceId = successfulBefore.instanceId
  action.failedCoinId = failedBefore.coinId
  action.successCoinId = successfulBefore.coinId

  context.trace.sleightMoves = context.trace.sleightMoves or {}
  table.insert(context.trace.sleightMoves, {
    op = "swap_coins",
    sourceId = action._trace and action._trace.sourceId or nil,
    failedSlotIndex = failedBefore.slotIndex,
    successSlotIndex = successfulBefore.slotIndex,
    failedResolutionIndex = failedBefore.resolutionIndex,
    successResolutionIndex = successfulBefore.resolutionIndex,
    failedResult = failedBefore.result,
    successResult = successfulBefore.result,
    failedInstanceId = failedBefore.instanceId,
    successInstanceId = successfulBefore.instanceId,
    failedCoinId = failedBefore.coinId,
    successCoinId = successfulBefore.coinId,
  })
end

function IdentityActions.isIdentityOp(op)
  return IDENTITY_OPS[op] == true
end

function IdentityActions.validate(action, TargetSelectorsModule)
  local selectors = TargetSelectorsModule or TargetSelectors

  if action.target ~= nil and type(action.target) ~= "table" then
    return false, string.format("%s target must be selector when present", action.op)
  end

  if type(action.target) == "table" then
    local validSourceSelector, sourceSelectorError = selectors.validateSlotSelector(action.target.source, { selected_coins = true })
    if not validSourceSelector then
      return false, action.op .. " source " .. sourceSelectorError
    end

    local validTargetSelector, targetSelectorError = selectors.validateSlotSelector(action.target.target, { selected_coins = true })
    if not validTargetSelector then
      return false, action.op .. " target " .. targetSelectorError
    end
  end

  return true
end

function IdentityActions.apply(context, action, options)
  if action.op == "forge_identity" then
    applyForgeIdentity(context, action, options)
    return true
  elseif action.op == "redirect_score_credit" then
    applyRedirectScoreCredit(context, action, options)
    return true
  elseif action.op == "swap_coins" then
    applySwitcherooSwap(context, action, options)
    return true
  end

  return false
end

return IdentityActions
