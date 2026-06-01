local Terminology = {}

Terminology.terms = {
  batch = { label = "Flip", lower = "flip", plural = "flips" },
  flip = { label = "Flip", lower = "flip", plural = "flips" },
  roll = { label = "Roll", lower = "roll", plural = "rolls" },
  call = { label = "Call", lower = "call", plural = "calls" },
  heads_call = { label = "Heads Call", lower = "Heads call", plural = "Heads calls" },
  tails_call = { label = "Tails Call", lower = "Tails call", plural = "Tails calls" },
  repeated_call = { label = "Repeated Call", lower = "repeated call", plural = "repeated calls" },
  matching_call = { label = "Matching Call", lower = "matching call", plural = "matching calls" },
  active_coin = { label = "Active Coin", lower = "active coin", plural = "active coins" },
  hand = { label = "Hand", lower = "hand", plural = "hands" },
  purse = { label = "Pouch", lower = "pouch", plural = "pouches" },
  sleight = { label = "Sleight", lower = "Sleight", plural = "Sleights" },
  replacement_coin = { label = "Replacement Coin", lower = "replacement coin", plural = "replacement coins" },
  reorder = { label = "Reorder", lower = "reorder", plural = "reorders" },
  chip = { label = "Chip", lower = "chip", plural = "Chips" },
  free_reroll = { label = "Free Reroll", lower = "free reroll", plural = "Free Rerolls" },
  head_weight = { label = "Head Chance", lower = "Head chance", plural = "Head Chances" },
  heads_weight = { label = "Heads Chance", lower = "Heads chance", plural = "Heads Chances" },
  tail_weight = { label = "Tail Chance", lower = "Tail chance", plural = "Tail Chances" },
  tails_weight = { label = "Tails Chance", lower = "Tails chance", plural = "Tails Chances" },
  stage_score = { label = "Damage", lower = "damage", plural = "Damage" },
  run_score = { label = "Total Score", lower = "total score", plural = "Total Scores" },
  score = { label = "Score", lower = "score", plural = "scores" },
  multiplier = { label = "Multiplier", lower = "multiplier", plural = "multipliers" },
  active_coin_slot = { label = "Active Coin Slot", lower = "active coin slot", plural = "active coin slots" },
  collection = { label = "Collection", lower = "collection", plural = "collections" },
  run = { label = "Run", lower = "run", plural = "runs" },
  stage = { label = "Stage", lower = "stage", plural = "stages" },
  boss = { label = "Boss", lower = "boss", plural = "bosses" },
  shop = { label = "Shop", lower = "shop", plural = "shops" },
  meta_progression = { label = "Meta Progression", lower = "meta progression", plural = "Meta Progression" },
}

Terminology.outcomes = {
  match = "Match",
  miss = "Miss",
  all_matched = "Perfect Flip",
  every_coin_matches = "Perfect Flip",
  no_matches = "Total Miss",
  no_coins_match = "Total Miss",
  any_matched = "Any Match",
  perfect = "Perfect Flip",
}

Terminology.hooks = {
  on_batch_start = "Start of Flip",
  before_hand_flip = "Before Flip",
  before_coin_roll = "Before Coin Roll",
  after_coin_roll = "After Coin Roll",
  before_scoring = "Before Scoring",
  after_scoring = "After Scoring",
  before_stage_end_check = "Before Stage Check",
  on_batch_end = "End of Flip",
  after_hand_draw = "After Draw",
  before_sleight = "Before Sleight",
  after_sleight_return = "After Sleight Return",
  after_replacement_draw = "After Replacement Draw",
  after_hand_reorder = "After Reorder",
  before_shop_generation = "Before Shop",
  after_shop_generation = "After Shop",
  before_purchase = "Before Purchase",
  after_purchase = "After Purchase",
}

Terminology.tags = {
  all_match = "Perfect Flip",
  anti_streak = "Repeated Call Penalty",
  attunement = "Attunement",
  basic = "Basic",
  boss = "Boss",
  chain = "Combo",
  coin = "Coin",
  collection = "Collection",
  combo = "Combo",
  counter = "Counter",
  discount = "Discount",
  draw = "Draw",
  economy = "Economy",
  filler = "Basic",
  flip = "Flip",
  heads = "Heads",
  match = "Match",
  meta = "Meta",
  miss = "Miss",
  motion = "Motion",
  multiplier = "Multiplier",
  neighbor = "Neighbor",
  offer = "Offer",
  opening = "Opening",
  odds = "Odds",
  perfect = "Perfect Flip",
  quality = "Quality",
  regular = "Basic",
  reorder = "Reorder",
  safety = "Safety",
  score = "Score",
  shop = "Shop",
  sleight = "Sleight",
  slots = "Slots",
  stage = "Stage",
  starter = "Starter",
  strategy = "Strategy",
  streak = "Streak",
  tails = "Tails",
  temporary = "Temporary",
  threshold = "Threshold",
  unlock = "Unlock",
  weight = "Chance",
}

Terminology.mechanicTermCategories = {
  resources = {
    bold = true,
    terms = {
      "Active Coin Slot",
      "Free Rerolls",
      "Free Reroll",
      "Heads Chance",
      "Tails Chance",
      "Head Chance",
      "Tail Chance",
      "Damage",
      "Total Score",
      "Score Multiplier",
      "Multiplier",
      "Chips",
      "Chip",
    },
  },
  outcomes = {
    bold = true,
    terms = {
      "Perfect Flip",
      "Total Miss",
      "Any Match",
      "Matches",
      "Matched",
      "Match",
      "Misses",
      "Missed",
      "Miss",
    },
  },
  conditions = {
    bold = true,
    terms = {
      "Repeated Call",
      "Matching Call",
      "Heads Call",
      "Tails Call",
      "Boss Stages",
      "Boss Stage",
      "Threshold",
      "Streak",
      "Combo",
      "Heads",
      "Tails",
    },
  },
  timing = {
    bold = true,
    terms = {
      "Before Coin Roll",
      "After Coin Roll",
      "Before Scoring",
      "After Scoring",
      "Start of Flip",
      "End of Flip",
      "Before Flip",
      "After Draw",
    },
  },
  actions = {
    bold = true,
    terms = {
      "Replacement Coin",
      "Sleight",
      "Reorder",
      "Draw",
    },
  },
  subjects = {
    bold = false,
    terms = {
      "Active Coins",
      "Active Coin",
      "Coins",
      "Coin",
      "Calls",
      "Call",
      "Flips",
      "Flip",
      "Hand",
      "Pouch",
      "Stage",
      "Run",
      "Shop",
      "Score",
    },
  },
}

Terminology.mechanicBoldTerms = {}

for _, category in pairs(Terminology.mechanicTermCategories) do
  if category.bold then
    for _, term in ipairs(category.terms or {}) do
      table.insert(Terminology.mechanicBoldTerms, term)
    end
  end
end

table.sort(Terminology.mechanicBoldTerms, function(left, right)
  return #left > #right
end)

local function lowerTerm(key)
  return Terminology.terms[key].lower
end

local function pluralTerm(key)
  return Terminology.terms[key].plural
end

local function labelTerm(key)
  return Terminology.terms[key].label
end

Terminology.textReplacements = {
  { from = "every equipped coin matches this batch", to = "every coin matches this " .. lowerTerm("flip") },
  { from = "every equipped coin matches a batch", to = "every coin matches a " .. lowerTerm("flip") },
  { from = "every equipped coin matches", to = "every coin matches" },
  { from = "no equipped coin matches this batch", to = "no coins match this " .. lowerTerm("flip") },
  { from = "no equipped coin matches", to = "no coins match" },
  { from = "no coins match this batch", to = "no coins match this " .. lowerTerm("flip") },
  { from = "repeated-call batch", to = "repeated-call " .. lowerTerm("flip") },
  { from = "repeated call batch", to = "repeated call " .. lowerTerm("flip") },
  { from = "Heads call batch", to = "Heads call " .. lowerTerm("flip") },
  { from = "Tails call batch", to = "Tails call " .. lowerTerm("flip") },
  { from = "scored batch", to = "scoring " .. lowerTerm("flip") },
  { from = "missed batches", to = "missed " .. pluralTerm("flip") },
  { from = "each scored batch", to = "each scoring " .. lowerTerm("flip") },
  { from = "each batch", to = "each " .. lowerTerm("flip") },
  { from = "this batch", to = "this " .. lowerTerm("flip") },
  { from = "At batch start", to = "At " .. lowerTerm("flip") .. " start" },
  { from = "at batch end", to = "at " .. lowerTerm("flip") .. " end" },
  { from = "Before flipping the hand", to = "Before the " .. lowerTerm("flip") },
  { from = "before flipping the hand", to = "before the " .. lowerTerm("flip") },
  { from = "Before rolling", to = "Before the coin rolls" },
  { from = "before rolling", to = "before the coin rolls" },
  { from = "equipped coins", to = pluralTerm("active_coin") },
  { from = "equipped coin", to = lowerTerm("active_coin") },
  { from = "max active coin slot", to = labelTerm("active_coin_slot") },
  { from = "active coin slots", to = pluralTerm("active_coin_slot") },
  { from = "active coin slot", to = lowerTerm("active_coin_slot") },
  { from = "free shop reroll(s)", to = labelTerm("free_reroll") .. "(s)" },
  { from = "free shop rerolls", to = pluralTerm("free_reroll") },
  { from = "free shop reroll", to = labelTerm("free_reroll") },
  { from = "shop point(s)", to = labelTerm("chip") .. "(s)" },
  { from = "shop points", to = pluralTerm("chip") },
  { from = "shop point", to = lowerTerm("chip") },
  { from = "Heads chance", to = labelTerm("heads_weight") },
  { from = "Tails chance", to = labelTerm("tails_weight") },
  { from = "stage score", to = labelTerm("stage_score") },
  { from = "score multiplier", to = labelTerm("score") .. " " .. labelTerm("multiplier") },
  { from = "all-match", to = Terminology.outcomes.all_matched },
}

local function escapePattern(text)
  return (string.gsub(text, "([^%w])", "%%%1"))
end

local function escapeReplacement(text)
  return (string.gsub(text, "%%", "%%%%"))
end

function Terminology.formatText(text)
  if type(text) ~= "string" then
    return text
  end

  local formatted = text

  for _, replacement in ipairs(Terminology.textReplacements) do
    formatted = string.gsub(formatted, escapePattern(replacement.from), escapeReplacement(replacement.to))
  end

  return formatted
end

local function startsWithWord(text)
  return string.match(text:sub(1, 1), "%w") ~= nil
end

local function endsWithWord(text)
  return string.match(text:sub(-1), "%w") ~= nil
end

function Terminology.getMechanicRichText(text)
  local formatted = Terminology.formatText(text or "")
  local lowerFormatted = string.lower(formatted)
  local segments = {}
  local index = 1

  while index <= #formatted do
    local bestStart = nil
    local bestEnd = nil

    for _, term in ipairs(Terminology.mechanicBoldTerms) do
      local lowerMechanicTerm = string.lower(term)
      local pattern = escapePattern(lowerMechanicTerm)

      if startsWithWord(lowerMechanicTerm) then
        pattern = "%f[%w]" .. pattern
      end

      if endsWithWord(lowerMechanicTerm) then
        pattern = pattern .. "%f[^%w]"
      end

      local startIndex, endIndex = string.find(lowerFormatted, pattern, index)

      if startIndex and (not bestStart or startIndex < bestStart or (startIndex == bestStart and endIndex > bestEnd)) then
        bestStart = startIndex
        bestEnd = endIndex
      end
    end

    if not bestStart then
      table.insert(segments, { text = formatted:sub(index), bold = false })
      break
    end

    if bestStart > index then
      table.insert(segments, { text = formatted:sub(index, bestStart - 1), bold = false })
    end

    table.insert(segments, { text = formatted:sub(bestStart, bestEnd), bold = true })
    index = bestEnd + 1
  end

  return {
    richText = true,
    segments = segments,
  }
end

function Terminology.getTagLabel(tag)
  return Terminology.tags[tag] or tostring(tag)
end

function Terminology.formatTags(tags)
  local labels = {}

  for _, tag in ipairs(tags or {}) do
    table.insert(labels, Terminology.getTagLabel(tag))
  end

  return labels
end

function Terminology.formatTagList(tags)
  return table.concat(Terminology.formatTags(tags), ", ")
end

function Terminology.getHookLabel(hook)
  return Terminology.hooks[hook] or tostring(hook)
end

function Terminology.getOutcomeLabel(outcome)
  return Terminology.outcomes[outcome] or tostring(outcome)
end

function Terminology.getTermLabel(key)
  local term = Terminology.terms[key]
  return term and term.label or tostring(key)
end

function Terminology.getTermLower(key)
  local term = Terminology.terms[key]
  return term and term.lower or tostring(key)
end

function Terminology.getTermPlural(key)
  local term = Terminology.terms[key]
  return term and term.plural or tostring(key)
end

return Terminology
