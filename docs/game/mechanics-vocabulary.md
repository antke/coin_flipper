# Mechanics Vocabulary

Coins and Tricks must use the same mechanical language so future combinations stay predictable.

Use this document when adding entries to `coin.md`, `trick.md` or technical content files.

## Core Objects

| Term | Meaning |
| --- | --- |
| `coin_definition` | base coin type, such as Weighted Coin |
| `coin_instance` | one owned copy of a coin in the run pouch |
| `material` | coin variant layer: Copper, Silver, Gold |
| `archetype` | main mechanical identity: Bent, Blank, Hollow, Marked, Lucky, Weighted |
| `trick_definition` | base Trick rules entry |
| `trick_instance` | run-owned Trick, including tier and state |
| `source` | object that caused an effect |
| `target` | object selected by an effect |
| `call` | player choice: Heads or Tails |
| `weight` | pre-flip probability bias toward a side or call before a result exists |
| `foretold_result` | future coin result revealed on a dealt coin before selection |
| `foretold_coin` | dealt coin whose future result is visible before selection |
| `ancient_pattern` | visible H/T result pattern contract checked against selected foretold coins |
| `coin_position` | current place of a coin body in the selected left-to-right layout |
| `result_slot` | resolved Heads/Tails outcome attached to a selected slot |
| `moved_layout` | selected layout after coin bodies have been physically swapped, moved or substituted |
| `identity_source` | coin whose archetype, tags, material, payout or trigger identity can be forged |
| `forged_identity` | temporary fake identity overlay used for requirement, payout or trigger checks |
| `forged_payout` | payout calculated by pretending a target used another coin's scoring identity |
| `forged_trigger` | bounded trigger copy fired as if the target had another coin's trigger identity |
| `decoy_coin` | coin flagged as the preferred wrong target for hostile or automatic effects |
| `spotlight_coin` | coin chosen to receive redirected score credit |
| `redirected_credit` | score or payout credit booked to a different recipient than the coin that created it |
| `redirected_target` | target chosen after Misdirection reroutes an intended target to a Decoy |
| `hand_coin` | owned coin instance currently in the dealt hand but not necessarily selected for the legal flip |
| `board_coin` | coin body currently on the flip board and eligible to flip or resolve |
| `smuggled_coin` | real hand coin forced onto the board beyond the normal selected slots |
| `overload_slot` | illegal extra board slot created by Smuggling beyond the normal flip-slot limit |
| `overloaded_board` | board state with more coin bodies than the normal selected-slot limit |
| `contraband_copy` | temporary physical board copy created by Smuggling multiplication; it is removed after the flip and does not become another owned pouch coin |
| `luck_meter` | run or stage meter that fills from Luck gain and enables the next Fated Flip when full |
| `luck_gain` | amount of progress being added to the Luck Meter |
| `fountain_favor` | persistent bonus Luck gain created by sacrificing coins at the Fountain |
| `fated_flip` | meter-backed global state where the next flip is blessed by fate |
| `fated_flip_payoff` | reward granted because the current flip is a Fated Flip |
| `resolution_packet` | recorded score, effects, affected targets and emitted bonuses produced by one coin resolution |
| `prestige_replay` | discounted replay of a completed resolution packet |
| `chained_coin` | coin triggered by another coin rather than by the original flip resolution |
| `chain_source` | coin that started or currently emits a Chain link |
| `chain_link` | one live trigger from a source coin into another coin |
| `chain_depth` | distance from the original Chain source; first triggered coin is depth 1, the next is depth 2 |
| `result` | actual coin outcome: Heads or Tails |
| `success` | result matches call after all current modifications |
| `failure` | result does not match call after all current modifications |
| `natural_result` | original flip result before modification |
| `final_result` | result after conversion, rerolls and other result changes |

## Timing Windows

| Timing | Use |
| --- | --- |
| `encounter_start` | enemy and encounter rules are created |
| `deal_coins` | coins are dealt from pouch into the current selection |
| `after_deal_before_selection` | dealt coins exist and Prediction? Tricks can reveal foretold results before player selection |
| `select_coins` | player chooses coins to flip |
| `arrange_coins` | selected coins can be reordered |
| `after_call_before_flip` | player has called Heads/Tails and Smuggling Tricks can force extra hand coins onto the board before results exist |
| `condition_check` | requirements, tags, archetypes, materials and pattern credentials are checked |
| `target_selection` | automatic or enemy target rules choose a target, allowing Decoy reroutes |
| `luck_gain` | Luck Meter progress is about to be added or has just been added |
| `luck_meter_full` | Luck Meter reaches its threshold and prepares a Fated Flip |
| `before_flip` | odds can be modified before results exist |
| `flip` | coin results are generated |
| `during_fated_flip` | the current flip is consuming a Fated Flip |
| `after_flip_before_score` | pre-score Tricks can inspect resolved slots and move coin bodies before scoring |
| `before_coin_score` | individual coin score is about to be calculated |
| `after_coin_score` | individual coin score has been calculated |
| `after_trigger` | a coin or Trick effect has just triggered and Chain can inspect live propagation |
| `chain_step` | one Chain link is being rolled, selected or resolved |
| `before_score` | final score total is about to be calculated |
| `after_score` | score has been calculated and applied |
| `refill_hand` | used hand/board coins are replaced from the pouch according to refill rules |
| `after_all_effects` | late cleanup, delayed effects, moved-layout rescores, Prestige packet replays and final retriggers |
| `encounter_end` | reward and failure flow |

## Action Terms

| Action | Meaning |
| --- | --- |
| `modify_call_chance` | change chance that a coin matches the player's call |
| `set_call_match_chance` | set exact chance that a coin matches the player's call |
| `add_weight` | add or increase pre-flip probability bias toward a side or call |
| `foretell_coin_result` | reveal and store a dealt coin's future result before selection |
| `check_ancient_pattern` | compare selected foretold results against a visible H/T pattern |
| `convert_coin_result` | change a coin result without rerolling |
| `reroll_coin` | generate a new result for an already flipped coin |
| `resolve_coin` | run one coin through result and scoring resolution |
| `retrigger_coin` | resolve the same coin again from a defined timing point |
| `rescore_moved_layout` | score the same resolved result slots again after Sleight moved coin bodies |
| `copy_coin` | legacy/generic copy term; prefer `create_contraband_copy` for Smuggling physical copies and `forge_identity` for Forgery identity copies |
| `forge_identity` | make a target count as an identity source for a defined check, payout or trigger |
| `replace_forged_identity` | use a forged identity instead of the target's real identity for one defined check |
| `add_forged_identity` | add a forged tag, archetype, material or identity while keeping the target's real identity |
| `copy_payout` | apply a source coin's payout logic to a target without changing the target's result |
| `copy_trigger_once` | fire one source trigger from a target with explicit source tracking and caps |
| `mark_decoy` | flag a coin as the Decoy for eligible target rerouting |
| `mark_spotlight` | flag a coin as the receiver for redirected score credit |
| `redirect_effect_target` | reroute an eligible hostile or automatic target to a Decoy |
| `redirect_score_credit` | book a successful scoring action onto a Spotlight instead of its original coin |
| `smuggle_coin_from_hand` | move a real unselected hand coin onto an overload slot on the board |
| `create_overload_slot` | create one illegal extra board slot for a smuggled or contraband coin |
| `mark_smuggled_coin` | flag a board coin as having entered through Smuggling this flip |
| `multiply_board_coin` | create one or more temporary physical board copies of a smuggled coin |
| `create_contraband_copy` | create a temporary board body copied from an owned coin; the copy resolves this flip only |
| `increase_refill_count` | raise the number of coins drawn/refilled into hand after the flip |
| `check_board_overload` | compare board coin count against the normal selected-slot limit |
| `clear_temporary_copies` | remove contraband copies after resolution while leaving the original owned coin as a single pouch/hand instance |
| `add_luck` | add progress to the Luck Meter |
| `multiply_luck_gain` | multiply a Luck gain event without changing coin results or odds |
| `boost_fountain_favor_luck` | increase the Luck generated by Fountain Favor |
| `add_fated_flip_payoff` | grant score, Influence or another reward because this flip is Fated |
| `retrigger_fated_flip_resolution` | resolve the whole Fated Flip payoff layer again without targeting individual coins |
| `allow_fated_luck_generation` | permit positive Luck gain during a Fated Flip |
| `chain_fated_flip` | keep or refill the Luck Meter so another Fated Flip can follow |
| `record_resolution_packet` | store the score, effects and affected targets produced by one coin resolution |
| `replay_resolution_packet` | replay a recorded packet as Prestige without rerolling or selecting new targets |
| `scale_replayed_packet` | apply a reduced value, usually 20%, to every output in a Prestige replay |
| `mark_prestige_replay` | flag replayed outputs so they cannot recursively trigger Prestige |
| `trigger_random_neighbor` | trigger one eligible neighbouring coin as the next Chain link |
| `mark_chained_coin` | flag a coin as Chained and assign its chain source and depth |
| `continue_chain` | roll or resolve the next Chain link if chance and depth limits allow it |
| `multiply_chained_score` | multiply score generated by a coin because it is Chained |
| `create_temp_coin` | create a coin only for the current resolution/encounter; prefer `create_contraband_copy` for Smuggling multiplication |
| `add_coin_to_resolution` | insert a coin into the current scoring sequence |
| `move_coin` | move one coin body from one selected position to another |
| `replace_coin` | substitute one coin body or selected entry for another, preserving the result slot when specified |
| `swap_coins` | exchange positions of two coin bodies, preserving resolved result slots when specified |
| `redirect_score` | legacy alias for `redirect_score_credit`; prefer the newer term in Misdirection entries |
| `redirect_penalty` | reroute an explicit penalty to an eligible Decoy without changing coin results |
| `add_score` | add score to the current score pool |
| `multiply_score` | multiply score using an explicit source and scope |
| `add_influence` | grant run currency |
| `set_flag` | mark state for later requirements or actions |
| `satisfy_requirement` | allow an object to count as meeting a requirement |

## Requirement Terms

| Requirement | Meaning |
| --- | --- |
| `requires_archetype` | needs a coin archetype |
| `requires_material` | needs a coin material |
| `requires_tag` | needs a tag on coin, Trick or effect |
| `requires_selected_coin` | needs at least one coin selected for the current flip |
| `requires_foretold_coin` | needs a selected or dealt coin with a visible foretold result |
| `requires_ancient_pattern` | needs selected foretold results that can be checked against a pattern |
| `requires_result_slot` | needs at least one resolved result slot |
| `requires_unselected_dealt_coin` | needs a dealt coin that was not chosen for the current flip |
| `requires_moved_layout` | needs a layout changed by a swap, move or substitution |
| `requires_identity_source` | needs a coin that can provide a forged identity, payout or trigger template |
| `requires_forged_identity` | needs a coin currently carrying a forged identity overlay |
| `requires_template_coin` | needs a positional template coin, usually slot 1 or the last slot |
| `requires_decoy` | needs a coin flagged as a Decoy or eligible to become one |
| `requires_spotlight` | needs a coin flagged as a Spotlight or eligible to receive redirected credit |
| `requires_hostile_target` | needs an enemy or automatic effect currently choosing a player coin target |
| `requires_score_credit` | needs a successful scoring action that can be reassigned |
| `requires_hand_coin` | needs a real coin currently in the dealt hand |
| `requires_unselected_hand_coin` | needs a real hand coin not already occupying a legal selected slot |
| `requires_smuggled_coin` | needs a coin that entered the board through Smuggling this flip |
| `requires_overloaded_board` | needs board coin count above the normal selected-slot limit |
| `requires_contraband_copy` | needs at least one temporary Smuggling-created board copy |
| `requires_refill_rule` | needs the hand refill step to be active or configurable |
| `requires_luck_meter` | needs the Luck Meter to exist |
| `requires_luck_gain` | needs a Luck gain event to modify |
| `requires_fountain_favor` | needs positive Fountain Favor or a Fountain Favor Luck gain |
| `requires_fated_flip` | needs the current or next flip to be a Fated Flip |
| `requires_luck_meter_full` | needs the Luck Meter to be full or to have just filled |
| `requires_resolution_packet` | needs a completed recorded resolution packet to replay |
| `requires_prestige_replay` | needs the current event to be a Prestige replay |
| `requires_chained_coin` | needs a coin that was triggered by another coin |
| `requires_chain_source` | needs a coin that can start or continue a Chain |
| `requires_chain_depth` | needs a minimum Chain depth, such as depth 2 for the third coin in a chain |
| `requires_success` | needs at least one successful coin |
| `requires_failure` | needs at least one failed coin |
| `success_count` | number of successful coins |
| `failure_count` | number of failed coins |
| `exactly_one_failure` | exactly one coin failed |
| `all_success` | all flipped coins succeeded |
| `no_success` | no flipped coins succeeded |
| `natural_success` | success before result modification |
| `final_success` | success after result modification |
| `adjacent_to_source` | target is next to the source coin |
| `left_of_source` | target is left of the source coin |
| `right_of_source` | target is right of the source coin |

## Target Rules

Every automatic Trick must define deterministic targeting.

Preferred target vocabulary:

- `leftmost`
- `rightmost`
- `slot_1`
- `last_slot`
- `highest_score`
- `lowest_score`
- `highest_base_score`
- `lowest_base_score`
- `first_success`
- `first_failure`
- `strongest_coin`
- `weakest_coin`
- `decoy`
- `spotlight`
- `intended_target`
- `redirect_target`
- `unselected_hand_coin`
- `overload_slot`
- `smuggled_coin`
- `contraband_copy`
- `luck_meter`
- `fated_flip`
- `resolution_packet`
- `replay_source`
- `chained_coin`
- `chain_source`
- `random_neighbor`
- `matching_archetype`
- `matching_material`
- `matching_tag`

Tie-breakers must be explicit. Default tie-breaker is `leftmost`.

Random targeting is allowed only when the effect explicitly says `random_target` or `random_neighbor` and uses deterministic run RNG.

## Scope and Limits

Use these terms to describe how often an effect can happen.

| Constraint | Meaning |
| --- | --- |
| `once_per_flip` | one time per player flip/selection |
| `once_per_deal` | one time per dealt hand before selection |
| `once_per_coin` | one time for each target coin |
| `once_per_source` | one time for each source object |
| `once_per_encounter` | one time per enemy encounter |
| `once_per_run` | one time per run |
| `max_triggers` | hard trigger count cap |
| `max_depth` | hard recursion/dependency depth cap |
| `no_self_trigger` | effect cannot trigger itself |
| `generated_only` | applies only to created/temp/copied coins |
| `natural_only` | checks pre-modification result/state |
| `final_only` | checks post-modification result/state |
| `one_payout_only` | copied or forged payout applies to only one payout calculation |
| `one_trigger_only` | copied or forged trigger fires only once |
| `no_recursive_copy` | copied payouts/triggers cannot copy themselves or copied history |
| `one_redirect_only` | Misdirection reroutes only one target or score-credit event |
| `no_recursive_redirect` | redirected credit cannot create another redirected credit loop |
| `no_redirected_retrigger` | redirected score credit does not retrigger the receiver unless explicitly allowed |
| `temporary_copy` | generated copy exists only for the current flip/resolution |
| `no_recursive_multiplication` | temporary copies cannot create more temporary copies unless a Trick explicitly allows it |
| `max_board_coins` | hard cap on total board coin bodies after Smuggling overload |
| `original_only_returns_to_pouch` | after multiplication, only the original owned coin persists in hand/pouch state |
| `once_per_fated_flip` | one time for each Fated Flip |
| `meter_only` | effect changes only Luck Meter or Fated Flip state, not coins or results |
| `no_individual_coin_targeting` | effect cannot choose or alter one coin as its target |
| `no_fated_result_change` | Fate Trick does not change individual coin results beyond the base Fated Flip system |
| `once_per_prestige` | one Prestige replay per eligible source or flip, as specified |
| `packet_replay_only` | Prestige replays the recorded packet and does not recalculate the world |
| `replay_at_20_percent` | Prestige replay output defaults to 20% of the original packet output |
| `no_recursive_prestige` | Prestige replay cannot trigger another Prestige replay |
| `no_new_targets_on_replay` | replayed packet uses original affected targets and does not choose new ones |
| `no_live_chain_from_replay` | replayed packet does not start fresh Chain propagation unless a Chain Trick explicitly allows it |
| `chain_chance` | chance that a Chain link triggers another coin, such as 50% |
| `max_chain_depth` | hard limit on how far Chain propagation can continue |
| `no_chain_reentry` | a coin already used in the current Chain cannot be triggered again by the same Chain |

Explosive combos are allowed, but every recursive, copy-like, replay, Chain or board-overload effect needs explicit scope and limits so the engine can resolve it deterministically.

## Coin Definition Requirements

Every coin should define:

- `name`
- `archetype`
- `tags`
- `base_score`
- `material_variants`
- `mechanic_terms`
- `trick_synergy`

Base coin identity does not include material. Material is a variant layer.

Copper is the baseline material and supplies baseline values.

## Trick Definition Requirements

Every Trick should define:

- `name`
- `category`
- `tags`
- `tier`
- `timing`
- `requirements`
- `target_rule`
- `actions`
- `scope_limits`
- `synergy`

If a Trick cannot be written with this vocabulary, add the missing term here before implementing the Trick.
