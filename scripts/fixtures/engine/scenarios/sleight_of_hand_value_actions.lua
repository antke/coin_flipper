local ActionQueue = require("src.core.action_queue")
local Coins = require("src.content.coins")
local PurseSystem = require("src.systems.purse_system")
local Upgrades = require("src.content.upgrades")

local function coinRoll(coinState)
  return {
    coinId = coinState.coinId,
    instanceId = coinState.instanceId,
    slotIndex = coinState.slotIndex,
    selectedSlotIndex = coinState.selectedSlotIndex,
    dealtIndex = coinState.dealtIndex,
    originalDrawIndex = coinState.originalDrawIndex,
    resolutionIndex = coinState.resolutionIndex,
    result = coinState.result,
    smuggled = coinState.smuggled,
  }
end

local function selectedState(coinId, instanceId, slotIndex, result, fields)
  local state = {
    coinId = coinId,
    instanceId = instanceId,
    slotIndex = slotIndex,
    selectedSlotIndex = slotIndex,
    dealtIndex = slotIndex,
    originalDrawIndex = slotIndex,
    resolutionIndex = slotIndex,
    result = result,
  }
  for key, value in pairs(fields or {}) do state[key] = value end
  if fields and fields.unselected == true then state.selectedSlotIndex = nil end
  return state
end

local function buildContext(states, sourceInstanceId, stageState)
  local resolutionOrder = {}
  local coinRolls = {}
  for index, state in ipairs(states) do
    resolutionOrder[index] = coinRoll(state)
    coinRolls[index] = coinRoll(state)
  end

  return ActionQueue.createContext("sleight_test", {
    call = "heads",
    perCoin = states,
    resolutionOrder = resolutionOrder,
    stageState = stageState,
    currentActivation = { sourceInstanceId = sourceInstanceId },
    trace = { coinRolls = coinRolls },
  })
end

local function dealtSlot(definitionId, instanceId, dealtIndex, selectedSlotIndex)
  return {
    definitionId = definitionId,
    instanceId = instanceId,
    dealtIndex = dealtIndex,
    originalDrawIndex = dealtIndex,
    selectedSlotIndex = selectedSlotIndex,
  }
end

local function applyAction(stageState, context, action)
  ActionQueue.applyAll({}, stageState, context, { action })
  return context.trace.actions[#context.trace.actions]
end

local function contains(values, expected)
  for _, value in ipairs(values or {}) do
    if value == expected then return true end
  end
  return false
end

return {
  id = "sleight_of_hand_value_actions",
  tags = { "sleight", "mechanics" },
  description = "Verifies Sleight owns value swaps, failed-coin palming, and local table rearrangement without touching Contraband.",

  steps = {},

  assert = function(_, A)
    local originals = {}
    local function setBaseScore(coinId, score)
      local definition = A.truthy(Coins.getById(coinId), "missing coin definition for score override")
      originals[coinId] = definition.base_score
      definition.base_score = score
    end
    local function restoreBaseScores()
      for coinId, score in pairs(originals) do Coins.getById(coinId).base_score = score end
    end

    setBaseScore("copper_vanishing_coin", 1)
    setBaseScore("silver_vanishing_coin", 3)
    setBaseScore("gold_vanishing_coin", 5)
    setBaseScore("gold_blank_coin", 4)
    setBaseScore("gold_lucky_coin", 8)

    local ok, errorMessage = pcall(function()
      local switchContext = buildContext({
        selectedState("copper_vanishing_coin", "sleight_match", 1, "heads"),
        selectedState("silver_vanishing_coin", "silver_miss", 2, "tails"),
        selectedState("gold_lucky_coin", "gold_miss", 3, "tails"),
        selectedState("gold_vanishing_coin", "contraband", 4, "tails", {
          unselected = true,
          smuggled = true,
          contrabandCopy = true,
        }),
      }, "sleight_match")
      local switchAction = applyAction(nil, switchContext, {
        op = "swap_coins",
        targetMode = "highest_value_higher_miss",
      })
      local switchMove = A.truthy((switchContext.trace.sleightMoves or {})[1], "Switcheroo should move a higher-value Miss")
      A.equal(switchMove.failedInstanceId, "gold_miss", "Switcheroo III should choose the highest-value regular Miss")
      A.equal(switchMove.successInstanceId, "sleight_match", "Switcheroo should spend the activating Match")
      A.equal(switchContext.perCoin[1].instanceId, "gold_miss", "valuable Miss body should inherit the Match slot")
      A.equal(switchContext.perCoin[1].result, "heads", "result belongs to the slot after Switcheroo")
      A.equal(switchContext.perCoin[3].instanceId, "sleight_match", "activating body should move into the Miss slot")
      A.equal(switchContext.perCoin[4].instanceId, "contraband", "Switcheroo must not move Contraband")
      A.equal(switchAction.appliedScoreMultiplier, nil, "Sleight movement should not add a hidden score multiplier")

      local saved = dealtSlot("gold_vanishing_coin", "saved_miss", 1, 1)
      local spent = dealtSlot("copper_vanishing_coin", "spent_match", 2, 2)
      local held = dealtSlot("silver_vanishing_coin", "held_coin", 3, nil)
      local palmStage = {
        stageStatus = "cleared",
        batchIndex = 1,
        purse = {
          dealtHandSlots = { saved, spent, held },
          selectedSlots = { saved, spent },
          boardSlots = {},
          availableInstanceIds = {},
          exhaustedInstanceIds = {},
        },
      }
      local palmContext = buildContext({
        selectedState("gold_vanishing_coin", "saved_miss", 1, "tails"),
        selectedState("copper_vanishing_coin", "spent_match", 2, "heads"),
      }, "spent_match", palmStage)
      local palmAction = applyAction(palmStage, palmContext, {
        op = "palm_failed_coin",
        targetMode = "global_highest_miss",
      })
      A.equal(palmAction.targetInstanceId, "saved_miss", "Vanishing Act III should palm the highest-value Miss")
      A.equal(palmContext.perCoin[1].palmed, true, "palmed Miss should be removed from scoring")
      A.equal(saved.sleightSaved, true, "palmed purse body should be marked for retention")
      local refill = PurseSystem.refillHand(palmStage)
      A.truthy(contains(refill.palmedInstanceIds, "saved_miss"), "refill should report the palmed coin")
      A.truthy(contains(refill.heldInstanceIds, "saved_miss"), "palmed coin should return to the next hand")
      A.falsy(contains(refill.exhaustedInstanceIds, "saved_miss"), "palmed coin should not be spent")
      A.truthy(contains(refill.exhaustedInstanceIds, "spent_match"), "ordinary committed coin should still be spent")

      local monteContext = buildContext({
        selectedState("gold_vanishing_coin", "valuable_miss", 1, "tails"),
        selectedState("copper_vanishing_coin", "monte_source", 2, "heads"),
        selectedState("silver_vanishing_coin", "medium_match", 3, "heads"),
        selectedState("gold_lucky_coin", "cargo", 4, "heads", {
          unselected = true,
          smuggled = true,
        }),
      }, "monte_source")
      local monteAction = applyAction(nil, monteContext, {
        op = "monte_rearrange",
        mode = "best_local_permutation",
      })
      local monteMove = A.truthy((monteContext.trace.sleightMoves or {})[1], "Three-Card Monte should find an improving arrangement")
      A.truthy(monteMove.afterScore > monteMove.beforeScore, "Three-Card Monte must strictly improve immediate score")
      A.equal(monteContext.perCoin[1].instanceId, "monte_source", "lowest-value body should inherit the Miss slot")
      A.equal(monteContext.perCoin[1].result, "tails", "Monte must not move slot results")
      A.equal(monteContext.perCoin[4].instanceId, "cargo", "Monte must not rearrange Smuggled cargo")
      A.truthy(#(monteAction.moves or {}) >= 2, "Monte should trace body travel")

      for _, trickId in ipairs({
        "switcheroo", "switcheroo_ii", "switcheroo_iii",
        "vanishing_act", "vanishing_act_ii", "vanishing_act_iii",
        "three_card_monte", "three_card_monte_ii", "three_card_monte_iii",
      }) do
        local definition = A.truthy(Upgrades.getById(trickId), "missing Sleight Trick " .. trickId)
        A.equal(definition.familyTriggerStatus, "converted", trickId .. " should be available to the family-trigger system")
        A.falsy(definition.rewardEligible == false, trickId .. " should remain reward eligible")
      end
      A.equal(Upgrades.getById("false_bottom").familyTriggerStatus, "removed", "False Bottom should be retired from Sleight")
      A.equal(Upgrades.getById("fall_guy").familyTriggerStatus, "removed", "Fall Guy should be retired from Smuggling")
    end)

    restoreBaseScores()
    if not ok then error(errorMessage, 0) end
  end,
}
