return {
  id = "smuggling_selected_scope_contracts",
  tags = { "smuggling", "weighted" },
  description = "Verifies selected-only Tricks do not leak onto smuggled board coins while smuggled coin triggers still run.",

  setup = function()
    return {
      runOptions = {
        seed = 4,
        starterCollection = { "copper_blank_coin", "copper_marked_coin", "copper_lucky_coin", "copper_weighted_coin" },
        ownedTrickIds = { "hidden_in_plain_sight", "heads_varnish" },
      },
      initialLoadout = {
        [1] = "copper_blank_coin",
        [2] = "copper_marked_coin",
        [3] = "copper_lucky_coin",
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "resolve_batch", call = "heads", label = "first_batch" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local smuggledRoll = nil

    for _, roll in ipairs(trace.coinRolls or {}) do
      if roll.smuggled == true then
        smuggledRoll = roll
        break
      end
    end

    A.truthy(smuggledRoll, "missing smuggled roll")
    A.equal(smuggledRoll.coinId, "copper_weighted_coin", "fixture should smuggle the unselected Weighted Coin")
    A.equal(smuggledRoll.selectedSlotIndex, nil, "smuggled coin should remain outside selected slots")

    A.traceHasTriggeredSource(trace, {
      phase = "before_coin_roll",
      sourceType = "equipped coin",
      sourceId = smuggledRoll.instanceId,
      instanceId = smuggledRoll.instanceId,
    }, "smuggled equipped coin source should trigger")

    A.notContains(trace.triggeredSources, function(entry)
      return entry.phase == "before_coin_roll"
        and entry.sourceType == "trick"
        and entry.sourceId == "heads_varnish"
        and entry.instanceId == smuggledRoll.instanceId
    end, "selected-only Headside Edge should not trigger on smuggled coin")

    A.contains(trace.triggeredSources, function(entry)
      return entry.phase == "before_coin_roll"
        and entry.sourceType == "trick"
        and entry.sourceId == "heads_varnish"
        and entry.instanceId ~= smuggledRoll.instanceId
    end, "Headside Edge should still trigger on selected coins")
  end,
}
