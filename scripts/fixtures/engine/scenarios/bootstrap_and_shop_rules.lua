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
          ["run.maxFlipSlots"] = { mode = "add", value = 1 },
          ["run.startingInfluence"] = { mode = "add", value = 2 },
          ["run.startingShopRerolls"] = { mode = "add", value = 1 },
        },
      },
      runOptions = {
        seed = 10,
        ownedTrickIds = { "encore", "weighted_palm" },
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
    A.equal(env.runState.maxFlipSlots, 4, "max Flip Slots")
    A.equal(env.runState.influence, 2 + (env.stageRecord.stageClearShopPoints or 0), "starting Influence plus clear reward")
    A.equal(env.runState.shopRerollsRemaining, 1, "starting Black Market rerolls")
    A.equal(#offers, 3, "shop offer count")

    for _, offer in ipairs(offers) do
      if offer.type == "trick" then
        local definition = Upgrades.getById(offer.contentId)
        local expectedPrice = ShopContent.resolvePrice("trick", definition)
        A.equal(offer.price, expectedPrice, string.format("price for %s", tostring(offer.contentId)))
      end
    end

    A.notContains(offers, { contentId = "encore" }, "owned Encore should not be re-offered")
    A.notContains(offers, { contentId = "weighted_palm" }, "owned Weighted Palm should not be re-offered")
    A.equal(#(env.shopSession.offerSets or {}), 1, "shop offer set history count")
    A.equal(#(env.shopSession.generationTraces or {}), 1, "shop generation trace count")
  end,
}
