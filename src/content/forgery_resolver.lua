local TrickActivationSystem = require("src.systems.trick_activation_system")

local ForgeryResolver = {}

function ForgeryResolver.resolve(phaseName, source, context)
  local currentCoin = context and context.currentCoin or nil
  local plan = currentCoin and source
    and TrickActivationSystem.getForgeryPlan(context, currentCoin, source.sourceId) or nil

  if not plan or not TrickActivationSystem.hasForgedTrickTarget(context, {
    mode = plan.mode,
    maxTier = plan.maxTier,
    maxTricks = plan.maxTricks,
    targetTrickIds = plan.targetTrickIds,
  }, phaseName) then
    return {}
  end

  return {
    {
      op = "forge_trick_activations",
      mode = plan.mode,
      maxTier = plan.maxTier,
      maxTricks = plan.maxTricks,
      targetTrickIds = plan.targetTrickIds,
      phase = phaseName,
    },
  }
end

return ForgeryResolver
