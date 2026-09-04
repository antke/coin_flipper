return {
  id = "extortion_black_market_crumbles",
  tags = { "extortion", "shop" },
  description = "Verifies Black Market Extortion effects mark/extort Coin offers, grant rerolls, discount rerolls, and Crumble.",

  setup = function()
    return {
      runOptions = {
        seed = 7,
        ownedTrickIds = {
          "five_finger_discount",
          "loaded_shelves",
          "pressure_sale",
          "no_questions_asked",
        },
      },
    }
  end,

  steps = {
    { op = "init_run" },
    { op = "create_stage" },
    { op = "commit_loadout" },
    { op = "force_stage_clear" },
    { op = "finalize_stage" },
    { op = "set_shop_points", value = 20 },
    { op = "create_shop_visit" },
    { op = "ensure_shop_offers", label = "initial_offers" },
    { op = "purchase_extorted_coin", label = "extorted_purchase" },
    { op = "reroll", label = "pressure_reroll" },
  },

  assert = function(env, A)
    local initialOffers = A.truthy(A.getResult("initial_offers"), "initial Black Market offers missing")
    local purchase = A.truthy(A.getResult("extorted_purchase"), "extorted purchase result missing")
    local firstTrace = A.truthy((env.shopSession.generationTraces or {})[1], "initial generation trace missing")
    local rerollTrace = A.truthy((env.shopSession.generationTraces or {})[2], "reroll generation trace missing")
    local extortedOffer = nil

    A.equal(#initialOffers, 3, "Black Market should show three Coin offers")

    for _, offer in ipairs(initialOffers) do
      A.equal(offer.type, "coin", "Black Market should only offer Coins")

      if offer.extorted then
        extortedOffer = offer
      end
    end

    A.truthy(extortedOffer, "Five-Finger Discount should extort one Coin")
    A.equal(extortedOffer.price, 0, "extorted Coin should have no Influence cost")
    A.truthy((extortedOffer.priceBeforeExtortion or 0) > 0, "extorted Coin should record original price")
    A.equal(extortedOffer.extortionSourceId, "five_finger_discount", "extorted Coin source")

    A.contains(firstTrace.extortionEffects or {}, { effect = "guarantee_uncommon_coin", sourceId = "loaded_shelves", natural = true }, "Loaded Shelves should recognize natural Silver or Gold stock")
    A.contains(firstTrace.extortionEffects or {}, { effect = "extort_cheapest_coin", sourceId = "five_finger_discount" }, "Five-Finger trace missing")
    A.notContains(env.runState.ownedTrickIds or {}, "loaded_shelves", "Loaded Shelves should Crumble after guaranteeing quality stock")
    A.notContains(env.runState.ownedTrickIds or {}, "five_finger_discount", "Five-Finger Discount should Crumble after visit")

    A.truthy(purchase.ok, "extorted Coin purchase should succeed")
    A.equal(purchase.result.finalPrice, 0, "extorted Coin final price")
    A.contains(purchase.result.trace.extortionEffects or {}, { effect = "extorted_coin_reroll", sourceId = "no_questions_asked" }, "No Questions Asked trace missing")
    A.notContains(env.runState.ownedTrickIds or {}, "no_questions_asked", "No Questions Asked should Crumble after extorted Coin")

    A.contains(rerollTrace.extortionEffects or {}, { effect = "pressure_reroll_discount", sourceId = "pressure_sale", discount = 1 }, "Pressure Sale trace missing")
    for _, offer in ipairs(env.shopFlow.offers or {}) do
      A.equal(offer.type, "coin", "rerolled Black Market should only offer Coins")
      A.equal(offer.pressureSaleDiscount, 1, "Pressure Sale should discount each rerolled Coin")
      A.equal(offer.pressureSaleSourceId, "pressure_sale", "Pressure Sale source")
    end
    A.notContains(env.runState.ownedTrickIds or {}, "pressure_sale", "Pressure Sale should Crumble after reroll")
    A.equal(env.runState.shopRerollsRemaining or 0, 0, "free reroll should be spent by the reroll")
  end,
}
