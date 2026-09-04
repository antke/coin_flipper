# Trick Family Design Update

> Historical design note (superseded): this document describes the earlier
> positional Rig proposal. The approved direction is now the family-triggered
> Trick engine in `docs/family-trigger-engine-design.md`, with implementation
> planning in `docs/family-trigger-engine-implementation.md` and first-pass
> content conversion in `docs/family-trigger-trick-migration.md`. Retain this
> file for its family audit, theme vocabulary, and opponent-pressure ideas; do
> not implement its random Trick shuffle, Trick-to-coin slot assignment,
> reshuffle, or reposition systems.

## Purpose

This update restructures Tricks around one central concept:

> The player builds a limited Rig of Trick Charms, receives a shuffled arrangement at the beginning of each round, commits coins to those Tricks during setup, and then watches the locked Rig resolve automatically.

Randomness creates the situation. The player demonstrates skill by interpreting, repairing, and operating the resulting machine.

The implementation should establish the Rig structure first, migrate surviving Trick families onto it, and only then balance individual Tricks.

---

## Core Design Contract

### The Rig

- Each coin Flip slot corresponds to one Rig slot.
- Each Rig slot may contain one Trick Charm.
- A Trick Charm can normally occupy only one slot.
- Empty Rig slots remain valid plain coin slots; their coins simply receive no Trick.
- The player's active Trick collection is limited by Rig capacity.
- When the Rig is full, acquiring a new Trick requires replacing an existing one.
- There is no unlimited inactive charm reserve.
- Future perks may increase Rig capacity or alter slot rules, but the initial system remains one charm per slot.

### Round Initialization

At the beginning of each round:

- All currently owned Trick Charms are placed into the Rig.
- Their positions are shuffled using deterministic run RNG.
- Empty positions participate in the shuffle if the player owns fewer Tricks than slots.
- The arrangement persists throughout the entire round.
- Shuffle and reposition allowances reset to three each.

A player-facing round maps to the current stage or encounter, not an individual Flip.

### Round-Wide Rig Manipulation

For the entire round, the player receives:

- **3 Reshuffles:** randomize the complete current Rig.
- **3 Repositions:** deterministically swap two chosen Rig positions.

These allowances:

- do not refresh between Flips;
- may only be used during setup;
- persist through save and load;
- are recorded in replay history;
- are discarded when the round ends.

The intended distinction is:

- Reshuffle when the machine is fundamentally unusable.
- Reposition when an almost-working machine can be repaired precisely.

Three of each is the initial prototype value and should be balanced later.

### Coin Commitment

During setup:

- The opponent's intent and slot pressure are visible.
- The current hand is visible.
- The player may manipulate the Rig if allowances remain.
- The player commits one coin to each desired Rig slot.
- The committed coin becomes that Trick's input for the Flip.
- Coins may still be arranged and the player selects Heads or Tails.
- Prediction may introduce a special irreversible pre-Flip commitment.

Recommended rules language:

- "The coin committed to this Trick..."
- "When the coin set here matches..."
- "The previous, next, or adjacent Trick..."
- "This Trick is prepared."
- "This Trick cannot resolve because..."

### Setup and Execution Boundary

Clicking Flip:

- locks the Rig;
- locks coin commitments;
- locks the call;
- snapshots the opponent's intent and slot states;
- begins uninterrupted automatic execution.

There are never:

- post-Flip target choices;
- reroll prompts;
- manual Trick activation;
- result-replacement decisions;
- reaction windows.

Player actions resume only after the complete Flip, Trick stack, opponent response, scoring, and reveal sequence have finished.

This boundary must be enforced by game state, not only by disabling UI controls.

---

## Thematic Vocabulary

The universal fiction is cheating, not feeding magical objects.

- **Rig:** the complete Trick arrangement.
- **Rig the Table:** the setup phase.
- **Commit/Set a Coin:** assign a coin to a Trick.
- **Prepared Trick:** a Trick with a committed coin.
- **Reshuffle the Rig:** full random rearrangement.
- **Switch Tricks:** targeted position swap.
- **Lock the Rig:** commit everything by clicking Flip.
- **Resolve/Pay Out:** automatic Trick execution.

The charm represents a prepared technique, keepsake, or cheating tool. The player is choosing which coin they will use to perform that Trick.

"Bless," "bind," and "contract" can remain family-specific flavour, especially for the Fountain or supernatural opponents, but they should not be the universal assignment terminology.

The intended fantasy is:

> A skilled cheat assembles an imperfect hidden Rig, assigns the right coin to every prepared Trick, makes a few covert adjustments, and then takes their hands off the table while the entire con plays out.

---

## Runtime State Model

The run can continue using `ownedTrickIds` as the active Trick collection, but each round needs a separate shuffled layout.

Suggested shape:

```lua
stageState.rig = {
    slots = {
        [1] = "borrowed_name",
        [2] = nil,
        [3] = "keep_it_rolling",
    },

    shufflesRemaining = 3,
    repositionsRemaining = 3,
    locked = false,
    revision = 1,
}
```

Coin commitments can continue using the existing selected or board slot model, provided each selected slot maps directly to the same Rig index.

Opponent pressure should be stored separately:

```lua
stageState.rigSlotStates = {
    [1] = { cursed = true },
    [2] = { blocked = true },
}
```

Slot pressure belongs to the table position, not the charm. Moving a charm out of a threatened position is therefore meaningful.

A dedicated `RigSystem` should own:

- round-start shuffle;
- Rig normalization;
- full reshuffle;
- targeted swap;
- counter consumption;
- setup-phase validation;
- coin-to-Trick binding;
- neighbour queries;
- Rig locking and unlocking;
- deterministic history records.

---

## Trick Runtime Changes

The current runtime activates every owned Trick globally. This must change.

Only Tricks present in the current Rig should become active sources. Each Trick source needs:

- `slotIndex`;
- `committedCoinInstanceId`;
- `committedCoinId`;
- neighbouring Rig positions;
- current slot pressure;
- whether it is prepared, armed, blocked, or broken.

Resolution order should use Rig position, left to right, rather than acquisition order.

Target selectors need positional concepts such as:

- `committed_coin`;
- `left_coin`;
- `right_coin`;
- `adjacent_coins`;
- `previous_trick_outcome`;
- `next_trick`;
- `current_rig_slot`;
- `adjacent_rig_slot`;
- `smuggled_coin_from_this_slot`.

Random "find the best eligible coin anywhere" targeting should largely disappear.

Every migrated Trick must answer:

1. What coin is committed to it?
2. What condition arms it?
3. What position or neighbour does it read?
4. What automatic output does it produce?
5. What happens when its condition is not met?
6. Can the UI explain this before Flip?

---

## Trick Family Migration

### Forgery

Role: hybrid support that counterfeits additional value and activations for a developed neighbouring family.

Rules:

- A committed Forgery/Blank Coin reads the genuine non-Forgery coin immediately to its left.
- Slot 1 and a Forgery Coin following another Forgery Coin have no valid source.
- Before Flip, the Blank locks that neighbour's family as its acting family. The source, direction, and bounded target package cannot change during execution.
- Fake Credentials I-III copy 50% / 75% / 100% of the successful left source's completed root Outcome when the Forgery Coin misses.
- Borrowed Name I-III let the rigged Blank imitate up to one / two / three eligible Tricks, capped at Tier I / II / III, from the left source's family.
- Forged Signature I-III repeat exactly one highest-tier eligible Trick, capped at Tier I / II / III, from the left source's family.
- Borrowed Name prefers lower-tier foundations first; Forged Signature prefers the highest eligible tier. Board order is the stable tie-break.
- The target list is selected once for the entire Flip, not independently in every hook phase.
- Copied activations use the Blank Coin as their activation source and run during every copied Trick's normal hook phase, including setup and pre-roll phases.
- A forged activation cannot activate Forgery, be forged again, or change the locked real family ledger.
- Block, Weaken, and Jam pressure still apply to the copied target Trick.

Forgery is intentionally inefficient as a one-card splash. Its payoff requires a developed primary family, Forgery Trick slots, Blank Coins in the pouch, and correct left-to-right positioning. Copied Tricks still evaluate their own Match, Miss, Foretold, and other conditions against the Blank.

Example:

> `[Prestige Coin] [Blank Coin]` lets Borrowed Name imitate a bounded Prestige package and Forged Signature repeat one valuable eligible Prestige Trick.

#### Post-implementation interaction audit

The pre-Flip acting-family assignment removes the old phase incompatibility. One target package is now locked for the entire Flip, so a Tier III three-Trick cap cannot silently select additional Tricks in later phases.

| Primary family | Interaction with Forgery | Remaining constraint or risk |
| --- | --- | --- |
| Weighted | Fully compatible. Copied Weight and minimum Match Chance run before the Blank rolls; copied payoff conditions then read the Blank's result. | Reliability can stack quickly and needs numerical playtesting. |
| Prestige | Fully compatible. The Blank can create extra completed-Outcome replays and is the clearest Forgery payoff build. | Prestige's global targeting makes this the highest-risk balance pairing. |
| Momentum | Fully compatible. Copied after-score hooks propagate from the Blank, while forged descendants remain recursion-blocked. | Watch the global activation-event cap in deep hybrid engines. |
| Prediction | Mechanically compatible. A Blank acting as Prediction can fulfill the visible forecast when the Blank itself occupies that predicted slot. | With the current fixed-left direction, predicted slot 1 cannot contain a valid disguised Blank; this is a visible positional limitation. |
| Sleight of Hand | Fully compatible. Copied post-result manipulation treats the Blank as the active body while preserving locked result slots. | Higher-tier Sleight still risks letting automatic optimization replace player planning. |
| Smuggling | Fully compatible. Copied inbound effects run before the board is finalized and can add another overload body when cargo and capacity remain. | The genuine Hollow source often uses the first capacity, so Forgery only adds value with sufficient hand depth and overload room. |

Audit conclusion: Forgery now interacts with every active family through its native timing rather than behaving as post-result-only support. Its remaining issues are balance and fixed-left geometry, not missing engine compatibility. Prestige remains the larger agency problem because its global/random Outcome targeting still makes placement less important than intended.

### Momentum

**Verdict:** Keep. First prototype family.

- The committed coin becomes the Momentum source.
- Propagation follows visible left or right paths.
- Replace unnecessary random neighbour selection with deterministic direction.
- Reduce additional continuation rolls where the original coin result already supplies enough uncertainty.
- Echo Wager should be removed or rewritten because it does not express Momentum.

Momentum proves directional chains and ordered execution.

Example:

> When the Flywheel Coin committed here scores, carry Momentum into the next Trick.

### Prestige

**Verdict:** Keep. First prototype family.

- Encore replays the previous or adjacent slot's Outcome.
- Curtain Call reads a larger but explicit local region.
- Impossible Finale replays a visible connected sequence instead of automatically choosing the globally highest Outcome.
- Remove or rewrite Steady Finish's passive global multiplier.

Prestige proves positional Outcome references.

Example:

> If the Bent Coin committed here matches, replay the preceding Trick's Outcome.

### Weighted

**Verdict:** Keep. Early supporting family.

- Weight applies to the committed coin.
- Weighted Coins receive stronger specialization, but other coins remain legal inputs.
- Remove broad selected-hand and random-global targeting.
- Weighted becomes a reliability anchor for other positional families.

Example:

> The coin committed here is weighted toward your call.

### Prediction

**Verdict:** Keep. Second-wave family with special setup sequencing.

Recommended behaviour:

1. Commit a coin to a Prediction Trick.
2. Reveal its foretold result.
3. That coin becomes committed to the slot for the Flip.
4. Use the information to arrange remaining coins and select the call.

The player cannot repeatedly insert and remove coins to scan the entire hand.

Ancient Patterns should read visible neighbouring Foretold slots rather than the whole board passively.

Prediction remains distinct from Weighted:

- Weighted changes probability.
- Prediction reveals information.
- Neither repairs outcomes after Flip.

### Sleight of Hand

**Verdict:** Keep. Second-wave family.

- Sleight owns physical manipulation after results are known: moving regular committed coin bodies between slots or palming a failed committed coin back into hand.
- Results and slot modifiers remain in their original slots; only coin bodies move.
- Activations stay locked to the coins that originally enabled them, and movement never creates another activation.
- Switcheroo I–III trade the activating Match for an increasingly well-selected higher-value Miss: random eligible, highest material band, then highest total value.
- Vanishing Act I–III palm a failed regular committed coin instead of spending it: the activating Miss, the best local Miss, then the best Miss on the table.
- Three-Card Monte I–III automatically choose a strictly score-improving local rearrangement: random neighbour, best neighbour, then best three-slot permutation.
- Sleight cannot move, palm, or activate from a Smuggled/Contraband body.
- False Bottom is removed because hand-to-table substitution belongs to Smuggling's semantic territory.
- There is no post-Flip player decision.

Example:

> If the Vanishing Coin committed here misses, switch it with the matching coin to its right.

### Smuggling

**Verdict:** Keep, but treat it as a controlled rule-breaking exception.

- A committed Hollow Coin can conceal extra uncommitted Hollow Coins beside itself.
- The overloaded coins visually belong to the activating slot instead of occupying a detached Contraband lane.
- A normal Smuggling effect chooses a random eligible coin. `Highest quality` and `lowest quality` first constrain the pool by Copper/Silver/Gold material, then choose randomly inside that material.
- The exact coin remains concealed until execution; the player controls the possible pool through commitment and purse construction.
- Smuggled coins flip and score independently but cannot activate Tricks.
- Smuggling is strictly inbound and additive: it brings an uncommitted hand coin onto an anchored overload position but never removes, saves, swaps, or substitutes an active body.
- Fall Guy is removed. Saving a failed committed coin belongs to Sleight's Vanishing Act line.
- Contraband copies require explicit caps and cannot recursively multiply.
- Hidden Pocket's permanent global slot increase should be removed or converted into the local pocket mechanic.

Smuggling should overload existing slots with extra coin bodies, not bypass the Rig's Trick capacity.

Example:

> A Hollow Coin committed here conceals a random eligible Hollow Coin beside it; a targeting modifier may restrict the draw to the highest or lowest material present.

### Fate

**Verdict:** Put on hold.

- Preserve the Luck Meter and Fountain sacrifice system.
- Remove Fate charms from normal reward offers while the family is on hold.
- Do not delete the underlying Luck engine yet.
- Audit Lucky Coins because their primary family synergy may disappear; they could become particularly valuable Fountain sacrifices instead.

If Fate returns, it must become local:

- a committed Lucky Coin charges the meter;
- a Fated Flip payoff affects its own or an adjacent slot;
- global passive generation multipliers do not occupy Rig slots.

The following current entries should not survive as Fate Tricks:

- Opening Stake;
- House Voucher;
- Insurance Slip;
- Rainy Day Voucher;
- passive Fountain Pact in its current form.

### Extortion

**Verdict:** Remove as a Trick family.

Its shop and Spoils effects may later become:

- immediate reward choices;
- Black Market events;
- opponent rewards;
- one-time run conditions.

They should not remain collectible Rig components.

Safe migration order:

1. Remove Extortion Tricks from reward and shop eligibility.
2. Safely drop old Extortion IDs when loading active saves.
3. Update fixtures and development builds.
4. Remove definitions and unused crumble or economy plumbing once no references remain.

---

## Recommended Machine Roles

The surviving families should have distinct purposes:

- **Weighted:** stabilizes an input.
- **Prediction:** reveals an input after commitment.
- **Forgery:** changes what a neighbouring input counts as.
- **Sleight:** moves coin bodies between predetermined slots.
- **Smuggling:** introduces extra charm-less bodies.
- **Fate, if retained:** charges or cashes out longer-term Luck through a local slot.
- **Prestige:** replays another slot's completed output.
- **Momentum:** propagates execution through the arrangement.

The individual pairing may be easy to understand. The strategic depth should come from the complete arrangement, competing positional requirements, the current hand, and opponent pressure.

Avoid reducing every family to:

> Put a family-X Coin into a family-X Trick for a score multiplier.

Family affinity can improve a Trick, but should not completely solve placement.

---

## Opponent Slot Pressure

Opponent slot pressure should follow the core Rig implementation. It is what keeps the ideal arrangement contextual across multiple Flips.

Initial effects should be few and readable:

- **Blocked:** no coin can be committed to this position.
- **Cursed:** the committed coin scores less or pays a penalty.
- **Watched:** the coin may score, but its Trick cannot initiate.
- **Crooked:** its probability is visibly pushed toward one side.
- **Redirected:** its score or effect travels to a neighbour.

Rules:

- Opponent intent is telegraphed before setup.
- Effects target table positions, not specific charms.
- Opponents use small move decks or scripts.
- Avoid repeating the same technique every turn.
- Some hostile positions should be exploitable rather than purely negative.
- Boss phases can change which positions are threatened.

This should force the ideal Rig order to evolve during the round, preventing the player from solving the shuffle once on the first Flip.

---

## UI Requirements

The table must communicate the machine without requiring tooltips for its basic relationships.

Each Rig slot should display:

- Trick Charm;
- committed coin;
- slot number;
- directional arrows or affected neighbours;
- armed or unarmed status;
- concise failure reason;
- opponent pressure attached to the position.

Controls should show:

- `Reshuffles: 3`;
- `Repositions: 3`;
- `Reshuffle Rig`;
- `Switch Tricks`;
- `Lock Rig & Flip`.

During execution:

- all setup controls disappear or disable;
- links animate in resolution order;
- Trick callouts originate from the actual charm slot;
- Prestige replays and Momentum chains visibly reference their source and destination;
- no modal prompt interrupts resolution.

The help text should be rewritten around **Rig the Table** and **commit coins to Tricks**.

---

## Trick Acquisition

Spoils must become a machine-building decision.

When there is an empty Rig slot:

- acquiring a Trick fills the active collection.

When the Rig is full:

- the player chooses an existing Trick to replace;
- declining remains possible where appropriate;
- a higher tier in the same Trick line upgrades or replaces that line directly.

Offers should preview:

- family;
- input requirement;
- direction or position shape;
- likely connections to owned Tricks;
- whether the player has suitable coin archetypes.

The player should evaluate potential machinery rather than collect every passive modifier that might occasionally trigger.

---

## Save, Replay, Validation, and Simulation

Save data must include:

- round Rig order;
- remaining reshuffle count;
- remaining reposition count;
- active slot pressure;
- current setup commitments;
- Rig lock state where appropriate.

Replay history must record:

- initial seeded Rig shuffle;
- each full reshuffle;
- each targeted swap;
- each coin commitment;
- final locked Rig snapshot;
- opponent slot state at Flip;
- Trick source slot and committed coin.

Validation must reject:

- duplicate Tricks in a Rig unless explicitly allowed later;
- Rig manipulation outside setup;
- negative action counters;
- Flip execution without a valid locked snapshot;
- post-Flip player mutations;
- Trick sources not present in the active Rig.

The simulation system must eventually choose:

- whether to accept or reshuffle a Rig;
- which two Tricks to switch;
- which coins to commit;
- which call best supports the assembled machine.

Until simulation understands those choices, automated win-rate results will not meaningfully evaluate the new game.

---

## Efficient Implementation Order

### Phase 0: Define the Trick Gameplay

Before implementing Rig randomness or migrating engine code:

- enumerate the player-controlled setup actions and outcome patterns that Tricks may reward;
- consolidate existing tier variants into Trick lines;
- classify every existing Trick line as convert, remove, or hold;
- rewrite each surviving line as committed coin, trigger condition, positional relationship, automatic output, and visible failure state;
- verify that different Trick collections make the same hand produce different preferred decisions;
- identify missing family roles and design additional Tricks to fill them;
- create a small representative Trick set for the first playable prototype.

The Trick set must create interesting gameplay in a player-controlled Rig before shuffling is added. Rig randomness may challenge an existing strategy, but it cannot be responsible for creating that strategy.

### Phase 1: Rig Foundation

- Add Rig state to each round.
- Initially allow a deterministic or directly configured Rig arrangement for content testing.
- Add deterministic initial shuffle behind a prototype option.
- Add round-wide counters behind the same prototype option.
- Add full reshuffle and targeted swap actions for comparison testing.
- Enforce setup-only manipulation.
- Save, validate, and replay those actions.

### Phase 2: Coin Commitment and Source Binding

- Map selected coin slots to Rig slots.
- Activate only slotted Tricks.
- Add committed-coin and neighbour selectors.
- Resolve Tricks left to right by Rig order.
- Lock all setup state when Flip begins.

### Phase 3: First Playable Vertical Slice

Migrate:

- Forgery;
- Momentum;
- Prestige;
- Weighted.

These families exercise identity, direction, replay, and probability without requiring every advanced mechanic.

### Phase 4: Table UI

- Draw the Rig directly around coin slots.
- Add counters and manipulation controls.
- Add armed or broken previews.
- Add source-to-target execution animation.
- Update terminology and help text.

### Phase 5: Opponent Pressure

- Add a small slot-pressure vocabulary.
- Add telegraphed opponent intents.
- Add repetition limits to opponent scripts.

### Phase 6: Advanced Families

- Implement Prediction's commit-and-reveal sequencing.
- Localize Sleight substitutions.
- Add strictly capped, charm-less Smuggling overload slots.

### Phase 7: Content Cleanup

- Remove Extortion offers and definitions safely.
- Disable Fate rewards.
- Remove miscategorized economy charms.
- Audit orphaned Lucky Coins and deprecated content.
- Update documentation, development builds, and reward pools.

### Phase 8: Simulation and Balance

- Teach automated policies to manipulate the Rig.
- Compare deliberate assignments against random assignments.
- Measure layout variance.
- Compare player-arranged, initially shuffled, and reshuffle-plus-reposition variants.
- Tune reshuffle and reposition counts.
- Decide whether universal initial shuffling is necessary or opponent slot pressure already provides sufficient variation.
- Tune family effects only after the structural choices work.

---

## Verification

### Engine and State

- Initial Rig shuffles are deterministic for a given seed.
- Reshuffle and reposition counters persist for the full round.
- Counters reset only when a new round begins.
- Save/load restores the exact Rig and allowances.
- Replays reproduce all Rig changes exactly.
- Only active slotted Tricks resolve.
- Trick resolution order follows Rig position.
- No player action can mutate setup after Flip begins.

### Family Behaviour

- Each Trick has a committed coin or clearly reports why it is inactive.
- Positional targets are deterministic and visible.
- No migrated Trick silently selects the globally strongest eligible target.
- Smuggled bodies cannot acquire unrestricted Trick effects.
- Prestige cannot recurse indefinitely.
- Momentum paths are capped and readable.
- Prediction cannot scan the hand without commitment.

### Balance and Agency

Track:

- how often the initial Rig is accepted;
- how often only repositioning is used;
- how often a full reshuffle is used;
- how often all allowances are consumed;
- whether the same final arrangement repeatedly appears;
- best-layout versus worst-layout performance;
- deliberate assignment versus random assignment performance.

The agency gap should be substantially larger than the layout-luck gap:

```text
Agency gap:
deliberate coin assignment vs random coin assignment

Luck gap:
best Rig arrangement vs worst Rig arrangement under deliberate play
```

---

## Success Criteria

The update is successful when:

- A player cannot choose random coins and perform nearly as well as deliberate play.
- The best coin assignment changes with Rig order, hand, and opponent intent.
- A poor initial shuffle is inconvenient but not a dead round.
- Clever play on an awkward Rig beats careless play on an ideal Rig.
- Players do not recreate the same universal arrangement every round.
- Full reshuffle feels like emergency recovery.
- Reposition feels like precise repair.
- Trick acquisition requires excluding incompatible machinery.
- Every Trick has a visible source, condition, and positional output.
- No player action is possible after Flip begins.
- Final execution feels like watching a con the player personally prepared.

The implementation target is therefore:

> First make the Rig real, then make each surviving Trick family earn its place inside it.
