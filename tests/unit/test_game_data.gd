extends GutTest

var d: GameData


func before_all() -> void:
	d = GameData.shared()


func test_everything_loads() -> void:
	assert_true(d.is_ok())
	assert_gt(d.events.size(), 0)
	assert_eq(d.hardware.size(), 12)


func test_history_shape() -> void:
	var h := d.history
	assert_eq(h.first_date(), "2009-01-03")
	assert_eq(h.last_date(), "2024-12-31")
	assert_eq(h.size(), 5842)
	assert_eq(h.index_of("2009-01-03"), 0)
	assert_eq(h.index_of("2008-12-31"), -1)
	assert_eq(h.dates[h.index_of("2012-11-28")], "2012-11-28")


func test_no_price_before_first_rate() -> void:
	var h := d.history
	assert_false(h.has_price(h.index_of("2009-10-04")))
	assert_true(h.has_price(h.index_of("2009-10-05")))


func test_history_halving_heights() -> void:
	var h := d.history
	for pair: Array in [["2012-11-28", 210000], ["2016-07-09", 420000], ["2020-05-11", 630000], ["2024-04-20", 840000]]:
		var i: int = h.index_of(pair[0])
		assert_true(h.height_end[i - 1] < pair[1] and h.height_end[i] >= pair[1], "halving on %s" % pair[0])


func test_protocol_values() -> void:
	assert_eq(d.protocol_int("retarget_interval_blocks"), 2016)
	assert_eq(d.protocol_int("initial_subsidy_sats"), 5000000000)


func test_tuning_reads_are_recorded() -> void:
	assert_eq(d.tuning("clock", "seconds_per_day_1x"), 2.0)
	assert_true(d.tuning_reads.has("clock.seconds_per_day_1x"))
	assert_true(d.tuning_keys().has("modes.slashdot"))


func test_every_mode_starts_inside_history() -> void:
	for mode_id: String in ["cypherpunk", "slashdot", "late"]:
		var mode: Dictionary = d.tuning("modes", mode_id)
		assert_ne(d.history.index_of(mode["clock_start"]), -1, mode_id)
	assert_true(d.has_tuning("modes", d.tuning("modes", "default_mode")))


func test_slashdot_mode_has_its_unlock_event() -> void:
	var found: Array = d.events.filter(func(e: Dictionary) -> bool: return e["id"] == "slashdot_v03")
	assert_eq(found.size(), 1)
	assert_eq(found[0]["date"], "2010-07-11")
	assert_true(found[0]["effects"].any(func(fx: Dictionary) -> bool: return fx["type"] == "unlock" and fx.get("feature") == "mining"))
