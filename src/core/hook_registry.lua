local Bosses = require("src.content.bosses")
local Coins = require("src.content.coins")
local PurseSystem = require("src.systems.purse_system")
local StageModifiers = require("src.content.stage_modifiers")
local TriggerScope = require("src.core.trigger_scope")
local Upgrades = require("src.content.upgrades")
local Utils = require("src.core.utils")

local HookRegistry = {}

HookRegistry.PHASES = {
  "after_deal_before_selection",
  "after_hand_draw",
  "before_sleight",
  "after_sleight_return",
  "after_replacement_draw",
  "after_hand_reorder",
  "after_call_before_flip",
  "before_hand_flip",
  "on_batch_start",
  "before_batch_validation",
  "before_coin_roll",
  "after_coin_roll",
  "after_flip_before_score",
  "before_scoring",
  "before_coin_score",
  "after_coin_score",
  "after_scoring",
  "luck_gain",
  "luck_meter_full",
  "after_all_effects",
  "before_stage_end_check",
  "on_batch_end",
  "before_shop_generation",
  "after_shop_generation",
  "before_purchase",
  "after_purchase",
}

HookRegistry.SOURCE_TYPE_PRECEDENCE = {
  ["boss modifier"] = 1,
  ["stage modifier"] = 2,
  ["meta modifier"] = 3,
  trick = 4,
  ["run upgrade"] = 4,
  ["equipped coin"] = 5,
  ["temporary effect"] = 6,
}

HookRegistry.SYSTEM_CONDITION_FLAG_KEYS = {
  all_matched = true,
  any_matched = true,
  no_matches = true,
}

HookRegistry.PURSE_COIN_PHASES = {
  after_deal_before_selection = true,
  after_hand_draw = true,
  before_sleight = true,
  after_sleight_return = true,
  after_replacement_draw = true,
  after_hand_reorder = true,
  after_call_before_flip = true,
  before_hand_flip = true,
}

local SELECTED_TRICK_COIN_PHASES = {
  before_hand_flip = true,
  before_coin_roll = true,
  after_coin_roll = true,
  before_coin_score = true,
  after_coin_score = true,
}

local CALL_CONDITION_PHASES = {
  after_hand_draw = true,
  before_sleight = true,
  after_sleight_return = true,
  after_replacement_draw = true,
  after_hand_reorder = true,
  after_call_before_flip = true,
  before_hand_flip = true,
  on_batch_start = true,
  before_batch_validation = true,
  before_coin_roll = true,
  after_coin_roll = true,
  after_flip_before_score = true,
  before_scoring = true,
  after_scoring = true,
  before_stage_end_check = true,
  on_batch_end = true,
}

local FATED_FLIP_CONDITION_PHASES = {
  on_batch_start = true,
  before_batch_validation = true,
  before_coin_roll = true,
  after_coin_roll = true,
  after_flip_before_score = true,
  before_scoring = true,
  after_scoring = true,
  after_all_effects = true,
  before_stage_end_check = true,
  on_batch_end = true,
}

HookRegistry.CONDITION_SCHEMAS = {
  call = {
    phases = CALL_CONDITION_PHASES,
    validate = function(value)
      return value == "heads" or value == "tails", "must be heads or tails"
    end,
  },
  result = {
    phases = {
      before_coin_roll = true,
      after_coin_roll = true,
      before_coin_score = true,
      after_coin_score = true,
    },
    validate = function(value)
      return value == "heads" or value == "tails", "must be heads or tails"
    end,
  },
  match = {
    phases = {
      before_coin_roll = true,
      after_coin_roll = true,
      after_flip_before_score = true,
      before_coin_score = true,
      after_coin_score = true,
      after_all_effects = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  foretold = {
    phases = {
      before_coin_roll = true,
      after_coin_roll = true,
      before_coin_score = true,
      after_coin_score = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  chained = {
    phases = {
      before_coin_roll = true,
      after_coin_roll = true,
      before_coin_score = true,
      after_coin_score = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  smuggled = {
    phases = {
      before_coin_score = true,
      after_coin_score = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  forged = {
    phases = {
      before_coin_score = true,
      after_coin_score = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  luck_gain_positive = {
    phases = {
      luck_gain = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  luck_gain_source = {
    phases = {
      luck_gain = true,
    },
    validate = function(value)
      return type(value) == "string" and value ~= "", "must be a non-empty string"
    end,
  },
  fated_flip = {
    phases = FATED_FLIP_CONDITION_PHASES,
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
  stage_type = {
    validate = function(value)
      return value == "normal" or value == "boss", "must be normal or boss"
    end,
  },
  slot_index = {
    phases = {
      after_deal_before_selection = true,
      after_hand_draw = true,
      before_sleight = true,
      after_sleight_return = true,
      after_replacement_draw = true,
      after_hand_reorder = true,
      after_call_before_flip = true,
      before_hand_flip = true,
      before_coin_roll = true,
      after_coin_roll = true,
      before_coin_score = true,
      after_coin_score = true,
    },
    validate = function(value)
      return type(value) == "number" and math.floor(value) == value and value >= 1, "must be a positive integer"
    end,
  },
  offer_type = {
    phases = {
      after_shop_generation = true,
    },
    validate = function(value)
      return value == "coin" or value == "trick" or value == "upgrade", "must be coin or Trick"
    end,
  },
  offer_rarity = {
    phases = {
      after_shop_generation = true,
    },
    validate = function(value)
      return type(value) == "string" and value ~= "", "must be non-empty string"
    end,
  },
  offer_content_id = {
    phases = {
      after_shop_generation = true,
    },
    validate = function(value)
      return type(value) == "string" and value ~= "", "must be non-empty string"
    end,
  },
  purchase_type = {
    phases = {
      before_purchase = true,
      after_purchase = true,
    },
    validate = function(value)
      return value == "coin" or value == "trick" or value == "upgrade", "must be coin or Trick"
    end,
  },
  purchase_rarity = {
    phases = {
      before_purchase = true,
      after_purchase = true,
    },
    validate = function(value)
      return type(value) == "string" and value ~= "", "must be non-empty string"
    end,
  },
  purchase_content_id = {
    phases = {
      before_purchase = true,
      after_purchase = true,
    },
    validate = function(value)
      return type(value) == "string" and value ~= "", "must be non-empty string"
    end,
  },
  purchase_was_blocked = {
    phases = {
      before_purchase = true,
      after_purchase = true,
    },
    validate = function(value)
      return type(value) == "boolean", "must be boolean"
    end,
  },
}

local phaseSet = {}
local phaseOrder = {}

local function canonicalContentType(contentType)
  return contentType == "upgrade" and "trick" or contentType
end

for index, phaseName in ipairs(HookRegistry.PHASES) do
  phaseSet[phaseName] = true
  phaseOrder[phaseName] = index
end

local function collectFromIds(target, ids, sourceType, lookupFn)
  for sourceOrder, id in ipairs(ids or {}) do
    local definition = lookupFn(id)

    if definition and not (sourceType == "trick"
      and (definition.familyTriggerStatus == "held" or definition.familyTriggerStatus == "removed")) then
      table.insert(target, HookRegistry.buildSource(sourceType, id, definition, {
        sourceOrder = sourceOrder,
      }))
    end
  end
end

local function sourceComparator(left, right)
  if left.priorityLayer ~= right.priorityLayer then
    return left.priorityLayer < right.priorityLayer
  end

  local leftPrecedence = HookRegistry.SOURCE_TYPE_PRECEDENCE[left.sourceType] or 999
  local rightPrecedence = HookRegistry.SOURCE_TYPE_PRECEDENCE[right.sourceType] or 999

  if leftPrecedence ~= rightPrecedence then
    return leftPrecedence < rightPrecedence
  end

  if type(left.slotIndex) == "number" and type(right.slotIndex) == "number" and left.slotIndex ~= right.slotIndex then
    return left.slotIndex < right.slotIndex
  end

  if type(left.sourceOrder) == "number" and type(right.sourceOrder) == "number" and left.sourceOrder ~= right.sourceOrder then
    return left.sourceOrder < right.sourceOrder
  end

  return tostring(left.sourceId) < tostring(right.sourceId)
end

local function matchesCondition(condition, context)
  if not condition then
    return true
  end

  for key, expectedValue in pairs(condition) do
    if key == "call" then
      if context.call ~= expectedValue then
        return false
      end
    elseif key == "result" then
      if not context.currentCoin or context.currentCoin.result ~= expectedValue then
        return false
      end
    elseif key == "match" then
      local didMatch = context.currentCoin and (context.currentCoin.result == context.call) or false

      if didMatch ~= expectedValue then
        return false
      end
    elseif key == "foretold" then
      local isForetold = context.currentCoin and context.currentCoin.foretold == true or false

      if isForetold ~= expectedValue then
        return false
      end
    elseif key == "chained" then
      local isChained = context.currentCoin and context.currentCoin.chained == true or false

      if isChained ~= expectedValue then
        return false
      end
    elseif key == "smuggled" then
      local isSmuggled = context.currentCoin and context.currentCoin.smuggled == true or false

      if isSmuggled ~= expectedValue then
        return false
      end
    elseif key == "forged" then
      local isForged = context.currentCoin and context.currentCoin.forged == true or false

      if isForged ~= expectedValue then
        return false
      end
    elseif key == "luck_gain_positive" then
      local isPositive = context.currentLuckGainEvent and (context.currentLuckGainEvent.appliedAmount or 0) > 0 or false

      if isPositive ~= expectedValue then
        return false
      end
    elseif key == "luck_gain_source" then
      if not context.currentLuckGainEvent or context.currentLuckGainEvent.source ~= expectedValue then
        return false
      end
    elseif key == "fated_flip" then
      local isFatedFlip = context.luck and context.luck.wasFatedFlip == true or false

      if isFatedFlip ~= expectedValue then
        return false
      end
    elseif key == "stage_type" then
      if not context.stageState or context.stageState.stageType ~= expectedValue then
        return false
      end
    elseif key == "slot_index" then
      if not context.currentCoin or context.currentCoin.slotIndex ~= expectedValue then
        return false
      end
    elseif key == "offer_type" then
      if not context.currentOffer or canonicalContentType(context.currentOffer.type) ~= canonicalContentType(expectedValue) then
        return false
      end
    elseif key == "offer_rarity" then
      if not context.currentOffer or context.currentOffer.rarity ~= expectedValue then
        return false
      end
    elseif key == "offer_content_id" then
      if not context.currentOffer or context.currentOffer.contentId ~= expectedValue then
        return false
      end
    elseif key == "purchase_type" then
      local purchaseType = context.purchase and context.purchase.type or (context.currentOffer and context.currentOffer.type)

      if canonicalContentType(purchaseType) ~= canonicalContentType(expectedValue) then
        return false
      end
    elseif key == "purchase_rarity" then
      local purchaseRarity = context.purchase and context.purchase.rarity or (context.currentOffer and context.currentOffer.rarity)

      if purchaseRarity ~= expectedValue then
        return false
      end
    elseif key == "purchase_content_id" then
      local purchaseContentId = context.purchase and context.purchase.contentId or (context.currentOffer and context.currentOffer.contentId)

      if purchaseContentId ~= expectedValue then
        return false
      end
    elseif key == "purchase_was_blocked" then
      if (context.purchaseBlocked == true) ~= expectedValue then
        return false
      end
    elseif context.batchFlags and context.batchFlags[key] ~= nil then
      if context.batchFlags[key] ~= expectedValue then
        return false
      end
    elseif context.shopFlags and context.shopFlags[key] ~= nil then
      if context.shopFlags[key] ~= expectedValue then
        return false
      end
    elseif context.batchFlags[key] ~= expectedValue then
      return false
    end
  end

  return true
end

local function prepareResolvedAction(phaseName, source, context, effect, triggerIndex, effectIndex)
  local action = Utils.clone(effect)

  if context.currentCoin then
    if action.coinId == nil then
      action.coinId = context.currentCoin.coinId
    end

    if action.instanceId == nil then
      action.instanceId = context.currentCoin.instanceId
    end

    if action.slotIndex == nil then
      action.slotIndex = context.currentCoin.slotIndex
    end

    if action.resolutionIndex == nil then
      action.resolutionIndex = context.currentCoin.resolutionIndex
    end
  end

  if context.currentOffer and action.op == "adjust_shop_price" and action.contentId == nil then
    action.contentId = context.currentOffer.contentId
    action.offerType = action.offerType or context.currentOffer.type
  end

  if source.sourceType == "temporary effect" and action.op == "consume_effect" and action.effectId == nil then
    action.effectId = source.sourceId
  end

  action._trace = action._trace or {
    phase = phaseName,
    sourceId = source.sourceId,
    sourceType = source.sourceType,
    coinId = context.currentCoin and context.currentCoin.coinId or nil,
    instanceId = context.currentCoin and context.currentCoin.instanceId or nil,
    slotIndex = context.currentCoin and context.currentCoin.slotIndex or nil,
    resolutionIndex = context.currentCoin and context.currentCoin.resolutionIndex or nil,
    sourceOrder = source.sourceOrder,
    triggerIndex = triggerIndex,
    effectIndex = effectIndex,
  }

  return action
end

local function runSourceForPhase(phaseName, source, context, targetActionList)
  local definition = source.definition or {}
  local sourceTriggered = false

  if context.currentCoin and source.sourceType == "equipped coin" then
    if source.instanceId then
      if context.currentCoin.instanceId ~= source.instanceId then
        return
      end
    elseif context.currentCoin.coinId ~= source.sourceId then
      return
    end
  end

  for triggerIndex, trigger in ipairs(definition.triggers or {}) do
    local condition = trigger.condition or {}
    local selectedCoinOnlyTrick = (source.sourceType == "trick" or source.sourceType == "run upgrade")
      and SELECTED_TRICK_COIN_PHASES[phaseName] == true
      and context.currentCoin
      and context.currentCoin.selectedSlotIndex == nil
      and condition.smuggled ~= true

    if not selectedCoinOnlyTrick and trigger.hook == phaseName and matchesCondition(trigger.condition, context) and TriggerScope.shouldRun(phaseName, source, trigger, triggerIndex, context) then
      sourceTriggered = true
      context.trace.triggeredSources = context.trace.triggeredSources or {}
      table.insert(context.trace.triggeredSources, {
        phase = phaseName,
        sourceId = source.sourceId,
        sourceType = source.sourceType,
        sourceName = definition.name,
        coinId = context.currentCoin and context.currentCoin.coinId or nil,
        instanceId = context.currentCoin and context.currentCoin.instanceId or nil,
        slotIndex = context.currentCoin and context.currentCoin.slotIndex or nil,
        resolutionIndex = context.currentCoin and context.currentCoin.resolutionIndex or nil,
      })

      for effectIndex, effect in ipairs(trigger.effects or {}) do
        local action = prepareResolvedAction(phaseName, source, context, effect, triggerIndex, effectIndex)
        table.insert(targetActionList, action)
      end
    end
  end

  if definition.customResolver then
    local resolver = require(definition.customResolver)
    local customActions = resolver.resolve(phaseName, source, context) or {}

    if #customActions > 0 and not sourceTriggered then
      context.trace.triggeredSources = context.trace.triggeredSources or {}
      table.insert(context.trace.triggeredSources, {
        phase = phaseName,
        sourceId = source.sourceId,
        sourceType = source.sourceType,
        sourceName = definition.name,
        coinId = context.currentCoin and context.currentCoin.coinId or nil,
        instanceId = context.currentCoin and context.currentCoin.instanceId or nil,
        slotIndex = context.currentCoin and context.currentCoin.slotIndex or nil,
        resolutionIndex = context.currentCoin and context.currentCoin.resolutionIndex or nil,
      })
    end

    for actionIndex, action in ipairs(customActions) do
      table.insert(targetActionList, prepareResolvedAction(phaseName, source, context, action, 0, actionIndex))
    end
  end
end

function HookRegistry.isValidPhase(phaseName)
  return phaseSet[phaseName] == true
end

function HookRegistry.getSystemConditionFlagKeys()
  return Utils.clone(HookRegistry.SYSTEM_CONDITION_FLAG_KEYS)
end

function HookRegistry.validateCondition(condition, allowedFlagKeys, phaseName)
  if condition == nil then
    return true
  end

  if type(condition) ~= "table" then
    return false, "condition must be a table"
  end

  local knownFlagKeys = Utils.clone(HookRegistry.SYSTEM_CONDITION_FLAG_KEYS)

  for key, value in pairs(allowedFlagKeys or {}) do
    if value then
      knownFlagKeys[key] = true
    end
  end

  for key, expectedValue in pairs(condition) do
    local schema = HookRegistry.CONDITION_SCHEMAS[key]

    if schema then
      if phaseName and schema.phases and not schema.phases[phaseName] then
        return false, string.format("condition key %s is not valid during phase %s", key, tostring(phaseName))
      end

      local ok, errorMessage = schema.validate(expectedValue)

      if not ok then
        return false, string.format("condition key %s %s", key, errorMessage)
      end
    elseif knownFlagKeys[key] then
      if type(expectedValue) ~= "boolean" then
        return false, string.format("flag condition %s must be boolean", key)
      end
    elseif type(key) == "string" and key ~= "" then
      if type(expectedValue) ~= "boolean" then
        return false, string.format("unknown condition key %s must be boolean to act as a flag condition", tostring(key))
      end
    else
      return false, string.format("unknown condition key %s", tostring(key))
    end
  end

  return true
end

function HookRegistry.getPhaseOrder(phaseName)
  return phaseOrder[phaseName]
end

function HookRegistry.buildSource(sourceType, sourceId, definition, extra)
  local source = {
    sourceType = sourceType,
    sourceId = sourceId,
    priorityLayer = definition.priorityLayer or 0,
    definition = definition,
    sourceName = definition.name,
  }

  for key, value in pairs(extra or {}) do
    source[key] = value
  end

  return source
end

function HookRegistry.insertSource(sourceList, source)
  table.insert(sourceList, source)
  table.sort(sourceList, sourceComparator)
end

function HookRegistry.removeSourceById(sourceList, sourceId)
  for index = #sourceList, 1, -1 do
    if sourceList[index].sourceId == sourceId then
      table.remove(sourceList, index)
    end
  end
end

function HookRegistry.collectSources(runState, stageState, metaProjection, options)
  options = options or {}
  local sources = {}

  collectFromIds(sources, stageState and stageState.activeBossModifierIds, "boss modifier", Bosses.getById)
  collectFromIds(sources, stageState and stageState.activeStageModifierIds, "stage modifier", StageModifiers.getById)

  if metaProjection then
    table.insert(sources, HookRegistry.buildSource("meta modifier", metaProjection.id or "meta_projection", metaProjection))
  end

  if options.includeTricks ~= false then
    collectFromIds(sources, runState and (runState.ownedTrickIds or runState.ownedUpgradeIds), "trick", Upgrades.getById)
  end

  if runState then
    if stageState and stageState.purse and (#(stageState.purse.handSlots or {}) > 0 or #(stageState.purse.boardSlots or {}) > 0) then
      for slotIndex, slot in ipairs(stageState.purse.handSlots) do
        local coinId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId)
        local definition = coinId and Coins.getById(coinId) or nil

        if definition then
          table.insert(sources, HookRegistry.buildSource("equipped coin", slot.instanceId, definition, {
            instanceId = slot.instanceId,
            coinId = coinId,
            slotIndex = slotIndex,
          }))
        end
      end

      for overloadIndex, slot in ipairs(stageState.purse.boardSlots or {}) do
        local coinId = slot.definitionId or PurseSystem.getDefinitionId(runState, slot.instanceId)
        local definition = coinId and Coins.getById(coinId) or nil

        if definition then
          table.insert(sources, HookRegistry.buildSource("equipped coin", slot.instanceId, definition, {
            instanceId = slot.instanceId,
            coinId = coinId,
            slotIndex = slot.boardSlotIndex or (#(stageState.purse.handSlots or {}) + overloadIndex),
            boardSlotIndex = slot.boardSlotIndex,
            overloadSlotIndex = slot.overloadSlotIndex or overloadIndex,
          }))
        end
      end
    else
      for slotIndex = 1, (runState.maxFlipSlots or runState.maxActiveCoinSlots or 0) do
        local coinId = runState.flipSlots[slotIndex]

        if coinId then
          local definition = Coins.getById(coinId)

          if definition then
            table.insert(sources, HookRegistry.buildSource("equipped coin", coinId, definition, {
              slotIndex = slotIndex,
            }))
          end
        end
      end
    end

    for index, effect in ipairs(runState.temporaryRunEffects or {}) do
      table.insert(sources, HookRegistry.buildSource("temporary effect", effect.id or string.format("temp_%d", index), effect))
    end
  end

  table.sort(sources, sourceComparator)
  return sources
end

function HookRegistry.collectGlobalSources(runState, stageState, metaProjection)
  return HookRegistry.collectSources(runState, stageState, metaProjection, { includeTricks = false })
end

function HookRegistry.buildActiveTrickSources(runState)
  local sources = {}
  for position, trickId in ipairs(runState and (runState.ownedTrickIds or runState.ownedUpgradeIds) or {}) do
    local definition = Upgrades.getById(trickId)
    if definition and definition.familyTriggerStatus == "converted" then
      table.insert(sources, HookRegistry.buildSource("trick", trickId, definition, {
        boardPosition = position,
        sourceOrder = position,
      }))
    end
  end
  return sources
end

function HookRegistry.runSourcePhase(phaseName, source, context)
  local actions = {}
  if not HookRegistry.isValidPhase(phaseName) then
    error(string.format("Unknown hook phase: %s", tostring(phaseName)))
  end
  runSourceForPhase(phaseName, source, context, actions)
  return actions
end

function HookRegistry.runPhase(phaseName, sourceList, context)
  local actions = {}

  if not HookRegistry.isValidPhase(phaseName) then
    error(string.format("Unknown hook phase: %s", tostring(phaseName)))
  end

  if HookRegistry.PURSE_COIN_PHASES[phaseName] then
    local eventCoins = context.purseEventCoins or context.perCoin or {}

    for _, coinState in ipairs(eventCoins) do
      context.currentCoin = coinState

      for _, source in ipairs(sourceList or {}) do
        runSourceForPhase(phaseName, source, context, actions)
      end
    end

    context.currentCoin = nil
    return actions
  end

  if phaseName == "before_coin_roll" or phaseName == "after_coin_roll" then
    for _, coinState in ipairs(context.perCoin or {}) do
      context.currentCoin = coinState

      for _, source in ipairs(sourceList or {}) do
        runSourceForPhase(phaseName, source, context, actions)
      end
    end

    context.currentCoin = nil
    return actions
  end

  if phaseName == "after_shop_generation" then
    for _, offer in ipairs(context.shopOffers or {}) do
      context.currentOffer = offer

      for _, source in ipairs(sourceList or {}) do
        runSourceForPhase(phaseName, source, context, actions)
      end
    end

    context.currentOffer = nil
    return actions
  end

  for _, source in ipairs(sourceList or {}) do
    runSourceForPhase(phaseName, source, context, actions)
  end

  return actions
end

return HookRegistry
