# Family-Triggered Trick Engine

Status: implemented first playable pass on 2026-07-29; balance values remain
prototype values.

This document supersedes the positional Rig proposal in
`trick-family-design-update.md`. That document remains useful as historical
family analysis, terminology research, and opponent-pressure exploration, but
coins are no longer assigned to individual Trick slots.

## Design Goal

The player should feel that they operate a machine rather than receive a pile
of passive bonuses.

- The selected Tricks define the machine.
- The purse determines which fuel the machine can draw.
- The current hand creates the immediate decision.
- The opponent changes which parts of the machine are safe or efficient.
- Luck determines the offered situation, while the player determines how to
  exploit it.

The game keeps a strict setup/execution boundary. Every player decision occurs
before **Flip**. Once Flip is clicked, the complete coin and Trick sequence
resolves automatically.

## Core Encounter Loop

Initial prototype values:

| Resource | Initial value |
| --- | ---: |
| Active Trick Charms | 5 |
| Hand limit | 5 coins |
| Flip slots | 3 coins |
| Coin replacements | 3 per encounter |
| Flips | 3 per encounter |
| Purse | approximately 12 coins |

These numbers are balance parameters, not permanent rules.

At the beginning of an encounter:

1. Five active Trick Charms are visible across the top of the table.
2. The opponent's current pressure is visible on those Tricks.
3. The player draws up to the hand limit.

During setup:

1. The player commits between one and three coins from the hand.
2. Committed coins may be arranged.
3. The player may replace hand coins while encounter replacements remain.
4. The player chooses Heads or Tails.
5. The interface previews which Tricks are armed and how many normal
   activations each will receive.

During execution:

1. Setup state is locked.
2. Every committed coin is rolled exactly once.
3. Root coin activations resolve from left to right.
4. Each coin activates every unblocked active Trick of its family once.
5. Generated replays, reactivations, and other bounded effects resolve
   automatically.
6. Score and opponent consequences are applied.
7. Played coins enter the spent pile.
8. Unplayed hand coins remain held.
9. The hand draws back up to its limit.

The player cannot select targets, swap coins, replace results, reroll, or make
any other decision after execution starts.

## Trick Capacity

The initial model follows the limited-engine logic of Joker slots:

- the run has at most five active Trick Charms;
- there is no inactive Trick reserve in the first implementation;
- when all five positions are full, gaining a new Trick requires replacing an
  active Trick or declining it;
- a higher tier in an owned Trick line replaces the lower tier directly;
- the left-to-right board order is stable during the encounter and is used for
  deterministic resolution and opponent targeting.

This keeps Trick acquisition consequential and avoids adding a separate
collection-management screen. An inactive reserve can be reconsidered only if
discarding/replacing Tricks proves too punitive.

For compatibility, the current `ownedTrickIds` field may temporarily represent
the active five-Trick board.

## Family Activation Rule

The universal rule is:

> Each committed coin activates every active Trick of its family once.

Examples:

- Three Prestige Tricks and one committed Prestige Coin create three normal
  Prestige activations.
- Three Prestige Tricks and two committed Prestige Coins create six normal
  Prestige activations.
- A committed Weighted Coin activates no Tricks when the player has no
  Weighted Tricks.
- An off-family coin still flips and produces its normal Outcome.

Coin material does not change activation count. Copper, Silver, and Gold coins
each create one family activation. Material may change a coin's base Score,
odds, Luck generation, or another native coin value.

### Canonical family identity

Every coin needs one explicit `activationFamily`. Every Trick needs one explicit
`activationFamily`.

Activation uses the coin's real family captured when the Flip is locked.
Borrowed identities, forged tags, copied effects, and other execution-time
mutations do not retroactively change which Trick family
the coin activates.

Do not infer activation family from a loose tag search. Tags remain useful for
targeting and content description, but the activation relationship must have
one authoritative field.

## Activation Timing

All matching Tricks are armed by a committed coin, but their effects occur in
declared windows.

| Window | Purpose | Runs on reactivation? |
| --- | --- | --- |
| `setup` | Foretell, Weight, or otherwise prepare the source before its roll | No |
| `before_score` | Modify the resolved source Outcome before it scores | Yes |
| `after_score` | Respond after the source produces its score event | Yes |
| `finish` | Prestige replay, aggregate payoff, and other end-of-Flip effects | Yes, when explicitly queued by that activation |

Setup effects occur after coin commitment and before Flip. Their preview must
be deterministic except for explicitly displayed probability changes.

A reactivation does not reroll the physical coin and does not return to the
setup window. It reuses the coin's resolved Heads/Tails result and creates
another eligible score/Trick activation sequence.

## Replay, Reactivate, and Repeat

These terms are mechanically distinct:

### Replay

Repeat a recorded Outcome or score packet, usually at a stated percentage.

- does not reroll the coin;
- does not activate the coin's family Tricks;
- does not generate another base Luck event;
- does not count as a new committed coin;
- cannot replay another Replay unless explicitly stated.

### Reactivate

Run an already-resolved coin through another eligible activation.

- reuses its original Heads/Tails result;
- produces another base coin score event;
- activates matching `before_score`, `after_score`, and `finish` Tricks;
- does not rerun `setup` effects;
- can generate further reactivations only within visible scope limits.

### Repeat

Resolve one named Trick effect again.

- repeats only that Trick;
- does not repeat the coin's base score;
- does not activate the rest of the family;
- is reserved for explicit higher-tier content.

This vocabulary is mandatory in content text. "Trigger again" is too
ambiguous for player-facing rules.

## Resolution Order

The result must be deterministic for a given locked setup and RNG stream.

1. Snapshot the active Trick board, opponent pressure, committed coins, order,
   call, and real activation families.
2. Run root `setup` effects by committed coin position, then Trick board
   position.
3. Roll every committed coin once, from left to right.
4. Enqueue one root activation for each committed coin, from left to right.
5. Resolve activation events first-in, first-out.
6. Within one activation, resolve matching Tricks in Trick board order.
7. Queue Prestige and other `finish` effects with their source activation.
8. Drain the finish queue in creation order.
9. Apply global cleanup, Luck, opponent response, and hand refill.

Generated events never jump ahead of the event that created them.

Each traceable event records:

- `activationId`;
- `kind` (`root`, `reactivation`, or `repeat`);
- source coin instance and committed slot;
- real activation family;
- parent activation/effect, if any;
- chain depth;
- Trick source and Trick board position;
- result and score packet references;
- opponent modification;
- reason for a prevented activation.

## Loop Rules

Short, earned feedback loops are desirable. They are a high-value build payoff,
especially for Tier II and Tier III Tricks.

Normal rules:

- a Trick resolves at most once for a particular activation event;
- a coin may be reactivated at most once per Flip unless an explicit higher-tier
  effect raises that limit;
- default visible chain depth is 3;
- copied or smuggled temporary coins cannot activate families unless their
  effect explicitly grants that permission;
- Replays never generate family activations;
- setup effects never rerun during reactivation;
- generated effects do not acquire a new family from Forgery;
- opponent blocks and jams are checked for every attempted activation.

Higher-tier content can explicitly allow:

- one additional reactivation of a coin;
- reactivation effects to respond to other reactivations;
- a named Trick to Repeat;
- a chain to branch to two neighbours.

The engine also keeps emergency ceilings, initially:

- 24 coin activation events per Flip;
- 128 applied actions per Flip;
- pending action depth 6.

Emergency ceilings are safeguards, not ordinary balancing rules. Normal content
must stop through visible text such as "once per Flip", "the first time", or
"up to three times".

## Hand and Purse Rules

The hand is the player's primary agency.

### Zones

- **Draw pile:** purse coins not currently held or spent.
- **Hand:** visible coins available for commitment.
- **Committed:** hand coins selected for this Flip.
- **Spent:** real coins already played during this encounter.
- **Temporary:** copies or contraband that do not return to the purse.

### Refill

After a Flip:

- committed real coins move to Spent;
- uncommitted hand coins stay in the hand, in their existing order;
- draw random coins from the draw pile until the hand reaches its limit;
- temporary copies disappear;
- smuggled real coins count as played and move to Spent.

The spent pile does not reshuffle during the initial prototype. A purse must
therefore contain enough coins to support the encounter, and spending a
family-rich hand early can create a deliberately weak later hand.

### Replacement

The player starts each encounter with three replacements.

- replacing a coin is allowed only during setup;
- the chosen hand coin moves to Spent;
- one random coin is drawn from the draw pile into that hand position;
- replacements are shared across the whole encounter, not refreshed per Flip;
- a committed coin must be uncommitted before it can be replaced;
- replacement is unavailable when the draw pile is empty;
- replacement history and RNG results are saved and replayable.

This is controlled recovery from a weak hand, not unlimited fishing.

## Focused and Mixed Builds

A one-family build is a valid archetype, comparable to committing to a hand
type in a deckbuilder. It is not an exploit that needs a hard family cap.

Focused builds gain:

- high activation density;
- simple purse requirements;
- spectacular same-family payoff when assembled successfully.

Focused builds still need:

- individually coherent Tricks rather than five matching labels;
- enough matching fuel in the purse;
- scaling, reliability, and recovery;
- answers to opponent disruption;
- access to the appropriate enemy reward families across a random route.

Mixed builds compete through complementary functions:

- Weighted improves reliable source Outcomes.
- Prediction converts hidden information into setup knowledge.
- Forgery copies a genuine left neighbour's completed Outcome or schedules bounded activations from its family.
- Sleight changes which coin body receives a result.
- Smuggling adds extra coin bodies.
- Prestige replays completed Outcomes.
- Momentum reactivates coins and extends chains.

Do not initially suppress matching enemy or reward families because the player
has specialized. If focused builds become too reliable, first adjust reward
availability, individual Trick coherence, purse consistency, or cross-family
synergy. Hidden anti-specialization weighting risks making successful
commitment feel punished.

## Opponent Interaction with the Trick Board

Opponent pressure replaces the need to randomly shuffle the player's Tricks.
It creates a contextual setup puzzle without taking ownership of the engine
away from the player.

The first implemented Enemy Trick pass also pressures physical coin slots.
Starting with encounter 3, each enemy receives exactly one round-gated Enemy
Trick for its complete encounter. Difficulty rank unlocks a different mechanic;
it does not grant two lower-rank skills. The skill may retarget between Flips,
but the enemy never changes to a second skill mid-encounter.

Boss encounters are outside this pool. They receive no regular Enemy Trick and
will use authored, family-themed Boss Trick kits instead.

Encounters 1 and 2 are a clean grace period. Rank-1 pressure teaches the system
in encounter 3, rank 2 joins the pool in encounter 4, and rank 3 starts at
encounter 5.

Enemy classes do not currently determine Enemy Tricks. Class affinities and
stronger numerical versions are deferred until isolated mechanics have been
tested. The live catalogue is documented in `docs/game/enemy-tricks.md`.

Opponent intent is chosen and displayed before setup. It is included in the
locked Flip snapshot.

Initial pressure vocabulary:

| Pressure | Effect |
| --- | --- |
| Block | The marked Trick cannot resolve this Flip. |
| Weaken | The marked Trick resolves at a displayed percentage of normal value. |
| Jam | The marked Trick can resolve only a displayed number of times this Flip. |
| Tax | Every resolution of the marked Trick grants the opponent a displayed benefit. |
| Family clamp | Activations after the displayed family count are weakened, not silently removed. |
| Expose | The marked Trick becomes stronger but causes a displayed retaliation when used. |

Initial implemented pool:

| Skill | Surface | Rank | Minimum round |
| --- | --- | ---: | ---: |
| Weakened Charm | Trick | 1 | 3 |
| Tarnished Slot | Coin slot | 1 | 3 |
| Jammed Charm | Trick | 2 | 4 |
| Leeching Slot | Coin slot | 2 | 4 |
| Blocked Charm | Trick | 3 | 5 |
| Poisoned Charm | Trick | 3 | 5 |

Rules:

- target one or a small number of visible Trick positions;
- show the target and exact consequence before coin commitment;
- avoid repeatedly blocking the player's strongest Trick every Flip;
- give each opponent a small recognizable pressure identity;
- include exploitable or conditional pressure, not only denial;
- never request a player reaction during execution.

## UI Contract

The main table should show:

- five active Tricks at the top;
- family and tier on every Trick;
- opponent pressure attached to the affected Trick;
- committed coins below;
- held coins in a five-coin hand;
- three encounter-wide replacement charges;
- current call;
- projected normal activation count on every Trick.

Example preview:

```text
Encore ×2   Curtain Call ×2   Keep It Rolling ×1   Follow Through ×1   Weighted Palm ×0
```

The count is a setup preview, not a guarantee of successful conditions or
generated reactivations. A blocked Trick clearly reads `BLOCKED`; a jammed
Trick can read `×2 → max 1`.

During execution:

- the source coin pulses;
- all matching Tricks light in board order;
- links show Replay, Reactivate, or Repeat;
- reactivation depth is visible;
- blocked or jammed attempts show a brief failure reason;
- setup controls are absent or disabled until resolution ends.

The animation may be skipped or accelerated, but skipping changes presentation
only. It cannot open a player decision window.

## Prototype Success Criteria

The first playable slice succeeds when:

- the same hand produces different preferred commitments for different Trick
  boards;
- random coin selection performs materially worse than family-aware selection;
- committing two same-family coins is powerful but not always correct;
- the player sometimes holds a matching coin for a later Flip;
- replacing a coin can rescue a weak hand but is not always worth spending;
- off-family coins remain useful through base score or complementary effects;
- a Momentum-to-Prestige reactivation is visually and mechanically legible;
- opponent pressure changes the best setup without simply deleting the build;
- no input can mutate the locked Flip.

## Deferred Questions

These should be answered through the vertical slice rather than guessed now:

- whether the final hand limit should be five or six;
- whether the player may commit fewer than three coins without a separate
  penalty;
- whether spent coins ever reshuffle in longer encounters;
- whether active Trick board order can be changed between encounters;
- whether a fifth/sixth Trick or fourth Flip slot belongs to meta progression;
- whether family-focused builds need any diminishing return after content and
  enemy pressure are implemented;
- whether Fate returns as a normal activation family.
