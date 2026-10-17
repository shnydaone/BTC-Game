extends GutTest

const SAVE_SCRIPT: GDScript = preload("res://autoload/save.gd")

var data: GameData


func before_all() -> void:
	data = GameData.shared()


func _run(sim: Sim, days: int) -> void:
	for i: int in days:
		# A varying player hashrate exercises the epoch accumulators.
		sim.state.player_hashrate_hs = 1.0e6 * (1 + sim.state.day_index % 7)
		sim.rng.uniform("test")
		sim.step_day()


func test_save_and_load_continues_identically() -> void:
	var straight := Sim.new_game(data, "cypherpunk", 2024)
	_run(straight, 1000)

	var first := Sim.new_game(data, "cypherpunk", 2024)
	_run(first, 500)
	var resumed: Sim = SAVE_SCRIPT.from_json(SAVE_SCRIPT.to_json(first))
	assert_not_null(resumed)
	_run(resumed, 500)

	assert_eq(SAVE_SCRIPT.to_json(resumed), SAVE_SCRIPT.to_json(straight))


func test_step_day_reports_the_simulated_date() -> void:
	var sim := Sim.new_game(data, "slashdot", 1)
	var r := sim.step_day()
	assert_eq(r.date, "2009-01-03")
	assert_eq(sim.current_date(), "2009-01-04")


func test_sim_stops_at_the_end_of_history() -> void:
	var sim := Sim.new_game(data, "late", 1)
	sim.state.day_index = data.history.size() - 1
	assert_not_null(sim.step_day())
	assert_true(sim.is_finished())
