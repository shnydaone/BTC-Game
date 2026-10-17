class_name Mining
extends RefCounted
## The player's mining rewards (GDD 7.1). The player's share of today's historical blocks:
## solo mining draws the blocks found from a Poisson distribution, pool mining pays the
## expected value daily less the pool fee.

var pool_fee: float
var default_mode: String


func _init(data: GameData) -> void:
	pool_fee = float(data.tuning("mining", "pool_fee"))
	default_mode = data.tuning("mining", "default_mode")


func set_mode(sim: Sim, mode: String) -> String:
	if mode == "pool" and not sim.state.events.features.has("pool_mining"):
		return "no pools exist yet"
	if mode != "pool" and mode != "solo":
		return "mode must be solo or pool"
	sim.state.mining.mode = mode
	return ""


func step(sim: Sim, day: int, result: DayResult) -> void:
	var m: SimState.MiningState = sim.state.mining
	var n: SimState.NetworkState = sim.state.network
	m.mined_sats_today = 0
	m.mined_value_cents_today = 0
	if not sim.state.events.features.has("mining") or n.blocks_today == 0 or n.player_share <= 0.0:
		return
	var reward_per_block: float = float(n.subsidy_sats_today + n.fees_sats_today) / n.blocks_today
	var expected_blocks: float = n.player_share * n.blocks_today
	var sats: int = 0
	if m.mode == "pool":
		var exact: float = expected_blocks * reward_per_block * (1.0 - pool_fee) + m.remainder_sats
		sats = floori(exact)
		m.remainder_sats = exact - sats
	else:
		var found: int = sim.rng.poisson("mining", expected_blocks)
		if found > 0:
			sats = roundi(found * reward_per_block)
			m.blocks_found += found
			result.add("block_found", {"count": found, "sats": sats})
	m.mined_sats_today = sats
	m.mined_value_cents_today = Finance.sats_to_cents(sats, sim.data.history.price_usd[day], sim.consensus.sats_per_btc)
	sim.custody.deposit_mined(sim, sats)
	Ledger.post(sim.state, "mining_revenue", m.mined_value_cents_today)
