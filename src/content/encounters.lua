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
    familyId = "stash",
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
        label = "Take Heads Contract",
        description = "Gain Heads Contract for the run.",
      },
      {
        id = "tip_tails_banker",
        type = "coin",
        contentId = "tails_banker",
        label = "Pocket Tails Banker",
        description = "Add Tails Banker to your run collection.",
      },
    },
  },
  {
    id = "credit_line",
    familyId = "credit",
    name = "Credit Line",
    description = "A sympathetic croupier offers either safer insurance or a banker tuned for heads-side play.",
    choices = {
      {
        id = "credit_insurance_ledger",
        type = "upgrade",
        contentId = "insurance_ledger",
        label = "Open Insurance Ledger",
        description = "Gain Insurance Ledger for the run.",
      },
      {
        id = "credit_heads_banker",
        type = "coin",
        contentId = "heads_banker",
        label = "Take Heads Banker",
        description = "Add Heads Banker to your run collection.",
      },
    },
  },
  {
    id = "quiet_ledgers",
    familyId = "ledgers",
    name = "Quiet Ledgers",
    description = "An abandoned ledger cart offers one clean economy trick or one steadier scoring note.",
    choices = {
      {
        id = "ledger_merchant_notebook",
        type = "upgrade",
        contentId = "merchant_notebook",
        label = "Take Merchant Notebook",
        description = "Gain Merchant Notebook for the run.",
      },
      {
        id = "ledger_steady_hand",
        type = "upgrade",
        contentId = "steady_hand",
        label = "Take Steady Hand",
        description = "Gain Steady Hand for the run.",
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
        label = "Take Coupon Case",
        description = "Gain Coupon Case for the run.",
      },
      {
        id = "runner_credit_reroll",
        type = "shop_rerolls",
        amount = 2,
        label = "Bank Two Rerolls",
        description = "+2 free shop rerolls.",
      },
    },
  },
  {
    id = "annotated_margin",
    familyId = "margin",
    name = "Annotated Margin",
    description = "Two marked notes promise either steadier totals or stronger Heads-side economy.",
    choices = {
      {
        id = "margin_profit_margin",
        type = "upgrade",
        contentId = "profit_margin",
        label = "Take Profit Margin",
        description = "Gain Profit Margin for the run.",
      },
      {
        id = "margin_heads_notebook",
        type = "upgrade",
        contentId = "heads_notebook",
        label = "Take Heads Notebook",
        description = "Gain Heads Notebook for the run.",
      },
    },
  },
  {
    id = "mirror_pool",
    familyId = "mirror",
    name = "Mirror Pool",
    description = "A polished table edge reflects the safest way to press your current line.",
    choices = {
      {
        id = "mirror_mark_choice",
        type = "coin",
        contentId = "mirror_mark",
        label = "Take Mirror Mark",
        description = "Add Mirror Mark to your run collection.",
      },
      {
        id = "mirror_purse_choice",
        type = "shop_points",
        amount = 4,
        label = "Take the mirrored purse",
        description = "+4 shop points for the next stop.",
      },
    },
  },
  {
    id = "streak_office",
    familyId = "streak_office",
    name = "Streak Office",
    description = "An old scorekeeper offers a way to monetize momentum before the market opens.",
    choices = {
      {
        id = "streak_credit_choice",
        type = "upgrade",
        contentId = "streak_credit",
        label = "Take Streak Credit",
        description = "Gain Streak Credit for the run.",
      },
      {
        id = "streak_rerolls_choice",
        type = "shop_rerolls",
        amount = 2,
        label = "Bank two rerolls",
        description = "+2 free shop rerolls.",
      },
    },
  },
  {
    id = "safety_cache",
    familyId = "safety",
    name = "Safety Cache",
    description = "A hidden pocket offers either a safety pin for missed batches or a cleaner insurance ledger.",
    choices = {
      {
        id = "safety_pin_choice",
        type = "coin",
        contentId = "parachute_pin",
        label = "Take Parachute Pin",
        description = "Add Parachute Pin to your run collection.",
      },
      {
        id = "safety_ledger_choice",
        type = "upgrade",
        contentId = "insurance_ledger",
        label = "Take Insurance Ledger",
        description = "Gain Insurance Ledger for the run.",
      },
    },
  },
  {
    id = "momentum_booth",
    familyId = "momentum",
    name = "Momentum Booth",
    description = "A streak-minded bookie offers a tails combo piece or a cleaner all-match payoff.",
    choices = {
      {
        id = "momentum_tails_echo",
        type = "coin",
        contentId = "tails_echo",
        label = "Take Tails Echo",
        description = "Add Tails Echo to your run collection.",
      },
      {
        id = "momentum_parlay_notes",
        type = "upgrade",
        contentId = "parlay_notes",
        label = "Take Parlay Notes",
        description = "Gain Parlay Notes for the run.",
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
