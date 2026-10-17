class_name SimState
extends RefCounted
## All mutable simulation state. Systems read and write it; save/load serializes it.
##
## to_dict() output is JSON-safe: ints that can exceed 2^53 are stored as strings, and the
## loader casts every number back to its type because JSON parses all numbers as floats.

const SCHEMA_VERSION: int = 1

var mode_id: String = ""
var day_index: int = 0  # the next day step_day() will simulate
var player_hashrate_hs: float = 0.0  # set by the hardware system each day (M2 PR 2)
var network: NetworkState = NetworkState.new()


class NetworkState:
	extends RefCounted
	## Anchored chain: height and blocks come from history (decisions.md 2026-10-16).

	var height: int = 0  # chain height at the end of the last simulated day
	var blocks_today: int = 0
	var world_hashrate_hs: float = 0.0
	var player_hashrate_hs: float = 0.0
	var network_hashrate_hs: float = 0.0
	var player_share: float = 0.0
	var subsidy_sats_today: int = 0
	var fees_sats_today: int = 0
	var historical_difficulty: float = 1.0
	## The difficulty the real rule would set against world plus player hashrate. A readout:
	## block counts stay historical, so it does not change rewards.
	var effective_difficulty: float = 1.0
	var epoch_world_hs_sum: float = 0.0
	var epoch_player_hs_sum: float = 0.0
	var epoch_days: int = 0

	func to_dict() -> Dictionary:
		return {
			"height": height,
			"blocks_today": blocks_today,
			"world_hashrate_hs": world_hashrate_hs,
			"player_hashrate_hs": player_hashrate_hs,
			"network_hashrate_hs": network_hashrate_hs,
			"player_share": player_share,
			"subsidy_sats_today": subsidy_sats_today,
			"fees_sats_today": fees_sats_today,
			"historical_difficulty": historical_difficulty,
			"effective_difficulty": effective_difficulty,
			"epoch_world_hs_sum": epoch_world_hs_sum,
			"epoch_player_hs_sum": epoch_player_hs_sum,
			"epoch_days": epoch_days,
		}

	static func from_dict(d: Dictionary) -> NetworkState:
		var n := NetworkState.new()
		n.height = int(d["height"])
		n.blocks_today = int(d["blocks_today"])
		n.world_hashrate_hs = float(d["world_hashrate_hs"])
		n.player_hashrate_hs = float(d["player_hashrate_hs"])
		n.network_hashrate_hs = float(d["network_hashrate_hs"])
		n.player_share = float(d["player_share"])
		n.subsidy_sats_today = int(d["subsidy_sats_today"])
		n.fees_sats_today = int(d["fees_sats_today"])
		n.historical_difficulty = float(d["historical_difficulty"])
		n.effective_difficulty = float(d["effective_difficulty"])
		n.epoch_world_hs_sum = float(d["epoch_world_hs_sum"])
		n.epoch_player_hs_sum = float(d["epoch_player_hs_sum"])
		n.epoch_days = int(d["epoch_days"])
		return n


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"mode_id": mode_id,
		"day_index": day_index,
		"player_hashrate_hs": player_hashrate_hs,
		"network": network.to_dict(),
	}


static func from_dict(d: Dictionary) -> SimState:
	if int(d["schema_version"]) != SCHEMA_VERSION:
		push_error("SimState: save schema %s, expected %d" % [d["schema_version"], SCHEMA_VERSION])
		return null
	var s := SimState.new()
	s.mode_id = String(d["mode_id"])
	s.day_index = int(d["day_index"])
	s.player_hashrate_hs = float(d["player_hashrate_hs"])
	s.network = NetworkState.from_dict(d["network"])
	return s
