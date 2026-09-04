# Cheating Gambler Mechanics

Core fantasy:

> The player is not lucky.
> The player is cheating.

Coins are simple objects. Tricks, scams, marks, counterfeits and hidden moves are what break the rules.

---

# Mechanic Tags

Use these as code-facing mechanic families:

- `weighted`
- `prediction`
- `sleight`
- `counterfeit`
- `smuggle`
- `fate`
- `prestige`
- `chain`

---

# `weighted`

Manipulates probability before results exist by adding Weight toward a side, usually the player's call.

Weighted does not convert, reroll, or repair outcomes after the flip. Post-result fixes belong to other Trick families.

## Weighted Palm

Before flip, the first selected Weighted Coin gets Matching Call chance. If there are none, the first coin gets it instead.
Example: base 50/50 becomes 75/25 toward the call.

Tags:

- `weighted`
- `weight`
- `auto`

Hook:

- `before_flip`

---

## Headside Edge

On Heads Flip, selected coins get +12% Heads Chance. Double for Weighted Coins.

Tags:

- `weighted`
- `weight`
- `heads`

Hook:

- `before_flip`

---

## Tailside Edge

On Tails Flip, a random selected Weighted Coin gets +30% Tails Chance.

Tags:

- `weighted`
- `weight`
- `tails`

Hook:

- `before_flip`

---

## Heavy Payout

Weighted coins score double when their weighted result succeeds.

Tags:

- `weighted`
- `weight`
- `weighted_payoff`
- `score_scaling`

Hook:

- `before_coin_score`

---

# `prediction` — Prediction Tricks

Current refined direction: Prediction uses **Foretold coins** and **Ancient Patterns**.

Prediction reveals future results on dealt coins before the player selects their hand. The player does not call individual coins. The player uses visible foreknowledge to choose and order coins, then payoff Tricks reward that choice.

Prediction has three elements:

- reveal: a dealt coin becomes Foretold and shows its future Heads/Tails result
- fulfillment: selected Foretold coins pay off when their known result becomes Matching Call
- Ancient Patterns: visible H/T pattern contracts create fallback rewards when raw call value is weak

Prediction should not convert failures, reroll coins, or fix results after the flip. Those belong to other Trick families.

Known problems:

- If too many results are revealed, the best line may become obvious: pick three foretold Heads for a Heads Flip.
- If fulfillment rewards are uncapped, Foretold coins become automatic value instead of a selection puzzle.
- If too many Ancient Patterns exist, the mechanic can devolve into passive "sometimes extra score" variance.
- The mechanic depends on clear pre-selection UI; the coin itself must show the foretold result without slowing the round.
- Implementation must define whether a foretold result is locked at deal time and how later Weighted, Fate, or result-modifying Tricks interact with it.

## See Behind the Veil

After deal, Foretell a random Marked Coin. If there are none, Foretell a random dealt coin.

Tags:

- `marked`
- `foretold`
- `read`
- `auto`

Hook:

- `after_deal_before_selection`

---

## Fulfilled Fate

First selected Foretold Coin with Matching Call scores 2x. Marked Coins score 4x instead.

This rewards using known information without adding individual coin-call UI.

Tags:

- `marked`
- `foretold`
- `fulfillment`
- `score_scaling`

Hook:

- `before_coin_score`

---

## Heads Pact

On Heads Flip, Foretold Coins with Matching Call score 1.25x.

Tags:

- `prediction`
- `heads`
- `foretold`
- `score_scaling`

Hook:

- `before_coin_score`

---

## Tails Pact

On Tails Flip, Foretold Coins with Matching Call score 1.25x.

Tags:

- `prediction`
- `tails`
- `foretold`
- `score_scaling`

Hook:

- `before_coin_score`

---

## Ancient Pattern: T-H-T

If selected Foretold coins read left-to-right as T-H-T, gain a bonus.

Ancient Patterns are a backup strategy: if the player sees two Tails and one Heads but cannot win cleanly by just calling Tails, the pattern reward can make that hand worth selecting.

Tags:

- `marked`
- `foretold`
- `ancient_pattern`
- `pattern`

Hook:

- `before_score`

---

# `sleight` — Sleight of Hand Tricks

Sleight of Hand is physical coin manipulation: fast hands, street-hustler swaps, palming and three-cup rearrangements.

Vanishing Coin is the coin archetype for Sleight of Hand. Its half-seen magician's body makes it easier to palm, swap and rearrange; Hollow Coin stays reserved for Smuggling concealment and overload.

The family changes which coin body occupies which resolved result slot. It does not change the result itself, reroll coins, weight odds, reveal prophecy or create copies.

Core direction:

1. Swap selected coin positions after the flip.
2. Palm a failed committed coin back into hand instead of spending it.
3. Keep result slots fixed while local coin bodies secretly change places.

Overlap is allowed, but the cause should stay physical:

- Prestige replays completed Outcomes at a discount.
- Momentum creates live coin-to-coin propagation.
- Sleight of Hand changes which coin body occupies an already-resolved result slot.

## Switcheroo

After flip, your strongest Miss switches places with your weakest Match if the Miss is worth more.

Example: results are `T T H`, the player called `H`, and the strongest Miss is worth more than the weakest Match. Switcheroo trades those bodies so the valuable coin scores without changing any result.

Tags:

- `sleight`
- `swap`
- `match`
- `miss`

Hook:

- `after_flip_before_score`

---

## Vanishing Act

After flip, palm a failed regular committed coin back into hand instead of spending it. Tier I saves the activating Miss, Tier II saves the best local Miss, and Tier III saves the best Miss on the table. A palmed body contributes no score this flip; Contraband is never eligible.

## Three-Card Monte

After flip, automatically rearrange regular committed bodies in a local group, but only if the change strictly improves immediate score. Tier I chooses a random improving neighbour swap, Tier II chooses the best neighbour swap, and Tier III chooses the best three-slot permutation. Results and slot effects stay fixed; Contraband does not move.

---

# `counterfeit` — Forgery Tricks

Forgery is a hybrid support family. It does not build an isolated machine; it counterfeits more value and activations for another family already represented on the table.

Core positioning contract:

1. Commit a real Blank/Forgery Coin.
2. Place a genuine non-Forgery family coin immediately to its left.
3. The left coin visibly supplies the family credentials before execution.
4. The Forgery Coin either copies its completed Outcome or uses those credentials to imitate eligible Tricks.
5. Forged activations never recurse and never change either coin's locked real family.

Current lines:

- Fake Credentials I-III: a missing Forgery Coin copies 50% / 75% / 100% of its successful left neighbour's completed root Outcome.
- Borrowed Name I-III: before Flip, a Blank locks and imitates up to one / two / three eligible Tricks, capped at Tier I / II / III, from its left neighbour's family.
- Forged Signature I-III: before Flip, a Blank locks one highest-tier eligible Trick, capped at Tier I / II / III, from its left neighbour's family.

Balance constraints:

- Forgery consumes both limited Trick slots and coin-pouch space that could have gone directly to the primary family.
- Low-tier Forgery cannot copy high-tier Tricks.
- Borrowed Name selects lower-tier foundations first; Forged Signature selects the highest eligible tier, with stable board order as tie-break.
- The Blank Coin is the activation source for imitated Tricks, so copied conditions can still fail.
- A forged activation cannot activate Forgery, cannot be forged again, and cannot bypass Block, Weaken, or Jam.
- Slot 1, another Forgery Coin to the left, a Smuggled source, or a Contraband source is invalid.

## Fake Credentials I-III

If the Forgery Coin misses and its genuine left neighbour produced a positive root Outcome, copy 50% / 75% / 100% of that recorded Outcome. The Forgery Coin remains a miss and the copied score is recorded separately from Prestige Replay.

## Borrowed Name I-III

Before Flip, lock a bounded package from the genuine left neighbour's family:

- I: one eligible Tier I Trick.
- II: up to two eligible Tier I-II Tricks.
- III: up to three eligible Tier I-III Tricks.

Each copied Trick runs in its normal phase using the Blank Coin as source. This provides flexibility when the hand lacks enough genuine family coins, but remains less efficient than a pure-family coin until the player invests in the line.

## Forged Signature I-III

Before Flip, lock one highest-tier eligible Trick from the genuine left neighbour's family:

- I can repeat Tier I.
- II can repeat Tier I-II.
- III can repeat Tier I-III.

This is the concentrated payoff line for hybrid engines such as Prestige + Forgery. It repeats one valuable Trick, not the entire family package.

## Forgery Audit

The family succeeds when the player can answer all four questions before execution: which Blank is forging, which genuine coin supplies its credentials, which Tricks are eligible, and which specific Trick Forged Signature will repeat. The setup UI must show `F+n` on every Trick scheduled to receive forged activations.

# `smuggle` — Smuggling Tricks

Smuggling is illegal capacity: overloading committed slots with too many real coin bodies.

The family physically conceals Hollow Coins from hand beside committed Hollow Coins after the normal selection/arrangement/call. A normal round might select 3 coins and flip 3. A Smuggling build wants to select 3, call, then overload those slots and flip 4, 5 or more coin bodies.

The exact smuggled instance is normally a surprise. `Highest quality` and `lowest quality` restrict the eligible material band first, then randomly choose an instance inside that band. Contraband is visually fanned beside its activating coin and does not activate Tricks.

Core direction:

1. Buy and keep enough coins to flood the hand.
2. Use refill/hand-size support so the hand refills to more coins after each flip.
3. Force unselected hand coins onto the board as extra illegal board bodies.
4. Optionally multiply a smuggled coin into temporary contraband copies for this flip.
5. Cash out when the board is overloaded.

Boundaries:

- Smuggling adds extra board bodies or illegal slots.
- Sleight of Hand moves existing selected coin bodies through resolved slots.
- Forgery changes identity, payout or trigger checks; it does not add physical resolving bodies.
- Weighted/Fate/Prediction affect probability, information or outcomes, not board capacity.
- Smuggling is inbound-only. It never extracts, palms, replaces or swaps an active body; those are Sleight operations.

Multiplication rule:

- A real owned XYZ coin can enter the board from hand and become two, three or more XYZ board bodies for the flip.
- Those extra bodies are temporary contraband copies.
- After the flip, only the original single XYZ coin remains in the pouch/hand state.
- Copies may need explicit caps, but the design can leave room for natural caps from hand size, refill and board readability.

Known problems:

- Too many coins can overload the UI, logs and resolution pacing.
- If every extra coin scores normally with no friction, the family becomes pure quantity scaling.
- Without refill support, Smuggling empties the hand too quickly.
- Coin multiplication is Forgery-adjacent; keep the boundary clear: Smuggling copies physical board presence, not identity credentials, payout records or recursive trigger history.
- `max_board_coins` and `no_recursive_multiplication` should remain available if natural caps are not enough.

## Hidden Pocket

Gain +1 max Flip Slot for the run.

Tags:

- `smuggle`
- `slots`

Hook:

- `on_acquire`

---

## Hidden in Plain Sight

After call, move one real unselected hand coin onto the board in an overload slot. It flips and resolves as an extra board coin.

Tags:

- `smuggle`
- `hand`
- `board_overload`
- `extra_coin`

Hook:

- `after_call_before_flip`

---

## Off the Books

After a flip where at least one coin was smuggled, draw one extra coin into the next hand if available.

Tags:

- `smuggle`
- `refill`
- `hand`
- `stockpile`

Hook:

- `on_batch_end`
- next hand deal consumes the banked draw

---

## Planted Double

50% chance to copy a random smuggled coin into a temporary contraband overload slot.

Example: one Hollow Coin enters from hand, but two Hollow coin bodies appear on the board for this flip. After resolution, only the original owned Hollow Coin remains in the pouch.

Tags:

- `smuggle`
- `multiply`
- `contraband_copy`
- `temporary`

Hook:

- `after_call_before_flip`

---

## Embarrassment of Riches

Matching coins that were not selected in the original flip but still got flipped score 2x.

This is the payoff branch. The build should feel like the table is covered in coins, and every extra smuggled body visibly matters.

Tags:

- `smuggle`
- `overloaded_board`
- `payoff`
- `extra_coin`

Hook:

- `before_coin_score`

---

# `fate` — Fate Tricks

Fate Tricks are about the Luck Meter and Fated Flip only.

They accelerate Luck gain, amplify Fountain Favor, reward Fated Flips, and eventually let advanced builds keep filling Luck during Fated Flips so Fated Flips can chain.

Fate does not create coins, copy coins, move coins, forge identities, reroll coins, Weight odds, or change individual coin results. Weighted owns individual probability/result manipulation. Fate owns the global meter and the global Fated Flip payoff layer.

Core direction:

1. Fill the Luck Meter faster.
2. Improve or multiply Luck gain, including Fountain Favor bonuses.
3. Cash out harder when the current flip is Fated.
4. At high tier, lift the normal Fated Flip Luck-gain limit and allow chained Fated Flips with caps.

Known problems:

- Flat `+1 luck` is bland unless attached to a clear meter engine or Fated Flip plan.
- Fated Flip chaining can dominate the whole game if it has no cap or cost.
- Fated Flip retriggers should be whole-flip payoff effects, not individual coin targeting.
- Stored-value Fate designs are removed for now because they overlap with delayed-score/Debt space.
- Copied or temporary coins do not become a Fate concern; those belong to Forgery or Smuggling.

## Omen Engine

When a positive Luck gain event happens, add a small extra Luck gain to the Luck Meter.

This is the basic accelerator. It should make successful calls feel like they are feeding destiny, not like one specific coin got fixed.

Tags:

- `fate`
- `luck_meter`
- `luck_gain`
- `accelerator`

Hook:

- `luck_gain`

---

## Fountain Pact

When Fountain Favor adds Luck, boost that Fountain Favor contribution.

This gives Fate a clean bridge into the Fountain without changing coin results or odds.

Tags:

- `fate`
- `fountain_favor`
- `luck_gain`
- `accelerator`

Hook:

- `luck_gain`

---

## Twist of Fate

During a Fated Flip, gain an extra Fated Flip payoff such as doubled final Fated Flip score or one whole-flip Fated resolution retrigger.

The effect applies to the Fated Flip layer as a whole. It should not choose one coin, reroll one coin, or change one coin's result.

Tags:

- `fate`
- `fated_flip`
- `payoff`
- `retrigger`

Hook:

- `during_fated_flip`

---

## Fate Uncapped

During a Fated Flip, allow positive Luck gain instead of suppressing it. If the meter fills, prepare another Fated Flip.

This is the chase version of the family: build enough Luck acceleration and Fated Flip payoff to chain destiny itself.

Tags:

- `fate`
- `fated_flip`
- `chain_fated_flip`
- `uncapped`

Hook:

- `during_fated_flip`

---

# `prestige`

Replays completed Outcomes.

Prestige Tricks are the finale, encore and impossible final act. The coin already resolved, its Score contribution already happened, and then Prestige makes that completed Outcome happen again at reduced value.

Prestige is about bending what counted as real. It does not add physical coin bodies, copy coin identities, move coins, reroll results, Weight odds, or retarget effects. It replays the recorded Outcome of a finished coin.

Core rule:

> Replay the record, not the world.

When a coin resolves, the engine records an **Outcome**: score produced, result, position, identity and payout context. Prestige replays that Outcome as a `prestige_replay`, usually at **20%** of the recorded Score contribution, using the same result and position.

Example:

- Coin A scored 100.
- Prestige replay at 20% grants +20.
- Impossible Finale III replays every eligible Outcome at 75%.

Known problems:

- This may become the most powerful family because it multiplies every synergy already built.
- Full-value replays will break the game; default replay should be discounted, around 20%.
- Replays should not choose new targets, roll new results or create new coin bodies.
- Replayed Outcomes should not start fresh Momentum propagation unless a Momentum Trick explicitly allows it.
- Mark replayed output as `prestige_replay` and enforce `no_recursive_prestige`.

Prestige and Momentum boundary:

- Prestige replays a completed Outcome.
- Momentum modifies live propagation from one coin into another.
- If the original Outcome included Momentum value, Prestige can replay that recorded Momentum value at the discount.
- Prestige does not rerun Momentum logic by default.
- A later Momentum payoff may explicitly say Prestige replays count as Momentum sources once.

## Encore

After all effects resolve, choose one completed coin Outcome and replay it at 20% value, preferring Bent Coins. Bent Coins replay at double value.

Tags:

- `prestige`
- `outcome`
- `prestige_replay`
- `encore`

Hook:

- `after_all_effects`

---

## Curtain Call

After all effects resolve, replay one random completed coin Outcome at 20% value, preferring Bent Coins. Curtain Call II replays two random completed Outcomes and cannot pick the same Outcome twice.

Tags:

- `prestige`
- `curtain_call`
- `prestige_replay`
- `outcome`

Hook:

- `after_all_effects`

---

## Impossible Finale

Replay the highest-value eligible Outcome at reduced value. Impossible Finale I replays the best Outcome at 20%, II replays the top two at 20%, and III replays every eligible Outcome at 75%.

Tags:

- `prestige`
- `finale`
- `outcome`
- `prestige_replay`

Hook:

- `after_all_effects`

---

# `momentum`

Creates live trigger propagation.

Momentum Tricks are about one coin keeping motion moving into another coin, then another, then another. They do not replay finished Outcomes like Prestige and they do not counterfeit bounded family activations like Forgery. Momentum manipulates live cause-and-effect between coins.

User-facing wording should be simple:

- "Has a chance to trigger another coin."
- "Coins In Motion have a chance to continue Momentum."

Keyword direction:

- A coin is **In Motion** if it was triggered by another coin instead of by the original flip resolution.
- A **Momentum Link** is one trigger from coin A into coin B.
- Internal trace fields still record source, link and depth for deterministic replay.
  - original source = depth 0
  - first triggered coin = depth 1
  - next triggered coin = depth 2

Known problems:

- Momentum can become unreadable if every trigger branches freely.
- Use simple odds such as 50% per link and hard propagation caps.
- Momentum payoffs should reward coins In Motion, not make Flywheel Coins score double by default.
- Momentum can synergize with Prestige if a Momentum Trick explicitly allows `prestige_replay` events to count as Momentum sources once.

## Keep It Rolling

After a scoring coin, there is a 50% chance to trigger a neighbouring Flywheel Coin if possible, otherwise a random neighbouring coin.

Tags:

- `momentum`
- `in_motion`
- `random_neighbor`
- `propagation`

Hook:

- `after_coin_score`

---

## Follow Through

Coins In Motion score more for each Momentum link that carried them.

Tags:

- `momentum`
- `in_motion`
- `payoff`
- `score_scaling`

Hook:

- `before_coin_score`

---

## Ripple

Ripple is the tiered Momentum line.

- Ripple I: 50% chance to trigger a random neighbour, then a 25% chance to continue Momentum.
- Ripple II: 75% chance to trigger the neighbour to the left, then a 50% chance to continue Momentum to the left.
- Ripple III: 75% chance to trigger neighbours in both directions, then a 50% chance to continue Momentum in each direction.

Tags:

- `momentum`
- `ripple`
- `propagation`

Hook:

- `after_coin_score`

---

# Recommended Implementation Shape

Each mechanic should be data-driven.

Example shape:

```lua
{
  id = "switcheroo",
  name = "Switcheroo",
  tags = { "sleight", "swap", "match", "miss" },
  hook = "after_flip_before_score",
  effect = {
    op = "swap_coins",
    target_a = "highest_base_score_miss",
    target_b = "lowest_base_score_match",
    require_source_base_score_greater_than_target = true,
    preserve_result_slots = true,
  },
}
```

Forgery example shape:

```lua
{
  id = "forged_signature_iii",
  name = "Forged Signature III",
  tags = { "counterfeit", "activation", "blank", "neighbor" },
  hook = "copied_trick_phase",
  effect = {
    op = "forge_trick_activations",
    source = "genuine_left_neighbor_family",
    mode = "forged_signature",
    maxTier = 3,
    maxTricks = 1,
  },
  limits = { "once_per_activation", "no_recursive_forgery" },
}
```

Smuggling example:

```lua
{
  id = "hidden_in_plain_sight",
  name = "Hidden in Plain Sight",
  tags = { "smuggle", "hand", "board_overload", "extra_coin" },
  hook = "after_call_before_flip",
  effect = {
    op = "smuggle_coin_from_hand",
    target = "first_unselected_hand_hollow_else_first_hand_coin",
    slot = "new_overload_slot",
    mark = "smuggled_coin",
  },
  limits = { "once_per_flip", "max_board_coins" },
}
```

Fate example:

```lua
{
  id = "omen_engine",
  name = "Omen Engine",
  tags = { "fate", "luck_meter", "luck_gain", "accelerator" },
  hook = "luck_gain",
  effect = {
    op = "add_luck",
    amount = 2,
    target = "luck_meter",
  },
  limits = { "once_per_flip", "meter_only", "no_individual_coin_targeting" },
}
```

Prestige example:

```lua
{
  id = "encore",
  name = "Encore",
  tags = { "prestige", "outcome", "prestige_replay", "encore" },
  hook = "after_all_effects",
  effect = {
    op = "replay_resolution_packet",
    target = "random_completed_bent_outcome_else_random_completed_outcome",
    scale = 0.2,
    mark = "prestige_replay",
    use_original_targets = true,
  },
  limits = { "once_per_flip", "outcome_replay_only", "no_recursive_prestige", "no_live_chain_from_replay" },
}
```

Momentum example:

```lua
{
  id = "keep_it_rolling",
  name = "Keep It Rolling",
  tags = { "momentum", "in_motion", "random_neighbor", "propagation" },
  hook = "after_coin_score",
  effect = {
    op = "trigger_random_neighbor",
    chainChance = 0.5,
    preferFamily = "momentum",
    mark = "in_motion",
    track = { "momentum_source", "momentum_depth" },
  },
  limits = { "max_momentum_depth", "no_momentum_reentry", "max_triggers" },
}
```

---

# Design Rules

## Good mechanic

Feels like cheating.

Examples:

- replace coin after flip
- swap coin bodies through resolved result slots
- substitute a stronger hand coin into a fixed result slot
- forge a failed Blank Coin as a random successful Identity
- make several weak coins share a fake signed identity
- overload the board with real hand coins after the call
- multiply one smuggled coin into temporary contraband copies
- accelerate the Luck Meter toward a Fated Flip
- cash out extra payoff because the whole flip is Fated
- lift the Fated Flip Luck-gain limit so another Fated Flip can chain
- replay a completed coin Outcome at 20% as a finale
- let triggered coins have a 50% chance to trigger another random coin
- reward coins In Motion
- reroll failure
- pretend Tails is Heads
- replay a completed Outcome at a discount
- cash out when too many coins are on the table

## Weak mechanic

Feels like plain math.

Examples:

- +5 score
- +10% multiplier
- +1 luck
- +15% Heads

These can exist, but should mostly support the stronger cheating mechanics.

---

# Content Direction

The player should feel like they are building a scam engine.

Early run:

- Weighted Tricks that add small Weight
- small rerolls
- small result manipulation

Mid run:

- Foretold coins and Ancient Patterns
- physical swaps and substitutions
- forged slot identities and counterfeit payout checks
- board-overload Smuggling and refill support

Late run:

- stronger physical swaps and substitutions
- bounded copied payouts and triggers
- temporary contraband multiplication with caps if needed
- Fated Flip payoffs and capped Fated Flip chains
- discounted Prestige Outcome replays
- live Momentum propagation and In Motion payoffs

The fantasy should escalate from:

> I improved my odds.

To:

> I cheated the table.

To:

> I rewrote the result after the flip.

To:

> The House has no idea what just happened.
