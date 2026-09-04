local Coins = require("src.content.coins")
local EncounterSystem = require("src.systems.encounter_system")
local MetaState = require("src.domain.meta_state")
local RunInitializer = require("src.systems.run_initializer")
local Stages = require("src.content.stages")

local SAMPLE_COUNT = 6000
local DISTRIBUTION_TOLERANCE = 0.12

local function increment(counts, key)
  counts[key] = (counts[key] or 0) + 1
end

local function assertBalanced(A, counts, ids, total, label)
  local expected = total / #ids
  local maximumDelta = expected * DISTRIBUTION_TOLERANCE

  for _, id in ipairs(ids) do
    local actual = counts[id] or 0
    A.truthy(
      math.abs(actual - expected) <= maximumDelta,
      string.format("%s %s should be balanced: expected %.1f +/- %.1f, got %d", label, id, expected, maximumDelta, actual)
    )
  end
end

return {
  id = "seeded_content_distribution",
  tags = { "randomness", "distribution", "determinism" },
  description = "Guards seeded stage, encounter, and starter-coin selection against candidate-hash bias.",

  steps = {},

  assert = function(_, A)
    local roundTwoCounts = {}
    local roundThreeCounts = {}
    local bossCounts = {}
    local encounterCounts = {}
    local starterCounts = {}
    local metaState = MetaState.new()

    for seed = 1, SAMPLE_COUNT do
      local source = { seed = seed }
      local roundTwo = Stages.getForRound(2, source)
      local roundThree = Stages.getForRound(3, source)
      local boss = Stages.getForRound(4, source)

      increment(roundTwoCounts, roundTwo.variantId)
      increment(roundThreeCounts, roundThree.variantId)
      increment(bossCounts, boss.variantId)
      A.equal(boss.id, "boss_round", "round four should use the authored boss stage")
      A.truthy(boss.opponent.name == "Betting Betty"
        or boss.opponent.name == "Washed-up Magician"
        or boss.opponent.name == "Madcap Lunatic"
        or boss.opponent.name == "The Quickhand"
        or boss.opponent.name == "The Taxman"
        or boss.opponent.name == "Blind Prophet"
        or boss.opponent.name == "The Impostor",
        "round four should choose an authored boss identity")
      if boss.opponent.name == "The Quickhand" then
        A.equal(boss.opponentHp, 60, "The Quickhand should use the 25%-reduced boss HP target")
        A.equal(boss.opponent.hp, 60, "The Quickhand opponent state should use the reduced HP target")
      end
      A.equal(#boss.bossModifierIds, 1, "round four should carry exactly one Boss Trick kit")

      local runState = select(1, RunInitializer.createNewRun(metaState, { seed = seed }))
      local encounter = EncounterSystem.buildSession(runState)
      increment(encounterCounts, encounter.encounterId)

      for _, coinId in ipairs(Coins.getStarterCoinIds(5, {}, seed)) do
        increment(starterCounts, coinId)
      end
    end

    assertBalanced(A, roundTwoCounts, {
      "round_2_crowd_favorite",
      "round_2_crosswind",
      "round_2_side_pot",
    }, SAMPLE_COUNT, "round two variants")
    assertBalanced(A, roundThreeCounts, {
      "round_3_house_lights",
      "round_3_long_game",
    }, SAMPLE_COUNT, "round three variants")
    assertBalanced(A, bossCounts, {
      "boss_betting_betty",
      "boss_madcap_lunatic",
      "boss_the_quickhand",
      "boss_the_taxman",
      "boss_blind_prophet",
      "boss_the_impostor",
      "boss_washed_up_magician",
    }, SAMPLE_COUNT, "boss variants")
    local encounterIds = {}
    for _, definition in ipairs(require("src.content.encounters").getAll()) do
      table.insert(encounterIds, definition.id)
    end
    assertBalanced(A, encounterCounts, encounterIds, SAMPLE_COUNT, "encounters")

    local starterIds = {}
    for _, definition in ipairs(Coins.getAll()) do
      if definition.rarity == "common" and Coins.isUnlocked(definition, {}) then
        table.insert(starterIds, definition.id)
      end
    end
    assertBalanced(A, starterCounts, starterIds, SAMPLE_COUNT * 5, "starter coins")

    for _, seed in ipairs({ 1, 42, 9999 }) do
      local firstStage = Stages.getForRound(2, { seed = seed })
      local secondStage = Stages.getForRound(2, { seed = seed })
      A.equal(firstStage.variantId, secondStage.variantId, "stage selection should be deterministic")

      local firstStarter = Coins.getStarterCoinIds(5, {}, seed)
      local secondStarter = Coins.getStarterCoinIds(5, {}, seed)
      A.equal(firstStarter, secondStarter, "starter selection should be deterministic")

      local runState = select(1, RunInitializer.createNewRun(metaState, { seed = seed }))
      local firstEncounter = EncounterSystem.buildSession(runState)
      local secondEncounter = EncounterSystem.buildSession(runState)
      A.equal(firstEncounter.encounterId, secondEncounter.encounterId, "encounter selection should be deterministic")
    end
  end,
}
