-- The family-trigger migration intentionally retires fixtures that assert the
-- superseded global-passive, Fate-Trick, Extortion, or fresh-hand rules. Their
-- files remain as historical specifications; this registry contains the live
-- engine contract.
return {
  require("scripts.fixtures.engine.scenarios.black_market_coin_biased_offers"),
  require("scripts.fixtures.engine.scenarios.bootstrap_and_shop_rules"),
  require("scripts.fixtures.engine.scenarios.deal_select_refill_round_flow"),
  require("scripts.fixtures.engine.scenarios.enemy_class_trick_reward_pool"),
  require("scripts.fixtures.engine.scenarios.family_trigger_content_contracts"),
  require("scripts.fixtures.engine.scenarios.forgery_fake_credentials_outcome"),
  require("scripts.fixtures.engine.scenarios.forgery_hybrid_activations"),
  require("scripts.fixtures.engine.scenarios.mechanics_architecture_contracts"),
  require("scripts.fixtures.engine.scenarios.per_coin_score_events"),
  require("scripts.fixtures.engine.scenarios.prepared_build_bootstrap"),
  require("scripts.fixtures.engine.scenarios.seeded_content_distribution"),
  require("scripts.fixtures.engine.scenarios.simulation_policy_contracts"),
  require("scripts.fixtures.engine.scenarios.sleight_of_hand_value_actions"),
  require("scripts.fixtures.engine.scenarios.smuggling_quality_and_extraction"),
  require("scripts.fixtures.engine.scenarios.unordered_slot_identity_replay"),
}
