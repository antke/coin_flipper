# Coins

## Definition Template

```md
## Coin Name

Archetype: Bent / Blank / Hollow / Marked / Lucky / Weighted

Tags: `tag`, `tag`

Base Score: 10

Mechanic Terms:

- `canonical_action_or_value`

Behavior:

- direct coin behavior

Trick Synergy:

- Trick family or specific Trick

Material Variants:

- Copper: baseline expression
- Silver: stronger expression of the same mechanic
- Gold: strongest expression of the same mechanic

Notes:

- open questions or implementation constraints
```

## Bent Coin

Archetype: Bent

Tags: `prestige`, `chain`, `bent`, `unstable`

Base Score: 10

Mechanic Terms:

- `resolution_packet`
- `prestige_replay`
- `chained_coin`
- `chain_depth`

Behavior:

- is the cleanest coin archetype for Prestige and Chain Tricks
- supports replaying completed resolution packets as discounted encores
- supports live Chain links where one coin triggers another coin
- does not create extra coin bodies, forge identities, move coins, reroll results or change individual odds by itself

Trick Synergy:

- Encore
- Curtain Call
- Impossible Finale
- Domino Line
- Chained Payout
- Deep Link

Material Variants:

- Copper: baseline eligibility or priority for packet replay and Chain effects
- Silver: stronger replay priority, Chain-link priority or Chained payoff eligibility
- Gold: strongest replay priority, deeper Chain support or premium finale eligibility

Notes:

- Bent Coin identity is instability in resolution, not physical duplication
- Prestige uses Bent Coin to replay what already happened at reduced value
- Chain uses Bent Coin to help one coin knock into another live trigger
- packet replays and Chain propagation both need caps so Bent Coin does not create endless loops

## Hollow Coin

Archetype: Hollow

Tags: `smuggle`, `hollow`, `contraband`, `hand_overflow`

Base Score: 10

Mechanic Terms:

- `smuggle_coin_from_hand`
- `overloaded_board`
- `contraband_copy`
- `increase_refill_count`

Behavior:

- is the cleanest coin archetype for Smuggling Tricks
- supports forcing real unselected hand coins onto overload slots
- can act as preferred source or anchor for temporary contraband copies
- does not forge identities, reroute score credit, move already-selected coins or change Heads/Tails results by itself

Trick Synergy:

- Sleeve Pocket
- Backroom Refill
- Planted Double
- Overloaded Table

Material Variants:

- Copper: baseline priority or eligibility for Smuggling effects
- Silver: stronger refill, overload-slot or smuggled-source priority
- Gold: strongest priority, multi-copy eligibility or higher overload-cap support

Notes:

- Smuggled coins are real owned hand coins moved onto the board
- multiplied contraband copies are temporary board bodies and are removed after the flip
- if one Hollow Coin enters and becomes two Hollow board bodies, only the original single Hollow Coin remains in the pouch afterward
- Smuggling should stay readable even when the board is overloaded

## Blank Coin

Archetype: Blank

Tags: `counterfeit`, `blank`, `forgery`, `copyable`

Base Score: 10

Mechanic Terms:

- `forged_identity`
- `forge_identity`
- `add_forged_identity`

Behavior:

- is the cleanest medium for Forgery Tricks
- can replace its identity with a template identity for one check at low tier
- can keep its original Blank identity and add fake credentials at higher tier
- does not create extra coins, add slots, move coin bodies or change Heads/Tails results by itself

Trick Synergy:

- Borrowed Name
- Fake Credentials
- Copycat Jackpot
- Forgery Audit

Material Variants:

- Copper: baseline priority or eligibility for forged identity effects
- Silver: stronger priority, longer check window or better forged payout eligibility
- Gold: strongest priority, multi-copy eligibility or premium forged-trigger support

Notes:

- Blank Coin identity is fake papers and open credentials, not physical duplication
- Forgery should reward creative template choice, especially slot 1 and last slot positioning
- copied triggers and payouts need explicit caps so Blank Coin does not create recursive loops

## Marked Coin

Archetype: Marked

Tags: `marked`, `foretold`, `read`

Base Score: 10

Mechanic Terms:

- `foretell_coin_result`
- `foretold_result`

Behavior:

- can become Foretold when dealt
- a Foretold coin shows its future Heads/Tails result before selection
- does not convert, reroll or repair its own result after the flip

Trick Synergy:

- See Behind the Veil
- Fulfilled Fate
- Ancient Patterns

Material Variants:

- Copper: baseline chance or priority to become Foretold
- Silver: stronger chance or priority to become Foretold
- Gold: strongest chance or priority to become Foretold

Notes:

- Prediction? is still a question-mark category
- Marked Coin identity is foreknowledge, not post-flip result repair
- avoid revealing so many results that selection becomes obvious

## Lucky Coin

Archetype: Lucky

Tags: `fate`, `luck_meter`, `fated_flip`, `destiny`

Base Score: 10

Mechanic Terms:

- `luck_meter`
- `luck_gain`
- `fated_flip`
- `fated_flip_payoff`

Behavior:

- is the cleanest coin archetype for Fate Tricks
- helps fill or amplify the Luck Meter
- makes Fated Flip payoff builds more reliable
- does not change individual coin results, reroll coins, Weight odds, forge identities, move coins, reroute score credit or create copies by itself

Trick Synergy:

- Omen Engine
- Fountain Pact
- Twist of Fate
- Fate Uncapped

Material Variants:

- Copper: baseline Luck gain or priority for Fate effects
- Silver: stronger Luck gain, Fountain Favor interaction or Fated Flip payoff eligibility
- Gold: strongest Luck gain, chain support or premium Fated Flip payoff eligibility

Notes:

- Lucky Coin identity is meter fuel and Fated Flip payoff, not individual result manipulation
- Loaded/Weighted effects handle coin-level odds; Fate handles the global Luck Meter
- Fated Flip chaining needs explicit caps so Lucky Coin does not create endless destiny loops

## Weighted Coin

Archetype: Weighted

Tags: `loaded`, `weight`, `odds`, `reliable`

Base Score: 10

Mechanic Terms:

- `set_call_match_chance`
- `call_match_chance`

Behavior:

- favours the player's call
- hidden 65% baseline chance to match the player's call

Trick Synergy:

- Weighted Palm
- Loaded Edge
- Heavy Payout

Material Variants:

- Copper: `call_match_chance = 65%`
- Silver: `call_match_chance = 75%`
- Gold: `call_match_chance = 85%`
