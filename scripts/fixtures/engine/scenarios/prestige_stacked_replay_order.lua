local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local EXPECTED_SOURCE_ORDER = {
  "encore",
  "curtain_call",
  "impossible_finale",
}

local function collectPrestigeActions(actions)
  local collected = {}

  for index, action in ipairs(actions or {}) do
    if action.op == "replay_resolution_packet" then
      table.insert(collected, {
        action = action,
        index = index,
      })
    end
  end

  return collected
end

return {
  id = "prestige_stacked_replay_order",
  tags = { "prestige", "replay", "stack" },
  description = "Verifies distinct post-flip Prestige sources resolve completely in owned left-to-right order.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_bent_coin", "copper_blank_coin", "copper_hollow_coin" },
        ownedTrickIds = Utils.copyArray(EXPECTED_SOURCE_ORDER),
      },
      initialLoadout = {
        [1] = "copper_bent_coin",
        [2] = "copper_blank_coin",
        [3] = "copper_hollow_coin",
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
    local actions = collectPrestigeActions(trace.actions)
    local replays = trace.prestigeReplays or {}

    A.equal(#actions, 3, "all three Prestige actions should resolve")
    A.equal(#replays, 3, "all three Prestige actions should create exactly one replay")

    for index, sourceId in ipairs(EXPECTED_SOURCE_ORDER) do
      local action = actions[index].action
      A.equal(action._trace and action._trace.sourceId, sourceId, "Prestige action order " .. tostring(index))
      A.equal(action.skipped, nil, sourceId .. " should not be suppressed by another Prestige source")
      A.equal(replays[index].sourceId, sourceId, "Prestige replay order " .. tostring(index))
      A.truthy((replays[index].replayedScore or 0) > 0, sourceId .. " should contribute replay Score")
    end

    A.notContains(trace.warnings, function(warning)
      return type(warning) == "string" and warning:match("already resolved") ~= nil
    end, "stacked Prestige sources should not report shared-window suppression")

    A.replayOk(env.replay, "stacked Prestige replay transcript should succeed")

    local orderTamper = Utils.clone(env.transcript)
    local signature = orderTamper.expected.batchSignatures[1]
    signature.prestigeReplays[1], signature.prestigeReplays[2] = signature.prestigeReplays[2], signature.prestigeReplays[1]
    local orderReplay = ReplaySystem.replayTranscript(orderTamper)
    A.falsy(orderReplay.ok, "tampered Prestige stack order should fail replay")
  end,
}
