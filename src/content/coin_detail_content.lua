local Terminology = require("src.content.terminology")

local CoinDetailContent = {}

local function clampChance(value)
  return math.max(0, math.min(1, value or 0))
end

local function targetsSelf(target)
  return target == nil
    or target == "self_and_left_neighbor"
    or target == "self_and_right_neighbor"
    or target == "self_and_neighbors"
end

local function applyChanceDelta(headsChance, side, amount)
  if side == "heads" then
    return clampChance(headsChance + (amount or 0))
  end

  if side == "tails" then
    return clampChance(headsChance - (amount or 0))
  end

  return headsChance
end

local function getIntrinsicChance(coin)
  local headsChance = 0.5

  for _, trigger in ipairs(coin and coin.triggers or {}) do
    if trigger.hook == "before_coin_roll" and trigger.condition == nil then
      for _, effect in ipairs(trigger.effects or {}) do
        if effect.op == "modify_coin_weight" and effect.persistent ~= true and targetsSelf(effect.target) then
          headsChance = applyChanceDelta(headsChance, effect.side, effect.amount)
        end
      end
    end
  end

  return headsChance, 1 - headsChance
end

local function formatChancePair(headsChance, tailsChance)
  return string.format("%.0fH %.0fT", (headsChance or 0) * 100, (tailsChance or 0) * 100)
end

local function capitalize(value)
  local text = tostring(value or "common")
  return (text:gsub("^%l", string.upper))
end

function CoinDetailContent.build(coin)
  if not coin then
    return nil
  end

  local headsChance, tailsChance = getIntrinsicChance(coin)
  local rarity = coin.rarity or "common"
  local pills = {
    {
      kind = "rarity",
      value = rarity,
      label = capitalize(rarity),
    },
  }

  for _, tag in ipairs(coin.typeTags or {}) do
    table.insert(pills, {
      kind = "type",
      value = tag,
      label = Terminology.getTagLabel(tag),
    })
  end

  return {
    title = coin.name or coin.id,
    pills = pills,
    chanceText = formatChancePair(headsChance, tailsChance),
    effectText = Terminology.formatText(coin.effectDescription or ""),
    description = Terminology.formatText(coin.description or ""),
  }
end

return CoinDetailContent
