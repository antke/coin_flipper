local Coins = require("src.content.coins")
return {
  id = "black_market_coin_biased_offers",
  tags = { "shop", "black_market", "influence" },
  description = "Verifies Black Market offers Coins only; Charms come from Spoils instead.",

  setup = function()
    return {
      runOptions = {
        seed = 3,
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
    local offers = A.truthy(env.shopFlow and env.shopFlow.offers, "Black Market offers missing")
    local coinCount = 0

    A.equal(#offers, 3, "Black Market offer count")

    for _, offer in ipairs(offers) do
      if offer.type == "coin" then
        coinCount = coinCount + 1
        A.truthy(Coins.getById(offer.contentId), string.format("active coin offer %s", tostring(offer.contentId)))
      else
        error(string.format("unexpected Black Market offer type %s", tostring(offer.type)), 0)
      end
    end

    A.equal(coinCount, #offers, "Black Market should only offer Coins")
  end,
}
