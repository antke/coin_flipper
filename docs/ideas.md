# Feature / Mechanics Ideas

These are future-facing feature ideas for the current opponent-HP hybrid purse version of the game.

The game now behaves like a small coin-purse deckbuilder wrapped in coin-flip showdowns:

- the player faces opponents with HP
- matching coins and effects deal damage
- defeating the opponent means total damage reaches or exceeds their HP
- the run owns a purse of coin instances
- duplicate coins are allowed
- each flip draws a hand from the purse
- the player chooses a call after seeing the hand
- Sleight of Hand can return a coin to the purse and draw a replacement
- the player can reorder the final hand before flipping
- flipped coins exhaust until the next stage
- shop purchases add new coin instances to the purse

Use `docs/game-mental-model-and-balance-map.md` as the current mental-model reference. `docs/hybrid-coin-purse-plan.md` is still useful background for the purse transition, but parts of it are historical.

---

## Gut-feel priority ranking

Ordered by likely value for the game right now, considering impact, implementation cost, clarity, and balance risk under the current opponent-HP purse loop.

2. **Purse Economy and Bloat Tuning**
   The shop now grows the purse with duplicate coin instances. The next design question is whether buying feels exciting, automatic, or diluted, and whether thinning/removal is needed.

3. **Cursed Coins v2 / Downside Identity**
   Cursed rarity and locked coins exist. The next pass should make cursed coins feel dangerous, not just strong-but-sticky.

4. **Stronger Semantic Feedback**
   The outcome burst already supports labels such as `COMBO`, `OVERKILL`, `CLUTCH`, and `JACKPOT`. Future work should add a few rarer, high-confidence callouts rather than more generic celebration.

5. **Coin Thinning, Merging, or Upgrades**
   Duplicates are real now, but a simple removal/thinning tool probably belongs before a full merge tree.

6. **Expand Neighbour / Order Coin Set**
   Reordering and neighbour effects are implemented. Future work should expand, tune, and clarify this family rather than establish the baseline.

7. **Expand Combo / Pattern Rewards**
   Pattern coins and combo resolution exist. Future work should add better previews, tuning, and more content only after the current examples prove readable.

8. **Divine Interventions**  
   Still thematic, but overlaps with Sleight as a manipulation layer. Any intervention should be narrow and clearly different from “just another reroll.”

9. **Luck and Karma Meters**  
   The emotional idea is good, but meter spending overlaps with Sleight, offerings, and interventions. Karma/failure builds remain the more interesting half.

10. **Mulligan Option**  
    Too generic as a universal rule because Sleight already covers the main “fix this hand” fantasy. Better as a coin, character passive, or rare intervention.

11. **Player Characters**  
    Valuable later, once the purse loop has proven build archetypes for characters to modify.

12. **Damage / Outcome Estimate on Hover**
    Useful for clarity, but exact previews may solve too much of the hand puzzle. Prefer ranges/explanations or a special character ability.

13. **Offerings**  
    Thematic, but still overlaps with betting, Luck/Karma, and interventions. Needs a sharper identity before implementation.

14. **Rooms / Stages / Map**  
    Opponent stages, variants, shops, and bosses already exist. A full map is still a large future run-structure layer, not a core-loop priority.

---

## Current baseline: Opponent HP Hybrid Purse Loop

### Implemented direction

The purse model is no longer an alternate prototype branch. It is the current core direction.

The game is now framed as coin-flip showdowns against opponents:

> Build a growing purse, draw a tactical hand, call Heads or Tails, use Sleight of Hand to improve the draw, reorder the coins, then flip the optimized setup to deal enough damage to defeat the opponent.

### Current pillars

- **Opponent HP:** encounters are cleared by dealing damage until the opponent HP threshold is reached.
- **Purse growth:** buying coins adds more coin instances instead of replacing a small fixed loadout.
- **Variance with agency:** draws create variety, while Sleight and reordering give the player control.
- **Hand-first play:** the current drawn hand should be the main decision object.
- **Ordered resolution:** final left-to-right order matters for neighbour effects and pattern checks.
- **Stage exhaustion:** flipped coins leave the available purse until the next stage.
- **Shop growth:** duplicate purchases are allowed and create new instances.

### Already implemented baseline mechanics

- Opponent names, HP, encounter variants, and boss encounters.
- Starting purse plus draft picks that add special coin instances.
- Purse draw, Sleight replacement, hand reorder, and stage exhaustion.
- Duplicate coin purchases from the shop.
- Shop rerolls, pricing by rarity, victory Chips, remaining-flip Chips, and overkill Chip rewards.
- Neighbour/edge effects and ordered resolution.
- Combo/pattern rewards and `COMBO` feedback.
- Cursed rarity, cursed styling, and locked coins that cannot be Sleighted/reordered.
- Central outcome burst labels such as `COMBO`, `OVERKILL`, `CLUTCH`, and `JACKPOT`.
- Basic flip log and purse inspection dialogs.

### Design consequences

- Future mechanics should usually interact with drawn hands, Sleight, final order, exhausted coins, opponent HP, overkill, or purse quality.
- Avoid “score target” language in player-facing docs. Use damage, HP, opponent, defeat, overkill, and Chips.
- Internal code still has legacy names such as `stageScore` and `targetScore`; docs should translate those to damage and opponent HP.
- Fixed-slot language should be avoided unless explicitly discussing old/historical behavior.
- Coin removal, thinning, merging, and upgrades are now purse-quality tools.
- Interventions, mulligans, offerings, and meters must avoid duplicating Sleight’s role.

### Known cleanup issue

The code still contains a legacy loadout/pre-stage path with active-slot concepts. Current stage resolution uses the purse instance system rather than an equipped fixed slot order, so that screen should eventually be renamed or simplified into a **Purse Review / Stage Briefing** flow.

---

## 1. Push Your Luck / Bank-or-Press

### Core idea

After the opponent is defeated, let the player either bank the win or continue flipping for extra rewards with added risk.

### Example

“The opponent is down. Bank your reward now, or press your luck with one more hand for bonus Chips. If the hand fails, lose the bonus or take a penalty.”

### Requirements

- Add a post-defeat decision phase before leaving the stage.
- Track banked clear rewards separately from push rewards.
- Define the failure penalty clearly.
- Make the risk/reward explicit before the player chooses.
- Use current remaining purse state unless a special push mode is intentionally designed.

### Technical notes

- Current HP/overkill/remaining-flip rewards already create the natural entry point.
- The result flow must distinguish normal clear, banked clear, pushed clear, and pushed failure.
- Pushing should probably continue with the current stage purse state, including exhausted coins.
- The UI should show remaining flips, remaining purse, likely reward, and penalty.

### Design effect

- Adds a natural gambling moment.
- Gives strong hands and remaining purse quality more value after a clear.
- Makes overkill and remaining flips feel like part of a larger risk/reward economy.

### Risks

- If expected value is clearly positive, players always push.
- If too punishing, players never push.
- Pushing could slow the run if offered too frequently or with too much UI.

### Evaluation criteria

- Does the choice feel optional but tempting?
- Does pushing create memorable wins and losses?
- Does it work with the purse exhaustion model?
- Does the player understand what is already banked and what is at risk?

### Comment

This is the best early prototype candidate because it uses systems that already exist instead of adding another manipulation layer. Start with one conservative version: after a defeat, offer one optional push for bonus Chips, with the bonus at risk but the stage clear safe.

---

## 2. Purse Economy and Bloat Tuning

### Core idea

Tune the shop around purse growth: offer quality, rerolls, pricing, duplicate value, bloat pressure, and eventually thinning/removal.

### Current baseline

- Shop appears after stages.
- Coin purchases add new coin instances to the purse.
- Duplicates are allowed.
- Rerolls exist and remain an important resource sink.
- The shop can inspect the current purse.
- Victory, remaining-flip, and overkill chip rewards exist.
- Active-slot replacement is no longer the main shop decision.

### Future shop actions

- Buy coins.
- Buy upgrades.
- Reroll offers.
- Inspect purse while shopping.
- Remove/thin weak coins once bloat becomes a proven problem.
- Merge or upgrade duplicates once duplicate pressure exists.
- Possibly sell coins/upgrades later, but not before the basic purse economy is tuned.

### Requirements

- Coin prices need to account for dilution and duplicate value.
- Offers should communicate “adds one coin to your purse.”
- Reroll cost and free rerolls should be balanced against purse bloat.
- Removal/thinning should only be added when buying starts to feel bad due to dilution.

### Technical notes

- Offer generation already supports duplicate coin definitions across purchases.
- Purchase flow creates a new coin instance every time.
- Current offer rolls avoid showing the same coin definition twice in a single generated set.
- Future thinning requires removing specific instances, not just definition ids.

### Design effect

- Makes spending feel rewarding because the purse visibly grows.
- Creates deckbuilder-style decisions around consistency versus power.
- Lets the player shape draw odds over the run.

### Risks

- If all coins are good and cheap, the correct move is always buy.
- If weak coins dilute too much, players stop buying.
- Too many management actions can slow the shop.

### Open questions

- How cheap should common coins be with duplicates allowed?
- When does purse bloat become a real problem?
- Should thinning be bought, earned, or attached to specific coin effects?
- Should there eventually be a maximum purse size, or should bloat be self-balancing?
- Should same-definition duplicates become more likely in shops, or remain spread out?

### Evaluation criteria

- Do players usually want to buy something without every purchase being automatic?
- Do duplicate offers feel exciting, acceptable, or disappointing?
- Does rerolling create enough tension as the main resource sink?
- Does the purse become more interesting rather than merely larger?

### Comment

Do not immediately grow the shop into buying, selling, merging, thinning, permanent upgrades, and collection management all at once. The next step should be tuning the purse economy and watching whether bloat actually appears.

---

## 3. Cursed Coins v2 / Downside Identity

### Core idea

Make cursed coins dangerous coins with strong upside and clear downside.

The baseline exists: cursed rarity, cursed visual treatment, `cannotSleight`, `cannotReorder`, and sticky high-upside examples. The next step is giving curses a sharper risk identity.

### Example effects

- Cannot be Sleighted, but pays double on match.
- Cannot be Sleighted; if it misses, it penalizes adjacent coins.
- Cannot be reordered; if placed poorly, its downside is harder to avoid.
- If all coins match, huge payout; if the pattern breaks, lose Chips or damage.
- If protected by a neighbour/protection effect, its penalty is reduced.

### Requirements

- Cursed styling must be visually distinct.
- `cannotSleight` and `cannotReorder` must be communicated before purchase and when drawn.
- Downsides should be deterministic and readable.
- Players need enough control to build around the risk: reordering, neighbour protection, pattern payoff, or future interventions.
- Cursed coins should be tempting, not automatic picks and not traps.

### Technical notes

- Coin definitions already support locked behavior fields.
- Scoring may need clearer support for penalties, negative modifiers, or risky conditional payouts.
- Cursed effects should be data-driven so reward/penalty numbers can be tuned quickly.
- Logs and feedback should identify cursed outcomes clearly.

### Design effect

- Gives the purse dangerous texture.
- Makes some draws tense because not every bad coin can be dodged.
- Creates strong build-around opportunities with protection, adjacency, pattern effects, and Karma/failure mechanics.

### Risks

- If the downside is too severe, cursed coins become traps.
- If the upside is too high or easy to guarantee, cursed coins become automatic.
- Run-ending penalties may feel unfair if the player did not understand the risk.
- Sticky coins can feel frustrating if they only remove agency.

### Evaluation criteria

- Is the cursed coin tempting despite the risk?
- Can the player intentionally build around it?
- Does locked behavior feel tense rather than frustrating?
- Does the player understand the downside before it happens?

### Comment

The first v2 cursed coin should probably be simple: cannot Sleight, high damage on match, mild visible penalty on miss. Avoid complicated curse ecosystems until one downside coin feels good.

---

## 4. Inspectable Event Log Improvements

### Core idea

Improve the existing flip log so players can inspect complex resolution without cluttering the main UI.

### Current baseline

A basic flip log exists and can show coin outcomes, weight details, damage details, and resolution order. Purse inspection also exists.

### Future improvements

- Show hand draw events.
- Show Sleight return and replacement events.
- Show reorder events and final order.
- Show triggered coin hooks in player-readable language.
- Show neighbour effects and their targets.
- Show combo/pattern hits and misses where useful.
- Show penalties and cursed effects clearly.
- Show overkill and reward calculations clearly.

### Requirements

- Keep the log hidden by default.
- Use concise player-facing descriptions instead of raw internal hook names wherever possible.
- Preserve enough detail to debug confusing damage outcomes.
- Keep chronology clear: draw → Sleight/reorder → flip → effects → damage/rewards → opponent check.

### Technical notes

- Current history already tracks draw, Sleight, reorder, hook, and flip data in several places.
- The log should combine those into a chronological resolution story.
- Long-term, replay/debug logs and player-facing logs may need different formatting layers.

### Design effect

- Supports more complex scoring without overwhelming the main screen.
- Helps players trust unusual outcomes.
- Helps development/debugging while systems are still changing.

### Risks

- A detailed log can become too technical.
- Building a huge log UI too early may waste effort if scoring changes.
- If wording diverges from actual resolution, the log becomes misleading.

### Evaluation criteria

- Can a player answer “why did that happen?” after opening the log?
- Does the main stage view stay clean when the log is closed?
- Are combo/neighbour/cursed/Sleight events understandable without reading code-like terms?

### Comment

This should be incremental. The log exists; the next upgrade should be better event wording for Sleight/reorder/hook triggers rather than a large new interface.

---

## 5. Stronger Semantic Feedback

### Core idea

Improve emotional feedback so the game celebrates player decisions and makes each hand feel dramatic.

The presentation foundation already exists. The next step is not “add feedback” in general, but adding a few semantic callouts for genuinely notable outcomes.

### Existing baseline

- Coin reveal motion.
- Match/miss particles.
- Sleight animation.
- Central outcome burst labels.
- Current labels include ideas such as `COMBO`, `OVERKILL`, `CLUTCH`, `JACKPOT`, and match-count based praise.

### Possible future labels

- `PERFECT HAND`
- `SLEIGHT SAVE`
- `RARE HIT`
- `CURSE SURVIVED`
- `ALL HEADS`
- `ALL TAILS`
- `LAST FLIP CLEAR`
- `BIG OVERKILL`

### Requirements

- Detect notable hand outcomes, not just stage clear/fail.
- Detect when Sleight materially improves a hand or triggers a valuable effect.
- Detect high-value reorder/neighbour/pattern outcomes.
- Keep messages short and rare enough to feel special.
- Avoid duplicating information already visible in the opponent/damage panel.

### Technical notes

- Extend the existing outcome burst before adding a new presentation system.
- Feedback should be driven by scoring/resolution facts, not UI guesses.
- Useful trigger inputs include match count, damage delta, Chips delta, overkill amount, final hand pattern, Sleight history, reorder history, and triggered sources.
- Label priority matters: a combo overkill clutch hand should not spam three competing banners.

### Risks

- Too many messages become noise.
- If feedback fires for ordinary outcomes, it stops feeling celebratory.
- If priority rules are unclear, the “wrong” label may appear for a memorable event.

### Evaluation criteria

- Do normal flips feel more dramatic without changing balance?
- Do players understand why a hand was special?
- Are the messages punchy enough to be noticed but not intrusive?

### Comment

Keep this small. Add only high-confidence facts that are easy to explain and unlikely to fire constantly.

---

## 6. Coin Thinning, Merging, or Upgrades

### Core idea

Use duplicate ownership and purse management to let players improve purse quality. This can include removing weak coins, merging matching coins into a stronger coin, or upgrading specific instances.

### Likely order

1. Add simple thinning/removal if purse bloat becomes painful.
2. Add duplicate upgrades/merges only after duplicate pressure is proven.
3. Add per-instance upgrades only if the UI can support it cleanly.

### Example merge

- Merge three **Heads Hunter** instances into one upgraded Heads Hunter.
- The upgraded coin has better stats, a new tag, or an additional trigger.

### Requirements

- The UI must show owned duplicate counts clearly.
- Removal must explain which instance leaves the run purse.
- Merging must explain which instances are consumed and what is created.
- Upgraded coins need visibly different names, tiers, stats, or art treatment.

### Technical notes

- Coin instances already support duplicates, but merging needs instance selection/removal rules.
- Coin definitions need tiered versions or an upgrade formula.
- Purse inspection may need grouping plus detailed instance view if per-instance upgrades exist.
- Save/replay logs should record consumed and created instance ids.

### Design effect

- Makes duplicate purchases more exciting.
- Gives players a way to improve consistency.
- Creates a late-run resource sink.
- Helps solve bloat if the purse starts feeling diluted.

### Risks

- If merging is too strong, forcing duplicates becomes optimal.
- If losing three coins for one feels bad, players avoid it.
- UI can become heavy if it requires too much instance management.
- Removal can make the purse too consistent if it is cheap and frequent.

### Open questions

- Should thinning/removal come before merging?
- Should merging cost only the coins, or coins plus Chips?
- Should upgraded coins count as the same definition for future merges?
- Can some coins upgrade through use instead of shop management?

### Evaluation criteria

- Do duplicates feel better after this system exists?
- Does purse quality improve without making the shop too complex?
- Is the merge/removal choice understandable at a glance?

### Comment

This used to depend on a more mature inventory model. The hybrid purse now provides the missing foundation, but this should still wait until duplicate/bloat pain is observed. Simple thinning is probably a better first step than a full merge tree.

---

## 7. Expand Neighbour / Order Coin Set

### Core idea

Expand coins that care about adjacent coins or final hand position. Reordering turns these into tactical hand-arrangement pieces instead of fixed build-position pieces.

### Current baseline

- Drag reorder exists.
- Final hand order determines resolution order.
- Neighbour targeting exists.
- Edge/adjacency coins exist.
- Some coins can be locked against reordering.

### Example future effects

- A coin copies the result of the coin to its left.
- A coin deals bonus damage only when placed on an edge.
- A coin pays out if placed between two matching results.
- A coin protects adjacent cursed coins from penalties.
- A coin changes behavior when surrounded by misses.

### Requirements

- Final hand order must be visible and understandable.
- Reorder controls must feel quick enough that neighbour coins do not slow every flip.
- Coin cards should communicate targeting clearly.
- Resolution order must remain deterministic.

### Technical notes

- Effects should evaluate against final resolution order, not original draw order.
- Hook payloads need access to left/right neighbours when relevant.
- Existing neighbour targets such as `self_and_left_neighbor` / `self_and_right_neighbor` can be expanded gradually.

### Design effect

- Makes drawn hands feel like small puzzles.
- Gives the player a reason to care about order before flipping.
- Preserves combo crafting inside a variable draw system.

### Risks

- Too many adjacency effects could make the hand hard to read.
- If reorder interaction is clumsy, these coins will feel annoying instead of clever.
- If every hand needs exact ordering, the core loop may slow down.

### Evaluation criteria

- Does reordering create satisfying decisions without becoming busywork?
- Can players predict which coins affect which neighbours?
- Do neighbour coins remain valuable even with random draws?

### Comment

This is now implemented as a baseline direction. Future work should be content expansion and clarity, not proving whether hand order matters.

---

## 8. Expand Combo / Pattern Rewards

### Core idea

Reward specific final hand patterns as combo goals, such as `HHH`, `HTH`, all same, alternating results, edge matches, or call-aligned sequences.

Pattern checks happen after Sleight, reordering, coin flips, and result-modifying effects.

### Current baseline

- Combo resolver exists.
- Pattern coins exist.
- Adjacent result sequences and matching-edge checks exist.
- Combo hits can set combo flags, add damage/Chips, and produce `COMBO` feedback/log notes.

### Example future effects

- Bonus damage if the final result pattern contains `HTH`.
- Bonus Chips if all visible coins match the call.
- A coin pays out if the two coins beside it land the same way.
- A rare upgrade doubles damage for alternating results.
- A cursed coin pays huge if the whole hand matches but penalizes if the pattern breaks.

### Requirements

- Define whether patterns use results, calls, coin tags, coin identities, or positions.
- Start with exact result patterns and simple whole-hand conditions.
- UI must show the target clearly before the flip when possible.
- Feedback should highlight successful combo hits clearly.

### Technical notes

- Pattern checks need ordered final hand results.
- Exact sequences should come before wildcards, partial matches, or regex-like logic.
- Pattern rewards should remain data-driven.
- Combo preview should be conservative if results are still random.

### Design effect

- Adds build variety beyond simply calling Heads or Tails.
- Gives Sleight and reorder more concrete goals.
- Creates exciting “can I line this up?” moments.

### Risks

- Patterns can feel too random if the player has too little control.
- Patterns can become too reliable if manipulation tools stack too heavily.
- Complex patterns may be hard to parse quickly.

### Evaluation criteria

- Does pattern matching create an understandable alternate build path?
- Does the player know when the pattern is checked?
- Does the reward feel worth the extra attention?

### Comment

This has graduated from future concept to implemented family. The next work should be tuning, clearer wording, and deciding which pattern types are readable enough to expand.

---

## 9. Divine Interventions

### Core idea

Add rare special actions that manipulate results, protect against bad luck, or create dramatic one-off saves.

### Example interventions

- **Vanish:** remove one coin from the final result set before scoring.
- **Flip Gravity:** invert all current coin results.
- **Blessed Nudge:** reroll one missed coin.
- **Bad Luck Protection:** reduce or prevent one penalty.
- **Last Prayer:** one final boost if the stage would fail.

### Requirements

- Interventions must be clearly distinct from Sleight.
- They should probably be rare, charged, or expensive.
- UI must show when they can be activated.
- Effects must resolve at a clear point: likely after reveal but before final scoring, or at a special failure-prevention window.

### Technical notes

- Needs a post-flip or pre-scoring resolution phase if effects alter visible results.
- Result transformations should be explicit and replayable.
- Owned charges/uses need to be tracked in run or stage state.

### Design effect

- Gives players agency after randomness happens.
- Creates high-value chase purchases.
- Can support cursed or pattern builds by fixing rare failures.

### Risks

- Post-flip manipulation is extremely powerful because it uses full information.
- Too many interventions can make the initial flip feel less important.
- It can overlap with Sleight, Luck, Karma, and mulligans.

### Evaluation criteria

- Does the intervention feel like a rare miracle rather than a required correction?
- Does it add a decision without trivializing bad draws?
- Can it be balanced through cost, rarity, charges, or timing?

### Comment

Still thematic and exciting, but lower priority after Sleight. If added, start with one narrow effect such as Vanish or Last Prayer, not a broad second ability system.

---

## 10. Luck and Karma Meters

### Core idea

Add round- or stage-scoped meters that build from outcomes. Correct guesses build Luck. Misses build Karma. The player can spend these meters for special effects or alternate rewards.

### Possible Luck behavior

- Correct guesses increase Luck.
- Luck helps press an advantage, such as improving payout or improving odds on a future hand.
- Luck may reset each stage.

### Possible Karma behavior

- Misses increase Karma.
- Karma supports fail-forward builds, protection, or alternate payouts.
- Karma could power cursed coins or bad-luck conversion effects.

### Requirements

- Luck and Karma must have distinct identities.
- Define when meters are gained and spent: before hand, after draw, after Sleight, after flip, or between stages.
- UI must be small enough not to compete with the hand.
- Spending must not become an automatic always-correct action.

### Technical notes

- Add stage- or run-scoped meter state.
- Outcome generation and scoring need hooks for meter effects.
- Meter changes should appear in feedback/logs.

### Design effect

- Makes streaks emotionally meaningful.
- Gives missed calls a possible purpose.
- Opens fail-build and curse-build space.

### Risks

- If both meters just “improve odds,” the system adds UI without much payoff.
- Meter spending overlaps with Sleight and interventions.
- Too many manipulation layers can make the game feel overcontrolled.

### Evaluation criteria

- Are Luck and Karma distinct?
- Do the meters create decisions rather than automatic spending?
- Does Karma make failure interesting without making failure optimal too often?

### Comment

Karma remains the more interesting half. A first version might skip Luck entirely and introduce Karma as a failure-conversion mechanic attached to a small set of coins.

---

## 11. Mulligan Option

### Core idea

Allow a limited reroll/redraw/reset action.

### Possible versions

- Redraw one hand slot before Sleight.
- Reset Sleight on one slot.
- Reroll one revealed coin after the flip.
- Redraw one shop offer.
- Replace the whole hand at a major cost.

### Requirements

- The mulligan target must be specific.
- Uses must be tracked clearly.
- It should not duplicate normal Sleight.

### Technical notes

- A pre-flip hand-slot mulligan is very close to Sleight and probably should be a coin/passive, not a universal rule.
- A post-flip reroll requires result transformation and replay logging.
- A shop mulligan could be implemented through existing reroll systems.

### Design effect

- Reduces frustration from bad luck.
- Can create a clear character or rare-item identity.

### Risks

- Universal mulligans make bad draws too easy to fix.
- Vague “try again” actions are less interesting than targeted tools.

### Evaluation criteria

- Does the mulligan solve a specific frustration?
- Is it different enough from Sleight?
- Does it feel valuable without becoming mandatory?

### Comment

Do not add this as a default rule. It is better as a character passive, rare intervention, or coin-specific effect.

---

## 12. Player Characters

### Core idea

At the beginning of a run, let the player choose a character. Each character changes the purse loop through a passive rule, starting purse, or special mechanic.

### Example characters

- **Gambler:** higher payouts on perfect hands, harsher penalties on misses.
- **Magician:** one extra Sleight per stage or improved replacement odds.
- **Collector:** starts with more special coins but a larger/weaker purse.
- **Oracle:** sees limited damage/odds previews.
- **Scoundrel:** cursed coins are cheaper and slightly safer.

### Requirements

- Add character selection before run start.
- Character effects should push distinct purse strategies.
- Unlock conditions or meta progression need persistence.
- Effects should reuse existing hooks where possible.

### Technical notes

- Character definitions need id, name, description, unlock condition, and passive effect.
- Run state should reference selected character.
- Passive effects may touch starter purse, Sleight count, shop generation, scoring, or feedback.

### Design effect

- Adds replayability.
- Gives players long-term goals.
- Helps frame different build archetypes.

### Risks

- Too early, characters become bland stat modifiers.
- Strong unlockable characters can create progression imbalance.
- Each unique passive can add special-case complexity.

### Evaluation criteria

- Does each character change how the player evaluates hands and shops?
- Are unlocks motivating without being grindy?
- Can passives be implemented mostly through existing systems?

### Comment

Keep this for later. Characters will be much better once there are proven archetypes: neighbour/order builds, pattern builds, cursed builds, economy builds, and fail/Karma builds.

---

## 13. Damage / Outcome Estimate on Hover

### Core idea

Show a damage estimate or explanation when hovering over a possible action, hand, coin, or shop purchase.

### Possible versions

- Show deterministic parts of damage only.
- Show damage range.
- Show expected value.
- Show “likely value” with uncertainty.
- Show exact preview only for a special character or upgrade.

### Requirements

- Decide whether previews explain current hand, possible Sleight outcomes, or shop purchases.
- Avoid revealing so much that the hand puzzle becomes solved automatically.
- Preview must stay accurate enough to be trusted.

### Technical notes

- Exact preview is hard if effects depend on random results, future replacements, or conditional hooks.
- A partial explanation layer may be easier and safer than full simulation.
- Could reuse damage breakdown formatting for deterministic pieces.

### Design effect

- Improves clarity for complex scoring.
- Helps players learn coin effects.
- Can be a character-defining ability if exact previews are restricted.

### Risks

- Exact previews may remove uncertainty.
- Expected value math may feel too abstract or encourage spreadsheet play.
- Inaccurate previews are worse than no preview.

### Evaluation criteria

- Does the preview teach without solving?
- Does it make decisions clearer?
- Is the implementation maintainable as scoring grows?

### Comment

Prefer explanations and ranges before exact numbers. Exact hand-solving is probably best as a character ability or rare upgrade.

---

## 14. Offerings

### Core idea

Before a flip, the player can sacrifice damage, Chips, coins, meter value, or another resource for a temporary effect.

### Example effects

- Pay Chips to improve the selected call’s odds.
- Sacrifice current damage progress for a larger payout if the hand succeeds.
- Exhaust a coin voluntarily for a temporary boost.
- Spend Karma to protect a cursed coin.

### Requirements

- Offerings must be meaningfully different from normal betting, Sleight, and interventions.
- The sacrifice and effect must be shown clearly.
- The player must be able to skip.
- Choices should be dramatic, not automatic expected-value calculations.

### Technical notes

- Requires a pre-flip decision phase if implemented as a general system.
- Outcome generation/scoring needs temporary modifiers.
- Voluntary coin sacrifice would need zone movement rules.

### Design effect

- Adds thematic divine/gambling flavor.
- Gives players another way to manage risk.
- Could create interesting interactions with cursed or Karma builds.

### Risks

- “Pay Chips to improve odds” may be too solvable.
- Overlaps with Luck/Karma and interventions.
- Adds another pre-flip step to a loop that already has draw, call, Sleight, reorder, and flip.

### Evaluation criteria

- Does the offering create a real trade-off?
- Does it feel different from a bet or reroll?
- Does it improve the hand loop without slowing every flip?

### Comment

Still low priority. The best version is probably not a universal offering screen, but a few specific coin/intervention effects that ask for sacrifices at dramatic moments.

---

## 15. Rooms / Stages / Map

### Core idea

Add a map, rooms, or branching stage structure to the run.

### Current baseline

- Opponent encounters exist.
- Stage variants exist.
- Boss encounters exist.
- Shops exist between stages.

### Possible room types

- Normal opponent
- Elite/boss opponent
- Shop
- Event
- Reward
- Rest/thinning opportunity
- Curse shrine / offering room

### Requirements

- Define room types and rewards.
- Add progression state across rooms.
- Decide how the map changes the current stage/shop rhythm.
- Create enough event content to justify the structure.

### Technical notes

- Would require new run navigation state and UI.
- Shop/result flow would need to route based on map node outcomes.
- Save data must persist map position and generated nodes.

### Design effect

- Adds macro-level route decisions.
- Can pace shops, events, bosses, and risk/reward rooms.
- Gives thinning, offerings, and special rewards a natural home.

### Risks

- Very large scope.
- Requires encounter/event design in addition to UI and state changes.
- Could distract from proving the core purse hand loop.

### Evaluation criteria

- Does route choice add meaningful decisions beyond the shop?
- Does the current stage/shop loop feel too flat without it?
- Is there enough content to support a map?

### Comment

Keep this as a future run-structure layer. It should wait until the hand loop, purse economy, and build archetypes are fun without a map.

---

## Historical / Retired Idea: Coin Purse / Drafted Flip Pool

### Status

This idea has effectively graduated into the current hybrid purse baseline.

The original version asked whether the game should replace fixed slots with a purse/deckbuilder model. That decision has now been made in a hybrid form: the player builds a purse, draws hands, uses Sleight, reorders, and flips the final hand.

### Remaining follow-ups

The unresolved parts of the old idea now live elsewhere in this backlog:

- purse bloat and pricing → **Purse Economy and Bloat Tuning**
- tactical hand arrangement → **Expand Neighbour / Order Coin Set**
- ordered result goals → **Expand Combo / Pattern Rewards**
- duplicate value → **Coin Thinning, Merging, or Upgrades**
- sticky/dangerous purse cards → **Cursed Coins v2 / Downside Identity**

### Comment

Do not treat “coin purse” as a separate future feature anymore. Future design should assume the hybrid purse model unless explicitly exploring a different prototype branch.
