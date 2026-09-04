# Family-Triggered Trick Migration Catalogue

## Current Family Pass (2026-07-31)

This section supersedes the earlier first-pass numbers and individual values
later in this catalogue.

### Weighted

Weighted remains the intentionally simple bread-and-butter family:

| Trick | Tier | Current effect |
|---|---:|---|
| Headside Edge | I | On a Heads call, +15% Heads Chance for the activating coin. |
| Tailside Edge | I | On a Tails call, +15% Tails Chance for the activating coin. |
| Weighted Palm | I | Minimum 65% call-match chance; matching Outcome is worth 1.45x. |
| Weighted Palm II | II | Minimum 75% call-match chance; matching Outcome is worth 1.65x. |
| Weighted Palm III | III | Minimum 85% call-match chance; matching Outcome is worth 1.85x. |

The two side Tricks are deliberately symmetrical. Weighted Palm was reduced by
approximately 15%, with percentage-point values rounded upward to multiples of
five.

### Prestige

Steady Finish is removed from acquisition. Prestige now has exactly three
complete I/II/III lines:

| Line | Tier I | Tier II | Tier III |
|---|---|---|---|
| Encore | Replay the activating Outcome at 20%. | 30%. | 40%. |
| Curtain Call | Replay 1 random other root Outcome at 20%. | 2 at 30%. | 3 at 40%. |
| Impossible Finale | Replay the highest root Outcome at 20%. | Top 2 at 30%. | Top 3 at 40%. |

### Momentum

Momentum now also has exactly three complete I/II/III lines:

| Line | Tier I | Tier II | Tier III |
|---|---|---|---|
| Keep It Rolling | 50% to Replay the next Outcome. | 75%. | 100%. |
| Follow Through | +25% score per Reactivation depth. | +50%. | +75%. |
| Ripple | Replay right at 50%/25% continuation. | Reactivate left at 75%/50%. | Reactivate both directions at 75%/50%. |

All Momentum propagation remains bounded by the activation-depth and event caps.

### Prediction

Prediction now belongs to table slots rather than hidden information attached
to dealt coins:

- each encounter deterministically marks one Flip slot as Heads or Tails;
- the mark is visible throughout setup and persists for the whole encounter;
- committing a Marked/Prediction Coin to that slot forces the displayed result;
- committing any other family there does nothing special;
- Prediction consistently uses **Foretell**, **Foretold result**, **fulfill**, and
  **defy** as its rules vocabulary;
- Heads Pact and Tails Pact are removed from acquisition;
- See Behind the Veil is removed from acquisition because the slot mark now
  supplies Prediction's setup information natively.

The forecast is saved, validated, simulation-aware, and part of deterministic
replay traces.

Prediction has four complete I/II/III lines:

| Line | Tier I | Tier II | Tier III |
|---|---|---|---|
| Fulfilled Fate | A fulfilled Foretold root Outcome is worth 2x. | 2.5x. | 3x. |
| Read the Stars | Matching neighbouring root Outcomes are worth 1.1x when the Foretold coin fulfills the Call. | 1.15x. | 1.2x. |
| Written in the Stars | Adjacent coins gain +5% Chance toward the Foretold result. | +10%. | +15%. |
| Defy Fate | Call against and sacrifice the Foretold coin; matching neighbouring root Outcomes are worth 1.5x. | 1.75x. | 2x. |

Neighbour score bonuses affect root Outcomes once. They are recorded into
Prestige replays as part of that completed Outcome but are not independently
reapplied to Momentum Reactivations.

Status: first-pass conversion implemented; values remain subject to playtest
balance.

Runtime disposition as of 2026-07-31:

- 51 converted and reward-capable Tricks;
- 12 held Tricks (Fate plus Echo Wager);
- 31 removed/deprecated Tricks (Extortion, incompatible economy content, and
  superseded legacy Prediction content);
- old held/removed IDs are filtered out of active boards during save migration.

This catalogue maps every current Trick line to the closest functioning
equivalent under the family-trigger engine. It intentionally favors efficient
mechanical conversion over perfect final design.

Canonical engine behavior is defined in
`docs/family-trigger-engine-design.md`.

## Conversion Rules

For every converted Trick:

1. a matching committed coin is its **activation source**;
2. remove "prefer family coin" targeting because the source is already from
   that family;
3. remove extra same-archetype/material bonuses that only reward finding the
   expected family coin;
4. use the source coin directly when that preserves the effect;
5. preserve the old effect's timing and target shape where practical;
6. use fixed values for the first prototype; coin material affects native coin
   strength, not activation count;
7. replace ambiguous "trigger again" text with Replay, Reactivate, or Repeat;
8. use root Outcomes as Prestige Replay candidates unless explicitly stated;
9. specify `once per activation` or another visible cap;
10. do not allow generated effects to recurse implicitly.

The values below are deliberately conservative placeholders. Multiplicity
already increases the value of each Trick.

## Recommended First Vertical Slice

Implement these first:

| ID | Family | Why |
| --- | --- | --- |
| `weighted_tail_coating` | Weighted | setup-window source targeting |
| `heads_varnish` | Weighted | repeated setup activation |
| `weighted_palm` | Weighted | chance floor plus source payoff |
| `steady_hand` | Prestige | simplest source Replay |
| `encore` | Prestige | canonical Replay |
| `curtain_call` | Prestige | other/root Outcome targeting |
| `impossible_finale` | Prestige | highest/root Outcome targeting |
| `keep_it_rolling` | Momentum | safe Tier I non-recursive propagation |
| `follow_through` | Momentum | reactivation payoff |
| `ripple_ii` | Momentum | first full Reactivate effect |
| `ripple_iii` | Momentum | bounded high-tier branching |

Suggested fixed prototype board:

1. Weighted Palm
2. Encore
3. Curtain Call
4. Keep It Rolling
5. Follow Through

Suggested demonstration commitment:

1. Weighted Coin
2. Momentum Coin
3. Prestige Coin

The Momentum source can Reactivate or Replay the Prestige source depending on
which tier is under test, making the difference visible immediately.

## Weighted

Weighted is a direct conversion. Its Tricks run in the `setup` window once per
matching committed source and never rerun on Reactivate.

### `weighted_tail_coating` — Tailside Edge

Current issue:

- searches for a random selected Weighted Coin;
- family preference is redundant under the new activation rule.

Prototype text:

> On a Tails call, give the activating coin +30% Tails Chance this Flip.

Rules:

- `activationFamily = weighted`;
- `activationWindow = setup`;
- target `activation_source`;
- once per root activation;
- clamp final chance to 100%;
- does not run on Reactivate.

Verdict: **automatic conversion**.

### `heads_varnish` — Headside Edge

Current issue:

- affects every selected coin;
- doubles the bonus for Weighted Coins.

Prototype text:

> On a Heads call, give the activating coin +12% Heads Chance this Flip.

Rules:

- source-only;
- remove the doubled Weighted bonus;
- additive with other Weight effects;
- once per root activation;
- does not run on Reactivate.

Verdict: **automatic conversion**.

### `weighted_palm` — Weighted Palm

Current issue:

- searches for the first Weighted Coin;
- adds a material-scaled bonus to matching Weighted Coins.

Prototype text:

> The activating coin has at least 75% chance to match your call. If it
> matches, its Outcome is worth 1.5x.

Rules:

- chance floor runs in `setup`;
- source Outcome scaling runs `before_score`;
- the floor never lowers native Silver/Gold odds;
- remove material-scaled Trick payout;
- setup portion does not rerun on Reactivate;
- score portion may run on Reactivate.

Verdict: **automatic conversion**.

## Prestige

Prestige is the cleanest expression of multiple family activations.

All Prestige Replay targets are immutable recorded root Outcomes unless stated
otherwise. A Replay cannot become another Prestige target.

### `steady_hand` — Steady Finish

Current issue:

- globally multiplies the whole Flip;
- doubles matching Bent Coins.

Prototype text:

> Replay 10% of the activating coin's original Outcome.

Rules:

- remove the global multiplier and Bent bonus;
- `activationWindow = finish`;
- one Replay per activation;
- reacts to root and reactivated Prestige sources;
- Replay does not activate Tricks.

Verdict: **automatic conversion with a source-local equivalent**.

### `encore` — Encore

Current issue:

- searches globally and prefers Prestige/Bent Outcomes;
- Bent replays at double value.

Prototype text:

> Replay 20% of the activating coin's original Outcome.

Rules:

- target the activation source's original/root score packet;
- remove all family/archetype preference and doubling;
- one Replay per activation;
- no recursive Replay.

Verdict: **automatic conversion**.

### `curtain_call` — Curtain Call I

Prototype text:

> Replay 20% of one random other committed coin's root Outcome.

Rules:

- choose among positive root Outcomes other than the activation source;
- deterministic run RNG;
- if no other positive root Outcome exists, Replay the source;
- one Replay per activation;
- the same Trick activation cannot choose the same packet twice.

Verdict: **automatic conversion**.

### `curtain_call_ii` — Curtain Call II

Prototype text:

> Replay 20% of up to two different random other committed root Outcomes.

Rules:

- same rules as Tier I;
- no duplicate packet within one activation;
- fall back to the source only when no other candidate exists.

Verdict: **automatic tier conversion**.

### `impossible_finale` — Impossible Finale I

Prototype text:

> Replay 20% of the highest-value committed root Outcome.

Rules:

- root Outcomes only;
- one packet per activation;
- deterministic first-slot tie break;
- no recursive Replay.

Verdict: **automatic conversion**.

### `impossible_finale_ii` — Impossible Finale II

Prototype text:

> Replay 20% of the two highest-value committed root Outcomes.

Rules:

- up to two different packets;
- deterministic value/slot ordering;
- no recursive Replay.

Verdict: **automatic tier conversion**.

### `impossible_finale_iii` — Impossible Finale III

Prototype text:

> Replay 50% of every positive committed root Outcome.

Rules:

- reduce the current 75% prototype value because every Prestige source can now
  activate the Trick;
- each root packet is replayed once per activation;
- no Replay/copy/contraband packet is eligible;
- no recursive Replay.

Verdict: **automatic tier conversion, value reduced for multiplicity**.

## Momentum

Momentum owns propagation. Tier I effects may Replay; Tier II/III effects can
Reactivate and therefore wake another family.

### `keep_it_rolling` — Keep It Rolling

Current issue:

- prefers a Flywheel neighbour and otherwise targets randomly;
- "extra Score event" is ambiguous about family activation.

Prototype Tier I text:

> After the activating coin scores, there is a 50% chance to Replay the next
> committed coin's original Outcome.

Rules:

- "next" means the committed slot to the right;
- no wrap at the final slot;
- one attempt per activation;
- Replay does not activate the target's Tricks;
- deterministic RNG trace.

Tier II upgrade candidate:

> After the activating coin scores, Reactivate the next committed coin once.

Verdict: **automatic conversion; use Replay at Tier I**.

### `follow_through` — Follow Through

Prototype text:

> Reactivated coins score +25% for each chain depth.

Rules:

- applies to any family reactivated by Momentum;
- additive by depth for the prototype: `1 + 0.25 × depth`;
- one scaling application per reactivated score event;
- does nothing on root activations or Replays.

Verdict: **automatic conversion**.

### `ripple` — Ripple I

Prototype text:

> After the activating coin scores, there is a 50% chance to Replay the next
> committed coin, then a 25% chance to continue right. Continue at most three
> coins.

Rules:

- Replay only;
- fixed rightward direction;
- no wrap;
- maximum three target packets;
- every continuation roll is traced.

Verdict: **automatic conversion with deterministic direction**.

### `ripple_ii` — Ripple II

Prototype text:

> After the activating coin scores, there is a 75% chance to Reactivate the
> committed coin to its left, then a 50% chance to continue left. Chain depth
> 3.

Rules:

- full Reactivate;
- no wrap;
- each target coin can be reactivated once per Flip by default;
- setup effects do not rerun;
- reactivated family Tricks may create more events within the shared limit.

Verdict: **automatic tier conversion; first feedback-loop Trick**.

### `ripple_iii` — Ripple III

Prototype text:

> After the activating coin scores, there is a 75% chance to Reactivate each
> neighbour, then a 50% chance to continue outward. Chain depth 3.

Rules:

- left branch resolves before right branch;
- each target coin can be reactivated once unless this Trick explicitly grants
  one additional reactivation;
- at most six generated activations;
- shared emergency ceilings still apply.

Verdict: **automatic tier conversion with branching cap**.

### `echo_cache` — Echo Wager

Prototype text:

> The first time this activates each Flip, if every committed coin matches,
> gain 1 Influence.

Rules:

- checks after root Outcomes resolve;
- once per Flip despite multiple Momentum sources;
- no temporary effect object is necessary;
- does not participate in Momentum propagation.

Verdict: **convertible but low family fit; keep out of first slice and consider
moving to a general Wager/event pool**.

## Prediction

Prediction converts commitment into information. Committing a Prediction coin
arms setup effects immediately, before Flip, without creating any post-Flip
decision.

### `see_behind_the_veil` — See Behind the Veil

Current issue:

- runs after the full deal and prefers a Marked Coin globally.

Prototype text:

> When a Prediction Coin is committed, Foretell that activating coin's result.

Rules:

- source-only;
- reveal during setup;
- the foretold result is generated once and remains stable if the coin is
  reordered;
- uncommitting the coin hides/removes the setup projection without consuming
  new RNG when recommitted in the same setup;
- does not run on Reactivate.

Verdict: **conversion requires setup-preview state, but mechanic is compatible**.

### `heads_contract` — Heads Pact

Prototype text:

> On a Heads call, if the activating Foretold coin matches, its Outcome is
> worth 1.25x.

Rules:

- source-only;
- `before_score`;
- root and Reactivate eligible;
- remove global search.

Verdict: **automatic conversion after Prediction setup exists**.

### `tails_contract` — Tails Pact

Prototype text:

> On a Tails call, if the activating Foretold coin matches, its Outcome is
> worth 1.25x.

Rules: identical to Heads Pact with Tails condition.

Verdict: **automatic conversion after Prediction setup exists**.

### `fulfilled_fate` — Fulfilled Fate

Current issue:

- searches for the first Foretold Match;
- scales by Marked material.

Prototype text:

> If the activating Foretold coin matches your call, its Outcome is worth 2x.

Rules:

- source-only;
- fixed prototype multiplier;
- remove Marked/material preference;
- root and Reactivate eligible.

Verdict: **automatic conversion after Prediction setup exists**.

## Forgery

Forgery is now a hybrid activation-support family rather than temporary Identity replacement. Before Flip, a real Blank/Forgery Coin reads the genuine non-Forgery coin immediately to its left and locks that coin's family as its acting family. Locked real families never change.

### `fake_credentials` I-III — Fake Credentials

Prototype text:

> If the activating Forgery Coin misses, copy 50% / 75% / 100% of the genuine left neighbour's completed root Outcome.

Rules:

- the left source must be genuine, committed, non-Forgery, non-Smuggled, and non-Contraband;
- the left source must have a positive root Outcome;
- the Forgery Coin remains a miss;
- copied score is recorded as `forgedOutcomeCopies`, not Prestige Replay;
- copied Outcomes cannot be copied recursively.

Verdict: **implemented three-tier Outcome-copy line**.

### `borrowed_name` I-III — Borrowed Name

Prototype text:

> Before Flip, rig the Blank to imitate up to one / two / three eligible Tricks, capped at Tier I / II / III, from the genuine family immediately to its left.

Rules:

- the Blank Coin remains the activation source;
- one bounded target list is locked for the whole Flip;
- copied Tricks run during all their normal hook phases, including pre-roll setup;
- lower tiers are selected first, with board order as stable tie-break;
- copied activations carry explicit parent, family, source, target, depth, and `forged` metadata;
- a forged activation cannot activate Forgery or be forged again.

Verdict: **implemented three-tier broad support line**.

### `forged_signature` I-III — Forged Signature

Prototype text:

> Before Flip, rig the Blank to repeat one highest-tier eligible Trick, capped at Tier I / II / III, from the genuine family immediately to its left.

Rules:

- exactly one target Trick per Forged Signature activation;
- highest eligible tier wins; board order breaks ties;
- the Blank Coin is the activation source;
- Block, Weaken, and Jam still affect the copied target;
- Signature and Borrowed Name use separate forged activation identities, so both can invest into the same primary family without colliding;
- replay signatures include the locked `forgeryAssignments` and resulting `forgedActivations`, and reject tampering.

Verdict: **implemented three-tier concentrated support line**.

## Sleight of Hand

Sleight remains automatic physical manipulation. The activating Sleight coin
enables the move; the player never chooses a target after Flip. Activations are
locked before movement, result and modifier state belongs to slots, and
Smuggled/Contraband bodies are never eligible.

### `switcheroo` — Switcheroo

Prototype text:

> If the activating coin Matches, switch it with a higher-value Miss.

Rules:

- results stay attached to slots while coin bodies move;
- Tier I chooses randomly, Tier II prefers the highest material band, and Tier
  III chooses highest total value;
- movement adds no hidden score multiplier;
- once per activation;
- a coin body cannot be moved more than once by this Trick per Flip.

Verdict: **automatic conversion with source binding**.

### `vanishing_act` I–III — Vanishing Act

Prototype text:

> Palm an eligible failed regular committed coin back into hand instead of
> spending it.

Rules:

- Tier I targets the activating Miss, Tier II the best local Miss, Tier III the
  best regular committed Miss on the table;
- the palmed coin contributes no score this Flip and remains in the next hand;
- Contraband cannot be palmed;
- once per activation;
- the same coin body cannot be used twice.

Verdict: **implemented structural conversion with persistent-hand retention**.

### `three_card_monte` I–III — Three-Card Monte

Prototype text:

> Automatically choose a strictly score-improving local arrangement of regular
> committed coin bodies.

Rules:

- Tier I chooses a random improving neighbour swap;
- Tier II chooses the best improving neighbour swap;
- Tier III chooses the best three-slot permutation;
- results and slot modifiers remain fixed;
- Contraband cannot move;
- no improvement means no movement.

Verdict: **implemented automatic local rearrangement**.

`false_bottom` is retired because hand-to-table movement overlaps Smuggling.

## Smuggling

Smuggling is compatible but not mechanically automatic because multiple
same-family sources can multiply extra coin bodies very quickly. Every effect
needs a board and activation cap. The family is strictly inbound and additive:
it brings hand coins onto anchored overload positions and never extracts,
palms, substitutes, or swaps an active body.

Contraband coins do not activate their own family by default.

`fall_guy` is retired. Failed-coin preservation now belongs to Sleight's
Vanishing Act line.

### `hidden_pocket` — Hidden Pocket

Current issue:

- permanently grants a Flip slot on acquisition, so it is not activated by a
  coin.

Prototype text:

> The first time this activates each Flip, open one Contraband slot for this
> Flip.

Rules:

- one temporary overload position;
- the slot is consumed only by a Smuggling effect;
- does not itself add a coin;
- once per Flip, not once per activation.

Verdict: **structural conversion; pairs with another Smuggling Trick and may be
too inert alone**.

Alternative if inert Tricks are unacceptable:

> The first time this activates each Flip, smuggle the first uncommitted hand
> coin into one temporary Contraband slot.

The implementation uses this combined version.

### `hidden_in_plain_sight` — Hidden in Plain Sight

Prototype text:

> Smuggle the highest-value uncommitted hand coin into an open Contraband slot.

Rules:

- remove Hollow preference/material bonus;
- deterministic value then hand-order target;
- one smuggled real coin per activation;
- shared maximum two Contraband slots for the prototype;
- smuggled coin flips/scores but cannot activate family Tricks;
- smuggled real coin enters Spent after the Flip.

Verdict: **compatible with hard cap**.

### `off_the_books` — Off the Books

Prototype text:

> After this activates and at least one coin was smuggled, draw one extra coin
> after the Flip. Keep it above your hand limit until the next setup ends.

Rules:

- once per Flip despite multiple Smuggling sources;
- temporary hand-limit overflow expires after the next commitment;
- no draw when the draw pile is empty.

Verdict: **convertible, but requires explicit temporary hand overflow**.

Simpler first-slice alternative:

> After this activates and at least one coin was smuggled, return one random
> spent coin to the draw pile.

This avoids hand overflow but changes the current effect more substantially.

### `planted_double` — Planted Double

Prototype text:

> After this activates, there is a 50% chance to copy one smuggled coin into an
> open Contraband slot.

Rules:

- deterministic random source among smuggled coins;
- shared maximum two Contraband slots;
- copy is temporary;
- copy cannot activate Tricks and cannot be copied again;
- one attempt per activation.

Verdict: **automatic conversion after Contraband cap exists**.

### `embarrassment_of_riches` — Embarrassment of Riches

Prototype text:

> Contraband Outcomes are worth 1.5x this Flip.

Rules:

- first activation arms the multiplier;
- additional activations do not stack in the first prototype;
- applies to smuggled real coins and temporary copies;
- does not grant family activation.

Verdict: **automatic conversion with once-per-Flip arming**.

## Fate

Fate remains held from normal Trick rewards. The Luck Meter and Fountain remain
in the game independently.

The following closest equivalents are recorded so the content is not lost, but
they should not be enabled in the first family-trigger slice.

### `omen_engine` — Omen Engine

Candidate text:

> If the activating coin matches, gain 2 additional Luck.

Verdict: **easy conversion, held**.

### `fountain_pact` I–III — Fountain Pact

Candidate text:

> Luck generated by the activating coin is worth 1.5x / 1.75x / 2x.

Verdict: **easy conversion, held**.

### `twist_of_fate` I–III — Twist of Fate

Candidate text:

> During a Fated Flip, the activating coin's Outcome is worth 1.5x / 1.75x /
> 2.25x.

Verdict: **easy conversion, held**.

### `starter_grant` — Opening Stake

An on-acquire currency grant does not operate through family activation.

Verdict: **remove from Trick rewards; preserve as event/immediate reward**.

### `coupon_case` — House Voucher

An on-acquire shop reroll does not operate through family activation.

Verdict: **remove from Trick rewards; preserve as event/immediate reward**.

### `insurance_ledger` — Insurance Slip

Candidate text:

> The first time this activates each Flip, if no committed coin matches, gain 2
> Influence.

The condition is global and does not benefit from multiple Fate sources.

Verdict: **hold; likely move to a Wager/insurance event family**.

### `rainy_day_fund` — Rainy Day Voucher

Candidate text:

> The first time this activates each Flip, if no committed coin matches, gain 1
> Free Reroll.

Verdict: **hold; likely event/consumable rather than a Trick**.

## Extortion

All eight Extortion lines and their Tier II/III variants are removed from the
Trick system:

- `five_finger_discount`;
- `loaded_shelves`;
- `pressure_sale`;
- `no_questions_asked`;
- `strong_arm_deal`;
- `take_whats_owed`;
- `protection_racket`;
- `forced_confession`.

Their effects occur in shops/Spoils and cannot be meaningfully activated by a
committed Extortion coin.

Migration:

- set every variant `rewardEligible = false`;
- remove Extortion from active enemy reward categories;
- allow old definitions to remain addressable for history compatibility while
  filtering their IDs out of the active five-Trick board during save migration;
- remove definitions, crumble plumbing, fixtures, and reward hooks only after
  save policy is decided;
- reuse good ideas as events, immediate rewards, opponent rewards, or
  consumable favors.

Verdict: **remove; no family-trigger conversion**.

## Complete Disposition Summary

| Family | Current definitions | Active | Held | Removed |
| --- | ---: | ---: | ---: | ---: |
| Weighted | 5 | 5 | 0 | 0 |
| Prestige | 10 | 9 | 0 | 1 |
| Momentum | 10 | 9 | 1 | 0 |
| Prediction | 15 | 12 | 0 | 3 |
| Forgery | 9 | 9 | 0 | 0 |
| Sleight | 10 | 9 | 0 | 1 |
| Smuggling | 7 | 6 | 0 | 1 |
| Fate | 11 | 0 | 11 | 0 |
| Extortion | 24 | 0 | 0 | 24 |
| **Total** | **101** | **59** | **12** | **30** |

Notes:

- Tier variants count as separate definitions; only the highest owned tier in a line occupies the board.
- Forgery now contains three complete three-tier lines.
- Fate remains held from normal rewards while its Luck Meter and Fountain systems remain active.
- Extortion and the listed legacy/deprecated definitions remain excluded from the active board.
- Verification derives these counts from `Upgrades.getAll()`; this table is a readable snapshot of the current catalogue.

## Description-Lint Requirements

Before enabling converted content, active Trick descriptions must not contain
these obsolete patterns unless they refer to a different target family:

```text
preferring [same-family coin]
double for [same-family coin]
first selected [same-family coin]
random selected [same-family coin]
if possible, otherwise [global fallback]
by [same-family] material
```

Preferred source language:

```text
the activating coin
the activating coin's original Outcome
another committed coin
the next committed coin
the coin to its left
one uncommitted coin in hand
```

Preferred recursion language:

```text
Replay
Reactivate
Repeat
once per activation
the first time each Flip
chain depth 3
cannot activate Tricks
```

## First Balance Pass Principles

- lower values before reducing activation count;
- allow focused builds to be strong when successfully assembled;
- do not add a universal same-family diminishing return;
- keep Copper/Silver/Gold activation count equal;
- make Tier II/III the main home of full Reactivate feedback;
- preserve useful off-family coin base score;
- use opponent pressure to create encounter-specific decisions, not to
  permanently switch off the strongest family;
- compare deliberate and random coin selection before tuning win rate.
