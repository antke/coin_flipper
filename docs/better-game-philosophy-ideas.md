# Cheating Fate - Core Design Document (v2)

## High-Level Vision

The game is no longer primarily about flipping coins.

The game is about becoming a legendary cheating gambler who bends probability, manipulates outcomes and learns increasingly powerful tricks from other cheats.

Coin flipping is the medium through which this fantasy is expressed.

The player is not trying to get lucky.

The player is trying to get away with cheating fate itself.

---

# Core Design Philosophy

## Build a Machine

The player should make a few strategic decisions and then watch a chain of effects resolve automatically.

The goal is to create moments similar to Balatro where:

- The player assembles a build.
- The player executes a round.
- A chain reaction of effects begins.
- The player watches their trick machine go to work.

The game should reward planning and creativity more than manual execution.

---

## Break Rules, Not Just Numbers

Interesting mechanics are not:

- +10 Score
- +5 Luck
- +10% Heads

Interesting mechanics are:

- Replace a coin after the flip.
- Forge a coin's identity or payout record.
- Stamp fake credentials onto a coin.
- Redirect a target or score credit to the wrong coin.
- Overload the board with smuggled hand coins.
- Trigger a coin twice.
- Treat Tails as Heads.

The player should feel like they found a loophole rather than a multiplier.

---

## Adapt To The Run

The player should never be guaranteed a specific build.

Every run should ask:

> "What tricks can I build from what I found?"

rather than:

> "How quickly can I force my favourite build?"

Randomness and adaptation are essential.

---

# World & Theme

The game takes place in an underground gambling world populated by:

- Cheats
- Card Sharks
- Forgers
- Smugglers
- Fortune Tellers
- Showmen
- Pit Bosses
- Hustlers
- Con Artists

These characters are not traditional enemies.

They are rival cheats.

Every opponent is running a trick.

Every victory allows the player to learn new tricks.

The player gradually rises from a nobody to a legendary cheat feared throughout the gambling world.

---

# Core Values & Resources

## Score

Generated during flips.

Score is the temporary output of the player's selected coins and resolved tricks.

Score is applied against enemy HP.

Score itself is not the main economy.

---

## HP

Enemy health.

The player wins an encounter by generating enough score to beat the enemy's HP.

HP should remain the name of the encounter win condition.

---

## Influence

Run-specific currency.

Influence replaces chips, dollars, shop points and similar temporary run currencies.

Influence represents favours, leverage, bribes and underworld connections.

Gained from:

- Winning encounters
- Overkill results
- Amazing combos
- Strong round performance

Used to:

- Buy coins in the Black Market
- Acquire tricks from defeated opponents
- Reroll trick offers
- Purchase special run opportunities

Lost at the end of the run.

---

## Reputation

Persistent meta currency and progression.

Reputation represents the player's long-term standing in the gambling underworld.

Reputation is awarded after each finished run, win or lose.

Used to:

- Purchase tattoos between runs
- Unlock content
- Unlock stronger enemies
- Unlock advanced encounters
- Increase long-term progression

Persists between runs.

---

# Tricks, Coins, Tattoos

## Tricks

Tricks are the player's run-only skills.

They are mostly passive.

They replace advanced coin functionality such as:

- Adding score to neighbours
- Moving coin bodies through resolved slots
- Replacing coins
- Forging coin identity
- Redirecting targets and score credit
- Overloading the board with smuggled hand coins
- Luck Meter and Fated Flip payoffs
- Prestige packet replays
- Chain propagation
- Re-triggering effects
- Manipulating final results

Tricks are unlocked step by step during the run by defeating opponents.

Tricks are not persisted between runs.

Initial tricks should resolve automatically and should not require player input during scoring.

If a trick moves, swaps, replaces, copies, redirects or smuggles something, it must define an automatic target rule.

Example:

- Swap your weakest successful coin with the strongest available coin in your hand.

---

## Coins

Coins are game objects.

Coins are bought, upgraded, removed and refined through the Black Market.

Coins are not the primary source of complexity.

Coins provide:

- Readable build pieces
- Synergy opportunities
- Draft decisions
- Pouch progression
- Black Market decisions

The player should be able to understand a coin immediately.

Complexity should primarily come from tricks.

---

## Tattoos

Tattoos are meta progression.

They replace the current persistent upgrade system.

Tattoos can only be purchased between runs.

Tattoos are purchased by reaching and spending the required Reputation.

Tattoos influence future runs but should not guarantee a complete build.

---

# Canonical Names

## Coin Archetypes

The coin design document was written after this philosophy document and overrides older Heads/Tails-oriented coin examples.

Heads and Tails are build directions, not coin archetypes.

Avoid coin identities such as:

- Heads Coin
- Tails Coin
- Heads-Weighted Coin
- Tails-Weighted Coin
- Weighted Heads Coin
- Weighted Tails Coin

Use these coin archetypes instead:

| Coin | Core identity | Preferred builds |
| --- | --- | --- |
| Bent Coin | Unstable packets, encores, chain links | Prestige, Encore, Domino Line |
| Blank Coin | Blank papers, forgery medium | Forgery, Borrowed Name, Fake Credentials |
| Hollow Coin | Hand overflow, contraband capacity | Smuggling, Sleeve Pocket, Planted Double |
| Marked Coin | Readable coin, foretold results | Prediction?, Foretold coins, Ancient Patterns |
| Lucky Coin | Luck Meter fuel, Fated Flip payoff | Fate, Omen Engine, Fountain Pact, Twist of Fate |
| Weighted Coin | Weight, commitment, reliability | Loaded, Weight, probability builds |

---

## Coin Quality

Coin quality defines how strongly the archetype is expressed.

Quality does not mean bigger raw score.

Use:

- Copper
- Silver
- Gold

Example names:

- Copper Bent Coin
- Silver Hollow Coin
- Gold Blank Coin

Quality means "more of the archetype".

Example:

- Copper Bent Coin supports packet replays and Chain links.
- Silver Bent Coin expresses the same unstable encore/Chain identity more strongly.
- Gold Bent Coin expresses the Bent identity even more strongly.

The player should think:

> "I need a Bent Coin for this Prestige trick."

not:

> "I need the coin with the biggest number."

---

## Trick Categories

Trick is the canonical name.

Scam can exist as world flavour, but rules, UI and content should use Trick.

Only actual coins should be named "X Coin".

Avoid naming tricks in a way that conflicts with coin archetypes.

For example:

- Prefer See Behind the Veil, Fulfilled Fate or Ancient Pattern over Marked Coin.
- Prefer Borrowed Name, Fake Credentials or Copycat Jackpot over Counterfeit Coin.
- Prefer Look Over There, Crooked Spotlight or Stolen Applause over Misdirection.
- Prefer Sleeve Pocket, Backroom Refill or Planted Double over generic Smuggling names.
- Prefer Omen Engine, Fountain Pact, Twist of Fate or Fate Uncapped over generic Fate names.
- Prefer Encore, Curtain Call or Impossible Finale over generic Prestige names.
- Prefer Domino Line, Chained Payout or Deep Link over generic Chain names.

Canonical trick categories:

| Code tag | Player-facing category | Role |
| --- | --- | --- |
| `loaded` | Loaded Tricks | Pre-flip probability Weight and weighted payoffs |
| `marked` | Prediction Tricks (?) | Foretold coins, pre-selection reads and Ancient Patterns |
| `sleight` | Sleight Tricks | Physical coin movement, slot swaps, substitutions and movement-based rescores |
| `counterfeit` | Forgery Tricks | Position-based identity fraud, forged credentials and copied payout/trigger behavior |
| `misdirection` | Misdirection Tricks | Decoy defense, target rerouting and score-credit funneling |
| `smuggle` | Smuggling Tricks | Board overload, extra hand coins, refill engines and temporary contraband copies |
| `fate` | Fate Tricks | Luck Meter acceleration, Fountain Favor boosts and Fated Flip payoffs/chains |
| `prestige` | Prestige Tricks | Discounted replays of completed resolution packets |
| `chain` | Chain Tricks | Live coin-to-coin trigger propagation |

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

Prestige Tricks replay completed resolution packets. A coin already resolved, produced score, emitted effects, affected other coins and caused neighbour bonuses; Prestige makes that recorded impact happen again as an encore at reduced value, usually 20%.

Prestige replays the record, not the world. It does not add coin bodies, copy identities, move coins, reroll, Weight odds, choose new targets or start fresh Chain propagation by default. If the original packet included Chain value, Prestige may replay that recorded value at the discount. Live Chain logic only runs from a Prestige replay if a Chain Trick explicitly allows it. Use `prestige_replay`, `packet_replay_only`, `replay_at_20_percent` and `no_recursive_prestige`.

Chain Tricks create live propagation: one coin has a chance to trigger another coin, then triggered coins have a chance to trigger another random coin. A coin is Chained if it was triggered by another coin instead of by original flip resolution. Track `chain_source`, `chain_link` and `chain_depth`; the third coin in the chain is a Chained coin at depth 2 or deeper.

Chain changes live cause-and-effect; Prestige replays completed cause-and-effect. Chain should use simple wording, visible links, chance gates such as 50%, `max_chain_depth` and payoffs like Chained coins scoring 1.25x.

---

# Tattoos (Meta Progression)

Tattoos represent the player's permanent identity.

Examples:

- Counterfeiter
- Card Shark
- Smuggler
- Fortune Hunter

Tattoos are unlocked through:

- Reputation
- Achievements
- Milestones
- Hidden challenges

Tattoos are then purchased between runs with Reputation.

Examples:

- Win 3 rounds with all Heads.
- Trigger Forgery Tricks 10 times.
- Reach maximum Luck meter 20 times.

---

## Tattoo Loadout

The player cannot bring all tattoos into a run.

Before starting:

- Select a limited number of tattoo slots.
- Choose which tattoos to equip.

Example:

- 3 tattoo slots initially.
- More slots unlocked later.

This creates meaningful meta decisions.

---

## Tattoo Purpose

Tattoos should:

- Influence playstyle.
- Increase appearance rates of certain tricks.
- Slightly alter run structure.

Tattoos should not:

- Define the entire build.
- Guarantee specific outcomes.

Runs should remain adaptable.

---

# Pouch System

The pouch acts as the player's pool of available coins.

Encounter start:

- Deal a temporary selection of coins from the pouch.
- The player chooses which dealt coins to flip.
- Used coins are replaced from the pouch after score is tallied.

The exact refill count can be tuned later.

The pouch creates draft decisions and allows tricks to interact with hand refills, smuggled coins and other run resources.

---

# Round Structure

## Encounter Begins

Player is shown:

- Opponent
- Opponent Class
- Active Trick
- Enemy HP

Example:

The Forger

Trick:
Fake Credentials II

HP:
100

Reward Category:
Forgery Tricks

---

## Coin Selection

Player is dealt coins from the pouch.

Example:

- 6 coins dealt.
- 3 flip slots available.

Player chooses which coins to play.

This is an important strategic decision.

---

## Arrangement Phase

Player:

- Reorders coins.
- Uses positioning synergies.
- Uses pre-flip effects.

This phase happens before the flip.

---

## Call Phase

Player calls:

- Heads
  or
- Tails

Smuggling Tricks may then force extra hand coins onto overload slots before the flip.

---

## Flip Phase

Board coins flip, including any smuggled bodies.

Results are revealed.

---

## Trick Resolution Phase

Automatic effects begin.

Examples:

- Forged identities
- Sleight swaps and substitutions
- Decoy target reroutes
- Spotlight score-credit funnels
- Smuggling board overload
- Fated Flip payoffs
- Prestige packet replays
- Chain propagation
- Bounded copied payouts or triggers
- Discounted encores

This is the "Goldberg machine" moment.

No additional player input required.

Any movement, replacement, swap, copy, redirect, smuggle, replay or Chain effect must use an automatic target rule.

---

## Score Resolution

Final score is calculated.

Score is applied against enemy HP.

Used coins are then replaced from the pouch according to the current refill rules.

---

## Encounter Result

Success:

- Gain Influence
- Access Trick Reward

Failure:

- Run continues or ends depending on mode
- Reduced rewards

Reputation is awarded after the run finishes, win or lose.

---

# Enemy Classes

Enemies are rival cheats.

They do not play the same coin-flipping game as the player.

They do not generate scores.

Instead they modify the rules of the encounter.

Each enemy belongs to a class.

---

## Forger

Theme:

Forged credentials and copied payouts.

Reward Pool:

Forgery Tricks.

---

## Smuggler

Theme:

Hand overflow, contraband coins and illegal board capacity.

Reward Pool:

Smuggling Tricks.

---

## Card Shark

Theme:

Reading coins and manipulating odds.

Reward Pool:

Prediction? and Loaded Tricks.

---

## Fortune Teller

Theme:

Luck Meter engines and Fated Flip payoffs.

Reward Pool:

Fate Tricks.

---

## Pit Boss

Theme:

Control, pressure and house rules.

Reward Pool:

Misdirection and control-oriented Tricks.

---

## Magician

Theme:

Fast hands, cup work and substitutions.

Reward Pool:

Sleight Tricks.

---

## Showman

Theme:

Encores, finales and chain reactions.

Reward Pool:

Prestige and Chain Tricks.

---

# Trick System

Tricks are the primary build-defining mechanic.

A trick is a rule-breaking effect.

Examples:

- Borrowed Name
- Switcheroo
- Sleeve Pocket
- Planted Double
- Omen Engine
- Twist of Fate
- Look Over There
- Crooked Spotlight
- Encore
- Domino Line
- Copycat Jackpot

---

# Shared Trick Philosophy

Every trick can have:

1. Player version.
2. Enemy version.

The same concept is expressed from opposite sides.

Example:

Smuggling

Player:
Force extra hand coins into illegal board slots and multiply them into temporary contraband bodies.

Enemy:
Overload the encounter with extra pressure or force awkward hand coins into play.

---

Forgery

Player:
Forge coin identities and cash counterfeit payouts.

Enemy:
Stamp bad credentials or make weak pressure copy your strongest success.

---

Misdirection

Player:
Use Decoys to protect important coins and funnel cheap successful score credit into a Spotlight.

Enemy:
Make your useful automatic targeting hit the wrong coin or book credit onto a weak Decoy.

---

Fate

Player:
Fill the Luck Meter faster, boost Fountain Favor and cash out whole-flip Fated payoffs.

Enemy:
Pressure the player with meter-driven Fated events or punish careless Luck feeding.

---

Prestige

Player:
Replay one completed coin packet at a discounted encore value after resolution should be over.

Enemy:
Replay one completed pressure packet after the player thinks the act has ended.

---

Chain

Player:
Make triggered coins continue into random neighbours, then cash out Chained coins or deep Chain links.

Enemy:
Pressure jumps through neighbouring coins as a visible Chain.

---

This keeps the world coherent.

This is a design goal, not a requirement that every early implementation must satisfy immediately.

---

# Trick Acquisition

After defeating an opponent:

Choose from multiple trick offers.

Example:

Defeat Forger.

Choose:

- Borrowed Name
- Fake Credentials
- Copycat Jackpot
- Generic Trick

Tricks offered should primarily come from the defeated enemy's class.

A small percentage should be wildcard offers.

This preserves adaptation and replayability.

---

# Trick Tiers

Tricks can exist in multiple strengths.

Example:

Borrowed Name I

One coin replaces its identity with slot 1 for one payout.

---

Fake Credentials II

One coin keeps its real identity and adds a forged identity for one check.

---

Copycat Jackpot III

Multiple forged coins copy a bounded payout or trigger from the slot 1 template.

---

Look Over There I

One hostile target is redirected to a Decoy.

---

Crooked Spotlight I

One cheap successful coin books its score credit onto a Spotlight.

---

Stolen Applause II

Up to two successful coins funnel capped score credit into the Spotlight.

---

Sleeve Pocket I

One real unselected hand coin enters an overload slot after the call.

---

Backroom Refill I

Refill one extra coin after the flip to keep Smuggling hands stocked.

---

Planted Double II

The first smuggled coin creates a temporary contraband copy for this flip.

---

Overloaded Table III

Board overload pays a capped bonus for extra coin bodies.

---

Omen Engine I

Positive Luck gain adds extra Luck Meter progress.

---

Fountain Pact I

Fountain Favor contributes more Luck.

---

Twist of Fate II

A Fated Flip gains an extra whole-flip payoff or retrigger.

---

Fate Uncapped III

Luck can keep filling during a Fated Flip and prepare another Fated Flip.

---

Encore I

Replay one resolved coin's completed packet at 20% value.

---

Curtain Call II

Replay the last effect-triggering coin packet at 20% value.

---

Impossible Finale III

Replay the highest-impact eligible packet at reduced value.

---

Domino Line I

Scoring or Chained coins have a 50% chance to trigger a random neighbour.

---

Chained Payout I

Chained coins score 1.25x.

---

Deep Link II

The third coin or deeper in a Chain gains a payoff.

This allows stronger enemies and deeper progression.

---

# Hidden Tricks

Some tricks cannot be purchased.

They are discovered through hidden challenges.

Examples:

- All Heads three rounds in a row.
- Trigger Encore five times.
- Reach a specific score threshold.

These discoveries should feel rare and memorable.

---

# Enemy HP

Encounters use enemy HP.

Example:

100 HP

The player wins by producing enough score across flips to beat that HP value.

HP keeps the win condition clear while still allowing score output to vary.

The player should build enough margin to defeat the opponent, not solve an exact score puzzle.

High overkill should be rewarded with extra Influence and other performance rewards.

---

# Long-Term Progression Fantasy

Early Game:

Small-time gambler.

Simple archetype coins.

Minor tricks.

---

Mid Game:

Known cheat.

Forged identities.

Decoy defenses.

Board overload smuggling.

Foretold coin reads.

---

Late Game:

Legendary con artist.

Massive chain reactions.

Reality-bending tricks.

Fated Flip payoff chains.

Complex trick combinations.

---

# Success Criteria

A successful run should feel like:

"I found a loophole."

A successful build should feel like:

"I built the perfect trick machine."

A successful late-game run should feel like:

"The House has absolutely no idea how I got away with this."
