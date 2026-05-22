# Game Mental Model and Balance Map

## Core mental model

The player is a gambler in coin-flip showdowns. Each encounter has an opponent with HP. The player calls Heads or Tails, flips their hand, and deals damage with coins that match the call plus coin effects and combos. When total damage dealt reaches opponent HP, the opponent is defeated.

There is no enemy turn, player HP, or combat loop right now. Opponents are obstacles/checks for the player's coin build.

## Current internal names

Some engine names are still legacy:

- `stageScore` = damage dealt to the current opponent
- `targetScore` = opponent HP
- `runTotalScore` = total run damage
- `shopPoints` = Chips / casino chip currency
- `stageClearShopPoints` = legacy record field for victory chips granted

## Main tuning files

### Economy rewards and shop prices

File: `src/content/economy.lua`

Tune here when you want to change:

- coin shop prices by rarity
- upgrade shop prices by rarity
- base victory chips
- remaining-flip chip rewards
- overkill chip rewards and cap

Current reward model:

```lua
victory chips = baseShopPoints
  + min(overkill cap, floor(overkill damage * overkill rate))
  + remaining flips * remainingFlipShopPoints
```

### Coins

File: `src/content/coins.lua`

Tune here when you want to change:

- coin names, rarity, descriptions, tags
- coin trigger timing
- damage, run damage, chips, multipliers, and weight/chance effects
- combo coin definitions

### Run upgrades

File: `src/content/upgrades.lua`

Tune here when you want to change shop upgrades that affect only the current run.

### Meta progression

Files:

- `src/content/meta_progression.lua` — meta reward formula after a run ends
- `src/content/meta_upgrades.lua` — meta upgrade costs, unlocks, and persistent bonuses

Tune here when you want to change long-term progression speed or unlock pacing.

### Opponents / encounter HP

File: `src/content/stages.lua`

Tune here when you want to change:

- opponent names/flavor
- opponent HP
- stage/boss modifiers attached to encounters

## First balance levers to try

If players cannot buy enough after wins:

1. Lower coin prices in `src/content/economy.lua`.
2. Raise `baseShopPoints`.
3. Raise `remainingFlipShopPoints` if fast wins should feel especially good.
4. Raise `overkillShopPointsPerDamage` or cap if explosive builds should snowball more.

If runs snowball too hard:

1. Lower overkill cap first.
2. Lower remaining-flip rewards second.
3. Raise uncommon/rare coin prices.
4. Raise later opponent HP in `src/content/stages.lua`.

If calls still feel irrelevant:

1. Rework common combo coins in `src/content/coins.lua` to care about matching the chosen call.
2. Adjust loaded starter coin odds/effects in `src/content/coins.lua`.
3. Tune opponent HP only after the call/coin incentives feel right.
