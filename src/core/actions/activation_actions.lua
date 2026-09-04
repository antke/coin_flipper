local ActivationActions = {}

local ACTIVATION_OPS = {
  forge_trick_activations = true,
  reactivate_coin = true,
  repeat_trick = true,
}

function ActivationActions.isActivationOp(op)
  return ACTIVATION_OPS[op] == true
end

function ActivationActions.validate(action)
  if action.op == "forge_trick_activations" then
    if action.mode ~= "borrowed_name" and action.mode ~= "forged_signature" then
      return false, "forge_trick_activations mode must be borrowed_name or forged_signature"
    end
    for _, key in ipairs({ "maxTier", "maxTricks" }) do
      if type(action[key]) ~= "number" or math.floor(action[key]) ~= action[key] or action[key] < 1 or action[key] > 3 then
        return false, string.format("forge_trick_activations %s must be an integer between 1 and 3", key)
      end
    end
    if type(action.phase) ~= "string" or action.phase == "" then
      return false, "forge_trick_activations phase must be a non-empty string"
    end
    if type(action.targetTrickIds) ~= "table" or #action.targetTrickIds < 1 or #action.targetTrickIds > 3 then
      return false, "forge_trick_activations targetTrickIds must contain between one and three Trick IDs"
    end
    for _, trickId in ipairs(action.targetTrickIds) do
      if type(trickId) ~= "string" or trickId == "" then
        return false, "forge_trick_activations targetTrickIds must contain non-empty strings"
      end
    end
    return true
  end

  if action.op == "repeat_trick" then
    if type(action.trickId) ~= "string" or action.trickId == "" then
      return false, "repeat_trick trickId must be a non-empty string"
    end
    if action.phase ~= nil and type(action.phase) ~= "string" then
      return false, "repeat_trick phase must be a string"
    end
    return true
  end

  if action.direction ~= nil and action.direction ~= "left" and action.direction ~= "right" then
    return false, "reactivate_coin direction must be left or right"
  end
  if action.directions ~= nil then
    if type(action.directions) ~= "table" then
      return false, "reactivate_coin directions must be a table"
    end
    for _, direction in ipairs(action.directions) do
      if direction ~= "left" and direction ~= "right" then
        return false, "reactivate_coin directions must contain left/right"
      end
    end
  end
  for _, key in ipairs({ "chance", "continuationChance" }) do
    if action[key] ~= nil and (type(action[key]) ~= "number" or action[key] < 0 or action[key] > 1) then
      return false, string.format("reactivate_coin %s must be between 0 and 1", key)
    end
  end
  for _, key in ipairs({ "maxTargets", "maxReactivationsPerCoin" }) do
    if action[key] ~= nil and (type(action[key]) ~= "number" or math.floor(action[key]) ~= action[key] or action[key] < 1) then
      return false, string.format("reactivate_coin %s must be a positive integer", key)
    end
  end
  return true
end

function ActivationActions.apply(runState, stageState, context, action)
  local activationSystem = require("src.systems.trick_activation_system")
  if action.op == "forge_trick_activations" then
    activationSystem.applyForgedTrickActivations(runState, stageState, context, action)
  elseif action.op == "reactivate_coin" then
    activationSystem.enqueueReactivation(context, action)
  elseif action.op == "repeat_trick" then
    activationSystem.enqueueRepeat(context, action)
  else
    return false
  end
  return true
end

return ActivationActions
