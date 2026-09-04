# Tricks

> Historical content reference (superseded mechanically): the current approved
> activation model and first-pass conversions are in
> `../family-trigger-engine-design.md` and
> `../family-trigger-trick-migration.md`. This file remains useful for family
> identity, existing targets, and prior implementation notes, but its
> same-archetype preferences and globally active Trick assumptions are not the
> implementation target.

## Definition Template

```md
## Trick Name

Category: Weighted / Prediction / Sleight of Hand / Forgery / Smuggling / Fate / Prestige / Momentum

Tags: `tag`, `tag`

Tier: I / II / III

Timing: after_deal_before_selection / after_call_before_flip / condition_check / target_selection / luck_gain / luck_meter_full / before_flip / during_fated_flip / after_flip_before_score / before_score / before_coin_score / after_score / after_coin_score / after_trigger / momentum_step / refill_hand / after_all_effects

Requirements:

- canonical requirement terms

Automatic Target Rule:

- deterministic targeting rule

Actions:

- canonical action terms

Scope Limits:

- once_per_flip / once_per_coin / once_per_fated_flip / once_per_prestige / max_board_coins / max_momentum_depth / max_triggers etc.

Synergy:

- coin archetypes or other Tricks

Enemy Version:

- optional rival-cheat version

Implementation:

- current code support or required engine work
```

## Modern Modular Trick Checklist

A Trick is ready for the updated modular system when it has:

- a clear `trick.category`, tags, tier, and player-facing family identity
- one or more explicit hook timings mapped to supported engine phases
- deterministic requirements and trigger conditions
- a deterministic automatic target rule, preferably expressed with selectors
- actions expressed as modular action ops, not one-off custom behavior
- explicit scope limits such as once per flip, once per coin, once per deal, or max Momentum depth
- trace metadata for any result-changing, RNG, targeting, identity, replay, or scoring effect
- focused fixture coverage when it adds or changes engine behavior

Tiered Trick lines should use a shared `trick.lineId`. A run may own only one Trick in a line; granting a higher tier replaces the weaker owned tier, while same-tier or lower-tier grants are rejected.

Old upgrade-style effects may remain valid Tricks, but they should be treated as migration candidates when they do not use a family mechanic, selector, scoped trigger, or traceable modular action.

## Current Weighted Family Audit

Weighted is a good first family for the modular system. Its tricks use probability actions before results exist, plus a narrow family selector filter for random Weighted targeting.

| Current Trick | Status | Checklist Notes | Next Action |
| --- | --- | --- | --- |
| `weighted_palm` / Weighted Palm | Modern baseline | Has category/tags/tier, `before_flip` timing mapped to `before_coin_roll`, selector targeting, `set_call_match_chance`, `oncePerFlip`, and replay fixture coverage. | Keep as the reference Tier I Weighted trick. |
| `heads_varnish` / Headside Edge | Modern enough | Uses `add_weight` before roll on Heads Flip, applies per selected coin, has family specialization and `maxTriggersPerCoin = 1`. Targeting is implicit through the per-coin hook rather than a selector. | Keep as the broad Heads Flip support trick. |
| `weighted_tail_coating` / Tailside Edge | Modern enough | Uses a deterministic random selector to boost one selected Weighted Coin on Tails Flip. It is modular and family-aligned. | Keep at +30% Tails Chance with no fallback when no selected Weighted Coin exists. |

Weighted family verdict: ready for the updated trick system. Current names are accepted; the next Weighted pass should only happen if a new target shape or new trick is designed.

## Weighted Palm I

Category: Weighted

Tags: `weighted`, `weight`, `auto`

Tier: I

Timing: before_flip

Requirements:

- `requires_selected_coin`

Automatic Target Rule:

- automatically target the first selected Weighted Coin
- if there are none, target the first selected coin

Actions:

- set a minimum `call_match_chance = 75%` for the target coin this flip; never reduce a Silver/Gold coin's native odds
- matching Copper/Silver/Gold Weighted Coins score `1.5x` / `1.75x` / `2x`

Scope Limits:

- chance floor once per flip
- material payout once per matching Weighted Coin

Synergy:

- Weighted Coin
- Heavy Payout
- Weighted Tricks
- probability builds

Enemy Version:

- the opponent adds Weight away from the player's call before the flip
- prefer the highest-value selected coin

Implementation:

- needs `set_call_match_chance`
- maps design timing `before_flip` to current hook `before_hand_flip` / `before_coin_roll`

Notes:

- Weighted Tricks affect probability before results exist
- Weighted Tricks should not convert or reroll results after the flip
- Weight is the player-facing keyword for this family

## See Behind the Veil I

Category: Prediction

Tags: `prediction`, `marked`, `foretold`, `read`, `auto`

Tier: I

Timing: after_deal_before_selection

Requirements:

- dealt coins exist

Automatic Target Rule:

- Foretell a random Marked Coin if possible
- if there are none, Foretell a random dealt coin
- use deterministic run RNG

Actions:

- `foretell_coin_result` for the target coin
- reveal the target coin's `foretold_result` before selection
- set the target coin flag `foretold`

Scope Limits:

- `once_per_deal`

Synergy:

- Marked Coin
- Fulfilled Fate
- Ancient Patterns
- Card Shark builds

Enemy Version:

- the opponent reveals one coin result, then taxes or pressures obvious selections

Implementation:

- needs `after_deal_before_selection`
- needs stable `foretold_result` state on dealt coin instances
- UI must show the foretold Heads/Tails result on the coin before selection

Notes:

- Prediction is foreknowledge attached to dealt coins, not individual coin calls
- player agency comes from selecting and ordering around known coin results

## Fulfilled Fate I

Category: Prediction

Tags: `prediction`, `marked`, `foretold`, `fulfillment`, `score_scaling`

Tier: I

Timing: before_coin_score

Requirements:

- `requires_foretold_coin`
- the coin is selected
- the coin has Matching Call

Automatic Target Rule:

- target the first selected Foretold Coin with Matching Call

Actions:

- Copper/Silver/Gold Marked Coins score `2x` / `2.5x` / `3x`
- non-Marked Foretold coins receive no Fulfilled Fate material payoff

Scope Limits:

- `once_per_flip`

Synergy:

- See Behind the Veil
- Marked Coin
- Weighted Tricks that make a known call more valuable

Enemy Version:

- the opponent rewards coins whose foretold result works against the player's call

Implementation:

- needs `requires_foretold_coin`
- scoring check should use the revealed `foretold_result` and current player `call`

Notes:

- fulfillment rewards should be capped so the obvious line is not always "see three Heads, pick three Heads for a Heads Flip"
- this payoff should reward using visible foreknowledge, not passive hidden patterns

## Heads Pact I / Tails Pact I

Category: Prediction

Tags: `prediction`, `foretold`, `heads` / `tails`, `score_scaling`

Tier: I

Timing: before_coin_score

Requirements:

- Heads Pact: Heads Flip
- Tails Pact: Tails Flip
- selected Foretold Coin has Matching Call

Automatic Target Rule:

- all selected Foretold Coins with Matching Call

Actions:

- `multiply_score = 1.25x` for each matching Foretold Coin

Scope Limits:

- `max_triggers_per_coin = 1`

Notes:

- these are Prediction payoffs, not aggregate call-only score multipliers
- they reward selecting around visible Foretold results

## Ancient Pattern I

Category: Prediction

Tags: `prediction`, `marked`, `foretold`, `ancient_pattern`, `pattern`

Tier: I

Timing: before_score

Requirements:

- selected coins have enough revealed `foretold_result` values to check the pattern

Automatic Target Rule:

- read selected coins left to right
- compare their foretold results against the Trick's pattern

Actions:

- if selected foretold results match `T-H-T`, `add_score` or `add_influence`

Scope Limits:

- `once_per_flip`

Synergy:

- See Behind the Veil
- Fulfilled Fate
- Marked Coin
- order-based Tricks

Enemy Version:

- the opponent punishes a visible pattern if the player selects into it carelessly

Implementation:

- needs `ancient_pattern` matching against selected order
- UI should show the active Ancient Pattern before selection if the player owns the Trick

Notes:

- Ancient Patterns are the variance/fallback branch of Prediction
- they can compensate for hands where the best raw call is weak
- stacking too many patterns risks turning Prediction into passive bonus soup

## Sleight of Hand Family Notes

Sleight of Hand Tricks are physical coin manipulation: fast hands, street-hustler swaps, palming and three-cup rearrangements.

They move regular committed coin bodies through already-resolved slots or save a failed committed body by palming it into hand. They do not change results, reroll coins, add odds, reveal prophecy, move Contraband or create copies.

Vanishing Coin is the physical-manipulation coin for this family. It is a half-seen magician's coin built for palms, swaps and impossible rearrangements.

## Switcheroo I

Category: Sleight of Hand

Tags: `sleight`, `swap`, `match`, `miss`

Current description: If the activating Sleight coin Matches, switch it with one random higher-value Miss.

Tier: I

Timing: after_flip_before_score

Requirements:

- the activating Sleight coin is a regular committed Match
- at least one higher-value regular committed Miss exists

Automatic Target Rule:

- Tier I chooses a random higher-value Miss
- Tier II chooses randomly inside the highest eligible material band
- Tier III chooses the highest-value eligible Miss and randomly breaks ties

Actions:

- `swap_coins`
- preserve both resolved Heads/Tails slots
- add no hidden score multiplier

Scope Limits:

- `once_per_activation`
- a body moved by Sleight cannot be moved again during the same flip

Synergy:

- position-based coins
- edge and neighbour effects
- high-base-score coins
- Vanishing Coin
- local result-slot effects

Enemy Version:

- the opponent swaps the player's best scoring Match out before scoring

Implementation:

- supported by `swap_coins`
- scoring reads the coin body currently occupying each resolved slot

Notes:

- this is the cleanest Sleight of Hand example: the flip result stays `T T H`, but the valuable Miss can trade places with the weakest Match
- should feel like the coin was always under the other cup

## Vanishing Act I–III

Category: Sleight of Hand

Tags: `sleight`, `palm`, `save`, `miss`, `hand`

Current description: Palm a failed regular committed coin back into hand instead of spending it.

Tier: I–III

Timing: after_flip_before_score

Requirements:

- an eligible regular committed Miss exists
- the body has not already been moved or palmed this flip

Automatic Target Rule:

- Tier I targets the activating Miss
- Tier II targets the highest-value Miss among the activating slot and its neighbours
- Tier III targets the highest-value regular committed Miss on the table

Actions:

- `palm_failed_coin`
- make the palmed body score zero this flip
- retain the real body in the next hand instead of exhausting it

Scope Limits:

- `once_per_activation`
- Smuggled and Contraband bodies are ineligible

Synergy:

- expensive coins worth preserving
- Vanishing Coin
- hand management

Enemy Version:

- the opponent prevents one failed coin from being recovered

Implementation:

- supported by `palm_failed_coin` and refill retention
- saving happens automatically before scoring

Notes:

- the palmed coin does not rescue current score; it preserves future inventory
- hand-to-table movement belongs to Smuggling

## Three-Card Monte I–III

Category: Sleight of Hand

Tags: `sleight`, `rearrange`, `neighbor`, `position`

Current description: Automatically choose a strictly score-improving local arrangement of regular committed coin bodies.

Tier: I–III

Timing: after_flip_before_score

Automatic Target Rule:

- Tier I chooses a random improving swap with one neighbour
- Tier II chooses the best improving neighbour swap
- Tier III chooses the best permutation of the activating slot and both neighbours

Actions:

- `monte_rearrange`
- keep results and slot modifiers fixed
- move only regular committed bodies
- do nothing when no arrangement strictly improves immediate score

Scope Limits:

- `once_per_activation`
- each involved body is locked against another Sleight move this flip
- Smuggled and Contraband bodies are ineligible

## Forgery Family Notes

Forgery is a hybrid support family: fake credentials, copied Outcomes, borrowed family papers, and forged Trick signatures. It enhances another developed family rather than forming a complete isolated machine.

A real Blank/Forgery Coin reads the genuine non-Forgery coin immediately to its left. Before Flip it locks that neighbour's family as its acting family plus one bounded target package per Forgery Trick. That relationship is visible during setup and immutable during execution. Slot 1, another Forgery Coin, Smuggled bodies, and Contraband copies cannot supply credentials.

Forgery never changes locked real family identity. Instead, it schedules explicit forged activations using the Blank Coin as source. Copied activations run in every target Trick's normal phase—including pre-roll phases—respect normal conditions and opponent pressure, and cannot activate Forgery or be forged again. The target list is chosen once for the whole Flip rather than separately per phase.

Tier direction:

- Fake Credentials I-III copies 50% / 75% / 100% of a successful left neighbour's completed root Outcome when the Forgery Coin misses.
- Borrowed Name I-III rigs the Blank to imitate up to one / two / three eligible Tricks, capped at Tier I / II / III.
- Forged Signature I-III rigs the Blank to repeat one highest-tier eligible Trick, capped at Tier I / II / III.

This creates a real hybrid cost. The player spends Trick capacity and pouch quality on Forgery instead of simply adding more primary-family pieces. Low-tier Forgery cannot repeat a Tier III payoff, while a developed Forgery line can substantially enhance an established Prestige, Momentum, Weighted, Prediction, Sleight, or Smuggling engine.

## Fake Credentials I-III

Category: Forgery

Tags: `counterfeit`, `outcome`, `blank`, `neighbor`

Tier: I / II / III

Timing: after_all_effects

Requirements:

- the activating real Forgery Coin missed;
- its immediate left neighbour is a genuine committed non-Forgery coin;
- the left neighbour produced a positive root Outcome.

Actions:

- `copy_outcome` from the immediate left root Outcome at 50% / 75% / 100%;
- keep the Forgery Coin's result and Match state unchanged;
- record the score under `forgedOutcomeCopies` with no recursive copying.

## Borrowed Name I-III

Category: Forgery

Tags: `counterfeit`, `activation`, `blank`, `neighbor`

Tier: I / II / III

Timing: multi-phase

Requirements:

- the setup-locked real Forgery Coin has a valid acting-family assignment;
- its immediate left neighbour supplies a genuine non-Forgery family;
- eligible selected Tricks from that family exist within the tier ceiling.

Actions:

- I imitates one Tier I Trick;
- II imitates up to two Tier I-II Tricks;
- III imitates up to three Tier I-III Tricks;
- select lower-tier foundations first and use board order as stable tie-break;
- execute each copied Trick in its normal phase using the Blank Coin as source.

## Forged Signature I-III

Category: Forgery

Tags: `counterfeit`, `activation`, `signature`, `neighbor`

Tier: I / II / III

Timing: multi-phase

Requirements:

- the setup-locked real Forgery Coin has a valid acting-family assignment;
- its immediate left neighbour supplies a genuine non-Forgery family;
- at least one eligible Trick exists at or below the Signature tier.

Actions:

- select exactly one highest-tier eligible Trick;
- use board order as stable tie-break;
- repeat that Trick in its normal phase using the Blank Coin as source;
- record the parent Forgery Trick, genuine source coin, forged family, target Trick, and chain depth.

Scope Limits:

- `once_per_activation`;
- no Forgery target family;
- no forged source chain;
- no recursive forged activation;
- normal Block, Weaken, and Jam rules remain active.

## Extortion Family Notes

Extortion Tricks are short-lived economy and acquisition scams. They make the Black Market and Spoils feel like theft, pressure and leverage rather than passive background discounts.

Extortion intentionally has no dedicated coin archetype. Its identity lives in Influence pressure, Black Market theft, Spoils leverage and Crumbling Charms rather than a physical coin body.

Canonical stage terms:

- **Black Market** is the Coin shop. It buys Coins, sells/refines/removes Coins, allows Fountain visits and rerolls Coin stock. It is not the normal place to acquire Charms.
- **Spoils** is the post-enemy Charm acquisition screen.
- **Seize** means spending Influence to take a Charm from Spoils.
- **Crumbles** means the Charm breaks after its last use and is removed from the run.

Tier rule for Crumbling Extortion Charms:

- Tier I has 1 use.
- Tier II has 2 uses.
- Tier III has 3 uses.
- The use unit depends on the Charm: Black Market visits, Black Market rerolls, extorted Coins, Spoils screens or Seized Charms.

Implemented Extortion lines:

- **Five-Finger Discount I-III**: At the next 1/2/3 Black Market visits, extort the cheapest Coin. Rerolls do not refresh this. Then this Charm Crumbles.
- **Loaded Shelves I-III**: At the next 1/2/3 Black Market visits, guarantee at least one uncommon-or-better Coin if possible. Then this Charm Crumbles.
- **Pressure Sale I-III**: At the next 1/2/3 Black Market rerolls, returned Coin offers cost 1 less Influence per consecutive reroll this visit. Then this Charm Crumbles.
- **No Questions Asked I-III**: The next 1/2/3 times you take an extorted Coin, gain +1 Free Reroll. Then this Charm Crumbles.
- **Strong-Arm Deal I-III**: The next 1/2/3 Spoils screens show +1 extra Charm option. Then this Charm Crumbles.
- **Take What's Owed I-III**: The next 1/2/3 Charms you Seize from Spoils cost 2 less Influence. Then this Charm Crumbles.
- **Protection Racket I-III**: The next 1/2/3 Spoils screens include +1 extra Charm option from the defeated enemy's family if possible. Then this Charm Crumbles.
- **Forced Confession I-III**: The next 1/2/3 Spoils screens reveal +1 higher-tier Charm option if possible. Then this Charm Crumbles.

Boundaries:

- Extortion changes offer visibility, temporary pricing, free rerolls and Spoils option counts.
- Extortion does not change flip results, coin bodies, identity or Luck/Fated Flip state.
- Because most Extortion Charms Crumble, they should pay out quickly and avoid permanently competing with late-run build Charms.

## Smuggling Family Notes

Smuggling Tricks are illegal capacity and board-overload effects: sleeve pockets, planted doubles, overflowing hands and too many coins on the table.

They physically force extra coin bodies from hand onto the board. A normal flip might select 3 coins and flip 3; a Smuggling build tries to select 3, call, then flip 4, 5 or far more coins by overloading the board.

Smuggling is strictly inbound and additive: it brings uncommitted hand coins onto anchored overload positions. It never extracts, palms, replaces or swaps an active body; those are Sleight of Hand operations. It does not forge identity, payout or trigger checks. That is Forgery. It does not change Heads/Tails results or probability.

Core direction:

- Stockpile path: buy many coins, keep the hand full, increase post-flip refill and force real unselected hand coins onto the board.
- Multiplication path: one real hand coin enters the board, then creates temporary contraband copies of that same coin for this flip.
- Payoff path: reward board overload, smuggled coins and contraband copies without making every extra coin automatically infinite value.

Real smuggled coins are owned coins from the hand. Multiplication copies are temporary board bodies: if one XYZ coin enters and becomes two XYZ bodies on the board, only the original single XYZ coin remains in the pouch after the flip.

Caps may happen naturally through hand size, refill count and board readability, but Smuggling entries should leave room for explicit `max_board_coins` or `no_recursive_multiplication` limits if needed.

## Hidden Pocket I

Category: Smuggling

Tags: `smuggle`, `slots`

Tier: I

Timing: on_acquire

Actions:

- `increase_coin_slots` by 1

Notes:

- this is the simple Smuggling capacity enabler
- it increases legal Flip Slots; it does not create an overload slot by itself

## Hidden in Plain Sight I

Category: Smuggling

Tags: `smuggle`, `hand`, `board_overload`, `extra_coin`

Tier: I

Timing: after_call_before_flip

Requirements:

- `requires_unselected_hand_coin`
- player has completed call and arrangement

Automatic Target Rule:

- choose one unselected hand coin
- prefer a Hollow Coin
- if tied, choose the first unselected hand coin

Actions:

- `create_overload_slot`
- `smuggle_coin_from_hand` into that overload slot
- `mark_smuggled_coin`
- the smuggled coin flips and resolves as a real board coin this flip

Scope Limits:

- `once_per_flip`
- `max_board_coins` if needed

Synergy:

- Hollow Coin
- Off the Books
- Planted Double
- Embarrassment of Riches
- coin-purchase and hand-size builds

Enemy Version:

- the opponent overloads the table with one pressure coin or forces the player's worst hand coin into the flip

Implementation:

- needs hand coins and board coins as separate zones
- needs legal selected slots and overload slots to be visible in logs/UI
- needs smuggled coins to enter before flip so they generate their own result

Notes:

- this is the cleanest Smuggling example: a real coin moves from hand to board after the call
- the coin is not temporary by default; it follows normal used-coin/refill rules after resolving

## Off the Books I

Category: Smuggling

Tags: `smuggle`, `refill`, `hand`, `stockpile`

Tier: I

Timing: on_batch_end / next hand deal

Requirements:

- `requires_smuggled_coin_this_flip`

Automatic Target Rule:

- after a flip where at least one coin was smuggled
- apply to the next hand deal

Actions:

- `add_next_hand_draws` by 1
- the next hand draws one extra owned pouch coin if available

Scope Limits:

- `once_per_flip`

Synergy:

- Hidden in Plain Sight
- Embarrassment of Riches
- coin-purchase builds
- large pouch builds

Enemy Version:

- the opponent pressures the player's refill, making Smuggling lines harder to restock

Implementation:

- needs next-hand draw banking after batch end
- logs should show the banked bonus draw and the later hand consuming it

Notes:

- this is an enabler, not the payoff
- Smuggling should care about buying and owning enough coins; refill support keeps the hand from emptying too fast

## Planted Double I

Category: Smuggling

Tags: `smuggle`, `multiply`, `contraband_copy`, `temporary`

Tier: I

Timing: after_call_before_flip

Requirements:

- `requires_smuggled_coin`

Automatic Target Rule:

- roll a 50% chance
- if successful, choose a random smuggled coin already on the board this flip

Actions:

- `copy_smuggled_coin` for the target smuggled coin
- `create_overload_slot`
- `create_contraband_copy` of that coin in the overload slot
- the copy flips and resolves as an extra temporary board body

Scope Limits:

- `once_per_flip`
- `temporary_copy`
- `original_only_returns_to_pouch`
- `no_recursive_multiplication`
- `max_board_coins` if needed

Synergy:

- Hidden in Plain Sight
- Hollow Coin
- Embarrassment of Riches
- high-value coins worth multiplying

Enemy Version:

- the opponent creates a temporary pressure duplicate that disappears after the flip

Implementation:

- needs temporary board bodies that can flip and score
- needs cleanup so only the original owned coin persists after resolution
- needs source tracking for copied-from coin/body metadata

Notes:

- this is Smuggling, not Forgery: it copies physical board presence, not identity checks, payout records or trigger credentials
- an XYZ coin may become two XYZ board bodies for the flip, but the pouch still contains one owned XYZ coin afterward

## Embarrassment of Riches I

Category: Smuggling

Tags: `smuggle`, `overloaded_board`, `payoff`, `extra_coin`

Tier: I

Timing: before_coin_score

Requirements:

- current coin was not selected in the original flip but ended up being flipped
- implemented as `smuggled = true`
- current coin matched the call

Automatic Target Rule:

- each matching smuggled coin, including contraband copies

Actions:

- `apply_score_scaling` 1.5x to the current coin score

Scope Limits:

- no result change
- applies per eligible unselected flipped coin

Synergy:

- Hidden in Plain Sight
- Off the Books
- Planted Double
- large pouch builds

Enemy Version:

- the opponent overloads the encounter with extra pressure that must be cleared or survived

Implementation:

- needs deterministic per-coin scoring for smuggled/unselected flipped bodies
- logs should show every smuggled coin that received the 1.5x score scaling

Notes:

- this is the payoff branch for flipping coins that were not originally selected
- the current Tier I version gives every matching smuggled coin a 1.5x payoff

## Fate Family Notes

Fate Tricks are Luck Meter engines and Fated Flip payoffs: omens, fountain bargains, destiny engines and whole-flip blessings.

They do not create coins, copy coins, move coin bodies, forge identities, reroll coins, add Weight, or change individual coin results. Weighted owns individual odds and result manipulation. Fate owns the global meter and the global Fated Flip payoff layer.

Core directions:

- accelerate Luck Meter progress
- amplify Luck gain, especially Fountain Favor
- add rewards because the current flip is Fated
- at high tier, allow Luck to keep filling during Fated Flips so Fated Flips can chain

Fated Flip retriggers should affect the whole Fated Flip resolution/payoff layer. They should not become targeted per-coin fixes or copied-trigger loops.

## Omen Engine I

Category: Fate

Tags: `fate`, `luck_meter`, `luck_gain`, `accelerator`

Tier: I

Timing: luck_gain

Requirements:

- `requires_luck_meter`
- `requires_luck_gain`
- positive Luck gain event

Automatic Target Rule:

- target the player's `luck_meter`
- no individual coin target is chosen

Actions:

- `add_luck = +2` to the Luck Meter when a positive Luck gain event occurs

Scope Limits:

- `once_per_flip`
- `meter_only`
- `no_individual_coin_targeting`
- `no_fated_result_change`

Synergy:

- Lucky Coin
- Fountain Pact
- Twist of Fate
- Fate Uncapped

Enemy Version:

- the opponent accelerates its pressure timer when the player's Luck Meter gains progress

Implementation:

- needs Luck gain events to be visible before or after meter application
- current runtime already has an `add_luck` action and Luck Meter state

Notes:

- this is the cleanest Fate accelerator
- it should feel like successful calls feed destiny, not like a coin's odds changed

## Fountain Pact I-III

Category: Fate

Tags: `fate`, `fountain_favor`, `luck_gain`, `accelerator`

Tier: I, II, III

Timing: passive

Requirements:

- `requires_luck_meter`
- positive Luck generation

Automatic Target Rule:

- target the player's `luck_meter`
- no individual coin target is chosen

Actions:

- Fountain Pact I sets global Luck generation speed to `1.5x`
- Fountain Pact II sets global Luck generation speed to `1.75x`
- Fountain Pact III sets global Luck generation speed to `2x`
- if multiple Pact tiers are owned, the highest tier wins

Scope Limits:

- `meter_only`
- `no_individual_coin_targeting`
- `no_fated_result_change`
- positive Luck only; negative meter changes and Fated Flip reset are not multiplied

Synergy:

- Fountain sacrifices
- Lucky Coin
- Omen Engine
- Fate Uncapped

Enemy Version:

- the opponent taxes or weakens the player's Fountain Favor Luck bonus for one encounter

Implementation:

- implemented as a passive effective value on Luck generation
- all Fountain Pact tiers share the `fountain_pact` Trick line; only the highest owned tier remains active
- Luck delta logs should show the base amount and applied generation multiplier when boosted

Notes:

- this is a Fate/Fountain bridge, not a coin result modifier
- sacrificing at the Fountain and generating Luck should feel like charging a faster destiny engine

## Twist of Fate I-III

Category: Fate

Tags: `fate`, `fated_flip`, `payoff`, `score_scaling`

Tier: I, II, III

Timing: before_scoring

Requirements:

- `requires_fated_flip`
- current flip is consuming a Fated Flip

Automatic Target Rule:

- target the global `fated_flip`
- no individual coin target is chosen

Actions:

- Twist of Fate I makes Fated Flips score `1.5x`
- Twist of Fate II makes Fated Flips score `1.75x`
- Twist of Fate III makes Fated Flips score `2.25x`
- all tiers share the `twist_of_fate` Trick line, so buying or granting a stronger tier replaces the weaker owned tier

Scope Limits:

- `fated_flip_only`
- `no_individual_coin_targeting`
- `no_fated_result_change`

Synergy:

- Omen Engine
- Fountain Pact
- Lucky Coin
- high-score Fated Flip builds

Enemy Version:

- the opponent's Fated pressure resolves twice when its meter event fires

Implementation:

- implemented with the `fated_flip` condition during `before_scoring`
- applies aggregate `apply_score_scaling` to the whole flip, not per-coin score
- score scaling actions and triggered sources are included in replay signatures

Notes:

- this is the payoff branch for Fate
- it affects the whole Fated Flip layer, not one chosen coin
- future retrigger-style payoffs should remain separate from the score-scaling line unless they upgrade this same payoff identity

## Fate Uncapped III

Category: Fate

Tags: `fate`, `fated_flip`, `chain_fated_flip`, `uncapped`

Tier: III

Timing: during_fated_flip

Requirements:

- `requires_fated_flip`
- `requires_luck_meter`
- positive Luck gain would normally be suppressed during the Fated Flip

Automatic Target Rule:

- target the global `luck_meter`
- target the current `fated_flip` state
- no individual coin target is chosen

Actions:

- `allow_fated_luck_generation`
- apply positive Luck gains during the Fated Flip
- if the Luck Meter fills, `chain_fated_flip` to prepare another Fated Flip

Scope Limits:

- `once_per_fated_flip`
- `meter_only`
- `no_individual_coin_targeting`
- `no_fated_result_change`
- `max_triggers`

Synergy:

- Omen Engine
- Fountain Pact
- Twist of Fate
- Lucky Coin
- builds that generate large Luck gains

Enemy Version:

- the opponent can keep its fate pressure active if the player feeds the Luck Meter during a Fated Flip

Implementation:

- current runtime suppresses Luck gain during Fated Flips by default
- this Trick needs a controlled override for that suppression
- needs explicit chain caps and logs showing whether another Fated Flip was prepared

Notes:

- this is the chase version of the family
- it should enable rare destiny chains without turning every Fated Flip into an endless loop

## Prestige Family Notes

Prestige Tricks replay completed **Outcomes**: encores, curtain calls, impossible finales and effects becoming real again after the act should be over.

An **Outcome** is what a coin already produced this flip, especially its recorded Score contribution. Prestige replays that record; it does not reroll the coin or make a new coin act again.

Prestige does not create or copy coin bodies, move coins, forge identities, reroll results, add Weight or choose new targets. It records what a resolved coin already produced, then replays that recorded Outcome at reduced value.

Default model:

- record each resolved coin's completed Outcome
- include score and replay-safe recorded value from that coin
- replay the Outcome as `prestige_replay`
- default replay value is 20% of the original Outcome output
- use the same result, position and affected targets
- resolve every eligible Prestige source in owned left-to-right order; one replay Trick must not consume another Trick's post-flip opportunity
- drain the complete post-flip stack while keeping `no_recursive_prestige` on the replayed Score itself

Prestige is allowed to be one of the strongest late-game families, but it must be tempered. Use `outcome_replay_only`, `replay_at_20_percent`, `no_recursive_prestige`, `no_new_targets_on_replay` and clear replay logs.

Prestige and Momentum boundary: Prestige replays a completed Outcome. Momentum modifies live propagation from one coin into another. If the original Outcome included Momentum value, Prestige may replay that recorded value at the discount, but it does not rerun Momentum logic unless a Momentum Trick explicitly allows `prestige_replay` events to count as Momentum sources once.

## Encore I

Category: Prestige

Tags: `prestige`, `outcome`, `prestige_replay`, `encore`

Tier: I

Timing: after_all_effects

Requirements:

- requires a completed coin Outcome
- at least one selected coin resolved this flip

Automatic Target Rule:

- choose one completed coin Outcome using deterministic run RNG
- prefer a Bent Coin Outcome if one was recorded this flip
- if multiple eligible Bent Coins exist, choose randomly among them with deterministic run RNG
- if no Bent Coin resolved, choose randomly among all eligible Outcomes

Actions:

- replay the chosen Outcome
- `scale_replayed_outcome = 20%`
- `mark_prestige_replay`
- use the same original affected targets and outputs

Scope Limits:

- `once_per_flip`
- `once_per_prestige`
- `outcome_replay_only`
- `replay_at_20_percent`
- `no_recursive_prestige`
- `no_new_targets_on_replay`
- `no_live_momentum_from_replay`

Synergy:

- Bent Coin
- Momentum Outcomes that already happened
- neighbour effects
- high-impact resolved coin Outcomes

Enemy Version:

- the opponent replays one completed pressure Outcome at reduced value after the player thinks resolution is over

Implementation:

- needs Outcome records for each resolved coin
- replay should be applied from the record, not recalculated from current board state
- replayed outputs need `prestige_replay` source marking in traces/logs

Notes:

- this is the cleanest Prestige expression
- satisfying because the whole coin impact happens again
- safe because the replay is discounted and cannot recursively Prestige itself

## Curtain Call I-II

Category: Prestige

Tags: `prestige`, `curtain_call`, `late_trigger`, `prestige_replay`

Tier: I-II

Timing: after_all_effects

Requirements:

- requires at least one completed coin Outcome

Automatic Target Rule:

- Curtain Call I chooses one random completed Outcome
- Curtain Call II chooses two random completed Outcomes
- prefer Bent Coin Outcomes
- never replay the same Outcome twice from one Curtain Call

Actions:

- replay each chosen Outcome at 20% value
- `mark_prestige_replay`

Scope Limits:

- `once_per_flip`
- `once_per_prestige`
- `outcome_replay_only`
- `replay_at_20_percent`
- `no_recursive_prestige`
- `no_new_targets_on_replay`
- `no_duplicate_outcomes`
- `no_live_momentum_from_replay`

Synergy:

- Bent Coin
- coins with strong on-score or neighbour effects
- Momentum effects whose value was already recorded in the Outcome

Enemy Version:

- the opponent gets one or two random discounted encores after normal resolution

Implementation:

- needs deterministic multi-Outcome replay without duplicates
- replay must not reopen target selection or live Momentum propagation by default

Notes:

- this version creates showy variance without becoming Momentum
- unlike Momentum, it does not make a fresh propagation path

## Impossible Finale I-III

Category: Prestige

Tags: `prestige`, `finale`, `bent`, `prestige_replay`

Tier: I-III

Timing: after_all_effects

Requirements:

- requires at least one completed coin Outcome

Automatic Target Rule:

- Impossible Finale I chooses the highest-value completed Outcome
- Impossible Finale II chooses the two highest-value completed Outcomes
- Impossible Finale III chooses every completed Outcome
- ties are deterministic by resolution order

Actions:

- Finale I and II replay chosen Outcomes at 20% value
- Finale III replays all chosen Outcomes at 75% of their recorded Score contribution
- `mark_prestige_replay`

Scope Limits:

- `once_per_flip`
- `once_per_prestige`
- `outcome_replay_only`
- `replay_at_20_percent` for I-II
- `replay_at_75_percent` for III
- `no_recursive_prestige`
- `no_new_targets_on_replay`
- `max_triggers`

Synergy:

- Bent Coin
- Momentum Outcomes that already include In Motion value
- high-impact late-game Outcomes

Enemy Version:

- the opponent saves its strongest pressure Outcome for a reduced final encore

Implementation:

- needs Outcome output measurement before replay scaling
- if Momentum synergy is enabled, source tracking must show that Momentum allowed it, not Prestige itself

Notes:

- this is the chase Prestige payoff
- keep reduced value even at high tier so the family feels broken without actually replaying everything at full strength

## Momentum Family Notes

Momentum Tricks create live trigger propagation: one coin sets another coin **In Motion**, then that coin can keep motion moving through the flip.

User-facing wording should stay simple: "has a chance to trigger another coin", "continues Momentum", or "coins In Motion score more." Avoid exposing depth math in Trick descriptions.

A coin is **In Motion** when it was triggered by another coin rather than by the original flip resolution. Internal traces still use chain source/link/depth fields for deterministic replay, but player-facing content should say **Momentum Link**, **Momentum Depth** only when a precise log or rules note needs it.

Momentum and Prestige boundary: Momentum changes live propagation. Prestige replays a completed Outcome. Prestige can replay Momentum value that already happened, but does not start new Momentum propagation unless a Momentum Trick explicitly says Prestige replays can be sources once.

Flywheel Coin is the clean Momentum coin. Momentum Tricks prefer the highest-quality available Flywheel Coin and its material scales the additional triggered Score event.

## Keep It Rolling I

Category: Momentum

Tags: `momentum`, `in_motion`, `random_neighbor`, `propagation`

Tier: I

Timing: after_coin_score

Description:

- After a scoring coin, there is a 50% chance to trigger a neighbouring Flywheel Coin if possible, otherwise a random neighbouring coin.

Requirements:

- scoring coin matched the call
- at least one eligible neighbour exists

Automatic Target Rule:

- choose one eligible neighbouring coin
- prefer a Flywheel/Momentum coin
- otherwise choose randomly with deterministic run RNG

Actions:

- `trigger_random_neighbor`
- mark the target **In Motion**
- queue an additional Score event from the triggered coin, even if its original result missed
- record source, link and depth for replay/invariant checks

Scope Limits:

- `once_per_flip`
- 50% Momentum chance
- capped Momentum depth and trigger count
- no re-entry into a coin already used by the same Momentum path

Synergy:

- Flywheel Coin
- Follow Through
- Ripple
- Prestige replays of Outcomes that already include Momentum value

## Follow Through I

Category: Momentum

Tags: `momentum`, `in_motion`, `payoff`, `score_scaling`

Tier: I

Timing: on_batch_start / applied to deferred Momentum Score

Description:

- Coins In Motion score more for each Momentum link that carried them.

Requirements:

- a Momentum link successfully triggers a coin

Actions:

- scale the separate triggered Score event by `+25%` per Momentum depth

Scope Limits:

- once per coin

Synergy:

- Keep It Rolling
- Ripple
- Flywheel Coin as a preferred Momentum target

## Ripple I-III

Category: Momentum

Tags: `momentum`, `ripple`, `propagation`

Timing: after_coin_score

Line ID: `ripple`

Descriptions:

- **Ripple I**: After a scoring coin, there is a 50% chance to trigger a random neighbour, then a 25% chance to continue Momentum.
- **Ripple II**: After a scoring coin, there is a 75% chance to trigger the neighbour to the left, then a 50% chance to continue Momentum to the left.
- **Ripple III**: After a scoring coin, there is a 75% chance to trigger neighbours in both directions, then a 50% chance to continue Momentum in each direction.

Requirements:

- scoring coin matched the call
- eligible neighbour exists in the requested direction

Actions:

- `trigger_random_neighbor`
- mark triggered coins **In Motion**
- continue Momentum while chance succeeds and caps allow

Scope Limits:

- one Ripple tier per run because all tiers share `trick.lineId = "ripple"`
- capped Momentum depth and trigger count
- no duplicate Outcome/coin retrigger inside the same Momentum path

Synergy:

- Follow Through
- Flywheel Coin
- Prestige replays of Outcomes that already include Ripple value
