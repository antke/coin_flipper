local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findMomentumAction(actions)
  for index, action in ipairs(actions or {}) do
    if action.op == "trigger_random_neighbor" and action.directions ~= nil then
      return action, index
    end
  end

  return nil, nil
end

return {
  id = "momentum_ripple_follow_through",
  tags = { "momentum", "replay" },
  description = "Verifies Ripple III can trigger both directions and Follow Through scales coins In Motion.",

  setup = function()
    return {
      runOptions = {
        seed = 15,
        handSize = 5,
        maxFlipSlots = 5,
        starterCollection = { "copper_weighted_coin", "copper_flywheel_coin", "copper_lucky_coin", "copper_marked_coin", "copper_blank_coin" },
        ownedTrickIds = { "ripple_iii", "follow_through" },
      },
      initialLoadout = {
        [1] = "copper_weighted_coin",
        [2] = "copper_flywheel_coin",
        [3] = "copper_lucky_coin",
        [4] = "copper_marked_coin",
        [5] = "copper_blank_coin",
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
    local breakdown = A.truthy(firstBatch.scoreBreakdown, "missing first batch score breakdown")
    local links = trace.chainLinks or {}

    A.equal(#links, 2, "Ripple III should create two Momentum links for seeded flip")
    A.equal(links[1].direction, "left", "first Ripple III branch should go left")
    A.equal(links[2].direction, "right", "second Ripple III branch should go right")
    A.equal(links[1].chainChance, 0.75, "Ripple III first link chance")
    A.equal(links[2].chainChance, 0.75, "Ripple III second link chance")
    A.equal(links[1].branchIndex, 1, "left branch index")
    A.equal(links[2].branchIndex, 2, "right branch index")
    A.equal(links[1].triggeredScore, 12, "left Momentum trigger score")
    A.equal(links[2].triggeredScore, 12, "right Momentum trigger score")

    local rightTargetEvent = A.truthy((breakdown.scoreEvents or {})[links[2].targetResolutionIndex], "missing right target score event")
    A.equal(rightTargetEvent.chained, true, "right target should be In Motion")
    A.equal(rightTargetEvent.chainDepth, 1, "right target depth")
    A.equal(rightTargetEvent.scoreScaling, 1.0, "Follow Through now scales the separate triggered score")
    A.equal(#(breakdown.additiveBonuses or {}), 2, "both Momentum links should add triggered score")

    local action, actionIndex = findMomentumAction(trace.actions)
    action = A.truthy(action, "Ripple III should trace trigger_random_neighbor")
    A.equal(action.chainTriggered, true, "Ripple III action should mark a Momentum trigger")
    A.equal(action.chainLinkCount, 2, "Ripple III action link count")
    A.equal(action.continuationChance, 0.5, "Ripple III continuation chance")
    A.equal(action.directions[1], "left", "Ripple III action first direction")
    A.equal(action.directions[2], "right", "Ripple III action second direction")
    A.equal(#(action.chainRolls or {}), 4, "Ripple III should trace branch roll attempts")
    A.replayOk(env.replay, "Ripple III transcript should succeed")

    local linkTamper = Utils.clone(env.transcript)
    linkTamper.expected.batchSignatures[1].chainLinks[2].direction = "left"
    local linkResult = ReplaySystem.replayTranscript(linkTamper)
    A.falsy(linkResult.ok, "tampered Ripple link direction should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].continuationChance = 0.25
    local actionResult = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionResult.ok, "tampered Ripple continuation chance should fail replay")
  end,
}
