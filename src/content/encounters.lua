local Utils = require("src.core.utils")

local EncounterDefinitions = {
  {
    id = "wager_table",
    familyId = "wager",
    name = "Wager Table",
    description = "A quiet side game offers immediate leverage if you know what to ask for.",
    choices = {
      {
        id = "house_purse",
        type = "shop_points",
        amount = 3,
        label = "Take the pouch",
        description = "+3 extra Influence for the next stop.",
      },
      {
        id = "voucher_roll",
        type = "shop_rerolls",
        amount = 1,
        label = "Take the voucher",
        description = "+1 Free Reroll.",
      },
    },
  },
  {
    id = "backroom_stash",
    familyId = "stash",
    name = "Backroom Stash",
    description = "A hidden cache offers one tactical pickup before the market opens.",
    choices = {
      {
        id = "stash_hollow_coin",
        type = "coin",
        contentId = "copper_hollow_coin",
        label = "Pocket Hollow Coin",
        description = "Add Hollow Coin to your run collection.",
      },
      {
        id = "stash_read_the_stars",
        type = "trick",
        contentId = "read_the_stars",
        label = "Read the Stars",
        description = "Gain the Read the Stars Trick for the run.",
      },
    },
  },
  {
    id = "dealer_tip",
    familyId = "tip",
    name = "Dealer Tip",
    description = "A quiet hint points you toward the safer side of the table.",
    choices = {
      {
        id = "tip_written_in_the_stars",
        type = "trick",
        contentId = "written_in_the_stars",
        label = "Follow the Omen",
        description = "Gain the Written in the Stars Trick for the run.",
      },
      {
        id = "tip_marked_coin",
        type = "coin",
        contentId = "copper_marked_coin",
        label = "Pocket Marked Coin",
        description = "Add Marked Coin to your run collection.",
      },
    },
  },
  {
    id = "credit_line",
    familyId = "credit",
    name = "Credit Line",
    description = "A sympathetic croupier offers either safer insurance or a reliable coin.",
    choices = {
      {
        id = "credit_insurance_ledger",
        type = "trick",
        contentId = "insurance_ledger",
        label = "Open Insurance Slip",
        description = "Gain the Insurance Slip Trick for the run.",
      },
      {
        id = "credit_weighted_coin",
        type = "coin",
        contentId = "copper_weighted_coin",
        label = "Take Weighted Coin",
        description = "Add Weighted Coin to your run collection.",
      },
    },
  },
  {
    id = "quiet_ledgers",
    familyId = "ledgers",
    name = "Quiet Ledgers",
    description = "An abandoned stage cart offers two different Prestige replay methods.",
    choices = {
      {
        id = "ledger_encore",
        type = "trick",
        contentId = "encore",
        label = "Take Encore",
        description = "Gain the Encore Charm for the run.",
      },
      {
        id = "ledger_curtain_call",
        type = "trick",
        contentId = "curtain_call",
        label = "Take Curtain Call",
        description = "Gain the Curtain Call Trick for the run.",
      },
    },
  },
  {
    id = "runner_credit",
    familyId = "credit",
    name = "Runner Credit",
    description = "A quiet backer offers a long-haul coupon or extra rerolls for the next stop.",
    choices = {
      {
        id = "runner_coupon_case",
        type = "trick",
        contentId = "coupon_case",
        label = "Take House Voucher",
        description = "Gain the House Voucher Trick for the run.",
      },
      {
        id = "runner_credit_reroll",
        type = "shop_rerolls",
        amount = 2,
        label = "Bank Two Rerolls",
        description = "+2 Free Rerolls.",
      },
    },
  },
  {
    id = "annotated_margin",
    familyId = "margin",
    name = "Annotated Margin",
    description = "Two marked notes offer opposite ways to answer a Foretold result.",
    choices = {
      {
        id = "margin_defy_fate",
        type = "trick",
        contentId = "defy_fate",
        label = "Defy Fate",
        description = "Gain the Defy Fate Trick for the run.",
      },
      {
        id = "margin_fulfilled_fate",
        type = "trick",
        contentId = "fulfilled_fate",
        label = "Take Fulfilled Fate",
        description = "Gain the Fulfilled Fate Trick for the run.",
      },
    },
  },
  {
    id = "safety_cache",
    familyId = "safety",
    name = "Safety Cache",
    description = "A hidden pocket offers either a fate-touched coin or a cleaner insurance Trick.",
    choices = {
      {
        id = "safety_lucky_coin_choice",
        type = "coin",
        contentId = "copper_lucky_coin",
        label = "Take Lucky Coin",
        description = "Add Lucky Coin to your run collection.",
      },
      {
        id = "safety_ledger_choice",
        type = "trick",
        contentId = "insurance_ledger",
        label = "Take Insurance Slip",
        description = "Gain the Insurance Slip Trick for the run.",
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
