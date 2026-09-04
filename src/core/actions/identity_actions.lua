local CoinTraits = require("src.core.coin_traits")
local TargetSelectors = require("src.core.target_selectors")
local Utils = require("src.core.utils")

local IdentityActions = {}

local IDENTITY_OPS = {
  swap_coins = true,
  replace_coin_from_hand = true,
  extract_failed_smuggling_coin = true,
  palm_failed_coin = true,
  monte_rearrange = true,
}

local function recordWarning(options, context, message)
  if options and options.recordWarning then
    options.recordWarning(context, message)
  end
end

local function findByResolutionIndex(entries, resolutionIndex)
  for _, entry in ipairs(entries or {}) do
    if entry.resolutionIndex == resolutionIndex then
      return entry
    end
  end

  return nil
end

local function baseScore(coin)
  return CoinTraits.baseScore(coin and (coin.coinId or coin.definitionId) or coin)
end

local function applyQualityScoreScaling(target, qualityCoin, action)
  local family = action.qualityFamily

  if type(family) ~= "string" or family == "" or not CoinTraits.hasRealFamily(qualityCoin, family) then
    return 1
  end

  local multiplier = CoinTraits.materialPayoffMultiplier(
    qualityCoin,
    action.qualityBaseMultiplier or 1,
    action.qualityRankStep or 0,
    true
  )

  target.scoreScalingMultiplier = (tonumber(target.scoreScalingMultiplier) or 1) * multiplier
  action.appliedQualityFamily = family
  action.appliedMaterialRank = CoinTraits.materialRank(qualityCoin, true)
  action.appliedScoreMultiplier = multiplier
  return multiplier
end

local function applyFixedScoreScaling(target, action)
  if target and type(action.fixedScoreScaling) == "number" then
    target.scoreScalingMultiplier = (tonumber(target.scoreScalingMultiplier) or 1) * action.fixedScoreScaling
    action.appliedScoreMultiplier = action.fixedScoreScaling
  end
end

local function findDealtSlotByInstanceId(context, instanceId)
  for _, slot in ipairs(context and context.stageState and context.stageState.purse and context.stageState.purse.dealtHandSlots or {}) do
    if slot and slot.instanceId == instanceId then
      return slot
    end
  end

  return nil
end

local function contextWithFields(context, fields)
  return setmetatable(fields or {}, { __index = context })
end

local function findCoinByResolutionIndex(context, resolutionIndex)
  for _, coinState in ipairs(context and context.perCoin or {}) do
    if coinState.resolutionIndex == resolutionIndex then
      return coinState
    end
  end

  return nil
end

local function findCoinByInstanceId(context, instanceId)
  for _, coinState in ipairs(context and context.perCoin or {}) do
    if coinState.instanceId == instanceId then
      return coinState
    end
  end

  return nil
end

local function activationSourceCoin(context)
  local instanceId = context and context.currentActivation and context.currentActivation.sourceInstanceId or nil
  return findCoinByInstanceId(context, instanceId) or (context and context.currentCoin or nil)
end

local function compareCoinValue(left, right)
  local leftRank = CoinTraits.materialRank(left, true)
  local rightRank = CoinTraits.materialRank(right, true)
  if leftRank ~= rightRank then
    return leftRank < rightRank and -1 or 1
  end

  local leftScore = baseScore(left)
  local rightScore = baseScore(right)
  if leftScore ~= rightScore then
    return leftScore < rightScore and -1 or 1
  end

  return 0
end

local function chooseRandom(context, candidates)
  if #candidates == 0 then return nil end
  if context and context.rng and type(context.rng.choose) == "function" then
    return context.rng:choose(candidates)
  end
  return candidates[1]
end

local function chooseHighestValue(context, candidates, materialOnly)
  local best = {}
  for _, candidate in ipairs(candidates or {}) do
    if #best == 0 then
      best = { candidate }
    else
      local comparison = materialOnly
        and (CoinTraits.materialRank(candidate, true) - CoinTraits.materialRank(best[1], true))
        or compareCoinValue(candidate, best[1])
      if comparison > 0 then
        best = { candidate }
      elseif comparison == 0 then
        table.insert(best, candidate)
      end
    end
  end
  return chooseRandom(context, best)
end

local function isSleightUsed(context, coinState)
  local instanceId = coinState and coinState.instanceId or nil
  return instanceId ~= nil and context and context.sleightUsedInstanceIds
    and context.sleightUsedInstanceIds[instanceId] == true
end

local function markSleightUsed(context, coinState)
  if not coinState or not coinState.instanceId then return end
  context.sleightUsedInstanceIds = context.sleightUsedInstanceIds or {}
  context.sleightUsedInstanceIds[coinState.instanceId] = true
  coinState.sleightUsed = true
end

local function syncTriggeredSourceBodies(context, resolutionIndices)
  local affected = {}
  for _, resolutionIndex in ipairs(resolutionIndices or {}) do
    affected[resolutionIndex] = true
  end

  for _, entry in ipairs(context.trace and context.trace.triggeredSources or {}) do
    if affected[entry.resolutionIndex] then
      local coinState = findCoinByResolutionIndex(context, entry.resolutionIndex)
      if coinState then
        entry.coinId = coinState.coinId
        entry.instanceId = coinState.instanceId
        entry.slotIndex = coinState.slotIndex
      end
    end
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

local SWAPPED_PURSE_BODY_FIELDS = {
  "definitionId",
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

local function assignBodyFields(target, source)
  if not target or not source then return end
  for _, field in ipairs(SWAPPED_BODY_FIELDS) do
    target[field] = source[field]
  end
end

local function swapPurseBodyFields(left, right)
  if not left or not right then
    return
  end

  for _, field in ipairs(SWAPPED_PURSE_BODY_FIELDS) do
    left[field], right[field] = right[field], left[field]
  end
end

local function replaceRuntimeBodyFields(target, replacement)
  if not target or not replacement then
    return
  end

  target.coinId = replacement.coinId or replacement.definitionId
  target.instanceId = replacement.instanceId
  target.originalDrawIndex = replacement.originalDrawIndex
  target.dealtIndex = replacement.dealtIndex
  target.foretold = replacement.foretold == true
  target.foretoldResult = replacement.foretoldResult
  target.foretoldBy = replacement.foretoldBy
  target.foretoldRngRoll = replacement.foretoldRngRoll
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

  if action.targetMode == "random_higher_miss"
    or action.targetMode == "highest_material_higher_miss"
    or action.targetMode == "highest_value_higher_miss" then
    successful = activationSourceCoin(context)

    if not successful or successful.selectedSlotIndex == nil or successful.smuggled == true
      or successful.palmed == true or successful.result ~= context.call then
      action.skipped = true
      action.skipReason = "activation_source_not_available_match"
      return
    end

    if isSleightUsed(context, successful) then
      action.skipped = true
      action.skipReason = "activation_source_already_moved"
      return
    end

    local candidates = {}
    for _, coinState in ipairs(context.perCoin or {}) do
      if coinState.instanceId ~= successful.instanceId
        and coinState.selectedSlotIndex ~= nil
        and coinState.smuggled ~= true
        and coinState.palmed ~= true
        and coinState.result ~= context.call
        and not isSleightUsed(context, coinState)
        and compareCoinValue(coinState, successful) > 0 then
        table.insert(candidates, coinState)
      end
    end

    if action.targetMode == "random_higher_miss" then
      failed = chooseRandom(context, candidates)
    elseif action.targetMode == "highest_material_higher_miss" then
      failed = chooseHighestValue(context, candidates, true)
    else
      failed = chooseHighestValue(context, candidates, false)
    end

    if not failed then
      action.skipped = true
      action.skipReason = "no_higher_value_miss"
      return
    end
  elseif action.activationSource == true then
    failed = context.currentCoin
    local bestScore = nil
    for _, coinState in ipairs(context.perCoin or {}) do
      if coinState.instanceId ~= (failed and failed.instanceId)
        and coinState.selectedSlotIndex ~= nil
        and coinState.result == context.call then
        local score = baseScore(coinState)
        if not successful or score < bestScore then
          successful = coinState
          bestScore = score
        end
      end
    end
  elseif type(action.target) == "table" then
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
  local failedScore = baseScore(failed)
  local successfulScore = baseScore(successful)

  action.failedBaseScore = failedScore
  action.successBaseScore = successfulScore
  action.failedSlotIndex = failedBefore.slotIndex
  action.successSlotIndex = successfulBefore.slotIndex
  action.failedResolutionIndex = failedBefore.resolutionIndex
  action.successResolutionIndex = successfulBefore.resolutionIndex
  action.failedInstanceId = failedBefore.instanceId
  action.successInstanceId = successfulBefore.instanceId
  action.failedCoinId = failedBefore.coinId
  action.successCoinId = successfulBefore.coinId

  if action.requireSourceBaseScoreGreaterThanTarget == true and failedScore <= successfulScore then
    action.skipped = true
    action.skipReason = "source_base_score_not_greater"
    return
  end

  local failedEntry = findByResolutionIndex(context.resolutionOrder, failed.resolutionIndex)
  local successfulEntry = findByResolutionIndex(context.resolutionOrder, successful.resolutionIndex)
  local failedRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, failed.resolutionIndex)
  local successfulRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, successful.resolutionIndex)

  markSleightUsed(context, failed)
  markSleightUsed(context, successful)
  swapBodyFields(failed, successful)
  swapBodyFields(failedEntry, successfulEntry)
  swapBodyFields(failedRoll, successfulRoll)

  applyQualityScoreScaling(successful, failedBefore, action)
  applyFixedScoreScaling(successful, action)
  syncTriggeredSourceBodies(context, { failedBefore.resolutionIndex, successfulBefore.resolutionIndex })

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
    failedBaseScore = failedScore,
    successBaseScore = successfulScore,
    targetMode = action.targetMode,
  })
end

local function applyReplaceCoinFromHand(context, action, options)
  if not context.perCoin or #context.perCoin == 0 then
    recordWarning(options, context, "replace_coin_from_hand ignored without resolved coins.")
    return
  end

  local target = TargetSelectors.resolveSlot(nil, nil, action.target and action.target.target, context)
  local replacement = TargetSelectors.resolveSlot(nil, context.stageState, action.target and action.target.replacement, context)

  if not target or not replacement then
    recordWarning(options, context, "replace_coin_from_hand had no eligible selected target and hand replacement.")
    return
  end

  local targetBefore = Utils.clone(target)
  local replacementBefore = Utils.clone(replacement)
  local targetScore = baseScore(target)
  local replacementScore = baseScore(replacement)

  action.targetBaseScore = targetScore
  action.replacementBaseScore = replacementScore
  action.targetSlotIndex = targetBefore.slotIndex
  action.targetSelectedSlotIndex = targetBefore.selectedSlotIndex
  action.targetResolutionIndex = targetBefore.resolutionIndex
  action.targetInstanceId = targetBefore.instanceId
  action.targetCoinId = targetBefore.coinId
  action.replacementSlotIndex = replacementBefore.slotIndex
  action.replacementDealtIndex = replacementBefore.dealtIndex
  action.replacementInstanceId = replacementBefore.instanceId
  action.replacementCoinId = replacementBefore.coinId or replacementBefore.definitionId

  if action.requireReplacementBaseScoreGreaterThanTarget == true and replacementScore <= targetScore then
    action.skipped = true
    action.skipReason = "replacement_base_score_not_greater"
    return
  end

  action.coinId = replacementBefore.coinId or replacementBefore.definitionId
  action.instanceId = replacementBefore.instanceId
  action.slotIndex = targetBefore.slotIndex
  action.selectedSlotIndex = targetBefore.selectedSlotIndex
  action.dealtIndex = replacementBefore.dealtIndex
  action.resolutionIndex = targetBefore.resolutionIndex

  local targetEntry = findByResolutionIndex(context.resolutionOrder, target.resolutionIndex)
  local targetRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, target.resolutionIndex)
  local targetPurseSlot = findDealtSlotByInstanceId(context, targetBefore.instanceId)
  local replacementPurseSlot = findDealtSlotByInstanceId(context, replacementBefore.instanceId)

  replaceRuntimeBodyFields(target, replacementBefore)
  replaceRuntimeBodyFields(targetEntry, replacementBefore)
  replaceRuntimeBodyFields(targetRoll, replacementBefore)
  swapPurseBodyFields(targetPurseSlot, replacementPurseSlot)

  applyQualityScoreScaling(target, replacementBefore, action)
  applyFixedScoreScaling(target, action)
  syncTriggeredSourceBodies(context, { targetBefore.resolutionIndex })

  context.trace.sleightMoves = context.trace.sleightMoves or {}
  table.insert(context.trace.sleightMoves, {
    op = "replace_coin_from_hand",
    sourceId = action._trace and action._trace.sourceId or nil,
    targetSlotIndex = targetBefore.slotIndex,
    targetSelectedSlotIndex = targetBefore.selectedSlotIndex,
    targetResolutionIndex = targetBefore.resolutionIndex,
    targetResult = targetBefore.result,
    targetInstanceId = targetBefore.instanceId,
    targetCoinId = targetBefore.coinId,
    targetBaseScore = targetScore,
    replacementSlotIndex = replacementBefore.slotIndex,
    replacementDealtIndex = replacementBefore.dealtIndex,
    replacementInstanceId = replacementBefore.instanceId,
    replacementCoinId = replacementBefore.coinId or replacementBefore.definitionId,
    replacementBaseScore = replacementScore,
  })
end

local function applyExtractFailedSmugglingCoin(context, action, options)
  local target = context.currentCoin

  if not target or target.selectedSlotIndex == nil then
    action.skipped = true
    action.skipReason = "activation_source_not_committed"
    return
  end

  if target.result == context.call then
    action.skipped = true
    action.skipReason = "activation_source_matched"
    return
  end

  if not CoinTraits.hasRealFamily(target, "smuggle") then
    action.skipped = true
    action.skipReason = "activation_source_not_smuggling"
    return
  end

  local replacement = TargetSelectors.resolveSlot(nil, context.stageState, action.target, context)
  if not replacement then
    action.skipped = true
    action.skipReason = "no_lower_quality_smuggling_coin"
    return
  end

  local targetRank = CoinTraits.materialRank(target, true)
  local replacementRank = CoinTraits.materialRank(replacement, true)
  if replacementRank >= targetRank or not CoinTraits.hasRealFamily(replacement, "smuggle") then
    action.skipped = true
    action.skipReason = "replacement_not_lower_quality_smuggling"
    return
  end

  local targetBefore = Utils.clone(target)
  local replacementBefore = Utils.clone(replacement)
  local targetEntry = findByResolutionIndex(context.resolutionOrder, target.resolutionIndex)
  local targetRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, target.resolutionIndex)
  local targetPurseSlot = findDealtSlotByInstanceId(context, targetBefore.instanceId)
  local replacementPurseSlot = findDealtSlotByInstanceId(context, replacementBefore.instanceId)

  if not targetPurseSlot or not replacementPurseSlot then
    action.skipped = true
    action.skipReason = "smuggling_body_not_in_dealt_hand"
    return
  end

  action.savedCoinId = targetBefore.coinId
  action.savedInstanceId = targetBefore.instanceId
  action.savedMaterialRank = targetRank
  action.replacementCoinId = replacementBefore.coinId or replacementBefore.definitionId
  action.replacementInstanceId = replacementBefore.instanceId
  action.replacementMaterialRank = replacementRank
  action.replacementDealtIndex = replacementBefore.dealtIndex
  action.coinId = replacementBefore.coinId or replacementBefore.definitionId
  action.instanceId = replacementBefore.instanceId
  action.slotIndex = targetBefore.slotIndex
  action.selectedSlotIndex = targetBefore.selectedSlotIndex
  action.resolutionIndex = targetBefore.resolutionIndex
  action.targetCoinId = targetBefore.coinId
  action.targetInstanceId = targetBefore.instanceId
  action.targetSlotIndex = targetBefore.slotIndex
  action.targetSelectedSlotIndex = targetBefore.selectedSlotIndex
  action.targetResolutionIndex = targetBefore.resolutionIndex

  replaceRuntimeBodyFields(target, replacementBefore)
  replaceRuntimeBodyFields(targetEntry, replacementBefore)
  replaceRuntimeBodyFields(targetRoll, replacementBefore)
  swapPurseBodyFields(targetPurseSlot, replacementPurseSlot)
  syncTriggeredSourceBodies(context, { targetBefore.resolutionIndex })

  context.trace.smugglingExtractions = context.trace.smugglingExtractions or {}
  table.insert(context.trace.smugglingExtractions, {
    op = "extract_failed_smuggling_coin",
    sourceId = action._trace and action._trace.sourceId or nil,
    savedCoinId = targetBefore.coinId,
    savedInstanceId = targetBefore.instanceId,
    savedMaterialRank = targetRank,
    replacementCoinId = replacementBefore.coinId or replacementBefore.definitionId,
    replacementInstanceId = replacementBefore.instanceId,
    replacementMaterialRank = replacementRank,
    replacementDealtIndex = replacementBefore.dealtIndex,
    targetSlotIndex = targetBefore.slotIndex,
    targetSelectedSlotIndex = targetBefore.selectedSlotIndex,
    targetResolutionIndex = targetBefore.resolutionIndex,
    targetResult = targetBefore.result,
  })
end

local function palmCandidateIsEligible(context, candidate)
  return candidate
    and candidate.selectedSlotIndex ~= nil
    and candidate.smuggled ~= true
    and candidate.palmed ~= true
    and candidate.result ~= context.call
    and not isSleightUsed(context, candidate)
end

local function applyPalmFailedCoin(context, action, options)
  local source = activationSourceCoin(context)
  local candidates = {}

  if action.targetMode == "activation_source_miss" then
    if palmCandidateIsEligible(context, source) then candidates = { source } end
  else
    for _, candidate in ipairs(context.perCoin or {}) do
      local isLocal = source and candidate.selectedSlotIndex
        and source.selectedSlotIndex
        and math.abs(candidate.selectedSlotIndex - source.selectedSlotIndex) <= 1
      if palmCandidateIsEligible(context, candidate)
        and (action.targetMode == "global_highest_miss" or isLocal) then
        table.insert(candidates, candidate)
      end
    end
  end

  local target = action.targetMode == "activation_source_miss"
    and candidates[1]
    or chooseHighestValue(context, candidates, false)

  if not target then
    action.skipped = true
    action.skipReason = "no_eligible_failed_coin_to_palm"
    return
  end

  local targetBefore = Utils.clone(target)
  local targetEntry = findByResolutionIndex(context.resolutionOrder, target.resolutionIndex)
  local targetRoll = findByResolutionIndex(context.trace and context.trace.coinRolls or {}, target.resolutionIndex)
  local targetPurseSlot = findDealtSlotByInstanceId(context, target.instanceId)

  if not targetPurseSlot then
    action.skipped = true
    action.skipReason = "palmed_body_not_in_dealt_hand"
    return
  end

  markSleightUsed(context, target)
  target.palmed = true
  target.sleightSaved = true
  if targetEntry then
    targetEntry.palmed = true
    targetEntry.sleightSaved = true
  end
  if targetRoll then
    targetRoll.palmed = true
    targetRoll.sleightSaved = true
  end
  targetPurseSlot.sleightSaved = true
  targetPurseSlot.sleightUsed = true

  action.coinId = targetBefore.coinId
  action.instanceId = targetBefore.instanceId
  action.slotIndex = targetBefore.slotIndex
  action.selectedSlotIndex = targetBefore.selectedSlotIndex
  action.resolutionIndex = targetBefore.resolutionIndex
  action.targetCoinId = targetBefore.coinId
  action.targetInstanceId = targetBefore.instanceId
  action.targetSlotIndex = targetBefore.slotIndex
  action.targetSelectedSlotIndex = targetBefore.selectedSlotIndex
  action.targetResolutionIndex = targetBefore.resolutionIndex
  action.targetDealtIndex = targetBefore.dealtIndex
  action.palmed = true

  context.trace.sleightMoves = context.trace.sleightMoves or {}
  table.insert(context.trace.sleightMoves, {
    op = "palm_failed_coin",
    sourceId = action._trace and action._trace.sourceId or nil,
    coinId = targetBefore.coinId,
    instanceId = targetBefore.instanceId,
    targetSlotIndex = targetBefore.slotIndex,
    targetSelectedSlotIndex = targetBefore.selectedSlotIndex,
    targetResolutionIndex = targetBefore.resolutionIndex,
    targetDealtIndex = targetBefore.dealtIndex,
    targetResult = targetBefore.result,
    targetMode = action.targetMode,
  })
end

local function projectedImmediateScore(context, slot, body)
  if not slot or not body or slot.result ~= context.call then return 0 end
  local multiplier = (tonumber(slot.scoreScalingMultiplier) or 1)
    * (tonumber(slot.rootScoreScalingMultiplier) or 1)
  return baseScore(body) * multiplier
end

local function assignmentScore(context, slots, bodies, order)
  local total = 0
  for index, slot in ipairs(slots or {}) do
    total = total + projectedImmediateScore(context, slot, bodies[order[index]])
  end
  return total
end

local function collectPermutations(count)
  local permutations = {}
  local used = {}
  local current = {}
  local function visit(position)
    if position > count then
      table.insert(permutations, Utils.copyArray(current))
      return
    end
    for index = 1, count do
      if not used[index] then
        used[index] = true
        current[position] = index
        visit(position + 1)
        used[index] = nil
      end
    end
  end
  visit(1)
  return permutations
end

local function applyMonteRearrange(context, action, options)
  local source = activationSourceCoin(context)
  if not source or source.selectedSlotIndex == nil or source.smuggled == true
    or source.palmed == true or isSleightUsed(context, source) then
    action.skipped = true
    action.skipReason = "activation_source_not_available_for_monte"
    return
  end
  local sourceBefore = Utils.clone(source)

  local neighbors = {}
  for _, candidate in ipairs(context.perCoin or {}) do
    if candidate.selectedSlotIndex ~= nil
      and candidate.smuggled ~= true
      and candidate.palmed ~= true
      and not isSleightUsed(context, candidate)
      and math.abs(candidate.selectedSlotIndex - source.selectedSlotIndex) == 1 then
      table.insert(neighbors, candidate)
    end
  end
  table.sort(neighbors, function(left, right)
    return left.selectedSlotIndex < right.selectedSlotIndex
  end)

  local arrangements = {}
  if action.mode == "random_improving_neighbor" or action.mode == "best_improving_neighbor" then
    for _, neighbor in ipairs(neighbors) do
      local slots = { source, neighbor }
      local bodies = { Utils.clone(source), Utils.clone(neighbor) }
      local currentScore = assignmentScore(context, slots, bodies, { 1, 2 })
      local swappedScore = assignmentScore(context, slots, bodies, { 2, 1 })
      if swappedScore > currentScore then
        table.insert(arrangements, {
          slots = slots,
          bodies = bodies,
          order = { 2, 1 },
          beforeScore = currentScore,
          afterScore = swappedScore,
        })
      end
    end
  elseif action.mode == "best_local_permutation" then
    if #neighbors < 2 then
      action.skipped = true
      action.skipReason = "monte_requires_two_neighbors"
      return
    end
    local slots = { neighbors[1], source, neighbors[2] }
    table.sort(slots, function(left, right)
      return left.selectedSlotIndex < right.selectedSlotIndex
    end)
    local bodies = {}
    for _, slot in ipairs(slots) do table.insert(bodies, Utils.clone(slot)) end
    local identity = { 1, 2, 3 }
    local currentScore = assignmentScore(context, slots, bodies, identity)
    for _, order in ipairs(collectPermutations(3)) do
      local score = assignmentScore(context, slots, bodies, order)
      if score > currentScore then
        table.insert(arrangements, {
          slots = slots,
          bodies = bodies,
          order = order,
          beforeScore = currentScore,
          afterScore = score,
        })
      end
    end
  end

  if #arrangements == 0 then
    action.skipped = true
    action.skipReason = "no_improving_monte_arrangement"
    return
  end

  local chosen = nil
  if action.mode == "random_improving_neighbor" then
    chosen = chooseRandom(context, arrangements)
  else
    local best = {}
    for _, arrangement in ipairs(arrangements) do
      if #best == 0 or arrangement.afterScore > best[1].afterScore then
        best = { arrangement }
      elseif arrangement.afterScore == best[1].afterScore then
        table.insert(best, arrangement)
      end
    end
    chosen = chooseRandom(context, best)
  end

  local moves = {}
  local affectedResolutionIndices = {}
  for index, slot in ipairs(chosen.slots) do
    local body = chosen.bodies[chosen.order[index]]
    local oldBody = chosen.bodies[index]
    markSleightUsed(context, oldBody)
    if body.instanceId ~= oldBody.instanceId then
      table.insert(moves, {
        coinId = body.coinId,
        instanceId = body.instanceId,
        sourceResolutionIndex = body.resolutionIndex,
        targetResolutionIndex = slot.resolutionIndex,
      })
    end
    assignBodyFields(slot, body)
    assignBodyFields(findByResolutionIndex(context.resolutionOrder, slot.resolutionIndex), body)
    assignBodyFields(findByResolutionIndex(context.trace and context.trace.coinRolls or {}, slot.resolutionIndex), body)
    table.insert(affectedResolutionIndices, slot.resolutionIndex)
  end
  syncTriggeredSourceBodies(context, affectedResolutionIndices)

  action.beforeScore = chosen.beforeScore
  action.afterScore = chosen.afterScore
  action.moves = Utils.clone(moves)
  action.affectedResolutionIndices = Utils.copyArray(affectedResolutionIndices)
  action.coinId = sourceBefore.coinId
  action.instanceId = sourceBefore.instanceId
  action.slotIndex = sourceBefore.slotIndex
  action.selectedSlotIndex = sourceBefore.selectedSlotIndex
  action.resolutionIndex = sourceBefore.resolutionIndex

  context.trace.sleightMoves = context.trace.sleightMoves or {}
  table.insert(context.trace.sleightMoves, {
    op = "monte_rearrange",
    sourceId = action._trace and action._trace.sourceId or nil,
    mode = action.mode,
    beforeScore = chosen.beforeScore,
    afterScore = chosen.afterScore,
    moves = Utils.clone(moves),
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

  if action.op == "replace_coin_from_hand" then
    if type(action.target) ~= "table" then
      return false, "replace_coin_from_hand requires target selectors"
    end

    local validTargetSelector, targetSelectorError = selectors.validateSlotSelector(action.target.target, { selected_coins = true })
    if not validTargetSelector then
      return false, action.op .. " target " .. targetSelectorError
    end

    local validReplacementSelector, replacementSelectorError = selectors.validateSlotSelector(action.target.replacement, { dealt_hand = true })
    if not validReplacementSelector then
      return false, action.op .. " replacement " .. replacementSelectorError
    end

    if action.requireReplacementBaseScoreGreaterThanTarget ~= nil and type(action.requireReplacementBaseScoreGreaterThanTarget) ~= "boolean" then
      return false, "replace_coin_from_hand requireReplacementBaseScoreGreaterThanTarget must be boolean when present"
    end

    return true
  end


  if action.op == "extract_failed_smuggling_coin" then
    local validReplacementSelector, replacementSelectorError = selectors.validateSlotSelector(action.target, { dealt_hand = true })
    if not validReplacementSelector then
      return false, action.op .. " target " .. replacementSelectorError
    end

    return true
  end

  if action.op == "palm_failed_coin" then
    if action.targetMode ~= "activation_source_miss"
      and action.targetMode ~= "local_highest_miss"
      and action.targetMode ~= "global_highest_miss" then
      return false, "palm_failed_coin targetMode must be activation_source_miss|local_highest_miss|global_highest_miss"
    end
    return true
  end

  if action.op == "monte_rearrange" then
    if action.mode ~= "random_improving_neighbor"
      and action.mode ~= "best_improving_neighbor"
      and action.mode ~= "best_local_permutation" then
      return false, "monte_rearrange mode must be random_improving_neighbor|best_improving_neighbor|best_local_permutation"
    end
    return true
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

  if action.op == "swap_coins"
    and action.requireSourceBaseScoreGreaterThanTarget ~= nil
    and type(action.requireSourceBaseScoreGreaterThanTarget) ~= "boolean" then
    return false, "swap_coins requireSourceBaseScoreGreaterThanTarget must be boolean when present"
  end

  if action.op == "swap_coins" and action.targetMode ~= nil
    and action.targetMode ~= "random_higher_miss"
    and action.targetMode ~= "highest_material_higher_miss"
    and action.targetMode ~= "highest_value_higher_miss" then
    return false, "swap_coins targetMode must be random_higher_miss|highest_material_higher_miss|highest_value_higher_miss when present"
  end

  return true
end

function IdentityActions.apply(context, action, options)
  if action.op == "swap_coins" then
    applySwitcherooSwap(context, action, options)
    return true
  elseif action.op == "replace_coin_from_hand" then
    applyReplaceCoinFromHand(context, action, options)
    return true
  elseif action.op == "extract_failed_smuggling_coin" then
    applyExtractFailedSmugglingCoin(context, action, options)
    return true
  elseif action.op == "palm_failed_coin" then
    applyPalmFailedCoin(context, action, options)
    return true
  elseif action.op == "monte_rearrange" then
    applyMonteRearrange(context, action, options)
    return true
  end

  return false
end

return IdentityActions
