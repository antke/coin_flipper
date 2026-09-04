local definitions = {
	{
		id = "weighted_tail_coating",
		name = "Tailside Edge",
		rarity = "uncommon",
		description = "On Tails Flip, a random selected Weighted Coin gets +30% Tails Chance.",
		tags = { "weighted", "tails", "weight" },
		trick = {
			category = "weighted",
			tags = { "weighted", "weight", "tails" },
			tier = 1,
			timing = "before_flip",
			targetRule = "random_selected_weighted_coin_on_tails_flip",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "before_coin_roll",
				condition = { call = "tails", slot_index = 1 },
				effects = {
					{
						op = "add_weight",
						side = "tails",
						amount = 0.30,
						target = {
							zone = "selected_coins",
							filters = {
								{ op = "family", value = "weighted" },
							},
							orderBy = "random",
							pick = { op = "slot_at_position", value = 1 },
						},
					},
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
		description = "After all effects, replay one completed coin Outcome at 20% value, preferring Bent Coins. Bent Coins replay at double value.",
		tags = { "prestige", "outcome", "prestige_replay", "encore" },
		trick = {
			category = "prestige",
			tags = { "prestige", "outcome", "prestige_replay", "encore" },
			tier = 1,
			timing = "after_all_effects",
			targetRule = "positive_outcome_prefer_prestige_then_bent_random",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				outcomeReplayOnly = true,
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
		id = "curtain_call",
		name = "Curtain Call",
		rarity = "common",
		description = "After all effects, replay one random completed coin Outcome at 20% value, preferring Bent Coins.",
		tags = { "prestige", "outcome", "prestige_replay", "curtain_call" },
		trick = {
			category = "prestige",
			lineId = "curtain_call",
			tags = { "prestige", "outcome", "prestige_replay", "curtain_call" },
			tier = 1,
			timing = "after_all_effects",
			targetRule = "random_positive_outcome_prefer_bent",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				outcomeReplayOnly = true,
				replayAt20Percent = true,
				noRecursivePrestige = true,
				noDuplicateOutcomes = true,
			},
		},
		triggers = {
			{
				hook = "after_all_effects",
				effects = {
					{
						op = "replay_resolution_packet",
						selectionMode = "random",
						count = 1,
						scale = 0.2,
						preferFamily = "prestige",
						preferArchetype = "bent",
					},
				},
			},
		},
	},
	{
		id = "curtain_call_ii",
		name = "Curtain Call II",
		rarity = "uncommon",
		description = "After all effects, replay two random completed coin Outcomes at 20% value, preferring Bent Coins. The same Outcome cannot be replayed twice.",
		tags = { "prestige", "outcome", "prestige_replay", "curtain_call" },
		trick = {
			category = "prestige",
			lineId = "curtain_call",
			tags = { "prestige", "outcome", "prestige_replay", "curtain_call" },
			tier = 2,
			timing = "after_all_effects",
			targetRule = "two_random_positive_outcomes_prefer_bent",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				outcomeReplayOnly = true,
				replayAt20Percent = true,
				noRecursivePrestige = true,
				noDuplicateOutcomes = true,
			},
		},
		triggers = {
			{
				hook = "after_all_effects",
				effects = {
					{
						op = "replay_resolution_packet",
						selectionMode = "random",
						count = 2,
						scale = 0.2,
						preferFamily = "prestige",
						preferArchetype = "bent",
					},
				},
			},
		},
	},
	{
		id = "impossible_finale",
		name = "Impossible Finale",
		rarity = "common",
		description = "After all effects, replay the highest-value completed coin Outcome at 20% value.",
		tags = { "prestige", "outcome", "prestige_replay", "finale" },
		trick = {
			category = "prestige",
			lineId = "impossible_finale",
			tags = { "prestige", "outcome", "prestige_replay", "finale" },
			tier = 1,
			timing = "after_all_effects",
			targetRule = "highest_value_positive_outcome",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				outcomeReplayOnly = true,
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
						selectionMode = "highest_value",
						count = 1,
						scale = 0.2,
					},
				},
			},
		},
	},
	{
		id = "impossible_finale_ii",
		name = "Impossible Finale II",
		rarity = "uncommon",
		description = "After all effects, replay the two highest-value completed coin Outcomes at 20% value.",
		tags = { "prestige", "outcome", "prestige_replay", "finale" },
		trick = {
			category = "prestige",
			lineId = "impossible_finale",
			tags = { "prestige", "outcome", "prestige_replay", "finale" },
			tier = 2,
			timing = "after_all_effects",
			targetRule = "two_highest_value_positive_outcomes",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				outcomeReplayOnly = true,
				replayAt20Percent = true,
				noRecursivePrestige = true,
				noDuplicateOutcomes = true,
			},
		},
		triggers = {
			{
				hook = "after_all_effects",
				effects = {
					{
						op = "replay_resolution_packet",
						selectionMode = "highest_value",
						count = 2,
						scale = 0.2,
					},
				},
			},
		},
	},
	{
		id = "impossible_finale_iii",
		name = "Impossible Finale III",
		rarity = "rare",
		description = "After all effects, replay every completed coin Outcome at 75% of its recorded Score contribution.",
		tags = { "prestige", "outcome", "prestige_replay", "finale" },
		trick = {
			category = "prestige",
			lineId = "impossible_finale",
			tags = { "prestige", "outcome", "prestige_replay", "finale" },
			tier = 3,
			timing = "after_all_effects",
			targetRule = "all_positive_outcomes",
			scope = {
				oncePerFlip = true,
				oncePerPrestige = true,
				outcomeReplayOnly = true,
				replayAt75Percent = true,
				noRecursivePrestige = true,
				noDuplicateOutcomes = true,
			},
		},
		triggers = {
			{
				hook = "after_all_effects",
				effects = {
					{
						op = "replay_resolution_packet",
						selectionMode = "all",
						scale = 0.75,
					},
				},
			},
		},
	},
	{
		id = "hidden_pocket",
		name = "Hidden Pocket",
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
		id = "hidden_in_plain_sight",
		name = "Hidden in Plain Sight",
		rarity = "common",
		priorityLayer = 0,
    description = "After the call, smuggle your highest-quality Hollow Coin if possible, otherwise one unselected dealt coin. Silver/Gold Hollows score 1.25x/1.5x.",
		tags = { "smuggle", "hand", "board_overload", "extra_coin" },
		trick = {
			category = "smuggle",
			tags = { "smuggle", "hand", "board_overload", "extra_coin" },
			tier = 1,
			timing = "after_call_before_flip",
			targetRule = "dealt_hand_unselected_prefer_highest_material_hollow",
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
						orderBy = "material_rank_desc",
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
					{
						op = "apply_score_scaling",
						value = 1.0,
						target = "current_coin_score",
						materialFamily = "smuggle",
						materialBaseMultiplier = 1.0,
						materialRankStep = 0.25,
						requireSpecializedFamily = true,
					},
				},
			},
		},
	},
	{
		id = "off_the_books",
		name = "Off the Books",
		rarity = "common",
    description = "After a flip where you smuggled at least one coin, draw +1 extra coin into your next hand if available.",
		tags = { "smuggle", "refill", "hand", "stockpile" },
		trick = {
			category = "smuggle",
			tags = { "smuggle", "refill", "hand", "stockpile" },
			tier = 1,
			timing = "on_batch_end",
			targetRule = "next_hand_draw",
			scope = { oncePerFlip = true, requiresSmuggledCoin = true },
		},
		triggers = {
			{
				hook = "on_batch_end",
				condition = { smuggled_this_flip = true },
				effects = {
					{ op = "add_next_hand_draws", amount = 1, reason = "off_the_books" },
				},
			},
		},
	},
	{
		id = "planted_double",
		name = "Planted Double",
		rarity = "common",
		priorityLayer = 20,
    description = "After the call, if you smuggled a coin this flip, roll a 50% chance to copy a random smuggled coin into another temporary overload slot.",
		tags = { "smuggle", "multiply", "contraband_copy", "temporary" },
		trick = {
			category = "smuggle",
			tags = { "smuggle", "multiply", "contraband_copy", "temporary" },
			tier = 1,
			timing = "after_call_before_flip",
			targetRule = "random_smuggled_coin_this_flip",
			scope = { oncePerFlip = true, temporaryCopy = true, maxOverloadSlots = 2 },
		},
		triggers = {
			{
				hook = "after_call_before_flip",
				effects = {
					{ op = "copy_smuggled_coin", chance = 0.5, maxOverloadSlots = 2, reason = "planted_double" },
				},
			},
		},
	},
	{
		id = "embarrassment_of_riches",
		name = "Embarrassment of Riches",
		rarity = "common",
    description = "Coins that were not selected in the original flip but still got flipped score 1.5x.",
		tags = { "smuggle", "overloaded_board", "payoff", "extra_coin" },
		trick = {
			category = "smuggle",
			tags = { "smuggle", "overloaded_board", "payoff", "extra_coin" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "unselected_flipped_coin",
			scope = { smuggledCoinOnly = true, noResultChange = true },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { smuggled = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.5, target = "current_coin_score", reason = "embarrassment_of_riches" },
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
    description = "Once per flip, your first positive Luck gain adds +2 extra Luck Meter progress.",
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
					{ op = "add_luck", amount = 2, reason = "omen_engine" },
				},
			},
		},
	},
	{
		id = "fountain_pact",
		name = "Fountain Pact",
		rarity = "common",
		priorityLayer = 10,
    description = "Luck generation is 1.5x faster.",
		tags = { "fate", "fountain_favor", "luck_gain", "accelerator" },
		trick = {
			category = "fate",
			lineId = "fountain_pact",
			tags = { "fate", "fountain_favor", "luck_gain", "accelerator" },
			tier = 1,
			timing = "passive",
			targetRule = "luck_meter",
			scope = { meterOnly = true, noIndividualCoinTargeting = true, noFatedResultChange = true },
		},
		effectiveValues = {
			["luck.generationMultiplier"] = { mode = "override", value = 1.5 },
		},
	},
	{
		id = "fountain_pact_ii",
		name = "Fountain Pact II",
		rarity = "uncommon",
		priorityLayer = 20,
    description = "Luck generation is 1.75x faster.",
		tags = { "fate", "fountain_favor", "luck_gain", "accelerator" },
		trick = {
			category = "fate",
			lineId = "fountain_pact",
			tags = { "fate", "fountain_favor", "luck_gain", "accelerator" },
			tier = 2,
			timing = "passive",
			targetRule = "luck_meter",
			scope = { meterOnly = true, noIndividualCoinTargeting = true, noFatedResultChange = true },
		},
		effectiveValues = {
			["luck.generationMultiplier"] = { mode = "override", value = 1.75 },
		},
	},
	{
		id = "fountain_pact_iii",
		name = "Fountain Pact III",
		rarity = "rare",
		priorityLayer = 30,
    description = "Luck generation is 2x faster.",
		tags = { "fate", "fountain_favor", "luck_gain", "accelerator" },
		trick = {
			category = "fate",
			lineId = "fountain_pact",
			tags = { "fate", "fountain_favor", "luck_gain", "accelerator" },
			tier = 3,
			timing = "passive",
			targetRule = "luck_meter",
			scope = { meterOnly = true, noIndividualCoinTargeting = true, noFatedResultChange = true },
		},
		effectiveValues = {
			["luck.generationMultiplier"] = { mode = "override", value = 2.0 },
		},
	},
	{
		id = "twist_of_fate",
		name = "Twist of Fate",
		rarity = "common",
		priorityLayer = 10,
    description = "Fated Flips score 1.5x.",
		tags = { "fate", "fated_flip", "payoff", "score_scaling" },
		trick = {
			category = "fate",
			lineId = "twist_of_fate",
			tags = { "fate", "fated_flip", "payoff", "score_scaling" },
			tier = 1,
			timing = "before_scoring",
			targetRule = "fated_flip_score",
			scope = { fatedFlipOnly = true, noIndividualCoinTargeting = true, noFatedResultChange = true },
		},
		triggers = {
			{
				hook = "before_scoring",
				condition = { fated_flip = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.5, reason = "twist_of_fate" },
				},
			},
		},
	},
	{
		id = "twist_of_fate_ii",
		name = "Twist of Fate II",
		rarity = "uncommon",
		priorityLayer = 20,
    description = "Fated Flips score 1.75x.",
		tags = { "fate", "fated_flip", "payoff", "score_scaling" },
		trick = {
			category = "fate",
			lineId = "twist_of_fate",
			tags = { "fate", "fated_flip", "payoff", "score_scaling" },
			tier = 2,
			timing = "before_scoring",
			targetRule = "fated_flip_score",
			scope = { fatedFlipOnly = true, noIndividualCoinTargeting = true, noFatedResultChange = true },
		},
		triggers = {
			{
				hook = "before_scoring",
				condition = { fated_flip = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.75, reason = "twist_of_fate_ii" },
				},
			},
		},
	},
	{
		id = "twist_of_fate_iii",
		name = "Twist of Fate III",
		rarity = "rare",
		priorityLayer = 30,
    description = "Fated Flips score 2.25x.",
		tags = { "fate", "fated_flip", "payoff", "score_scaling" },
		trick = {
			category = "fate",
			lineId = "twist_of_fate",
			tags = { "fate", "fated_flip", "payoff", "score_scaling" },
			tier = 3,
			timing = "before_scoring",
			targetRule = "fated_flip_score",
			scope = { fatedFlipOnly = true, noIndividualCoinTargeting = true, noFatedResultChange = true },
		},
		triggers = {
			{
				hook = "before_scoring",
				condition = { fated_flip = true },
				effects = {
					{ op = "apply_score_scaling", value = 2.25, reason = "twist_of_fate_iii" },
				},
			},
		},
	},
	{
		id = "heads_varnish",
		name = "Headside Edge",
		rarity = "common",
		description = "On Heads Flip, selected coins get +12% Heads Chance. Double for Weighted Coins.",
		tags = { "weighted", "heads", "weight" },
		trick = {
			category = "weighted",
			tags = { "weighted", "weight", "heads" },
			tier = 1,
			timing = "before_flip",
			targetRule = "all_selected_coins_on_heads_flip",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "before_coin_roll",
				condition = { call = "heads" },
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
		description = "First selected Weighted Coin gets at least 75% Matching Call chance. Matching Weighted Coins score 1.5x/1.75x/2x by material.",
		tags = { "weighted", "weight" },
		trick = {
			category = "weighted",
			tags = { "weighted", "weight" },
			tier = 1,
			timing = "before_flip",
			targetRule = "selected_coins_prefer_weighted_first_slot_position",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "before_coin_roll",
				condition = { slot_index = 1 },
				effects = {
					{
						op = "set_call_match_chance",
						chance = 0.75,
						minimum = true,
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
			{
				hook = "before_coin_score",
				condition = { match = true },
				effects = {
					{
						op = "apply_score_scaling",
						value = 1.0,
						target = "current_coin_score",
						materialFamily = "weighted",
						materialBaseMultiplier = 1.5,
						materialRankStep = 0.25,
						requireSpecializedFamily = true,
					},
				},
			},
		},
	},
	{
		id = "see_behind_the_veil",
		name = "See Behind the Veil",
		rarity = "common",
		description = "After deal, Foretell your highest-quality Marked Coin. If there are none, Foretell the first eligible dealt coin.",
		tags = { "prediction", "marked", "foretold", "read", "auto" },
		trick = {
			category = "prediction",
			tags = { "prediction", "marked", "foretold", "read", "auto" },
			tier = 1,
			timing = "after_deal_before_selection",
			targetRule = "dealt_hand_not_foretold_prefer_highest_material_prediction",
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
							orderBy = "material_rank_desc",
							pick = { op = "slot_at_position", value = 1 },
						},
						specializedFamily = "prediction",
					},
				},
			},
		},
	},
	{
		id = "fake_credentials",
		name = "Fake Credentials",
		rarity = "common",
		description = "If this Forgery Coin misses, copy 50% of the genuine coin immediately to its left's root Outcome.",
		tags = { "counterfeit", "outcome", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "fake_credentials", tier = 1 },
		triggers = {},
	},
	{
		id = "borrowed_name",
		name = "Borrowed Name",
		rarity = "common",
		description = "Before Flip, rig this Blank to imitate one Tier I Trick from the genuine family immediately to its left.",
		tags = { "counterfeit", "activation", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "borrowed_name", tier = 1 },
		triggers = {},
	},
	{
		id = "borrowed_name_ii",
		name = "Borrowed Name II",
		rarity = "uncommon",
		description = "Before Flip, rig this Blank to imitate up to two Tier I-II Tricks from the genuine family immediately to its left.",
		tags = { "counterfeit", "activation", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "borrowed_name", tier = 2 },
		triggers = {},
	},
	{
		id = "borrowed_name_iii",
		name = "Borrowed Name III",
		rarity = "rare",
		description = "Before Flip, rig this Blank to imitate up to three Tier I-III Tricks from the genuine family immediately to its left.",
		tags = { "counterfeit", "activation", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "borrowed_name", tier = 3 },
		triggers = {},
	},
	{
		id = "switcheroo",
		name = "Switcheroo",
		rarity = "common",
		description = "After flip, your highest-quality missed Vanishing Coin switches into a matching result slot and scores 3.5x/4x/4.5x by material.",
		tags = { "sleight", "swap", "match", "miss" },
		trick = {
			category = "sleight",
			tags = { "sleight", "swap", "match", "miss" },
			tier = 1,
			timing = "after_flip_before_score",
			targetRule = "highest_material_vanishing_miss_to_matching_slot",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "after_flip_before_score",
				effects = {
					{
						op = "swap_coins",
						qualityFamily = "sleight",
						qualityBaseMultiplier = 3.5,
						qualityRankStep = 0.5,
						target = {
							source = {
								zone = "selected_coins",
								filters = {
									{ op = "failed_call" },
									{ op = "real_family", value = "sleight" },
								},
								orderBy = "material_rank_desc",
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
		id = "false_bottom",
		name = "False Bottom",
		rarity = "common",
		description = "After flip, your weakest Match is replaced by the highest-quality unselected Vanishing Coin, which scores 3.5x/4x/4.5x by material.",
		tags = { "sleight", "replace", "hand", "match" },
		trick = {
			category = "sleight",
			tags = { "sleight", "replace", "hand", "match" },
			tier = 1,
			timing = "after_flip_before_score",
			targetRule = "lowest_match_to_highest_material_unselected_vanishing_coin",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "after_flip_before_score",
				effects = {
					{
						op = "replace_coin_from_hand",
						qualityFamily = "sleight",
						qualityBaseMultiplier = 3.5,
						qualityRankStep = 0.5,
						target = {
							target = {
								zone = "selected_coins",
								filters = {
									{ op = "matched_call" },
								},
								orderBy = "base_score",
								pick = { op = "slot_at_position", value = 1 },
							},
							replacement = {
								zone = "dealt_hand",
								filters = {
									{ op = "not_selected" },
									{ op = "not_smuggled" },
									{ op = "real_family", value = "sleight" },
								},
								orderBy = "material_rank_desc",
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
		id = "keep_it_rolling",
		name = "Keep It Rolling",
		rarity = "common",
    description = "After a scoring coin, there is a 50% chance to trigger a neighbouring Flywheel Coin if possible, otherwise a random neighbour, for an extra Score event.",
		tags = { "momentum", "in_motion", "random_neighbor", "propagation" },
		trick = {
			category = "momentum",
			tags = { "momentum", "in_motion", "random_neighbor", "propagation" },
			tier = 1,
			timing = "after_coin_score",
			targetRule = "unused_neighbor_prefer_momentum_random",
			scope = { oncePerFlip = true, momentumChance = 0.5, maxMomentumDepth = 2, maxTriggers = 2, noMomentumReentry = true },
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
								{ op = "family", value = "momentum" },
							},
						orderBy = "material_rank_desc",
							pick = { op = "slot_at_position", value = 1 },
						},
						chainChance = 0.5,
						maxChainDepth = 2,
						maxTriggers = 2,
						specializedFamily = "momentum",
					},
				},
			},
		},
	},
	{
		id = "follow_through",
		name = "Follow Through",
		rarity = "common",
    description = "Triggered Momentum Score gains +25% for each link that carried the coin.",
		tags = { "momentum", "in_motion", "payoff", "score_scaling" },
		trick = {
			category = "momentum",
			tags = { "momentum", "in_motion", "payoff", "score_scaling" },
			tier = 1,
			timing = "on_batch_start",
			targetRule = "all_momentum_triggered_coin_scores",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "on_batch_start",
				effects = {
					{ op = "set_batch_flag", flag = "momentum_follow_through" },
				},
			},
		},
	},
	{
		id = "ripple",
		name = "Ripple",
		rarity = "common",
    description = "After a scoring coin, there is a 50% chance to trigger a random neighbour, then a 25% chance to continue Momentum.",
		tags = { "momentum", "ripple", "random_neighbor", "propagation" },
		trick = {
			category = "momentum",
			lineId = "ripple",
			tags = { "momentum", "ripple", "random_neighbor", "propagation" },
			tier = 1,
			timing = "after_coin_score",
			targetRule = "random_neighbor_then_continue",
			scope = { oncePerFlip = true, momentumChance = 0.5, continuationChance = 0.25, maxMomentumDepth = 3, noMomentumReentry = true },
		},
		triggers = {
			{
				hook = "after_coin_score",
				condition = { match = true },
				effects = {
					{ op = "trigger_random_neighbor", chainChance = 0.5, continuationChance = 0.25, maxChainDepth = 3, maxTriggers = 3 },
				},
			},
		},
	},
	{
		id = "ripple_ii",
		name = "Ripple II",
		rarity = "uncommon",
    description = "After a scoring coin, there is a 75% chance to trigger the neighbour to the left, then a 50% chance to continue Momentum to the left.",
		tags = { "momentum", "ripple", "left_neighbor", "propagation" },
		trick = {
			category = "momentum",
			lineId = "ripple",
			tags = { "momentum", "ripple", "left_neighbor", "propagation" },
			tier = 2,
			timing = "after_coin_score",
			targetRule = "left_neighbor_then_continue_left",
			scope = { oncePerFlip = true, momentumChance = 0.75, continuationChance = 0.5, maxMomentumDepth = 3, noMomentumReentry = true },
		},
		triggers = {
			{
				hook = "after_coin_score",
				condition = { match = true },
				effects = {
					{ op = "trigger_random_neighbor", direction = "left", chainChance = 0.75, continuationChance = 0.5, maxChainDepth = 3, maxTriggers = 3 },
				},
			},
		},
	},
	{
		id = "ripple_iii",
		name = "Ripple III",
		rarity = "rare",
    description = "After a scoring coin, there is a 75% chance to trigger neighbours in both directions, then a 50% chance to continue Momentum in each direction.",
		tags = { "momentum", "ripple", "both_neighbors", "propagation" },
		trick = {
			category = "momentum",
			lineId = "ripple",
			tags = { "momentum", "ripple", "both_neighbors", "propagation" },
			tier = 3,
			timing = "after_coin_score",
			targetRule = "both_neighbors_then_continue",
			scope = { oncePerFlip = true, momentumChance = 0.75, continuationChance = 0.5, maxMomentumDepth = 3, noMomentumReentry = true },
		},
		triggers = {
			{
				hook = "after_coin_score",
				condition = { match = true },
				effects = {
					{ op = "trigger_random_neighbor", directions = { "left", "right" }, chainChance = 0.75, continuationChance = 0.5, maxChainDepth = 3, maxTriggers = 6 },
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
		tags = { "momentum", "temporary", "black_market", "all_match" },
		trick = {
			category = "momentum",
			tags = { "momentum", "all_match", "temporary", "influence" },
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
		description = "On Tails Flip, Foretold Coins with Matching Call score 1.25x.",
		tags = { "prediction", "tails", "foretold", "score_scaling" },
		trick = {
			category = "prediction",
			tags = { "prediction", "tails", "foretold", "score_scaling" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "tails_flip_foretold_matching_call",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { result = "tails", foretold = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.25, target = "current_coin_score" },
				},
			},
		},
	},
	{
		id = "heads_contract",
		name = "Heads Pact",
		rarity = "common",
		description = "On Heads Flip, Foretold Coins with Matching Call score 1.25x.",
		tags = { "prediction", "heads", "foretold", "score_scaling" },
		trick = {
			category = "prediction",
			tags = { "prediction", "heads", "foretold", "score_scaling" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "heads_flip_foretold_matching_call",
			scope = { maxTriggersPerCoin = 1 },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { result = "heads", foretold = true, match = true },
				effects = {
					{ op = "apply_score_scaling", value = 1.25, target = "current_coin_score" },
				},
			},
		},
	},
	{
		id = "fulfilled_fate",
		name = "Fulfilled Fate",
		rarity = "common",
		description = "First selected Foretold Coin with Matching Call scores 2x/2.5x/3x when it is Copper/Silver/Gold Marked; other Foretold coins score normally.",
		tags = { "prediction", "marked", "foretold", "fulfillment", "score_scaling" },
		trick = {
			category = "prediction",
			tags = { "prediction", "marked", "foretold", "fulfillment", "score_scaling" },
			tier = 1,
			timing = "before_coin_score",
			targetRule = "first_selected_foretold_matching_call",
			scope = { oncePerFlip = true },
		},
		triggers = {
			{
				hook = "before_coin_score",
				condition = { foretold = true, match = true },
				effects = {
					{
						op = "apply_score_scaling",
						value = 1.0,
						target = "current_coin_score",
						materialFamily = "prediction",
						materialBaseMultiplier = 2.0,
						materialRankStep = 0.5,
					},
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
}

local EXTORTION_TIER_SUFFIXES = { "", "_ii", "_iii" }
local EXTORTION_TIER_LABELS = { "", " II", " III" }
local EXTORTION_TIER_RARITIES = { "common", "uncommon", "rare" }

local function pluralizeUse(uses, singular, plural)
	return uses == 1 and singular or plural
end

local function addExtortionLine(line)
	for tier = 1, 3 do
		local uses = tier

		table.insert(definitions, {
			id = line.id .. EXTORTION_TIER_SUFFIXES[tier],
			name = line.name .. EXTORTION_TIER_LABELS[tier],
			rarity = EXTORTION_TIER_RARITIES[tier],
			description = line.description(uses),
			tags = { "extortion", line.stageTag, line.effectTag, "crumbles" },
			trick = {
				category = "extortion",
				lineId = line.id,
				tags = { "extortion", line.stageTag, line.effectTag, "crumbles" },
				tier = tier,
				timing = line.timing,
				targetRule = line.targetRule,
				scope = {
					crumbles = true,
					uses = uses,
					useType = line.useType,
				},
			},
			crumble = {
				uses = uses,
				useType = line.useType,
			},
			extortion = {
				effect = line.effect,
				stage = line.stage,
				value = line.value,
			},
		})
	end
end

addExtortionLine({
	id = "five_finger_discount",
	name = "Five-Finger Discount",
	stage = "black_market",
	stageTag = "black_market",
	effect = "extort_cheapest_coin",
	effectTag = "extort_coin",
	timing = "after_shop_generation",
	targetRule = "cheapest_coin_offer_once_per_black_market_visit",
	useType = "black_market_visit",
	description = function(uses)
		return string.format(
			"At your next %d Black Market %s, extort the cheapest Coin. Rerolls do not refresh this. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "visit", "visits")
		)
	end,
})

addExtortionLine({
	id = "loaded_shelves",
	name = "Loaded Shelves",
	stage = "black_market",
	stageTag = "black_market",
	effect = "guarantee_uncommon_coin",
	effectTag = "stock_quality",
	timing = "before_shop_generation",
	targetRule = "black_market_coin_stock_uncommon_or_better",
	useType = "black_market_visit",
		description = function(uses)
			return string.format(
				"Your next %d Black Market %s contain at least one uncommon-or-better Coin if possible. Then this Charm Crumbles.",
				uses,
				pluralizeUse(uses, "visit", "visits")
			)
		end,
})

addExtortionLine({
	id = "pressure_sale",
	name = "Pressure Sale",
	stage = "black_market",
	stageTag = "black_market",
	effect = "pressure_reroll_discount",
	effectTag = "discount",
	timing = "after_shop_generation",
	targetRule = "rerolled_coin_offers",
	useType = "black_market_reroll",
	description = function(uses)
		return string.format(
			"Your next %d Black Market %s discount returned Coin offers by 1 Influence per consecutive reroll this visit. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "reroll", "rerolls")
		)
	end,
})

addExtortionLine({
	id = "no_questions_asked",
	name = "No Questions Asked",
	stage = "black_market",
	stageTag = "black_market",
	effect = "extorted_coin_reroll",
	effectTag = "reroll",
	timing = "after_purchase",
	targetRule = "extorted_coin_purchase",
	useType = "extorted_coin_taken",
	description = function(uses)
		return string.format(
			"The next %d %s you take an extorted Coin, gain +1 Free Reroll. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "time", "times")
		)
	end,
})

addExtortionLine({
	id = "strong_arm_deal",
	name = "Strong-Arm Deal",
	stage = "spoils",
	stageTag = "spoils",
	effect = "extra_spoils_option",
	effectTag = "extra_charm",
	timing = "before_spoils_generation",
	targetRule = "spoils_charm_options",
	useType = "spoils_screen",
	description = function(uses)
		return string.format(
			"Your next %d Spoils %s show +1 extra Charm option. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "screen", "screens")
		)
	end,
})

addExtortionLine({
	id = "take_whats_owed",
	name = "Take What's Owed",
	stage = "spoils",
	stageTag = "spoils",
	effect = "spoils_seize_discount",
	effectTag = "discount",
	timing = "before_seize",
	targetRule = "next_seized_charm",
	useType = "seized_charm",
	value = 2,
	description = function(uses)
		return string.format(
			"The next %d %s you Seize from Spoils cost 2 less Influence. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "Charm", "Charms")
		)
	end,
})

addExtortionLine({
	id = "protection_racket",
	name = "Protection Racket",
	stage = "spoils",
	stageTag = "spoils",
	effect = "extra_enemy_family_spoils",
	effectTag = "enemy_family",
	timing = "before_spoils_generation",
	targetRule = "defeated_enemy_family_charm_options",
	useType = "spoils_screen",
	description = function(uses)
		return string.format(
			"Your next %d Spoils %s include +1 extra Charm option from the defeated enemy's family if possible. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "screen", "screens")
		)
	end,
})

addExtortionLine({
	id = "forced_confession",
	name = "Forced Confession",
	stage = "spoils",
	stageTag = "spoils",
	effect = "reveal_higher_tier_spoils",
	effectTag = "higher_tier",
	timing = "before_spoils_generation",
	targetRule = "higher_tier_charm_option",
	useType = "spoils_screen",
	description = function(uses)
		return string.format(
			"Your next %d Spoils %s reveal +1 higher-tier Charm option if possible. Then this Charm Crumbles.",
			uses,
			pluralizeUse(uses, "screen", "screens")
		)
	end,
})

-- New family-trigger-native tier lines fill out the thinnest surviving
-- families. Unlike the legacy records above, these definitions are authored
-- directly against activation_source semantics.
local FAMILY_TRIGGER_NATIVE_DEFINITIONS = {
	{
		id = "weighted_palm_ii",
		name = "Weighted Palm II",
		rarity = "uncommon",
		description = "The activating coin has at least 75% chance to match your call. If it matches, its Outcome is worth 1.65x.",
		tags = { "weighted", "weight", "score_scaling" },
		trick = {
			category = "weighted",
			lineId = "weighted_palm",
			tier = 2,
			timing = "before_flip",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "before_coin_roll", effects = {
				{ op = "set_call_match_chance", chance = 0.75, minimum = true },
			} },
			{ hook = "before_coin_score", condition = { match = true }, effects = {
				{ op = "apply_score_scaling", value = 1.65, target = "current_coin_score" },
			} },
		},
	},
	{
		id = "weighted_palm_iii",
		name = "Weighted Palm III",
		rarity = "rare",
		description = "The activating coin has at least 85% chance to match your call. If it matches, its Outcome is worth 1.85x.",
		tags = { "weighted", "weight", "score_scaling" },
		trick = {
			category = "weighted",
			lineId = "weighted_palm",
			tier = 3,
			timing = "before_flip",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "before_coin_roll", effects = {
				{ op = "set_call_match_chance", chance = 0.85, minimum = true },
			} },
			{ hook = "before_coin_score", condition = { match = true }, effects = {
				{ op = "apply_score_scaling", value = 1.85, target = "current_coin_score" },
			} },
		},
	},
	{
		id = "encore_ii",
		name = "Encore II",
		rarity = "uncommon",
		description = "Replay 30% of the activating coin's original Outcome.",
		tags = { "prestige", "outcome", "prestige_replay", "encore" },
		trick = {
			category = "prestige",
			lineId = "encore",
			tier = 2,
			timing = "after_all_effects",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "after_all_effects", effects = {
				{ op = "replay_resolution_packet", selectionMode = "activation_source", scale = 0.30 },
			} },
		},
	},
	{
		id = "encore_iii",
		name = "Encore III",
		rarity = "rare",
		description = "Replay 40% of the activating coin's original Outcome.",
		tags = { "prestige", "outcome", "prestige_replay", "encore" },
		trick = {
			category = "prestige",
			lineId = "encore",
			tier = 3,
			timing = "after_all_effects",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "after_all_effects", effects = {
				{ op = "replay_resolution_packet", selectionMode = "activation_source", scale = 0.40 },
			} },
		},
	},
	{
		id = "curtain_call_iii",
		name = "Curtain Call III",
		rarity = "rare",
		description = "Replay 40% of up to three different random other committed root Outcomes.",
		tags = { "prestige", "outcome", "prestige_replay", "curtain_call" },
		trick = {
			category = "prestige",
			lineId = "curtain_call",
			tier = 3,
			timing = "after_all_effects",
			targetRule = "three_random_other_positive_outcomes",
		},
		triggers = {
			{ hook = "after_all_effects", effects = {
				{ op = "replay_resolution_packet", selectionMode = "random_other", count = 3, scale = 0.40 },
			} },
		},
	},
	{
		id = "keep_it_rolling_ii",
		name = "Keep It Rolling II",
		rarity = "uncommon",
		description = "After the activating coin scores, there is a 75% chance to Replay the next committed coin's original Outcome.",
		tags = { "momentum", "in_motion", "directional", "replay" },
		trick = {
			category = "momentum",
			lineId = "keep_it_rolling",
			tier = 2,
			timing = "after_coin_score",
			targetRule = "next_committed_coin",
		},
		triggers = {
			{ hook = "after_coin_score", condition = { match = true }, effects = {
				{ op = "replay_resolution_packet", selectionMode = "directional", direction = "right", count = 1, chance = 0.75, scale = 1 },
			} },
		},
	},
	{
		id = "keep_it_rolling_iii",
		name = "Keep It Rolling III",
		rarity = "rare",
		description = "After the activating coin scores, Replay the next committed coin's original Outcome.",
		tags = { "momentum", "in_motion", "directional", "replay" },
		trick = {
			category = "momentum",
			lineId = "keep_it_rolling",
			tier = 3,
			timing = "after_coin_score",
			targetRule = "next_committed_coin",
		},
		triggers = {
			{ hook = "after_coin_score", condition = { match = true }, effects = {
				{ op = "replay_resolution_packet", selectionMode = "directional", direction = "right", count = 1, chance = 1, scale = 1 },
			} },
		},
	},
	{
		id = "follow_through_ii",
		name = "Follow Through II",
		rarity = "uncommon",
		description = "Reactivated coins score +50% for each chain depth.",
		tags = { "momentum", "in_motion", "payoff", "score_scaling" },
		trick = {
			category = "momentum",
			lineId = "follow_through",
			tier = 2,
			timing = "before_coin_score",
			targetRule = "reactivated_coin",
		},
		triggers = {
			{ hook = "before_coin_score", effects = {
				{ op = "apply_score_scaling", value = 1, chainDepthBonus = 0.50, target = "current_coin_score" },
			} },
		},
	},
	{
		id = "follow_through_iii",
		name = "Follow Through III",
		rarity = "rare",
		description = "Reactivated coins score +75% for each chain depth.",
		tags = { "momentum", "in_motion", "payoff", "score_scaling" },
		trick = {
			category = "momentum",
			lineId = "follow_through",
			tier = 3,
			timing = "before_coin_score",
			targetRule = "reactivated_coin",
		},
		triggers = {
			{ hook = "before_coin_score", effects = {
				{ op = "apply_score_scaling", value = 1, chainDepthBonus = 0.75, target = "current_coin_score" },
			} },
		},
	},
	{
		id = "switcheroo_ii",
		name = "Switcheroo II",
		rarity = "uncommon",
		description = "If the activating Sleight coin Matches, switch it with a random Miss from the highest-quality eligible group.",
		tags = { "sleight", "swap", "match", "miss" },
		trick = {
			category = "sleight",
			lineId = "switcheroo",
			tier = 2,
			timing = "after_flip_before_score",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "after_flip_before_score", condition = { match = true }, effects = {
				{ op = "swap_coins", targetMode = "highest_material_higher_miss" },
			} },
		},
	},
	{
		id = "switcheroo_iii",
		name = "Switcheroo III",
		rarity = "rare",
		description = "If the activating Sleight coin Matches, switch it with the highest-value eligible Miss. Randomly break ties.",
		tags = { "sleight", "swap", "match", "miss" },
		trick = {
			category = "sleight",
			lineId = "switcheroo",
			tier = 3,
			timing = "after_flip_before_score",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "after_flip_before_score", condition = { match = true }, effects = {
				{ op = "swap_coins", targetMode = "highest_value_higher_miss" },
			} },
		},
	},
	{
		id = "vanishing_act",
		name = "Vanishing Act",
		rarity = "common",
		description = "If the activating Sleight coin Misses, palm it back into your hand instead of spending it.",
		tags = { "sleight", "palm", "save", "miss", "hand" },
		trick = {
			category = "sleight",
			lineId = "vanishing_act",
			tier = 1,
			timing = "after_flip_before_score",
			targetRule = "activation_source_miss",
		},
		triggers = {
			{ hook = "after_flip_before_score", effects = {
				{ op = "palm_failed_coin", targetMode = "activation_source_miss" },
			} },
		},
	},
	{
		id = "vanishing_act_ii",
		name = "Vanishing Act II",
		rarity = "uncommon",
		description = "Palm the highest-value Miss among the activating Sleight coin and its neighbouring committed slots.",
		tags = { "sleight", "palm", "save", "miss", "neighbor" },
		trick = {
			category = "sleight",
			lineId = "vanishing_act",
			tier = 2,
			timing = "after_flip_before_score",
			targetRule = "local_highest_miss",
		},
		triggers = {
			{ hook = "after_flip_before_score", effects = {
				{ op = "palm_failed_coin", targetMode = "local_highest_miss" },
			} },
		},
	},
	{
		id = "vanishing_act_iii",
		name = "Vanishing Act III",
		rarity = "rare",
		description = "Palm the highest-value Miss among all regular committed coins.",
		tags = { "sleight", "palm", "save", "miss", "table" },
		trick = {
			category = "sleight",
			lineId = "vanishing_act",
			tier = 3,
			timing = "after_flip_before_score",
			targetRule = "global_highest_miss",
		},
		triggers = {
			{ hook = "after_flip_before_score", effects = {
				{ op = "palm_failed_coin", targetMode = "global_highest_miss" },
			} },
		},
	},
	{
		id = "three_card_monte",
		name = "Three-Card Monte",
		rarity = "common",
		description = "Randomly perform one score-improving swap between the activating Sleight coin and a regular committed neighbour.",
		tags = { "sleight", "rearrange", "neighbor", "position" },
		trick = {
			category = "sleight",
			lineId = "three_card_monte",
			tier = 1,
			timing = "after_flip_before_score",
			targetRule = "random_improving_neighbor",
		},
		triggers = {
			{ hook = "after_flip_before_score", effects = {
				{ op = "monte_rearrange", mode = "random_improving_neighbor" },
			} },
		},
	},
	{
		id = "three_card_monte_ii",
		name = "Three-Card Monte II",
		rarity = "uncommon",
		description = "Perform the best score-improving swap between the activating Sleight coin and either regular committed neighbour.",
		tags = { "sleight", "rearrange", "neighbor", "position" },
		trick = {
			category = "sleight",
			lineId = "three_card_monte",
			tier = 2,
			timing = "after_flip_before_score",
			targetRule = "best_improving_neighbor",
		},
		triggers = {
			{ hook = "after_flip_before_score", effects = {
				{ op = "monte_rearrange", mode = "best_improving_neighbor" },
			} },
		},
	},
	{
		id = "three_card_monte_iii",
		name = "Three-Card Monte III",
		rarity = "rare",
		description = "Choose the highest-scoring arrangement of the activating Sleight coin and both regular committed neighbours.",
		tags = { "sleight", "rearrange", "neighbor", "position", "permutation" },
		trick = {
			category = "sleight",
			lineId = "three_card_monte",
			tier = 3,
			timing = "after_flip_before_score",
			targetRule = "best_local_permutation",
		},
		triggers = {
			{ hook = "after_flip_before_score", effects = {
				{ op = "monte_rearrange", mode = "best_local_permutation" },
			} },
		},
	},
}

local PREDICTION_TIER_RARITY = { "common", "uncommon", "rare" }
local PREDICTION_TIER_SUFFIX = { "", "_ii", "_iii" }
local PREDICTION_TIER_LABEL = { "", " II", " III" }

local function addPredictionTierLine(line)
	for tier = 1, 3 do
		table.insert(FAMILY_TRIGGER_NATIVE_DEFINITIONS, {
			id = line.id .. PREDICTION_TIER_SUFFIX[tier],
			name = line.name .. PREDICTION_TIER_LABEL[tier],
			rarity = PREDICTION_TIER_RARITY[tier],
			description = line.descriptions[tier],
			tags = line.tags,
			trick = {
				category = "prediction",
				lineId = line.id,
				tier = tier,
				timing = line.hook,
				targetRule = line.targetRule,
			},
			triggers = {
				{
					hook = line.hook,
					condition = line.condition,
					effects = line.effects(tier),
				},
			},
		})
	end
end

-- Fulfilled Fate I is a legacy save ID defined above. Its II/III records are
-- native family-trigger definitions; the Tier I runtime override remains the
-- authoritative base effect.
for tier = 2, 3 do
	table.insert(FAMILY_TRIGGER_NATIVE_DEFINITIONS, {
		id = "fulfilled_fate" .. PREDICTION_TIER_SUFFIX[tier],
		name = "Fulfilled Fate" .. PREDICTION_TIER_LABEL[tier],
		rarity = PREDICTION_TIER_RARITY[tier],
		description = string.format(
			"If the activating Foretold coin fulfills your Call, its root Outcome is worth %.1fx.",
			tier == 2 and 2.5 or 3.0
		),
		tags = { "prediction", "foretold", "fulfillment", "score_scaling" },
		trick = {
			category = "prediction",
			lineId = "fulfilled_fate",
			tier = tier,
			timing = "before_coin_score",
			targetRule = "activation_source",
		},
		triggers = {
			{ hook = "before_coin_score", condition = { foretold = true, match = true }, effects = {
				{ op = "apply_score_scaling", value = tier == 2 and 2.5 or 3.0, target = "current_coin_score" },
			} },
		},
	})
end

addPredictionTierLine({
	id = "read_the_stars",
	name = "Read the Stars",
	hook = "after_coin_roll",
	condition = { foretold = true, match = true },
	targetRule = "matching_committed_neighbors",
	tags = { "prediction", "foretold", "neighbor", "score_scaling" },
	descriptions = {
		"When the activating Foretold coin fulfills your Call, matching neighbouring root Outcomes are worth 1.1x.",
		"When the activating Foretold coin fulfills your Call, matching neighbouring root Outcomes are worth 1.15x.",
		"When the activating Foretold coin fulfills your Call, matching neighbouring root Outcomes are worth 1.2x.",
	},
	effects = function(tier)
		return {
			{ op = "amplify_foretold_neighbors", value = ({ 1.10, 1.15, 1.20 })[tier], requireTargetMatch = true },
		}
	end,
})

addPredictionTierLine({
	id = "written_in_the_stars",
	name = "Written in the Stars",
	hook = "before_coin_roll",
	condition = { foretold = true },
	targetRule = "committed_neighbors",
	tags = { "prediction", "foretold", "neighbor", "weight" },
	descriptions = {
		"Adjacent committed coins gain +5% Chance toward the activating coin's Foretold result this Flip.",
		"Adjacent committed coins gain +10% Chance toward the activating coin's Foretold result this Flip.",
		"Adjacent committed coins gain +15% Chance toward the activating coin's Foretold result this Flip.",
	},
	effects = function(tier)
		return {
			{ op = "add_weight", side = "foretold", amount = ({ 0.05, 0.10, 0.15 })[tier], target = {
				zone = "selected_coins",
				filters = { { op = "neighbor_of_current" } },
				orderBy = "slot_position",
				pick = { op = "all" },
			} },
		}
	end,
})

addPredictionTierLine({
	id = "defy_fate",
	name = "Defy Fate",
	hook = "after_coin_roll",
	condition = { foretold = true, match = false },
	targetRule = "matching_committed_neighbors",
	tags = { "prediction", "foretold", "sacrifice", "neighbor", "score_scaling" },
	descriptions = {
		"If you Call against the activating Foretold coin, sacrifice it; matching neighbouring root Outcomes are worth 1.5x.",
		"If you Call against the activating Foretold coin, sacrifice it; matching neighbouring root Outcomes are worth 1.75x.",
		"If you Call against the activating Foretold coin, sacrifice it; matching neighbouring root Outcomes are worth 2x.",
	},
	effects = function(tier)
		return {
			{ op = "amplify_foretold_neighbors", value = ({ 1.50, 1.75, 2.00 })[tier], requireTargetMatch = true, sacrificeSource = true },
		}
	end,
})

table.insert(FAMILY_TRIGGER_NATIVE_DEFINITIONS, {
	id = "under_the_table",
	name = "Under the Table",
	rarity = "common",
	description = "Smuggle one random lowest-quality uncommitted Smuggling Coin beside the activating coin, up to three overloaded coins this Flip.",
	tags = { "smuggle", "hand", "slot_overload", "lowest_quality" },
	trick = {
		category = "smuggle",
		tier = 1,
		timing = "after_call_before_flip",
		targetRule = "random_lowest_material_uncommitted_smuggling_coin",
	},
	triggers = {
		{ hook = "after_call_before_flip", effects = {
			{ op = "smuggle_coin_from_hand", target = {
				zone = "dealt_hand",
				filters = {
					{ op = "not_selected" },
					{ op = "not_smuggled" },
					{ op = "real_family", value = "smuggle" },
				},
				materialBand = "lowest",
				orderBy = "random",
				pick = { op = "slot_at_position", value = 1 },
			}, maxOverloadSlots = 3 },
		} },
	},
})

table.insert(FAMILY_TRIGGER_NATIVE_DEFINITIONS, {
	id = "fall_guy",
	name = "Fall Guy",
	rarity = "uncommon",
	description = "If the activating Smuggling Coin misses, save it by replacing it with one random lower-quality uncommitted Smuggling Coin. The replacement keeps the Miss.",
	tags = { "smuggle", "extract", "replace", "miss", "lower_quality" },
	trick = {
		category = "smuggle",
		tier = 1,
		timing = "after_flip_before_score",
		targetRule = "activation_source_to_random_lower_material_smuggling_coin",
	},
	triggers = {
		{ hook = "after_flip_before_score", condition = { match = false }, effects = {
			{ op = "extract_failed_smuggling_coin", target = {
				zone = "dealt_hand",
				filters = {
					{ op = "not_selected" },
					{ op = "not_smuggled" },
					{ op = "real_family", value = "smuggle" },
					{ op = "material_rank_below_current" },
				},
				orderBy = "random",
				pick = { op = "slot_at_position", value = 1 },
			} },
		} },
	},
})

for _, definition in ipairs({
	{
		id = "fake_credentials_ii",
		name = "Fake Credentials II",
		rarity = "uncommon",
		tags = { "counterfeit", "outcome", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "fake_credentials", tier = 2 },
		triggers = {},
	},
	{
		id = "fake_credentials_iii",
		name = "Fake Credentials III",
		rarity = "rare",
		tags = { "counterfeit", "outcome", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "fake_credentials", tier = 3 },
		triggers = {},
	},
	{
		id = "forged_signature",
		name = "Forged Signature",
		rarity = "common",
		tags = { "counterfeit", "activation", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "forged_signature", tier = 1 },
		triggers = {},
	},
	{
		id = "forged_signature_ii",
		name = "Forged Signature II",
		rarity = "uncommon",
		tags = { "counterfeit", "activation", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "forged_signature", tier = 2 },
		triggers = {},
	},
	{
		id = "forged_signature_iii",
		name = "Forged Signature III",
		rarity = "rare",
		tags = { "counterfeit", "activation", "forgery", "neighbor" },
		trick = { category = "forgery", lineId = "forged_signature", tier = 3 },
		triggers = {},
	},
}) do
	table.insert(FAMILY_TRIGGER_NATIVE_DEFINITIONS, definition)
end

for _, definition in ipairs(FAMILY_TRIGGER_NATIVE_DEFINITIONS) do
	table.insert(definitions, definition)
end

-- Family-trigger migration overlay. The original records above remain useful as
-- save IDs and art metadata; this block is the authoritative runtime contract.
local FAMILY_TRIGGER_TEXT = {
	weighted_tail_coating = "On a Tails call, give the activating coin +15% Tails Chance this Flip.",
	heads_varnish = "On a Heads call, give the activating coin +15% Heads Chance this Flip.",
	weighted_palm = "The activating coin has at least 65% chance to match your call. If it matches, its Outcome is worth 1.45x.",
	steady_hand = "Replay 10% of the activating coin's original Outcome.",
	encore = "Replay 20% of the activating coin's original Outcome.",
	curtain_call = "Replay 20% of one random other committed coin's root Outcome.",
	curtain_call_ii = "Replay 30% of up to two different random other committed root Outcomes.",
	impossible_finale = "Replay 20% of the highest-value committed root Outcome.",
	impossible_finale_ii = "Replay 30% of the two highest-value committed root Outcomes.",
	impossible_finale_iii = "Replay 40% of the three highest-value committed root Outcomes.",
	keep_it_rolling = "After the activating coin scores, there is a 50% chance to Replay the next committed coin's original Outcome.",
	follow_through = "Reactivated coins score +25% for each chain depth.",
	ripple = "After the activating coin scores, Replay right with 50% initial and 25% continuation chances, up to three coins.",
	ripple_ii = "After the activating coin scores, there is a 75% chance to Reactivate left, then 50% to continue. Chain depth 3.",
	ripple_iii = "After the activating coin scores, there is a 75% chance to Reactivate each neighbour, then 50% to continue outward.",
	see_behind_the_veil = "When a Prediction Coin is committed, Foretell that activating coin's result.",
	heads_contract = "On Heads, if the activating Foretold coin matches, its Outcome is worth 1.25x.",
	tails_contract = "On Tails, if the activating Foretold coin matches, its Outcome is worth 1.25x.",
	fulfilled_fate = "If the activating Foretold coin fulfills your Call, its root Outcome is worth 2x.",
	hidden_pocket = "Smuggle one random uncommitted Smuggling Coin beside the activating coin, up to one overloaded coin this Flip.",
	hidden_in_plain_sight = "Smuggle one random highest-quality uncommitted Smuggling Coin beside the activating coin, up to two overloaded coins this Flip.",
	off_the_books = "After this activates and at least one coin was smuggled, draw one extra coin after the Flip.",
	planted_double = "After this activates, there is a 50% chance to copy one smuggled coin into a Contraband slot.",
	embarrassment_of_riches = "The first activation arms this Flip: Contraband Outcomes are worth 1.5x.",
	fake_credentials = "If this Forgery Coin misses, copy 50% of the genuine coin immediately to its left's root Outcome.",
	fake_credentials_ii = "If this Forgery Coin misses, copy 75% of the genuine coin immediately to its left's root Outcome.",
	fake_credentials_iii = "If this Forgery Coin misses, copy 100% of the genuine coin immediately to its left's root Outcome.",
	borrowed_name = "Before Flip, rig this Blank to imitate one Tier I Trick from the genuine family immediately to its left.",
	borrowed_name_ii = "Before Flip, rig this Blank to imitate up to two Tier I-II Tricks from the genuine family immediately to its left.",
	borrowed_name_iii = "Before Flip, rig this Blank to imitate up to three Tier I-III Tricks from the genuine family immediately to its left.",
	forged_signature = "Before Flip, rig this Blank to repeat the highest-priority eligible Tier I Trick from the genuine family immediately to its left.",
	forged_signature_ii = "Before Flip, rig this Blank to repeat the highest-priority eligible Tier I-II Trick from the genuine family immediately to its left.",
	forged_signature_iii = "Before Flip, rig this Blank to repeat the highest-priority eligible Tier I-III Trick from the genuine family immediately to its left.",
	switcheroo = "If the activating Sleight coin Matches, switch it with one random higher-value Miss.",
	false_bottom = "Replace the lowest-value matching committed coin with the highest-value uncommitted coin in hand. The replacement keeps the result slot.",
}

local FAMILY_TRIGGER_OVERRIDES = {
	weighted_tail_coating = {
		{ hook = "before_coin_roll", condition = { call = "tails" }, effects = {
			{ op = "add_weight", side = "tails", amount = 0.15 },
		} },
	},
	heads_varnish = {
		{ hook = "before_coin_roll", condition = { call = "heads" }, effects = {
			{ op = "add_weight", side = "heads", amount = 0.15 },
		} },
	},
	weighted_palm = {
		{ hook = "before_coin_roll", effects = {
			{ op = "set_call_match_chance", chance = 0.65, minimum = true },
		} },
		{ hook = "before_coin_score", condition = { match = true }, effects = {
			{ op = "apply_score_scaling", value = 1.45, target = "current_coin_score" },
		} },
	},
	steady_hand = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "activation_source", scale = 0.10 },
		} },
	},
	encore = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "activation_source", scale = 0.20 },
		} },
	},
	curtain_call = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "random_other", count = 1, scale = 0.20 },
		} },
	},
	curtain_call_ii = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "random_other", count = 2, scale = 0.30 },
		} },
	},
	impossible_finale = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "highest_value", count = 1, scale = 0.20 },
		} },
	},
	impossible_finale_ii = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "highest_value", count = 2, scale = 0.30 },
		} },
	},
	impossible_finale_iii = {
		{ hook = "after_all_effects", effects = {
			{ op = "replay_resolution_packet", selectionMode = "highest_value", count = 3, scale = 0.40 },
		} },
	},
	keep_it_rolling = {
		{ hook = "after_coin_score", condition = { match = true }, effects = {
			{ op = "replay_resolution_packet", selectionMode = "directional", direction = "right", count = 1, chance = 0.50, scale = 1 },
		} },
	},
	follow_through = {
		{ hook = "before_coin_score", effects = {
			{ op = "apply_score_scaling", value = 1, chainDepthBonus = 0.25, target = "current_coin_score" },
		} },
	},
	ripple = {
		{ hook = "after_coin_score", condition = { match = true }, effects = {
			{ op = "replay_resolution_packet", selectionMode = "directional", direction = "right", count = 3, chance = 0.50, continuationChance = 0.25, scale = 1 },
		} },
	},
	ripple_ii = {
		{ hook = "after_coin_score", condition = { match = true }, effects = {
			{ op = "reactivate_coin", direction = "left", maxTargets = 3, chance = 0.75, continuationChance = 0.50 },
		} },
	},
	ripple_iii = {
		{ hook = "after_coin_score", condition = { match = true }, effects = {
			{ op = "reactivate_coin", directions = { "left", "right" }, maxTargets = 6, chance = 0.75, continuationChance = 0.50 },
		} },
	},
	see_behind_the_veil = {
		{ hook = "before_coin_roll", effects = {
			{ op = "foretell_coin_result" },
		} },
	},
	heads_contract = {
		{ hook = "before_coin_score", condition = { result = "heads", foretold = true, match = true }, effects = {
			{ op = "apply_score_scaling", value = 1.25, target = "current_coin_score" },
		} },
	},
	tails_contract = {
		{ hook = "before_coin_score", condition = { result = "tails", foretold = true, match = true }, effects = {
			{ op = "apply_score_scaling", value = 1.25, target = "current_coin_score" },
		} },
	},
	fulfilled_fate = {
		{ hook = "before_coin_score", condition = { foretold = true, match = true }, effects = {
			{ op = "apply_score_scaling", value = 2, target = "current_coin_score" },
		} },
	},
	hidden_pocket = {
		{ hook = "after_call_before_flip", effects = {
			{ op = "smuggle_coin_from_hand", target = {
				zone = "dealt_hand",
				filters = {
					{ op = "not_selected" },
					{ op = "not_smuggled" },
					{ op = "real_family", value = "smuggle" },
				},
				orderBy = "random",
				pick = { op = "slot_at_position", value = 1 },
			}, maxOverloadSlots = 1 },
		} },
	},
	hidden_in_plain_sight = {
		{ hook = "after_call_before_flip", effects = {
			{ op = "smuggle_coin_from_hand", target = {
				zone = "dealt_hand",
				filters = {
					{ op = "not_selected" },
					{ op = "not_smuggled" },
					{ op = "real_family", value = "smuggle" },
				},
				materialBand = "highest",
				orderBy = "random",
				pick = { op = "slot_at_position", value = 1 },
			}, maxOverloadSlots = 2 },
		} },
	},
	off_the_books = {
		{ hook = "on_batch_end", condition = { smuggled_this_flip = true }, effects = {
			{ op = "add_next_hand_draws", amount = 1, reason = "off_the_books" },
		} },
	},
	planted_double = {
		{ hook = "after_call_before_flip", effects = {
			{ op = "copy_smuggled_coin", chance = 0.5, maxOverloadSlots = 2 },
		} },
	},
	embarrassment_of_riches = {
		{ hook = "after_call_before_flip", effects = {
			{ op = "set_batch_flag", flag = "contraband_riches" },
		} },
	},
	fake_credentials = {
		{ hook = "after_all_effects", condition = { match = false }, effects = {
			{ op = "copy_outcome", selectionMode = "directional", direction = "left", count = 1,
				scale = 0.50, requireGenuineFamilySource = true },
		} },
	},
	fake_credentials_ii = {
		{ hook = "after_all_effects", condition = { match = false }, effects = {
			{ op = "copy_outcome", selectionMode = "directional", direction = "left", count = 1,
				scale = 0.75, requireGenuineFamilySource = true },
		} },
	},
	fake_credentials_iii = {
		{ hook = "after_all_effects", condition = { match = false }, effects = {
			{ op = "copy_outcome", selectionMode = "directional", direction = "left", count = 1,
				scale = 1.00, requireGenuineFamilySource = true },
		} },
	},
	switcheroo = {
		{ hook = "after_flip_before_score", condition = { match = true }, effects = {
			{ op = "swap_coins", targetMode = "random_higher_miss" },
		} },
	},
	false_bottom = {
		{ hook = "after_flip_before_score", effects = {
			{ op = "replace_coin_from_hand", target = {
				target = {
					zone = "selected_coins",
					filters = { { op = "matched_call" } },
					orderBy = "base_score",
					pick = { op = "slot_at_position", value = 1 },
				},
				replacement = {
					zone = "dealt_hand",
					filters = { { op = "not_selected" }, { op = "not_smuggled" } },
					orderBy = "base_score_desc",
					pick = { op = "slot_at_position", value = 1 },
				},
			} },
		} },
	},
}

local FORGERY_CONFIG = {
	fake_credentials = { lineId = "fake_credentials", tier = 1, rarity = "common", timing = "after_all_effects" },
	fake_credentials_ii = { lineId = "fake_credentials", tier = 2, rarity = "uncommon", timing = "after_all_effects" },
	fake_credentials_iii = { lineId = "fake_credentials", tier = 3, rarity = "rare", timing = "after_all_effects" },
	borrowed_name = { lineId = "borrowed_name", tier = 1, rarity = "common", mode = "borrowed_name", maxTricks = 1 },
	borrowed_name_ii = { lineId = "borrowed_name", tier = 2, rarity = "uncommon", mode = "borrowed_name", maxTricks = 2 },
	borrowed_name_iii = { lineId = "borrowed_name", tier = 3, rarity = "rare", mode = "borrowed_name", maxTricks = 3 },
	forged_signature = { lineId = "forged_signature", tier = 1, rarity = "common", mode = "forged_signature", maxTricks = 1 },
	forged_signature_ii = { lineId = "forged_signature", tier = 2, rarity = "uncommon", mode = "forged_signature", maxTricks = 1 },
	forged_signature_iii = { lineId = "forged_signature", tier = 3, rarity = "rare", mode = "forged_signature", maxTricks = 1 },
}

local HELD_FAMILIES = { fate = true }
local REMOVED_FAMILIES = { extortion = true }
local REMOVED_TRICK_IDS = {
	steady_hand = true,
	see_behind_the_veil = true,
	heads_contract = true,
	tails_contract = true,
	starter_grant = true,
	coupon_case = true,
	insurance_ledger = true,
	rainy_day_fund = true,
	false_bottom = true,
	fall_guy = true,
}

for _, definition in ipairs(definitions) do
	local trick = definition.trick
	if trick then
		local forgery = FORGERY_CONFIG[definition.id]
		if forgery then
			definition.rarity = forgery.rarity
			definition.tags = { "counterfeit", "forgery", "neighbor", forgery.mode and "activation" or "outcome" }
			trick.category = "forgery"
			trick.lineId = forgery.lineId
			trick.tier = forgery.tier
			trick.timing = forgery.timing or "multi_phase"
			trick.targetRule = "genuine_left_neighbor_family"
			trick.forgeryMode = forgery.mode
			trick.forgeryMaxTier = forgery.tier
			trick.forgeryMaxTricks = forgery.maxTricks or 1
			if forgery.mode then
				definition.triggers = {}
				definition.customResolver = "src.content.forgery_resolver"
			else
				definition.customResolver = nil
			end
		end
		trick.activationFamily = trick.activationFamily or trick.category
		trick.activationWindow = trick.activationWindow or trick.timing
		trick.scope = { oncePerActivation = true }
		if FAMILY_TRIGGER_TEXT[definition.id] then
			definition.description = FAMILY_TRIGGER_TEXT[definition.id]
		end
		if FAMILY_TRIGGER_OVERRIDES[definition.id] then
			definition.triggers = FAMILY_TRIGGER_OVERRIDES[definition.id]
		end
		if definition.id == "hidden_pocket" then
			definition.onAcquire = nil
			trick.timing = "after_call_before_flip"
			trick.activationWindow = "after_call_before_flip"
			trick.targetRule = "random_uncommitted_smuggling_coin"
		elseif definition.id == "hidden_in_plain_sight" then
			trick.timing = "after_call_before_flip"
			trick.activationWindow = "after_call_before_flip"
			trick.targetRule = "random_highest_material_uncommitted_smuggling_coin"
		elseif definition.id == "switcheroo" then
			trick.targetRule = "activation_match_to_random_higher_value_miss"
		end
		if HELD_FAMILIES[trick.activationFamily] or REMOVED_FAMILIES[trick.activationFamily] or REMOVED_TRICK_IDS[definition.id]
			or definition.id == "echo_cache" then
			definition.rewardEligible = false
			definition.familyTriggerStatus = (HELD_FAMILIES[trick.activationFamily] or definition.id == "echo_cache") and "held" or "removed"
		else
			definition.familyTriggerStatus = "converted"
		end
	end
end

local byId = {}

for _, definition in ipairs(definitions) do
	byId[definition.id] = definition
end

local Upgrades = {}

local function contains(values, expected)
	for _, value in ipairs(values or {}) do
		if value == expected then
			return true
		end
	end

	return false
end

local function resolveDefinition(definitionOrId)
	if type(definitionOrId) == "string" then
		return byId[definitionOrId]
	end

	return definitionOrId
end

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

function Upgrades.getLineId(definitionOrId)
	local definition = resolveDefinition(definitionOrId)

	if not definition then
		return nil
	end

	return definition.lineId or (definition.trick and definition.trick.lineId) or definition.id
end

function Upgrades.getTier(definitionOrId)
	local definition = resolveDefinition(definitionOrId)
	local tier = definition and ((definition.trick and definition.trick.tier) or definition.tier) or nil

	return tonumber(tier) or 1
end

function Upgrades.findOwnedLine(ownedUpgradeIds, lineId)
	local bestMatch = nil

	for index, ownedId in ipairs(ownedUpgradeIds or {}) do
		local definition = byId[ownedId]

		if definition and Upgrades.getLineId(definition) == lineId then
			local tier = Upgrades.getTier(definition)

			if not bestMatch or tier > bestMatch.tier then
				bestMatch = {
					id = ownedId,
					definition = definition,
					index = index,
					lineId = lineId,
					tier = tier,
				}
			end
		end
	end

	return bestMatch
end

function Upgrades.canGrantUpgrade(ownedUpgradeIds, upgradeId)
	local definition = byId[upgradeId]

	if not definition then
		return false, "unknown_upgrade"
	end

	if contains(ownedUpgradeIds, upgradeId) then
		return false, "upgrade_already_owned"
	end

	local lineId = Upgrades.getLineId(definition)
	local ownedLine = Upgrades.findOwnedLine(ownedUpgradeIds, lineId)

	if ownedLine and ownedLine.tier >= Upgrades.getTier(definition) then
		return false, "trick_line_tier_not_higher"
	end

	return true, definition, ownedLine
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
