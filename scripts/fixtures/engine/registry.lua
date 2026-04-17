local batchQueueEffectStageClear = require("scripts.fixtures.engine.scenarios.batch_queue_effect_stage_clear")
local shopPurchaseBoundary = require("scripts.fixtures.engine.scenarios.shop_purchase_boundary")
local unorderedSlotIdentityReplay = require("scripts.fixtures.engine.scenarios.unordered_slot_identity_replay")
local bootstrapAndShopRules = require("scripts.fixtures.engine.scenarios.bootstrap_and_shop_rules")

return {
  batchQueueEffectStageClear,
  shopPurchaseBoundary,
  unorderedSlotIdentityReplay,
  bootstrapAndShopRules,
}
