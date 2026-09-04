# Tricks Redesign Implementation Plan

> Historical migration plan (superseded): continue to use this document for
> background on the already-landed terminology, coin-instance, action, and
> family work. The next implementation target is
> `../family-trigger-engine-implementation.md`; where the plans conflict, the
> family-trigger plan wins.

This plan records the migration path from the current coin-special-effect / Chips / upgrades implementation toward the revised Trick-centered game defined in `docs/game/`.

The goal is not a rewrite. The goal is to keep the game runnable while moving terminology, content, flow, and engine support in the dependency order required by the new design.

## Source Documents

- `docs/game/game-document.md` is the canonical current game design.
- `docs/game/coin.md` defines canonical coin archetypes, material expectations, and coin-field requirements.
- `docs/game/trick.md` defines Trick families, timing, scope limits, examples, and family boundaries.
- `docs/game/mechanics-vocabulary.md` defines canonical timing windows, action names, requirements, target rules, and deterministic limits.
- `docs/better-game-philosophy-ideas.md`, `docs/better-coin-design.md`, and `docs/better-mechanics-ideas.md` are supporting source notes.
- `docs/ideas.md` is historical/future-facing context and is overridden by the canonical `docs/game/*` documents when they conflict.

Older docs and current code still use legacy terms such as upgrades, chips, shop points, score targets, damage, active coin slots, and Heads/Tails coin identities. Those terms are migration leftovers unless explicitly preserved by the canonical design or retained temporarily as internal compatibility fields.

## Confirmed Direction

- **Tricks** are the canonical rules, UI, reward, and content term for run-only skills.
- **Scam** is flavour only, not a core mechanical term.
- **Influence** is the in-run currency, replacing chips, dollars, shop points, and similar temporary currencies.
- **HP** is the enemy win-condition value.
- **Score** is temporary flip output applied against enemy HP.
- **Coins** are simple archetypal build pieces bought, upgraded, removed, and refined through the Black Market.
- **Pouch** is the player's run coin pool.
- **Black Market** primarily handles coins and other run objects.
- **Defeated opponents** primarily offer Tricks.
- **Reputation** is persistent meta currency awarded after runs.
- **Tattoos** replace persistent upgrades as meta progression.
- Tricks should usually resolve automatically. Any move, swap, replacement, copy, redirect, smuggle, replay, or Momentum effect needs an explicit automatic target rule and deterministic cap.

## Current Implementation Baseline

The current codebase already has useful foundations, but they are mostly legacy-named:

- `src/systems/purse_system.lua` has real coin instances and stage zones: available, hand, exhausted.
- `src/systems/flip_resolver.lua` resolves the current batch loop: draw hand, run hooks, roll every hand coin, score, apply luck, check stage end, exhaust hand.
- `src/systems/scoring_system.lua` calculates aggregate scoring. It does not yet emit true per-coin score events.
- `src/core/hook_registry.lua` and `src/core/action_queue.lua` provide the existing hook/action substrate.
- `src/systems/luck_system.lua` has a Luck Meter and Fated Flip state.
- `src/systems/reward_system.lua` offers mixed coin/upgrade rewards.
- `src/systems/shop_system.lua` sells coins and upgrades using `shopPoints`.
- `src/content/coins.lua` still contains bespoke effect coins such as Heads/Tails-weighted and economy coins.
- `src/content/upgrades.lua` still contains legacy run upgrades that can become the first internal Trick substrate.
- `src/content/meta_upgrades.lua` still contains persistent upgrades that should later become Tattoos.

Current high-risk mismatches:

1. Player-facing terms still say Chips, Shop, Upgrades, Damage, Meta Upgrades, and active coin slots.
2. Internal fields such as `shopPoints`, `ownedUpgradeIds`, `stageScore`, `targetScore`, `equippedCoinSlots`, and `persistedLoadoutSlots` are broad compatibility roots.
3. Current coins are effect-heavy identities instead of simple archetypes.
4. Current hand is also the flip board: draw hand, arrange, call, flip all hand coins, exhaust all.
5. The target flow needs deal N, select M, arrange selected, call, optional Smuggling, flip board, resolve Tricks, score HP, refill.
6. Current manual pre-flip Sleight of Hand conflicts with the new automatic post-result Sleight of Hand family.
7. Current Fated Flip forces coin results to match the call; the revised Fate boundary says Fate should be a Luck Meter / Fated Flip payoff layer and should not target individual coin odds/results.
8. Current scoring is aggregate, blocking Heavy Payout as a true weighted-coin payoff, score-credit redirects, Forgery payout copies, Prestige Outcome replay, and Momentum payoffs.

## Migration Principles

1. Do not rewrite the whole game at once.
2. Preserve a runnable build after every phase.
3. Migrate player-facing terminology and content before deep engine rewrites.
4. Keep legacy internal field names until behavior, save compatibility, replay, and fixtures are stable.
5. Add only the engine operations needed by the current Trick slice.
6. Prefer canonical action names from `docs/game/mechanics-vocabulary.md`, but allow narrow aliases to existing internal operations during migration.
7. Defer recursive Momentum, copied-trigger, target-rerouting, board-overload, Fated Flip chaining, Prestige replay, and per-coin scoring mechanics until their prerequisites exist.
8. Treat unsupported design ideas as explicit deferred work instead of implying they are implemented.
9. Run targeted verification after each phase and the full verification set before merging a phase.

## Phase 0: Documentation and Status Baseline

Goal: keep a single current design reference and record the real code constraints before implementation starts.

Likely files:

- `docs/game/game-document.md`
- `docs/game/implementation-plan.md`
- `docs/game/coin.md`
- `docs/game/trick.md`
- `docs/game/mechanics-vocabulary.md`

Tasks:

- Treat `docs/game/game-document.md` as canonical.
- Keep this file as the technical migration plan.
- Record known mismatches between the docs and current code before changing implementation.
- Keep open questions visible instead of guessing them in code.
- Explicitly mark deep mechanics as deferred until their prerequisites exist.

Exit criteria:

- Canonical terms are consistent across the plan: Charm, Trick, Influence, HP, Score, Coin, Pouch, Black Market, Spoils, Seize, Crumbles, Reputation, Tattoo.
- Current implementation constraints are listed.
- The first code implementation slice can be chosen without re-reading all source notes.

Baseline verification:

```sh
lua scripts/engine_fixture_verify.lua
lua scripts/invariant_verify.lua
lua scripts/replay_verify.lua
lua scripts/artifact_verify.lua
```

Optional balance sanity only when tuning changed:

```sh
lua scripts/simulate.lua
```

## Phase 1: Player-Facing Terminology Layer

Goal: make the game speak the revised design language without risky internal renames.

This phase is display/copy migration only. Do not rename broad internal fields yet.

Likely files:

- `src/content/terminology.lua`
- `src/states/stage_state.lua`
- `src/states/shop_state.lua`
- `src/states/meta_state.lua`
- `src/states/help_state.lua`
- `src/states/result_state.lua`
- `src/states/summary_state.lua`
- `src/states/collection_state.lua`
- content descriptions in `src/content/*`

Required display mapping:

- Chips / shop points -> **Influence**
- Shop -> **Black Market**
- Run upgrades -> **Tricks**
- Meta points -> **Reputation**
- Meta upgrades -> **Tattoos**
- Damage / score-target copy -> **Score applied to HP**
- Active coin slot / equipped coin language -> **Pouch** or **flip slot**, depending context

Internal names intentionally kept for now:

- `shopPoints`
- `ownedUpgradeIds`
- `unlockedUpgradeIds`
- `stageScore`
- `targetScore`
- `equippedCoinSlots`
- `persistedLoadoutSlots`

Tasks:

- Update `src/content/terminology.lua` to prefer canonical terms.
- Route UI copy through terminology where practical.
- Update visible content descriptions that still say Chips, Shop, Upgrade, Damage, Meta Upgrade, or active coin slot.
- Add status notes where internal names intentionally lag behind player-facing terms.
- Do not change save/replay field names in this phase.

Exit criteria:

- Player-facing language uses Influence, Charms/Tricks, HP, Score, Pouch, Black Market, Spoils, Seize, Crumbles, Reputation, and Tattoos consistently.
- Remaining legacy terms are internal compatibility fields, fixture names, archived docs, or explicit status notes.
- Existing saves, replay fixtures, and artifact checks still pass.

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:shop
lua scripts/artifact_verify.lua
lua scripts/invariant_verify.lua 5 1001 1
```

Search check:

```sh
rg -n "Chip|Chips|Shop|shop points|Upgrade|upgrades|Damage|active coin slot|Purse" src/content src/states src/ui scripts/fixtures
```

## Phase 2: Coin Archetype and Starter Pouch Migration

Goal: replace bespoke special-effect coins with simple readable archetype coins.

Likely files:

- `src/content/coins.lua`
- `src/systems/run_initializer.lua`
- `src/content/coin_detail_content.lua`
- `src/ui/coin_art.lua`
- shop/reward filters that assume old coin IDs
- fixtures that reference old starter/effect coin IDs

Initial canonical archetypes:

- **Bent Coin**: Prestige synergy
- **Flywheel Coin**: Momentum / In Motion synergy
- **Blank Coin**: Forgery synergy
- **Vanishing Coin**: Sleight of Hand synergy
- **Hollow Coin**: Smuggling synergy
- **Marked Coin**: Prediction / Foretold synergy
- **Lucky Coin**: Fate / Luck Meter synergy
- **Weighted Coin**: Weighted / probability synergy

Recommended data direction:

```lua
id = "copper_weighted_coin"
name = "Weighted Coin"
archetype = "weighted"
material = "copper"
materialRank = 1
base_score = 1
tags = { "weighted", "weight", "odds", "reliable" }
mechanic_terms = { "Weighted", "Weight" }
trick_synergy = { "weighted" }
```

Tasks:

- Add explicit `archetype`, `material`, `base_score`, `material_variants`, `mechanic_terms`, and `trick_synergy` where active coin definitions need them.
- Start with Copper-material versions only unless Silver/Gold behavior is needed immediately.
- Replace the starter pouch contents with canonical archetype coins.
- Remove Heads/Tails-named identities from active starter content.
- Move old neighbor, score, economy, and manipulation complexity out of coins and toward Tricks over time.
- Update fixtures and deterministic replay expectations that reference removed legacy coin IDs.

Exit criteria:

- Starter pouch represents the new archetype model.
- Active coin identities are not named around Heads/Tails outcomes.
- Old special coins are removed, archived, or clearly marked legacy.
- Coin descriptions are readable as build pieces rather than full special-effect rules.
- Shop/reward generation does not offer removed legacy IDs.

Verification:

```sh
lua scripts/engine_fixture_verify.lua unordered_slot_identity_replay
lua scripts/engine_fixture_verify.lua batch_queue_effect_stage_clear
lua scripts/replay_verify.lua 5 1001 1
lua scripts/invariant_verify.lua 5 1001 1
```

Likely legacy IDs that need fixture migration:

- `heads_weighted_penny`
- `tails_weighted_penny`
- `regular_dollar`
- `heads_cache`
- `heads_anchor`
- `heads_varnish`
- `echo_cache`

## Phase 3: Trick Wrapper Around Current Upgrades

Goal: present current run upgrades as the first internal Trick substrate before adding deep Trick mechanics.

Likely files:

- `src/content/upgrades.lua`
- `src/core/hook_registry.lua`
- `src/core/action_queue.lua`
- `src/systems/reward_system.lua`
- reward/shop UI copy that displays upgrade offers

Approach:

- Keep `ownedUpgradeIds` and `unlockedUpgradeIds` internally.
- Display and describe those entries as run-only Tricks.
- Add Trick metadata while preserving compatibility with the existing hook/action system.
- Split content conversion from engine changes: first metadata/copy, then new behavior.

Recommended Trick metadata:

```lua
trick = {
  category = "weighted",
  tags = { "weighted", "weight" },
  tier = 1,
  timing = "before_flip",
  targetRule = "one_selected_weighted_coin_or_random_selected_coin",
  scope = { maxTriggersPerFlip = 1 }
}
```

Canonical categories/tags:

- `weighted`
- `prediction`
- `sleight`
- `forgery`
- `smuggle`
- `fate`
- `prestige`
- `momentum`

Tasks:

- Rewrite visible upgrade names/descriptions toward Trick fantasy.
- Add category/tier/tag metadata to early run-upgrade definitions.
- Keep old action ops where they already work.
- Update reward display to call these options Tricks even if `type = "upgrade"` remains internally.
- Avoid claiming unsupported advanced Trick families are implemented.

Exit criteria:

- The player can acquire run-only Tricks through the existing acquisition path.
- Current internal upgrade storage remains deterministic and replay-safe.
- Trick category metadata exists for future enemy class reward pools.

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:replay
lua scripts/replay_verify.lua 5 1001 1
lua scripts/invariant_verify.lua 5 1001 1
```

## Phase 4: MVP Weighted / Weight Engine Slice

Goal: add the smallest canonical engine operation support needed by early Weighted Tricks.

Likely files:

- `src/core/action_queue.lua`
- `src/core/hook_registry.lua`
- `src/content/upgrades.lua`
- `src/systems/flip_resolver.lua`
- engine fixtures under `scripts/fixtures/engine/`

Good first Tricks:

- **Weighted Palm**: before each selected Weighted Coin rolls, ensure at least a 75% Matching Call chance; Silver and Gold keep their stronger native odds. Matching Weighted Coins then receive their material payoff.
- **Headside Edge**: on Heads Flip, add Heads Chance to selected coins, doubled for Weighted Coins.
- **Tailside Edge**: on Tails Flip, add Tails Chance to a random selected Weighted Coin.

Do not implement true **Heavy Payout** until per-coin scoring support exists. If a temporary aggregate version exists, label it as temporary and do not let it block the later per-coin refactor.

First canonical action aliases:

- `add_weight`
- `set_call_match_chance`

Migration approach:

- Map `add_weight` narrowly to existing `modify_coin_weight` behavior where possible.
- Map `set_call_match_chance` narrowly to existing probability/weight support where possible.
- Keep `modify_coin_weight` compatibility until old content/fixtures are migrated.
- Trace canonical action names in logs where feasible.

Exit criteria:

- Early Weighted Tricks affect probability before results exist.
- Weighted Tricks do not repair failures after the flip.
- New Weight operations are deterministic and visible in traces/logs.
- Replay fails if weighted action metadata is tampered.

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:replay
lua scripts/replay_verify.lua 5 1001 1
lua scripts/invariant_verify.lua 5 1001 1
```

Suggested new fixture:

- `weighted_trick_weighted_payout.lua`, but include payout assertions only after per-coin scoring exists.

## Phase 5: New Round Flow and Pouch Zones

Goal: move from hand-is-board resolution to the canonical deal/select/flip/refill loop.

Current flow:

1. Draw hand.
2. Arrange/reorder hand.
3. Call Heads/Tails.
4. Flip every hand coin.
5. Score aggregate result.
6. Exhaust the whole hand.

Target flow:

1. Deal temporary coins from the Pouch.
2. Player selects legal flip-slot coins.
3. Player arranges selected coins.
4. Player calls Heads/Tails.
5. Smuggling may add extra board coins after the call.
6. Board flips.
7. Tricks resolve automatically.
8. Final Score applies to enemy HP.
9. Used coins refill according to the chosen rule.

Likely files:

- `src/systems/purse_system.lua`
- `src/systems/flip_resolver.lua`
- `src/domain/stage_state.lua`
- `src/states/stage_state.lua`
- `src/ui/purse_view.lua`
- UI helper files if the stage state needs splitting later

Required zones/state concepts:

- available pouch coins
- dealt hand coins
- selected flip slots
- board/result slots
- used/exhausted coins
- overload slots later for Smuggling
- temporary/contraband bodies later for Smuggling

Open tuning values:

- dealt coins per selection, e.g. 6
- legal flip slots per selection, e.g. 3
- refill count after scoring
- whether unselected dealt coins return to pouch, remain dealt, or are replaced
- whether used coins exhaust until encounter end or later re-enter the pouch
- maximum readable overloaded board size

Tasks:

- Model dealt coins separately from the full pouch.
- Model selected legal flip slots separately from unselected dealt coins.
- Preserve player arrangement of selected coins before call/flip.
- Add `after_deal_before_selection` as the future Prediction window.
- Add `after_call_before_flip` as the future Smuggling window.
- After score, replace or recycle used coins according to one chosen refill rule.
- Update replay/transcript shape to preserve dealt order, selected IDs, slot metadata, and refill result.
- Update UI only after the internal zones are deterministic.

Exit criteria:

- The round loop matches the canonical design closely enough for playtesting.
- Pouch, dealt hand, selected slots, board/result slots, and used/exhausted zones are clear in code and UI.
- Replay detects tampering with dealt order, selected IDs, slot metadata, or refill results.
- Legal selected slots are distinct from overload slots once Smuggling is attempted.

Verification:

```sh
lua scripts/engine_fixture_verify.lua unordered_slot_identity_replay
lua scripts/replay_verify.lua 5 1001 1
lua scripts/invariant_verify.lua 5 1001 1
lua scripts/artifact_verify.lua
```

Suggested new fixture:

- `deal_select_refill_round_flow.lua`

## Phase 6: Per-Coin Scoring and Score Events

Goal: split aggregate scoring into deterministic per-coin score events while preserving existing aggregate behavior when no advanced Trick intervenes.

This phase must happen before implementing per-coin payout, score-credit redirect, Outcome replay, and Momentum payoff mechanics.

Likely files:

- `src/systems/scoring_system.lua`
- `src/systems/flip_resolver.lua`
- `src/domain/score_breakdown.lua`
- `src/core/action_queue.lua`
- trace/replay/fixture code

Required support:

- per-coin score action/event records
- `before_coin_score`
- `after_coin_score`
- score-credit attribution
- scoped score multipliers
- result-slot identity separate from coin-body identity
- Outcome seed shape for later Prestige

Tasks:

- Preserve current aggregate score total for ordinary flips.
- Emit deterministic score events for each scoring coin.
- Allow scoped multipliers against eligible coin events instead of only `pendingScoreMultiplier` against the whole batch.
- Record enough event metadata for later Forgery, Prestige, and Momentum work.
- Add fixtures that compare old aggregate result and new event breakdown.

Exit criteria:

- Existing scoring is unchanged when no per-coin Trick intervenes.
- Per-coin score hooks are deterministic and replay-safe.
- Heavy Payout can be implemented as a true eligible weighted-coin payoff after this phase.
- Prestige can record replayable completed Outcomes after this phase.

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:replay
lua scripts/replay_verify.lua 5 1001 1
lua scripts/invariant_verify.lua 5 1001 1
```

## Phase 7: Deeper Trick Families

Goal: implement advanced Trick families only after their prerequisites exist.

Do not start this phase until early Weighted Tricks, new round flow, and per-coin score events are stable.

Recommended family order:

### 7A. Prediction

Prerequisites:

- dealt-vs-selected flow
- visible `after_deal_before_selection` timing
- deterministic foretold result state

First candidates:

- **See Behind the Veil**: after deal, Foretell a random Marked Coin, otherwise a random dealt coin.
- **Fulfilled Fate**: the highest-quality selected Marked Coin is Foretold; when it matches the call, it scores `2x` / `2.5x` / `3x` by material.
- **Heads Pact / Tails Pact**: on matching Heads/Tails Flip, Foretold Coins with Matching Call score extra.
- **Ancient Pattern: T-H-T**: selected Foretold coins matching a visible pattern grant a capped fallback reward.

Boundary:

- Prediction reveals/reads future results. It does not repair failures or change odds.

### 7B. Sleight of Hand

Prerequisites:

- selected slot/result state separate from coin body identity
- movement/swap operations
- material/value comparison gates for physical swaps and strictly improving local rearrangements

First candidates:

- **Switcheroo I–III**: an activating Match trades with a higher-value Miss, with increasingly precise automatic targeting.
- **Vanishing Act I–III**: palm an eligible failed committed body back into hand instead of spending it.
- **Three-Card Monte I–III**: choose a strictly score-improving local arrangement while results remain attached to slots.

Boundary:

- Sleight of Hand moves regular committed bodies through resolved slots or palms a failed body. It does not change results, move Contraband, copy identities, or create coins.

### 7C. Fate

Prerequisites:

- explicit Luck gain event attribution
- `luck_gain` and `luck_meter_full` timing
- design decision on current Fated Flip semantics

First candidates:

- **Omen Engine**: positive Luck gain adds extra Luck Meter progress.
- **Fountain Pact**: global Luck generation is faster.
- **Twist of Fate**: Fated Flips score `1.5x` / `1.75x` / `2.25x` by tier.
- **Fate Uncapped**: Luck can keep filling during a Fated Flip and prepare another Fated Flip, with caps.

Boundary:

- Fate modifies Luck Meter and Fated Flip payoff state. It should not target individual coin results or odds.

Current decision:

- Preserve the current global “all results match call” Fated Flip as the base payoff, then layer Fate Tricks on top as whole-flip rewards.

### 7D. Smuggling

Prerequisites:

- unselected hand/dealt coins
- board slots distinct from legal selected slots
- overload slots
- temporary-copy cleanup
- max board coin cap

First candidates:

- **Hidden Pocket**: gain +1 max Flip Slot for the run.
- **Hidden in Plain Sight**: after the call, move one real unselected hand coin into an overload slot.
- **Off the Books**: after a flip with smuggling, draw +1 extra coin into the next hand if available.
- **Planted Double**: 50% chance to copy a random smuggled coin into a temporary contraband overload slot for this flip.
- **Embarrassment of Riches**: matching coins that were not originally selected but still got flipped score `1.5x`.

Boundary:

- Smuggling adds extra board bodies or temporary contraband copies. It does not forge identity.

### 7E. Forgery

Prerequisites:

- family-trigger activation ledger;
- per-coin root Outcome packets;
- stable selected-slot positions;
- multi-phase custom Trick resolvers;
- replay signatures for generated activations.

Implemented lines:

- **Fake Credentials I-III**: a missing real Blank Coin copies 50% / 75% / 100% of the genuine left neighbour's completed root Outcome.
- **Borrowed Name I-III**: before Flip, a real Blank Coin locks and imitates up to one / two / three eligible Tricks, capped at Tier I / II / III, from the genuine family immediately left.
- **Forged Signature I-III**: before Flip, a real Blank Coin locks one highest-tier eligible Trick, capped at Tier I / II / III, from the genuine family immediately left.

Runtime contract:

- `copy_outcome` records score under `forgedOutcomeCopies` rather than Prestige Replay;
- `forge_trick_activations` creates a separate deterministic forged activation identity;
- one bounded target package is locked for the entire Flip;
- copied Tricks run in every original hook phase using the Blank Coin as source, including pre-roll setup;
- forged activations cannot target Forgery, cannot recurse, and cannot alter locked real families;
- target Tricks retain Block, Weaken, and Jam pressure;
- setup preview marks every scheduled target Trick with `F+n`;
- replay signatures include and validate both `forgeryAssignments` and `forgedActivations`.

### 7G. Prestige

Prerequisites:

- completed coin Outcome records
- discounted Outcome replay
- replay source marking
- non-recursive replay caps

First candidates:

- **Encore**: replay one completed coin Outcome at 20% value, preferring Bent Coins.
- **Curtain Call I-II**: replay one/two random completed coin Outcomes at 20% value, preferring Bent Coins.
- **Impossible Finale I-III**: replay the highest-value, top-two, or all completed coin Outcomes; Finale III replays all at 75% recorded Score contribution.

Boundary:

- Prestige replays recorded Outcomes. It does not recalculate targets, reroll results, run at full value, or recursively replay itself.

### 7H. Momentum

Prerequisites:

- live trigger propagation
- Momentum source/link/depth tracking
- used-coin tracking
- max Momentum depth and action count caps

First candidates:

- **Keep It Rolling**: after a scoring coin, 50% chance to trigger a neighbouring Flywheel Coin if possible, otherwise a random neighbour.
- **Follow Through**: each deferred Momentum Score event gains `+25%` per link depth.
- **Ripple I-II-III**: random, left-neighbour, then both-direction Momentum propagation with capped continuation chances.

Boundary:

- Momentum propagates live links with explicit source and depth. It does not copy full trigger history, make Flywheel Coins score double by default, or recurse without caps.

Global avoid list for this phase:

- board overload before hand/board/overload zones are explicit
- temporary contraband copies before cleanup proves only original owned coins persist
- unbounded coin multiplication before `max_board_coins` and `no_recursive_multiplication` support exists
- Fate payoffs that target individual coins or alter individual coin results
- Fated Flip chaining before Luck-gain suppression overrides and explicit caps exist
- Prestige Outcome replay before completed Outcomes can be recorded and replayed from history
- Prestige replay that recalculates targets, rerolls results, or starts recursive replay
- Momentum propagation before source/depth/used-coin tracking and max-depth caps exist
- copied payouts/triggers retaining copied history
- highest/lowest per-coin scoring logic before per-coin score events are stable

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:replay
lua scripts/replay_verify.lua 10 1001 1
lua scripts/invariant_verify.lua 10 1001 1
```

Add one fixture per family as that family is implemented.

## Phase 8: Enemy Class Trick Rewards

Goal: make defeated opponents the main source of Charms through the **Spoils** screen.

This phase depends on Trick metadata/catalog support from Phase 3 at minimum. It should wait until at least a small set of real Tricks exists.

Likely files:

- `src/content/stages.lua`
- `src/content/bosses.lua`
- `src/content/stage_modifiers.lua`
- `src/systems/reward_system.lua`
- reward UI/state files

Enemy class reward pools:

- **Forger** -> Forgery Tricks
- **Smuggler** -> Smuggling Tricks
- **Card Shark** -> Prediction and Weighted Tricks
- **Fortune Teller** -> Fate Tricks
- **Pit Boss** -> Weighted and Forgery Tricks
- **Magician** -> Sleight of Hand Tricks
- **Showman** -> Prestige and Momentum Tricks

Tasks:

- Add enemy class metadata to stage/opponent definitions.
- Add optional active enemy Trick metadata.
- Weight post-encounter Spoils Charm offers toward the defeated enemy class.
- Keep a bounded wildcard offer chance.
- Add **Seize** costs so Influence is spent to take Charms from Spoils.
- Keep Black Market from being the Charm source; it is the Coin shop.
- Update reward fixtures that currently assume generic `upgrade` offers.

Exit criteria:

- Winning an encounter offers Spoils Charms from the expected class pool.
- Charm offer weighting and Seize costs are deterministic for replay/fixtures.
- Wildcard offers are bounded and visible in reward generation metadata.

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:shop
lua scripts/invariant_verify.lua 5 1001 1
lua scripts/replay_verify.lua 5 1001 1
```

Suggested new fixture:

- `enemy_class_trick_reward_pool.lua`

## Phase 9: Black Market and Economy Cleanup

Goal: align the shop/economy loop with Influence, the Black Market role and Extortion Charms.

Likely files:

- `src/systems/shop_system.lua`
- `src/content/shop.lua`
- `src/content/economy.lua`
- `src/states/shop_state.lua`
- shop fixtures

Tasks:

- Keep Influence as the in-run currency.
- Make the Black Market the Coin shop: Coins, coin refinement/removal, Fountain visits and Coin-stock rerolls.
- Remove normal Charm generation from the Black Market; Charms come from Spoils.
- Add **Extortion** Charms that make economy interactions feel like theft/pressure rather than passive discounts.
- Add **Crumbles** support for temporary economy Charms: tier I/II/III = 1/2/3 uses.
- Update pricing/copy from Chips/shop points to Influence.
- Ensure Black Market/Spoils generation does not offer removed legacy IDs or deprecated entries.

Exit criteria:

- Black Market decisions are Coin/pouch synergy choices, not Charm shopping.
- Influence gain/spend is consistent across stage rewards, Black Market Coin purchases, Spoils Seize costs, and rerolls.
- Extortion effects are visible in generation/purchase traces and consume/Crumbles deterministically.
- Shop fixtures pass with canonical terms and offer types.

Verification:

```sh
lua scripts/engine_fixture_verify.lua tag:shop
lua scripts/invariant_verify.lua 5 1001 1
lua scripts/replay_verify.lua 5 1001 1
```

## Phase 10: Tattoos and Reputation

Goal: replace persistent upgrades with Tattoos and Reputation.

This phase is late because it touches persistence and save/artifact migration.

Likely files:

- `src/content/meta_upgrades.lua`
- `src/content/meta_progression.lua`
- `src/systems/meta_progression_system.lua`
- `src/domain/meta_state.lua`
- `src/states/meta_state.lua`
- save/artifact systems
- tattoo loadout UI

Tasks:

- Rename/design persistent meta upgrades as Tattoos.
- Use Reputation as the persistent purchase/unlock resource.
- Add Tattoo loadout limits.
- Prefer appearance-rate and run-shape influence over build guarantees.
- Preserve or explicitly migrate legacy saves with `metaPoints` and old meta upgrade IDs.

Exit criteria:

- Reputation is awarded after finished runs.
- Tattoos are purchased/equipped between runs.
- Tricks do not persist between runs unless a Tattoo/unlock explicitly changes availability.
- Tattoos influence runs without forcing complete builds.
- Artifact/save verification covers legacy meta state.

Verification:

```sh
lua scripts/artifact_verify.lua
lua scripts/invariant_verify.lua 5 1001 1
lua scripts/replay_verify.lua 5 1001 1
```

## Phase 11: Legacy Cleanup and Internal Renames

Goal: remove compatibility names only after replacement behavior exists and verification passes.

Do not begin broad internal renames until the corresponding player-facing behavior, fixtures, saves, and replay transcripts are stable.

Audit search:

```sh
rg -n "chip|chips|shopPoints|upgrade|upgrades|active coin slot|equippedCoinSlots|persistedLoadoutSlots|targetScore|stageScore|heads_weighted_penny|tails_weighted_penny|economy|attunement|multiplier" src scripts docs/game
```

Cleanup targets:

- legacy player-facing Chip/Shop/Upgrade/Damage copy
- removed legacy coin IDs
- old tags such as `economy`, `attunement`, and aggregate `multiplier` where no longer meaningful
- obsolete manual Sleight of Hand terminology after new Sleight of Hand Tricks exist
- internal names only when their compatibility role is gone

Exit criteria:

- Remaining legacy terms are intentionally documented compatibility paths, archived docs, or migration shims.
- Save/replay/artifact compatibility is preserved or explicitly migrated.
- Full verification set passes.

## Verification Plan

Stable full set before merging each phase:

```sh
lua scripts/engine_fixture_verify.lua
lua scripts/invariant_verify.lua
lua scripts/replay_verify.lua
lua scripts/artifact_verify.lua
```

Minimal targeted set for most engine/content phases:

```sh
lua scripts/engine_fixture_verify.lua <changed_fixture_or_tag>
lua scripts/replay_verify.lua 5 1001 1
lua scripts/invariant_verify.lua 5 1001 1
```

Add artifact verification whenever save, active-run, transcript, or meta shape changes:

```sh
lua scripts/artifact_verify.lua
```

Useful targeted fixtures/tags:

```sh
lua scripts/engine_fixture_verify.lua bootstrap_and_shop_rules
lua scripts/engine_fixture_verify.lua shop_purchase_boundary
lua scripts/engine_fixture_verify.lua unordered_slot_identity_replay
lua scripts/engine_fixture_verify.lua batch_queue_effect_stage_clear
lua scripts/engine_fixture_verify.lua tag:shop
lua scripts/engine_fixture_verify.lua tag:replay
```

Optional simulation only when balance/tuning changed:

```sh
lua scripts/simulate.lua
lua scripts/simulate.lua 5 1001 1
```

After each engine change:

- Add or update one focused fixture for the changed behavior.
- Run deterministic replay checks.
- Check action queue/depth behavior for repeated effects.
- Confirm traces/logs expose new canonical operation names where relevant.

After each terminology/content cleanup:

- Search for old terms.
- Confirm remaining old terms are internal placeholders, archived docs, fixtures, or explicit compatibility paths.

## Next Implementation Slice

Start with Phase 1: player-facing terminology.

The first implementation slice should not rename internal `shopPoints`, `ownedUpgradeIds`, `stageScore`, `targetScore`, `equippedCoinSlots`, or `persistedLoadoutSlots`. It should update visible copy and terminology routing first, then run shop/artifact/invariant verification.
