package.path = "./?.lua;./?/init.lua;" .. package.path

local AcquisitionSystem = require("src.systems.acquisition_system")
local ActionQueue = require("src.core.action_queue")
local EnemySkills = require("src.content.enemy_skills")
local EnemySkillSystem = require("src.systems.enemy_skill_system")
local BossTrickSystem = require("src.systems.boss_trick_system")
local FlipResolver = require("src.systems.flip_resolver")
local PurseSystem = require("src.systems.purse_system")
local RNG = require("src.core.rng")
local RunState = require("src.domain.run_state")
local RunInitializer = require("src.systems.run_initializer")
local StageState = require("src.domain.stage_state")
local TrickBoardSystem = require("src.systems.trick_board_system")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")
local Validator = require("src.core.validator")

local passed = 0

local function check(name, fn)
  local ok, result = xpcall(fn, debug.traceback)
  if not ok then
    io.stderr:write(string.format("%s failed: %s\n", name, tostring(result)))
    os.exit(1)
  end
  passed = passed + 1
end

local function makeRun(seed, purse, tricks, options)
  options = options or {}
  local run = RunInitializer.createNewRun({
    effectiveValues = {},
    unlockedCoinIds = {},
    unlockedTrickIds = {},
  }, {
    seed = seed,
    starterCollection = purse,
    starterPurse = purse,
    ownedTrickIds = tricks or {},
    maxFlipSlots = 3,
    maxActiveTricks = 5,
    baseFlipsPerStage = 3,
    handSize = options.handSize,
  })
  run.currentStageId = "family_trigger_test"
  local stage = StageState.new({
    id = "family_trigger_test",
    label = "Family Trigger Test",
    stageType = "normal",
    opponentHp = 9999,
    opponent = {
      id = "test_opponent",
      name = "Test Opponent",
      enemyClass = "card_shark",
      hp = 9999,
    },
  }, run, { flipsPerStage = 3 })
  stage.trickBoard.pressure = {}
  return run, stage, RNG.new(seed)
end

local function selectDefinitions(run, stage, wanted)
  local chosen = {}
  for _, definitionId in ipairs(wanted) do
    for _, entry in ipairs(PurseSystem.getDealtHandEntries(run, stage)) do
      if entry.coinId == definitionId then
        local already = false
        for _, selected in ipairs(chosen) do
          if selected.instanceId == entry.instanceId then already = true end
        end
        if not already then
          table.insert(chosen, entry)
          break
        end
      end
    end
  end
  assert(#chosen == #wanted, "required test coins were not dealt")
  assert(PurseSystem.setSelectedSlotsFromEntries(run, stage, chosen, { rule = "family_trigger_verify" }))
end

check("matching families activate in board order", function()
  local run, stage, rng = makeRun(11, {
    "copper_weighted_coin",
    "copper_flywheel_coin",
    "copper_bent_coin",
    "copper_blank_coin",
    "copper_marked_coin",
  }, {
    "weighted_palm",
    "encore",
    "keep_it_rolling",
    "follow_through",
    "heads_varnish",
  })
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, {
    "copper_weighted_coin",
    "copper_flywheel_coin",
    "copper_bent_coin",
  })
  run.pendingForcedCoinResults = { "heads", "heads", "heads" }
  local result, err = FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng)
  assert(result, err)
  assert(#(result.trace.activationLedger or {}) >= 5, "expected family-trigger ledger entries")
  assert(#(result.trace.prestigeReplays or {}) >= 1, "Prestige source should Replay")
  assert(result.scoreAppliedToHp > 30, "Tricks should improve the three root Outcomes")
  assert(Validator.validateStageState(run, stage))
end)

check("unplayed coins remain held and played coins become spent", function()
  local run, stage, rng = makeRun(23, {
    "copper_weighted_coin", "copper_flywheel_coin", "copper_bent_coin", "copper_blank_coin",
    "copper_marked_coin", "copper_hollow_coin", "copper_vanishing_coin", "copper_lucky_coin",
  }, {})
  PurseSystem.fillHand(run, stage, rng)
  local dealt = PurseSystem.getDealtHandEntries(run, stage)
  assert(PurseSystem.setSelectedSlotsFromEntries(run, stage, { dealt[1], dealt[2], dealt[3] }))
  run.pendingForcedCoinResults = { "heads", "heads", "heads" }
  local result, err = FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng)
  assert(result, err)
  assert(result.trace.refillEvent.refillRule == "selected_spend_unselected_hold")
  assert(#result.trace.refillEvent.heldInstanceIds == 2)
  assert(#stage.purse.dealtHandSlots == 5)
  assert(#stage.purse.exhaustedInstanceIds == 3)
end)

check("replacement charges are encounter-wide and setup-only", function()
  local run, stage, rng = makeRun(31, {
    "copper_weighted_coin", "copper_flywheel_coin", "copper_bent_coin",
    "copper_blank_coin", "copper_marked_coin", "copper_hollow_coin",
  }, {})
  PurseSystem.fillHand(run, stage, rng)
  local target = stage.purse.dealtHandSlots[1]
  local ok, event = PurseSystem.replaceHeldCoin(run, stage, target.instanceId, rng)
  assert(ok, event)
  assert(event.replacementsRemaining == 2)
  assert(#stage.purse.replacementHistory == 1)
  TrickBoardSystem.setPhase(stage, "locked")
  local selectOk, reason = PurseSystem.selectDealtSlot(run, stage, 1)
  assert(not selectOk and reason == "setup_locked")
  local pressureOk, pressureReason = TrickBoardSystem.setPressure(stage, 1, { kind = "blocked" })
  assert(not pressureOk and pressureReason == "setup_locked")
end)

check("five-Trick capacity requires an explicit replacement", function()
  local run = RunState.new({
    seed = 41,
    starterCollection = { "copper_weighted_coin" },
    starterPurse = { "copper_weighted_coin" },
    ownedTrickIds = {
      "weighted_palm", "encore", "keep_it_rolling", "follow_through", "heads_varnish",
    },
    maxFlipSlots = 3,
    maxActiveTricks = 5,
    baseFlipsPerStage = 3,
  })
  local ok, reason = AcquisitionSystem.grantTrick(run, "vanishing_act")
  assert(not ok and type(reason) == "table" and reason.code == "trick_board_full")
  local replaceOk = AcquisitionSystem.grantTrick(run, "vanishing_act", nil, { replacePosition = 1 })
  assert(replaceOk)
  assert(#run.ownedTrickIds == 5 and run.ownedTrickIds[1] == "vanishing_act")
end)

check("held and removed Tricks cannot occupy active board slots", function()
  local run = RunInitializer.createNewRun({
    effectiveValues = {},
    unlockedCoinIds = {},
    unlockedTrickIds = {},
  }, {
    seed = 47,
    starterCollection = { "copper_weighted_coin" },
    ownedTrickIds = {
      "omen_engine",
      "five_finger_discount",
      "echo_cache",
      "weighted_palm",
    },
  })
  assert(#run.ownedTrickIds == 1 and run.ownedTrickIds[1] == "weighted_palm")
  local ok, reason = AcquisitionSystem.grantTrick(run, "omen_engine")
  assert(not ok and reason == "inactive_trick")
end)

check("Momentum Reactivate wakes the target family without rerunning setup", function()
  local found = false
  for seed = 1, 40 do
    local run, stage, rng = makeRun(seed, {
      "copper_weighted_coin",
      "copper_flywheel_coin",
      "copper_bent_coin",
      "copper_blank_coin",
      "copper_marked_coin",
    }, {
      "ripple_ii",
      "follow_through",
      "weighted_palm",
      "encore",
      "curtain_call",
    })
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, {
      "copper_weighted_coin",
      "copper_flywheel_coin",
      "copper_bent_coin",
    })
    run.pendingForcedCoinResults = { "heads", "heads", "heads" }
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    if (result.trace.activationEventsResolved or 0) > 0 then
      local sawReactivatedWeighted = false
      for _, entry in ipairs(result.trace.activationLedger or {}) do
        if entry.kind == "reactivation" and entry.family == "weighted" and entry.trickId == "weighted_palm" then
          sawReactivatedWeighted = true
        end
      end
      assert(sawReactivatedWeighted, "reactivated Weighted source did not wake Weighted Palm")
      found = true
      break
    end
  end
  assert(found, "no seeded Momentum reactivation succeeded")
end)

check("Repeat resolves one named Trick without family fan-out or base score", function()
  local generator = assert(Upgrades.getById("weighted_tail_coating"))
  local originalTriggers = generator.triggers
  generator.triggers = {
    {
      hook = "after_all_effects",
      effects = {
        { op = "repeat_trick", trickId = "heads_varnish", phase = "before_coin_roll" },
      },
    },
  }

  local ok, errorMessage = xpcall(function()
    local run, stage, rng = makeRun(61, {
      "copper_weighted_coin",
      "copper_blank_coin",
      "copper_bent_coin",
      "copper_marked_coin",
      "copper_flywheel_coin",
    }, {
      "weighted_tail_coating",
      "heads_varnish",
      "weighted_palm",
    })
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, { "copper_weighted_coin" })
    run.pendingForcedCoinResults = { "heads" }
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    local repeats = 0
    for _, entry in ipairs(result.trace.activationLedger or {}) do
      if entry.kind == "repeat" and entry.trickId == "heads_varnish" then
        repeats = repeats + 1
      end
    end
    assert(repeats == 1, "Repeat should resolve exactly the named Trick once")
    assert((result.trace.activationEventsResolved or 0) == 1, "Repeat should consume one generated activation event")
  end, debug.traceback)
  generator.triggers = originalTriggers
  assert(ok, errorMessage)
end)

check("family-aware commitment materially beats an equal off-family coin", function()
  local function scoreCoin(coinId)
    local run, stage, rng = makeRun(73, {
      coinId,
      "copper_bent_coin",
      "copper_marked_coin",
      "copper_flywheel_coin",
      "copper_hollow_coin",
    }, {
      "heads_varnish",
      "weighted_palm",
    })
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, { coinId })
    run.pendingForcedCoinResults = { "heads" }
    return assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng)).scoreAppliedToHp
  end

  local matchingScore = scoreCoin("copper_weighted_coin")
  local offFamilyScore = scoreCoin("copper_blank_coin")
  assert(matchingScore > offFamilyScore, "matching family choice should produce a stronger Outcome")
  assert(matchingScore >= offFamilyScore * 1.4, "family choice should be materially, not marginally, stronger")
end)

check("native Tier II/III Tricks upgrade their line in place", function()
  local run = RunState.new({
    seed = 83,
    starterCollection = { "copper_weighted_coin" },
    starterPurse = { "copper_weighted_coin" },
    ownedTrickIds = {
      "weighted_palm", "encore", "keep_it_rolling", "borrowed_name", "switcheroo",
    },
    maxActiveTricks = 5,
  })
  assert(AcquisitionSystem.grantTrick(run, "weighted_palm_ii"))
  assert(#run.ownedTrickIds == 5 and run.ownedTrickIds[1] == "weighted_palm_ii")
  assert(AcquisitionSystem.grantTrick(run, "weighted_palm_iii"))
  assert(#run.ownedTrickIds == 5 and run.ownedTrickIds[1] == "weighted_palm_iii")
  local lowerOk, lowerReason = AcquisitionSystem.grantTrick(run, "weighted_palm_ii")
  assert(not lowerOk and lowerReason == "lower_or_equal_tier")
end)

check("Block and Jam produce traceable prevented activations", function()
  local run, stage, rng = makeRun(97, {
    "copper_weighted_coin",
    "silver_weighted_coin",
    "copper_blank_coin",
    "copper_bent_coin",
    "copper_marked_coin",
  }, {
    "heads_varnish",
    "weighted_palm",
  })
  assert(TrickBoardSystem.setPressure(stage, 1, { kind = "blocked", sourceId = "test_block" }))
  assert(TrickBoardSystem.setPressure(stage, 2, { kind = "jammed", sourceId = "test_jam", maxActivations = 1 }))
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_weighted_coin", "silver_weighted_coin" })
  run.pendingForcedCoinResults = { "heads", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local sawBlock = false
  local sawJam = false
  for _, entry in ipairs(result.trace.preventedActivations or {}) do
    sawBlock = sawBlock or entry.reason == "trick_blocked"
    sawJam = sawJam or entry.reason == "trick_jammed"
  end
  assert(sawBlock, "blocked Trick attempts should be traced")
  assert(sawJam, "jammed Trick attempts after the first activation should be traced")
end)

check("Prestige and Momentum expose complete three-by-three tier grids", function()
  local expected = {
    prestige = {
      encore = { encore = 1, encore_ii = 2, encore_iii = 3 },
      curtain_call = { curtain_call = 1, curtain_call_ii = 2, curtain_call_iii = 3 },
      impossible_finale = { impossible_finale = 1, impossible_finale_ii = 2, impossible_finale_iii = 3 },
    },
    momentum = {
      keep_it_rolling = { keep_it_rolling = 1, keep_it_rolling_ii = 2, keep_it_rolling_iii = 3 },
      follow_through = { follow_through = 1, follow_through_ii = 2, follow_through_iii = 3 },
      ripple = { ripple = 1, ripple_ii = 2, ripple_iii = 3 },
    },
  }

  for family, lines in pairs(expected) do
    local activeCount = 0
    for _, definition in ipairs(Upgrades.getAll()) do
      if definition.trick and definition.trick.activationFamily == family and definition.rewardEligible ~= false then
        activeCount = activeCount + 1
      end
    end
    assert(activeCount == 9, family .. " should have exactly nine active Tricks")

    for lineId, ids in pairs(lines) do
      for id, tier in pairs(ids) do
        local definition = assert(Upgrades.getById(id))
        assert(Upgrades.getLineId(definition) == lineId, id .. " line mismatch")
        assert(Upgrades.getTier(definition) == tier, id .. " tier mismatch")
        assert(definition.rewardEligible ~= false, id .. " should be reward eligible")
      end
    end
  end

  assert(Upgrades.getById("steady_hand").rewardEligible == false)
  assert(Upgrades.getById("see_behind_the_veil").rewardEligible == false)

  local function findEffect(id, op)
    for _, trigger in ipairs(assert(Upgrades.getById(id)).triggers or {}) do
      for _, effect in ipairs(trigger.effects or {}) do
        if effect.op == op then return effect end
      end
    end
    error(string.format("%s missing %s effect", id, op))
  end

  for index, id in ipairs({ "encore", "encore_ii", "encore_iii" }) do
    assert(findEffect(id, "replay_resolution_packet").scale == ({ 0.20, 0.30, 0.40 })[index])
  end
  for index, id in ipairs({ "curtain_call", "curtain_call_ii", "curtain_call_iii" }) do
    local effect = findEffect(id, "replay_resolution_packet")
    assert(effect.count == index and effect.scale == ({ 0.20, 0.30, 0.40 })[index])
  end
  for index, id in ipairs({ "impossible_finale", "impossible_finale_ii", "impossible_finale_iii" }) do
    local effect = findEffect(id, "replay_resolution_packet")
    assert(effect.count == index and effect.scale == ({ 0.20, 0.30, 0.40 })[index])
  end
  for index, id in ipairs({ "keep_it_rolling", "keep_it_rolling_ii", "keep_it_rolling_iii" }) do
    assert(findEffect(id, "replay_resolution_packet").chance == ({ 0.50, 0.75, 1.00 })[index])
  end
  for index, id in ipairs({ "follow_through", "follow_through_ii", "follow_through_iii" }) do
    assert(findEffect(id, "apply_score_scaling").chainDepthBonus == ({ 0.25, 0.50, 0.75 })[index])
  end
end)

check("Weighted values are symmetric and use the reduced rounded Palm curve", function()
  local function findEffect(id, op)
    for _, trigger in ipairs(assert(Upgrades.getById(id)).triggers or {}) do
      for _, effect in ipairs(trigger.effects or {}) do
        if effect.op == op then return effect end
      end
    end
    error(string.format("%s missing %s effect", id, op))
  end

  assert(findEffect("heads_varnish", "add_weight").amount == 0.15)
  assert(findEffect("weighted_tail_coating", "add_weight").amount == 0.15)

  local ids = { "weighted_palm", "weighted_palm_ii", "weighted_palm_iii" }
  local chances = { 0.65, 0.75, 0.85 }
  local multipliers = { 1.45, 1.65, 1.85 }
  for index, id in ipairs(ids) do
    assert(findEffect(id, "set_call_match_chance").chance == chances[index])
    assert(findEffect(id, "apply_score_scaling").value == multipliers[index])
  end
end)

check("Prediction Coin fulfills the encounter's visible slot result", function()
  local run, stage, rng = makeRun(109, {
    "copper_marked_coin",
    "copper_weighted_coin",
    "copper_blank_coin",
    "copper_bent_coin",
    "copper_flywheel_coin",
    "copper_hollow_coin",
    "copper_vanishing_coin",
    "copper_lucky_coin",
  }, {
    "fulfilled_fate",
    "read_the_stars",
    "written_in_the_stars",
    "defy_fate",
  })
  PurseSystem.fillHand(run, stage, rng)

  local marked
  local others = {}
  for _, entry in ipairs(PurseSystem.getDealtHandEntries(run, stage)) do
    if entry.coinId == "copper_marked_coin" and not marked then
      marked = entry
    else
      table.insert(others, entry)
    end
  end
  assert(marked and #others >= 2)

  local selected = { others[1], others[2], others[2] }
  selected[stage.predictionSlot.slotIndex] = marked
  local used = { [marked.instanceId] = true }
  local fillIndex = 1
  for slotIndex = 1, 3 do
    if selected[slotIndex] == marked or used[selected[slotIndex] and selected[slotIndex].instanceId] then
      if selected[slotIndex] ~= marked then
        while others[fillIndex] and used[others[fillIndex].instanceId] do fillIndex = fillIndex + 1 end
        selected[slotIndex] = assert(others[fillIndex])
      end
    end
    used[selected[slotIndex].instanceId] = true
  end

  assert(PurseSystem.setSelectedSlotsFromEntries(run, stage, selected, { rule = "prediction_slot_verify" }))
  local oppositeCall = stage.predictionSlot.result == "heads" and "tails" or "heads"
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, oppositeCall, rng))
  local markedResult
  for _, coinState in ipairs(result.perCoin or {}) do
    if coinState.instanceId == marked.instanceId then
      markedResult = coinState
      break
    end
  end
  assert(markedResult and markedResult.result == stage.predictionSlot.result)
  assert(markedResult.forcedReason == "prediction_slot")
  assert(markedResult.selectedSlotIndex == stage.predictionSlot.slotIndex)
  assert(result.trace.predictionSlot.result == stage.predictionSlot.result)
end)

check("Prediction exposes four complete lines with bounded neighbour effects", function()
  local expected = {
    fulfilled_fate = { "fulfilled_fate", "fulfilled_fate_ii", "fulfilled_fate_iii" },
    read_the_stars = { "read_the_stars", "read_the_stars_ii", "read_the_stars_iii" },
    written_in_the_stars = { "written_in_the_stars", "written_in_the_stars_ii", "written_in_the_stars_iii" },
    defy_fate = { "defy_fate", "defy_fate_ii", "defy_fate_iii" },
  }
  local activeCount = 0
  for _, definition in ipairs(Upgrades.getAll()) do
    if definition.trick and definition.trick.activationFamily == "prediction" and definition.rewardEligible ~= false then
      activeCount = activeCount + 1
    end
  end
  assert(activeCount == 12)
  for lineId, ids in pairs(expected) do
    for tier, id in ipairs(ids) do
      local definition = assert(Upgrades.getById(id))
      assert(Upgrades.getLineId(definition) == lineId)
      assert(Upgrades.getTier(definition) == tier)
    end
  end
  assert(Upgrades.getById("heads_contract").rewardEligible == false)
  assert(Upgrades.getById("tails_contract").rewardEligible == false)

  local left = { coinId = "copper_bent_coin", instanceId = "left", selectedSlotIndex = 1, resolutionIndex = 1,
    headsWeight = 0.5, tailsWeight = 0.5, result = "heads" }
  local source = { coinId = "copper_marked_coin", instanceId = "source", selectedSlotIndex = 2, resolutionIndex = 2,
    headsWeight = 0.5, tailsWeight = 0.5, result = "heads", foretold = true, foretoldResult = "heads" }
  local right = { coinId = "copper_weighted_coin", instanceId = "right", selectedSlotIndex = 3, resolutionIndex = 3,
    headsWeight = 0.5, tailsWeight = 0.5, result = "tails" }
  local context = ActionQueue.createContext("batch", {
    call = "heads",
    currentCoin = source,
    perCoin = { left, source, right },
  })
  ActionQueue.applyAll({}, nil, context, {
    { op = "add_weight", side = "foretold", amount = 0.1, target = {
      zone = "selected_coins",
      filters = { { op = "neighbor_of_current" } },
      orderBy = "slot_position",
      pick = { op = "all" },
    } },
    { op = "amplify_foretold_neighbors", value = 1.2, requireTargetMatch = true },
  })
  assert(math.abs(left.headsWeight - 0.6) < 0.00001)
  assert(math.abs(right.headsWeight - 0.6) < 0.00001)
  assert(left.rootScoreScalingMultiplier == 1.2)
  assert(right.rootScoreScalingMultiplier == nil, "Read the Stars should not amplify a missing neighbour")

  context.call = "tails"
  right.result = "tails"
  ActionQueue.applyAll({}, nil, context, {
    { op = "amplify_foretold_neighbors", value = 1.5, requireTargetMatch = true, sacrificeSource = true },
  })
  assert(source.predictionSacrificed == true)
  assert(right.rootScoreScalingMultiplier == 1.5)
end)

check("Forgery exposes three complete tier lines", function()
  local expected = {
    fake_credentials = { "fake_credentials", "fake_credentials_ii", "fake_credentials_iii" },
    borrowed_name = { "borrowed_name", "borrowed_name_ii", "borrowed_name_iii" },
    forged_signature = { "forged_signature", "forged_signature_ii", "forged_signature_iii" },
  }
  local activeCount = 0
  for _, definition in ipairs(Upgrades.getAll()) do
    if definition.trick and definition.trick.activationFamily == "forgery" and definition.rewardEligible ~= false then
      activeCount = activeCount + 1
    end
  end
  assert(activeCount == 9)
  for lineId, ids in pairs(expected) do
    for tier, id in ipairs(ids) do
      local definition = assert(Upgrades.getById(id))
      assert(Upgrades.getLineId(definition) == lineId)
      assert(Upgrades.getTier(definition) == tier)
    end
  end

  local activation = require("src.systems.trick_activation_system").newActivation({ activationSequence = 0 }, {
    coinId = "copper_blank_coin",
    instanceId = "recursive_blank",
    resolutionIndex = 2,
  }, "reactivation", {
    activationId = "forged_parent",
    chainDepth = 1,
    forged = true,
  })
  assert(activation.forged == true, "descendants of forged activations must remain recursion-blocked")
end)

check("Fake Credentials copies the genuine left neighbour Outcome", function()
  local run, stage, rng = makeRun(127, {
    "copper_weighted_coin", "copper_blank_coin", "copper_bent_coin",
    "copper_marked_coin", "copper_flywheel_coin",
  }, { "fake_credentials_iii" })
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_weighted_coin", "copper_blank_coin", "copper_bent_coin" })
  run.pendingForcedCoinResults = { "heads", "tails", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local copied = assert((result.trace.forgedOutcomeCopies or {})[1])
  assert(copied.packetCoinId == "copper_weighted_coin")
  assert(copied.packetResolutionIndex == 1)
  assert(copied.scale == 1)
  assert(copied.forgedOutcomeCopy == true)
  assert(#(result.trace.forgedOutcomeCopies or {}) == 1)
end)

check("Borrowed Name and Forged Signature enhance a genuine left family without recursion", function()
  local run, stage, rng = makeRun(131, {
    "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin",
    "copper_marked_coin", "copper_flywheel_coin",
  }, {
    "encore",
    "curtain_call_ii",
    "impossible_finale_iii",
    "borrowed_name_iii",
    "forged_signature_iii",
  })
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin" })
  local previewById = {}
  for _, entry in ipairs(TrickBoardSystem.getActivationPreview(run, stage)) do
    previewById[entry.trickId] = entry
  end
  assert(previewById.encore.forgedActivationCount == 1)
  assert(previewById.curtain_call_ii.forgedActivationCount == 1)
  assert(previewById.impossible_finale_iii.forgedActivationCount == 2)
  run.pendingForcedCoinResults = { "heads", "heads", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local borrowed = 0
  local signatures = 0
  local signatureTarget
  for _, entry in ipairs(result.trace.forgedActivations or {}) do
    assert(entry.forged == true)
    assert(entry.family == "prestige")
    assert(entry.coinId == "copper_blank_coin")
    assert(entry.genuineSourceCoinId == "copper_bent_coin")
    assert(entry.chainDepth == 1)
    if entry.kind == "borrowed_name" then
      borrowed = borrowed + 1
    elseif entry.kind == "forged_signature" then
      signatures = signatures + 1
      signatureTarget = entry.trickId
    end
  end
  assert(borrowed == 3, "Borrowed Name III should imitate up to three eligible Tricks")
  assert(signatures == 1, "Forged Signature should repeat exactly one Trick")
  assert(signatureTarget == "impossible_finale_iii", "Signature III should prefer the highest-tier eligible Trick")
  assert(#(result.trace.forgedActivations or {}) == 4, "forged activations must remain bounded")
end)

check("Forgery locks one bounded target package before pre-roll Weighted hooks", function()
  local run, stage, rng = makeRun(137, {
    "copper_weighted_coin", "copper_blank_coin", "copper_bent_coin",
    "copper_marked_coin", "copper_flywheel_coin",
  }, {
    "heads_varnish",
    "weighted_palm_iii",
    "borrowed_name_iii",
  })
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_weighted_coin", "copper_blank_coin", "copper_bent_coin" })
  run.pendingForcedCoinResults = { "heads", "heads", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local blank = assert(result.perCoin[2])
  assert(blank.coinId == "copper_blank_coin")
  assert(blank.actingFamily == "weighted")
  assert(blank.forgerySourceCoinId == "copper_weighted_coin")
  assert(math.abs(blank.headsWeight - 0.85) < 0.00001, "copied Weighted setup package should rig the Blank before rolling")

  local assignment = assert((result.trace.forgeryAssignments or {})[1])
  assert(assignment.actingFamily == "weighted")
  assert(assignment.direction == "left")
  local plan = assert(assignment.plans[1])
  assert(#plan.targetTrickIds == 2, "Borrowed Name must lock one global Trick set, not a fresh set per phase")
  assert(plan.targetTrickIds[1] == "heads_varnish")
  assert(plan.targetTrickIds[2] == "weighted_palm_iii")

  local sawHeadsideBeforeRoll = false
  local sawPalmBeforeRoll = false
  for _, activation in ipairs(result.trace.forgedActivations or {}) do
    if activation.phase == "before_coin_roll" and activation.trickId == "heads_varnish" then
      sawHeadsideBeforeRoll = true
    elseif activation.phase == "before_coin_roll" and activation.trickId == "weighted_palm_iii" then
      sawPalmBeforeRoll = true
    end
  end
  assert(sawHeadsideBeforeRoll and sawPalmBeforeRoll, "Forgery should reach pre-roll Weighted hooks")
end)

check("Forgery acting as Prediction can fulfill the visible forecast slot", function()
  local run, stage, rng
  for seed = 139, 180 do
    local candidateRun, candidateStage, candidateRng = makeRun(seed, {
      "copper_marked_coin", "copper_blank_coin", "copper_weighted_coin",
      "copper_bent_coin", "copper_flywheel_coin",
    }, {
      "written_in_the_stars_iii",
      "fulfilled_fate_iii",
      "borrowed_name_iii",
    })
    if candidateStage.predictionSlot and candidateStage.predictionSlot.slotIndex >= 2 then
      run, stage, rng = candidateRun, candidateStage, candidateRng
      break
    end
  end
  assert(run and stage and rng, "expected a deterministic non-first Prediction slot seed")
  PurseSystem.fillHand(run, stage, rng)

  local byCoinId = {}
  for _, entry in ipairs(PurseSystem.getDealtHandEntries(run, stage)) do byCoinId[entry.coinId] = entry end
  local selected = {}
  local forecastIndex = stage.predictionSlot.slotIndex
  selected[forecastIndex - 1] = assert(byCoinId.copper_marked_coin)
  selected[forecastIndex] = assert(byCoinId.copper_blank_coin)
  local fillers = { byCoinId.copper_weighted_coin, byCoinId.copper_bent_coin, byCoinId.copper_flywheel_coin }
  local fillerIndex = 1
  for index = 1, 3 do
    if not selected[index] then
      selected[index] = assert(fillers[fillerIndex])
      fillerIndex = fillerIndex + 1
    end
  end
  assert(PurseSystem.setSelectedSlotsFromEntries(run, stage, selected, { rule = "forgery_prediction_verify" }))

  local call = stage.predictionSlot.result
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, call, rng))
  local blank
  for _, coinState in ipairs(result.perCoin or {}) do
    if coinState.coinId == "copper_blank_coin" then blank = coinState break end
  end
  assert(blank and blank.actingFamily == "prediction")
  assert(blank.foretold == true and blank.foretoldResult == call)
  assert(blank.forcedReason == "prediction_slot" and blank.result == call)

  local phases = {}
  for _, activation in ipairs(result.trace.forgedActivations or {}) do
    phases[activation.trickId .. ":" .. activation.phase] = true
  end
  assert(phases["written_in_the_stars_iii:before_coin_roll"], "Forgery should reach Prediction setup hooks")
  assert(phases["fulfilled_fate_iii:before_coin_score"], "the disguised Blank should satisfy Foretold payoff conditions")
end)

check("Forgery carries a locked Momentum package into after-score hooks", function()
  local run, stage, rng = makeRun(173, {
    "copper_flywheel_coin", "copper_blank_coin", "copper_weighted_coin",
    "copper_marked_coin", "copper_bent_coin",
  }, {
    "keep_it_rolling_iii",
    "borrowed_name_iii",
  })
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_flywheel_coin", "copper_blank_coin", "copper_weighted_coin" })
  run.pendingForcedCoinResults = { "heads", "heads", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local sawMomentum = false
  for _, activation in ipairs(result.trace.forgedActivations or {}) do
    if activation.family == "momentum" and activation.trickId == "keep_it_rolling_iii"
      and activation.phase == "after_coin_score" then
      sawMomentum = true
    end
  end
  assert(sawMomentum, "Forgery should reach Momentum after-score hooks")
end)

check("Forgery carries a locked Sleight package into post-result hooks", function()
  local run, stage, rng = makeRun(179, {
    "copper_vanishing_coin", "copper_blank_coin", "copper_weighted_coin",
    "copper_marked_coin", "copper_bent_coin",
  }, {
    "vanishing_act",
    "borrowed_name",
  })
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_vanishing_coin", "copper_blank_coin", "copper_weighted_coin" })
  run.pendingForcedCoinResults = { "heads", "tails", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local blank = assert(result.perCoin[2])
  assert(blank.actingFamily == "sleight")
  assert(blank.palmed == true and blank.sleightSaved == true, "copied Vanishing Act should save the missing Blank")
  local sawSleight = false
  for _, activation in ipairs(result.trace.forgedActivations or {}) do
    if activation.family == "sleight" and activation.trickId == "vanishing_act"
      and activation.phase == "after_flip_before_score" then
      sawSleight = true
    end
  end
  assert(sawSleight, "Forgery should reach Sleight post-result hooks")
end)

check("Fake Credentials follows its locked source body through Sleight movement", function()
  local result, sourceInstanceId
  for seed = 180, 500 do
    local run, stage, rng = makeRun(seed, {
      "gold_bent_coin", "copper_blank_coin", "copper_vanishing_coin",
      "copper_marked_coin", "copper_weighted_coin",
    }, {
      "switcheroo_iii",
      "fake_credentials_iii",
    })
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, { "gold_bent_coin", "copper_blank_coin", "copper_vanishing_coin" })
    local candidateSourceId = assert(PurseSystem.getSelectedSlotEntries(run, stage)[1]).instanceId
    local candidate = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    if #(candidate.trace.sleightMoves or {}) >= 1 and #(candidate.trace.forgedOutcomeCopies or {}) >= 1 then
      result, sourceInstanceId = candidate, candidateSourceId
      break
    end
  end
  assert(result and sourceInstanceId, "expected a deterministic Sleight movement plus Fake Credentials seed")
  local copied = assert((result.trace.forgedOutcomeCopies or {})[1])
  assert(copied.packetInstanceId == sourceInstanceId, "Fake Credentials must follow the setup-locked genuine body")
  assert(copied.packetCoinId == "gold_bent_coin")
end)

check("Forgery can add a second Smuggling overload before the Flip", function()
  local purse = {
    "copper_hollow_coin", "copper_blank_coin", "copper_weighted_coin",
    "silver_hollow_coin", "gold_hollow_coin",
    "copper_marked_coin", "copper_bent_coin", "copper_flywheel_coin",
  }
  local tricks = { "hidden_in_plain_sight", "borrowed_name" }
  local run, stage, rng
  for seed = 181, 500 do
    local candidateRun, candidateStage, candidateRng = makeRun(seed, purse, tricks)
    PurseSystem.fillHand(candidateRun, candidateStage, candidateRng)
    local present = {}
    for _, entry in ipairs(PurseSystem.getDealtHandEntries(candidateRun, candidateStage)) do
      present[entry.coinId] = true
    end
    if present.copper_hollow_coin and present.copper_blank_coin and present.copper_weighted_coin
      and present.silver_hollow_coin and present.gold_hollow_coin then
      run, stage, rng = candidateRun, candidateStage, candidateRng
      break
    end
  end
  assert(run and stage and rng, "expected a deterministic five-card Smuggling test hand")
  selectDefinitions(run, stage, { "copper_hollow_coin", "copper_blank_coin", "copper_weighted_coin" })
  run.pendingForcedCoinResults = { "heads", "heads", "heads", "heads", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local dealtDebug = {}
  for _, entry in ipairs(result.trace.dealtHand or {}) do
    table.insert(dealtDebug, string.format("%s(sel=%s,sm=%s)", entry.coinId, tostring(entry.selectedSlotIndex), tostring(entry.smuggled)))
  end
  assert(#(result.trace.boardSlots or {}) == 2, string.format(
    "real and forged Smuggling activations should fill two overload slots (got %d; forged=%d; warnings=%s; dealt=%s)",
    #(result.trace.boardSlots or {}),
    #(result.trace.forgedActivations or {}),
    table.concat(result.trace.warnings or {}, " | "),
    table.concat(dealtDebug, ",")
  ))
  assert(result.perCoin[2].actingFamily == "smuggle")

  local sawForgedSmuggling = false
  for _, activation in ipairs(result.trace.forgedActivations or {}) do
    if activation.family == "smuggle" and activation.trickId == "hidden_in_plain_sight"
      and activation.phase == "after_call_before_flip" then
      sawForgedSmuggling = true
    end
  end
  assert(sawForgedSmuggling, "Forgery should reach pre-Flip Smuggling hooks")
end)

check("enemy skills are round-gated and each encounter carries exactly one", function()
  local roundTwo = EnemySkills.getEligible(2, { hasActiveTricks = true })
  local roundThree = EnemySkills.getEligible(3, { hasActiveTricks = true })
  local roundFour = EnemySkills.getEligible(4, { hasActiveTricks = true })
  local roundFive = EnemySkills.getEligible(5, { hasActiveTricks = true })
  local roundThreeIds = {}
  local roundFourIds = {}
  local roundFiveIds = {}
  for _, definition in ipairs(roundThree) do roundThreeIds[definition.id] = true end
  for _, definition in ipairs(roundFour) do roundFourIds[definition.id] = true end
  for _, definition in ipairs(roundFive) do roundFiveIds[definition.id] = true end
  assert(#roundTwo == 0, "the first two encounters must not assign an Enemy Trick")
  assert(roundThreeIds.weakened_charm and roundThreeIds.tarnished_slot,
    "rank-1 Enemy Tricks should teach the mechanic in encounter 3")
  assert(not roundThreeIds.jammed_charm and not roundThreeIds.lifesteal_slot,
    "rank-2 Enemy Tricks must remain locked until encounter 4")
  assert(roundFourIds.jammed_charm and roundFourIds.lifesteal_slot)
  assert(not roundFourIds.blocked_charm and not roundFourIds.poisoned_charm,
    "rank-3 Enemy Tricks must remain locked until encounter 5")
  assert(roundFiveIds.blocked_charm, "Block should unlock at round 5")
  assert(roundFiveIds.poisoned_charm, "Poison should unlock at round 5")

  local graceRun, graceStage = makeRun(191, { "copper_weighted_coin" }, { "weighted_palm" })
  graceRun.roundIndex = 2
  assert(EnemySkillSystem.prepareIntent(graceRun, graceStage) == nil,
    "encounter 2 should create no Enemy Trick intent")
  assert(graceStage.enemySkill.skillId == nil and next(graceStage.trickBoard.pressure) == nil)

  local run, stage = makeRun(197, { "copper_weighted_coin" }, { "weighted_palm" })
  run.roundIndex = 5
  local snapshot = assert(EnemySkillSystem.prepareIntent(run, stage, {
    skillId = "blocked_charm",
    targetIndex = 1,
  }))
  assert(snapshot.difficultyRank == 3, "fixture must exercise a high-rank Enemy Trick")
  assert(snapshot.skillId and snapshot.targetIndex)
  local pressureCount = 0
  for _ in pairs(stage.trickBoard.pressure or {}) do pressureCount = pressureCount + 1 end
  for _ in pairs(stage.enemySkill.slotPressure or {}) do pressureCount = pressureCount + 1 end
  assert(pressureCount == 1, "a rank-3 Enemy Trick must still apply exactly one pressure")

  local skillId = snapshot.skillId
  stage.batchIndex = 1
  local nextSnapshot = assert(EnemySkillSystem.prepareIntent(run, stage))
  assert(nextSnapshot.skillId == skillId, "the enemy must keep one skill for the encounter")
end)

check("bosses never receive regular Enemy Tricks", function()
  local run = RunInitializer.createNewRun({
    effectiveValues = {},
    unlockedCoinIds = {},
    unlockedTrickIds = {},
  }, {
    seed = 198,
    starterCollection = { "copper_weighted_coin" },
    ownedTrickIds = { "weighted_palm" },
    maxFlipSlots = 3,
    maxActiveTricks = 5,
    baseFlipsPerStage = 3,
  })
  run.roundIndex = 5
  local stage = StageState.new({
    id = "boss_enemy_trick_boundary",
    label = "Boss Enemy Trick Boundary",
    stageType = "boss",
    opponentHp = 100,
    opponent = {
      id = "boss_enemy_trick_boundary",
      name = "Test Boss",
      hp = 100,
    },
  }, run, { flipsPerStage = 3 })

  assert(EnemySkillSystem.prepareIntent(run, stage, {
    skillId = "poisoned_charm",
    targetIndex = 1,
  }) == nil, "even an explicit regular Enemy Trick override must be rejected for a boss")
  assert(stage.enemySkill.skillId == nil)
  assert(next(stage.enemySkill.slotPressure) == nil)
  assert(next(stage.trickBoard.pressure) == nil)
  assert(Validator.validateStageState(run, stage))
end)

check("Betting Betty selects and applies The Favourite on every Flip", function()
  local function resolve(call)
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = 202,
      starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin" },
      ownedTrickIds = {},
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = 3,
    })
    run.roundIndex = 4
    run.currentStageId = "betting_betty_test"
    local stage = StageState.new({
      id = "betting_betty_test",
      label = "Betting Betty Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "betting_betty" },
      opponent = {
        id = "betting_betty",
        name = "Betting Betty",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    assert(BossTrickSystem.prepareIntent(run, stage, { favouriteSide = "heads" }))
    local rng = RNG.new(202)
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, { "copper_bent_coin" })
    run.pendingForcedCoinResults = { call }
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, call, rng))
    return result, stage
  end

  local favourite, favouriteStage = resolve("heads")
  local underdog = resolve("tails")
  assert(favourite.trace.bossTrickSnapshot.bossId == "betting_betty")
  assert(favourite.trace.bossTrickSnapshot.trickId == "the_favourite")
  assert(favourite.trace.bossTrickSnapshot.favouriteSide == "heads")
  assert(math.abs((favourite.perCoin[1].headsWeight or 0) - 0.65) < 0.00001,
    "The Favourite should add 15 percentage points toward Heads")
  assert(underdog.scoreAppliedToHp > favourite.scoreAppliedToHp * 2,
    "the 150% underdog payout should exceed the rounded 75% favourite payout")
  assert(favouriteStage.bossTrick.intentIndex == 2,
    "Betting Betty should select the next favourite before the following setup")
  assert(favouriteStage.bossTrick.favouriteSide == "heads"
    or favouriteStage.bossTrick.favouriteSide == "tails")
end)

check("Washed-up Magician resolves Centre Stage after each Flip", function()
  local function resolve(forcedResults, selectedCoins)
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = 303,
      starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin" },
      ownedTrickIds = {},
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = 3,
    })
    run.roundIndex = 4
    run.currentStageId = "washed_up_magician_test"
    local stage = StageState.new({
      id = "washed_up_magician_test",
      label = "Washed-up Magician Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "washed_up_magician" },
      opponent = {
        id = "washed_up_magician",
        name = "Washed-up Magician",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    assert(BossTrickSystem.prepareIntent(run, stage, { spotlightSlotIndex = 1 }))
    local rng = RNG.new(303)
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, selectedCoins)
    run.pendingForcedCoinResults = forcedResults
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    return result, stage
  end

  local encore, encoreStage = resolve({ "heads" }, { "copper_bent_coin" })
  assert(encore.trace.bossTrickSnapshot.bossId == "washed_up_magician")
  assert(encore.trace.bossTrickSnapshot.trickId == "centre_stage")
  assert(encore.trace.bossTrickSnapshot.spotlightSlotIndex == 1)
  assert(encore.scoreAppliedToHp == 15, "the winning Spotlight should Encore its 10 Score at 50%")
  assert(encore.trace.bossTrickEffects[1].kind == "spotlight_encore")
  assert(encore.trace.bossTrickEffects[1].amount == 5)
  assert(encoreStage.bossTrick.intentIndex == 2,
    "Washed-up Magician should select the next Spotlight before the following setup")
  assert(encoreStage.bossTrick.spotlightSlotIndex >= 1
    and encoreStage.bossTrick.spotlightSlotIndex <= 3)

  local tie = resolve(
    { "heads", "heads" },
    { "copper_bent_coin", "copper_blank_coin" }
  )
  assert(tie.scoreAppliedToHp == 25, "the Spotlight should win a 10–10 tie and Encore at 50%")
  assert(tie.trace.bossTrickEffects[1].kind == "spotlight_encore")

  local upstaged = resolve(
    { "tails", "heads" },
    { "copper_bent_coin", "copper_blank_coin" }
  )
  assert(upstaged.scoreAppliedToHp == 5,
    "a 10-Score non-Spotlight winner should lose 50% of its Score")
  assert(upstaged.trace.bossTrickEffects[1].kind == "upstaged_penalty")
  assert(upstaged.trace.bossTrickEffects[1].highestSlotIndex == 2)
  assert(upstaged.trace.bossTrickEffects[1].amount == 5)
end)

check("Madcap Lunatic applies Full Throttle by revealed slot order", function()
  local function resolve(leadSlotIndex, forcedResults, tricks)
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = 404,
      starterCollection = { "copper_blank_coin", "copper_weighted_coin", "copper_bent_coin" },
      ownedTrickIds = tricks or {},
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = 3,
    })
    run.roundIndex = 4
    run.currentStageId = "madcap_lunatic_test"
    local stage = StageState.new({
      id = "madcap_lunatic_test",
      label = "Madcap Lunatic Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "madcap_lunatic" },
      opponent = {
        id = "madcap_lunatic",
        name = "Madcap Lunatic",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    assert(BossTrickSystem.prepareIntent(run, stage, { leadSlotIndex = leadSlotIndex }))
    local rng = RNG.new(404)
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, {
      "copper_blank_coin", "copper_weighted_coin", "copper_bent_coin",
    })
    run.pendingForcedCoinResults = forcedResults
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    return result, stage
  end

  local leadLeft, leadLeftStage = resolve(1, { "heads", "heads", "tails" })
  assert(leadLeft.trace.bossTrickSnapshot.bossId == "madcap_lunatic")
  assert(leadLeft.trace.bossTrickSnapshot.trickId == "full_throttle")
  assert(leadLeft.trace.bossTrickSnapshot.leadSlotIndex == 1)
  assert(leadLeft.scoreAppliedToHp == 15,
    "left Lead should scale scoring slots one and two to 50% and 100%")
  local leftEffect = leadLeft.trace.bossTrickEffects[1]
  assert(leftEffect.kind == "full_throttle_scaling")
  assert(leftEffect.slotScalings[1] == 0.5
    and leftEffect.slotScalings[2] == 1
    and leftEffect.slotScalings[3] == 1.5)
  assert(leftEffect.amount == -5)
  assert(leadLeftStage.bossTrick.intentIndex == 2)
  assert(leadLeftStage.bossTrick.leadSlotIndex == 1
    or leadLeftStage.bossTrick.leadSlotIndex == 3)

  local leadRight = resolve(3, { "heads", "heads", "tails" })
  assert(leadRight.scoreAppliedToHp == 25,
    "right Lead should make slot one the 150% finishing slot")
  assert(leadRight.trace.bossTrickEffects[1].slotScalings[1] == 1.5)
  assert(leadRight.trace.bossTrickEffects[1].amount == 5)

  local prestige = resolve(3, { "tails", "tails", "heads" }, { "encore" })
  assert(#(prestige.trace.prestigeReplays or {}) == 1)
  assert(prestige.trace.prestigeReplays[1].originSlotIndex == 3,
    "Prestige replay Score should remain credited to its activating slot")
  assert(prestige.trace.bossTrickEffects[1].slotScoreTotals[3] > 10,
    "Full Throttle should include the slot's Prestige effect in its effectiveness")
end)

check("The Impostor steals one adjacent coin's activation family", function()
  local function makeBossRun(seed, purse, tricks)
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = seed,
      starterCollection = purse,
      ownedTrickIds = tricks or {},
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = #purse,
    })
    run.roundIndex = 4
    run.currentStageId = "the_impostor_test"
    local stage = StageState.new({
      id = "the_impostor_test",
      label = "The Impostor Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "the_impostor" },
      opponent = {
        id = "the_impostor",
        name = "The Impostor",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    return run, stage, RNG.new(seed)
  end

  local run, stage, rng = makeBossRun(505, {
    "copper_bent_coin", "copper_flywheel_coin", "copper_weighted_coin",
  }, { "encore", "keep_it_rolling", "headside_edge" })
  assert(BossTrickSystem.prepareIntent(run, stage, {
    victimSlotIndex = 1,
    impostorSlotIndex = 2,
  }))
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, {
    "copper_bent_coin", "copper_flywheel_coin", "copper_weighted_coin",
  })
  run.pendingForcedCoinResults = { "heads", "heads", "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  assert(result.trace.bossTrickSnapshot.trickId == "stolen_identity")
  assert(result.trace.stolenIdentity.stolenFamily == "prestige")
  assert(result.trace.stolenIdentity.originalFamily == "momentum")
  assert(result.perCoin[2].coinId == "copper_flywheel_coin",
    "the Impostor must retain its physical coin body")
  assert(result.perCoin[2].bossActivationFamily == "prestige")
  assert(result.perCoin[2].originalActivationFamily == "momentum")

  local encoreActivations = 0
  local momentumActivations = 0
  for _, activation in ipairs(result.trace.activationLedger or {}) do
    if activation.trickId == "encore" then encoreActivations = encoreActivations + 1 end
    if activation.trickId == "keep_it_rolling" then momentumActivations = momentumActivations + 1 end
  end
  assert(encoreActivations >= 2,
    "Victim and Impostor coins should both activate the stolen Prestige family")
  assert(momentumActivations == 0,
    "the Impostor coin's original Momentum family must remain inactive")
  assert(stage.bossTrick.intentIndex == 2)

  local emptyRun, emptyStage, emptyRng = makeBossRun(506, {
    "copper_flywheel_coin", "copper_blank_coin", "copper_weighted_coin",
  }, { "keep_it_rolling" })
  assert(BossTrickSystem.prepareIntent(emptyRun, emptyStage, {
    victimSlotIndex = 2,
    impostorSlotIndex = 1,
  }))
  PurseSystem.fillHand(emptyRun, emptyStage, emptyRng)
  selectDefinitions(emptyRun, emptyStage, { "copper_flywheel_coin" })
  emptyRun.pendingForcedCoinResults = { "heads" }
  local suppressed = assert(FlipResolver.resolveBatch(
    emptyRun, emptyStage, emptyRun.metaProjection, "heads", emptyRng
  ))
  assert(suppressed.trace.stolenIdentity.suppressed == true)
  assert(suppressed.perCoin[1].bossActivationFamily == false)
  assert(#(suppressed.trace.activationLedger or {}) == 0,
    "an empty Victim should leave the Impostor without an activation family")
end)

check("The Quickhand shuffles slots and palms one committed coin", function()
  local function resolve(seed, shuffleSeed, selectedCoins)
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = seed,
      starterCollection = {
        "copper_bent_coin", "copper_flywheel_coin", "copper_weighted_coin",
      },
      starterPurse = {
        "copper_bent_coin", "copper_flywheel_coin", "copper_weighted_coin",
      },
      ownedTrickIds = { "encore", "keep_it_rolling", "headside_edge" },
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = 3,
    })
    run.roundIndex = 4
    run.currentStageId = "the_quickhand_test"
    local stage = StageState.new({
      id = "the_quickhand_test",
      label = "The Quickhand Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "the_quickhand" },
      opponent = {
        id = "the_quickhand",
        name = "The Quickhand",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    assert(BossTrickSystem.prepareIntent(run, stage, { shuffleSeed = shuffleSeed }))
    local rng = RNG.new(seed)
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, selectedCoins)
    run.pendingForcedCoinResults = { "heads", "heads" }
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    return result, stage
  end

  local selected = {
    "copper_bent_coin", "copper_flywheel_coin", "copper_weighted_coin",
  }
  local result, stage = resolve(606, 123456, selected)
  local cups = result.trace.threeCups
  assert(result.trace.bossTrickSnapshot.trickId == "three_cups")
  assert(cups.kind == "three_cups" and #cups.moves == 3)
  assert(cups.palmed and cups.palmed.instanceId, "one of three committed coins must be palmed")
  assert(#result.perCoin == 2, "the palmed body must be absent from resolution")
  assert(Utils.contains(result.trace.refillEvent.palmedInstanceIds, cups.palmed.instanceId),
    "the purse refill must report the boss-palmed body")
  assert(not Utils.contains(stage.purse.exhaustedInstanceIds, cups.palmed.instanceId),
    "the boss-palmed body must return to hand instead of being spent")

  local resolvedByInstance = {}
  for _, coin in ipairs(result.perCoin) do resolvedByInstance[coin.instanceId] = coin end
  for _, move in ipairs(cups.moves) do
    local resolved = resolvedByInstance[move.instanceId]
    if move.palmed then
      assert(resolved == nil, "the palmed coin must not roll or activate")
    else
      assert(resolved and resolved.selectedSlotIndex == move.targetSlotIndex,
        "surviving bodies must resolve from their shuffled slots")
    end
  end
  assert(stage.bossTrick.intentIndex == 2 and stage.bossTrick.shuffleSeed ~= 123456,
    "the next Flip must receive a fresh deterministic shuffle seed")

  local repeated = resolve(606, 123456, selected)
  assert(repeated.trace.threeCups.palmed.instanceId == cups.palmed.instanceId)
  for index, move in ipairs(cups.moves) do
    local repeatedMove = repeated.trace.threeCups.moves[index]
    assert(repeatedMove.instanceId == move.instanceId
      and repeatedMove.targetSlotIndex == move.targetSlotIndex
      and repeatedMove.palmed == move.palmed,
      "Three Cups must replay the same shuffle from the same seed")
  end

  local solo, soloStage = resolve(607, 654321, { "copper_bent_coin" })
  assert(solo.trace.threeCups.palmed == nil)
  assert(#solo.perCoin == 1, "a single committed coin must still resolve")
  assert(#(solo.trace.refillEvent.palmedInstanceIds or {}) == 0)
  assert(Utils.contains(soloStage.purse.exhaustedInstanceIds, solo.perCoin[1].instanceId),
    "the unpalmed solo coin should be spent normally")
end)

check("The Taxman taxes final slot Score except the Off-the-Books slot", function()
  local function resolve(offTheBooksSlotIndex, selectedCoins)
    local purse = {
      "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin",
      "copper_hollow_coin", "copper_marked_coin",
    }
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = 707,
      starterCollection = purse,
      starterPurse = purse,
      ownedTrickIds = {},
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = 5,
    })
    run.roundIndex = 4
    run.currentStageId = "the_taxman_test"
    local stage = StageState.new({
      id = "the_taxman_test",
      label = "The Taxman Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "the_taxman" },
      opponent = {
        id = "the_taxman",
        name = "The Taxman",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    assert(BossTrickSystem.prepareIntent(run, stage, {
      offTheBooksSlotIndex = offTheBooksSlotIndex,
    }))
    local rng = RNG.new(707)
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, selectedCoins)
    run.pendingForcedCoinResults = {}
    for _ = 1, #selectedCoins do table.insert(run.pendingForcedCoinResults, "heads") end
    local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
    return result, stage
  end

  local full, fullStage = resolve(2, {
    "copper_bent_coin", "copper_blank_coin", "copper_weighted_coin",
  })
  local effect = full.trace.bossTrickEffects[1]
  assert(full.trace.bossTrickSnapshot.trickId == "nothing_to_declare")
  assert(full.trace.bossTrickSnapshot.offTheBooksSlotIndex == 2)
  assert(effect.kind == "tax_collected" and effect.taxRate == 0.30)
  assert(effect.slotScoreTotals[1] == 10
    and effect.slotScoreTotals[2] == 10
    and effect.slotScoreTotals[3] == 10)
  assert(effect.slotTaxes[1] == 3 and effect.slotTaxes[2] == 0 and effect.slotTaxes[3] == 3)
  assert(effect.amount == 6 and full.scoreAppliedToHp == 24,
    "two 10-Score taxed slots should each lose 3 Score")
  assert(fullStage.bossTrick.intentIndex == 2)
  assert(fullStage.bossTrick.offTheBooksSlotIndex >= 1
    and fullStage.bossTrick.offTheBooksSlotIndex <= 3)

  local protected = resolve(1, { "copper_bent_coin" })
  assert(protected.scoreAppliedToHp == 10)
  assert(protected.trace.bossTrickEffects[1].amount == 0,
    "Score from the protected slot must remain untouched")

  local taxed = resolve(2, { "copper_bent_coin" })
  assert(taxed.scoreAppliedToHp == 7)
  assert(taxed.trace.bossTrickEffects[1].slotTaxes[1] == 3,
    "an occupied non-protected slot must pay the 30% tax")
end)

check("Blind Prophet inscribes mixed slot results before every Flip", function()
  local function makeBossRun(seed)
    local purse = {
      "copper_marked_coin", "copper_blank_coin", "copper_bent_coin",
    }
    local run = RunInitializer.createNewRun({
      effectiveValues = {},
      unlockedCoinIds = {},
      unlockedTrickIds = {},
    }, {
      seed = seed,
      starterCollection = purse,
      ownedTrickIds = {},
      maxFlipSlots = 3,
      maxActiveTricks = 5,
      baseFlipsPerStage = 3,
      handSize = 3,
    })
    run.roundIndex = 4
    run.currentStageId = "blind_prophet_test"
    local stage = StageState.new({
      id = "blind_prophet_test",
      label = "Blind Prophet Test",
      stageType = "boss",
      opponentHp = 9999,
      bossModifierIds = { "blind_prophet" },
      opponent = {
        id = "blind_prophet",
        name = "Blind Prophet",
        hp = 9999,
      },
    }, run, { flipsPerStage = 3 })
    return run, stage, RNG.new(seed)
  end

  local run, stage, rng = makeBossRun(808)
  local pattern = { "heads", "tails", "heads" }
  assert(BossTrickSystem.prepareIntent(run, stage, { writtenSlotResults = pattern }))
  stage.predictionSlot = { revision = 1, slotIndex = 1, result = "tails" }
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, {
    "copper_marked_coin", "copper_blank_coin", "copper_bent_coin",
  })
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  assert(result.trace.bossTrickSnapshot.trickId == "written_in_stone")
  assert(result.trace.bossTrickSnapshot.writtenSlotResults[1] == "heads"
    and result.trace.bossTrickSnapshot.writtenSlotResults[2] == "tails"
    and result.trace.bossTrickSnapshot.writtenSlotResults[3] == "heads")
  for slotIndex, coinState in ipairs(result.perCoin) do
    assert(coinState.result == pattern[slotIndex],
      "each physical slot must force its written result")
    assert(coinState.forcedReason == "written_in_stone")
  end
  assert(result.perCoin[1].predictionSlotForced == true,
    "the Prediction mark should still be represented in the locked coin state")
  assert(result.perCoin[1].result == "heads",
    "Written in Stone must override a conflicting ordinary Prediction mark")
  assert(result.trace.bossTrickEffects[1].kind == "written_results"
    and result.trace.bossTrickEffects[1].forcedCount == 3)
  assert(stage.bossTrick.intentIndex == 2,
    "Blind Prophet should prepare a new inscription for the next setup")
  local nextHasHeads = false
  local nextHasTails = false
  for _, writtenResult in ipairs(stage.bossTrick.writtenSlotResults) do
    nextHasHeads = nextHasHeads or writtenResult == "heads"
    nextHasTails = nextHasTails or writtenResult == "tails"
  end
  assert(nextHasHeads and nextHasTails,
    "every generated multi-slot pattern must contain both sides")

  local anchoredContext = {
    bossTrickSnapshot = {
      bossId = "blind_prophet",
      trickId = "written_in_stone",
      writtenSlotResults = { "heads", "tails", "heads" },
    },
    perCoin = {
      {
        coinId = "copper_hollow_coin",
        instanceId = "smuggled_body",
        resolutionIndex = 4,
        anchorSelectedSlotIndex = 2,
        smuggled = true,
      },
    },
    trace = {},
  }
  BossTrickSystem.applyPreFlipForcedOutcomes(anchoredContext)
  assert(anchoredContext.perCoin[1].bossForcedResult == "tails"
    and anchoredContext.perCoin[1].writtenSlotIndex == 2,
    "a Smuggling overload must inherit its anchor slot's inscription")

  local fatedRun, fatedStage, fatedRng = makeBossRun(809)
  assert(BossTrickSystem.prepareIntent(fatedRun, fatedStage, {
    writtenSlotResults = { "heads", "tails", "heads" },
  }))
  fatedRun.luck.value = fatedRun.luck.max
  fatedRun.luck.fatedFlipActive = true
  PurseSystem.fillHand(fatedRun, fatedStage, fatedRng)
  selectDefinitions(fatedRun, fatedStage, {
    "copper_marked_coin", "copper_blank_coin", "copper_bent_coin",
  })
  local fated = assert(FlipResolver.resolveBatch(
    fatedRun, fatedStage, fatedRun.metaProjection, "tails", fatedRng
  ))
  for _, coinState in ipairs(fated.perCoin) do
    assert(coinState.result == "tails" and coinState.forcedReason == "fated_flip",
      "Twist of Fate must remain stronger than Written in Stone")
  end
end)

check("Tarnished Slot reduces only Outcomes scored from its marked slot", function()
  local function resolve(withTarnish)
    local run, stage, rng = makeRun(199, {
      "copper_weighted_coin", "copper_bent_coin", "copper_marked_coin",
    }, {})
    if withTarnish then
      assert(EnemySkillSystem.prepareIntent(run, stage, {
        skillId = "tarnished_slot",
        targetIndex = 1,
      }))
    end
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, { "copper_bent_coin" })
    run.pendingForcedCoinResults = { "heads" }
    return assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  end

  local clean = resolve(false)
  local tarnished = resolve(true)
  assert(tarnished.scoreAppliedToHp < clean.scoreAppliedToHp)
  assert(tarnished.trace.enemySkillSnapshot.skillId == "tarnished_slot")
  assert(#(tarnished.trace.enemySkillEffects or {}) >= 1)
end)

check("Leeching Slot heals without reducing the player's run Score", function()
  local overloadActions = EnemySkillSystem.buildAfterEffectsActions({
    call = "heads",
    enemySkillSnapshot = {
      skillId = "lifesteal_slot",
      targetIndex = 1,
      effect = { healMaxHpOnMatch = 0.05 },
    },
    perCoin = {
      { result = "heads", selectedSlotIndex = 1 },
      { result = "heads", anchorSelectedSlotIndex = 1, smuggled = true },
      { result = "heads", anchorSelectedSlotIndex = 1, palmed = true },
    },
  }, {
    opponentHp = 100,
  })
  assert(overloadActions[1].amount == 10 and overloadActions[1].matchCount == 2,
    "overloaded physical coins should inherit the slot hazard, while palmed coins should not")

  local run, stage, rng = makeRun(211, {
    "copper_bent_coin", "copper_weighted_coin", "copper_marked_coin",
  }, {})
  stage.opponentHp = 100
  stage.opponent.hp = 100
  stage.scoreAppliedToHp = 20
  assert(EnemySkillSystem.prepareIntent(run, stage, {
    skillId = "lifesteal_slot",
    targetIndex = 1,
  }))
  PurseSystem.fillHand(run, stage, rng)
  selectDefinitions(run, stage, { "copper_bent_coin" })
  run.pendingForcedCoinResults = { "heads" }
  local result = assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  local healing = assert((result.scoreBreakdown.opponentHealing or {})[1])
  assert(healing.amount == 5, "Leeching Slot should heal 5% of 100 maximum HP")
  assert(result.runTotalScore > 0, "healing the opponent must not erase earned run Score")
  assert(result.scoreAppliedToHp == 20 + result.runTotalScore - healing.amount)
end)

check("Poison charges once per Charm activation and unlocks at round 5", function()
  local function resolve(withPoison)
    local run, stage, rng = makeRun(223, {
      "copper_weighted_coin", "silver_weighted_coin", "copper_bent_coin",
      "copper_marked_coin", "copper_blank_coin",
    }, { "weighted_palm" })
    run.roundIndex = 5
    if withPoison then
      assert(EnemySkillSystem.prepareIntent(run, stage, {
        skillId = "poisoned_charm",
        targetIndex = 1,
      }))
    end
    PurseSystem.fillHand(run, stage, rng)
    selectDefinitions(run, stage, { "copper_weighted_coin", "silver_weighted_coin" })
    run.pendingForcedCoinResults = { "heads", "heads" }
    return assert(FlipResolver.resolveBatch(run, stage, run.metaProjection, "heads", rng))
  end

  local clean = resolve(false)
  local poisoned = resolve(true)
  local poisonAction = nil
  for _, action in ipairs(poisoned.trace.actions or {}) do
    if action.op == "add_stage_score" and action.category == "enemy_skill" then
      poisonAction = action
    end
  end
  assert(poisonAction, "Poison should create a visible score-loss action")
  assert(poisonAction.poisonStacks == 2, "two coins should create two activations, not one stack per hook phase")
  assert(poisonAction.poisonRate == 0.20)
  assert(poisoned.scoreAppliedToHp < clean.scoreAppliedToHp)
end)

print(string.format("Family-trigger verification: %d/%d passed", passed, 35))
