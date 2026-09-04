local AnalyticsSystem = require("src.systems.analytics_system")
local SimulationSystem = require("src.systems.simulation_system")

return {
  id = "simulation_policy_contracts",
  tags = { "simulation", "policy", "analytics" },
  description = "Verifies named simulation policies are deterministic and enforce their advertised call behavior.",

  steps = {},

  assert = function(_, A)
    A.equal(SimulationSystem.getPolicyIds(), {
      "strategic",
      "synergy_aware",
      "naive",
      "heads_only",
      "tails_only",
    }, "simulation policy order")

    local strategic = SimulationSystem.simulateRun({ seed = 77, policy = "strategic" })
    local strategicAgain = SimulationSystem.simulateRun({ seed = 77, policy = "strategic" })
    A.equal(strategic.policyId, "strategic", "strategic policy id")
    A.equal(strategic.runState.runStatus, strategicAgain.runState.runStatus, "strategic policy result determinism")
    A.equal(strategic.runState.runTotalScore, strategicAgain.runState.runTotalScore, "strategic policy score determinism")

    local headsOnly = SimulationSystem.simulateRun({ seed = 77, policy = "heads_only" })
    A.equal(headsOnly.policyId, "heads_only", "Heads-only policy id")
    A.truthy(headsOnly.runState.counters.headsCalls > 0, "Heads-only policy should make Heads calls")
    A.equal(headsOnly.runState.counters.tailsCalls, 0, "Heads-only policy should never call Tails")

    local tailsOnly = SimulationSystem.simulateRun({ seed = 77, policy = "tails_only" })
    A.equal(tailsOnly.policyId, "tails_only", "Tails-only policy id")
    A.truthy(tailsOnly.runState.counters.tailsCalls > 0, "Tails-only policy should make Tails calls")
    A.equal(tailsOnly.runState.counters.headsCalls, 0, "Tails-only policy should never call Heads")

    local analytics = AnalyticsSystem.buildSimulationReport({
      {
        summary = { runStatus = "lost" },
        runState = { history = { stageResults = {
          {
            stageId = "round_2",
            variantId = "round_2_crosswind",
            stageLabel = "Round 2 — Crosswind Table",
            stageType = "normal",
            roundIndex = 2,
            status = "cleared",
            scoreAppliedToHp = 60,
          },
        } } },
      },
      {
        summary = { runStatus = "lost" },
        runState = { history = { stageResults = {
          {
            stageId = "round_2",
            variantId = "round_2_side_pot",
            stageLabel = "Round 2 — Side Pot",
            stageType = "normal",
            roundIndex = 2,
            status = "failed",
            scoreAppliedToHp = 30,
          },
        } } },
      },
    })
    A.equal(analytics.stageStats.round_2.stageLabel, "Round 2 — All Variants", "aggregate stage label")
    A.equal(analytics.stageStats.round_2.attempts, 2, "aggregate stage attempts")
    A.equal(analytics.stageVariantStats.round_2_crosswind.attempts, 1, "Crosswind variant attempts")
    A.equal(analytics.stageVariantStats.round_2_side_pot.attempts, 1, "Side Pot variant attempts")
  end,
}
