local definitions = {
	{
		id = "weighted_tail_coating",
		name = "Tailside Edge",
		rarity = "uncommon",
    description = "Before each flip, all selected coins gain +15% Tails chance. Weighted Coins gain double the odds shift.",
		tags = { "weighted", "tails", "weight" },
		trick = {
			category = "weighted",
			tags = { "weighted", "weight", "tails" },
			tier = 1,
			timing = "before_flip",
			targetRule = "all_selected_coins",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "before_coin_roll",
				effects = {
					{ op = "add_weight", side = "tails", amount = 0.15, specializedFamily = "weighted" },
				},
			},
		},
	},
	{
		id = "merchant_notebook",
		name = "Street Ledger",
		rarity = "common",
		description = "After each scoring flip, gain +1 Influence.",
		tags = { "prestige", "payout", "influence" },
		trick = {
			category = "prestige",
			tags = { "prestige", "payout", "influence" },
			tier = 1,
			timing = "after_score",
			targetRule = "scoring_flip",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "after_scoring",
				effects = {
					{ op = "add_influence", amount = 1 },
				},
			},
		},
	},
	{
		id = "steady_hand",
		name = "Steady Finish",
		rarity = "common",
    description = "Before scoring, total Score is multiplied by 1.10x. Matching Bent Coins score double.",
		tags = { "prestige", "score_scaling" },
		trick = {
			category = "prestige",
			tags = { "prestige", "score_scaling" },
			tier = 1,
			timing = "before_score",
			targetRule = "aggregate_score",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "before_scoring",
				effects = {
					{ op = "apply_score_scaling", value = 1.10 },
				},
			},
			{
				hook = "before_coin_score",
				condition = { match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.0, target = "current_coin_score", specializedFamily = "prestige", requireSpecializedFamily = true },
				},
			},
		},
	},
	{
		id = "encore",
		name = "Encore",
		rarity = "common",
    description = "After all effects, replay one Bent Coin’s completed packet if possible, otherwise one selected coin’s packet, at 20% value. Bent Coins replay at double value.",
		tags = { "prestige", "resolution_packet", "prestige_replay", "encore" },
		trick = {
			category = "prestige",
			tags = { "prestige", "resolution_packet", "prestige_replay", "encore" },
			tier = 1,
			timing = "after_all_effects",
			targetRule = "selected_positive_packet_prefer_prestige_then_bent_random",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				packetReplayOnly = true,
				replayAt20Percent = true,
				noRecursivePrestige = true,
			},
		},
		triggers = {
			{
				hook = "after_all_effects",
				effects = {
					{
						op = "replay_resolution_packet",
						target = {
							zone = "resolution_packets",
							filters = {
								{ op = "selected" },
								{ op = "positive_score" },
								{ op = "not_prestige_replay" },
							},
							prefer = {
								{ op = "family", value = "prestige" },
								{ op = "archetype", value = "bent" },
							},
							orderBy = "random",
							pick = { op = "slot_at_position", value = 1 },
						},
						scale = 0.2,
						specializedFamily = "prestige",
					},
				},
			},
		},
	},
	{
		id = "roomy_bandolier",
		name = "Hidden Sleeve",
		rarity = "rare",
    description = "Gain +1 max Flip Slot for the run.",
		tags = { "smuggle", "slots" },
		trick = {
			category = "smuggle",
			tags = { "smuggle", "flip_slot" },
			tier = 1,
			timing = "on_acquire",
			targetRule = "run_flip_slots",
			scope = { oncePerRun = true },
		},
		onAcquire = {
			{ op = "increase_coin_slots", amount = 1 },
		},
	},
	{
		id = "sleeve_pocket",
		name = "Sleeve Pocket",
		rarity = "common",
    description = "After the call, smuggle one Hollow Coin if possible, otherwise one unselected dealt coin, into an overload slot for this flip. Hollow Coins score double.",
		tags = { "smuggle", "hand", "board_overload", "extra_coin" },
		trick = {
			category = "smuggle",
			tags = { "smuggle", "hand", "board_overload", "extra_coin" },
			tier = 1,
			timing = "after_call_before_flip",
			targetRule = "dealt_hand_unselected_prefer_smuggle_then_hollow_lowest_slot_position",
			scope = { oncePerFlip = true, maxOverloadSlots = 1 },
		},
		triggers = {
			{
				hook = "after_call_before_flip",
				condition = { slot_index = 1 },
				effects = {
					{
						op = "smuggle_coin_from_hand",
						target = {
							zone = "dealt_hand",
							filters = {
								{ op = "not_selected" },
								{ op = "not_smuggled" },
							},
							prefer = {
								{ op = "family", value = "smuggle" },
								{ op = "archetype", value = "hollow" },
							},
							orderBy = "slot_position",
							pick = { op = "slot_at_position", value = 1 },
						},
						maxOverloadSlots = 1,
						specializedFamily = "smuggle",
					},
				},
			},
			{
				hook = "before_coin_score",
				condition = { smuggled = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.0, target = "current_coin_score", specializedFamily = "smuggle", requireSpecializedFamily = true },
				},
			},
		},
	},
	{
		id = "starter_grant",
		name = "Opening Stake",
		rarity = "common",
    description = "Gain +2 Influence when acquired.",
		tags = { "fate", "payout", "influence" },
		trick = {
			category = "fate",
			tags = { "fate", "payout", "influence" },
			tier = 1,
			timing = "on_acquire",
			targetRule = "run_wallet",
			scope = { oncePerRun = true },
		},
		onAcquire = {
			{ op = "add_influence", amount = 2 },
		},
	},
	{
		id = "omen_engine",
		name = "Omen Engine",
		rarity = "common",
    description = "Once per flip, your first positive Luck gain adds +1 extra Luck Meter progress.",
		tags = { "fate", "luck_meter", "luck_gain", "accelerator" },
		trick = {
			category = "fate",
			tags = { "fate", "luck_meter", "luck_gain", "accelerator" },
			tier = 1,
			timing = "luck_gain",
			targetRule = "luck_meter",
			scope = { oncePerFlip = true, meterOnly = true },
		},
		triggers = {
			{
				hook = "luck_gain",
				condition = { luck_gain_positive = true },
				effects = {
					{ op = "add_luck", amount = 1, reason = "omen_engine" },
				},
			},
		},
	},
	{
		id = "heads_varnish",
		name = "Headside Edge",
		rarity = "common",
    description = "Before each flip, all selected coins gain +12% Heads chance. Weighted Coins gain double the odds shift.",
		tags = { "weighted", "heads", "weight" },
		trick = {
			category = "weighted",
			tags = { "weighted", "weight", "heads" },
			tier = 1,
			timing = "before_flip",
			targetRule = "all_selected_coins",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "before_coin_roll",
				effects = {
					{ op = "add_weight", side = "heads", amount = 0.12, specializedFamily = "weighted" },
				},
			},
		},
	},
	{
		id = "weighted_palm",
		name = "Weighted Palm",
		rarity = "common",
    description = "Before each flip, set one selected Weighted Coin, or the leftmost selected coin, to 75% call-match chance.",
		tags = { "weighted", "weight", "call_bias" },
		trick = {
			category = "weighted",
			tags = { "weighted", "weight", "call_bias" },
			tier = 1,
			timing = "before_flip",
			targetRule = "selected_coins_prefer_weighted_lowest_slot_position",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "before_coin_roll",
				condition = { slot_index = 1 },
				effects = {
					{
						op = "set_call_match_chance",
						chance = 0.75,
						target = {
							zone = "selected_coins",
							prefer = {
								{ op = "family", value = "weighted" },
							},
							orderBy = "slot_position",
							pick = { op = "slot_at_position", value = 1 },
						},
					},
				},
			},
		},
	},
	{
		id = "see_behind_the_veil",
		name = "See Behind the Veil",
		rarity = "common",
    description = "After each deal, Foretell one Marked Coin if possible, otherwise one random dealt coin, before selection.",
		tags = { "prediction", "marked", "foretold", "read", "auto" },
		trick = {
			category = "prediction",
			tags = { "prediction", "marked", "foretold", "read", "auto" },
			tier = 1,
			timing = "after_deal_before_selection",
			targetRule = "dealt_hand_not_foretold_prefer_prediction_random_slot_position",
			scope = { oncePerDeal = true },
		},
		triggers = {
			{
				hook = "after_deal_before_selection",
				condition = { slot_index = 1 },
				effects = {
					{
						op = "foretell_coin_result",
						target = {
							zone = "dealt_hand",
							filters = {
								{ op = "not_foretold" },
							},
							prefer = {
								{ op = "family", value = "prediction" },
							},
							orderBy = "random",
							pick = { op = "slot_at_position", value = 1 },
						},
						specializedFamily = "prediction",
					},
				},
			},
		},
	},
	{
		id = "borrowed_name",
		name = "Borrowed Name",
		rarity = "common",
    description = "Before scoring, one failed Blank Coin if possible, otherwise one failed selected coin, borrows the slot 1 coin’s identity for one payout check. Forged Blank Coins score double.",
		tags = { "counterfeit", "identity", "slot_1", "replace_identity" },
		trick = {
			category = "forgery",
			tags = { "counterfeit", "identity", "slot_1", "replace_identity" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "selected_slot_1_to_failed_selected_prefer_forgery_lowest_base_score",
			scope = { oncePerFlip = true, onePayoutOnly = true },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { slot_index = 1 },
				effects = {
					{
						op = "forge_identity",
						target = {
							source = {
								zone = "selected_coins",
								filters = {
									{ op = "slot_index", value = 1 },
								},
								pick = { op = "slot_at_position", value = 1 },
							},
							target = {
								zone = "selected_coins",
								filters = {
									{ op = "failed_call" },
									{ op = "not_current_coin" },
								},
								prefer = {
									{ op = "family", value = "forgery" },
								},
								orderBy = "base_score",
								pick = { op = "slot_at_position", value = 1 },
							},
						},
						specializedFamily = "forgery",
					},
				},
			},
			{
				hook = "before_coin_score",
				condition = { forged = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.0, target = "current_coin_score", specializedFamily = "forgery", requireSpecializedFamily = true },
				},
			},
		},
	},
	{
		id = "crooked_spotlight",
		name = "Crooked Spotlight",
		rarity = "common",
    description = "Before scoring, one low-value successful coin gives its score credit to the highest-value successful coin.",
		tags = { "misdirection", "spotlight", "score_credit", "score_funnel" },
		trick = {
			category = "misdirection",
			tags = { "misdirection", "spotlight", "score_credit", "score_funnel" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "lowest_base_score_success_to_highest_base_score_spotlight",
			scope = { oncePerFlip = true, oneRedirectOnly = true, noRedirectedRetrigger = true },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { slot_index = 1 },
				effects = {
					{
						op = "redirect_score_credit",
						target = {
							target = {
								zone = "selected_coins",
								filters = {
									{ op = "matched_call" },
								},
								orderBy = "base_score_desc",
								pick = { op = "slot_at_position", value = 1 },
							},
							source = {
								zone = "selected_coins",
								filters = {
									{ op = "matched_call" },
									{ op = "not_context_instance" },
									{ op = "not_redirected_credit" },
								},
								orderBy = "base_score",
								pick = { op = "slot_at_position", value = 1 },
							},
						},
					},
				},
			},
		},
	},
	{
		id = "switcheroo",
		name = "Switcheroo",
		rarity = "common",
    description = "After each flip, swap one failed coin with one successful result slot before scoring.",
		tags = { "sleight", "position", "swap", "slot" },
		trick = {
			category = "sleight",
			tags = { "sleight", "position", "swap", "slot" },
			tier = 1,
			timing = "after_flip_before_score",
			targetRule = "highest_base_score_failed_coin_lowest_base_score_success_slot",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "after_flip_before_score",
				effects = {
					{
						op = "swap_coins",
						target = {
							source = {
								zone = "selected_coins",
								filters = {
									{ op = "failed_call" },
								},
								orderBy = "base_score_desc",
								pick = { op = "slot_at_position", value = 1 },
							},
							target = {
								zone = "selected_coins",
								filters = {
									{ op = "matched_call" },
									{ op = "not_context_instance" },
								},
								orderBy = "base_score",
								pick = { op = "slot_at_position", value = 1 },
							},
						},
					},
				},
			},
		},
	},
	{
		id = "coupon_case",
		name = "House Voucher",
		rarity = "common",
		shopEligible = true,
    description = "Gain 1 Free Reroll for the rest of the run when acquired.",
		tags = { "fate", "reroll", "black_market" },
		trick = {
			category = "fate",
			tags = { "fate", "reroll", "black_market" },
			tier = 1,
			timing = "on_acquire",
			targetRule = "run_rerolls",
			scope = { oncePerRun = true },
		},
		onAcquire = {
			{ op = "add_shop_rerolls", amount = 1 },
		},
	},
	{
		id = "showcase_rack",
		name = "Backroom Display",
		rarity = "uncommon",
		unlockedByDefault = false,
		rewardEligible = false,
		shopEligible = true,
		description = "Trick offers cost 1 less in future Black Markets.",
		tags = { "misdirection", "black_market", "discount" },
		trick = {
			category = "misdirection",
			tags = { "misdirection", "black_market", "discount" },
			tier = 1,
			timing = "after_shop_generation",
			targetRule = "each_trick_offer",
			scope = { maxTriggersPerOffer = 1 },
		},
		triggers = {
			{
				hook = "after_shop_generation",
				condition = { offer_type = "trick" },
				effects = {
					{ op = "adjust_shop_price", delta = -1 },
				},
			},
		},
	},
	{
		id = "cashback_badge",
		name = "Kickback Mark",
		rarity = "common",
		unlockedByDefault = false,
		rewardEligible = false,
		shopEligible = true,
    description = "Buying a Trick refunds 1 Influence in future Black Markets.",
		tags = { "misdirection", "black_market", "influence" },
		trick = {
			category = "misdirection",
			tags = { "misdirection", "black_market", "influence" },
			tier = 1,
			timing = "after_purchase",
			targetRule = "trick_purchase",
			scope = { maxTriggersPerPurchase = 1 },
		},
		triggers = {
			{
				hook = "after_purchase",
				condition = { purchase_type = "trick" },
				effects = {
					{ op = "add_influence", amount = 1 },
					{ op = "add_shop_message", message = "Kickback Mark refunded 1 Influence." },
				},
			},
		},
	},
	{
		id = "domino_line",
		name = "Domino Line",
		rarity = "common",
    description = "After a scoring coin, there is a 50% chance to trigger a neighbouring Bent Coin if possible, otherwise a random neighbouring coin, in a capped Chain. Chained Bent Coins score double.",
		tags = { "chain", "chained", "random_neighbor", "propagation" },
		trick = {
			category = "chain",
			tags = { "chain", "chained", "random_neighbor", "propagation" },
			tier = 1,
			timing = "after_coin_score",
			targetRule = "unused_neighbor_prefer_chain_random",
			scope = { oncePerFlip = true, chainChance = 0.5, maxChainDepth = 2, maxTriggers = 2, noChainReentry = true },
		},
		triggers = {
			{
				hook = "after_coin_score",
				condition = { match = true },
				effects = {
					{
						op = "trigger_random_neighbor",
						target = {
							zone = "selected_coins",
							filters = {
								{ op = "neighbor_of_current" },
								{ op = "not_used_resolution_index" },
							},
							prefer = {
								{ op = "family", value = "chain" },
							},
							orderBy = "random",
							pick = { op = "slot_at_position", value = 1 },
						},
						chainChance = 0.5,
						maxChainDepth = 2,
						maxTriggers = 2,
						specializedFamily = "chain",
					},
				},
			},
			{
				hook = "before_coin_score",
				condition = { chained = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.0, target = "current_coin_score", specializedFamily = "chain", requireSpecializedFamily = true },
				},
			},
		},
	},
	{
		id = "echo_cache",
		name = "Echo Wager",
		rarity = "uncommon",
		unlockedByDefault = false,
    description = "At flip start, create a temporary echo. If every coin matches this flip, gain +1 Influence.",
		tags = { "chain", "temporary", "black_market", "all_match" },
		trick = {
			category = "chain",
			tags = { "chain", "all_match", "temporary", "influence" },
			tier = 1,
			timing = "before_flip",
			targetRule = "all_selected_coins",
			scope = { maxTemporaryEffectsPerFlip = 1 },
		},
		triggers = {
			{
				hook = "on_batch_start",
				effects = {
					{
						op = "grant_temporary_effect",
						effect = {
							id = "echo_cache_echo",
							name = "Echo Wager Echo",
              description = "This flip only, if every coin matches, gain +1 Influence.",
							triggers = {
								{
									hook = "after_scoring",
									condition = { all_matched = true },
									effects = {
										{ op = "add_influence", amount = 1 },
										{ op = "queue_trace_note", note = "Echo Wager paid out." },
									},
								},
								{
									hook = "on_batch_end",
									effects = {
										{ op = "consume_effect" },
									},
								},
							},
						},
					},
				},
			},
		},
	},
	{
		id = "tails_contract",
		name = "Tails Pact",
		rarity = "common",
    description = "Tails calls multiply Score by 1.15x.",
		tags = { "prediction", "tails", "score_scaling" },
		trick = {
			category = "prediction",
			tags = { "prediction", "tails", "score_scaling" },
			tier = 1,
			timing = "before_score",
			targetRule = "tails_call",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "before_scoring",
				condition = { call = "tails" },
				effects = {
					{ op = "apply_score_scaling", value = 1.15 },
				},
			},
		},
	},
	{
		id = "heads_notebook",
		name = "Heads Ledger",
		rarity = "common",
    description = "After scoring a Heads call, gain +1 Influence.",
		tags = { "prediction", "heads", "payout", "influence" },
		trick = {
			category = "prediction",
			tags = { "prediction", "heads", "payout", "influence" },
			tier = 1,
			timing = "after_score",
			targetRule = "heads_call",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "after_scoring",
				condition = { call = "heads" },
				effects = {
					{ op = "add_influence", amount = 1 },
				},
			},
		},
	},
	{
		id = "heads_contract",
		name = "Heads Pact",
		rarity = "common",
    description = "Heads calls multiply Score by 1.15x.",
		tags = { "prediction", "heads", "score_scaling" },
		trick = {
			category = "prediction",
			tags = { "prediction", "heads", "score_scaling" },
			tier = 1,
			timing = "before_score",
			targetRule = "heads_call",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "before_scoring",
				condition = { call = "heads" },
				effects = {
					{ op = "apply_score_scaling", value = 1.15 },
				},
			},
		},
	},
	{
		id = "fulfilled_fate",
		name = "Fulfilled Fate",
		rarity = "common",
    description = "The first selected Foretold coin that matches your call scores 2x. Marked Coins double this bonus.",
		tags = { "prediction", "marked", "foretold", "fulfillment", "score_scaling" },
		trick = {
			category = "prediction",
			tags = { "prediction", "marked", "foretold", "fulfillment", "score_scaling" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "selected_foretold_matching_coin",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { foretold = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 2.0, target = "current_coin_score", specializedFamily = "prediction" },
				},
			},
		},
	},
	{
		id = "insurance_ledger",
		name = "Insurance Slip",
		rarity = "common",
		description = "If no coins match this flip, gain +2 Influence.",
		tags = { "fate", "payout", "influence", "safety" },
		trick = {
			category = "fate",
			tags = { "fate", "safety", "payout", "influence" },
			tier = 1,
			timing = "after_flip",
			targetRule = "no_success_flip",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "on_batch_end",
				condition = { no_matches = true },
				effects = {
					{ op = "add_influence", amount = 2 },
				},
			},
		},
	},
	{
		id = "rainy_day_fund",
		name = "Rainy Day Voucher",
		rarity = "uncommon",
		unlockedByDefault = false,
		description = "If no coins match this flip, gain +1 Free Reroll.",
		tags = { "fate", "reroll", "safety", "black_market" },
		trick = {
			category = "fate",
			tags = { "fate", "safety", "reroll" },
			tier = 1,
			timing = "after_flip",
			targetRule = "no_success_flip",
			scope = { maxTriggersPerFlip = 1 },
		},
		triggers = {
			{
				hook = "on_batch_end",
				condition = { no_matches = true },
				effects = {
					{ op = "add_shop_rerolls", amount = 1 },
				},
			},
		},
	},
	{
		id = "recovery_coupon",
		name = "Recovery Voucher",
		rarity = "uncommon",
		unlockedByDefault = false,
		rewardEligible = false,
		shopEligible = true,
    description = "Buying a Coin grants 1 Free Reroll.",
		tags = { "misdirection", "black_market", "reroll", "coin" },
		trick = {
			category = "misdirection",
			tags = { "misdirection", "black_market", "reroll" },
			tier = 1,
			timing = "after_purchase",
			targetRule = "coin_purchase",
			scope = { maxTriggersPerPurchase = 1 },
		},
		triggers = {
			{
				hook = "after_purchase",
				condition = { purchase_type = "coin" },
				effects = {
					{ op = "add_shop_rerolls", amount = 1 },
					{ op = "add_shop_message", message = "Recovery Voucher granted a free reroll." },
				},
			},
		},
	},
}

local byId = {}

for _, definition in ipairs(definitions) do
	byId[definition.id] = definition
end

local Upgrades = {}

local function buildUnlockedIndex(unlockedUpgradeIds)
	local unlockedIndex = {}

	if type(unlockedUpgradeIds) ~= "table" then
		return unlockedIndex
	end

	for key, value in pairs(unlockedUpgradeIds) do
		if type(key) == "string" and value == true then
			unlockedIndex[key] = true
		elseif type(value) == "string" and value ~= "" then
			unlockedIndex[value] = true
		end
	end

	return unlockedIndex
end

function Upgrades.getAll()
	return definitions
end

function Upgrades.getById(id)
	return byId[id]
end

function Upgrades.isUnlocked(definition, unlockedUpgradeIds)
	if not definition then
		return false
	end

	if definition.unlockedByDefault ~= false then
		return true
	end

	local unlockedIndex = buildUnlockedIndex(unlockedUpgradeIds)
	return unlockedIndex[definition.id] == true
end

function Upgrades.getUnlockedIds(unlockedUpgradeIds)
	local unlockedIds = {}
	local unlockedIndex = buildUnlockedIndex(unlockedUpgradeIds)

	for _, definition in ipairs(definitions) do
		if definition.unlockedByDefault ~= false or unlockedIndex[definition.id] then
			table.insert(unlockedIds, definition.id)
		end
	end

	return unlockedIds
end

function Upgrades.getDefaultUnlockedIds()
	return Upgrades.getUnlockedIds({})
end

return Upgrades
