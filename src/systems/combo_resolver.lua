local ComboResolver = {}

local function resultsMatch(perCoin, startIndex, expectedResults)
  for offset, expectedResult in ipairs(expectedResults or {}) do
    local coinState = perCoin[startIndex + offset - 1]

    if not coinState or coinState.result ~= expectedResult then
      return false
    end
  end

  return true
end

local function hasAdjacentResults(perCoin, expectedResults)
  local requiredCount = #(expectedResults or {})

  if requiredCount == 0 or #perCoin < requiredCount then
    return false
  end

  for startIndex = 1, #perCoin - requiredCount + 1 do
    if resultsMatch(perCoin, startIndex, expectedResults) then
      return true
    end
  end

  return false
end

local function hasMatchingEdges(perCoin)
  return #perCoin >= 2 and perCoin[1].result ~= nil and perCoin[1].result == perCoin[#perCoin].result
end

local function comboMatched(combo, perCoin)
  if combo.kind == "adjacent_results" then
    return hasAdjacentResults(perCoin, combo.results)
  end

  if combo.kind == "matching_edges" then
    return hasMatchingEdges(perCoin)
  end

  return false
end

function ComboResolver.resolve(phaseName, source, context)
  if phaseName ~= "before_stage_end_check" then
    return nil
  end

  local definition = source and source.definition or {}
  local combo = definition.combo

  if type(combo) ~= "table" or not comboMatched(combo, context.perCoin or {}) then
    return nil
  end

  local actions = {
    { op = "set_batch_flag", flag = "combo_matched" },
    { op = "queue_trace_note", note = string.format("COMBO: %s", definition.name or source.sourceId or "Combo") },
  }

  if combo.stageScore and combo.stageScore ~= 0 then
    table.insert(actions, {
      op = "add_stage_score",
      amount = combo.stageScore,
      category = "combo",
      label = combo.label or "Combo",
    })
  end

  if combo.runScore and combo.runScore ~= 0 then
    table.insert(actions, {
      op = "add_run_score",
      amount = combo.runScore,
      category = "combo",
      label = combo.label or "Combo",
    })
  end

  if combo.shopPoints and combo.shopPoints ~= 0 then
    table.insert(actions, {
      op = "add_shop_points",
      amount = combo.shopPoints,
      category = "combo",
      label = combo.label or "Combo",
    })
  end

  return actions
end

return ComboResolver
