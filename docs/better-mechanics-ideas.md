# Cheating Gambler Mechanics

Core fantasy:

> The player is not lucky.
> The player is cheating.

Coins are simple objects. Tricks, scams, marks, counterfeits and hidden moves are what break the rules.

---

# Mechanic Tags

Use these as code-facing mechanic families:

- `loaded`
- `marked`
- `sleight`
- `counterfeit`
- `misdirection`
- `smuggle`
- `fate`
- `prestige`
- `chain`

---

# `loaded`

Manipulates probability before results exist by adding Weight toward a side, usually the player's call.

Loaded does not convert, reroll, or repair outcomes after the flip. Post-result fixes belong to other Trick families.

## Weighted Palm

Before flip, one selected coin gains Weight toward the player's call.
Example: base 50/50 becomes 75/25 toward the call.

Tags:

- `loaded`
- `weight`
- `call_bias`
- `auto`

Hook:

- `before_flip`

---

## Loaded Edge

Before flip, adjacent coins gain Heads/Tails Weight based on the player call or position.

Tags:

- `loaded`
- `weight`
- `position`

Hook:

- `before_flip`

---

## Heavy Payout

Weighted coins score double when their weighted result succeeds.

Tags:

- `loaded`
- `weight`
- `weighted_payoff`
- `score_scaling`

Hook:

- `before_coin_score`

---

# `marked` — Prediction Tricks (?)

This family is still under a question mark.

Current refined direction: Prediction uses **Foretold coins** and **Ancient Patterns**.

Prediction reveals future results on dealt coins before the player selects their hand. The player does not call individual coins. The player uses visible foreknowledge to choose and order coins, then payoff Tricks reward that choice.

Prediction has three elements:

- reveal: a dealt coin becomes Foretold and shows its future Heads/Tails result
- fulfillment: selected Foretold coins pay off when their known result is used well, usually by matching the player's call
- Ancient Patterns: visible H/T pattern contracts create fallback rewards when raw call value is weak

Prediction should not convert failures, reroll coins, or fix results after the flip. Those belong to other Trick families.

Known problems:

- If too many results are revealed, the best line may become obvious: pick three foretold Heads and call Heads.
- If fulfillment rewards are uncapped, Foretold coins become automatic value instead of a selection puzzle.
- If too many Ancient Patterns exist, the mechanic can devolve into passive "sometimes extra score" variance.
- The mechanic depends on clear pre-selection UI; the coin itself must show the foretold result without slowing the round.
- Implementation must define whether a foretold result is locked at deal time and how later Loaded, Fate, or result-modifying Tricks interact with it.

## See Behind the Veil

When coins are dealt, reveal the future result of one random dealt coin before selection.

The revealed coin becomes Foretold.

Tags:

- `marked`
- `foretold`
- `read`
- `auto`

Hook:

- `after_deal_before_selection`

---

## Fulfilled Fate

The first selected Foretold coin that matches the player's call scores double.

This rewards using known information without adding individual coin-call UI.

Tags:

- `marked`
- `foretold`
- `fulfillment`
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

# `sleight` — Sleight Tricks

Sleight is physical coin manipulation: fast hands, street-hustler swaps, three-cup moves and substitutions.

The family changes which coin body occupies which resolved result slot. It does not change the result itself, reroll coins, weight odds, reveal prophecy or create copies.

Core direction:

1. Swap selected coin positions after the flip.
2. Substitute a selected coin body with a real coin from the dealt hand.
3. Occasionally rescore a moved layout when the rescore is caused by coins changing places.

Overlap is allowed, but the cause should stay physical:

- Prestige replays completed resolution packets at a discount.
- Chain creates live coin-to-coin propagation.
- Sleight retriggers because the cups moved and different coin bodies now occupy the result slots.

## Switcheroo

After flip, swap two selected coin bodies before scoring while preserving the resolved result slots.

Example: results are `T T H`, the player called `H`, and the best coin is sitting in slot 1. Switcheroo swaps that coin body into the `H` slot so the valuable coin scores without changing any result.

Tags:

- `sleight`
- `position`
- `swap`
- `slot`

Hook:

- `after_flip_before_score`

---

## Spin Me Baby One More Time

After scoring and normal trigger resolution, rearrange one or more selected coins and score the moved layout again once.

The same resolved Heads/Tails slots are reused. Position, edge and neighbour effects may be checked again because the coin bodies physically moved.

Tags:

- `sleight`
- `position`
- `move`
- `retrigger`
- `rescore`

Hook:

- `after_all_effects`

Notes:

- limit to once per flip
- do not freely replay unrelated Tricks unless they explicitly listen for moved-layout scoring
- this is the three-cups / street-hustler expression of Sleight

---

## False Bottom

After flip, replace the weakest selected coin body with a random stronger coin from the unselected dealt hand.

The selected slot keeps its resolved result. The Trick is a physical substitution, not a result fix.

Tags:

- `sleight`
- `replace`
- `hand`
- `slot`
- `auto`

Hook:

- `after_flip_before_score`

Notes:

- if the effect adds the hand coin as an extra board body instead of replacing a selected body, it starts becoming Smuggling
- if it copies a coin identity instead of moving a real coin body, it becomes Forgery

---

# `counterfeit` — Forgery Tricks

Forgery is position-based identity fraud: fake papers, forged signatures, stamped credentials and counterfeit payout records.

The family changes what trigger, payout or requirement checks believe a coin is. It does not add extra real coins or coin slots; that is Smuggling. It does not move coin bodies; that is Sleight. It does not move score away from another source; that is Misdirection.

Core loop:

1. Choose or create a template identity: slot 1, last slot, first success, nearest success, matching tag or strongest visible success.
2. Forge one or more weak/failing coins so they count as that template for a bounded check.
3. Cash out with a payoff that cares about forged identity, copied payout or copied trigger behavior.

Tier direction:

- Tier I: replace identity for one payout or requirement check.
- Tier II: additive identity; the coin keeps its real identity and also gains fake credentials.
- Tier III: copy two templates or let multiple coins share the same signed identity.

Known problems:

- If every Trick copies the highest scoring coin automatically, the family becomes bland "make weak coins better" scaling.
- Source constraints like slot 1 and last slot should make the player arrange and choose what to copy.
- Copied triggers can spiral, so Forgery needs `once_per_flip`, `one_trigger_only`, `no_self_trigger` and `no_recursive_copy` limits.
- Temporary physical copies belong to Smuggling when they add extra slots or extra resolving coin bodies.

## Borrowed Name

One failed selected coin forges the identity of the coin in slot 1 for one payout or requirement check.

The target's result does not change and it does not become successful. It simply presents slot 1's papers when the payout is calculated.

Tags:

- `counterfeit`
- `identity`
- `slot_1`
- `replace_identity`

Hook:

- `before_coin_score`

---

## Fake Credentials

One selected coin keeps its real identity and also gains a fake tag, archetype or material from the last-slot coin for the current check.

Example: a Hollow Coin with forged Heavy credentials remains Hollow and also counts as Heavy for a payout or requirement.

Tags:

- `counterfeit`
- `credentials`
- `additive_identity`
- `last_slot`

Hook:

- `condition_check`

---

## Copycat Jackpot

If slot 1 succeeds or scores, up to two forged coins may copy its payout and one eligible non-recursive trigger.

This is the chase fantasy: failures can behave like the strongest successful template, but only through explicit forged identity and strict caps.

Tags:

- `counterfeit`
- `copy_payout`
- `copy_trigger`
- `slot_1`
- `chase`

Hook:

- `after_coin_score`

---

## Forgery Audit

If two or more selected coins share an identity through real or forged credentials, gain a bonus.

This is the cleaner spender for the family: it rewards making a convincing fake set instead of only copying raw score.

Tags:

- `counterfeit`
- `forged_set`
- `identity_match`
- `payoff`

Hook:

- `before_score`

---

# `misdirection` — Misdirection Tricks

Defensive control first, score funneling second.

Misdirection makes the wrong coin get targeted, credited or paid. It does not move coin bodies, forge identities, add extra coins or slots, change Heads/Tails results, reroll coins or manipulate odds.

The family is allowed to be a support/defense family. Its main job is protecting important coins from enemy skills and hostile targeting through Decoys. Its offensive branch redirects successful score credit into a Spotlight coin.

Core direction:

- mark cheap or expendable coins as Decoys
- reroute enemy Tricks or hostile automatic targets to Decoys
- mark one important coin as the Spotlight
- redirect a capped number of successful scoring actions into the Spotlight

Boundaries:

- Sleight physically moves coins through slots
- Forgery changes what a coin is treated as
- Smuggling adds extra hand coins, overload slots or temporary contraband copies
- Misdirection keeps all coins, results and identities fixed, then changes who receives the target, credit or payout

Known problems:

- if the family only funnels score, it becomes narrow and boring
- if every score funnel automatically chooses the best coin, it becomes an obvious support button
- if Decoys cancel too many enemy effects, defensive builds become passive immunity
- target rerouting needs clear UI/logs so the player sees which Decoy protected which coin
- redirected score credit needs caps and source tracking so it does not become Chain-style recursion

Avoid blame-transfer framing for now. Decoy protection is the cleaner defensive fantasy.

---

## Look Over There

When an enemy Trick or hostile automatic effect targets an important player coin, redirect that target to a cheap Decoy.

This is the core defensive Misdirection piece: the wrong coin gets targeted, but no coin moves and no identity changes.

Tags:

- `misdirection`
- `decoy`
- `target_redirect`
- `defense`

Hook:

- `target_selection`

---

## Crooked Spotlight

Redirect one successful cheap coin's scoring action into the highest-base-score successful coin.

The source coin still succeeded, but the score credit is booked onto the Spotlight instead of scoring as itself.

Tags:

- `misdirection`
- `spotlight`
- `score_credit`
- `score_funnel`

Hook:

- `before_coin_score`

---

## Stolen Applause

If several coins succeed, up to two cheap successful coins send their scoring credit to the Spotlight.

This is the stronger funnel branch: many coins did the work, but one expensive coin gets paid. It should be capped, visible in the log and non-recursive.

Tags:

- `misdirection`
- `spotlight`
- `score_credit`
- `multi_redirect`

Hook:

- `before_score`

---

# `smuggle` — Smuggling Tricks

Smuggling is illegal capacity: overloading the board with too many real coin bodies.

The family physically forces coins from hand onto the board after the normal selection/arrangement/call. A normal round might select 3 coins and flip 3. A Smuggling build wants to select 3, call, then shove extra hand coins into play and flip 4, 5 or far more coins.

Core direction:

1. Buy and keep enough coins to flood the hand.
2. Use refill/hand-size support so the hand refills to more coins after each flip.
3. Force unselected hand coins onto the board as extra illegal board bodies.
4. Optionally multiply a smuggled coin into temporary contraband copies for this flip.
5. Cash out when the board is overloaded.

Boundaries:

- Smuggling adds extra board bodies or illegal slots.
- Sleight moves existing selected coin bodies through resolved slots.
- Forgery changes identity, payout or trigger checks; it does not add physical resolving bodies.
- Misdirection reroutes targets or score credit.
- Loaded/Fate/Prediction affect probability, information or outcomes, not board capacity.

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

## Sleeve Pocket

After call, move one real unselected hand coin onto the board in an overload slot. It flips and resolves as an extra board coin.

Tags:

- `smuggle`
- `hand`
- `board_overload`
- `extra_coin`

Hook:

- `after_call_before_flip`

---

## Backroom Refill

After scoring, refill the hand with one extra coin so future Smuggling flips have enough bodies to shove onto the board.

Tags:

- `smuggle`
- `refill`
- `hand`
- `stockpile`

Hook:

- `refill_hand`

---

## Planted Double

The first real smuggled coin enters with one temporary contraband copy of itself.

Example: one Hollow Coin enters from hand, but two Hollow coin bodies appear on the board for this flip. After resolution, only the original owned Hollow Coin remains in the pouch.

Tags:

- `smuggle`
- `multiply`
- `contraband_copy`
- `temporary`

Hook:

- `after_call_before_flip`

---

## Overloaded Table

If the board has more coin bodies than the legal selected-slot limit, gain a capped bonus for each extra body or boost the first successful smuggled coin.

This is the payoff branch. The build should feel like the table is covered in coins, not like a single hidden post-score bonus appeared from nowhere.

Tags:

- `smuggle`
- `overloaded_board`
- `payoff`
- `extra_coin`

Hook:

- `before_score`

---

# `fate` — Fate Tricks

Fate Tricks are about the Luck Meter and Fated Flip only.

They accelerate Luck gain, amplify Fountain Favor, reward Fated Flips, and eventually let advanced builds keep filling Luck during Fated Flips so Fated Flips can chain.

Fate does not create coins, copy coins, move coins, forge identities, reroute score credit, reroll coins, Weight odds, or change individual coin results. Loaded owns individual probability/result manipulation. Fate owns the global meter and the global Fated Flip payoff layer.

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

Replays completed resolution packets.

Prestige Tricks are the finale, encore and impossible final act. The coin already resolved, its score and effects already happened, and then Prestige makes that completed impact happen again at reduced value.

Prestige is about bending what counted as real. It does not add physical coin bodies, copy coin identities, move coins, reroll results, Weight odds, or retarget effects. It replays the recorded effect of a finished coin.

Core rule:

> Replay the record, not the world.

When a coin resolves, the engine can record a `resolution_packet`: score produced, effects emitted, other coins affected, neighbour bonuses caused and payout events created. Prestige replays that packet as a `prestige_replay`, usually at **20%** of the original output, using the same result, position and affected targets.

Example:

- Coin A scored 100.
- Coin A gave neighbour B +50.
- Coin A triggered C for +30.
- Prestige replay at 20% grants A +20, B +10 and C +6.

Known problems:

- This may become the most powerful family because it multiplies every synergy already built.
- Full-value replays will break the game; default replay should be discounted, around 20%.
- Replays should not choose new targets, roll new results or create new coin bodies.
- Replayed packets should not start fresh Chain propagation unless a Chain Trick explicitly allows it.
- Mark replayed output as `prestige_replay` and enforce `no_recursive_prestige`.

Prestige and Chain boundary:

- Prestige replays a completed packet.
- Chain modifies live propagation from one coin into another.
- If the original packet included Chain value, Prestige can replay that recorded Chain value at the discount.
- Prestige does not rerun Chain logic by default.
- A later Chain payoff may explicitly say Prestige replays count as Chain sources once.

## Encore

After all effects resolve, choose one random resolved selected coin and replay its full recorded resolution packet at 20% value.

Tags:

- `prestige`
- `resolution_packet`
- `prestige_replay`
- `encore`

Hook:

- `after_all_effects`

---

## Curtain Call

After all effects resolve, replay the last coin that triggered an effect. Use the same affected targets and outputs, but scale the replay to 20%.

Tags:

- `prestige`
- `curtain_call`
- `prestige_replay`
- `late_trigger`

Hook:

- `after_all_effects`

---

## Impossible Finale

Replay the highest-impact eligible resolution packet at reduced value. Bent Coin packets are preferred because Bent Coin is the cleanest Prestige archetype.

Tags:

- `prestige`
- `finale`
- `bent`
- `prestige_replay`

Hook:

- `after_all_effects`

---

# `chain`

Creates live trigger propagation.

Chain Tricks are about one coin knocking into another, then another, then another. They do not replay finished packets like Prestige and they do not copy identity like Forgery. Chain manipulates live cause-and-effect between coins.

User-facing wording should be simple:

- "Has a chance to trigger another coin."
- "Triggered coins have a chance to trigger another random coin."

Keyword direction:

- A coin is **Chained** if it was triggered by another coin instead of by the original flip resolution.
- `chain_source` is the coin that emitted the link.
- `chain_link` is one trigger from coin A into coin B.
- `chain_depth` is how far from the original source.
  - original source = depth 0
  - first triggered coin = depth 1
  - next triggered coin = depth 2

The "third coin in the chain" is a Chained coin at `chain_depth >= 2`.

Known problems:

- Chain can become unreadable if every trigger branches freely.
- Use simple odds such as 50% per link and hard `max_chain_depth` caps.
- Chain payoffs should reward being Chained or deep in a Chain, not just duplicate all triggers forever.
- Chain can synergize with Prestige if a Chain Trick explicitly allows `prestige_replay` events to count as Chain sources once.

## Domino Line

When a coin scores, it has a 50% chance to trigger a random neighbour. If that neighbour was triggered, it has a 50% chance to trigger another random coin. Continue until the Chain roll fails or max depth is reached.

Tags:

- `chain`
- `chained`
- `random_neighbor`
- `propagation`

Hook:

- `after_coin_score`
- `after_trigger`

---

## Chained Payout

Chained coins score 1.25x.

Tags:

- `chain`
- `chained`
- `payoff`
- `score_scaling`

Hook:

- `before_coin_score`

---

## Deep Link

If the Chain reaches the third coin or deeper, the final Chained coin gains a bonus.

Tags:

- `chain`
- `chain_depth`
- `deep_chain`
- `payoff`

Hook:

- `after_trigger`
- `before_coin_score`

---

## Cascade

Each Chained coin boosts the next Chain link if the Chain continues.

Tags:

- `chain`
- `chained`
- `chain_link`
- `score_scaling`

Hook:

- `chain_step`

---

# Recommended Implementation Shape

Each mechanic should be data-driven.

Example shape:

```lua
{
  id = "switcheroo",
  name = "Switcheroo",
  tags = { "sleight", "position", "swap", "slot" },
  hook = "after_flip_before_score",
  effect = {
    op = "swap_coins",
    target_a = "highest_base_score_coin_in_failed_slot",
    target_b = "lowest_base_score_coin_in_successful_slot",
    preserve_result_slots = true,
  },
}
```

Forgery example shape:

```lua
{
  id = "borrowed_name",
  name = "Borrowed Name",
  tags = { "counterfeit", "identity", "slot_1", "replace_identity" },
  hook = "before_coin_score",
  effect = {
    op = "forge_identity",
    source = "slot_1",
    target = "lowest_base_score_failed_non_source",
    mode = "replace_identity_for_one_payout",
  },
  limits = { "once_per_flip", "one_payout_only" },
}
```

Smuggling example:

```lua
{
  id = "sleeve_pocket",
  name = "Sleeve Pocket",
  tags = { "smuggle", "hand", "board_overload", "extra_coin" },
  hook = "after_call_before_flip",
  effect = {
    op = "smuggle_coin_from_hand",
    target = "leftmost_unselected_hand_hollow_else_leftmost_hand_coin",
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
    amount = 1,
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
  tags = { "prestige", "resolution_packet", "prestige_replay", "encore" },
  hook = "after_all_effects",
  effect = {
    op = "replay_resolution_packet",
    target = "random_resolved_bent_else_random_resolved_coin",
    scale = 0.2,
    mark = "prestige_replay",
    use_original_targets = true,
  },
  limits = { "once_per_flip", "packet_replay_only", "no_recursive_prestige", "no_live_chain_from_replay" },
}
```

Chain example:

```lua
{
  id = "domino_line",
  name = "Domino Line",
  tags = { "chain", "chained", "random_neighbor", "propagation" },
  hook = "after_coin_score",
  effect = {
    op = "trigger_random_neighbor",
    chance = 0.5,
    mark = "chained_coin",
    track = { "chain_source", "chain_depth" },
  },
  limits = { "max_chain_depth", "no_chain_reentry", "max_triggers" },
}
```

---

# Design Rules

## Good mechanic

Feels like cheating.

Examples:

- replace coin after flip
- swap coin bodies through resolved result slots
- rescore a moved layout after the cups shift
- forge a failed coin as the slot 1 template
- make several weak coins share a fake signed identity
- overload the board with real hand coins after the call
- multiply one smuggled coin into temporary contraband copies
- accelerate the Luck Meter toward a Fated Flip
- cash out extra payoff because the whole flip is Fated
- lift the Fated Flip Luck-gain limit so another Fated Flip can chain
- replay a completed coin packet at 20% as a finale
- let triggered coins have a 50% chance to trigger another random coin
- reward Chained coins or the third coin in a Chain
- reroll failure
- pretend Tails is Heads
- replay a completed packet at a discount
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

- Loaded Tricks that add small Weight
- small rerolls
- small result manipulation

Mid run:

- Foretold coins and Ancient Patterns
- physical swaps and substitutions
- forged slot identities and counterfeit payout checks
- board-overload Smuggling and refill support

Late run:

- movement-based rescores
- bounded copied payouts and triggers
- temporary contraband multiplication with caps if needed
- Fated Flip payoffs and capped Fated Flip chains
- discounted Prestige packet replays
- live Chain propagation and Chained coin payoffs

The fantasy should escalate from:

> I improved my odds.

To:

> I cheated the table.

To:

> I rewrote the result after the flip.

To:

> The House has no idea what just happened.
