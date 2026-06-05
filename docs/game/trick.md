# Tricks

## Definition Template

```md
## Trick Name

Category: Loaded / Prediction? / Sleight / Forgery / Misdirection / Smuggling / Fate / Prestige / Chain

Tags: `tag`, `tag`

Tier: I / II / III

Timing: after_deal_before_selection / after_call_before_flip / condition_check / target_selection / luck_gain / luck_meter_full / before_flip / during_fated_flip / after_flip_before_score / before_score / before_coin_score / after_score / after_coin_score / after_trigger / chain_step / refill_hand / after_all_effects

Requirements:

- canonical requirement terms

Automatic Target Rule:

- deterministic targeting rule

Actions:

- canonical action terms

Scope Limits:

- once_per_flip / once_per_coin / once_per_fated_flip / once_per_prestige / max_board_coins / max_chain_depth / max_triggers etc.

Synergy:

- coin archetypes or other Tricks

Enemy Version:

- optional rival-cheat version

Implementation:

- current code support or required engine work
```

## Weighted Palm I

Category: Loaded

Tags: `loaded`, `weight`, `call_bias`, `auto`

Tier: I

Timing: before_flip

Requirements:

- `requires_selected_coin`

Automatic Target Rule:

- choose one selected coin
- prefer a Weighted Coin
- if tied, choose the leftmost selected coin

Actions:

- `add_weight` toward the player's `call`
- `set_call_match_chance = 75%` for the target coin this flip

Scope Limits:

- `once_per_flip`

Synergy:

- Weighted Coin
- Heavy Payout
- Loaded Tricks
- probability builds

Enemy Version:

- the opponent adds Weight away from the player's call before the flip
- prefer the highest-value selected coin

Implementation:

- needs `set_call_match_chance`
- maps design timing `before_flip` to current hook `before_hand_flip` / `before_coin_roll`

Notes:

- Loaded Tricks affect probability before results exist
- Loaded Tricks should not convert or reroll results after the flip
- Weight is the player-facing keyword for this family

## See Behind the Veil I

Category: Prediction?

Tags: `marked`, `foretold`, `read`, `auto`

Tier: I

Timing: after_deal_before_selection

Requirements:

- dealt coins exist

Automatic Target Rule:

- choose one unrevealed dealt coin
- use deterministic run RNG when choosing randomly
- if tied by future targeting rules, choose the leftmost dealt coin

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

- Prediction is a question-mark category
- the current direction is foreknowledge attached to dealt coins, not individual coin calls
- player agency comes from selecting and ordering around known coin results

## Fulfilled Fate I

Category: Prediction?

Tags: `marked`, `foretold`, `fulfillment`, `score_scaling`

Tier: I

Timing: before_coin_score

Requirements:

- `requires_foretold_coin`
- the coin is selected
- the coin's `foretold_result` matches the player's `call`

Automatic Target Rule:

- choose the first selected foretold coin that matches the player's call
- tie-break leftmost selected coin

Actions:

- `multiply_score = 2x` for the target coin

Scope Limits:

- `once_per_flip`

Synergy:

- See Behind the Veil
- Marked Coin
- Loaded Tricks that make a known call more valuable

Enemy Version:

- the opponent rewards coins whose foretold result works against the player's call

Implementation:

- needs `requires_foretold_coin`
- scoring check should use the revealed `foretold_result` and current player `call`

Notes:

- fulfillment rewards should be capped so the obvious line is not always "see three Heads, pick three Heads, call Heads"
- this payoff should reward using visible foreknowledge, not passive hidden patterns

## Ancient Pattern I

Category: Prediction?

Tags: `marked`, `foretold`, `ancient_pattern`, `pattern`

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

## Sleight Family Notes

Sleight Tricks are physical coin manipulation: fast hands, street-hustler swaps, three-cup moves and substitutions.

They move coin bodies through already-resolved slots. They do not change results, reroll coins, add odds, reveal prophecy or create copies.

Movement-based rescore effects are allowed when the new scoring pass is clearly caused by coins changing places. These effects should use the same resolved result slots and should not freely retrigger every Trick unless explicitly stated.

## Switcheroo I

Category: Sleight

Tags: `sleight`, `position`, `swap`, `slot`

Tier: I

Timing: after_flip_before_score

Requirements:

- `requires_selected_coin`
- `requires_result_slot`
- at least one successful result slot and one failed result slot

Automatic Target Rule:

- choose the highest-base-score selected coin in a failed result slot
- choose the lowest-base-score selected coin in a successful result slot
- tie-break leftmost selected coin

Actions:

- `swap_coins`
- preserve both `result_slot` outcomes
- score the swapped coin bodies in their new positions

Scope Limits:

- `once_per_flip`

Synergy:

- position-based coins
- edge and neighbour effects
- high-base-score coins
- Sleight movement rescores

Enemy Version:

- the opponent swaps the player's best scoring coin out of a successful result slot

Implementation:

- needs selected slot/result state separate from coin body identity
- needs scoring to read the coin body currently occupying each resolved slot

Notes:

- this is the cleanest Sleight example: the flip result stays `T T H`, but the valuable coin can be moved into the `H` slot
- should feel like the coin was always under the other cup

## Spin Me Baby One More Time I

Category: Sleight

Tags: `sleight`, `position`, `move`, `retrigger`, `rescore`

Tier: I

Timing: after_all_effects

Requirements:

- `requires_selected_coin`
- `requires_result_slot`
- scoring and normal Trick resolution for the flip have completed

Automatic Target Rule:

- choose one selected coin whose movement creates the largest deterministic score gain from position, edge or neighbour effects
- if no gain can be calculated, choose the rightmost selected coin and move it one slot left
- tie-break leftmost eligible move

Actions:

- `move_coin` within the selected layout
- preserve all resolved `result_slot` outcomes
- `rescore_moved_layout` once using the moved layout

Scope Limits:

- `once_per_flip`
- `no_self_trigger`

Synergy:

- neighbour effects
- position-based coins
- Switcheroo
- Bent Coin and packet-replay or Chain support pieces

Enemy Version:

- the opponent spins the cups after scoring and forces the worst movement-based rescore

Implementation:

- needs `rescore_moved_layout`
- moved rescore should recheck coin score, position and neighbour effects
- moved rescore should not automatically replay unrelated Tricks unless those Tricks explicitly listen for moved-layout scoring

Notes:

- Sleight can overlap with Prestige and Chain, but the cause is physical movement rather than timing mastery or combo cascade
- this is the three-cups / street-hustler expression of the family

## False Bottom I

Category: Sleight

Tags: `sleight`, `replace`, `hand`, `slot`, `auto`

Tier: I

Timing: after_flip_before_score

Requirements:

- `requires_selected_coin`
- `requires_unselected_dealt_coin`
- `requires_result_slot`

Automatic Target Rule:

- choose the weakest selected coin body in the flipped layout
- choose a random stronger unselected dealt coin using deterministic run RNG
- if multiple stronger coins are equally eligible, tie-break leftmost dealt coin

Actions:

- `replace_coin` in the selected slot with the stronger coin body from hand
- preserve the selected slot's resolved result

Scope Limits:

- `once_per_flip`

Synergy:

- strong coins left in hand
- position-based coins
- Smuggling support that increases available hand options

Enemy Version:

- the opponent palms away the player's strongest selected coin and substitutes a weaker dealt coin

Implementation:

- needs dealt-but-unselected hand state during scoring
- replacement is a physical substitution, not a result fix

Notes:

- if the effect adds the hand coin as an extra board body instead of replacing a selected body, it starts overlapping with Smuggling
- if the replacement copies the old coin rather than moving a real coin body, it becomes Forgery

## Forgery Family Notes

Forgery Tricks are position-based identity fraud: fake papers, forged signatures, stamped credentials and counterfeit payout records.

They do not add real coins or extra slots. That is Smuggling. They do not move coin bodies. That is Sleight. They do not redirect score away from another target. That is Misdirection.

Forgery changes what scoring, trigger or requirement checks believe a coin is. The strongest versions let weak or failed coins behave like a carefully chosen successful template, but every copied payout or trigger needs strict scope limits.

Tier direction:

- Tier I can replace identity for one check or payout
- Tier II can add forged identity while keeping the original identity
- Tier III can copy two templates or let multiple coins share the same signed identity

Avoid making Forgery always copy the highest-score coin automatically. Prefer creative source constraints such as slot 1, last slot, nearest success, first success or a matching tag.

## Borrowed Name I

Category: Forgery

Tags: `counterfeit`, `identity`, `slot_1`, `replace_identity`

Tier: I

Timing: before_coin_score

Requirements:

- `requires_selected_coin`
- `requires_template_coin`
- slot 1 selected coin exists

Automatic Target Rule:

- source is the selected coin in slot 1
- choose one selected non-source coin in a failed result slot
- prefer the lowest-base-score eligible coin
- tie-break leftmost selected coin

Actions:

- `forge_identity` from slot 1 onto the target
- `replace_forged_identity` for one payout or requirement check
- target uses the source coin's scoring identity for that check only

Scope Limits:

- `once_per_flip`
- `one_payout_only`

Synergy:

- Blank Coin
- slot 1 builds
- weak coins that become valuable when forged
- payoff Tricks that care about shared identity

Enemy Version:

- the opponent makes one of the player's failed coins count as the least useful template for its next payout check

Implementation:

- needs `forged_identity`
- needs `identity_source`
- needs scoring to distinguish real identity from forged identity overlay

Notes:

- Tier I Forgery replaces identity rather than adding it
- the target does not become successful and the result does not change
- this should feel like the coin presents slot 1's papers at payout time

## Fake Credentials II

Category: Forgery

Tags: `counterfeit`, `credentials`, `additive_identity`, `last_slot`

Tier: II

Timing: condition_check

Requirements:

- `requires_selected_coin`
- `requires_identity_source`
- a selected coin is missing a tag, archetype or material requirement that another selected coin can provide

Automatic Target Rule:

- source is the selected coin in the last slot
- choose the leftmost selected non-source coin that can satisfy an active requirement by borrowing one source identity term
- if no active requirement exists, choose the leftmost Blank Coin; otherwise choose the leftmost selected coin

Actions:

- `add_forged_identity` from the last-slot source onto the target
- target keeps its original identity and also counts as the forged tag, archetype or material for the current check
- `satisfy_requirement` if the additive fake credential completes the check

Scope Limits:

- `once_per_flip`
- `one_payout_only`

Synergy:

- Blank Coin
- Hollow Coin plus forged Weighted/Heavy credentials
- requirement-based Tricks
- first/last slot builds

Enemy Version:

- the opponent stamps a bad credential onto one coin so enemy pressure treats it as the wrong archetype

Implementation:

- needs additive identity overlays rather than permanent tag mutation
- requirement checks must know whether real or forged identity satisfied the requirement

Notes:

- Tier II Forgery is additive: Hollow plus fake Heavy remains Hollow and also counts as Heavy
- fake credentials should be visible in the resolution log so the payoff feels earned, not random

## Copycat Jackpot III

Category: Forgery

Tags: `counterfeit`, `copy_payout`, `copy_trigger`, `slot_1`, `chase`

Tier: III

Timing: after_coin_score

Requirements:

- `requires_selected_coin`
- `requires_success`
- `requires_identity_source`
- slot 1 selected coin is successful or has scored this flip

Automatic Target Rule:

- source is the selected coin in slot 1
- choose up to two selected non-source coins
- prefer failed coins carrying a `forged_identity` copied from the source
- then prefer lowest scoring eligible coins
- tie-break leftmost selected coin

Actions:

- `copy_payout` from the slot 1 source to each target
- optionally `copy_trigger_once` from the source if the source has one eligible non-recursive trigger
- targets do not change result and do not become extra coins

Scope Limits:

- `once_per_flip`
- `one_payout_only`
- `one_trigger_only`
- `no_self_trigger`
- `no_recursive_copy`

Synergy:

- Borrowed Name
- Fake Credentials
- Blank Coin
- strong slot 1 template coins
- builds that can make failures impersonate the best success

Enemy Version:

- the opponent makes weak enemy pressure behave like the player's strongest successful identity for one bounded trigger

Implementation:

- needs copied payout and trigger source tracking
- copied trigger must copy only the source's current eligible trigger, not copied history
- needs clear loop caps in traces and fixtures

Notes:

- this is the chase fantasy: failures can behave like the strongest successful template
- the interesting decision should be what to place in slot 1 or last slot, not simply always copy the highest score automatically

## Misdirection Family Notes

Misdirection Tricks are defensive control first and score funneling second: decoys, wrong targets, false credit and crooked spotlights.

They do not move coin bodies. That is Sleight. They do not change identity. That is Forgery. They do not add extra coins or slots. That is Smuggling. They do not change Heads/Tails results or probability.

Misdirection changes where targeting, credit, score events or explicit penalties are booked. The wrong coin gets targeted, credited or paid while the original coins, results and identities remain fixed.

Core direction:

- Decoy effects protect important coins from enemy Tricks or hostile automatic targeting.
- Score-funnel effects redirect successful scoring actions into one Spotlight coin.
- This family can be mostly defensive/supportive; it does not need to be a full primary combo engine.

Avoid making every Misdirection Trick automatically send everything to the highest-value coin. Use constraints such as Decoy flags, lowest-base-score Decoys, slot 1, last slot, adjacent coins, one redirected target or one/two redirected score-credit events.

Avoid blame-transfer framing for now; Decoy protection is the cleaner defensive fantasy.

## Look Over There I

Category: Misdirection

Tags: `misdirection`, `decoy`, `target_redirect`, `defense`

Tier: I

Timing: target_selection

Requirements:

- `requires_selected_coin`
- `requires_hostile_target`
- a player coin is being targeted by an enemy Trick or hostile automatic effect

Automatic Target Rule:

- intended target is the coin the hostile effect would normally choose
- choose a selected non-intended coin as Decoy
- prefer the lowest-base-score eligible coin
- if tied, choose the leftmost eligible coin

Actions:

- `mark_decoy` on the Decoy coin
- `redirect_effect_target` from the intended target to the Decoy
- record the `redirected_target` in the resolution log

Scope Limits:

- `once_per_flip`
- `one_redirect_only`

Synergy:

- expensive or fragile high-value coins
- enemy-heavy encounters
- score-funnel Tricks that also care about Decoys

Enemy Version:

- the opponent causes one of the player's beneficial automatic target rules to hit a low-value Decoy instead of the useful coin

Implementation:

- needs `target_selection` timing
- needs target rules to expose an intended target before finalizing
- needs logs to show the Decoy taking the target so the defensive save is visible

Notes:

- this is the core Misdirection defensive piece
- the Decoy takes the target, but no coin moves and no identity changes
- should not nullify every enemy Trick forever; the cap is part of the design

## Crooked Spotlight I

Category: Misdirection

Tags: `misdirection`, `spotlight`, `score_credit`, `score_funnel`

Tier: I

Timing: before_coin_score

Requirements:

- `requires_selected_coin`
- `requires_success`
- `requires_score_credit`
- at least two successful selected coins

Automatic Target Rule:

- choose Spotlight as the highest-base-score successful selected coin
- choose one successful non-Spotlight source coin
- prefer the lowest-base-score successful source coin
- if tied, choose the leftmost eligible source coin

Actions:

- `mark_spotlight` on the Spotlight coin
- `redirect_score_credit` from the source coin to the Spotlight
- source coin's successful scoring action is booked onto the Spotlight instead of scoring as itself

Scope Limits:

- `once_per_flip`
- `one_redirect_only`
- `no_redirected_retrigger`

Synergy:

- high-base-score coins
- all-success flips
- Loaded Tricks that make multiple cheap coins pass
- Decoy builds that protect the Spotlight

Enemy Version:

- the opponent redirects one valuable scoring credit into the player's weakest successful coin

Implementation:

- needs per-coin score-credit events before final score total is locked
- needs score attribution to distinguish original source from credited recipient
- redirected score credit should not retrigger receiver effects unless a later Trick explicitly says it does

Notes:

- this is the offensive branch: cheap successful coins did the work, but the expensive coin gets paid
- the result, success and identity of every coin stay unchanged

## Stolen Applause II

Category: Misdirection

Tags: `misdirection`, `spotlight`, `score_credit`, `multi_redirect`

Tier: II

Timing: before_score

Requirements:

- `requires_selected_coin`
- `requires_spotlight`
- at least three successful selected coins

Automatic Target Rule:

- Spotlight is slot 1 if slot 1 succeeded; otherwise choose the highest-base-score successful selected coin
- choose up to two successful non-Spotlight source coins
- prefer lowest-base-score sources
- tie-break leftmost eligible coins

Actions:

- `redirect_score_credit` from each source coin to the Spotlight
- record each source as redirected so it cannot be redirected again this flip

Scope Limits:

- `once_per_flip`
- `no_recursive_redirect`
- `no_redirected_retrigger`

Synergy:

- slot 1 builds
- all-success flips
- Crooked Spotlight
- defensive Decoys that keep the Spotlight safe

Enemy Version:

- the opponent steals credit from the player's best-scoring coin and books it onto a weak Decoy for one final score calculation

Implementation:

- needs multiple score-credit redirects with clear source tracking
- needs trace output showing which successes paid the Spotlight

Notes:

- this is stronger score funneling, but still capped and non-recursive
- if it becomes automatic highest-score funneling every time, constrain the Spotlight to slot 1 or last slot

## Smuggling Family Notes

Smuggling Tricks are illegal capacity and board-overload effects: sleeve pockets, planted doubles, overflowing hands and too many coins on the table.

They physically force extra coin bodies from hand onto the board. A normal flip might select 3 coins and flip 3; a Smuggling build tries to select 3, call, then flip 4, 5 or far more coins by overloading the board.

Smuggling does not merely move already-selected coins. That is Sleight. It does not forge identity, payout or trigger checks. That is Forgery. It does not reroute targets or score credit. That is Misdirection. It does not change Heads/Tails results or probability.

Core direction:

- Stockpile path: buy many coins, keep the hand full, increase post-flip refill and force real unselected hand coins onto the board.
- Multiplication path: one real hand coin enters the board, then creates temporary contraband copies of that same coin for this flip.
- Payoff path: reward board overload, smuggled coins and contraband copies without making every extra coin automatically infinite value.

Real smuggled coins are owned coins from the hand. Multiplication copies are temporary board bodies: if one XYZ coin enters and becomes two XYZ bodies on the board, only the original single XYZ coin remains in the pouch after the flip.

Caps may happen naturally through hand size, refill count and board readability, but Smuggling entries should leave room for explicit `max_board_coins` or `no_recursive_multiplication` limits if needed.

## Sleeve Pocket I

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
- if tied, choose the leftmost unselected hand coin

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
- Backroom Refill
- Planted Double
- Overloaded Table
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

## Backroom Refill I

Category: Smuggling

Tags: `smuggle`, `refill`, `hand`, `stockpile`

Tier: I

Timing: refill_hand

Requirements:

- `requires_refill_rule`

Automatic Target Rule:

- apply to the current hand refill after scoring

Actions:

- `increase_refill_count` by 1 for this refill
- refill the hand with one extra owned pouch coin if available

Scope Limits:

- `once_per_flip`

Synergy:

- Sleeve Pocket
- Overloaded Table
- coin-purchase builds
- large pouch builds

Enemy Version:

- the opponent pressures the player's refill, making Smuggling lines harder to restock

Implementation:

- needs a defined refill step and configurable refill count
- logs should show the extra refill as a Smuggling enabler

Notes:

- this is an enabler, not the payoff
- Smuggling should care about buying and owning enough coins; refill support keeps the hand from emptying too fast

## Planted Double II

Category: Smuggling

Tags: `smuggle`, `multiply`, `contraband_copy`, `temporary`

Tier: II

Timing: after_call_before_flip

Requirements:

- `requires_smuggled_coin`

Automatic Target Rule:

- choose the first real smuggled coin this flip
- if multiple entered at the same time, choose the leftmost smuggled coin

Actions:

- `multiply_board_coin` for the target smuggled coin
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

- Sleeve Pocket
- Hollow Coin
- Overloaded Table
- high-value coins worth multiplying

Enemy Version:

- the opponent creates a temporary pressure duplicate that disappears after the flip

Implementation:

- needs temporary board bodies that can flip and score
- needs cleanup so only the original owned coin persists after resolution
- needs source tracking so a contraband copy cannot multiply itself unless a later Trick explicitly allows it

Notes:

- this is Smuggling, not Forgery: it copies physical board presence, not identity checks, payout records or trigger credentials
- an XYZ coin may become two XYZ board bodies for the flip, but the pouch still contains one owned XYZ coin afterward

## Overloaded Table III

Category: Smuggling

Tags: `smuggle`, `overloaded_board`, `payoff`, `extra_coin`

Tier: III

Timing: before_score

Requirements:

- `requires_overloaded_board`
- at least one `smuggled_coin` or `contraband_copy` resolved this flip

Automatic Target Rule:

- count board coins beyond the normal selected-slot limit
- prefer scoring smuggled real coins before contraband copies when applying per-coin caps

Actions:

- `check_board_overload`
- add a capped bonus for each coin body beyond the legal flip-slot limit
- optionally `multiply_score` for the first smuggled coin that succeeded

Scope Limits:

- `once_per_flip`
- `max_board_coins`

Synergy:

- Sleeve Pocket
- Backroom Refill
- Planted Double
- large pouch builds

Enemy Version:

- the opponent overloads the encounter with extra pressure that must be cleared or survived

Implementation:

- needs a visible legal-slot count versus actual board-coin count
- needs deterministic scoring for overloaded board bonuses
- should keep logs readable when many coins flip

Notes:

- this is the payoff branch for flipping too many coins
- if quantity scaling becomes too automatic, cap the number of rewarded extra bodies while still allowing the board to be visually overloaded

## Fate Family Notes

Fate Tricks are Luck Meter engines and Fated Flip payoffs: omens, fountain bargains, destiny engines and whole-flip blessings.

They do not create coins, copy coins, move coin bodies, forge identities, reroute score credit, reroll coins, add Weight, or change individual coin results. Loaded owns individual odds and result manipulation. Fate owns the global meter and the global Fated Flip payoff layer.

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

- `add_luck = +1` to the Luck Meter when a positive Luck gain event occurs

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

## Fountain Pact I

Category: Fate

Tags: `fate`, `fountain_favor`, `luck_gain`, `accelerator`

Tier: I

Timing: luck_gain

Requirements:

- `requires_luck_meter`
- `requires_fountain_favor`
- `requires_luck_gain`
- the current Luck gain includes Fountain Favor

Automatic Target Rule:

- target the player's `luck_meter`
- target the Fountain Favor portion of the Luck gain event

Actions:

- `boost_fountain_favor_luck`
- optionally `multiply_luck_gain` for the Fountain Favor portion only

Scope Limits:

- `once_per_flip`
- `meter_only`
- `no_individual_coin_targeting`
- `no_fated_result_change`

Synergy:

- Fountain sacrifices
- Lucky Coin
- Omen Engine
- Fate Uncapped

Enemy Version:

- the opponent taxes or weakens the player's Fountain Favor Luck bonus for one encounter

Implementation:

- needs Luck gain events to expose base Luck versus Fountain Favor contribution
- logs should show that the Fountain Favor bonus was boosted

Notes:

- this is a Fate/Fountain bridge, not a coin result modifier
- sacrificing at the Fountain should feel like charging a stronger destiny engine

## Twist of Fate II

Category: Fate

Tags: `fate`, `fated_flip`, `payoff`, `retrigger`

Tier: II

Timing: during_fated_flip

Requirements:

- `requires_fated_flip`
- current flip is consuming a Fated Flip

Automatic Target Rule:

- target the global `fated_flip`
- no individual coin target is chosen

Actions:

- `add_fated_flip_payoff`
- either double the final Fated Flip score payoff or `retrigger_fated_flip_resolution` once

Scope Limits:

- `once_per_fated_flip`
- `meter_only`
- `no_individual_coin_targeting`
- `no_fated_result_change`
- `max_triggers`

Synergy:

- Omen Engine
- Fountain Pact
- Lucky Coin
- high-score Fated Flip builds

Enemy Version:

- the opponent's Fated pressure resolves twice when its meter event fires

Implementation:

- needs a clear Fated Flip context flag and a whole-flip payoff/retrigger path
- should log the extra Fated Flip payoff separately from normal scoring

Notes:

- this is the payoff branch for Fate
- it affects the whole Fated Flip layer, not one chosen coin
- if retriggering all coins is too explosive, start with doubled Fated Flip score payoff

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

Prestige Tricks replay completed resolution packets: encores, curtain calls, impossible finales and effects becoming real again after the act should be over.

Prestige does not create or copy coin bodies, move coins, forge identities, reroute score credit, reroll results, add Weight or choose new targets. It records what a resolved coin already produced, then replays that record at reduced value.

Default model:

- record each resolved coin's `resolution_packet`
- include score, emitted effects, affected coins, neighbour bonuses and payout events caused by that coin
- replay the packet as `prestige_replay`
- default replay value is 20% of the original packet output
- use the same result, position and affected targets

Prestige is allowed to be one of the strongest late-game families, but it must be tempered. Use `packet_replay_only`, `replay_at_20_percent`, `no_recursive_prestige`, `no_new_targets_on_replay` and clear replay logs.

Prestige and Chain boundary: Prestige replays a completed packet. Chain modifies live propagation from one coin into another. If the original packet included Chain value, Prestige may replay that recorded value at the discount, but it does not rerun Chain logic unless a Chain Trick explicitly allows `prestige_replay` events to count as Chain sources once.

## Encore I

Category: Prestige

Tags: `prestige`, `resolution_packet`, `prestige_replay`, `encore`

Tier: I

Timing: after_all_effects

Requirements:

- `requires_resolution_packet`
- at least one selected coin resolved this flip

Automatic Target Rule:

- choose one resolved selected coin using deterministic run RNG
- prefer a Bent Coin if a Bent Coin resolved this flip
- if multiple eligible Bent Coins exist, choose randomly among them with deterministic run RNG
- if no Bent Coin resolved, choose randomly among all resolved selected coins

Actions:

- `replay_resolution_packet` for the chosen coin
- `scale_replayed_packet = 20%`
- `mark_prestige_replay`
- use the same original affected targets and outputs

Scope Limits:

- `once_per_flip`
- `once_per_prestige`
- `packet_replay_only`
- `replay_at_20_percent`
- `no_recursive_prestige`
- `no_new_targets_on_replay`
- `no_live_chain_from_replay`

Synergy:

- Bent Coin
- Chain packets that already happened
- neighbour effects
- high-impact resolved coin packets

Enemy Version:

- the opponent replays one completed pressure packet at reduced value after the player thinks resolution is over

Implementation:

- needs `resolution_packet` records for each resolved coin
- replay should be applied from the record, not recalculated from current board state
- replayed outputs need `prestige_replay` source marking in traces/logs

Notes:

- this is the cleanest Prestige expression
- satisfying because the whole coin impact happens again
- safe because the replay is discounted and cannot recursively Prestige itself

## Curtain Call II

Category: Prestige

Tags: `prestige`, `curtain_call`, `late_trigger`, `prestige_replay`

Tier: II

Timing: after_all_effects

Requirements:

- `requires_resolution_packet`
- at least one selected coin triggered an effect this flip

Automatic Target Rule:

- choose the last resolved selected coin that triggered an effect
- if multiple effects share the same final timing, choose the rightmost eligible coin

Actions:

- `replay_resolution_packet` for that coin's last completed packet
- `scale_replayed_packet = 20%`
- replay score, affected targets and emitted bonuses from the original packet
- `mark_prestige_replay`

Scope Limits:

- `once_per_flip`
- `once_per_prestige`
- `packet_replay_only`
- `replay_at_20_percent`
- `no_recursive_prestige`
- `no_new_targets_on_replay`
- `no_live_chain_from_replay`

Synergy:

- Bent Coin
- coins with strong on-score or neighbour effects
- Chain effects whose value was already recorded in the packet

Enemy Version:

- the opponent's final pressure effect gets a discounted encore after normal resolution

Implementation:

- needs source tracking for which coin triggered the last effect
- replay must not reopen target selection or live Chain propagation by default

Notes:

- this version rewards building around visible finale coins
- unlike Chain, it does not make a fresh propagation path

## Impossible Finale III

Category: Prestige

Tags: `prestige`, `finale`, `bent`, `prestige_replay`

Tier: III

Timing: after_all_effects

Requirements:

- `requires_resolution_packet`
- at least one high-impact selected coin packet was recorded this flip

Automatic Target Rule:

- choose the highest original-output eligible packet
- prefer Bent Coin packets when within 20% of the highest output
- tie-break by rightmost eligible coin

Actions:

- `replay_resolution_packet` for the chosen packet
- `scale_replayed_packet = 20%`
- optionally allow one Chain Trick to treat the replay as a Chain source if that Chain Trick explicitly says so
- `mark_prestige_replay`

Scope Limits:

- `once_per_flip`
- `once_per_prestige`
- `packet_replay_only`
- `replay_at_20_percent`
- `no_recursive_prestige`
- `no_new_targets_on_replay`
- `max_triggers`

Synergy:

- Bent Coin
- Chained Payout
- Deep Link
- high-impact late-game packets

Enemy Version:

- the opponent saves its strongest pressure packet for a reduced final encore

Implementation:

- needs packet output measurement before replay scaling
- if Chain synergy is enabled, source tracking must show that Chain allowed it, not Prestige itself

Notes:

- this is the chase Prestige payoff
- keep reduced value even at high tier so the family feels broken without actually replaying everything at full strength

## Chain Family Notes

Chain Tricks create live trigger propagation: one coin knocks into another, then another, then another.

User-facing wording should stay simple: "has a chance to trigger another coin" or "triggered coins have a chance to trigger another random coin."

A coin is **Chained** when it was triggered by another coin rather than by the original flip resolution. Chain state should track `chain_source`, `chain_link` and `chain_depth`. The original source is depth 0, the first triggered coin is depth 1, and the next triggered coin is depth 2. The "third coin in the chain" is therefore a Chained coin at `chain_depth >= 2`.

Chain and Prestige boundary: Chain changes live propagation. Prestige replays a completed packet. Prestige can replay Chain value that already happened, but does not start new Chain propagation unless a Chain Trick explicitly says `prestige_replay` events count as Chain sources once.

Use `chain_chance`, `max_chain_depth`, `no_chain_reentry`, `max_triggers` and clear Chain logs so propagation feels exciting without becoming unreadable.

## Domino Line I

Category: Chain

Tags: `chain`, `chained`, `random_neighbor`, `propagation`

Tier: I

Timing: after_coin_score / after_trigger

Requirements:

- `requires_selected_coin`
- `requires_success`
- at least one eligible neighbour exists

Automatic Target Rule:

- when a coin scores or when a Chained coin resolves, roll `chain_chance = 50%`
- if the roll succeeds, choose one random eligible neighbouring coin using deterministic run RNG
- prefer a neighbour not already used in the current Chain
- if both neighbours are equally eligible, choose randomly with deterministic run RNG

Actions:

- `trigger_random_neighbor`
- `mark_chained_coin`
- set `chain_source` to the triggering coin
- set `chain_depth = source.chain_depth + 1`, or 1 if the source was not already Chained
- `continue_chain` while chance succeeds and depth cap allows

Scope Limits:

- `once_per_flip`
- `chain_chance`
- `max_chain_depth`
- `no_chain_reentry`
- `max_triggers`

Synergy:

- Bent Coin
- Chained Payout
- Deep Link
- Prestige replays if a Chain Trick later allows replay events as sources

Enemy Version:

- the opponent's pressure effect can jump from one coin to a random neighbour with capped Chain depth

Implementation:

- needs Chain source, depth and used-coin tracking
- Chain resolution must be visible in logs as links, not generic retriggers

Notes:

- this is the clean Chain enabler
- it should feel like a visible line of cause and effect across coins

## Chained Payout I

Category: Chain

Tags: `chain`, `chained`, `payoff`, `score_scaling`

Tier: I

Timing: before_coin_score

Requirements:

- `requires_chained_coin`

Automatic Target Rule:

- target each Chained coin as it scores
- if multiple Chained coins score at once, resolve left-to-right

Actions:

- `multiply_chained_score = 1.25x`

Scope Limits:

- `once_per_coin`
- `max_triggers`

Synergy:

- Domino Line
- Deep Link
- Prestige replay packets that already include Chained Payout value

Enemy Version:

- chained pressure effects gain a small score/pressure boost

Implementation:

- needs `chained_coin` flag available during coin scoring
- multiplier should be logged as Chain payoff

Notes:

- this is the basic Chain spender/payoff
- it rewards propagation without copying all triggers forever

## Deep Link II

Category: Chain

Tags: `chain`, `chain_depth`, `deep_chain`, `payoff`

Tier: II

Timing: after_trigger / before_coin_score

Requirements:

- `requires_chained_coin`
- `requires_chain_depth`
- target coin has `chain_depth >= 2`

Automatic Target Rule:

- target the first coin this flip that reaches `chain_depth >= 2`
- if multiple coins reach it at the same timing, choose the one with greater chain depth, then leftmost

Actions:

- `add_score` or `multiply_chained_score` for the deep Chained coin
- record the achieved `chain_depth`

Scope Limits:

- `once_per_flip`
- `max_chain_depth`
- `max_triggers`

Synergy:

- Domino Line
- Chained Payout
- Prestige replay of packets that already reached deep Chain value

Enemy Version:

- the opponent gains a pressure bonus if its Chain reaches the third link

Implementation:

- needs chain depth tracking in trace output
- payoff should say "third coin in the chain" or "deep in the chain" in player-facing text

Notes:

- this turns Chain into a build, not just random neighbour retriggers
