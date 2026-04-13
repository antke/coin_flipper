# Coin-Flip Roguelike (Love2D) — Technical Implementation Plan

## 1. Purpose of this document

This document is the authoritative implementation plan for a Love2D prototype of a coin-flipping roguelike inspired by the build-driven structure of games like Balatro.

The goal is not only to define features, but to define a **technical architecture that remains flexible under heavy iteration**.

This project must support:

- rapid tuning of numbers and rules
- easy addition/removal of coins, upgrades, boss modifiers, and stage rules
- deterministic resolution for debugging and balancing
- a **hook-based resolution engine** so gameplay logic does not collapse into hardcoded branches
- future expansion into meta progression / persistent upgrades

This plan is intentionally detailed so implementation can proceed from scratch in a precise and controlled way.

---

## 2. Game concept summary

### 2.1 Core player fantasy

The player builds a run around manipulating and exploiting coin flips.

Each stage gives the player a limited number of flip opportunities. On each flip:

1. the player chooses **Heads** or **Tails**
2. all currently equipped coins are flipped
3. all coin and upgrade effects resolve
4. score is awarded based on the interaction between:
   - the player call
   - the actual flip result(s)
   - active coins
   - run upgrades
   - boss/stage modifiers
   - future meta effects

The player progresses by:

- meeting a stage score threshold
- acquiring coins and upgrades between stages
- adapting loadouts for each stage
- constructing synergies (for example tails-focused, weighted-odds, streak, economy, or boss-counter builds)

### 2.2 Prototype scope

The first build is an MVP to prove/disprove the design.

Prototype scope:

- 3 regular rounds
- 1 boss round
- stage-specific score thresholds
- 3 flips per stage by default
- up to 3 equipped coins by default
- no duplicate coins in the collection or loadout
- no gameplay order dependence for equipped coins in the MVP ruleset
- run-specific upgrades persist through the run
- persistent/meta upgrades exist conceptually and will be scaffolded, even if the first version only implements a minimal subset
- shop between rounds
- previously committed stage loadout is persisted and shown again on later loadout screens as the current build
- core values such as rounds, slots, offers, flips, and base weights come from central config/constants rather than being hardcoded across systems
- score split into:
  - `stageScore` for progression
  - `runTotalScore` for run summary/statistics

### 2.3 Rule clarifications already decided

- The player owns a **collection** of coins.
- Before a stage, the player chooses a **loadout** from that collection.
- The player equips up to `maxActiveCoinSlots` coins for that stage.
- Base slot count is 3, but future upgrades/meta unlocks may increase it.
- The last committed loadout should persist between stages and pre-populate the next loadout selection screen if still valid.
- On each flip, **all equipped coins** are flipped.
- Stage clear is checked **only after the full batch resolves**.
- If the threshold is met by the first or second coin in a batch, the remaining equipped coins still resolve.
- Coin order does **not** matter for MVP gameplay rules, but loadout storage should preserve slot positions so ordered mechanics can be enabled later.
- Duplicates are **not** allowed.
- Upgrades affect the whole run.
- Bosses should introduce rule changes, not just inflated thresholds.

---

## 3. Primary technical requirement

The most important technical requirement is flexibility.

This game is expected to change repeatedly in:

- thresholds
- number of flips
- scoring formulas
- weighting rules
- shop economy
- boss rules
- content definitions
- run progression structure
- meta progression modifiers

Therefore, the codebase **must not rely on hardcoded, monolithic gameplay flows**.

Instead, it must be built around:

1. a **macro state graph** for screen/round progression
2. a **micro resolution pipeline** for gameplay logic
3. a **hook-based rules engine** that lets content inject behavior into controlled phases
4. a **central action/effect interpreter** that applies gameplay state changes deterministically

This is the single most important architectural decision in the project.

---

## 4. Architectural overview

The architecture is split into two layers.

### 4.1 Layer A — macro game flow (state graph)

This controls large-scale movement through the game:

- boot
- menu
- meta progression screen (future)
- pre-stage loadout selection
- stage gameplay
- stage result
- shop
- run summary

This can be thought of as a state machine, but it should be implemented as a **state graph / step graph**, not as rigid hardcoded transitions.

Why:

- certain screens may be inserted conditionally
- some stages may add extra pre-stage or post-stage steps
- relics/upgrades/modifiers may later introduce bonus reward steps or special events
- the boss may have unique transitions

### 4.2 Layer B — micro gameplay resolution (hook pipeline)

This controls what happens when the player performs one flip action.

Each player flip resolves as a **deterministic multi-phase pipeline**.

The pipeline is fixed.
The behavior inside it is flexible.

That means:

- phase order is explicit and stable
- coins/upgrades/bosses inject behavior through hooks
- hook outputs are translated into standardized actions/effects
- state mutations happen centrally

This avoids both extremes:

- too rigid: hardcoded one-off branches everywhere
- too abstract: uncontrolled “everything listens to everything” chaos

---

## 5. Architectural principles

These principles should guide every implementation decision.

### 5.1 Determinism first

Gameplay resolution must be reproducible.

Same seed + same initial state + same inputs = same outcome.

This is critical for:

- debugging
- balance testing
- regression tracking
- replayability analysis

### 5.2 Explicit phases, flexible content

The flow of resolution should be explicit.
Content should be flexible.

In other words:

- **phases are code-level structure**
- **coins/upgrades/modifiers are data-driven content**

### 5.3 One mutation path

State should not be mutated ad hoc from arbitrary modules.

Instead:

- hooks produce actions/effects
- the engine applies those actions centrally

This makes debugging and reasoning dramatically easier.

### 5.4 Current order independence, future order support

Current MVP rules treat coin order as irrelevant for gameplay.

However, the data model should still preserve slot/index placement so future content can opt into ordered behavior without a large refactor.

Practical rule:

- store equipped coins in slot order
- derive a canonical order-insensitive key when current rules require it
- never assume the absence of slot order in storage

### 5.5 Separate run state from meta state

Run-time upgrades and long-term progression are different systems.

They may interact, but they must not be blended together in one undifferentiated state blob.

### 5.6 Prefer data for 80–90% of content

Most coins, upgrades, and boss effects should be definable using declarative Lua tables.

Only rare effects should need custom Lua callbacks.

### 5.7 Instrumentation is a feature, not an afterthought

Because the game depends on tuning, visibility into resolution must exist from the beginning.

### 5.8 Centralized base constants

Core numeric defaults should live in one central or semi-central configuration layer.

Examples:

- normal round count
- boss round count
- starting coin slots
- flips per stage
- shop offer count
- base head/tail weights
- starter collection size

Modifiers should act on top of these values rather than replacing the need for a base configuration source.

No system should hardcode scattered literals like `3 rounds`, `3 slots`, or `3 offers` when those values are meant to be tunable.

---

## 6. Recommended project structure

Suggested initial folder layout:

```text
.
├── conf.lua
├── main.lua
├── docs/
│   └── love2d-implementation-plan.md
└── src/
    ├── app/
    │   ├── game.lua
    │   ├── config.lua
    │   ├── state_graph.lua
    │   └── step_builder.lua
    ├── core/
    │   ├── rng.lua
    │   ├── log.lua
    │   ├── hook_registry.lua
    │   ├── action_queue.lua
    │   ├── validator.lua
    │   └── utils.lua
    ├── content/
    │   ├── coins.lua
    │   ├── upgrades.lua
    │   ├── bosses.lua
    │   ├── stages.lua
    │   ├── shop.lua
    │   └── meta_upgrades.lua
    ├── domain/
    │   ├── run_state.lua
    │   ├── meta_state.lua
    │   ├── stage_state.lua
    │   ├── flip_batch.lua
    │   ├── score_breakdown.lua
    │   └── loadout.lua
    ├── systems/
    │   ├── run_initializer.lua
    │   ├── loadout_system.lua
    │   ├── flip_resolver.lua
    │   ├── scoring_system.lua
    │   ├── shop_system.lua
    │   ├── progression_system.lua
    │   ├── boss_system.lua
    │   └── summary_system.lua
    ├── states/
    │   ├── menu_state.lua
    │   ├── loadout_state.lua
    │   ├── stage_state.lua
    │   ├── result_state.lua
    │   ├── shop_state.lua
    │   ├── summary_state.lua
    │   └── meta_state.lua
    └── ui/
        ├── theme.lua
        ├── layout.lua
        ├── button.lua
        ├── panel.lua
        └── debug_overlay.lua
```

This is deliberately modular.

The main rule is:

- `content/` describes game content
- `domain/` describes runtime data shapes
- `systems/` contain logic
- `states/` control screen behavior
- `core/` contains engine utilities and infrastructure

### 6.1 Central constants / config layer

The existing `src/app/config.lua` should act as the first authoritative home for base constants.

If it grows too large later, it can be split into multiple files, but there should still be one clear import surface for the rest of the game.

Recommended shape:

```lua
GameConfig = {
  run = {
    normalRoundCount = 3,
    bossRoundCount = 1,
    startingCoinSlots = 3,
    startingFlipsPerStage = 3,
    startingCollectionSize = 5,
  },

  shop = {
    offerCount = 3,
    guaranteedCoinOffers = 1,
    guaranteedUpgradeOffers = 1,
  },

  flip = {
    baseHeadsWeight = 0.5,
    baseTailsWeight = 0.5,
    orderMode = "unordered", -- unordered for MVP, can later become slot_order or rule_defined
  },

  scoring = {
    clearOnThresholdAtBatchEnd = true,
  },
}
```

Rules for usage:

- systems read base values from config instead of embedding literals
- stage/boss definitions may override or extend base values
- run/meta/batch modifiers operate on derived effective values, not by mutating config tables directly

### 6.2 Effective value resolution

Many tunable values should be resolved through a small helper layer rather than read raw from config every time.

Recommended precedence:

1. base config constant
2. stage definition override
3. boss/stage modifier override
4. meta projection modifier
5. run upgrade modifier
6. temporary batch modifier
7. clamp/final normalization

Examples of values that should support this pattern:

- flips per stage
- max active coin slots
- shop point gain multiplier
- per-coin base weights
- shop offer count
- round count / boss placement rules

---

## 7. Core runtime data model

The data model must separate concerns cleanly.

## 7.1 RunState

Represents all state that persists during a single run.

Suggested shape:

```lua
RunState = {
  seed = 0,
  roundIndex = 1,
  currentStageId = nil,
  runStatus = "active", -- active | won | lost

  collectionCoinIds = {},
  equippedCoinSlots = {}, -- slot-preserving storage; current rules may still treat this as unordered
  persistedLoadoutSlots = {}, -- preselected build shown on future loadout screens
  ownedUpgradeIds = {},

  maxActiveCoinSlots = 3,
  baseFlipsPerStage = 3,

  shopPoints = 0,
  runTotalScore = 0,

  history = {
    stageResults = {},
    purchases = {},
    flipBatches = {},
  },

  counters = {
    totalFlips = 0,
    totalMatches = 0,
    totalMisses = 0,
    headsCalls = 0,
    tailsCalls = 0,
  },

  flags = {},
  temporaryRunEffects = {},
}
```

## 7.2 StageState

Represents state that exists only for the current stage.

```lua
StageState = {
  stageId = nil,
  stageType = "normal", -- normal | boss
  targetScore = 0,
  stageScore = 0,
  flipsRemaining = 3,
  stageStatus = "active", -- active | cleared | failed

  activeBossModifierIds = {},
  activeStageModifierIds = {},

  batchIndex = 0,
  streak = {
    consecutiveHeadsCalls = 0,
    consecutiveTailsCalls = 0,
    consecutiveMatches = 0,
    consecutiveMisses = 0,
  },

  lastCall = nil,
  lastBatchResults = nil,
  flags = {},
}
```

## 7.3 MetaState

Represents persistent progression across multiple runs.

```lua
MetaState = {
  unlockedCoinIds = {},
  unlockedUpgradeIds = {},
  purchasedMetaUpgradeIds = {},

  modifiers = {
    shopPointMultiplier = 1.0,
    bonusStartingCoins = 0,
    bonusCoinSlots = 0,
    bonusRerolls = 0,
  },

  stats = {
    runsStarted = 0,
    runsWon = 0,
    bestRunScore = 0,
    bossesDefeated = 0,
  }
}
```

Even if meta progression is minimal in the first implementation, the boundary should exist immediately.

## 7.4 FlipBatch

Represents one player action during a stage.

```lua
FlipBatch = {
  batchId = 0,
  call = "heads", -- heads | tails
  equippedCoinSlots = {},
  resolutionCoinIds = {}, -- actual order used for this ruleset's batch evaluation
  resolvedCoinResults = {},
  actions = {},
  trace = {},
  scoreBreakdown = nil,
}
```

## 7.5 ScoreBreakdown

Used for UI, debugging, and balance analysis.

```lua
ScoreBreakdown = {
  baseScore = 0,
  additiveBonuses = {},
  multipliers = {},
  conversions = {},
  shopPointChanges = {},
  perCoin = {},
  totalStageScoreDelta = 0,
  totalRunScoreDelta = 0,
  totalShopPointDelta = 0,
}
```

---

## 8. Content definition strategy

The project should be **data-driven first**.

Most content should be defined using Lua tables that describe:

- identity
- rarity
- tags
- hook triggers
- conditions
- effects/actions
- optional custom behavior hooks

### 8.1 Coin definition shape

Example schema:

```lua
{
  id = "tails_chaser",
  name = "Tails Chaser",
  rarity = "common",
  description = "+2 stage score when this coin matches a Tails call.",
  tags = { "tails", "match", "score" },
  triggers = {
    {
      hook = "after_coin_flip",
      condition = {
        call = "tails",
        result = "tails",
      },
      effects = {
        { op = "add_stage_score", amount = 2 },
        { op = "add_run_score", amount = 2 },
      }
    }
  }
}
```

### 8.2 Upgrade definition shape

```lua
{
  id = "weighted_tail_coating",
  name = "Weighted Tail Coating",
  rarity = "uncommon",
  description = "Your equipped coins gain +0.15 Tails weight.",
  tags = { "tails", "weight" },
  triggers = {
    {
      hook = "before_coin_roll",
      effects = {
        { op = "modify_coin_weight", side = "tails", amount = 0.15 }
      }
    }
  }
}
```

### 8.3 Boss definition shape

```lua
{
  id = "anti_streak_warden",
  name = "Anti-Streak Warden",
  description = "Repeated calls score less each batch.",
  tags = { "boss", "anti_streak" },
  triggers = {
    {
      hook = "before_scoring",
      condition = {
        repeated_call = true,
      },
      effects = {
        { op = "apply_score_multiplier", value = 0.8 }
      }
    }
  }
}
```

### 8.4 Meta upgrade definition shape

```lua
{
  id = "meta_shop_efficiency_1",
  name = "Merchant's Favor I",
  description = "+10% shop point gain in runs.",
  tags = { "meta", "economy" },
  runModifiers = {
    shopPointMultiplier = 1.10
  }
}
```

### 8.5 Custom callback escape hatch

Some content will eventually require more complex logic than declarative triggers can express.

Allow a controlled escape hatch:

```lua
customResolver = "content_callbacks.special_coin_xyz"
```

Rules for custom callbacks:

- they should receive a standard context object
- they should **return standardized actions**, not mutate global state directly
- they should be rare
- they should be logged in trace output

---

## 9. Hook-based gameplay engine

This is the central engine concept.

## 9.1 Why hooks are necessary

Hardcoded resolution is too brittle for this game because scoring may depend on multiple sources:

- coin intrinsic behavior
- run upgrade modifiers
- boss/stage rules
- future meta passives
- temporary flags/status effects

The clean solution is to define a set of **hook phases** and let active content respond during those phases.

## 9.2 Core engine model

The engine resolves one flip batch by:

1. creating a resolution context
2. collecting active hook sources
3. running hook phases in fixed order
4. collecting actions/effects produced by each phase
5. applying actions centrally
6. building a trace and score breakdown
7. checking for stage end after the full batch

## 9.3 Active hook sources

For each batch, the resolver collects hook sources from:

- equipped coins
- owned run upgrades
- active boss modifiers
- active stage modifiers
- run-level temporary effects
- meta modifiers that are allowed to influence runs

These sources are all treated through the same interface.

## 9.4 Mandatory hook phases

The first version should support the following hook phases:

1. `on_batch_start`
2. `before_batch_validation`
3. `before_coin_roll`
4. `after_coin_roll`
5. `before_scoring`
6. `after_scoring`
7. `before_stage_end_check`
8. `on_batch_end`

Optional later hook phases:

- `before_shop_generation`
- `after_purchase`
- `before_loadout_lock`
- `after_stage_clear`
- `before_summary`

## 9.5 Hook phase responsibilities

### `on_batch_start`

Purpose:

- initialize temporary context
- register tags/markers
- start trace output

Typical effects:

- set temporary flags
- mark this batch as “tails-focused”
- begin a one-batch multiplier chain

### `before_batch_validation`

Purpose:

- validate any special restrictions before rolling
- modify batch-level conditions

Typical effects:

- prevent certain coins under a boss rule
- inject a temporary penalty tag

### `before_coin_roll`

Purpose:

- modify per-coin odds
- add per-coin temporary weight modifiers

Typical effects:

- weighted coin upgrades
- bias heads/tails odds
- reduce effectiveness under boss rules

### `after_coin_roll`

Purpose:

- react to the actual coin result
- award preliminary outcomes

Typical effects:

- add score on match
- add shop points on miss
- convert result into secondary flags

### `before_scoring`

Purpose:

- aggregate raw score
- apply additive modifiers and multipliers

Typical effects:

- streak bonuses
- all-tails build bonus
- boss anti-repeat penalty

### `after_scoring`

Purpose:

- grant post-score rewards or chained effects

Typical effects:

- if score exceeded X, gain shop points
- if all coins matched, queue a bonus flag

### `before_stage_end_check`

Purpose:

- finalize batch state before checking clear/fail

Typical effects:

- one-time conversion before threshold evaluation
- end-of-batch cleanup

### `on_batch_end`

Purpose:

- finalize trace
- update non-critical bookkeeping

Typical effects:

- increment counters
- history logging
- analytics collection

---

## 10. Action/effect system

Hooks should not directly mutate the game state whenever possible.

Instead, they emit actions which are interpreted by the central resolver.

## 10.1 Why actions are important

Actions provide:

- deterministic ordering
- clear logs
- easier debugging
- easier testing
- reduced mutation chaos

## 10.2 Example action types

Initial required action set:

- `add_stage_score`
- `add_run_score`
- `add_shop_points`
- `modify_coin_weight`
- `apply_score_multiplier`
- `set_batch_flag`
- `set_stage_flag`
- `set_run_flag`
- `increment_streak`
- `reset_streak`
- `queue_trace_note`
- `grant_upgrade`
- `grant_coin`
- `increase_coin_slots`
- `set_flips_remaining`
- `consume_effect`

Potential later actions:

- `insert_step`
- `add_shop_offer`
- `reroll_shop`
- `prevent_purchase`
- `change_threshold`
- `spawn_special_event`

## 10.3 Action application rules

Action application should be centralized in something like:

```lua
ActionQueue.applyAll(runState, stageState, context, actionList)
```

This function is responsible for:

- validating action payloads
- applying state mutations in order
- updating score breakdown
- appending trace entries

No other system should casually bypass this unless absolutely necessary.

---

## 11. Resolution order and deterministic layering

Flexibility is only safe if ordering is explicit.

## 11.1 Stable ordering rules

Within a given hook phase, handlers should be sorted deterministically by:

1. `priorityLayer`
2. `sourceType`
3. `sourceId`

Recommended `sourceType` precedence:

1. boss modifier
2. stage modifier
3. meta modifier
4. run upgrade
5. equipped coin
6. temporary effect

This precedence can be tuned, but once chosen it should remain explicit.

## 11.2 Score assembly order

Recommended scoring order:

1. base per-coin score contributions
2. additive bonuses
3. score conversions / replacements
4. multiplicative effects
5. caps/floors if needed
6. side rewards (shop points, flags, etc.)

## 11.3 RNG order

The resolver must consume RNG in a consistent order.

Required rule:

- resolution order should come from a dedicated strategy function rather than ad hoc array order
- in MVP unordered mode, the strategy may return canonical sorted coin IDs
- if ordered mechanics are introduced later, the same strategy function can switch to slot order or another explicit rule

This ensures deterministic replay and prevents accidental logic changes from reordering arrays.

---

## 12. Canonical handling of coin sets

Because coin order does not matter in the MVP and duplicates are forbidden, loadouts and batch resolution need canonicalization.

However, canonicalization should be treated as a derived view, not the only representation.

The raw loadout should still preserve slot placement for future order-sensitive rules.

## 12.1 Loadout invariants

At all times:

- no duplicate coin IDs may exist in the equipped loadout
- equipped coin count must be `<= maxActiveCoinSlots`
- each equipped coin ID must exist in the player collection
- persisted loadout should be revalidated after shop purchases or other collection changes

### 12.1.1 Representation recommendation

Use slot-preserving storage such as:

```lua
equippedCoinSlots = { "coin_a", "coin_b", "coin_c" }
```

Then derive:

- `canonicalLoadoutKey` for unordered logic
- `resolutionCoinIds` for the current rule set
- `displayLoadout` for UI

## 12.2 Canonical loadout key

Add a utility that converts any equipped set into a canonical key:

```lua
"coin_a|coin_b|coin_c"
```

Where IDs are sorted alphabetically.

Uses:

- caching combo evaluations
- comparing loadouts
- debugging
- analytics

### 12.3 Persisted build / current build behavior

The game should remember the last committed loadout and show it back to the player on the next loadout selection screen.

Behavior rules:

- when a stage begins, the committed loadout is copied into `persistedLoadoutSlots`
- after the shop, the next loadout screen opens with that build already selected where possible
- if a persisted slot becomes invalid in the future, the UI should mark or clear that slot gracefully
- the player can confirm the same build quickly or edit it before locking the next stage

This should be treated as part of quality-of-life, not as a visual-only feature.

---

## 13. Macro game flow as a state graph

The outer run progression should be modeled as a graph of steps/states.

## 13.1 Initial state graph

```text
Boot
  -> Menu
  -> Meta (future/optional)
  -> StartRun
  -> LoadoutSelection (pre-populated from persisted/current build)
  -> Stage
  -> Result
      -> if failed: Summary
      -> if cleared and boss: Summary
      -> if cleared and not boss: Shop
  -> Shop
  -> LoadoutSelection (pre-populated from persisted/current build)
  -> Stage
  -> ...
```

## 13.2 Why a state graph instead of rigid transition branches

Later features may insert extra states based on conditions:

- bonus event after a win
- special relic choice after a boss
- reward preview before shop
- pre-boss warning screen
- post-stage analytics/debug screen in development builds

This is easier if transitions are constructed by a `StepBuilder` rather than buried in individual screen code.

## 13.3 Recommended step builder concept

Pseudo-flow:

```lua
local nextSteps = StepBuilder.buildNextSteps(currentContext)
```

The step builder can inspect:

- stage result
- round index
- boss flag
- development/debug flags
- active modifiers that insert extra steps

And return a step sequence.

This is the macro equivalent of the hook engine.

---

## 14. Detailed flip batch resolution plan

This section defines the exact intended sequence for one player flip.

## 14.1 Resolution input

Inputs:

- `runState`
- `stageState`
- `metaState` (or projected meta run modifiers)
- player call (`heads` or `tails`)
- equipped loadout
- deterministic RNG instance

## 14.2 Resolution pipeline

### Phase 0 — create context

Build a `ResolutionContext` object:

```lua
ResolutionContext = {
  batchId = stageState.batchIndex + 1,
  call = "heads",
  activeSources = {},
  perCoin = {},
  batchFlags = {},
  scoreBreakdown = ScoreBreakdown.new(),
  pendingActions = {},
  trace = {},
  rng = rng,
}
```

### Phase 1 — collect active hook sources

Gather active definitions from:

- equipped coins
- run upgrades
- active boss modifier
- active stage modifiers
- applicable meta passives

### Phase 2 — `on_batch_start`

All sources may initialize context or flags.

### Phase 3 — validate batch invariants

Check:

- call is valid
- loadout size is valid
- no duplicates
- every equipped coin exists in collection
- stage is active
- flips remain

### Phase 4 — `before_batch_validation`

Allow sources to inject temporary conditions.

### Phase 5 — prepare coin roll state

For each equipped coin in the selected resolution order:

- initialize base weights, e.g. `heads = 0.5`, `tails = 0.5`
- attach temporary modifiers container

### Phase 6 — `before_coin_roll`

Hook sources may change:

- heads weight
- tails weight
- tags
- per-coin flags

Normalize / clamp as required.

### Phase 7 — roll outcomes

For each equipped coin in the selected resolution order:

1. compute final weight distribution
2. consume RNG once
3. resolve `heads` or `tails`
4. record raw roll details in trace

### Phase 8 — `after_coin_roll`

Evaluate reactions to actual results.

Typical effects:

- match score
- miss score
- economy rewards
- streak tracking

### Phase 9 — `before_scoring`

Aggregate raw score contributions and modifiers.

### Phase 10 — apply scoring actions

Translate aggregate results into actions:

- `add_stage_score`
- `add_run_score`
- `add_shop_points`

### Phase 11 — `after_scoring`

Resolve post-score rewards and chained effects.

### Phase 12 — finalize streaks and counters

Update:

- flip counters
- streak state
- call counters
- match/miss counters

### Phase 13 — `before_stage_end_check`

Allow final threshold-related conversions.

### Phase 14 — stage end evaluation

If `stageScore >= targetScore`, mark stage cleared.

Else if `flipsRemaining == 0`, mark stage failed.

Else continue.

Important: `flipsRemaining` should decrement for the completed batch before failure is evaluated.

### Phase 15 — `on_batch_end`

Finalize batch trace/history.

### Phase 16 — return batch result

Return a structured object containing:

- per-coin results
- score breakdown
- updated stage summary
- trace
- clear/fail/continue status

---

## 15. Suggested function contracts

These interfaces should be stabilized early.

## 15.1 Flip resolver

```lua
FlipResolver.resolveBatch(runState, stageState, metaProjection, call, rng)
  -> batchResult
```

## 15.2 Hook collection

```lua
HookRegistry.collectSources(runState, stageState, metaProjection)
  -> sourceList
```

## 15.3 Hook execution

```lua
HookRegistry.runPhase(phaseName, sourceList, context)
  -> actionList
```

## 15.4 Action application

```lua
ActionQueue.applyAll(runState, stageState, context, actionList)
  -> nil
```

## 15.5 Validation

```lua
Validator.validateLoadout(runState)
Validator.reconcilePersistedLoadout(runState)
Validator.validateBatchInput(runState, stageState, call)
Validator.validateContentDefinition(definition)
```

## 15.6 Config / effective values

```lua
GameConfig.get(path)
RulesResolver.getEffectiveValue(path, runState, stageState, context)
LoadoutSystem.getResolutionOrder(runState, stageState, context)
```

## 15.7 Shop generation

```lua
ShopSystem.generateOffers(runState, stageState, metaProjection, rng)
  -> offers
```

## 15.8 Step graph

```lua
StateGraph.transition(currentStateName, transitionPayload)
  -> nextStateName

StepBuilder.buildNextSteps(runState, stageState, transitionPayload)
  -> stepList
```

---

## 16. Loadout selection system

Because loadout matters per stage, this must be a first-class system.

## 16.1 Responsibilities

The loadout system should:

- present the player collection
- present the currently persisted build as the default selection
- enforce slot caps
- prevent duplicates
- allow equipping/unequipping before stage start
- lock the loadout when the stage begins

## 16.2 Runtime rule

Once a stage starts, equipped coins are frozen for that stage unless an effect explicitly says otherwise.

This avoids mid-stage loadout exploits.

When the stage is committed, the chosen slot layout should be saved as the persisted/current build for the next loadout screen.

## 16.3 Early content recommendation

Start the player with more coins in the collection than active slots.

Recommended initial collection size:

- 4 or 5 coins owned
- 3 active slots

This ensures the loadout system matters immediately.

---

## 17. Shop system plan

The shop is a key build-shaping layer.

## 17.1 Shop goals

The shop should:

- present meaningful choices
- reinforce build direction
- occasionally offer pivot opportunities
- avoid dead shops as much as possible

## 17.2 Recommended MVP rules

- 3 offers per shop
- guarantee at least:
  - 1 coin offer
  - 1 upgrade offer
- no duplicates among current offers
- optionally prevent offering already owned coins/upgrades if uniqueness is global

## 17.3 Offer structure

```lua
ShopOffer = {
  id = "offer_001",
  type = "coin", -- coin | upgrade
  contentId = "tails_chaser",
  price = 4,
  rarity = "common",
}
```

## 17.4 Shop generation hooks

Eventually the shop can also use hook phases, for example:

- `before_shop_generation`
- `after_shop_generation`
- `before_purchase`
- `after_purchase`

This allows boss rewards, meta bonuses, or relics to influence the shop without hardcoding branches.

---

## 18. Boss modifier system

Bosses should function as rule modifiers, not just score checks.

## 18.1 Boss design principle

A boss should stress the player’s build in a way that changes decision-making.

Examples:

- repeated calls are penalized
- weighting effects are partially weakened
- first successful match per batch scores less
- all miss rewards are disabled
- tails-focused scoring is reduced, forcing adaptation

## 18.2 Technical integration

Bosses should use the same trigger model as other content.

That means a boss is just another source of hooks in the resolution engine.

This is important because it keeps the system uniform.

---

## 19. Persistent / meta progression plan

Even if the first playable prototype only uses a very small meta layer, the architecture should support it cleanly.

## 19.1 Meta upgrade examples

- `+10% shop point generation`
- `+1 starting shop point`
- `+1 max active coin slot`
- `+1 starting coin choice`
- improved rarity odds in shops

## 19.2 Integration rule

Meta progression should not freely mutate run state from everywhere.

Instead, when a run starts:

1. `MetaState` is read
2. a **meta projection** / run modifier package is created
3. that projection becomes one of the active source groups for the run

This keeps boundaries clean.

---

## 20. UI / UX scaffolding plan

This prototype does not need final art, but the UI must communicate complex resolution clearly.

## 20.1 Minimum required screens

1. Menu
2. Loadout Selection
3. Stage Screen
4. Result Screen
5. Shop Screen
6. Summary Screen

## 20.2 Loadout selection screen requirements

The loadout selection screen should show at minimum:

- current round / upcoming stage label
- active slot count and maximum slot count
- player collection
- currently persisted build / current build panel
- preselected slots based on the last committed build
- clear indication of invalid or empty slots
- confirm/lock button for stage start

If the player makes no changes, they should still be able to continue quickly with the previously committed build.

## 20.3 Stage screen requirements

The stage screen should show at minimum:

- current round / stage label
- target score
- current stage score
- flips remaining
- shop points
- equipped coins
- active upgrades
- active boss/stage modifiers
- current call selection (heads/tails)
- flip button
- last batch result summary
- expandable or visible score breakdown

## 20.4 Debug overlay requirements

Debug information is essential.

The debug overlay should optionally show:

- seed
- batch index
- raw RNG roll per coin
- final coin weights per coin
- per-coin result
- triggered hook sources
- emitted actions
- stage end evaluation

This overlay should be available via a dev toggle.

---

## 21. Validation and guardrails

Because the engine is flexible, guardrails are essential.

## 21.1 Content validation

At startup, validate all content definitions:

- required fields exist
- IDs are unique
- trigger phases are valid
- action payloads match schemas
- references point to existing content

Fail loudly in development.

## 21.2 Runtime validation

Before each batch:

- stage is active
- flips remain
- loadout is valid
- no duplicates
- equipped coins exist in collection

## 21.3 Action safety

Action payloads should be validated before application.

For example:

- no unknown `op`
- numeric fields must be numbers
- clamped weights must remain valid
- no negative slot counts

## 21.4 Loop protection

If hooks can queue follow-up actions, guard against infinite trigger loops:

- max action count per batch
- max recursion/chain depth
- trace warning when limits are hit

---

## 22. Logging, tracing, and analytics

This system needs high observability.

## 22.1 Per-batch trace

Each flip batch should generate a structured trace.

Suggested trace fields:

```lua
{
  batchId = 3,
  call = "tails",
  coinRolls = {
    {
      coinId = "tails_chaser",
      headsWeight = 0.25,
      tailsWeight = 0.75,
      rngRoll = 0.61,
      result = "tails",
    }
  },
  triggeredSources = {},
  actions = {},
  scoreBreakdown = {},
  stageStatusAfter = "active",
}
```

## 22.2 Console/dev logging

Useful human-readable log line example:

```text
R2 B3 | call=T | coin=tails_chaser roll=.61 odds H25/T75 => T | +2 stage | +2 run | stage 7/8
```

## 22.3 Balancing counters

Track metrics like:

- average stage score per batch
- pass/fail rate per stage
- call distribution
- heads/tails outcome distribution
- shop offer frequency
- win rate by coin or upgrade

These can start as debug-only stats.

---

## 23. Minimal content plan for the first implementation

The first implementation should keep content intentionally small.

## 23.1 Suggested starter content count

- 5 starter coins in collection pool
- 6 to 8 total coin definitions
- 6 to 10 run upgrades
- 3 regular stages
- 1 boss stage
- 1 boss modifier definition
- 2 to 4 meta upgrades scaffolded

## 23.2 Content archetype coverage

Ensure at least one example of each:

- simple match scorer
- tails-focused scorer
- heads-focused scorer
- weighted odds modifier
- economy generator
- streak synergy
- boss counter or anti-boss support

---

## 24. Suggested implementation roadmap

Implementation should happen in controlled stages.

## Phase 1 — project bootstrap

Deliverables:

- `main.lua`
- `conf.lua`
- folder scaffolding
- basic Love2D app loop
- central config/constants module
- lightweight state manager / state graph shell
- debug logger

Success criteria:

- app boots
- menu screen renders
- state transitions work
- systems can read tunable base values from one config source

## Phase 2 — core domain scaffolding

Deliverables:

- `RunState`
- `StageState`
- `MetaState`
- persisted/current build fields
- content registries
- validators

Success criteria:

- run can be initialized from data
- stage can be initialized cleanly
- content loads without errors
- default loadout can be persisted and restored into the loadout screen model

## Phase 3 — hook engine skeleton

Deliverables:

- hook registry
- hook phases enum/list
- source collection logic
- action queue / action interpreter

Success criteria:

- sources can register hook triggers
- a phase run emits actions
- actions apply in deterministic order

## Phase 4 — flip resolution MVP

Deliverables:

- flip batch resolver
- deterministic RNG wrapper
- per-coin roll resolution
- stage score / run total score updates
- stage clear/fail logic

Success criteria:

- player can choose heads/tails
- equipped coins resolve as a batch
- full batch resolves before stage clear check
- exact-threshold success works as intended

## Phase 5 — stage screen and debug overlay

Deliverables:

- stage UI
- call selection controls
- flip button
- last-result summary
- debug overlay

Success criteria:

- stage is playable end-to-end
- resolution is legible
- debug info is visible

## Phase 6 — loadout selection

Deliverables:

- loadout screen
- equip/unequip behavior
- slot validation
- loadout lock on stage start
- persisted/current build preselection

Success criteria:

- player can choose up to 3 coins from collection
- duplicates are prevented
- stage starts with locked loadout
- previous build is shown by default on the next loadout screen

## Phase 7 — shop system

Deliverables:

- shop screen
- offer generation
- purchase logic
- collection/upgrades update from purchases

Success criteria:

- player receives offers after clear
- purchases persist into the next stage
- shop points are spent correctly

## Phase 8 — boss rules

Deliverables:

- boss stage definition
- boss modifier hook source
- boss UI messaging

Success criteria:

- round 4 behaves differently from normal rounds
- boss rule affects resolution through the same hook engine

## Phase 9 — meta progression scaffold

Deliverables:

- meta state storage
- meta upgrade definitions
- run start projection from meta

Success criteria:

- meta modifiers can alter run setup cleanly
- architecture supports persistent progression without hacks

## Phase 10 — balancing and polish

Deliverables:

- tune thresholds
- tune weights and prices
- adjust content
- add basic juice (sound, visual feedback, simple animation)

Success criteria:

- game feels testable as a build system, not pure randomness

---

## 25. Testing strategy

Testing should combine manual playtesting and logic-level verification.

## 25.1 Highest-risk areas

- score resolution correctness
- weight modification correctness
- deterministic action ordering
- stage clear timing
- loadout validation
- persisted/current build reconciliation
- shop persistence
- boss modifier interaction with normal scoring

## 25.2 Manual test checklist

Required manual tests:

1. choose heads and flip with one coin
2. choose tails and flip with multiple coins
3. verify weights change when an upgrade is active
4. verify all equipped coins resolve before stage clear
5. verify exact threshold succeeds
6. verify stage fails when flips run out below threshold
7. verify loadout cannot exceed slot count
8. verify duplicate equip is impossible
9. verify previous loadout is preselected on the next loadout screen
10. verify shop purchase persists to next loadout screen
11. verify boss modifier changes resolution behavior

## 25.3 Debug controls recommended early

Development controls should include:

- force next coin result to heads/tails
- grant shop points
- grant upgrade
- jump to boss round
- simulate multiple flips quickly
- print full batch trace

---

## 26. Risk register

## 26.1 Biggest architecture risks

### Risk: overengineering too early

Mitigation:

- build a small, explicit hook set first
- avoid a fully generic scripting system
- add only the phases actually needed

### Risk: hidden interactions between modifiers

Mitigation:

- deterministic ordering
- trace every triggered source
- central action application

### Risk: content too hard to balance

Mitigation:

- keep content count low initially
- add debugging metrics early
- separate score breakdown into visible components

### Risk: state graph becomes messy

Mitigation:

- centralize transition construction in `StepBuilder`
- do not let screens invent arbitrary hidden transitions

### Risk: run/meta state bleed

Mitigation:

- preserve strict boundary between `RunState` and `MetaState`
- apply meta only through explicit projection/setup

---

## 27. Non-negotiable invariants

These invariants must remain true unless the design intentionally changes.

1. No duplicate equipped coins.
2. MVP rules treat equipped coin order as order-insensitive, but slot order is still preserved in data.
3. All equipped coins resolve during a batch.
4. Stage clear is checked only after the full batch resolves.
5. Run upgrades persist through the run.
6. Meta upgrades are stored separately from run upgrades.
7. Same seed + same state + same inputs produce the same outcome.
8. State mutation during resolution flows through standardized action application.
9. Content definitions are validated before gameplay starts.
10. Debug/trace visibility exists for batch resolution.
11. Tunable base values come from central configuration, not scattered literals.

---

## 28. Example pseudocode for the final desired resolver

```lua
function FlipResolver.resolveBatch(runState, stageState, metaProjection, call, rng)
  Validator.validateBatchInput(runState, stageState, call)

  local context = ResolutionContext.new(runState, stageState, metaProjection, call, rng)
  local sources = HookRegistry.collectSources(runState, stageState, metaProjection)

  local function runPhase(phaseName)
    local actions = HookRegistry.runPhase(phaseName, sources, context)
    ActionQueue.applyAll(runState, stageState, context, actions)
  end

  runPhase("on_batch_start")
  runPhase("before_batch_validation")

  context.perCoin = FlipResolver.prepareCoinRollState(runState, stageState, context)

  runPhase("before_coin_roll")

  for _, coinRollState in ipairs(context.perCoin) do
    FlipResolver.resolveCoinOutcome(coinRollState, context)
  end

  runPhase("after_coin_roll")
  runPhase("before_scoring")

  local scoringActions = ScoringSystem.buildScoreActions(context)
  ActionQueue.applyAll(runState, stageState, context, scoringActions)

  runPhase("after_scoring")

  FlipResolver.updateCounters(runState, stageState, context)

  runPhase("before_stage_end_check")

  FlipResolver.evaluateStageEnd(runState, stageState, context)

  runPhase("on_batch_end")

  return FlipResolver.buildBatchResult(runState, stageState, context)
end
```

This pseudocode captures the central intended shape of the project.

---

## 29. Immediate next implementation task after this document

Once this plan is accepted, the next step should be:

1. scaffold the file structure
2. create the base Love2D app boot flow
3. implement state graph shell
4. implement the domain state modules
5. implement the hook registry and action queue before any real gameplay content

Do **not** jump directly into coin-specific logic before the engine skeleton exists.

The engine foundation is what guarantees flexibility later.

---

## 30. Final guidance

This prototype should be built with the mindset that game rules will move.

That does **not** mean every part of the code should be dynamic.

The correct balance is:

- fixed, explicit structure for engine phases and data ownership
- flexible, data-driven content and modifier behavior

If this balance is maintained, the game will be easy to extend, easy to debug, and easy to tune.

If this balance is lost, the prototype will quickly become brittle.

This document should remain the reference point during implementation.
