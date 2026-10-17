extends GutTest
## Every tuning value must be read by something. Values read only outside the sim are
## listed here with the reader.

const READ_ELSEWHERE: Dictionary = {
	"clock.seconds_per_day_1x": "autoload/game_clock.gd",
	"clock.speed_multipliers": "autoload/game_clock.gd",
	"clock.max_days_per_frame": "autoload/game_clock.gd",
	"clock.pause_on_difficulty_adjustment": "presentation (M3)",
	"hardware.footprint_tiles": "facility view (M3)",
}


func test_every_tuning_value_is_read() -> void:
	var data := GameData.shared()
	for mode_id: String in ["", "cypherpunk", "slashdot", "late"]:
		Sim.new_game(data, mode_id, 1)
	var unread: PackedStringArray = []
	for key: String in data.tuning_keys():
		if not data.tuning_reads.has(key) and not READ_ELSEWHERE.has(key):
			unread.append(key)
	assert_eq(unread, PackedStringArray(), "tuning values nothing reads")
