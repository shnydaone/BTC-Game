extends GutTest
## The decision meter and the F12 tuning panel, plus the M3-4 content wiring: mentor
## messages, Codex triggers and parody names.

const TEST_SAVE_DIR: String = "user://test_saves/"

var main: Control
var screen: Node


func before_each() -> void:
	Save.save_dir = TEST_SAVE_DIR
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)


func after_each() -> void:
	GameClock.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path(Save.AUTOSAVE)))
	Save.save_dir = Save.SAVE_DIR


func _start(mode_id: String, cards: bool = false) -> void:
	main.start_new_game(mode_id)
	await wait_process_frames(2)
	screen = main.get_child(main.get_child_count() - 1)
	screen.moments.clear()
	screen.moments.enabled = cards


func test_meter_counts_commands_and_real_choices() -> void:
	await _start("cypherpunk", true)
	var meter: DecisionMeter = screen.meter
	screen.moments.push(Cards.living_card(GameClock.sim))
	screen.moments.current.choose(screen.moments.current.spec["choices"][0])  # living situation
	GameClock.apply({"type": "set_mining_mode", "mode": "pool"})  # fails: no pools yet
	GameClock.apply({"type": "set_shutoff_unprofitable", "enabled": true})
	assert_eq(meter.decisions.size(), 3, "the choice, its command, and the shut-off; the failed command does not count")
	screen.moments.push({"kind": "event", "title": "x"})
	screen.moments.current.choose_text("Continue")
	assert_eq(meter.decisions.size(), 3, "Continue is not a decision")
	assert_gt(meter.rate(), 0.0)
	meter.toggle()
	assert_string_contains(meter.text, "decisions")


func test_tuning_panel_edits_the_live_game() -> void:
	await _start("cypherpunk")
	var data: GameData = Data.game
	var before: float = float(data.tuning("mining", "pool_fee"))
	var panel := TuningPanel.new()
	screen.add_child(panel)
	await wait_process_frames(1)
	panel.show_file("mining")
	(panel._edits["pool_fee"] as LineEdit).text = "0.05"
	assert_eq(panel.apply(), 1)
	assert_almost_eq(GameClock.sim.mining.pool_fee, 0.05, 1e-9, "the running sim picked it up")
	var dir: String = panel.dump()
	assert_true(FileAccess.file_exists(dir.path_join("mining.json")))
	data.set_tuning("mining", "pool_fee", before)
	GameClock.sim.reload_config()
	panel.queue_free()


func test_mentor_messages_reach_the_inbox_once() -> void:
	await _start("slashdot")
	GameClock.step_days(800)
	await wait_process_frames(1)
	var mentor: Array = screen.inbox.messages.filter(func(m: Dictionary) -> bool: return m["kind"] == "mentor")
	assert_gt(mentor.size(), 5)
	var texts: Array = mentor.map(func(m: Dictionary) -> String: return m["text"])
	assert_true(texts.any(func(t: String) -> bool: return t.contains("your wallet is a file")))
	assert_false(texts.any(func(t: String) -> bool: return t.contains("Your laptop is mining")), "Slashdot players are not mining in 2009")
	var seen: int = GameClock.sim.state.ui_seen.size()
	var again: Sim = load("res://autoload/save.gd").from_json(load("res://autoload/save.gd").to_json(GameClock.sim))
	assert_eq(again.state.ui_seen.size(), seen, "delivered messages survive a save")


func test_late_mode_has_no_mentor() -> void:
	await _start("late")
	GameClock.step_days(200)
	await wait_process_frames(1)
	assert_eq(screen.inbox.messages.filter(func(m: Dictionary) -> bool: return m["kind"] == "mentor").size(), 0)


func test_mentor_goes_quiet_after_april_2011() -> void:
	var sim := Sim.new_game(GameData.shared(), "cypherpunk", 1)
	var last: String = ""
	while sim.current_date() < "2013-01-01":
		var r := sim.step_day()
		if not MentorFeed.due(sim, r).is_empty():
			last = r.date
	assert_true(last != "" and last <= "2011-04-30", "last message %s" % last)


func test_codex_triggers_and_text() -> void:
	var sim := Sim.new_game(GameData.shared(), "cypherpunk", 1)
	while sim.current_date() < "2010-01-15":
		sim.step_day()
	assert_true(sim.state.events.codex.has("difficulty_adjustment"))
	assert_false(sim.state.events.codex.has("j_per_th"), "no new machine yet")
	assert_string_contains(Readouts.codex_text("hashprice"), "terahash")
