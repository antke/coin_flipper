local Bosses = require("src.content.bosses")
local Coins = require("src.content.coins")
local RNG = require("src.core.rng")
local Utils = require("src.core.utils")

local BossTrickSystem = {}

local function baseState()
  return {
    revision = 1,
    bossId = nil,
    trickId = nil,
    favouriteSide = nil,
    spotlightSlotIndex = nil,
    leadSlotIndex = nil,
    victimSlotIndex = nil,
    impostorSlotIndex = nil,
    shuffleSeed = nil,
    offTheBooksSlotIndex = nil,
    writtenSlotResults = nil,
    intentIndex = 0,
    rngRoll = nil,
  }
end

local function clear(state)
  if not state then return end
  state.bossId = nil
  state.trickId = nil
  state.favouriteSide = nil
  state.spotlightSlotIndex = nil
  state.leadSlotIndex = nil
  state.victimSlotIndex = nil
  state.impostorSlotIndex = nil
  state.shuffleSeed = nil
  state.offTheBooksSlotIndex = nil
  state.writtenSlotResults = nil
  state.intentIndex = 0
  state.rngRoll = nil
end

local function seedText(runState, stageState, definition, intentIndex)
  return table.concat({
    tostring(runState and runState.seed or 1),
    tostring(stageState and stageState.stageId or "boss"),
    tostring(stageState and stageState.variantId or ""),
    tostring(definition and definition.id or "boss"),
    tostring(definition and definition.bossTrick and definition.bossTrick.id or "trick"),
    tostring(intentIndex or 1),
  }, ":")
end

function BossTrickSystem.ensureState(stageState)
  if not stageState then return nil end
  stageState.bossTrick = stageState.bossTrick or baseState()
  stageState.bossTrick.revision = stageState.bossTrick.revision or 1
  return stageState.bossTrick
end

function BossTrickSystem.getDefinition(stageState)
  if not stageState or stageState.stageType ~= "boss" then return nil end
  local state = stageState.bossTrick
  if state and state.bossId then
    local definition = Bosses.getById(state.bossId)
    if definition and definition.bossTrick then return definition end
  end
  for _, bossId in ipairs(stageState.activeBossModifierIds or {}) do
    local definition = Bosses.getById(bossId)
    if definition and definition.bossTrick then return definition end
  end
  return nil
end

function BossTrickSystem.prepareIntent(runState, stageState, options)
  options = options or {}
  local state = BossTrickSystem.ensureState(stageState)
  local definition = BossTrickSystem.getDefinition(stageState)
  if not definition then
    clear(state)
    return nil
  end

  local intentIndex = math.max(1, tonumber(options.intentIndex)
    or ((tonumber(stageState.batchIndex) or 0) + 1))
  local rng = RNG.newFromText(seedText(runState, stageState, definition, intentIndex))
  local rngRoll = rng:nextFloat()
  local trick = definition.bossTrick
  local favouriteSide = nil
  local spotlightSlotIndex = nil
  local leadSlotIndex = nil
  local victimSlotIndex = nil
  local impostorSlotIndex = nil
  local shuffleSeed = nil
  local offTheBooksSlotIndex = nil
  local writtenSlotResults = nil
  if trick.id == "the_favourite" then
    favouriteSide = options.favouriteSide
    if favouriteSide ~= "heads" and favouriteSide ~= "tails" then
      favouriteSide = rngRoll < 0.5 and "heads" or "tails"
    end
  elseif trick.id == "centre_stage" then
    local slotCount = math.max(1, tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1)
    spotlightSlotIndex = tonumber(options.spotlightSlotIndex)
    if not spotlightSlotIndex or spotlightSlotIndex < 1 or spotlightSlotIndex > slotCount then
      spotlightSlotIndex = math.min(slotCount, math.floor(rngRoll * slotCount) + 1)
    else
      spotlightSlotIndex = math.floor(spotlightSlotIndex)
    end
  elseif trick.id == "full_throttle" then
    local slotCount = math.max(1, tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1)
    leadSlotIndex = tonumber(options.leadSlotIndex)
    if leadSlotIndex ~= 1 and leadSlotIndex ~= slotCount then
      leadSlotIndex = rngRoll < 0.5 and 1 or slotCount
    end
  elseif trick.id == "stolen_identity" then
    local slotCount = math.max(1, tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1)
    victimSlotIndex = tonumber(options.victimSlotIndex)
    impostorSlotIndex = tonumber(options.impostorSlotIndex)
    local explicitPairValid = victimSlotIndex and impostorSlotIndex
      and victimSlotIndex >= 1 and victimSlotIndex <= slotCount
      and impostorSlotIndex >= 1 and impostorSlotIndex <= slotCount
      and math.abs(victimSlotIndex - impostorSlotIndex) == 1
    if not explicitPairValid then
      local pairs = {}
      for slotIndex = 1, slotCount - 1 do
        table.insert(pairs, { victim = slotIndex, impostor = slotIndex + 1 })
        table.insert(pairs, { victim = slotIndex + 1, impostor = slotIndex })
      end
      local pair = pairs[math.min(#pairs, math.floor(rngRoll * #pairs) + 1)]
        or { victim = 1, impostor = 1 }
      victimSlotIndex = pair.victim
      impostorSlotIndex = pair.impostor
    else
      victimSlotIndex = math.floor(victimSlotIndex)
      impostorSlotIndex = math.floor(impostorSlotIndex)
    end
  elseif trick.id == "three_cups" then
    shuffleSeed = tonumber(options.shuffleSeed)
      or RNG.seedFromText(seedText(runState, stageState, definition, intentIndex) .. ":three_cups")
  elseif trick.id == "nothing_to_declare" then
    local slotCount = math.max(1, tonumber(runState and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1)
    offTheBooksSlotIndex = tonumber(options.offTheBooksSlotIndex)
    if not offTheBooksSlotIndex or offTheBooksSlotIndex < 1 or offTheBooksSlotIndex > slotCount then
      offTheBooksSlotIndex = math.min(slotCount, math.floor(rngRoll * slotCount) + 1)
    else
      offTheBooksSlotIndex = math.floor(offTheBooksSlotIndex)
    end
  elseif trick.id == "written_in_stone" then
    local slotCount = math.max(1, math.floor(tonumber(runState
      and (runState.maxFlipSlots or runState.maxActiveCoinSlots)) or 1))
    local explicitResults = options.writtenSlotResults
    local explicitValid = type(explicitResults) == "table" and #explicitResults == slotCount
    local hasHeads = false
    local hasTails = false
    if explicitValid then
      for _, result in ipairs(explicitResults) do
        if result == "heads" then
          hasHeads = true
        elseif result == "tails" then
          hasTails = true
        else
          explicitValid = false
          break
        end
      end
      if slotCount > 1 and not (hasHeads and hasTails) then explicitValid = false end
    end

    if explicitValid then
      writtenSlotResults = Utils.copyArray(explicitResults)
    elseif slotCount == 1 then
      writtenSlotResults = { rngRoll < 0.5 and "heads" or "tails" }
    else
      local maximumCode = (2 ^ slotCount) - 2
      local patternCode = rng:nextInt(1, maximumCode)
      writtenSlotResults = {}
      for slotIndex = 1, slotCount do
        local bitValue = math.floor(patternCode / (2 ^ (slotIndex - 1))) % 2
        writtenSlotResults[slotIndex] = bitValue == 1 and "heads" or "tails"
      end
    end
  end

  state.bossId = definition.id
  state.trickId = trick.id
  state.favouriteSide = favouriteSide
  state.spotlightSlotIndex = spotlightSlotIndex
  state.leadSlotIndex = leadSlotIndex
  state.victimSlotIndex = victimSlotIndex
  state.impostorSlotIndex = impostorSlotIndex
  state.shuffleSeed = shuffleSeed
  state.offTheBooksSlotIndex = offTheBooksSlotIndex
  state.writtenSlotResults = writtenSlotResults
  state.intentIndex = intentIndex
  state.rngRoll = rngRoll
  return BossTrickSystem.snapshot(stageState)
end

function BossTrickSystem.ensureIntent(runState, stageState)
  local state = BossTrickSystem.ensureState(stageState)
  local definition = BossTrickSystem.getDefinition(stageState)
  if not definition then
    clear(state)
    return nil
  end
  local expectedIntent = (tonumber(stageState.batchIndex) or 0) + 1
  local intentReady = definition.bossTrick.id == "the_favourite"
    and (state.favouriteSide == "heads" or state.favouriteSide == "tails")
    or definition.bossTrick.id == "centre_stage"
      and type(state.spotlightSlotIndex) == "number"
    or definition.bossTrick.id == "full_throttle"
      and type(state.leadSlotIndex) == "number"
    or definition.bossTrick.id == "stolen_identity"
      and type(state.victimSlotIndex) == "number"
      and type(state.impostorSlotIndex) == "number"
    or definition.bossTrick.id == "three_cups"
      and type(state.shuffleSeed) == "number"
    or definition.bossTrick.id == "nothing_to_declare"
      and type(state.offTheBooksSlotIndex) == "number"
    or definition.bossTrick.id == "written_in_stone"
      and type(state.writtenSlotResults) == "table"
  if state.bossId ~= definition.id
    or state.trickId ~= definition.bossTrick.id
    or not intentReady
    or state.intentIndex ~= expectedIntent then
    return BossTrickSystem.prepareIntent(runState, stageState, { intentIndex = expectedIntent })
  end
  return BossTrickSystem.snapshot(stageState)
end

function BossTrickSystem.snapshot(stageState)
  local state = BossTrickSystem.ensureState(stageState)
  local definition = BossTrickSystem.getDefinition(stageState)
  local trick = definition and definition.bossTrick or nil
  return {
    revision = state and state.revision or 1,
    bossId = state and state.bossId or nil,
    bossName = definition and definition.name or nil,
    trickId = state and state.trickId or nil,
    trickName = trick and trick.name or nil,
    family = trick and trick.family or nil,
    favouriteSide = state and state.favouriteSide or nil,
    spotlightSlotIndex = state and state.spotlightSlotIndex or nil,
    leadSlotIndex = state and state.leadSlotIndex or nil,
    victimSlotIndex = state and state.victimSlotIndex or nil,
    impostorSlotIndex = state and state.impostorSlotIndex or nil,
    shuffleSeed = state and state.shuffleSeed or nil,
    offTheBooksSlotIndex = state and state.offTheBooksSlotIndex or nil,
    writtenSlotResults = state and Utils.copyArray(state.writtenSlotResults or {}) or nil,
    intentIndex = state and state.intentIndex or 0,
    rngRoll = state and state.rngRoll or nil,
    chanceShift = trick and trick.chanceShift or nil,
    favouriteScoreScaling = trick and trick.favouriteScoreScaling or nil,
    underdogScoreScaling = trick and trick.underdogScoreScaling or nil,
    encoreScaling = trick and trick.encoreScaling or nil,
    upstagedLossScaling = trick and trick.upstagedLossScaling or nil,
    spotlightWinsTies = trick and trick.spotlightWinsTies == true or nil,
    leadScaling = trick and trick.leadScaling or nil,
    middleScaling = trick and trick.middleScaling or nil,
    finishingScaling = trick and trick.finishingScaling or nil,
    taxRate = trick and trick.taxRate or nil,
  }
end

local function effectiveCoinSlotIndex(coinState)
  return coinState and (coinState.selectedSlotIndex or coinState.anchorSelectedSlotIndex or coinState.slotIndex) or nil
end

function BossTrickSystem.applyPreFlipForcedOutcomes(context)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot or snapshot.trickId ~= "written_in_stone" then return nil end

  local forcedCount = 0
  local assignments = {}
  for _, coinState in ipairs(context.perCoin or {}) do
    local slotIndex = effectiveCoinSlotIndex(coinState)
    local result = slotIndex and snapshot.writtenSlotResults
      and snapshot.writtenSlotResults[slotIndex] or nil
    if result == "heads" or result == "tails" then
      coinState.bossForcedResult = result
      coinState.bossForcedReason = "written_in_stone"
      coinState.writtenSlotIndex = slotIndex
      forcedCount = forcedCount + 1
      table.insert(assignments, {
        coinId = coinState.coinId,
        instanceId = coinState.instanceId,
        resolutionIndex = coinState.resolutionIndex,
        slotIndex = slotIndex,
        result = result,
      })
    end
  end

  local effect = {
    bossId = snapshot.bossId,
    trickId = snapshot.trickId,
    kind = "written_results",
    writtenSlotResults = Utils.copyArray(snapshot.writtenSlotResults or {}),
    forcedCount = forcedCount,
    assignments = assignments,
  }
  context.trace.bossTrickEffects = context.trace.bossTrickEffects or {}
  table.insert(context.trace.bossTrickEffects, effect)
  return effect
end

local function findCoinState(coinStates, instanceId)
  for _, coinState in ipairs(coinStates or {}) do
    if coinState.instanceId == instanceId then return coinState end
  end
  return nil
end

local function markPalmedPurseCoin(context, instanceId)
  local purse = context and context.stageState and context.stageState.purse or nil
  for _, slot in ipairs(purse and purse.selectedSlots or {}) do
    if slot.instanceId == instanceId then
      slot.sleightSaved = true
      slot.bossPalmed = true
      return true
    end
  end
  return false
end

local function buildThreeCupsPlan(context, coinStates)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot or snapshot.trickId ~= "three_cups" then return nil end
  if context.trace.threeCups then return context.trace.threeCups end

  local originals = {}
  for sourceIndex, coinState in ipairs(coinStates or {}) do
    if coinState.smuggled ~= true and coinState.contrabandCopy ~= true then
      table.insert(originals, {
        coinId = coinState.coinId,
        instanceId = coinState.instanceId,
        sourceSlotIndex = coinState.selectedSlotIndex or coinState.slotIndex or sourceIndex,
        selectedSlotIndex = coinState.selectedSlotIndex or coinState.slotIndex or sourceIndex,
        dealtIndex = coinState.dealtIndex,
        originalDrawIndex = coinState.originalDrawIndex,
      })
    end
  end

  local shuffled = Utils.clone(originals)
  local rng = RNG.new(snapshot.shuffleSeed or 1)
  rng:shuffle(shuffled)
  local palmedTargetSlotIndex = #shuffled > 1 and rng:nextInt(1, #shuffled) or nil
  local moves = {}
  local palmed = nil

  for targetIndex, coin in ipairs(shuffled) do
    local move = {
      coinId = coin.coinId,
      instanceId = coin.instanceId,
      sourceSlotIndex = coin.sourceSlotIndex,
      targetSlotIndex = targetIndex,
      palmed = targetIndex == palmedTargetSlotIndex,
    }
    table.insert(moves, move)
    if move.palmed then palmed = Utils.clone(move) end
  end

  local plan = {
    bossId = snapshot.bossId,
    trickId = snapshot.trickId,
    kind = "three_cups",
    shuffleSeed = snapshot.shuffleSeed,
    occupiedSlotCount = #originals,
    originalCoins = originals,
    moves = moves,
    palmed = palmed,
  }
  context.trace.threeCups = plan
  context.trace.bossTrickEffects = context.trace.bossTrickEffects or {}
  table.insert(context.trace.bossTrickEffects, Utils.clone(plan))
  if palmed then markPalmedPurseCoin(context, palmed.instanceId) end
  return plan
end

function BossTrickSystem.applyPreFlipCoinMovement(context, coinStates, resolutionEntries)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot or snapshot.trickId ~= "three_cups" then
    return coinStates, resolutionEntries
  end

  local plan = buildThreeCupsPlan(context, coinStates)
  local movedCoins = {}
  local movedEntries = resolutionEntries and {} or nil

  for _, move in ipairs(plan and plan.moves or {}) do
    if not move.palmed then
      local coinState = findCoinState(coinStates, move.instanceId)
      if coinState then
        coinState.selectedSlotIndex = move.targetSlotIndex
        coinState.slotIndex = move.targetSlotIndex
        coinState.resolutionIndex = #movedCoins + 1
        table.insert(movedCoins, coinState)
      end

      if movedEntries then
        local entry = findCoinState(resolutionEntries, move.instanceId)
        if entry then
          entry.selectedSlotIndex = move.targetSlotIndex
          entry.slotIndex = move.targetSlotIndex
          entry.resolutionIndex = #movedEntries + 1
          table.insert(movedEntries, entry)
        end
      end
    end
  end

  return movedCoins, movedEntries
end

local function realCoinFamily(coinState)
  local definition = coinState and coinState.coinId and Coins.getById(coinState.coinId) or nil
  return definition and definition.activationFamily or nil
end

function BossTrickSystem.applyPreFlipCoinIdentities(context)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot or snapshot.trickId ~= "stolen_identity" then return nil end
  local victim = nil
  local impostor = nil
  for _, coinState in ipairs(context.perCoin or {}) do
    coinState.bossActivationFamily = nil
    coinState.stolenIdentity = nil
    coinState.stolenFromSlotIndex = nil
    coinState.originalActivationFamily = nil
    if coinState.selectedSlotIndex == snapshot.victimSlotIndex then victim = coinState end
    if coinState.selectedSlotIndex == snapshot.impostorSlotIndex then impostor = coinState end
  end

  local stolenFamily = realCoinFamily(victim)
  if impostor then
    impostor.originalActivationFamily = realCoinFamily(impostor)
    impostor.bossActivationFamily = stolenFamily or false
    impostor.stolenIdentity = true
    impostor.stolenFromSlotIndex = snapshot.victimSlotIndex
  end

  local trace = {
    bossId = snapshot.bossId,
    trickId = snapshot.trickId,
    kind = "stolen_identity",
    victimSlotIndex = snapshot.victimSlotIndex,
    impostorSlotIndex = snapshot.impostorSlotIndex,
    victimCoinId = victim and victim.coinId or nil,
    victimInstanceId = victim and victim.instanceId or nil,
    impostorCoinId = impostor and impostor.coinId or nil,
    impostorInstanceId = impostor and impostor.instanceId or nil,
    stolenFamily = stolenFamily,
    originalFamily = impostor and impostor.originalActivationFamily or nil,
    suppressed = impostor ~= nil and stolenFamily == nil,
  }
  context.trace.stolenIdentity = trace
  context.trace.bossTrickEffects = { Utils.clone(trace) }
  return trace
end

function BossTrickSystem.getSlotScaling(snapshot, slotIndex, slotCount)
  if not snapshot or snapshot.trickId ~= "full_throttle" or not slotIndex then return 1 end
  slotCount = math.max(1, tonumber(slotCount) or 3)
  local leadSlotIndex = tonumber(snapshot.leadSlotIndex) or 1
  local routePosition = leadSlotIndex == 1 and slotIndex or (slotCount - slotIndex + 1)
  if routePosition <= 1 then return tonumber(snapshot.leadScaling) or 0.50 end
  if routePosition >= slotCount then return tonumber(snapshot.finishingScaling) or 1.50 end
  return tonumber(snapshot.middleScaling) or 1.00
end

function BossTrickSystem.buildBeforeRollActions(context)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot or snapshot.trickId ~= "the_favourite" then return {} end
  local actions = {}
  for _, coinState in ipairs(context.perCoin or {}) do
    if coinState.smuggled ~= true and coinState.contrabandCopy ~= true then
      table.insert(actions, {
        op = "modify_coin_weight",
        side = snapshot.favouriteSide,
        amount = tonumber(snapshot.chanceShift) or 0.15,
        instanceId = coinState.instanceId,
        resolutionIndex = coinState.resolutionIndex,
        _trace = {
          phase = "before_coin_roll",
          sourceId = snapshot.bossId,
          sourceType = "boss trick",
        },
      })
    end
  end
  return actions
end

function BossTrickSystem.getScoreScaling(snapshot, result)
  if not snapshot or snapshot.trickId ~= "the_favourite" then return 1 end
  if result == snapshot.favouriteSide then
    return tonumber(snapshot.favouriteScoreScaling) or 0.75
  end
  return tonumber(snapshot.underdogScoreScaling) or 1.50
end

function BossTrickSystem.buildCoinScoreActions(context, coinState)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot or snapshot.trickId ~= "the_favourite" or not coinState then return {} end
  local scaling = BossTrickSystem.getScoreScaling(snapshot, coinState.result)
  context.trace.bossTrickEffects = context.trace.bossTrickEffects or {}
  table.insert(context.trace.bossTrickEffects, {
    bossId = snapshot.bossId,
    trickId = snapshot.trickId,
    kind = coinState.result == snapshot.favouriteSide and "favourite_payout" or "underdog_payout",
    favouriteSide = snapshot.favouriteSide,
    coinId = coinState.coinId,
    instanceId = coinState.instanceId,
    resolutionIndex = coinState.resolutionIndex,
    scaling = scaling,
  })
  return {
    {
      op = "apply_score_scaling",
      value = scaling,
      target = "current_coin_score",
      _trace = {
        phase = "before_coin_score",
        sourceId = snapshot.bossId,
        sourceType = "boss trick",
      },
    },
  }
end

local function effectiveSlotIndex(scoreEvent)
  return scoreEvent and (scoreEvent.selectedSlotIndex or scoreEvent.anchorSelectedSlotIndex) or nil
end

local function buildSlotScoreTotals(context)
  local totals = {}
  local packetSlots = {}
  for _, scoreEvent in ipairs(context.scoreBreakdown and context.scoreBreakdown.scoreEvents or {}) do
    local slotIndex = effectiveSlotIndex(scoreEvent)
    if slotIndex then
      totals[slotIndex] = (totals[slotIndex] or 0) + (tonumber(scoreEvent.finalScoreContribution) or 0)
      if scoreEvent.eventId then
        packetSlots["packet_" .. scoreEvent.eventId] = slotIndex
      end
    end
  end
  for _, collection in ipairs({
    context.scoreBreakdown and context.scoreBreakdown.prestigeReplays or {},
    context.scoreBreakdown and context.scoreBreakdown.forgedOutcomeCopies or {},
  }) do
    for _, replay in ipairs(collection) do
      local slotIndex = replay.originSlotIndex or replay.packetSelectedSlotIndex or packetSlots[replay.packetId]
      if slotIndex then
        totals[slotIndex] = (totals[slotIndex] or 0) + (tonumber(replay.replayedScore) or 0)
      end
    end
  end
  for _, bonus in ipairs(context.scoreBreakdown and context.scoreBreakdown.additiveBonuses or {}) do
    local slotIndex = bonus.category == "momentum" and bonus.trace
      and (bonus.trace.originSlotIndex or bonus.trace.slotIndex) or nil
    if slotIndex then
      totals[slotIndex] = (totals[slotIndex] or 0) + (tonumber(bonus.amount) or 0)
    end
  end
  return totals
end

function BossTrickSystem.buildAfterEffectsActions(context)
  local snapshot = context and context.bossTrickSnapshot or nil
  if not snapshot then return {} end

  if snapshot.trickId == "full_throttle" then
    local slotTotals = buildSlotScoreTotals(context)
    local slotCount = math.max(1, tonumber(context.runState
      and (context.runState.maxFlipSlots or context.runState.maxActiveCoinSlots)) or 1)
    local rawTotal = 0
    local scaledTotal = 0
    local slotScalings = {}
    for slotIndex = 1, slotCount do
      local score = tonumber(slotTotals[slotIndex]) or 0
      local scaling = BossTrickSystem.getSlotScaling(snapshot, slotIndex, slotCount)
      rawTotal = rawTotal + score
      scaledTotal = scaledTotal + (score * scaling)
      slotScalings[slotIndex] = scaling
    end
    local adjustment = math.floor(scaledTotal + 0.00001) - math.floor(rawTotal + 0.00001)
    context.trace.bossTrickEffects = context.trace.bossTrickEffects or {}
    table.insert(context.trace.bossTrickEffects, {
      bossId = snapshot.bossId,
      trickId = snapshot.trickId,
      kind = "full_throttle_scaling",
      leadSlotIndex = snapshot.leadSlotIndex,
      slotScoreTotals = Utils.clone(slotTotals),
      slotScalings = slotScalings,
      rawTotal = rawTotal,
      scaledTotal = scaledTotal,
      amount = adjustment,
    })
    if adjustment == 0 then return {} end
    return {
      {
        op = "add_stage_score",
        amount = adjustment,
        category = "boss_trick",
        label = "Full Throttle",
        _trace = {
          phase = "boss_trick_resolution",
          sourceId = snapshot.bossId,
          sourceType = "boss trick",
        },
      },
    }
  end

  if snapshot.trickId == "nothing_to_declare" then
    local taxRate = tonumber(snapshot.taxRate) or 0.30
    local offTheBooksSlotIndex = tonumber(snapshot.offTheBooksSlotIndex)
    local slotCount = math.max(1, tonumber(context.runState
      and (context.runState.maxFlipSlots or context.runState.maxActiveCoinSlots)) or 1)
    local slotTotals = buildSlotScoreTotals(context)
    local slotTaxes = {}
    local attributedTotal = 0
    local taxableTotal = 0
    local totalTax = 0

    for slotIndex, score in pairs(slotTotals) do
      local positiveScore = math.max(0, tonumber(score) or 0)
      attributedTotal = attributedTotal + positiveScore
      if slotIndex ~= offTheBooksSlotIndex then
        local slotTax = math.floor(positiveScore * taxRate + 0.00001)
        slotTaxes[slotIndex] = slotTax
        taxableTotal = taxableTotal + positiveScore
        totalTax = totalTax + slotTax
      else
        slotTaxes[slotIndex] = 0
      end
    end

    local scoreBeforeTax = math.max(0, tonumber(context.scoreBreakdown
      and context.scoreBreakdown.totalStageScoreDelta) or 0)
    local unattributedScore = math.max(0, scoreBeforeTax - attributedTotal)
    local unattributedTax = math.floor(unattributedScore * taxRate + 0.00001)
    taxableTotal = taxableTotal + unattributedScore
    totalTax = math.min(totalTax + unattributedTax, math.floor(scoreBeforeTax + 0.00001))

    local effect = {
      bossId = snapshot.bossId,
      trickId = snapshot.trickId,
      kind = "tax_collected",
      offTheBooksSlotIndex = offTheBooksSlotIndex,
      slotCount = slotCount,
      taxRate = taxRate,
      slotScoreTotals = Utils.clone(slotTotals),
      slotTaxes = slotTaxes,
      attributedTotal = attributedTotal,
      unattributedScore = unattributedScore,
      unattributedTax = unattributedTax,
      taxableTotal = taxableTotal,
      scoreBeforeTax = scoreBeforeTax,
      amount = totalTax,
    }
    context.trace.bossTrickEffects = context.trace.bossTrickEffects or {}
    table.insert(context.trace.bossTrickEffects, effect)
    if totalTax <= 0 then return {} end

    return {
      {
        op = "add_stage_score",
        amount = -totalTax,
        category = "boss_trick",
        label = "Tax Collected",
        _trace = {
          phase = "boss_trick_resolution",
          sourceId = snapshot.bossId,
          sourceType = "boss trick",
        },
      },
    }
  end

  if snapshot.trickId ~= "centre_stage" then return {} end

  local spotlightSlotIndex = snapshot.spotlightSlotIndex
  local slotTotals = buildSlotScoreTotals(context)
  local spotlightScore = tonumber(slotTotals[spotlightSlotIndex]) or 0
  local highestSlotIndex = spotlightSlotIndex
  local highestScore = spotlightScore

  for slotIndex, score in pairs(slotTotals) do
    local winsEqualScore = score == highestScore
      and (slotIndex == spotlightSlotIndex
        or (highestSlotIndex ~= spotlightSlotIndex and slotIndex < highestSlotIndex))
    if score > highestScore or winsEqualScore then
      highestSlotIndex = slotIndex
      highestScore = score
    end
  end

  local effect = {
    bossId = snapshot.bossId,
    trickId = snapshot.trickId,
    spotlightSlotIndex = spotlightSlotIndex,
    spotlightScore = spotlightScore,
    highestSlotIndex = highestSlotIndex,
    highestScore = highestScore,
    slotScoreTotals = Utils.clone(slotTotals),
  }
  context.trace.bossTrickEffects = context.trace.bossTrickEffects or {}

  if highestScore <= 0 then
    effect.kind = "no_score"
    effect.amount = 0
    table.insert(context.trace.bossTrickEffects, effect)
    return {}
  end

  if highestSlotIndex == spotlightSlotIndex then
    local scaling = tonumber(snapshot.encoreScaling) or 0.50
    local amount = math.max(1, math.floor(spotlightScore * scaling + 0.00001))
    effect.kind = "spotlight_encore"
    effect.amount = amount
    effect.scaling = scaling
    table.insert(context.trace.bossTrickEffects, effect)
    return {
      {
        op = "add_stage_score",
        amount = amount,
        category = "boss_trick",
        label = "Centre Stage Encore",
        _trace = {
          phase = "boss_trick_resolution",
          sourceId = snapshot.bossId,
          sourceType = "boss trick",
          slotIndex = spotlightSlotIndex,
        },
      },
    }
  end

  local scaling = tonumber(snapshot.upstagedLossScaling) or 0.50
  local amount = math.floor(highestScore * scaling + 0.00001)
  effect.kind = "upstaged_penalty"
  effect.amount = amount
  effect.scaling = scaling
  table.insert(context.trace.bossTrickEffects, effect)
  if amount <= 0 then return {} end
  return {
    {
      op = "add_stage_score",
      amount = -amount,
      category = "boss_trick",
      label = "Upstaged",
      _trace = {
        phase = "boss_trick_resolution",
        sourceId = snapshot.bossId,
        sourceType = "boss trick",
        slotIndex = highestSlotIndex,
      },
    },
  }
end

return BossTrickSystem
