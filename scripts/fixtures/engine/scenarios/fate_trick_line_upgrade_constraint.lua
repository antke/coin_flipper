local AcquisitionSystem = require("src.systems.acquisition_system")

return {
  id = "fate_trick_line_upgrade_constraint",
  tags = { "fate", "shop" },
  description = "Verifies same-line Trick tiers replace weaker tiers and reject downgrades.",

  setup = function()
    return {
      runOptions = {
        seed = 1,
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
        { type = "trick", contentId = "twist_of_fate", price = 1 },
        { type = "trick", contentId = "twist_of_fate_ii", price = 1 },
        { type = "trick", contentId = "twist_of_fate_iii", price = 1 },
      },
    },
    { op = "purchase", offerType = "trick", contentId = "twist_of_fate", label = "buy_twist_i" },
    { op = "purchase", offerType = "trick", contentId = "twist_of_fate_ii", label = "buy_twist_ii" },
    { op = "purchase", offerType = "trick", contentId = "twist_of_fate_iii", label = "buy_twist_iii" },
  },

  assert = function(env, A)
    local buyTwistI = A.truthy(A.getResult("buy_twist_i"), "missing Twist I purchase")
    local buyTwistII = A.truthy(A.getResult("buy_twist_ii"), "missing Twist II purchase")
    local buyTwistIII = A.truthy(A.getResult("buy_twist_iii"), "missing Twist III purchase")

    A.truthy(buyTwistI.ok, "Twist I should purchase")
    A.truthy(buyTwistII.ok, "Twist II should purchase as an upgrade")
    A.truthy(buyTwistIII.ok, "Twist III should purchase as an upgrade")
    A.equal(env.runState.ownedTrickIds, { "twist_of_fate_iii" }, "only highest purchased Twist tier should remain owned")
    A.contains(buyTwistII.result.trace.actions, {
      op = "grant_trick",
      trickId = "twist_of_fate_ii",
      trickLineId = "twist_of_fate",
      replacedTrickIds = { "twist_of_fate" },
    }, "Twist II grant should replace Twist I")
    A.contains(buyTwistIII.result.trace.actions, {
      op = "grant_trick",
      trickId = "twist_of_fate_iii",
      trickLineId = "twist_of_fate",
      replacedTrickIds = { "twist_of_fate_ii" },
    }, "Twist III grant should replace Twist II")

    local downgradeOk, downgradeReason = AcquisitionSystem.canGrantUpgrade(env.runState, "twist_of_fate_ii")
    A.falsy(downgradeOk, "lower Twist tier should not be grantable after owning Twist III")
    A.equal(downgradeReason, "trick_line_tier_not_higher", "lower Twist tier rejection reason")

    local duplicateOk, duplicateReason = AcquisitionSystem.canGrantUpgrade(env.runState, "twist_of_fate_iii")
    A.falsy(duplicateOk, "duplicate Twist III should not be grantable")
    A.equal(duplicateReason, "upgrade_already_owned", "duplicate Twist tier rejection reason")
  end,
}
