extends GutTest
## Golden test, external half: the sim's hashprice against published third-party figures
## (data/history/hashprice_references.csv). Zero player hashrate, so this checks the
## anchored chain, subsidy schedule, fees and price join against the outside world.

const REFERENCES: String = "res://data/history/hashprice_references.csv"
const TOLERANCE: float = 0.15
const HASHES_PER_TERAHASH: float = 1.0e12

var hashprice: Dictionary = {}  # ISO date -> USD per TH/s per day
var data: GameData


func before_all() -> void:
	data = GameData.shared()
	var sim := Sim.new_game(data, "cypherpunk", 1)
	sim.state.hashrate_override_hs = 0.0
	sim.state.day_index = data.history.index_of("2020-01-01")
	sim.state.network = sim.network.initial_state(sim.state.day_index)
	while sim.current_date() <= "2024-05-31":
		var day: int = sim.state.day_index
		sim.step_day()
		var sats_per_th: float = Network.hashprice_sats_per_th_day(sim.state.network)
		hashprice[data.history.dates[day]] = sats_per_th / sim.consensus.sats_per_btc * data.history.price_usd[day]


func _references() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(REFERENCES, FileAccess.READ)
	var header: PackedStringArray = f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < header.size():
			continue
		var ref: Dictionary = {}
		for i: int in header.size():
			ref[header[i]] = row[i]
		out.append(ref)
	return out


func test_references_are_sourced() -> void:
	var refs := _references()
	assert_gte(refs.size(), 5)
	for ref: Dictionary in refs:
		assert_true(String(ref["url"]).begins_with("https://"), ref["date"])
		assert_ne(String(ref["publisher"]), "", ref["date"])


func test_sim_hashprice_matches_published_figures() -> void:
	for ref: Dictionary in _references():
		var date: String = ref["date"]
		var window: int = String(ref["window_days"]).to_int()
		var end: int = data.history.index_of(date)
		var total: float = 0.0
		for i: int in range(end - window + 1, end + 1):
			total += hashprice[data.history.dates[i]]
		var sim_value: float = total / window
		var published: float = String(ref["usd_per_th_day"]).to_float()
		assert_almost_eq(sim_value / published, 1.0, TOLERANCE, "%s (%s): sim $%.4f vs published $%.4f" % [date, ref["publisher"], sim_value, published])
