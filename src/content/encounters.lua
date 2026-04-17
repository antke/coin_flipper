local Utils = require("src.core.utils")

local EncounterDefinitions = {
  {
    id = "wager_table",
    name = "Wager Table",
    description = "A quiet side game offers immediate leverage if you know what to ask for.",
    choices = {
      {
        id = "house_purse",
        type = "shop_points",
        amount = 3,
        label = "Take the purse",
        description = "+3 shop points for the next stop.",
      },
      {
        id = "voucher_roll",
        type = "shop_rerolls",
        amount = 1,
        label = "Take the voucher",
        description = "+1 free shop reroll.",
      },
    },
  },
  {
    id = "backroom_stash",
    name = "Backroom Stash",
    description = "A hidden cache offers one tactical pickup before the market opens.",
    choices = {
      {
        id = "stash_cross_bet",
        type = "coin",
        contentId = "cross_bet",
        label = "Pocket Cross Bet",
        description = "Add Cross Bet to your run collection.",
      },
      {
        id = "stash_tails_contract",
        type = "upgrade",
        contentId = "tails_contract",
        label = "Sign Tails Contract",
        description = "Gain Tails Contract for the run.",
      },
    },
  },
}

local byId = {}
for _, definition in ipairs(EncounterDefinitions) do
  byId[definition.id] = definition
end

local Encounters = {}

function Encounters.getAll()
  return EncounterDefinitions
end

function Encounters.getById(id)
  return byId[id]
end

function Encounters.cloneDefinition(definition)
  return Utils.clone(definition)
end

return Encounters
