extends GutTest

const SATS: int = 100000000
const TWO_WEEKS: float = 14.0 * 86400.0

var c: Consensus


func before_all() -> void:
	c = Consensus.new(GameData.shared())


func test_subsidy_schedule() -> void:
	assert_eq(c.subsidy_sats(0), 50 * SATS)
	assert_eq(c.subsidy_sats(209999), 50 * SATS)
	assert_eq(c.subsidy_sats(210000), 25 * SATS)
	assert_eq(c.subsidy_sats(420000), 1250000000)
	assert_eq(c.subsidy_sats(630000), 625000000)
	assert_eq(c.subsidy_sats(840000), 312500000)
	assert_eq(c.subsidy_sats(1050000), 156250000)


func test_subsidy_reaches_zero() -> void:
	assert_eq(c.subsidy_sats(33 * 210000), 0, "5,000,000,000 >> 33 is 0")
	assert_eq(c.subsidy_sats(32 * 210000), 1, "the last single-sat era")
	assert_eq(c.subsidy_sats(64 * 210000), 0, "shift limit")


func test_subsidy_for_range_spans_a_halving() -> void:
	assert_eq(c.subsidy_sats_for_range(209998, 210001), 2 * 50 * SATS + 2 * 25 * SATS)
	assert_eq(c.subsidy_sats_for_range(5, 5), 50 * SATS)


func test_crosses_retarget() -> void:
	assert_false(c.crosses_retarget(0, 0))
	assert_false(c.crosses_retarget(0, 2015))
	assert_true(c.crosses_retarget(2015, 2016))
	assert_true(c.crosses_retarget(2000, 2100))
	assert_false(c.crosses_retarget(2016, 4031))


func test_retarget_follows_timespan() -> void:
	assert_almost_eq(c.retarget(100.0, TWO_WEEKS), 100.0, 1e-9)
	assert_almost_eq(c.retarget(100.0, TWO_WEEKS / 2.0), 200.0, 1e-9)
	assert_almost_eq(c.retarget(100.0, TWO_WEEKS * 2.0), 50.0, 1e-9)


func test_retarget_clamps_at_four_x() -> void:
	assert_almost_eq(c.retarget(100.0, TWO_WEEKS / 10.0), 400.0, 1e-9)
	assert_almost_eq(c.retarget(100.0, TWO_WEEKS * 10.0), 25.0, 1e-9)


func test_retarget_never_below_minimum() -> void:
	assert_eq(c.retarget(1.0, TWO_WEEKS * 3.0), 1.0)


func test_difficulty_one_is_about_seven_megahash() -> void:
	assert_almost_eq(c.hashrate_for_difficulty(1.0), 7158278.8, 0.1)
	assert_almost_eq(c.difficulty_for_hashrate(c.hashrate_for_difficulty(123.0)), 123.0, 1e-9)
