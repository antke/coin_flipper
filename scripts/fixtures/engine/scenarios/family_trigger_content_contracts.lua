local Coins = require("src.content.coins")
local Upgrades = require("src.content.upgrades")

return {
  id = "family_trigger_content_contracts",
  tags = { "family_trigger", "content", "architecture" },
  description = "Guards explicit coin families and the converted/held/removed Trick catalogue.",
  steps = {},
  assert = function(_, A)
    for _, coin in ipairs(Coins.getAll()) do
      A.truthy(type(coin.activationFamily) == "string" and coin.activationFamily ~= "",
        string.format("%s should expose activationFamily", coin.id))
    end

    local converted = 0
    local held = 0
    local removed = 0
    for _, trick in ipairs(Upgrades.getAll()) do
      local status = trick.familyTriggerStatus
      if status == "converted" then
        converted = converted + 1
        A.truthy(type(trick.trick.activationFamily) == "string" and trick.trick.activationFamily ~= "",
          string.format("%s should expose activationFamily", trick.id))
        A.truthy(trick.trick.scope.oncePerActivation == true,
          string.format("%s should be scoped per activation", trick.id))
        local description = string.lower(trick.description or "")
        for _, obsolete in ipairs({
          "preferring ",
          "double for ",
          "first selected ",
          "random selected ",
          "if possible, otherwise",
          " by material",
        }) do
          A.falsy(string.find(description, obsolete, 1, true),
            string.format("%s should not use obsolete targeting text '%s'", trick.id, obsolete))
        end
      elseif status == "held" then
        held = held + 1
        A.equal(trick.rewardEligible, false, string.format("%s should be held from rewards", trick.id))
      elseif status == "removed" then
        removed = removed + 1
        A.equal(trick.rewardEligible, false, string.format("%s should be removed from rewards", trick.id))
      end
    end

    A.truthy(converted >= 20, "expected a substantial converted Trick set")
    A.truthy(held >= 1, "expected held Trick content")
    A.truthy(removed >= 20, "expected Extortion/deprecated Trick removals")
  end,
}
