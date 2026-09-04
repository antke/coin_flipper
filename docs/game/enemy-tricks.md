# Enemy Tricks

Enemy Tricks are telegraphed normal-encounter rules that change the player's
setup decision. They are not tied to enemy classes during the first balance
pass. Bosses never draw from this catalogue; they use authored Boss Tricks.

## First-Pass Contract

- From normal encounter 3 onward, each eligible enemy owns exactly one Enemy
  Trick for the complete encounter.
- Encounters 1 and 2 are a grace period and do not assign an Enemy Trick.
- A higher difficulty rank does not grant additional Enemy Tricks.
- The Enemy Trick's target may change between Flips, but its mechanic does not.
- Every target and consequence is visible during setup and locked on Flip.
- Enemy Tricks can target an active Trick Charm or a physical coin slot.
- More difficult Enemy Tricks enter the eligible pool through `minRound` gates.
- Enemy classes remain presentation and reward identities until testing supports
  mechanical affinities.
- Stronger numerical versions of the same Enemy Trick are deferred.

Selection and targeting use deterministic run RNG derived from the run seed,
stage, variant, Enemy Trick, and Flip intent index. Replay traces record the
locked Enemy Trick snapshot and its effects.

## Initial Catalogue

| Enemy Trick | Surface | Rank | First round | Effect |
| --- | --- | ---: | ---: | --- |
| Weakened Charm | Trick | 1 | 3 | The marked Trick resolves at 75% effectiveness. |
| Tarnished Slot | Slot | 1 | 3 | Outcomes from the marked slot are worth 75%. |
| Jammed Charm | Trick | 2 | 4 | The marked Trick resolves for only its first activation each Flip. |
| Leeching Slot | Slot | 2 | 4 | Each matching coin in the marked slot heals 5% of maximum enemy health. |
| Blocked Charm | Trick | 3 | 5 | The marked Trick cannot resolve. |
| Poisoned Charm | Trick | 3 | 5 | Lose 10% of the Flip's Score per marked-Trick activation, capped at 30%. |

The current four-round run introduces rank-1 pressure in encounter 3. Because
encounter 4 is a boss, rank-2 and rank-3 regular Enemy Tricks currently require
developer fixtures or a longer run.

## Boss Boundary

Boss stages always clear regular Enemy Trick state, including when loading an
older development snapshot. Authored Boss Tricks are defined separately in
`docs/game/boss-tricks.md`.

## Surface Rules

### Trick Charm pressure

Charm pressure applies to genuine activations, explicit Trick Repeats, and
forged activations. Prevented activations do not pay activation costs. Poison
counts a `(Trick position, activation event)` pair once even when that Trick
has effects in several resolution phases.

### Coin-slot pressure

A regular coin uses its committed slot. A Smuggled or Contraband body uses its
anchor slot, so overloading a dangerous slot carries the same hazard for every
physical body there.

Tarnished Slot applies to root Outcomes and Reactivations scored from the slot.
Prestige copies the already-tarnished recorded Outcome rather than applying the
slot modifier a second time.

Leeching Slot checks every matching physical coin body in the slot, including
overloaded Smuggled or Contraband coins. Palmed coins are not physically in a
slot and do not count. Healing does not remove the player's earned run Score;
mechanically it reduces damage already applied to the opponent.

## Balance Evaluation

The simulation report records Enemy Trick encounters separately from affected
batches, plus effect events, Poison score loss, and opponent healing. Difficulty
ranks should eventually be revised from measured score loss, win-rate change,
setup-decision change, and frequency of hands with no reasonable counterplay.

Do not add class affinities, multiple simultaneous Enemy Tricks, or upgraded
Enemy Trick values until this catalogue has been tested in fixed-build and
normal-run scenarios. Powerful boss mechanics belong to the separate Boss
Trick catalogue rather than upgraded entries here.
