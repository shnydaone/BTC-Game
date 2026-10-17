class_name Consensus
extends RefCounted
## Bitcoin consensus rules the sim needs: block subsidy and the difficulty retarget.
## Constants come from data/protocol/consensus.json.

var halving_interval: int
var initial_subsidy_sats: int
var subsidy_shift_limit: int
var sats_per_btc: int
var retarget_interval: int
var target_block_seconds: int
var max_retarget_factor: float
var min_difficulty: float
var hashes_per_difficulty_1: float


func _init(data: GameData) -> void:
	halving_interval = data.protocol_int("halving_interval_blocks")
	initial_subsidy_sats = data.protocol_int("initial_subsidy_sats")
	subsidy_shift_limit = data.protocol_int("subsidy_shift_limit")
	sats_per_btc = data.protocol_int("sats_per_btc")
	retarget_interval = data.protocol_int("retarget_interval_blocks")
	target_block_seconds = data.protocol_int("target_block_seconds")
	max_retarget_factor = data.protocol_float("max_retarget_factor")
	min_difficulty = data.protocol_float("min_difficulty")
	hashes_per_difficulty_1 = data.protocol_float("hashes_per_difficulty_1")


func halvings_at(height: int) -> int:
	return height / halving_interval


## GetBlockSubsidy: the initial subsidy shifted right once per halving, zero past the limit.
func subsidy_sats(height: int) -> int:
	var halvings: int = halvings_at(height)
	if halvings >= subsidy_shift_limit:
		return 0
	return initial_subsidy_sats >> halvings


## Total subsidy for blocks first_height..last_height inclusive, across halving boundaries.
func subsidy_sats_for_range(first_height: int, last_height: int) -> int:
	var total: int = 0
	var h: int = first_height
	while h <= last_height:
		var era_end: int = mini(last_height, (halvings_at(h) + 1) * halving_interval - 1)
		total += subsidy_sats(h) * (era_end - h + 1)
		h = era_end + 1
	return total


## True when a block at a height in (prev_height, new_height] starts a new difficulty epoch.
func crosses_retarget(prev_height: int, new_height: int) -> bool:
	return new_height > prev_height and new_height / retarget_interval > prev_height / retarget_interval


## CalculateNextWorkRequired: scale by target over actual timespan, with the timespan
## clamped to a quarter and four times the target, and never below minimum difficulty.
func retarget(prev_difficulty: float, actual_seconds: float) -> float:
	var target: float = float(retarget_interval * target_block_seconds)
	var clamped: float = clampf(actual_seconds, target / max_retarget_factor, target * max_retarget_factor)
	return maxf(min_difficulty, prev_difficulty * target / clamped)


## Difficulty at which this hashrate finds one block per target spacing on average.
func difficulty_for_hashrate(hashrate_hs: float) -> float:
	return hashrate_hs * target_block_seconds / hashes_per_difficulty_1


func hashrate_for_difficulty(d: float) -> float:
	return d * hashes_per_difficulty_1 / target_block_seconds
