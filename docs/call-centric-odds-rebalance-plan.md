# Call-Centric Odds Rebalance Plan

## Current prototype change

- Replace the 10 plain starter `$ Coin`s with 5 `Heads-Loaded Penny` coins and 5 `Tails-Loaded Penny` coins.
- Player-facing text uses cheat-coin language, not math-weight language:
  - `A crooked coin rigged for Heads. 75% Heads chance.`
  - `A crooked coin rigged for Tails. 75% Tails chance.`
- The first target is to make the Heads/Tails call feel like a build decision: the player should call the side supported by the drawn hand.

## Viability questions to test

1. Does the player choose calls based on the hand composition?
   - Good sign: a hand with more Heads-loaded coins makes Heads feel like the obvious but still risky call.
   - Bad sign: the player still ignores the call and only hunts raw combo patterns.
2. Does 75% preserve coin-flip tension?
   - Good sign: misses happen often enough to create drama.
   - Bad sign: outcomes feel either deterministic or too swingy.
3. Do stage targets still fit the new baseline?
   - Track clear/fail rate over early stages.
   - Compare average score per flip before and after the starter-purse change.
4. Do raw-result combos overpower call-based scoring?
   - Track how often combo payouts decide a stage versus base matches/call-specific coins.
   - If combos dominate, convert common combos toward call-aware conditions first.
5. Does the terminology build trust?
   - Coin cards should show exact readable odds like `75% Heads chance`.
   - Future effects should say `Heads chance +10%`, not `+0.10 Heads weight`.

## Test pass

Run at least 10 seeded starts with the new starter purse.

For each run, record:

- Seed.
- First three hands drawn.
- Call chosen for each hand and why.
- Number of loaded coins matching the chosen call.
- Stage result and margin: cleared with how many flips left, or failed by how much.
- Score source impression: base call matches, special coin triggers, or combo triggers.

Useful quick metrics:

- Expected base matches for all-Heads call against a mixed 5-coin hand.
- Average stage score after Round 1.
- Clear rate for normal stages.
- How often the best call is visually obvious from the hand.

## Rebalance thresholds

Make the smallest next change based on test results:

- If starter hands feel too random: raise loaded coins from 75% to 80%.
- If starter hands feel solved/deterministic: lower loaded coins to 70% or reduce early rewards.
- If stage clears become too easy: raise early target scores before changing coin mechanics.
- If raw combos dominate decisions: redesign common combo coins around `matches your call` patterns.
- If players misunderstand modifiers: implement explicit chance-point math and update all player text to `chance`, `odds`, `loaded`, or `rigged`.

## Likely next design step

Move the internal odds model from normalized `headsWeight / (headsWeight + tailsWeight)` to explicit chance points:

- Base: `50% Heads / 50% Tails`.
- Loaded coin: direct `75%` toward its side.
- Modifier: `Heads chance +10%` means `75% -> 85%`.
- Cap odds, probably around `5%` minimum and `95%` maximum, so cheating stays dramatic without becoming guaranteed.

Do this only after the starter-purse test confirms the call-centric direction is worth pursuing.
