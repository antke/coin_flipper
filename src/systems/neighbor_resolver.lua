local NeighborResolver = {}

local function findSourceCoin(source, perCoin)
  for _, coinState in ipairs(perCoin or {}) do
    if coinState.instanceId == source.instanceId or coinState.instanceId == source.sourceId then
      return coinState
    end
  end

  return nil
end

local function findCoinAtResolutionIndex(perCoin, resolutionIndex)
  for _, coinState in ipairs(perCoin or {}) do
    if coinState.resolutionIndex == resolutionIndex then
      return coinState
    end
  end

  return nil
end

local function matchesCall(coinState, call)
  return coinState and coinState.result ~= nil and coinState.result == call
end

local function addRewardActions(actions, reward, label)
  if reward.stageScore and reward.stageScore ~= 0 then
    table.insert(actions, {
      op = "add_stage_score",
      amount = reward.stageScore,
      category = "neighbor",
      label = label,
    })
  end

  if reward.runScore and reward.runScore ~= 0 then
    table.insert(actions, {
      op = "add_run_score",
      amount = reward.runScore,
      category = "neighbor",
      label = label,
    })
  end

  if reward.shopPoints and reward.shopPoints ~= 0 then
    table.insert(actions, {
      op = "add_shop_points",
      amount = reward.shopPoints,
      category = "neighbor",
      label = label,
    })
  end
end

local function isEdgeCoin(coinState, perCoin)
  local resolutionIndex = coinState and coinState.resolutionIndex
  return resolutionIndex == 1 or resolutionIndex == #(perCoin or {})
end

local function neighborMatched(neighbor, sourceCoin, perCoin, call)
  if neighbor.kind == "right_match_bonus" then
    local rightCoin = findCoinAtResolutionIndex(perCoin, (sourceCoin.resolutionIndex or 0) + 1)
    return matchesCall(sourceCoin, call) and matchesCall(rightCoin, call)
  end

  if neighbor.kind == "edge_match_bonus" then
    return isEdgeCoin(sourceCoin, perCoin) and matchesCall(sourceCoin, call)
  end

  return false
end

function NeighborResolver.resolve(phaseName, source, context)
  if phaseName ~= "before_stage_end_check" then
    return nil
  end

  local definition = source and source.definition or {}
  local neighbor = definition.neighbor
  local perCoin = context.perCoin or {}
  local sourceCoin = findSourceCoin(source or {}, perCoin)

  if type(neighbor) ~= "table" or not sourceCoin or not neighborMatched(neighbor, sourceCoin, perCoin, context.call) then
    return nil
  end

  local label = neighbor.label or definition.name or "Neighbor Bonus"
  local actions = {
    { op = "queue_trace_note", note = string.format("NEIGHBOR: %s", label) },
  }

  addRewardActions(actions, neighbor, label)

  return actions
end

return NeighborResolver
