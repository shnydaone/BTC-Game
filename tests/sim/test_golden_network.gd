extends GutTest
## Golden test for the anchored chain: with no player hashrate, the sim must reproduce
## history's difficulty, halvings and hashprice across the whole dataset.

const WINDOW_DAYS: int = 30
const HASHPRICE_TOLERANCE: float = 0.001  # anchored chain: 0.1% on 30-day means
const HALVINGS: Dictionary = {"2012-11-28": 210000, "2016-07-09": 420000, "2020-05-11": 630000, "2024-04-20": 840000}
const SATS: float = 1.0e8

var data: GameData
var rows: Array[Dictionary] = []
var halvings: Dictionary = {}
var adjustments: int = 0


func before_all() -> void:
	data = GameData.shared()
	var sim := Sim.new_game(data, "cypherpunk", 1)
	sim.state.hashrate_override_hs = 0.0
	while not sim.is_finished():
		var r := sim.step_day()
		var n := sim.state.network
		rows.append({
			"effective": n.effective_difficulty,
			"historical": n.historical_difficulty,
			"hashprice": Network.hashprice_sats_per_th_day(n),
		})
		for e: Dictionary in r.of_type("subsidy_halved"):
			halvings[r.date] = e["height"]
		adjustments += r.of_type("difficulty_adjusted").size()


func test_runs_the_whole_dataset() -> void:
	assert_eq(rows.size(), data.history.size())


func test_effective_difficulty_equals_history_every_day() -> void:
	var worst: float = 0.0
	for row: Dictionary in rows:
		worst = maxf(worst, absf(row["effective"] / row["historical"] - 1.0))
	assert_lt(worst, 1e-9, "largest relative gap %s" % worst)


func test_halvings_land_on_real_dates() -> void:
	assert_eq(halvings, HALVINGS)


func test_retarget_count_matches_height() -> void:
	var top: int = data.history.height_end[data.history.size() - 1]
	assert_eq(adjustments, top / 2016)


func test_hashprice_matches_dataset_on_30_day_means() -> void:
	# The dataset's own figure: claimed subsidy plus fees over estimated hashrate.
	var h := data.history
	var failures: Array[String] = []
	var start: int = 0
	while start + WINDOW_DAYS <= rows.size():
		var sim_sum: float = 0.0
		var real_sum: float = 0.0
		for i: int in range(start, start + WINDOW_DAYS):
			sim_sum += rows[i]["hashprice"]
			if h.hashrate_hs[i] > 0.0:
				real_sum += (h.subsidy_btc[i] + h.fees_btc[i]) * SATS / (h.hashrate_hs[i] / Network.HASHES_PER_TERAHASH)
		var gap: float = absf(sim_sum / real_sum - 1.0)
		if gap > HASHPRICE_TOLERANCE:
			failures.append("%s: %.5f" % [h.dates[start], gap])
		start += WINDOW_DAYS
	assert_eq(failures, [] as Array[String], "30-day windows over tolerance")
