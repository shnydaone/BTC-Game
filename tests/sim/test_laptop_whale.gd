extends GutTest
## The 2009 stack (decisions.md 2026-10-16). No balance verdict: these pin down what the
## Laptop Whale holds so a change to the knobs (uptime, liquidity) shows up here first.
## run_bots.gd writes the full report.


func test_a_laptop_from_genesis_is_a_whale() -> void:
	var r := BotRunner.run(LaptopWhaleBot.new(false), "cypherpunk", 1, "2010-07-19")
	var held: float = (r.cold_sats[-1] + r.exchange_sats[-1]) / 1.0e8
	assert_between(held, 100000.0, 250000.0, "laptop at half uptime, BTC by Mt. Gox's opening")


func test_a_desktop_more_than_triples_it() -> void:
	var laptop := BotRunner.run(LaptopWhaleBot.new(false), "cypherpunk", 1, "2010-07-19")
	var both := BotRunner.run(LaptopWhaleBot.new(true), "cypherpunk", 1, "2010-07-19")
	assert_gt(both.cold_sats[-1], 3 * laptop.cold_sats[-1])


func test_slashdot_players_are_not_whales() -> void:
	var r := BotRunner.run(PassiveHodlerBot.new(), "slashdot", 1, "2011-01-01")
	assert_lt((r.cold_sats[-1] + r.exchange_sats[-1]) / 1.0e8, 1000.0, "a laptop from the Slashdot story")


func test_report_renders() -> void:
	var script: GDScript = load("res://tests/sim/run_bots.gd")
	var text: String = script.whale_report()
	assert_string_contains(text, "## Laptop only")
	assert_string_contains(text, "| 2011-06-08 |")
