local ActionQueue = require("src.core.action_queue")
local HookRegistry = require("src.core.hook_registry")
local PredictionActions = require("src.core.actions.prediction_actions")
local TargetSelectors = require("src.core.target_selectors")
local TriggerScope = require("src.core.trigger_scope")
local Upgrades = require("src.content.upgrades")

local actionModules = {
  { path = "src.core.actions.score_actions", opCheck = "isScoreOp" },
  { path = "src.core.actions.coin_chance_actions", opCheck = "isChanceOp" },
  { path = "src.core.actions.prediction_actions", opCheck = "isPredictionOp" },
  { path = "src.core.actions.identity_actions", opCheck = "isIdentityOp" },
  { path = "src.core.actions.purse_actions", opCheck = "isPurseOp" },
  { path = "src.core.actions.replay_actions", opCheck = "isReplayOp" },
  { path = "src.core.actions.chain_actions", opCheck = "isChainOp" },
  { path = "src.core.actions.economy_actions", opCheck = "isEconomyOp" },
  { path = "src.core.actions.shop_actions", opCheck = "isShopOp" },
}

local allowedStringTargets = {
  current_coin_score = true,
}

local allowedInlineOps = {
  set_batch_flag = true,
  set_shop_flag = true,
  set_stage_flag = true,
  set_run_flag = true,
  queue_trace_note = true,
  grant_trick = true,
  grant_upgrade = true,
  grant_coin = true,
  increase_coin_slots = true,
  set_flips_remaining = true,
  consume_effect = true,
  grant_temporary_effect = true,
  queue_actions = true,
}

local function collectActions(actionList, output)
  for _, action in ipairs(actionList or {}) do
    table.insert(output, action)

    if action.op == "queue_actions" then
      collectActions(action.actions, output)
    elseif action.op == "grant_temporary_effect" and type(action.effect) == "table" then
      for _, trigger in ipairs(action.effect.triggers or {}) do
        collectActions(trigger.effects, output)
      end
    end
  end
end

return {
  id = "mechanics_architecture_contracts",
  tags = { "architecture", "mechanics" },
  description = "Guards trick mechanics against bespoke target strings and missing action module contracts.",

  steps = {},

  assert = function(_, A)
    for _, moduleSpec in ipairs(actionModules) do
      local module = require(moduleSpec.path)
      A.equal(type(module.apply), "function", moduleSpec.path .. " should export apply")
      A.equal(type(module.validate), "function", moduleSpec.path .. " should export validate")
      A.equal(type(module[moduleSpec.opCheck]), "function", moduleSpec.path .. " should export op check")
    end

    for op in pairs(ActionQueue.KNOWN_OPS) do
      local owningModules = {}

      for _, moduleSpec in ipairs(actionModules) do
        local module = require(moduleSpec.path)

        if module[moduleSpec.opCheck](op) then
          table.insert(owningModules, moduleSpec.path)
        end
      end

      A.truthy(#owningModules <= 1, string.format("%s should be owned by at most one action module", op))

      if #owningModules == 0 then
        A.truthy(allowedInlineOps[op], string.format("%s should be module-owned or explicitly allowed inline", op))
      else
        A.falsy(allowedInlineOps[op], string.format("%s should not be both module-owned and inline", op))
      end
    end

    for _, upgrade in ipairs(Upgrades.getAll()) do
      local actions = {}
      collectActions(upgrade.onAcquire, actions)

      for _, trigger in ipairs(upgrade.triggers or {}) do
        collectActions(trigger.effects, actions)
      end

      for _, action in ipairs(actions) do
        if type(action.target) == "string" then
          A.truthy(
            allowedStringTargets[action.target],
            string.format("%s action %s should use selector target instead of %s", upgrade.id, tostring(action.op), action.target)
          )
        end
      end
    end

    local selectedSlot, selectedError = TargetSelectors.resolveSlot(nil, nil, {
      zone = "selected_coins",
      orderBy = "slot_position",
      pick = { op = "slot_at_position", value = 1 },
    }, {
      perCoin = {
        { coinId = "copper_blank_coin", instanceId = "selected_coin", selectedSlotIndex = 1, resolutionIndex = 1 },
        { coinId = "copper_hollow_coin", instanceId = "smuggled_coin", boardSlotIndex = 4, resolutionIndex = 4, smuggled = true },
      },
    })
    A.equal(selectedError, nil, "selected selector should resolve selected coin")
    A.truthy(selectedSlot, "selected selector should return selected coin")
    A.equal(selectedSlot.instanceId, "selected_coin", "selected selector should exclude smuggled board coins")

    local randomSelectorOk, randomSelectorError = TargetSelectors.validateSlotSelector({
      zone = "selected_coins",
      orderBy = "random",
      pick = { op = "slot_at_position", value = 2 },
    }, { selected_coins = true })
    A.falsy(randomSelectorOk, "random selector should reject pick positions after 1")
    A.equal(randomSelectorError, "target selector random order only supports pick position 1", "random selector error")

    local stageTypeActions = HookRegistry.runPhase("before_scoring", {
      HookRegistry.buildSource("trick", "stage_type_guard_test", {
        name = "Stage Type Guard Test",
        triggers = {
          {
            hook = "before_scoring",
            condition = { stage_type = "boss" },
            effects = { { op = "queue_trace_note", note = "should not run" } },
          },
        },
      }),
    }, {
      trace = { triggeredSources = {} },
    })
    A.equal(#stageTypeActions, 0, "stage_type should be false without stageState")

    local scopedContext = {}
    local topLevelScopeSource = {
      sourceType = "temporary effect",
      sourceId = "top_level_scope_test",
      definition = { scope = { oncePerFlip = true } },
    }
    A.equal(TriggerScope.shouldRun("after_scoring", topLevelScopeSource, {}, 1, scopedContext), true, "top-level scope should allow first trigger")
    A.equal(TriggerScope.shouldRun("after_scoring", topLevelScopeSource, {}, 1, scopedContext), false, "top-level scope should cap second trigger")

    local dealtSlot = { instanceId = "foretold_coin", definitionId = "copper_marked_coin", dealtIndex = 1 }
    local predictionAction = { op = "foretell_coin_result", instanceId = dealtSlot.instanceId, foretoldResult = "tails" }
    PredictionActions.apply({}, { purse = { dealtHandSlots = { dealtSlot } } }, { trace = {} }, predictionAction, {})
    A.equal(dealtSlot.foretold, true, "explicit foretold result should mark target")
    A.equal(dealtSlot.foretoldResult, "tails", "explicit foretold result should be honored")
    A.equal(predictionAction.foretoldRngRoll, nil, "explicit foretold result should not consume rng")
  end,
}
