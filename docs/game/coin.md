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

Black Market Material Weights:

- Copper / regular: 50%
- Silver: 35%
- Gold: 15%

All materials keep `Base Score: 10`. Material improves the archetype payoff, not the raw coin value.

Notes:

- open questions or implementation constraints
```

## Bent Coin

Archetype: Bent

Tags: `prestige`, `bent`, `unstable`

Base Score: 10

Mechanic Terms:

- `outcome`
- `prestige_replay`
- `outcome`

Behavior:

- is the cleanest coin archetype for Prestige Tricks
- supports replaying completed coin Outcomes as discounted encores
- does not create extra coin bodies, forge identities, move coins, reroll results or change individual odds by itself

Trick Synergy:

- Encore
- Curtain Call
- Impossible Finale

Material Variants:

- Copper: `40%` specialized Encore replay value
- Silver: `60%` specialized Encore replay value
- Gold: `80%` specialized Encore replay value

Notes:

- Bent Coin identity is instability in resolution, not physical duplication
- Prestige uses Bent Coin to replay what already happened at reduced value
- Outcome replays need caps so Bent Coin does not create endless loops

## Flywheel Coin

Archetype: Flywheel

Tags: `momentum`, `flywheel`, `motion`, `propagation`

Base Score: 10

Mechanic Terms:

- `in_motion`
- `momentum_link`
- `momentum_depth`

Behavior:

- is the cleanest coin archetype for Momentum Tricks
- supports live Momentum links where one coin triggers another coin
- acts as the preferred basis for keeping a flip moving
- does not score double by default just because Momentum targets it

Trick Synergy:

- Keep It Rolling
- Follow Through
- Ripple

Material Variants:

- Copper: `1x` triggered Momentum score
- Silver: `1.25x` triggered Momentum score
- Gold: `1.5x` triggered Momentum score

Notes:

- Flywheel Coin identity is stored motion and continuing spin
- visually it should read like a flywheel, car rim or heavy rotating disc
- Momentum propagation needs caps so Flywheel Coin does not create endless loops

## Hollow Coin

Archetype: Hollow

Tags: `smuggle`, `hollow`, `contraband`, `hand_overflow`

Base Score: 10

Mechanic Terms:

- `smuggle_coin_from_hand`
- `overloaded_board`
- `contraband_copy`
- `add_next_hand_draws`

Behavior:

- is the cleanest coin archetype for Smuggling Tricks
- supports forcing real unselected hand coins onto overload slots
- can act as preferred source or anchor for temporary contraband copies
- does not forge identities, move already-selected coins or change Heads/Tails results by itself

Trick Synergy:

- Hidden Pocket
- Hidden in Plain Sight
- Off the Books
- Planted Double
- Embarrassment of Riches

Material Variants:

- Copper: highest-priority baseline smuggling body
- Silver: `1.25x` material payoff when smuggled by Hidden in Plain Sight
- Gold: `1.5x` material payoff when smuggled by Hidden in Plain Sight

Notes:

- Smuggled coins are real owned hand coins moved onto the board
- multiplied contraband copies are temporary board bodies and are removed after the flip
- if one Hollow Coin enters and becomes two Hollow board bodies, only the original single Hollow Coin remains in the pouch afterward
- Smuggling should stay readable even when the board is overloaded

## Vanishing Coin

Archetype: Vanishing

Tags: `sleight`, `vanishing`, `palm`, `rearrangement`

Base Score: 10

Mechanic Terms:

- `swap_coins`
- `palm_failed_coin`
- `monte_rearrange`

Behavior:

- is the cleanest coin archetype for Sleight of Hand Tricks
- is a half-seen magician's coin built for palms, swaps and impossible rearrangements
- can serve as priority or eligibility for Tricks that move coin bodies through fixed result slots
- does not smuggle extra board bodies, forge identities or change Heads/Tails results by itself

Trick Synergy:

- Switcheroo
- Vanishing Act
- Three-Card Monte

Material Variants:

- Copper: baseline Sleight targeting value
- Silver: preferred over Copper by quality-aware Sleight targeting
- Gold: preferred over Silver by quality-aware Sleight targeting

Notes:

- Vanishing Coin should read as partly gone at a glance: broken rim, missing side or ghosted afterimage
- it must remain visually distinct from Blank Coin's whole empty face and Hollow Coin's central void

## Blank Coin

Archetype: Blank

Tags: `counterfeit`, `blank`, `forgery`, `copyable`

Base Score: 10

Mechanic Terms:

- `copy_outcome`
- `forge_trick_activations`
- `forged_activation`
- `genuine_left_source`

Behavior:

- is the required real coin body for Forgery Tricks;
- reads only the genuine committed non-Forgery coin immediately to its left;
- locks that neighbour's family as its acting family before Flip while remaining a real Forgery Coin;
- can copy a completed Outcome, imitate a bounded family package, or repeat one eligible Trick depending on the active Forgery line;
- remains a Blank/Forgery Coin for the locked activation ledger;
- cannot use another Forgery Coin, Smuggled body, or Contraband copy as its credential source;
- does not move coin bodies or change Heads/Tails results.

Trick Synergy:

- Fake Credentials I-III
- Borrowed Name I-III
- Forged Signature I-III

Material Variants:

- Copper, Silver, and Gold retain normal coin quality progression;
- copied activation strength is gated by Forgery Trick tier rather than an automatic material multiplier.

Notes:

- the setup UI must make the left source relationship obvious;
- target Tricks display an `F+n` preview badge before Flip;
- one bounded copied package is chosen for the whole Flip and can run during pre-roll phases;
- a forged activation cannot activate Forgery or be forged again.

## Marked Coin

Archetype: Marked

Tags: `marked`, `prediction`, `predicted_slot`, `forced_result`

Base Score: 10

Mechanic Terms:

- `predicted_slot`
- `forced_result`
- `foretold_result`

Behavior:

- the table visibly marks one Flip slot as predicted Heads or Tails for the encounter
- committing a Marked Coin to that slot forces the displayed result
- placing any other coin family there provides no forced result
- the prediction is setup information and never creates a post-Flip decision

Trick Synergy:

- Fulfilled Fate
- Read the Stars
- Written in the Stars
- Defy Fate

Material Variants:

- Copper: standard Prediction enabler
- Silver: higher-value Prediction enabler
- Gold: highest-value Prediction enabler

Notes:

- Prediction is the visible slot-contract family
- Marked Coin identity is controlled setup, not post-flip result repair
- one predicted slot per encounter creates a clear positional constraint without solving the whole hand

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
- does not change individual coin results, reroll coins, Weight odds, forge identities, move coins or create copies by itself

Trick Synergy:

- Omen Engine
- Fountain Pact
- Twist of Fate
- Fate Uncapped

Material Variants:

- Copper: `+2 Luck` on Matching Call
- Silver: `+3 Luck` on Matching Call
- Gold: `+4 Luck` on Matching Call

Notes:

- Lucky Coin identity is meter fuel and Fated Flip payoff, not individual result manipulation
- Weighted effects handle coin-level odds; Fate handles the global Luck Meter
- Fated Flip chaining needs explicit caps so Lucky Coin does not create endless destiny loops

## Weighted Coin

Archetype: Weighted

Tags: `weighted`, `weight`, `odds`, `reliable`

Base Score: 10

Mechanic Terms:

- `set_call_match_chance`
- `call_match_chance`

Behavior:

- favours the player's call
- hidden 65% baseline chance to match the player's call

Trick Synergy:

- Weighted Palm
- Headside Edge
- Tailside Edge
- Heavy Payout

Material Variants:

- Copper: `call_match_chance = 65%`
- Silver: `call_match_chance = 75%`
- Gold: `call_match_chance = 85%`
