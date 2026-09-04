# Family-Triggered Trick Engine: Technical Implementation Plan

Status: implemented and verified on 2026-07-29.

## Implementation Result

All eight phases below have an implemented first pass:

- a persistent five-coin hand, three Flip slots, spent pile, and three
  encounter-wide replacements;
- a stable five-Trick active board with in-place tier upgrades and explicit
  replacement at capacity;
- explicit coin/Trick family metadata, family previews, and active-Trick-only
  hook dispatch;
- deterministic Replay, Reactivate, and Repeat semantics with activation
  ledger, parent/depth metadata, and hard loop ceilings;
- telegraphed opponent pressure whose target can rotate between Flips;
- one deterministic, round-gated Enemy Trick per eligible encounter, including Charm
  and coin-slot pressure, with class assignment and upgraded values deferred;
- converted Weighted, Prestige, Momentum, Prediction, Forgery, Sleight, and
  Smuggling content;
- Fate held, Extortion/economy Tricks removed, and legacy active boards
  sanitized on load;
- family-aware simulation, save/replay coverage, replacement-aware acquisition,
  updated developer builds, and native Tier II/III additions for thin families.

The permanent focused contract is `scripts/family_trigger_verify.lua`.
Superseded global-passive fixtures remain in the repository as historical
references but are no longer registered as live engine contracts.

Canonical behavior is defined in
`docs/family-trigger-engine-design.md`. Proposed first-pass content is defined
in `docs/family-trigger-trick-migration.md`.

## Current Architecture Assessment

The codebase is closer to this design than the old positional Rig plan, but the
resolution core still assumes global passive Tricks.

Useful existing foundations:

- `src/domain/run_state.lua` already stores real coin instances and
  `ownedTrickIds`.
- `src/systems/purse_system.lua` already distinguishes available, dealt,
  selected, board/contraband, and exhausted coins.
- `src/systems/flip_resolver.lua` already has deterministic phases, per-coin
  state, trace output, pending actions, and hard action/depth limits.
- `src/systems/scoring_system.lua` already produces per-coin score events.
- `src/core/hook_registry.lua` and `src/core/action_queue.lua` already express
  most effects as data-driven triggers and modular operations.
- Replay, Momentum, Prediction, Forgery, Sleight, and Smuggling
  already have focused action modules.
- reward generation in `src/systems/reward_system.lua` already maps enemy
  classes to Trick families.
- the stage UI already supports selecting fewer coins than the dealt hand,
  arranging selected coins, locking on Flip, and showing Trick callouts.

Critical mismatches:

1. `HookRegistry.collectSources` makes every owned Trick globally active.
2. Per-coin phases run every global Trick against every coin and rely on
   conditions/selectors to narrow the effect.
3. There is no explicit coin-family activation event or activation ledger.
4. There is no five-Trick capacity/replacement rule.
5. `PurseSystem.refillHand` returns unplayed coins to the available pool instead
   of keeping them held.
6. `dealHand` creates a fresh dealt hand only when the old hand is empty; there
   is no draw-to-limit operation for a persistent hand.
7. current `trigger_random_neighbor` generates an extra score event, not a full
   family reactivation.
8. current Replay and chain systems do not expose the strict Replay /
   Reactivate / Repeat distinction.
9. opponent content modifies general stage rules; it cannot yet pressure
   individual active Trick positions.
10. simulation policies understand coin score/family heuristics but not
    activation density, holding, encounter-wide replacement, or loop value.

## Recommended Architecture

Add an explicit activation layer instead of embedding family matching in every
Trick definition.

### New modules

#### `src/systems/trick_board_system.lua`

Own:

- five active Trick positions;
- capacity and replacement validation;
- tier-line replacement;
- deterministic board order;
- opponent Trick pressure;
- board snapshot at Flip lock;
- activation-count preview.

Initial compatibility rule:

- `runState.ownedTrickIds` remains the active board list;
- a new `runState.maxActiveTricks` defaults to 5;
- no reserve collection exists;
- acquisition invokes a replacement choice when capacity is full.

If acquisition UI cannot support replacement in the first vertical slice,
prototype runs should start with a fixed five-Trick board and normal Spoils
acquisition should be feature-flagged rather than silently exceeding capacity.

#### `src/systems/trick_activation_system.lua`

Own:

- family matching;
- creation of root activation events;
- activation FIFO;
- per-activation Trick execution in board order;
- reactivation counts and chain depth;
- Replay / Reactivate / Repeat scheduling;
- pressure checks;
- trace ledger;
- player-visible stop reasons.

It should use `HookRegistry` to evaluate data-driven triggers, not replace the
action system.

#### Optional `src/domain/activation_event.lua`

Recommended shape:

```lua
{
  activationId = "activation_004",
  kind = "reactivation",
  sourceInstanceId = "coin_009",
  sourceCoinId = "copper_bent_coin",
  sourceSlotIndex = 3,
  activationFamily = "prestige",
  result = "heads",
  parentActivationId = "activation_002",
  parentTrickId = "keep_it_rolling",
  chainDepth = 1,
  canRunSetup = false,
  canActivateTricks = true,
}
```

### Data changes

Coin definitions:

```lua
activationFamily = "prestige"
```

Trick definitions:

```lua
trick = {
  activationFamily = "prestige",
  category = "prestige", -- compatibility/display alias during migration
  tier = 1,
  activationWindow = "finish",
  reactsTo = {
    root = true,
    reactivation = true,
  },
  scope = {
    oncePerActivation = true,
  },
}
```

Use an explicit field even when it duplicates current archetype/category data.
Validation should require it for active family-trigger content.

Stage state:

```lua
stageState.trickBoard = {
  pressure = {
    [2] = { kind = "blocked", sourceId = "opponent_move_1" },
  },
  replacementsRemaining = 3,
  phase = "setup",
  revision = 1,
}
```

Purse state keeps:

```lua
stageState.purse = {
  availableInstanceIds = {},
  dealtHandSlots = {}, -- persistent held hand
  selectedSlots = {},
  exhaustedInstanceIds = {},
  replacementHistory = {},
}
```

Do not introduce a second hand data structure. Convert `dealtHandSlots` into
the persistent hand and keep `selectedSlots` as references/order for committed
coins.

### Resolution context

Add:

```lua
context.trickBoardSnapshot
context.activationQueue
context.finishQueue
context.activationLedger
context.currentActivation
context.reactivationCounts
context.trickActivationCounts
context.lockedSetup
```

`currentActivation` becomes the authoritative source coin for a
family-triggered Trick. Content should target `activation_source` instead of
searching all selected coins and preferring a family/archetype.

## Resolution Refactor

The current broad phase sweep can be migrated incrementally.

### Keep global sources global

Boss modifiers, stage modifiers, meta modifiers, and true global temporary
effects continue through `HookRegistry.collectSources`.

### Remove active Tricks from the global sweep

`HookRegistry.collectSources` should accept source-selection options or split
into:

- `collectGlobalSources`;
- `collectActiveTrickSources`;
- `collectCoinSources`.

Active Tricks must not run in the general global source list. They are invoked
only by `TrickActivationSystem` for a matching activation.

### Preserve hook phases inside an activation

For one activation:

1. set `context.currentActivation` and `context.currentCoin`;
2. select active Tricks whose `activationFamily` matches;
3. apply opponent pressure;
4. run relevant trigger hooks for those selected Tricks only;
5. clear the activation context;
6. enqueue generated events.

This reuses trigger conditions, target selectors, action validation, tracing,
and existing focused action modules.

### Separate root preparation from reactivation

Before rolling:

- create root activation descriptors for committed coins;
- run matching `setup` triggers;
- apply probability and Foretell effects;
- snapshot final per-coin roll weights.

After rolling:

- enqueue the root activations;
- resolve their score and execution-window Tricks;
- allow Reactivate to enqueue another activation that starts at
  `before_score`;
- never rerun setup triggers for Reactivate.

### Score event extraction

The hardest code change is making one coin score event reusable.

`ScoringSystem.buildScoreActions` currently assembles the whole batch. Extract
or add an API similar to:

```lua
ScoringSystem.buildCoinActivationScoreActions(context, coinState, activation)
```

It should:

- create a new score event for the activation;
- run matching `before_coin_score` Trick and global hooks;
- apply base coin score;
- run `after_coin_score` hooks;
- record a resolution packet;
- allow Reactivate to call the same path again;
- mark Replays as packet copies so they do not activate Tricks.

Aggregate `before_scoring` and `after_scoring` hooks may remain around the full
queue, but content that needs per-activation multiplicity must move to
per-activation windows.

## Purse and Hand Migration

Replace the current fresh-deal lifecycle with persistent holding.

### Add `PurseSystem.fillHand`

Behavior:

- preserve existing uncommitted `dealtHandSlots`;
- remove spent/temporary slots;
- draw random available instances until `getHandSize`;
- preserve held order;
- return a traceable draw event;
- stop cleanly when the draw pile is empty.

### Replace `refillHand`

New end-of-Flip behavior:

1. move selected real coins to `exhaustedInstanceIds`;
2. move smuggled real coins to exhausted;
3. delete contraband copies;
4. remove played slots from `dealtHandSlots`;
5. clear `selectedSlots` and `boardSlots`;
6. retain unplayed slots;
7. call `fillHand`;
8. record spent, held, and drawn instance IDs.

The current `selected_exhaust_unselected_return` refill rule becomes
`selected_spend_unselected_hold`.

### Add `PurseSystem.replaceHeldCoin`

Validate:

- stage phase is `setup`;
- replacement charges remain;
- target is held and not currently committed;
- draw pile is non-empty.

Then:

- move target instance to exhausted;
- draw one random instance into the same hand position;
- decrement encounter replacement count;
- record old/new instance IDs, RNG decision, batch index, and remaining count.

### Purse exhaustion

The current stage can fail as soon as `dealHand` sees no available coins. Under
the new model, an empty draw pile is not a failure while the player still has
held coins. Failure due to purse exhaustion occurs only when:

- the stage is active;
- no committed/held coin can be played;
- no available coin can be drawn.

## Trick Acquisition and Capacity

Current `AcquisitionSystem.grantTrick` and `ActionQueue.grant_trick` append to
`ownedTrickIds`.

Required changes:

- enforce `maxActiveTricks`;
- preserve same-line tier replacement;
- return `trick_board_full` with replacement metadata when a different line is
  acquired at capacity;
- let Spoils UI choose an active Trick to replace;
- allow declining or taking the normal Skip reward;
- include old/new board state in history and replay.

Do not silently discard the oldest Trick and do not create an invisible
reserve.

Enemy-class reward pools already support focused build assembly:

- Forger → Forgery;
- Smuggler → Smuggling;
- Card Shark → Prediction/Weighted;
- Fortune Teller → Fate;
- Pit Boss → Weighted/Forgery;
- Magician → Sleight;
- Showman → Prestige/Momentum.

The pools need content changes for held/removed families, but not a new reward
algorithm for the first slice. Do not add anti-specialization weighting until
metrics prove it is required.

## Opponent Trick Pressure

Enemy pressure is now sourced from a standalone Enemy Trick catalogue rather
than enemy class or boss-modifier identity. The active enemy keeps one skill
for the encounter and deterministically retargets it between Flips.

Implemented state shape:

```lua
enemySkill = {
  revision = 1,
  skillId = "lifesteal_slot",
  targetIndex = 2,
  intentIndex = 1,
  slotPressure = {
    [2] = { kind = "lifesteal", healMaxHpOnMatch = 0.05 },
  },
}
```

At the beginning of each setup:

1. keep the encounter's assigned Enemy Trick;
2. resolve its target against the stable Trick board;
3. store Charm pressure in `trickBoard.pressure` or physical pressure in
   `enemySkill.slotPressure`;
4. display it before commitment;
5. snapshot it when Flip is locked.

Encounters 1 and 2 deliberately return no eligible Enemy Trick. The first
catalogue introduces Weaken and Tarnished Slot in encounter 3, Jam and
Lifesteal in encounter 4, and Block and Poison in encounter 5. Class
affinities, multiple simultaneous skills, Tax, Expose, redirection, and
upgraded skill values remain deferred.

Boss stages are structurally ineligible for this catalogue. They clear regular
Enemy Trick state. The separate authored Boss Trick system currently includes
Betting Betty and The Favourite for Weighted, plus Washed-up Magician and
Centre Stage for Prestige, plus Madcap Lunatic and Full Throttle for Momentum.
The Impostor and Stolen Identity provide the Forgery boss pattern. The
Quickhand and Three Cups provide the Sleight-of-Hand robustness pattern, with
one hidden shuffled body palmed and returned to hand during execution. The
Taxman and Nothing to Declare provide the Smuggling boss pattern, taxing final
slot-attributed Score while one seeded slot remains Off the Books. Blind Prophet
and Written in Stone provide the Prediction boss pattern: every setup reveals a
seeded mixed Heads/Tails slot inscription, and physical coins resolve to their
slot's result unless Twist of Fate overrides the table.

## Input Lock

The UI currently blocks many actions while reveal animation is active, but the
design requires a domain-level boundary.

Use explicit phase state:

```text
setup → locked → resolving → reveal → setup/complete
```

All mutation APIs for:

- coin selection;
- coin deselection;
- reordering;
- replacement;
- call selection;
- Trick replacement;
- any future setup action

must validate `stageState.trickBoard.phase == "setup"`.

`FlipResolver` receives an immutable locked snapshot or cloned input. It does
not read mutable UI selection state after resolution begins.

Reveal skipping may move `reveal → setup/complete`; it must never unlock a
partially resolved Flip.

## Action Operations

Keep existing:

- `replay_resolution_packet` as the implementation base for Replay;
- score, chance, prediction, identity, swap, replacement, and Smuggling
  operations;
- `queue_actions` and existing action safety ceilings.

Add or rename:

| Operation | Meaning |
| --- | --- |
| `reactivate_coin` | Enqueue a full eligible coin activation using its resolved result. |
| `repeat_trick` | Enqueue one named Trick effect without base coin score or family fan-out. |
| `replay_resolution_packet` | Replay recorded score only; explicitly cannot activate families. |
| `set_trick_pressure` | Stage/opponent setup operation, not usable during resolution. |

Deprecate `trigger_random_neighbor` after Momentum migration. Keep a temporary
compatibility adapter only while old Trick definitions or fixtures still use
it.

All generated event actions need trace fields:

- source activation;
- generating Trick;
- target coin/Trick;
- depth;
- prevented reason;
- RNG roll when applicable.

## Content Migration Mechanics

The mechanical conversion rule is:

1. replace family-preferring target search with `activation_source`;
2. remove bonuses that exist only because the source is the preferred
   same-family archetype;
3. keep the closest effect shape and timing;
4. change `oncePerFlip` to `oncePerActivation` when multiplicity is intended;
5. keep `oncePerFlip` only when stacking would break the identity of the
   effect;
6. declare whether the effect reacts to root activations, reactivations, or
   both;
7. make Replay/Reactivate/Repeat explicit;
8. add deterministic target and recursion limits.

Do not mechanically convert Extortion or deprecated economy Tricks. Fate stays
out of the first playable pool.

## Save and Replay Migration

Save:

- add a schema version for the family-trigger engine;
- persist `maxActiveTricks`;
- persist active Trick order;
- persist hand order, available and spent zones;
- persist replacements remaining/history;
- persist current opponent pressure and setup phase;
- never save halfway through a synchronous activation queue unless resume from
  mid-Flip is explicitly supported.

Replay bootstrap:

- active Trick board order;
- coin activation families;
- hand limit and Flip slots;
- replacement budget;
- loop limits.

Replay actions:

- draws and replacements;
- commitments and reorder;
- locked setup snapshot;
- activation and parent event IDs;
- blocks/jams/weaken scaling;
- Replay/Reactivate/Repeat events.

Old saves containing more than five Tricks cannot be migrated silently without
changing the build. Options:

1. invalidate active-run saves across the prototype flag;
2. present a one-time choose-five migration screen;
3. retain overflow only as a temporary compatibility reserve, never active.

For the prototype, invalidating active development runs is the least complex
and most honest option. Permanent player saves should use option 2.

## UI Migration

Primary file: `src/states/stage_state.lua`.

Required work:

- move active Trick display from a drawer-only summary into a visible five-slot
  board;
- show activation count previews derived from current committed families;
- attach opponent pressure to the affected Trick;
- add replacement action and encounter-wide counter to the hand;
- keep current selection and drag-to-reorder behavior;
- animate activation source → Trick board → generated target;
- distinguish Replay, Reactivate, and Repeat visually;
- update the Flip log to show activation parentage and prevented attempts;
- preserve existing skip/fast reveal as presentation-only controls.

The existing Trick charm renderer, callouts, reveal timeline, score floaties,
and coin row animation can be extended rather than replaced.

## Simulation and Analytics

Current simulation results will be misleading until policies understand the new
actions.

Minimum policy additions:

- score a candidate commitment by base Outcome plus matching active Trick
  activations;
- value holding a matching family coin for later;
- value Momentum target order;
- account for blocked/weakened/jammed Tricks;
- spend a replacement only when expected improvement clears a threshold;
- model spent and held zones correctly;
- stop evaluating removed/held Trick families.

Required comparisons:

- strategic policy versus random coin selection;
- strategic order versus random order;
- replacement policy versus never replace;
- focused versus mixed Trick boards;
- loop-enabled versus loop-disabled content;
- each opponent pressure type versus no pressure.

Useful metrics:

- activation attempts and successful activations by family;
- activations per committed coin;
- Replay/Reactivate/Repeat counts;
- prevented activations by pressure type;
- replacement usage and expected gain;
- held-family decisions;
- score concentration by Flip number;
- focused-build frequency and win rate;
- action/depth limit hits (must normally be zero).

## Verification Matrix

### Unit/fixture contracts

- one matching coin activates N matching Tricks once each;
- two matching coins activate N matching Tricks twice each;
- off-family coin activates none;
- blocked Trick activates zero;
- weakened Trick applies exact scale;
- jammed Trick stops at its displayed count;
- active board order determines Trick order;
- Replay adds score but no family activation;
- Reactivate adds base score and matching execution Trick activations;
- Reactivate does not rerun setup effects or reroll;
- Repeat runs one Trick only;
- Forgery cannot change locked real activation family mid-Flip or recursively forge a generated activation;
- contraband/copies do not activate families by default;
- per-coin reactivation and chain depth limits stop loops deterministically;
- held coins remain in hand;
- played/replaced coins enter Spent;
- replacement budget is encounter-wide;
- no setup mutation is accepted after lock.

### Replay/save contracts

- identical seed and setup produce the identical activation graph;
- replacement draw is replayable;
- pressure target is replayable;
- save/load between Flips preserves hand, spent pile, charges, and pressure;
- old active-run save behavior follows the chosen migration policy.

### Content contracts

- every active coin has one valid `activationFamily`;
- every reward-eligible active Trick has one valid `activationFamily`;
- no active description contains obsolete same-family preference language;
- every Reactivate/Repeat effect declares caps;
- Extortion and held Fate content do not enter normal reward pools;
- tier lines remain mutually exclusive.

### Full regression

Use the repository's existing verification commands through the available
LuaJIT runtime:

```sh
luajit scripts/engine_fixture_verify.lua
luajit scripts/invariant_verify.lua
luajit scripts/replay_verify.lua
luajit scripts/artifact_verify.lua
```

Then run targeted simulations only after policies have been migrated.

## Implementation Phases

### Phase 0 — Lock documentation and prototype content

- accept the core rules in the design document;
- accept or edit the first-pass Trick catalogue;
- choose the five-Trick vertical-slice board;
- use a feature flag so unfinished mechanics do not contaminate existing runs.

Exit: one exact expected Flip can be written by hand, including activation
order and score packets.

### Phase 1 — Persistent hand and replacements

- convert refill to hold unplayed coins;
- add draw-to-limit;
- add encounter-wide replacement state/action;
- update save, replay, validation, UI, simulation purse logic, and fixtures.

Exit: hand management is playable without any family-triggered Tricks.

### Phase 2 — Trick board and family metadata

- add five-Trick capacity/order;
- add explicit coin and Trick activation families;
- separate active Tricks from global sources;
- add activation-count preview;
- use fixed developer builds before changing acquisition flow.

Exit: committing coins produces correct preview counts with no behavior change.

### Phase 3 — Non-recursive vertical slice

Convert:

- Tailside Edge;
- Headside Edge;
- Weighted Palm;
- Steady Finish;
- Encore;
- Curtain Call;
- Impossible Finale.

Implement root activation events and Replay only. No Reactivate yet.

Exit: one/two Prestige Coins produce the documented multiplicity, and Replays
never retrigger.

### Phase 4 — Reactivation and bounded loops

- extract reusable per-activation score path;
- add `reactivate_coin`;
- convert Keep It Rolling, Follow Through, and Ripple II/III;
- add ledger, parent trace, depth/reactivation limits, and reveal animation.

Exit: Momentum can reactivate Prestige and visibly cause a second set of
Prestige activations without exceeding declared limits.

### Phase 5 — Trick capacity and acquisition

- enforce five active Tricks;
- add replacement selection to Spoils;
- update encounter grants, shops/dev controls, history, and replay;
- remove Extortion from normal pools;
- hold Fate from normal pools.

Exit: a normal run can build and replace its active engine safely.

### Phase 6 — Opponent pressure

- add one telegraphed, round-gated Enemy Trick per eligible encounter;
- support both Charm and coin-slot targeting;
- keep the skill stable while allowing deterministic retargeting;
- teach simulation and analytics about pressure.

Exit: pressure changes commitment decisions and never asks for execution input.

### Phase 7 — Advanced family conversion

Convert:

- Prediction setup reveals;
- Forgery Outcome copies and bounded cross-family activations;
- Sleight automatic movement/substitution;
- capped Smuggling overload.

Exit: every reward-eligible surviving Trick is either converted or explicitly
disabled.

### Phase 8 — Balance and content expansion

- add missing Tricks within thin families — first pass complete with native
  Weighted Palm and Switcheroo tier lines;
- tune focused versus mixed engines — initial family-aware simulation policy
  and controlled payoff contract complete; ongoing playtest work;
- tune hand/purse/Flip/replacement counts — implemented at 5/12/3/3 prototype
  values;
- measure first-Flip burst — activation ledger and policy scripts now expose
  the required data;
- decide Fate's future — explicitly held while the Fountain/Luck system
  remains independent;
- remove compatibility operations and obsolete fixtures — obsolete fixtures
  are retired from the live registry; compatibility definitions remain only
  for save/history lookup.

## Primary Technical Risks

### Event ordering

Global hook phases and per-activation effects can double-apply if migrated
piecemeal. Active Tricks must leave the global source list before converted
effects become activation-driven.

### Score duplication

Reactivate must create a new score event through the authoritative score path,
not directly edit HP/Score totals.

### Setup effects on reactivation

Weighted/Prediction effects cannot be allowed to rerun after the result exists.
Window validation must enforce this rather than relying on content discipline.

### State aliasing

`dealtHandSlots`, `selectedSlots`, and `handSlots` currently share compatibility
relationships. Persistent holding must preserve instance identity without
duplicating the same coin in two authoritative zones.

### Save/replay surface

The activation graph introduces parent/child ordering and new RNG decisions.
Trace and replay must be designed with the system, not bolted on afterward.

### UI duration

A successful loop may produce many effects. Reveal timing must compress repeated
activations and allow skipping without obscuring source/target relationships.

### Content explosion

The universal cross-product can make one additional coin or Trick multiply the
engine sharply. Balance values must be lower than current once-per-Flip values,
and high-tier fan-out needs strict caps.
