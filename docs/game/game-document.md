# Coin Flipper: Current Game Design

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
- replay a completed resolution packet
- make one coin trigger another coin in a Chain
- redirect targets, score credit or penalties

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
| Black Market | Main place to buy, upgrade material, remove and refine coins |
| Reputation   | Persistent meta progression awarded after finished runs    |
| Tattoo       | Persistent meta modifier purchased/equipped between runs   |

`Trick` is the canonical rules, UI and content term. `Scam` may exist as world flavour only.

Mechanical vocabulary: `docs/game/mechanics-vocabulary.md`.

## Core Values and Resources

### Score

Score is temporary output from selected coins and resolved Tricks.

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

- buy coins and run objects in the Black Market
- acquire Tricks from defeated opponents
- reroll Trick offers
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
| Bent Coin   | unstable packets, encores, chain links | Prestige, Encore, Domino Line                |
| Blank Coin  | blank papers, forgery medium              | Forgery, Borrowed Name, Fake Credentials      |
| Hollow Coin | hand overflow, contraband capacity        | Smuggling, Sleeve Pocket, Planted Double      |
| Marked Coin | readable coin, foretold results           | Prediction?, Foretold coins, Ancient Patterns |
| Lucky Coin  | Luck Meter fuel, Fated Flip payoff        | Fate, Omen Engine, Fountain Pact, Twist of Fate |
| Weighted Coin | weight, commitment, reliability         | Loaded, Weight, probability builds            |

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

## Tricks

Reference catalog: `docs/game/trick.md`.

Tricks are mostly passive, run-only skills learned during the run from defeated opponents.

Tricks are not persisted between runs.

Tricks replace advanced coin functionality such as neighbor scoring, physical movement, forged identity, target redirection, score-credit funneling, replacement, board overload, smuggling, Luck Meter/Fated Flip payoffs, Prestige packet replays, Chain propagation and final result manipulation.

Initial Tricks should resolve automatically. The player should not need to make choices during score resolution.

Any Trick that moves, swaps, replaces, copies, redirects, smuggles, replays or chains something must define an automatic target rule.

- Swap your weakest successful coin with the strongest available coin in your hand.

Only actual coins should be named `X Coin`. Trick names should avoid colliding with coin archetypes.

- Prefer See Behind the Veil, Fulfilled Fate or Ancient Pattern over Marked Coin.
- Prefer Borrowed Name, Fake Credentials or Copycat Jackpot over Counterfeit Coin.
- Prefer Look Over There, Crooked Spotlight or Stolen Applause over Misdirection.
- Prefer Sleeve Pocket, Backroom Refill or Planted Double over generic Smuggling names.
- Prefer Omen Engine, Fountain Pact, Twist of Fate or Fate Uncapped over generic Fate names.
- Prefer Encore, Curtain Call or Impossible Finale over generic Prestige names.
- Prefer Domino Line, Chained Payout or Deep Link over generic Chain names.

### Trick Categories

| Code tag       | Player-facing category | Role                                           |
| -------------- | ---------------------- | ---------------------------------------------- |
| `loaded`       | Loaded Tricks          | pre-flip probability Weight and weighted payoffs |
| `marked`       | Prediction Tricks (?)   | foretold coins, pre-selection reads and Ancient Patterns |
| `sleight`      | Sleight Tricks         | physical coin movement, slot swaps, substitutions and movement-based rescores |
| `counterfeit`  | Forgery Tricks         | position-based identity fraud, forged credentials and copied payout/trigger behavior |
| `misdirection` | Misdirection Tricks    | Decoy defense, target rerouting and score-credit funneling |
| `smuggle`      | Smuggling Tricks       | board overload, extra hand coins, refill engines and temporary contraband copies |
| `fate`         | Fate Tricks            | Luck Meter acceleration, Fountain Favor boosts and Fated Flip payoffs/chains |
| `prestige`     | Prestige Tricks        | discounted replays of completed resolution packets |
| `chain`        | Chain Tricks           | live coin-to-coin trigger propagation          |

Loaded Tricks act before results exist by adding or increasing Weight toward a side, usually the player's call. They do not convert, reroll or repair outcomes after the flip.

Prediction Tricks are still a question-mark category. Current direction: reveal future results on dealt coins as Foretold coins before selection, then reward selected Foretold coins that fulfill the call or match visible Ancient Patterns. They should not add individual coin-call UI, convert failures, reroll coins or fix outcomes after the flip.

Prediction risk to remember: if too many results are revealed, the optimal move may become obvious; if too many Ancient Patterns exist, the family can become passive bonus variance instead of a meaningful selection puzzle.

Sleight Tricks are physical manipulation: fast hands, street-hustler swaps, three-cup moves and substitutions. They move coin bodies through resolved result slots, but do not change the Heads/Tails results, reroll coins, weight odds, reveal prophecy or create copies.

Sleight can occasionally rescore or retrigger, but only as a consequence of coins changing places. Prestige replays completed resolution packets at a discount; Chain creates live coin-to-coin propagation; Sleight retriggers because the cups moved and different coin bodies now occupy the same result slots.

Forgery Tricks are identity fraud: fake papers, forged signatures, stamped credentials and counterfeit payout records. They change what payout, trigger or requirement checks believe a coin is. They do not add extra real coins or slots, move coin bodies, change Heads/Tails results, or redirect score away from another source.

Forgery should be creative rather than automatic highest-score copying. Prefer source constraints such as slot 1, last slot, nearest success, first success or matching tags. Tier I can replace identity for one check, Tier II can add forged identity while keeping the real identity, and Tier III can copy two identities or let multiple coins share one signed template. Copied payout and trigger effects need explicit caps and no recursive copying.

Misdirection Tricks are defensive control first and score funneling second. They make the wrong coin get targeted, credited or paid while keeping coin bodies, identities, results and slots fixed. Decoys protect important coins from enemy Tricks or hostile automatic targeting; Spotlights receive redirected score credit from successful cheap coins.

Misdirection is allowed to be a support family rather than a full primary combo engine. Its risks are narrowness if it only funnels score, passive immunity if Decoys cancel too much, and bland play if score funnels always choose the highest-value coin. Use explicit Decoy/Spotlight constraints, one or two redirected events, clear logs and no recursive redirected retriggers.

Smuggling Tricks are illegal capacity and board overload. They physically force real unselected hand coins onto the board after the player has selected, arranged and called, so a normal 3-coin flip can become 4, 5 or far more coin bodies resolving on the table.

Smuggling's main enablers are coin purchases, bigger hand/refill support and Tricks that move extra hand coins into overload slots. Its multiplication branch can make one real smuggled XYZ coin appear as multiple XYZ board bodies for the current flip, but the extra bodies are temporary contraband copies and only the original owned coin remains in the pouch afterward.

Smuggling adds physical board bodies. It does not merely move selected coins like Sleight, forge identity/payout/trigger checks like Forgery, reroute credit like Misdirection, or change probability/results. Risks: too many coins can slow logs/UI, pure quantity scaling can get bland, and multiplication may need `max_board_coins` or `no_recursive_multiplication` caps if natural hand/refill limits are not enough.

Fate Tricks are Luck Meter engines and Fated Flip payoffs. They fill the Luck Meter faster, improve Luck gain, amplify Fountain Favor, reward Fated Flips and eventually allow capped Fated Flip chains.

Fate only affects the global Luck Meter and Fated Flip layer. It does not create or copy coins, move coin bodies, forge identities, reroute score credit, reroll coins, Weight odds or change individual coin results. Loaded owns individual odds/results; Fate owns meter acceleration and whole-flip Fated payoff.

Fate risks: flat `+1 Luck` can feel like plain math, Fated Flip chaining can dominate if uncapped, and Fated retriggers can become Chain/Prestige confusion if they replay arbitrary triggers. Keep Fate effects meter-only, clearly logged and scoped with `once_per_fated_flip`, `no_individual_coin_targeting` and chain caps.

Prestige Tricks replay completed resolution packets. The act is over, one coin already produced score, effects, neighbour bonuses and affected targets, and then Prestige gives that recorded impact an encore at reduced value, usually 20%.

Prestige replays the record, not the world. It does not add coin bodies, copy identities, move coins, reroll, Weight odds, choose new targets or start fresh Chain propagation by default. It can replay Chain value that already happened inside the original packet, but live Chain logic only runs from a Prestige replay if a Chain Trick explicitly allows it. Use `prestige_replay`, `packet_replay_only`, `replay_at_20_percent`, `no_recursive_prestige` and clear logs.

Chain Tricks create live propagation: one coin has a chance to trigger another coin, then triggered coins have a chance to trigger another random coin. A coin is Chained if it was triggered by another coin rather than by original flip resolution. Track `chain_source`, `chain_link` and `chain_depth`; the third coin in a chain is a Chained coin at depth 2 or deeper.

Chain changes live cause-and-effect; Prestige replays completed cause-and-effect. Chain should use simple player-facing wording, visible links, chance gates such as 50%, `max_chain_depth` and payoffs like Chained coins scoring 1.25x.

### Trick Tiers

- Borrowed Name I: one coin replaces its identity with the slot 1 template for one payout.
- Fake Credentials II: one coin keeps its real identity and adds a forged identity for one check.
- Copycat Jackpot III: multiple forged coins copy a bounded payout or trigger from the slot 1 template.
- Look Over There I: one hostile target is redirected to a Decoy.
- Crooked Spotlight I: one cheap successful coin books its score credit onto a Spotlight.
- Stolen Applause II: up to two successful coins funnel capped score credit into the Spotlight.
- Sleeve Pocket I: one real unselected hand coin enters an overload slot after the call.
- Backroom Refill I: refill one extra coin after the flip to keep Smuggling hands stocked.
- Planted Double II: the first smuggled coin creates a temporary contraband copy for this flip.
- Overloaded Table III: board overload pays a capped bonus for extra coin bodies.
- Omen Engine I: positive Luck gain adds extra Luck Meter progress.
- Fountain Pact I: Fountain Favor contributes more Luck.
- Twist of Fate II: a Fated Flip gains an extra whole-flip payoff or retrigger.
- Fate Uncapped III: Luck can keep filling during a Fated Flip and prepare another Fated Flip.
- Encore I: replay one resolved coin's completed packet at 20% value.
- Curtain Call II: replay the last effect-triggering coin packet at 20% value.
- Impossible Finale III: replay the highest-impact eligible packet at reduced value.
- Domino Line I: scoring or Chained coins have a 50% chance to trigger a random neighbour.
- Chained Payout I: Chained coins score 1.25x.
- Deep Link II: the third coin or deeper in a Chain gains a payoff.

Tiers allow stronger enemies and deeper progression.

### Shared Player and Enemy Trick Philosophy

Every Trick can eventually have a player version and an enemy version.

The same concept should be expressed from opposite sides where useful.

- Player Sleeve Pocket: force an extra hand coin into an illegal board slot.
- Enemy Sleeve Pocket: overload the encounter with extra pressure or force an awkward hand coin into play.
- Player Omen Engine: fill the Luck Meter faster and cash out stronger Fated Flip payoffs.
- Enemy Omen Engine: pressure the player with meter-driven Fated events or punish careless Luck feeding.
- Player Encore: replay one finished coin packet at a discounted encore value.
- Enemy Encore: replay one completed pressure packet after the player thinks resolution is over.
- Player Domino Line: let triggered coins continue into random neighbours with capped Chain depth.
- Enemy Domino Line: pressure jumps through neighbouring coins as a visible Chain.

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
| Active Trick    | Fake Credentials II |
| HP              | 100                |
| Reward Category | Forgery Tricks     |

### Coin Selection

This should be a major strategic decision because the player is choosing which archetypes and synergies enter the Trick machine.

### Arrangement Phase

The player may reorder selected coins before the flip.

Positioning can matter for Tricks, but the complexity should remain readable.

### Call Phase

The player calls Heads or Tails.

Heads/Tails should support build directions through Tricks, calls, Loaded Weight effects and probability manipulation. They should not become primary coin archetypes.

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
- access Trick rewards

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
| Card Shark     | reading coins and manipulating odds    | Prediction? and Loaded Tricks          |
| Fortune Teller | Luck Meter engines and Fated Flip payoffs | Fate Tricks                            |
| Pit Boss       | control, pressure and house rules      | Misdirection and control-oriented Tricks       |
| Magician       | fast hands, cup work and substitutions | Sleight Tricks                         |
| Showman        | encores, finales and chain reactions   | Prestige and Chain Tricks              |

## Trick Acquisition

After defeating an opponent, the player chooses from multiple Trick offers.

Offers should primarily come from the defeated enemy's class, with a small chance of wildcard offers.

Defeat a Forger and choose one:

- Borrowed Name
- Fake Credentials
- Copycat Jackpot
- Generic Trick

Influence may be used to acquire Tricks, reroll offers or purchase special run opportunities.

## Black Market

Black Market actions can include:

- buy a coin
- upgrade coin material
- remove a coin
- refine the pouch
- buy special run opportunities

The Black Market should improve the player's pouch and support Trick builds without becoming the main source of Tricks.

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
- Decoy defenses
- board overload smuggling
- Foretold coin reads
- class-weighted Trick rewards

### Late Game

- legendary con artist
- massive chain reactions
- reality-bending Tricks
- Prestige packet replays
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
7. Defer deep copied-trigger, target-rerouting, board-overload, Fated Flip chaining, Prestige packet replay, Chain propagation and per-coin-scoring mechanics.

## Open Questions Before Implementation

- Exact dealt coin count.
- Exact flip slot count.
- Exact refill rule after scoring.
- Whether unflipped dealt coins remain, return or are replaced.
- Whether used coins exhaust for the full encounter.
- Whether Trick acquisition always costs Influence or only optional rerolls/extra picks cost Influence.
- Which first 3-5 Tricks should define the MVP.
- Whether Silver/Gold coin materials should exist immediately or after Copper-only archetypes are proven.
- Whether Prediction? is strong enough once it depends only on selecting around Foretold coins and Ancient Patterns.

## Success Criteria

A successful run should feel like:

> I found a loophole.

A successful build should feel like:

> I built the perfect Trick machine.

A successful late-game run should feel like:

> The House has absolutely no idea how I got away with this.
