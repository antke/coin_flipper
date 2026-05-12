# Economy, Draft, and Betting Plan

Goal: make runs center on a modular chip economy while keeping the change easy to tune or revert.

## Step 1: Expand common coins

- Add more default-unlocked common coins with simple, readable hooks.
- Cover clear archetypes: heads, tails, misses, streaks, alternating calls, comeback, over-target, and bankroll scaling.
- Keep each coin data-driven in `src/content/coins.lua` so balance can change without engine rewrites.

## Step 2: Starting draft

- Replace the static starter collection with a seed-deterministic draft of 5 common/default-unlocked coins.
- Keep active slots at 3 for now; the loadout screen remains the selection point.
- Preserve modularity by adding draft helpers to coin/run initialization code instead of hard-coding UI behavior.

## Step 3: Chip economy

- Treat stage score as the chips earned during the current stage.
- On stage clear, grant a small fixed pass reward to spendable chips; default: 3.
- Keep spending separate from stage clearance: shop purchases subtract from spendable chips but do not undo cleared stages.
- Keep existing `shopPoints` storage initially as the spendable chip field to minimize migration risk; rename-facing UI text can follow after playtesting.

## Step 4: Modular bets

- Add a small bet model selected before resolving a batch.
- First implementation should expose bet metadata and result context without locking final payout design.
- Initial default bet options: no bet plus one simple risky bet.
- Bet resolution should be isolated in its own system so upgrades can later modify odds, stake, payout, or loss behavior through hooks/effective values.

## Step 5: Shop rebalance

- Increase prices because spendable chips are now tied to stage performance and carry over.
- Initial tuning target: common 8, uncommon 15, rare 25; upgrades remain slightly more expensive.
- Expect these values to change after simulation and playtesting.

## Step 6: Verification

- Run artifact/invariant/replay/engine fixture scripts after changes.
- Run simulation to check that shops, saves, and stage flow survive the new economy.
