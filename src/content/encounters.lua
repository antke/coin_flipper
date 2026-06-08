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
        id = "stash_tails_contract",
        type = "upgrade",
        contentId = "tails_contract",
        label = "Sign Tails Pact",
        description = "Gain the Tails Pact Trick for the run.",
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
        id = "tip_heads_contract",
        type = "upgrade",
        contentId = "heads_contract",
        label = "Take Heads Pact",
        description = "Gain the Heads Pact Trick for the run.",
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
        type = "upgrade",
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
    description = "An abandoned ledger cart offers one clean payout Trick or one steadier scoring Trick.",
    choices = {
      {
        id = "ledger_merchant_notebook",
        type = "upgrade",
        contentId = "merchant_notebook",
        label = "Take Street Ledger",
        description = "Gain the Street Ledger Trick for the run.",
      },
      {
        id = "ledger_steady_hand",
        type = "upgrade",
        contentId = "steady_hand",
        label = "Take Steady Finish",
        description = "Gain the Steady Finish Trick for the run.",
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
        type = "upgrade",
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
    description = "Two marked notes promise either steadier Influence flow or stronger Heads-side payouts.",
    choices = {
      {
        id = "margin_merchant_notebook",
        type = "upgrade",
        contentId = "merchant_notebook",
        label = "Take Street Ledger",
        description = "Gain the Street Ledger Trick for the run.",
      },
      {
        id = "margin_heads_notebook",
        type = "upgrade",
        contentId = "heads_notebook",
        label = "Take Heads Ledger",
        description = "Gain the Heads Ledger Trick for the run.",
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
        type = "upgrade",
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
