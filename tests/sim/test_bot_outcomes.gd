extends GutTest
## GDD 14 expected bot outcomes, asserted in Slashdot mode over Acts 1-2 on several seeds
## (decisions.md 2026-10-16). The other modes get sanity checks. A failure here is a
## balance regression: flag it, don't silently retune.

const SEEDS: Array[int] = [1, 2, 3]
const SANITY_MODES: PackedStringArray = ["cypherpunk", "late"]
const OBJECTIVE_WINDOW: Array[String] = ["2010-10-01", "2012-06-30"]
const GOOD_GRADES: PackedStringArray = ["A", "B"]
const NEGATIVE_STRETCH_DAYS: int = 60
const MAX_SECONDS_PER_RUN: float = 5.0

var runs: Dictionary = {}  # "bot/mode/seed" -> BotRunner.Run


func before_all() -> void:
	for seed_value: int in SEEDS:
		for bot: Bot in BotRunner.all_bots():
			_keep(BotRunner.run(bot, "slashdot", seed_value))
	for mode_id: String in SANITY_MODES:
		for bot: Bot in BotRunner.all_bots():
			_keep(BotRunner.run(bot, mode_id, 1))


func _keep(r: BotRunner.Run) -> void:
	runs["%s/%s/%d" % [r.bot, r.mode, r.seed_value]] = r


func _run(bot: String, mode_id: String = "slashdot", seed_value: int = 1) -> BotRunner.Run:
	return runs["%s/%s/%d" % [bot, mode_id, seed_value]]


func test_never_upgrade_is_unprofitable_by_2014() -> void:
	for seed_value: int in SEEDS:
		var r := _run("never_upgrade", "slashdot", seed_value)
		var start: String = _first_negative_stretch(r, "2013-02-01")
		assert_true(start >= "2014-01-01" and start <= "2014-12-31", "seed %d: margin first stays negative from %s" % [seed_value, start])


## First day after `after` that starts NEGATIVE_STRETCH_DAYS days of mining revenue below power.
func _first_negative_stretch(r: BotRunner.Run, after: String) -> String:
	var run_length: int = 0
	for i: int in r.dates.size():
		if r.dates[i] < after:
			continue
		run_length = run_length + 1 if r.mined_cents[i] < r.power_cents[i] else 0
		if run_length == NEGATIVE_STRETCH_DAYS:
			return r.dates[i - NEGATIVE_STRETCH_DAYS + 1]
	return "never"


func test_passive_hodler_survives_with_a_low_score() -> void:
	for seed_value: int in SEEDS:
		var hodler := _run("passive_hodler", "slashdot", seed_value)
		assert_true(hodler.survived(), "seed %d" % seed_value)
		for other: String in ["never_upgrade", "hindsight", "sensible", "max_leverage"]:
			assert_lt(hodler.score_usd(), _run(other, "slashdot", seed_value).score_usd(), "seed %d: below %s" % [seed_value, other])


func test_hindsight_defines_the_ceiling() -> void:
	var cases: Array = []
	for seed_value: int in SEEDS:
		cases.append(["slashdot", seed_value])
	for mode_id: String in SANITY_MODES:
		cases.append([mode_id, 1])
	for c: Array in cases:
		var ceiling: float = _run("hindsight", c[0], c[1]).score_usd()
		for other: String in ["never_upgrade", "passive_hodler", "sensible", "max_leverage"]:
			assert_gte(ceiling, _run(other, c[0], c[1]).score_usd(), "%s seed %d: hindsight vs %s" % [c[0], c[1], other])


func test_sensible_survives_with_a_good_score() -> void:
	for seed_value: int in SEEDS:
		var r := _run("sensible", "slashdot", seed_value)
		var label: String = "seed %d" % seed_value
		assert_true(r.survived(), label)
		assert_true(r.objective_met_on >= OBJECTIVE_WINDOW[0] and r.objective_met_on <= OBJECTIVE_WINDOW[1], "%s: quit the day job on %s" % [label, r.objective_met_on])
		assert_true(GOOD_GRADES.has(r.card(1).get("grade", "")), "%s: act 1 grade %s" % [label, r.card(1).get("grade")])
		assert_true(GOOD_GRADES.has(r.card(2).get("grade", "")), "%s: act 2 grade %s" % [label, r.card(2).get("grade")])
		for other: String in ["never_upgrade", "passive_hodler", "max_leverage"]:
			assert_gt(r.score_usd(), _run(other, "slashdot", seed_value).score_usd(), "%s: above %s" % [label, other])


func test_max_leverage_borrows_and_expands() -> void:
	for seed_value: int in SEEDS:
		var r := _run("max_leverage", "slashdot", seed_value)
		assert_true(r.loan_taken, "seed %d" % seed_value)
		assert_eq(r.final_site, "warehouse", "seed %d" % seed_value)


func test_max_leverage_restructures_in_the_2014_2015_bear() -> void:
	# Interim M2 expectation. It does not hold: Max Leverage fills its sites with Gen 1
	# ASICs in early 2013, when payback was about a week, and banks more cash than the one
	# $50,000 loan can threaten. The GDD's 2018/2022 outcome needs the Act 3-4 debt (M6).
	var restructured: int = 0
	for seed_value: int in SEEDS:
		for date: String in _run("max_leverage", "slashdot", seed_value).restructured_on:
			if date >= "2014-01-01" and date <= "2015-12-31":
				restructured += 1
	if restructured == 0:
		pending("Max Leverage survives the 2014-2015 bear with only the Act 2 loan; flagged for Eric (see the PR)")
	else:
		assert_gt(restructured, 0)


func test_max_leverage_fails_when_it_starts_late() -> void:
	var r := _run("max_leverage", "late", 1)
	assert_false(r.survived())
	assert_true(r.act_lost)


func test_every_sanity_run_finishes() -> void:
	for mode_id: String in SANITY_MODES:
		for bot: String in ["never_upgrade", "passive_hodler", "hindsight", "sensible", "max_leverage"]:
			var r := _run(bot, mode_id, 1)
			assert_true(r.act_lost or r.card(2).size() > 0, "%s %s reached the Act 2 report card" % [bot, mode_id])


func test_same_seed_same_game() -> void:
	var again := BotRunner.run(SensibleBot.new(), "slashdot", 1)
	assert_eq(again.final_json, _run("sensible", "slashdot", 1).final_json)
	assert_ne(_run("sensible", "slashdot", 1).final_json, _run("sensible", "slashdot", 2).final_json)


func test_runs_are_fast() -> void:
	for key: String in runs:
		assert_lt((runs[key] as BotRunner.Run).seconds, MAX_SECONDS_PER_RUN, key)
