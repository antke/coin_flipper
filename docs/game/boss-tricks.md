# Boss Tricks

Boss Tricks are authored encounter rules. Bosses never draw regular Enemy
Tricks, and each boss keeps its named Boss Trick for every Flip.

Boss intent is selected with deterministic run RNG, shown during setup, locked
when Flip begins, and recorded in save and replay state.

## Betting Betty — The Favourite

Before every Flip, Betting Betty randomly selects Heads or Tails as the
favourite and reveals it before setup.

- Every committed root coin gains +15 percentage points toward the favourite.
- Favourite Outcomes score at 75%.
- Underdog Outcomes score at 150%.
- Smuggled and Contraband bodies do not receive the initial Chance adjustment,
  but their Outcomes use the table-wide payout rule.
- A new seeded selection is made before every Flip; the same side may be
  selected on consecutive Flips.

The Favourite is the Weighted-family boss pattern. It rewards players who can
decide whether reliable lower payout or risky higher payout is correct for the
current hand.

## Washed-up Magician — Centre Stage

Before every Flip, one legal coin slot is randomly placed under the Spotlight
and revealed during setup.

- Score is totalled per legal slot after normal scoring, Prestige replays,
  Forgery copies, and reactivations resolve.
- Smuggled and Contraband bodies count toward the legal slot that brought them
  onto the table.
- If the Spotlight slot has the highest final Score, including ties, it
  performs an Encore worth 50% of that Score.
- If another slot has the highest final Score, that slot is Upstaged and loses
  50% of its Score.
- A new seeded Spotlight is selected before every Flip; the same slot may be
  selected consecutively.

Centre Stage is the Prestige-family boss pattern. It gives the player a visible
setup objective and tests whether they can concentrate their strongest engine
in the correct slot without letting another slot steal the show.

## Madcap Lunatic — Full Throttle

Before every Flip, either the far-left or far-right legal slot becomes the
Lead. The route and all three effectiveness values are revealed during setup.

- Lead on the left: 50% → 100% → 150%.
- Lead on the right: 150% ← 100% ← 50%.
- Coin Outcome Score is credited to that coin's legal slot.
- Score-producing Trick effects are credited to the slot whose coin activated
  them. This includes Prestige replays, Forgery copies, Momentum propagation,
  and reactivated Outcomes.
- All credited Score is totalled and scaled once after normal Trick resolution,
  preventing nested multipliers from applying Full Throttle more than once.
- A new seeded Lead edge is selected before every Flip; the same edge may be
  selected consecutively.

Full Throttle is the Momentum-family boss pattern. Its random intent changes
the setup puzzle without making the execution depend upon another success
chain: the player sees the complete route and chooses the coin order.

## The Impostor — Stolen Identity

Before every Flip, two adjacent legal slots are marked with a directed
Victim → Impostor relationship.

- The Victim coin retains and activates its genuine family normally.
- The Impostor coin retains its body, material, value, result, and physical
  tags, but uses the Victim's family as its activation family for that Flip.
- The Impostor coin does not activate its own genuine family's Tricks.
- Other coins may still activate that suppressed family normally.
- If the Victim slot is empty while the Impostor is occupied, the Impostor
  activates no family.
- The relationship is selected with deterministic run RNG, revealed before
  setup, and locked during execution.

Stolen Identity is the Forgery-family boss pattern. It creates a controlled
fraudulent substitution: the player chooses which developed family to
duplicate and which coin activation to surrender in exchange.

## The Quickhand — Three Cups

Three Cups has no setup marker. When the player locks Flip, The Quickhand
secretly shuffles the committed coin bodies between the occupied legal slots.

- Exactly one shuffled coin is palmed when at least two coins were committed.
- The palmed coin does not activate Tricks, roll, or score during that Flip.
- The palmed coin is returned to the dealt hand instead of being spent.
- A single committed coin is neither shuffled nor palmed, preventing an empty
  execution.
- Surviving coins use their new legal slots for Prediction and all other slot
  effects.
- Smuggled and Contraband bodies are not part of the initial cup shuffle.
- The complete shuffle, palm, and reveal are deterministic and recorded in the
  replay trace, but remain hidden until execution.
- The Quickhand has 60 HP, 25% below the standard 80-HP boss baseline.

Three Cups is the Sleight-of-Hand-family boss pattern. It tests redundancy:
the player can commit similarly valuable bodies, spread activation support, or
risk placing one indispensable coin into the hustle.

## The Taxman — Nothing to Declare

Before every Flip setup, one legal slot is randomly marked Off the Books.

- The marked slot and its current body are visible throughout setup.
- Score credited to the Off-the-Books slot is not taxed.
- Every other slot loses 30% of its final credited Score, rounded down per
  slot.
- Coin Outcomes, Prestige replays, Forgery copies, Momentum bonuses,
  reactivations, and Smuggling overloads use their existing origin-slot credit.
- Overloaded bodies anchored to the protected slot are protected as part of
  that slot's shipment.
- Positive table-wide Score without a slot origin is taxed at 30% and receives
  no exemption.
- Tax is calculated and deducted once after normal Trick resolution.
- A new seeded slot is selected before each Flip; the same slot may repeat.

Nothing to Declare is the Smuggling-family boss pattern. The Taxman supplies
the pressure, while the player thematically smuggles the strongest available
engine through the one channel that escaped inspection.

## Blind Prophet — Written in Stone

Before every Flip setup, all slots receive a visible Heads or Tails
inscription. Every pattern contains both sides, so a three-slot table can
never show H/H/H or T/T/T.

- A coin resolves to the side written on its physical slot.
- Smuggling overloads inherit the inscription of their anchor slot.
- Ordinary Prediction cannot replace a Written in Stone result.
- Twist of Fate remains stronger and forces every coin to match the player's
  call.
- The inscription is locked when Flip begins and a fresh seeded pattern is
  generated before the next setup.
- The standard boss target remains 80 HP for initial tuning.

Written in Stone is the Prediction-family boss pattern. It removes outcome
uncertainty while turning the global call and coin order into the player's
central decisions: valuable bodies belong in slots whose known result matches
the chosen call.
