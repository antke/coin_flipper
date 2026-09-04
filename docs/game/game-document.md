# Coin Flipper: Current Game Design

> Design precedence (2026-07-29): the high-level fantasy, terminology, coin
> archetypes, economy, and progression in this document remain useful. The
> family-triggered engine in `../family-trigger-engine-design.md` overrides this
> document wherever it discusses how Tricks become active, same-archetype
> preference bonuses, hand refill/holding, Momentum triggering, or opponent
> interaction with the active Trick board. Use
> `../family-trigger-trick-migration.md` for current proposed Trick text.

## High-Level Vision

The game is about becoming a legendary cheating gambler who bends probability, manipulates outcomes and learns powerful Tricks from rival cheats.

Coin flipping is the medium.

The player is not trying to get lucky. The player is trying to get away with cheating fate.

The best builds should feel like automatic Trick machines: the player makes strategic decisions, starts the flip, then watches a chain of rule-breaking effects resolve.

## Core Pillars

### Build a Machine

The player assembles coins and Tricks over a run, then watches them interact automatically.

The main satisfaction should come from planning, synergy and adaptation rather than manual execution during scoring.

### Break Rules, Not Just Numbers

Weak effects only add more score, luck or percentage chance.

Strong Trick effects feel like cheating:

- convert a failed coin into a success
- reroll a failed coin
- forge a coin's identity or payout record
- overload the board with smuggled hand coins
- treat one result as another
- replay a completed coin Outcome
- make one coin trigger another coin through Momentum

### Adapt to the Run

The player should not be guaranteed a specific build.

Each run should ask:

> What Tricks can I build from what I found?

Random offers, enemy classes, Black Market coin availability and Tattoo influence should create direction without forcing complete builds.

## Canonical Terms

| Term         | Meaning                                                    |
| ------------ | ---------------------------------------------------------- |
| Trick        | Run-only passive skill and primary build-defining mechanic |
| Influence    | In-run currency, lost at run end                           |
| HP           | Enemy health and encounter win condition                   |
| Score        | Temporary flip output applied against enemy HP             |
| Coin         | Simple archetypal game object in the player's pouch        |
| Pouch        | Player's run pool of available coins                       |
| Black Market | Coin shop: buy Coins, sell/refine/remove Coins, visit Fountain and reroll stock |
| Spoils       | Post-enemy Charm acquisition screen                        |
| Seize        | Spend Influence to take a Charm from Spoils                |
| Crumbles     | Charm breaks after its last use and is removed             |
| Reputation   | Persistent meta progression awarded after finished runs    |
| Tattoo       | Persistent meta modifier purchased/equipped between runs   |

`Trick` is the canonical rules, UI and content term. `Scam` may exist as world flavour only.

Mechanical vocabulary: `docs/game/mechanics-vocabulary.md`.

## Core Values and Resources

### Score

Score is temporary output from selected coins and resolved Tricks.

The standard coin Score unit is `10`. Percentages and discounted replays are balanced around that unit so small multipliers remain visible after integer rounding.

Score is applied against enemy HP and is not the main economy.

### HP

The player wins an encounter by generating enough score across flips to reduce or beat the enemy's HP requirement.

HP should remain the name of the encounter win condition.

### Influence

Influence replaces chips, dollars, shop points and similar temporary run currencies.

Influence represents favours, leverage, bribes and underworld connections.

Gained from:

- winning encounters
- overkill
- strong combos
- strong round performance

Used to:

- buy Coins in the Black Market
- Seize Charms from defeated opponents' Spoils
- reroll Spoils or Black Market stock
- buy special run opportunities

Influence is lost at the end of the run.

### Reputation

Reputation is awarded after each finished run, win or lose.

Used to:

- purchase Tattoos between runs
- unlock content
- unlock stronger enemies
- unlock advanced encounters
- unlock long-term progression

Reputation persists between runs.

## Coins

Reference catalog: `docs/game/coin.md`.

Coins provide:

- readable build pieces
- synergy opportunities
- draft decisions
- pouch progression
- Black Market decisions

The player should understand a coin quickly. Complex rule-breaking should mostly come from Tricks.

### Coin Archetypes

Heads and Tails are build directions, not coin archetypes.

Avoid coin identities such as Heads Coin, Tails Coin, Heads-Weighted Coin, Tails-Weighted Coin, Weighted Heads Coin and Weighted Tails Coin.

| Coin        | Core identity                             | Trick synergy                                 |
| ----------- | ----------------------------------------- | --------------------------------------------- |
| Bent Coin   | unstable Outcomes and encores            | Prestige, Encore, Curtain Call              |
| Flywheel Coin | motion, carried force, In Motion links | Momentum, Keep It Rolling, Ripple           |
| Blank Coin  | blank papers, forgery medium              | Forgery, Borrowed Name, Fake Credentials      |
| Hollow Coin | hand overflow, contraband capacity        | Smuggling, Hidden in Plain Sight, Planted Double |
| Vanishing Coin | half-seen magician's coin, palms and rearrangements | Sleight of Hand, Switcheroo, Vanishing Act, Three-Card Monte |
| Marked Coin | readable coin, foretold results           | Prediction, Foretold coins, Ancient Patterns |
| Lucky Coin  | Luck Meter fuel, Fated Flip payoff        | Fate, Omen Engine, Fountain Pact, Twist of Fate |
| Weighted Coin | weight, commitment, reliability         | Weighted, probability builds                  |

### Coin Materials

Coin material defines how strongly the archetype is expressed.

Material does not mean bigger raw score.

Initial materials:

- Copper
- Silver
- Gold

- Copper Bent Coin
- Silver Hollow Coin
- Gold Blank Coin

Base coin identity does not include material. Material is a variant layer.

Copper is the baseline material and supplies baseline values.

Material means "more of the archetype". A stronger Bent Coin should feel more Bent, not merely have a larger number.

All materials retain `Base Score: 10`. Initial Black Market material weights are:

- Copper / regular: 50%
- Silver: 35%
- Gold: 15%

## Tricks

Reference catalog: `docs/game/trick.md`.

Tricks are mostly passive, run-only skills learned during the run from defeated opponents.

Tricks are not persisted between runs.

Tricks replace advanced coin functionality such as neighbor scoring, physical movement, forged identity, target redirection, score-credit funneling, replacement, board overload, smuggling, Luck Meter/Fated Flip payoffs, Prestige Outcome replays, Momentum propagation and final result manipulation.

Initial Tricks should resolve automatically. The player should not need to make choices during score resolution.

Any Trick that moves, swaps, replaces, copies, redirects, smuggles, replays or chains something must define an automatic target rule.

- Swap your weakest successful coin with the strongest available coin in your hand.

Only actual coins should be named `X Coin`. Trick names should avoid colliding with coin archetypes.

- Prefer See Behind the Veil, Fulfilled Fate or Ancient Pattern over Marked Coin.
- Prefer Fake Credentials, Borrowed Name or Forged Signature over Counterfeit Coin.
- Prefer Hidden Pocket, Hidden in Plain Sight, Off the Books or Planted Double over generic Smuggling names.
- Prefer Omen Engine, Fountain Pact, Twist of Fate or Fate Uncapped over generic Fate names.
- Prefer Encore, Curtain Call or Impossible Finale over generic Prestige names.
- Prefer Keep It Rolling, Follow Through or Ripple over generic Momentum names.

### Trick Categories

| Code tag       | Player-facing category | Role                                           |
| -------------- | ---------------------- | ---------------------------------------------- |
| `weighted`     | Weighted Tricks        | pre-flip probability Weight and weighted payoffs |
| `prediction`   | Prediction Tricks       | foretold coins, pre-selection reads and Ancient Patterns |
| `sleight`      | Sleight of Hand Tricks | physical coin movement, slot swaps and substitutions |
| `counterfeit`  | Forgery Tricks         | left-neighbour credentials, copied Outcomes and bounded family/Trick activations |
| `smuggle`      | Smuggling Tricks       | board overload, extra hand coins, refill engines and temporary contraband copies |
| `fate`         | Fate Tricks            | Luck Meter acceleration, Fountain Favor boosts and Fated Flip payoffs/chains |
| `prestige`     | Prestige Tricks        | discounted replays of completed coin Outcomes |
| `momentum`     | Momentum Tricks        | live coin-to-coin trigger propagation          |

Weighted Tricks act before results exist by adding or increasing Weight toward a side, usually the player's call. They do not convert, reroll or repair outcomes after the flip.

Prediction Tricks reveal future results on dealt coins as Foretold coins before selection, then reward selected Foretold coins with Matching Call or visible Ancient Patterns. They should not add individual coin-call UI, convert failures, reroll coins or fix outcomes after the flip.

Prediction risk to remember: if too many results are revealed, the optimal move may become obvious; if too many Ancient Patterns exist, the family can become passive bonus variance instead of a meaningful selection puzzle.

Sleight of Hand Tricks are physical manipulation: fast hands, street-hustler swaps, three-cup moves and substitutions. Vanishing Coin is their coin archetype because it is a half-seen magician's coin built to palm, swap or substitute. Sleight Tricks move coin bodies through resolved result slots, but do not change the Heads/Tails results, reroll coins, weight odds, reveal prophecy or create copies.

Sleight of Hand keeps result slots fixed while the coin bodies secretly change places. Prestige replays completed coin Outcomes at a discount; Momentum creates live coin-to-coin propagation.

Forgery is hybrid support. A real Blank Coin reads the genuine non-Forgery coin immediately to its left, then copies its completed Outcome or counterfeits bounded activations from that family. The setup UI marks scheduled targets before execution.

Forgery consumes both Trick capacity and pouch space. Low-tier Forgery cannot copy high-tier Tricks, copied activations use the Blank as source, normal opponent pressure still applies, locked real families never change, and a forged activation cannot activate Forgery or be forged again.

Smuggling Tricks are illegal capacity and board overload. They physically force real unselected hand coins onto the board after the player has selected, arranged and called, so a normal 3-coin flip can become 4, 5 or far more coin bodies resolving on the table.

Smuggling's main enablers are coin purchases, bigger hand/refill support and Tricks that move extra hand coins into overload slots. Its multiplication branch can make one real smuggled XYZ coin appear as multiple XYZ board bodies for the current flip, but the extra bodies are temporary contraband copies and only the original owned coin remains in the pouch afterward.

Smuggling adds physical board bodies. It does not merely move selected coins like Sleight of Hand, forge identity/payout/trigger checks like Forgery, or change probability/results. Risks: too many coins can slow logs/UI, pure quantity scaling can get bland, and multiplication may need `max_board_coins` or `no_recursive_multiplication` caps if natural hand/refill limits are not enough.

Extortion has no dedicated coin archetype by design. It belongs to Influence pressure, Black Market theft, Spoils leverage and Crumbling Charms rather than coin-body rules.

Fate Tricks are Luck Meter engines and Fated Flip payoffs. They fill the Luck Meter faster, improve Luck gain, amplify Fountain Favor, reward Fated Flips and eventually allow capped Fated Flip chains.

Fate only affects the global Luck Meter and Fated Flip layer. It does not create or copy coins, move coin bodies, forge identities, reroll coins, Weight odds or change individual coin results. Weighted owns individual odds/results; Fate owns meter acceleration and whole-flip Fated payoff.

Fate risks: flat `+1 Luck` can feel like plain math, Fated Flip chaining can dominate if uncapped, and Fated retriggers can become Momentum/Prestige confusion if they replay arbitrary triggers. Keep Fate effects meter-only, clearly logged and scoped with `once_per_fated_flip`, `no_individual_coin_targeting` and propagation caps.

Prestige Tricks replay completed coin **Outcomes**. The act is over, one coin already produced score and recorded value, and then Prestige gives that Outcome an encore at reduced value, usually 20%.

Prestige replays the record, not the world. It does not add coin bodies, copy identities, move coins, reroll, Weight odds, choose new targets or start fresh Momentum propagation by default. It can replay Momentum value that already happened inside the original Outcome, but live Momentum logic only runs from a Prestige replay if a Momentum Trick explicitly allows it. Use `prestige_replay`, `outcome_replay_only`, `replay_at_20_percent`, `no_recursive_prestige` and clear logs.

Momentum Tricks create live propagation: one coin has a chance to trigger another coin for an additional Score event, then triggered coins can continue the motion. A coin is **In Motion** if it was triggered by another coin rather than by original flip resolution. Flywheel Coins are the clean Momentum archetype and preferred basis for links.

Momentum changes live cause-and-effect; Prestige replays completed cause-and-effect. Momentum should use simple player-facing wording, visible links, chance gates such as 50%, capped propagation and payoffs like Follow Through.

### Trick Tiers

- Fake Credentials I/II/III: a missing Blank copies 50% / 75% / 100% of its successful genuine left neighbour's completed Outcome.
- Borrowed Name I/II/III: before Flip, a Blank locks and imitates up to one / two / three eligible Tricks, capped at Tier I / II / III, from its genuine left neighbour's family.
- Forged Signature I/II/III: before Flip, a Blank locks one highest-tier eligible Trick, capped at Tier I / II / III, from its genuine left neighbour's family.
- Hidden Pocket I: gain +1 max Flip Slot for the run.
- Hidden in Plain Sight I: one real unselected hand coin enters an overload slot after the call.
- Off the Books I: after a flip with smuggling, draw +1 extra coin into the next hand if available.
- Planted Double I: 50% chance to copy a random smuggled coin into a temporary contraband overload slot for this flip.
- Embarrassment of Riches I: matching coins not selected in the original flip but still flipped score 1.5x.
- Omen Engine I: positive Luck gain adds extra Luck Meter progress.
- Fountain Pact I: Fountain Favor contributes more Luck.
- Twist of Fate II: a Fated Flip gains an extra whole-flip payoff or retrigger.
- Fate Uncapped III: Luck can keep filling during a Fated Flip and prepare another Fated Flip.
- Encore: replay one completed coin Outcome at 20% value, preferring Bent Coins.
- Curtain Call I/II: replay one/two random completed coin Outcomes at 20% value, preferring Bent Coins.
- Impossible Finale I/II/III: replay the highest-value, top-two, or all completed coin Outcomes; Finale III uses 75% recorded Score contribution.
- Keep It Rolling I: scoring coins have a 50% chance to trigger a neighbouring Flywheel Coin if possible, otherwise a random neighbouring coin.
- Follow Through I: coins In Motion score more for each Momentum link that carried them.
- Ripple I/II/III: random, to-the-left, then both-direction Momentum propagation with capped continuation chances.

Tiers allow stronger enemies and deeper progression.

### Shared Player and Enemy Trick Philosophy

Every Trick can eventually have a player version and an enemy version.

The same concept should be expressed from opposite sides where useful.

- Player Hidden in Plain Sight: force an extra hand coin into an illegal board slot.
- Enemy Hidden in Plain Sight: overload the encounter with extra pressure or force an awkward hand coin into play.
- Player Omen Engine: fill the Luck Meter faster and cash out stronger Fated Flip payoffs.
- Enemy Omen Engine: pressure the player with meter-driven Fated events or punish careless Luck feeding.
- Player Encore: replay one finished coin Outcome at a discounted encore value.
- Enemy Encore: replay one completed pressure Outcome after the player thinks resolution is over.
- Player Keep It Rolling: let scoring coins carry motion into neighbouring coins.
- Enemy Keep It Rolling: pressure jumps through neighbouring coins as visible Momentum.

This is a design goal, not an immediate implementation requirement for every early Trick.

## Pouch and Round Flow

The target flow is similar to a card game:

1. At encounter start, the player is dealt a temporary selection of coins from the pouch.
2. The player chooses some dealt coins to flip.
3. The player may arrange chosen coins before the flip.
4. The player calls Heads or Tails.
5. Smuggling Tricks may force extra hand coins onto overload slots after the call.
6. Board coins flip, including any smuggled bodies.
7. Tricks resolve automatically.
8. Final score is applied against enemy HP.
9. Used coins are replaced from the pouch according to refill rules.
10. The player repeats selection/flip cycles until the encounter ends.

Example starting numbers:

- 6 coins dealt.
- 3 flip slots.
- 3 flips per encounter.
- Current HP curve: 40 / 55 / 65 / 80.

Open tuning questions:

- exact dealt count
- exact flip slot count
- refill count after scoring
- maximum readable overloaded board size, if Smuggling needs an explicit cap
- whether temporary contraband copies score or trigger exactly like originals before cleanup
- what happens to unflipped dealt coins
- whether used coins exhaust for the encounter or re-enter the pouch later

## Encounter Structure

### Encounter Begins

| Field           | Example            |
| --------------- | ------------------ |
| Opponent        | The Forger         |
| Class           | Forger             |
| Active Trick    | Fake Credentials I |
| HP              | 40                 |
| Reward Category | Forgery Tricks     |

### Coin Selection

This should be a major strategic decision because the player is choosing which archetypes and synergies enter the Trick machine.

### Arrangement Phase

The player may reorder selected coins before the flip.

Positioning can matter for Tricks, but the complexity should remain readable.

### Call Phase

The player calls Heads or Tails.

Heads/Tails should support build directions through Tricks, calls, Weighted effects and probability manipulation. They should not become primary coin archetypes.

### Flip Phase

Coins flip and reveal results.

### Trick Resolution Phase

No additional player input should be required.

### Score Resolution

Final score is calculated and applied against enemy HP.

Used coins are replaced from the pouch according to refill rules.

### Encounter Result

On success:

- gain Influence
- access Spoils Charms

On failure:

- run continues or ends depending on mode
- reduced rewards may apply

Reputation is awarded after the run finishes, win or lose.

## Enemy Classes

Enemies are rival cheats. They do not play the same coin-flipping game as the player and do not generate scores.

Instead, enemies modify encounter rules through active Tricks.

| Class          | Theme                                  | Reward pool                            |
| -------------- | -------------------------------------- | -------------------------------------- |
| Forger         | forged credentials and copied payouts  | Forgery Tricks                         |
| Smuggler       | hand overflow, contraband coins and illegal board capacity | Smuggling Tricks                       |
| Card Shark     | reading coins and manipulating odds    | Prediction and Weighted Tricks         |
| Fortune Teller | Luck Meter engines and Fated Flip payoffs | Fate Tricks                            |
| Pit Boss       | control, pressure and house rules      | Weighted and Forgery Tricks                    |
| Magician       | fast hands, cup work and substitutions | Sleight of Hand Tricks                 |
| Showman        | encores, finales and kept motion       | Prestige and Momentum Tricks           |

## Trick Acquisition

After defeating an opponent, the player sees **Spoils** and chooses from multiple Charm offers.

Offers should primarily come from the defeated enemy's class, with a small chance of wildcard offers.

The player spends Influence to **Seize** one Charm. Some economy Charms can modify Spoils before they **Crumble**.

Defeat a Forger and choose one:

- Borrowed Name
- Fake Credentials
- Forged Signature
- Generic Trick

Influence may be used to Seize Charms, reroll Spoils, buy Coins or purchase special run opportunities.

## Black Market

Black Market actions can include:

- buy a Coin
- upgrade coin material
- remove a coin
- refine the pouch
- sell Charms
- visit the Fountain
- reroll Coin stock
- buy special run opportunities

The Black Market should improve the player's pouch and support Charm builds without becoming the Charm source. Charms normally come from Spoils.

## Tattoos and Meta Progression

Tattoos replace the current persistent upgrade system.

Tattoos are purchased and equipped between runs using Reputation.

Tattoos can be unlocked through:

- Reputation thresholds
- achievements
- milestones
- hidden challenges

Tattoo effects should:

- influence playstyle
- alter appearance rates of certain Tricks or coins
- slightly alter run structure

Tattoo effects should not:

- define the entire build
- guarantee specific outcomes
- remove the need to adapt during the run

Example Tattoo achievements:

- Win 3 rounds with all Heads.
- Trigger Forgery Tricks 10 times.
- Reach maximum Luck meter 20 times.

## Progression Fantasy

### Early Game

- small-time gambler
- simple archetype coins
- minor Tricks
- clear HP goals

### Mid Game

- known cheat
- forged identities
- board overload smuggling
- Foretold coin reads
- class-weighted Trick rewards

### Late Game

- legendary con artist
- massive Momentum reactions
- reality-bending Tricks
- Prestige Outcome replays
- Fated Flip payoff chains
- complex Trick combinations

## Implementation Priority

First playable implementation slice:

1. Keep enemy HP/damage scoring working.
2. Rename player-facing economy to Influence.
3. Treat current run upgrades as the first internal version of Tricks.
4. Add a small set of passive early Tricks.
5. Replace starter coins with simple archetype coins.
6. Add only the missing engine operations needed for those Tricks.
7. Defer deep copied-trigger, target-rerouting, board-overload, Fated Flip chaining, Prestige Outcome replay, Momentum propagation and per-coin-scoring mechanics.

## Open Questions Before Implementation

- Exact dealt coin count.
- Exact flip slot count.
- Exact refill rule after scoring.
- Whether unflipped dealt coins remain, return or are replaced.
- Whether used coins exhaust for the full encounter.
- Whether Trick acquisition always costs Influence or only optional rerolls/extra picks cost Influence.
- Which first 3-5 Tricks should define the MVP.
- Whether later material weights should remain 50/35/15 or vary by run depth and Tattoos.
- Whether Prediction is strong enough once it depends only on selecting around Foretold coins and Ancient Patterns.

## Success Criteria

A successful run should feel like:

> I found a loophole.

A successful build should feel like:

> I built the perfect Trick machine.

A successful late-game run should feel like:

> The House has absolutely no idea how I got away with this.
