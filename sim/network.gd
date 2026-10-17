class_name Network
extends RefCounted
## The Bitcoin network, as an anchored chain (decisions.md 2026-10-16).
##
## Blocks per day and chain height come from history, so halvings and every dated event
## stay on their real dates. The player's hashrate is added to the world's for the
## player's share of those blocks, and for an effective difficulty readout: what the
## 2,016-block rule would set against world plus player hashrate.

const HASHES_PER_TERAHASH: float = 1.0e12

var history: History
var consensus: Consensus


func _init(data: GameData, rules: Consensus) -> void:
	history = data.history
	consensus = rules


## State for a game whose first simulated day is start_index. The player has had no
## influence on the chain yet, so effective difficulty equals history's.
func initial_state(start_index: int) -> SimState.NetworkState:
	var n := SimState.NetworkState.new()
	if start_index == 0:
		return n
	var last: int = start_index - 1
	n.height = history.height_end[last]
	n.historical_difficulty = history.difficulty[last]
	n.effective_difficulty = n.historical_difficulty
	# Fill the current epoch's accumulators with the days since the last retarget.
	var i: int = last
	while i > 0 and not consensus.crosses_retarget(history.height_end[i - 1], history.height_end[i]):
		n.epoch_world_hs_sum += history.hashrate_hs[i]
		n.epoch_days += 1
		i -= 1
	return n


func step(state: SimState, day: int, result: DayResult) -> void:
	var n: SimState.NetworkState = state.network
	var prev_height: int = n.height
	var height: int = history.height_end[day]
	var blocks: int = history.blocks[day]

	n.height = height
	n.blocks_today = blocks
	n.world_hashrate_hs = history.hashrate_hs[day]
	n.player_hashrate_hs = state.player_hashrate_hs
	n.network_hashrate_hs = n.world_hashrate_hs + n.player_hashrate_hs
	n.player_share = n.player_hashrate_hs / n.network_hashrate_hs if n.network_hashrate_hs > 0.0 else 0.0
	n.subsidy_sats_today = consensus.subsidy_sats_for_range(height - blocks + 1, height) if blocks > 0 else 0
	n.fees_sats_today = roundi(history.fees_btc[day] * consensus.sats_per_btc)

	n.epoch_world_hs_sum += n.world_hashrate_hs
	n.epoch_player_hs_sum += n.player_hashrate_hs
	n.epoch_days += 1

	var new_historical: float = history.difficulty[day]
	if consensus.crosses_retarget(prev_height, height):
		_retarget(n, new_historical, result, height)
	n.historical_difficulty = new_historical

	if consensus.halvings_at(height) > consensus.halvings_at(prev_height):
		var halving_height: int = consensus.halvings_at(height) * consensus.halving_interval
		result.add("subsidy_halved", {
			"height": halving_height,
			"subsidy_sats": consensus.subsidy_sats(halving_height),
		})


func _retarget(n: SimState.NetworkState, new_historical: float, result: DayResult, height: int) -> void:
	# The rule sets difficulty in proportion to the epoch's hashrate, so the player's
	# extra hashrate scales history's new difficulty by (world + player) / world.
	var factor: float = 1.0
	if n.epoch_world_hs_sum > 0.0:
		factor = (n.epoch_world_hs_sum + n.epoch_player_hs_sum) / n.epoch_world_hs_sum
	var base: float = new_historical
	if new_historical <= consensus.min_difficulty:
		# History sat on the floor, so the rule's unfloored value was below it. Recover it
		# from the epoch's hashrate, capped at the floor, before scaling by the player.
		var mean_world_hs: float = n.epoch_world_hs_sum / maxi(n.epoch_days, 1)
		base = minf(consensus.difficulty_for_hashrate(mean_world_hs), consensus.min_difficulty)
	var limit: float = consensus.max_retarget_factor
	var previous: float = n.effective_difficulty
	var proposed: float = clampf(base * factor, previous / limit, previous * limit)
	n.effective_difficulty = maxf(consensus.min_difficulty, proposed)
	result.add("difficulty_adjusted", {
		"height": height - height % consensus.retarget_interval,
		"difficulty": n.effective_difficulty,
		"change": n.effective_difficulty / previous - 1.0,
	})
	n.epoch_world_hs_sum = 0.0
	n.epoch_player_hs_sum = 0.0
	n.epoch_days = 0


## Hashprice in sats per TH/s per day: today's block rewards over the network's hashrate.
static func hashprice_sats_per_th_day(n: SimState.NetworkState) -> float:
	if n.network_hashrate_hs <= 0.0:
		return 0.0
	return float(n.subsidy_sats_today + n.fees_sats_today) / (n.network_hashrate_hs / HASHES_PER_TERAHASH)
