local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function roundToHundredths(value)
  return math.floor((value or 0) * 100 + 0.5) / 100
end

return {
  id = "weighted_trick_weight_actions",
  tags = { "weighted", "replay" },
  description = "Verifies canonical Weighted weight actions affect pre-flip odds and replay signatures.",

  setup = function()
    return {
      runOptions = {
        seed = 7,
        starterCollection = { "copper_blank_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedTrickIds = { "heads_varnish", "weighted_palm" },
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
    { op = "resolve_until_stage_end", call = "heads", maxBatches = 4, label = "remaining_batches" },
    { op = "finalize_stage" },
    { op = "build_transcript" },
    { op = "replay_transcript" },
  },

  assert = function(env, A)
    local firstBatch = A.truthy(A.getResult("first_batch"), "missing first batch")
    local trace = A.truthy(firstBatch.trace, "missing first batch trace")
    local coinRolls = trace.coinRolls or {}

    A.truthy(#coinRolls >= 3, "expected canonical coin rolls")
    A.equal(roundToHundredths(coinRolls[1].headsWeight), 0.75, "Weighted Palm should set the first selected coin")
    A.truthy(coinRolls[2].headsWeight > coinRolls[2].baseHeadsWeight, "Headside Edge should add heads Weight to coin 2")
    A.truthy(coinRolls[3].headsWeight > coinRolls[3].baseHeadsWeight, "Headside Edge should add heads Weight to coin 3")

    A.traceHasAction(trace, { op = "add_weight", side = "heads", amount = 0.12 }, "Headside Edge should trace add_weight")
    A.traceHasAction(trace, {
      op = "set_call_match_chance",
      chance = 0.75,
      target = {
        zone = "selected_coins",
        prefer = {
          { op = "family", value = "weighted" },
        },
        orderBy = "slot_position",
        pick = { op = "slot_at_position", value = 1 },
      },
    }, "Weighted Palm should trace set_call_match_chance")
    A.replayOk(env.replay, "Weighted weight action replay should succeed")

    local tamperedTranscript = Utils.clone(env.transcript)
    local tamperedActions = tamperedTranscript.expected.batchSignatures[1].actions or {}

    for _, action in ipairs(tamperedActions) do
      if action.op == "set_call_match_chance" then
        action.chance = 0.70
        break
      end
    end

    local tamperedReplay = ReplaySystem.replayTranscript(tamperedTranscript)
    A.falsy(tamperedReplay.ok, "tampered Weighted action metadata should fail replay")
  end,
}
