return {
  id = "shop_purchase_boundary",
  tags = { "shop", "purchase", "boundary" },
  description = "Ensures purchases do not affect the same transaction but do affect later purchases in the same visit.",

  setup = function()
    return {
      metaStateOptions = {
        unlockedUpgradeIds = { "cashback_badge" },
      },
      runOptions = {
        seed = 12,
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
    {
      op = "create_shop_visit",
      reason = "fixture_injected",
      offers = {
        { type = "upgrade", contentId = "cashback_badge", price = 4 },
        { type = "upgrade", contentId = "steady_hand", price = 4 },
      },
      generationTrace = {
        mode = "fixture_injected",
        triggeredSources = {},
        actions = {},
        warnings = {},
        messages = { "Fixture injected deterministic upgrade offers." },
        notes = {},
        offerCount = 2,
      },
    },
    { op = "purchase", offerType = "upgrade", contentId = "cashback_badge", label = "buy_cashback" },
    { op = "purchase", offerType = "upgrade", contentId = "steady_hand", label = "buy_steady" },
  },

  assert = function(env, A)
    local firstPurchase = A.truthy(A.getResult("buy_cashback"), "missing first purchase result")
    local secondPurchase = A.truthy(A.getResult("buy_steady"), "missing second purchase result")

    A.truthy(firstPurchase.ok, "cashback badge should purchase successfully")
    A.truthy(secondPurchase.ok, "steady hand should purchase successfully")
    A.equal(firstPurchase.result.finalPrice, 4, "cashback badge final price")
    A.equal(secondPurchase.result.finalPrice, 4, "steady hand final price")
    A.equal(env.runState.shopPoints, 13, "shop points after cashback sequence")
    A.notContains(firstPurchase.result.trace.messages or {}, function(message)
      return tostring(message):find("Cashback Badge refunded 1 shop point.", 1, true) ~= nil
    end, "cashback badge should not refund its own purchase")
    A.contains(secondPurchase.result.trace.messages or {}, function(message)
      return tostring(message):find("Cashback Badge refunded 1 shop point.", 1, true) ~= nil
    end, "steady hand purchase should receive cashback refund")
    A.equal(#(env.runState.history.purchases or {}), 2, "global purchase history count")
    A.equal(#(env.shopSession.actions or {}), 2, "shop session action count")
  end,
}
