local ReplaySystem = require("src.systems.replay_system")
local Utils = require("src.core.utils")

local function findRedirectAction(actions)
  for index, action in ipairs(actions or {}) do
    if action.op == "redirect_score_credit" then
      return action, index
    end
  end

  return nil, nil
end

return {
  id = "misdirection_crooked_spotlight_credit",
  tags = { "misdirection", "replay" },
  description = "Verifies Crooked Spotlight redirects one successful score-credit event and is replay-checked.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
        starterCollection = { "copper_weighted_coin", "copper_marked_coin", "copper_lucky_coin" },
        ownedTrickIds = { "crooked_spotlight" },
      },
      initialLoadout = {
        [1] = "copper_weighted_coin",
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
    local scoreEvents = firstBatch.scoreBreakdown and firstBatch.scoreBreakdown.scoreEvents or {}
    local redirect = A.truthy((trace.redirectedScoreCredits or {})[1], "Crooked Spotlight should record one score-credit redirect")

    A.equal(redirect.mode, "score_credit", "Crooked Spotlight redirect mode")
    A.equal(redirect.scope, "one_redirect_only", "Crooked Spotlight redirect scope")
    A.equal(redirect.spotlightResolutionIndex, 1, "seeded Spotlight resolution index")
    A.equal(redirect.sourceResolutionIndex, 2, "seeded redirected source resolution index")
    A.equal(redirect.spotlightCoinId, "copper_weighted_coin", "seeded Spotlight coin")
    A.equal(redirect.sourceCoinId, "copper_lucky_coin", "seeded redirected source coin")

    local spotlightEvent = A.truthy(scoreEvents[redirect.spotlightResolutionIndex], "Spotlight score event should exist")
    A.equal(spotlightEvent.spotlight, true, "Spotlight event should be marked")
    A.equal(spotlightEvent.redirectedCredit, false, "Spotlight keeps its own natural credit")

    local sourceEvent = A.truthy(scoreEvents[redirect.sourceResolutionIndex], "redirected source score event should exist")
    A.equal(sourceEvent.matched, true, "redirected source should be successful")
    A.equal(sourceEvent.redirectedCredit, true, "source event should carry redirected credit")
    A.equal(sourceEvent.scoreCredit.coinId, redirect.spotlightCoinId, "source credit should book to Spotlight coin")
    A.equal(sourceEvent.scoreCredit.instanceId, redirect.spotlightInstanceId, "source credit should book to Spotlight instance")
    A.equal(sourceEvent.scoreCredit.resolutionIndex, redirect.spotlightResolutionIndex, "source credit should book to Spotlight resolution")
    A.equal(sourceEvent.coinId, redirect.sourceCoinId, "source body identity remains unchanged")

    local spotlightRoll = A.truthy((trace.coinRolls or {})[redirect.spotlightResolutionIndex], "Spotlight roll should be traced")
    local sourceRoll = A.truthy((trace.coinRolls or {})[redirect.sourceResolutionIndex], "source roll should be traced")
    A.equal(spotlightRoll.spotlight, true, "Spotlight roll should be marked")
    A.equal(sourceRoll.redirectedCredit, true, "source roll should be marked redirected")
    A.equal(sourceRoll.redirectedCreditTargetInstanceId, redirect.spotlightInstanceId, "source roll target instance")

    local redirectAction, actionIndex = findRedirectAction(trace.actions)
    redirectAction = A.truthy(redirectAction, "Crooked Spotlight should trace redirect_score_credit")
    A.equal(redirectAction.sourceInstanceId, redirect.sourceInstanceId, "redirect action source instance")
    A.equal(redirectAction.spotlightInstanceId, redirect.spotlightInstanceId, "redirect action Spotlight instance")
    A.equal(redirectAction.redirectedCredit, true, "redirect action should carry redirected flag")
    A.traceHasAction(trace, {
      op = "redirect_score_credit",
      target = "crooked_spotlight_lowest_success_to_highest_success",
      sourceInstanceId = redirect.sourceInstanceId,
      spotlightInstanceId = redirect.spotlightInstanceId,
    }, "Crooked Spotlight action should be traced with redirect metadata")
    A.replayOk(env.replay, "Misdirection replay should succeed")

    local redirectTamper = Utils.clone(env.transcript)
    redirectTamper.expected.batchSignatures[1].redirectedScoreCredits[1].sourceInstanceId = redirect.spotlightInstanceId
    local redirectReplay = ReplaySystem.replayTranscript(redirectTamper)
    A.falsy(redirectReplay.ok, "tampered redirected score-credit metadata should fail replay")

    local actionTamper = Utils.clone(env.transcript)
    actionTamper.expected.batchSignatures[1].actions[actionIndex].spotlightCoinId = redirect.sourceCoinId
    local actionReplay = ReplaySystem.replayTranscript(actionTamper)
    A.falsy(actionReplay.ok, "tampered redirect action metadata should fail replay")
  end,
}
