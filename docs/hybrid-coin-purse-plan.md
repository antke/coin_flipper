# Hybrid Coin Purse Plan

## 1. Decision

The game should move from a fixed active-coin loadout into a **hybrid coin purse** model.

This is not a pure card-deck model. The target fantasy is:

> Build a growing purse, draw a tactical hand, use sleight of hand to improve it, reorder the coins, then flip the optimized setup.

The new core loop should preserve careful combo crafting while preventing solved fixed builds where the player repeatedly presses the same call with the same active coins.

---

## 2. Core design goals

1. **Coins take center stage.** In the main gameplay view, the drawn coins are the primary object in the middle of the screen. Everything else is secondary.
2. **Variance with agency.** Random draws create variety, but sleight and reordering give the player enough control to feel responsible for the result.
3. **Spending should feel rewarding.** Buying more coins should usually be useful because the purse is a growing run object, not a small fixed loadout.
4. **Keep combo play.** Neighbour effects, ordered effects, and pattern-like effects remain valuable because the player can reorder the drawn hand before flipping.
5. **Minimal viable information.** UI should show only the information needed for the current decision, with deeper purse inspection hidden behind an explicit window.
6. **Deterministic resolution.** Draws, sleights, replacement draws, reorders, flips, and scoring must remain seed-replayable.

---

## 3. Initial mechanic set

### 3.1 Coin purse

- The player owns a purse containing many coin **instances**.
- There is no purse size limit in the first implementation.
- Duplicates are allowed.
- Limits, thinning, and removal can be tuned later after the base loop feels good.
- Purchased coins are added to the purse directly.

### 3.2 Drawn hand

- At each flip opportunity, draw a hand from the purse.
- Initial tuning target: `handSize = 5`.
- Initial stage tuning should ensure the starting purse has enough coins for normal stage length.
- Drawn coins are shown in the center of the screen.
- All coins remaining in the final hand are flipped.

### 3.3 Sleight of Hand

Sleight of Hand is the replacement mechanic.

Rule:

> Once per hand slot, the player may return that coin to the available purse and draw a replacement into the same slot.

Important details:

- Each slot can be sleighted at most once per flip opportunity.
- Sleighted coins are not destroyed and are not exhausted.
- Sleighted coins return to the available purse for future draws in the same stage.
- The immediate replacement draw should avoid returning the exact same coin into the same slot if another eligible coin is available. This prevents the action from feeling broken while still keeping the coin in the purse for later.
- A coin may be marked as `cannotSleight`, which makes it stick in the hand once drawn.
- Sleight is optional; the player can keep the original hand.

Why this matters:

- Replacing a weak coin is not always correct because the replacement may be worse.
- Returning weak coins to the purse creates late-stage risk.
- Avoiding sleight early can preserve purse quality for later flips.
- Coin effects can trigger when a coin is returned to the purse, opening a large thematic design space.

### 3.4 Reordering

- After drawing and sleighting, the player may reorder the final hand.
- Reordering exists so neighbour effects remain part of the game.
- Reordering turns each flip into a small optimization puzzle rather than a static build execution.
- The final left-to-right order becomes the resolution order for ordered effects.

### 3.5 Neighbour coins remain supported

Coins that affect adjacent coins should be preserved and expanded.

Examples:

- boost the coin to the right
- copy the coin to the left
- score if placed between two matching results
- protect adjacent coins from penalties
- curse adjacent coins but gain a large payout
- improve both neighbours if this coin matches the call

Under the purse model, neighbour coins become tactical hand-arrangement pieces rather than fixed build-position pieces.

---

## 4. Recommended first playable flow

### 4.1 Run start

Initial tuning target:

- Start with enough baseline coins to support all normal flip opportunities.
- If `handSize = 5` and `flipsPerStage = 3`, the starter purse should contain at least 15 baseline/filler coins plus several special coins.
- A reasonable first prototype target is 15 basic coins + 3 drafted/special coins.

The exact numbers are tuning values, not permanent design commitments.

### 4.2 Stage start

The old “choose active loadout” step should become a lighter **Purse Review / Stage Briefing** step.

The player should see:

- next stage target
- flips available
- boss/stage modifier if relevant
- purse count summary
- button to inspect purse
- start stage button

The player should not be asked to choose active coins before the stage in the first purse implementation.

### 4.3 Flip opportunity

Per flip opportunity:

1. Draw 5 coins from the available purse.
2. Show the hand centered on screen.
3. Player chooses Heads or Tails.
4. Player may sleight any eligible slot once.
5. Player may reorder the final hand.
6. Player presses Flip.
7. Coins flip left-to-right in final order.
8. Scoring resolves.
9. Flipped coins move to the stage exhausted pile.
10. If the stage is still active, draw the next hand from the remaining available purse.

### 4.4 Call timing

The call should be selected after seeing the drawn hand but before using sleight.

For the first implementation:

- The call becomes locked once the player uses Sleight of Hand.
- If no sleight has been used, the player may change the call before flipping.
- This avoids ambiguity for effects like “when returned to the purse, gain weight toward the selected side.”

### 4.5 Stage exhaustion

- Coins flipped in the final hand are exhausted until the next stage.
- Coins returned through sleight go back into the available purse and may appear later in the same stage.
- At the start of the next stage, all purse coins become available again.

This is what creates the risk of dodging weak coins early and drawing them later.

### 4.6 Short-purse edge case

Normal tuning should avoid the player running out of coins.

If available coins are fewer than `handSize`:

- draw all remaining available coins
- empty hand slots stay empty
- show a small “Purse running low” warning
- allow flipping the partial hand

If no coins are available before a required flip:

- do not softlock
- immediately resolve the stage state: cleared if the target has already been met, otherwise failed
- record this as an exhaustion event for debugging and balance review

---

## 5. Data model consequences

### 5.1 Replace coin-id collection with coin instances

The current model stores owned coins as ids and disallows duplicates. The purse model needs instances.

Recommended run state fields:

```lua
runState.coinInstances = {
  {
    instanceId = "coin_001",
    definitionId = "heads_hunter",
    state = {},
    flags = {},
  },
}
```

The old `collectionCoinIds` can be migrated or replaced by instance-based storage.

Why instances are required:

- duplicates must be possible
- individual coins may gain temporary or permanent state
- a specific coin can be drawn, sleighted, exhausted, or modified
- replay logs need to identify the exact coin instance, not only the definition id

### 5.2 Stage purse zones

Each stage should track coin locations.

Recommended stage-scoped fields:

```lua
stageState.purse = {
  availableInstanceIds = {},
  handSlots = {
    { instanceId = "coin_001", sleightUsed = false },
    { instanceId = "coin_002", sleightUsed = false },
  },
  exhaustedInstanceIds = {},
  sleightHistory = {},
}
```

Zones:

- `available`: can be drawn
- `hand`: currently visible to the player
- `exhausted`: already flipped this stage

No separate discard pile is needed for the first implementation because sleighted coins return to available and flipped coins exhaust.

### 5.3 Hand slot identity

Hand slots need stable slot indexes because:

- each slot can be sleighted once
- reordering changes slot order
- neighbour effects need final order
- UI needs to animate/reveal specific slots

Recommended distinction:

- `handSlotIndex`: visual/current slot position
- `originalDrawIndex`: where the coin first entered the hand
- `resolutionIndex`: final left-to-right order at flip time

### 5.4 Coin definitions

Coin definitions should support new optional fields:

```lua
{
  id = "cursed_anchor",
  name = "Cursed Anchor",
  cannotSleight = true,
  tags = { "cursed", "anchor" },
  triggers = { ... }
}
```

Potential new hook phases:

- `after_hand_draw`
- `before_sleight`
- `after_sleight_return`
- `after_replacement_draw`
- `after_hand_reorder`
- `before_hand_flip`

Only add phases that are needed by real content. The likely minimum for the first thematic coin wave is `after_sleight_return`.

---

## 6. Resolution pipeline changes

Current resolution assumes all equipped coins flip in loadout order. The new pipeline should resolve the current hand.

Recommended pipeline:

1. `draw_hand`
2. `select_call`
3. `apply_sleight_actions`
4. `apply_reorder_actions`
5. `validate_final_hand`
6. `before_hand_flip` hooks
7. per-coin roll in final order
8. existing per-coin hooks
9. scoring
10. stage-end check
11. move flipped hand to exhausted
12. clear hand

Important implementation rule:

> Player manipulation actions should be explicit inputs, not hidden UI-only mutations.

Replay/invariant tests should be able to reconstruct:

- drawn instance ids
- selected call
- which slots were sleighted
- replacement instance ids
- final order
- flip results

---

## 7. UI philosophy

### 7.1 Main principle

The gameplay screen should answer one question at a time.

During hand manipulation, the important question is:

> What do I do with these coins?

Therefore the center of the screen should contain only the drawn coins and their immediate actions.

### 7.2 Minimal always-visible information

Always visible in the stage view:

- current stage score / target
- flips remaining
- chips, if still relevant during stage
- selected call
- drawn hand
- action buttons: Heads, Tails, Sleight, Flip, Inspect Purse

Hidden or secondary:

- full purse list
- detailed score logs
- long coin descriptions
- historical stage stats
- deep odds breakdowns

### 7.3 Coin card states

Each hand coin should communicate:

- coin name/icon
- short effect text or compact tags
- whether it can be sleighted
- whether its slot has already used sleight
- current selected/reorder state
- final flip result after reveal

Do not show every technical detail on the card. Use inspection/hover/detail for full text.

---

## 8. Game view update plan

The current state graph contains these views: boot, menu, run setup, help, collection, records, pause, loadout, boss warning, stage, result, post-stage analytics, reward preview, boss reward, encounter, shop, summary, and meta.

### 8.1 Boot

No design change.

Technical requirement:

- validate new purse-capable coin definitions
- validate instance-safe save migration if needed

### 8.2 Menu

Minimal change.

Update wording if needed:

- “New Run” starts a purse-based run
- continue run must restore hand/purse zone state if saved mid-stage

### 8.3 Run setup

Purpose changes from generic setup into optional starting configuration.

First implementation:

- show short rules summary for the purse model
- show starter purse summary if useful
- avoid adding complex starting choices yet

Future:

- choose character
- choose starting purse archetype
- choose starting special coins

### 8.4 Help

Must be updated.

Add concise explanations for:

- purse
- hand draw
- Sleight of Hand
- reordering
- exhausted coins
- neighbour effects
- shop purchases adding to purse

Keep it short. The help screen should explain rules, not become a strategy guide.

### 8.5 Collection

This remains the meta/codex collection, not the current run purse.

Update needed:

- clarify that Collection shows unlocked content
- add tags/fields for `cannotSleight`, neighbour effects, and purse-trigger effects
- do not use this screen as the run purse inspection window

### 8.6 Records

Add purse-relevant stats only after the base system works.

Useful future stats:

- largest purse size
- most sleights in a run
- cursed coins carried
- stage won with partial hand
- wins by dominant call

Not required for first implementation.

### 8.7 Pause

Add a small action:

- Inspect Purse

If modal overlays are easier, pause can simply expose the same purse inspection window used by stage/shop.

### 8.8 Loadout → Purse Review / Stage Briefing

The old loadout state is the biggest macro-flow change.

New purpose:

- preview the next stage
- review the purse if desired
- start the stage

Remove from this view for the first purse version:

- active slot selection
- persisted loadout reconciliation
- duplicate prevention

Show instead:

- stage target
- flips available
- stage/boss modifier summary
- purse size
- counts by rarity or broad tag
- Inspect Purse button
- Start Stage button

This keeps pre-stage flow fast and avoids forcing a management screen before every stage.

### 8.9 Boss warning

Keep as a focused warning screen.

Update copy to reference the purse model only if the boss affects draw, sleight, order, or exhaustion.

Otherwise:

- show boss modifiers
- show purse size summary
- continue to stage

### 8.10 Stage

This becomes the primary redesigned screen.

Layout target:

- top: compact status bar
- center: large hand of 5 coins
- below center: sleight/reorder affordances
- bottom: call + flip controls
- corner/secondary: Inspect Purse, Pause

Player flow states inside stage:

1. `hand_drawn`
   - hand is visible
   - player can choose/change call
   - flip disabled until a call exists

2. `manipulating_hand`
   - call selected
   - sleight buttons enabled for eligible unused slots
   - reorder enabled
   - flip enabled

3. `revealing_flip`
   - no manipulation controls
   - reveal final ordered coins
   - show compact score changes

4. `stage_complete`
   - continue to result

Important UI detail:

- A coin’s Sleight control should be attached to that coin card, not placed in a distant menu.
- Reorder should be direct manipulation if possible: drag coins horizontally, or use simple left/right buttons as a first implementation.
- Coin detail should be available, but not always expanded.

### 8.11 Result

Keep result concise.

Update summary lines:

- stage score / target
- chips earned/current chips
- flips used
- purse size
- coins added this stage, if any
- notable exhaustion/sleight summary if useful

Per user decision:

- after a finished round, the user goes directly to the store
- skip per-round choice rewards for now

This means Result → Continue should prepare/open Shop for cleared normal stages unless the run is over.

### 8.12 Post-stage analytics

This should be skipped or kept hidden by default during the purse migration.

Reason:

- the immediate desired flow is Result → Shop
- extra analytics between stage and shop slows the reward loop

If retained, it should be reachable only as an optional detail, not required progression.

### 8.13 Reward preview

Skip for now.

The purse shop should be the main reward/spending moment.

Do not add per-round choice rewards until the new loop is stable.

### 8.14 Encounter

Skip for now unless already needed by existing progression.

Encounters can return later as special shop-adjacent events.

### 8.15 Boss reward

Keep only if required by current boss flow.

If simplifying:

- boss clear can go to summary/meta rather than a separate reward choice

Do not expand boss rewards during the purse migration.

### 8.16 Shop

The shop must be reworked around purse growth.

First implementation:

- shop appears after the result screen
- offers include coins and upgrades
- buying a coin adds a new coin instance to the purse
- duplicates are allowed
- no active-slot replacement decision
- reroll remains available
- continue starts next stage briefing

Shop should show minimal run context:

- chips
- next stage label/modifier
- purse size
- maybe “+1 coin to purse” on coin offers
- Inspect Purse button

Avoid for first implementation:

- one-purchase-per-round reward choice
- selling
- removing/thinning
- merging
- purse size limits

These are likely valuable later but should not block proving the new core loop.

### 8.17 Summary

Update end-of-run summary with purse-oriented stats:

- final purse size
- coins bought
- sleights used
- strongest call tendency
- stages cleared

Keep detailed per-stage purse logs optional.

### 8.18 Meta

No immediate mechanical change.

Future meta upgrades may unlock:

- new starting purse templates
- extra sleight affordances
- new coin types
- better shop offers

Do not add these until the base purse loop is playable.

---

## 9. Coin purse inspection window

Add a run-specific purse inspection window separate from the meta Collection screen.

### 9.1 Access points

Available from:

- stage
- shop
- purse review/stage briefing
- pause

### 9.2 Minimal first version

Show grouped entries by coin definition:

- coin name
- count
- rarity/tags
- short description
- current stage zone counts if in stage: available / hand / exhausted

Example:

```text
Heads Hunter x4
Common · Heads · Match
Stage: 2 available, 1 in hand, 1 exhausted
+2 score when this coin matches a Heads call.
```

### 9.3 Sorting/filtering

First version:

- sort by name or count
- no advanced filters required

Later:

- filter by tag
- show cursed/non-sleight coins
- show neighbour coins
- show purse-trigger coins

### 9.4 UI philosophy

The inspection window should not be open by default.

Main gameplay should remain focused on the current hand. Purse inspection is for deliberate planning.

---

## 10. Shop/economy consequences

### 10.1 Coin pricing

Because coins are no longer replacing scarce active slots, coin prices likely need retuning.

Early expectations:

- common coins can be cheaper than fixed-slot coins
- powerful rare coins may still be expensive
- cursed/non-sleight coins can be cheaper because they add risk
- removal/thinning, when added, should be expensive because it increases consistency

### 10.2 Wealth reward

The purse model solves the main fixed-loadout economy problem:

- buying more coins usually changes future draws
- big chip rewards can convert into a visibly larger purse
- the player can build broader strategies instead of only replacing active coins

### 10.3 Bloat risk

No purse limit is acceptable for the first version, but bloat must be watched.

Signs that thinning/removal is needed:

- players avoid buying because every coin feels like dilution
- late runs become too random
- weak starter coins remain too punishing
- shop decisions become obvious skips

Do not add thinning until this problem is observed in play.

---

## 11. New coin design space

The purse model enables many coin effects that did not make sense in a fixed setup.

### 11.1 Sleight-return coins

Examples:

- When returned to the purse, gain +0.15 weight toward the selected call next time it is drawn.
- When returned to the purse, gain +1 value for this stage.
- When returned to the purse, give +1 chip immediately.
- When returned to the purse, make the next replacement coin more likely to match the selected call.
- When returned to the purse twice in a run, upgrade permanently.

### 11.2 Cursed/non-sleight coins

Examples:

- Cannot be sleighted, but pays double on match.
- Cannot be sleighted; if it misses, it penalizes adjacent coins.
- Cannot be sleighted; if placed in the middle, it boosts both neighbours.
- Cannot be sleighted; if all coins match, huge payout.

### 11.3 Neighbour/tactical placement coins

Examples:

- Doubles the coin to the right if both match.
- Gives +1 weight to adjacent coins before roll.
- Copies the result of the left coin after roll.
- Scores only if placed on an edge.
- Scores only if surrounded by two coins of the same call alignment.

### 11.4 Purse-quality coins

Examples:

- When drawn, improve all remaining available coins of a tag.
- When exhausted, add a temporary basic coin to the purse next stage.
- When sleighted, remove one weak baseline coin from available for this stage only.

These should be introduced gradually. The first implementation only needs enough content to prove the loop.

---

## 12. Player flow optimization

### 12.1 Desired emotional rhythm

1. Anticipation: “What did I draw?”
2. Assessment: “What is the best call?”
3. Manipulation: “Can I improve this hand?”
4. Puzzle: “What order is best?”
5. Commitment: “Flip.”
6. Payoff: “The ordered machine resolves.”
7. Reward: “Spend chips to improve the purse.”

### 12.2 Avoid slow turns

Main risk: every flip could become too long.

Mitigations:

- hand size starts at 5, not larger
- each slot can be sleighted only once
- reordering should be quick
- coin text should be compact
- reveal should be punchy
- avoid extra post-stage reward screens for now

### 12.3 Avoid decision overload

Do not show full purse odds by default.

Instead, show only:

- current hand
- whether a coin can be sleighted
- whether a slot already used sleight
- final order
- current call

Deep information belongs in the inspection window.

---

## 13. Implementation phases

### Phase 1: Data foundation

- Introduce coin instances.
- Allow duplicate owned coins.
- Add stage purse zones.
- Add deterministic draw helpers.
- Save/replay instance ids and purse zones.

### Phase 2: Basic hand flow

- Replace active loadout resolution with drawn hand resolution.
- Draw 5 coins per flip opportunity.
- Flip final hand in order.
- Exhaust flipped coins until next stage.
- Keep scoring mostly unchanged by adapting “equipped coin” source collection to use current hand coins.

### Phase 3: Stage UI redesign

- Put drawn coins in the center.
- Add call selection without immediate resolution.
- Add Flip button.
- Add compact stage status.
- Keep reveal behavior simple.

### Phase 4: Sleight of Hand

- Add per-slot sleight action.
- Return coin to available purse.
- Draw replacement.
- Track per-slot `sleightUsed`.
- Lock call after first sleight.
- Add validation for `cannotSleight`.

### Phase 5: Reordering

- Add simple reorder controls.
- Use final hand order as resolution order.
- Preserve enough data for neighbour effects.

### Phase 6: Shop rework

- Make coin purchases create new instances.
- Allow duplicate purchases.
- Update shop copy and offer cards.
- Add purse summary and inspection access.
- Ensure Result → Shop flow skips per-round reward choice.

### Phase 7: Purse inspection window

- Add shared run-purse inspection modal/window.
- Group coins by definition.
- Show zone counts during stage.

### Phase 8: First purse-specific content

- Add a small set of simple purse/sleight/neighbour coins.
- Add at least one `cannotSleight` cursed coin.
- Add at least one coin that benefits from being returned to the purse.

### Phase 9: Balance/testing pass

- Tune starter purse size.
- Tune hand size if needed.
- Tune coin prices.
- Watch for bloat, turn length, and solved call patterns.

---

## 14. Verification checklist

Required checks after implementation:

- Same seed + same inputs produces the same hand draws, sleights, replacements, order, and flip results.
- A coin instance cannot exist in two zones at once.
- Sleight can only be used once per slot.
- `cannotSleight` coins cannot be returned to the purse.
- Reorder changes resolution order but does not duplicate/drop coins.
- Flipped coins exhaust until next stage.
- Sleighted coins can return in later hands.
- Shop coin purchase creates a new instance, even for duplicate definitions.
- Save/load restores current hand and purse zones if saved mid-stage.
- Replay logs include draw, sleight, replacement, reorder, and flip data.
- Stage cannot softlock if the available purse is short or empty.

Existing verification scripts should be updated or extended around the new instance/purse invariants.

---

## 15. Open tuning questions

These should remain open until the first playable purse build exists:

- Is `handSize = 5` the right default?
- Should every final hand coin always flip, or should the player eventually choose a subset?
- How many baseline coins should the starter purse contain?
- Should sleighted coins be able to appear again in the same flip replacement draw, or only later?
- Are flipped coins exhausted for the whole stage, or should some coin types return sooner?
- How cheap should common coins be when duplicates are allowed?
- When does the game need coin removal/thinning?
- Should there eventually be a maximum purse size?

---

## 16. Guiding principle

The purse system should make the game feel less like pressing the correct solved button and more like performing a small coin trick each flip.

The player should feel:

> “I built this purse, I drew this situation, I manipulated it, I arranged it, and then luck judged the result.”
