local ShopContent = require("src.content.shop")
local Upgrades = require("src.content.upgrades")

return {
  id = "bootstrap_and_shop_rules",
  tags = { "bootstrap", "shop", "effective_values", "replay" },
  description = "Verifies bootstrap effective values and deterministic shop generation rules.",

  setup = function()
    return {
      metaStateOptions = {
        effectiveValues = {
          ["run.maxActiveCoinSlots"] = { mode = "add", value = 1 },
          ["run.startingShopPoints"] = { mode = "add", value = 2 },
          ["run.startingShopRerolls"] = { mode = "add", value = 1 },
        },
      },
      runOptions = {
        seed = 10,
        ownedUpgradeIds = { "contraband_case", "showcase_rack" },
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "force_stage_clear" },
    { op = "finalize_stage" },
    { op = "create_shop_visit" },
    { op = "ensure_shop_offers" },
  },

  assert = function(env, A)
    local offers = A.truthy(env.shopFlow and env.shopFlow.offers, "shop offers missing")
    A.equal(env.runState.maxActiveCoinSlots, 4, "max active coin slots")
    A.equal(env.runState.shopPoints, 2, "starting shop points")
    A.equal(env.runState.shopRerollsRemaining, 1, "starting shop rerolls")
    A.equal(#offers, 4, "shop offer count with contraband case")

    local bonusOffer = A.contains(offers, function(offer)
      return offer.contentId == "boss_biter"
    end, "bonus boss biter offer expected")
    A.truthy(bonusOffer.injectedBy ~= nil, "bonus offer should preserve injectedBy")

    for _, offer in ipairs(offers) do
      if offer.type == "upgrade" then
        local definition = Upgrades.getById(offer.contentId)
        local expectedPrice = ShopContent.resolvePrice("upgrade", definition) - 1
        A.equal(offer.price, expectedPrice, string.format("discounted price for %s", tostring(offer.contentId)))
      end
    end

    A.notContains(offers, { contentId = "contraband_case" }, "owned contraband case should not be re-offered")
    A.notContains(offers, { contentId = "showcase_rack" }, "owned showcase rack should not be re-offered")
    A.contains(env.shopFlow.lastGenerationTrace.messages or {}, function(message)
      return tostring(message):find("Contraband Case smuggled in a bonus coin offer.", 1, true) ~= nil
    end, "contraband message should be present")
    A.equal(#(env.shopSession.offerSets or {}), 1, "shop offer set history count")
    A.equal(#(env.shopSession.generationTraces or {}), 1, "shop generation trace count")
  end,
}
