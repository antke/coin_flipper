local definitions = {
  {
    id = "betting_betty",
    name = "Betting Betty",
    description = "The Favourite — Before each Flip, randomly favour Heads or Tails. Coins gain +15% Chance toward the favourite; favourite Outcomes score at 75% and underdog Outcomes at 150%.",
    tags = { "boss", "weighted", "chance", "score_scaling" },
    bossTrick = {
      id = "the_favourite",
      name = "The Favourite",
      family = "weighted",
      chanceShift = 0.15,
      favouriteScoreScaling = 0.75,
      underdogScoreScaling = 1.50,
    },
  },
  {
    id = "washed_up_magician",
    name = "Washed-up Magician",
    description = "Centre Stage — Before each Flip, one slot is placed under the Spotlight. If it produces the highest final Score, it performs an Encore at 50%; otherwise the slot that upstages it loses 50% of its Score.",
    tags = { "boss", "prestige", "slot", "replay", "score" },
    bossTrick = {
      id = "centre_stage",
      name = "Centre Stage",
      family = "prestige",
      encoreScaling = 0.50,
      upstagedLossScaling = 0.50,
      spotlightWinsTies = true,
    },
  },
  {
    id = "madcap_lunatic",
    name = "Madcap Lunatic",
    description = "Full Throttle — Before each Flip, one edge becomes the Lead. Score-producing Outcomes and Trick effects accelerate from 50% through 100% to 150% toward the opposite edge.",
    tags = { "boss", "momentum", "slot", "direction", "score" },
    bossTrick = {
      id = "full_throttle",
      name = "Full Throttle",
      family = "momentum",
      leadScaling = 0.50,
      middleScaling = 1.00,
      finishingScaling = 1.50,
    },
  },
  {
    id = "the_impostor",
    name = "The Impostor",
    description = "Stolen Identity — Before each Flip, adjacent Victim and Impostor slots are marked. The Impostor coin activates the Victim's Trick family instead of its own.",
    tags = { "boss", "forgery", "slot", "identity", "activation" },
    bossTrick = {
      id = "stolen_identity",
      name = "Stolen Identity",
      family = "forgery",
    },
  },
  {
    id = "the_quickhand",
    name = "The Quickhand",
    description = "Three Cups — When Flip begins, committed coins are secretly shuffled between their slots and one coin is palmed for that Flip. The palmed coin returns to your hand.",
    tags = { "boss", "sleight", "slot", "shuffle", "palm" },
    bossTrick = {
      id = "three_cups",
      name = "Three Cups",
      family = "sleight",
    },
  },
  {
    id = "the_taxman",
    name = "The Taxman",
    description = "Nothing to Declare — Before each Flip, one random slot goes Off the Books. Score credited there avoids the 30% tax collected from every other slot and unattributed table-wide Score.",
    tags = { "boss", "smuggling", "slot", "score", "tax" },
    bossTrick = {
      id = "nothing_to_declare",
      name = "Nothing to Declare",
      family = "smuggling",
      taxRate = 0.30,
    },
  },
  {
    id = "blind_prophet",
    name = "Blind Prophet",
    description = "Written in Stone — Before each Flip, every slot is visibly inscribed Heads or Tails and both sides appear. Coins resolve to their slot's inscription; Twist of Fate still overrides it.",
    tags = { "boss", "prediction", "slot", "forced_result", "positioning" },
    bossTrick = {
      id = "written_in_stone",
      name = "Written in Stone",
      family = "prediction",
      requiresMixedSides = true,
    },
  },
  {
    id = "weighted_ledger",
    name = "Weighted Ledger",
    description = "Each coin in the flip gains +6% Tails chance before rolling.",
    tags = { "boss", "weight", "tails" },
    enemyTrick = { category = "weighted", tags = { "weighted", "weight", "tails" }, timing = "before_flip" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "tails", amount = 0.06 },
        },
      },
    },
  },
  {
    id = "heads_embargo",
    name = "Heads Embargo",
    description = "Heads Flips are worth 15% less Score during this boss fight.",
    tags = { "boss", "heads", "score" },
    enemyTrick = { category = "control", tags = { "control", "heads", "score_scaling" }, timing = "before_score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          call = "heads",
        },
        effects = {
          { op = "apply_score_scaling", value = 0.85 },
        },
      },
    },
  },
  {
    id = "tails_embargo",
    name = "Tails Embargo",
    description = "Tails Flips are worth 15% less Score during this boss fight.",
    tags = { "boss", "tails", "score" },
    enemyTrick = { category = "control", tags = { "control", "tails", "score_scaling" }, timing = "before_score" },
    triggers = {
      {
        hook = "before_scoring",
        condition = {
          call = "tails",
        },
        effects = {
          { op = "apply_score_scaling", value = 0.85 },
        },
      },
    },
  },
  {
    id = "stacked_deck",
    name = "Stacked Deck",
    description = "Each coin in the flip gains +6% Heads chance before rolling.",
    tags = { "boss", "weight", "heads" },
    enemyTrick = { category = "weighted", tags = { "weighted", "weight", "heads" }, timing = "before_flip" },
    triggers = {
      {
        hook = "before_coin_roll",
        effects = {
          { op = "modify_coin_weight", side = "heads", amount = 0.06 },
        },
      },
    },
  },
}

local byId = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local Bosses = {}

function Bosses.getAll()
  return definitions
end

function Bosses.getById(id)
  return byId[id]
end

return Bosses
