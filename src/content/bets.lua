local definitions = {
  {
    id = "none",
    name = "No Bet",
    shortLabel = "NO BET",
    description = "No extra chip risk this flip.",
    stake = 0,
  },
  {
    id = "match_bet",
    name = "Match Bet",
    shortLabel = "MATCH BET",
    description = "Risk 1 chip: gain 3 chips if any equipped coin matches; lose 1 chip if none match.",
    stake = 1,
    winAmount = 3,
    winFlag = "any_matched",
    loseFlag = "no_matches",
  },
}

local byId = {}

for _, definition in ipairs(definitions) do
  byId[definition.id] = definition
end

local Bets = {}

function Bets.getAll()
  return definitions
end

function Bets.getById(id)
  return byId[id]
end

function Bets.getDefaultId()
  return "none"
end

return Bets
