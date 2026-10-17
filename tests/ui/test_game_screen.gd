extends GutTest
## Headless smoke tests for the shell: screens build, the game screen follows the sim,
## and saves round-trip. Uses its own save slot so a player's saves are never touched.

const TEST_SLOT: String = "test_slot"
const TEST_SAVE_DIR: String = "user://test_saves/"

var main: Control


func before_each() -> void:
	Save.save_dir = TEST_SAVE_DIR
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)


func after_each() -> void:
	GameClock.stop()
	for slot: String in [TEST_SLOT, Save.AUTOSAVE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.path(slot)))
	Save.save_dir = Save.SAVE_DIR


## First descendant whose script class_name is `type`.
func _find(node: Node, type: String) -> Node:
	for child: Node in node.find_children("*", "", true, false):
		var script: Script = child.get_script()
		if script != null and script.get_global_name() == type:
			return child
	return null


func test_title_then_new_game() -> void:
	assert_not_null(_find(main, "TitleScreen"))
	main.start_new_game("slashdot")
	await wait_process_frames(2)
	assert_not_null(_find(main, "GameScreen"))
	assert_not_null(GameClock.sim)
	assert_true(GameClock.paused, "a new game starts paused")
	assert_eq(GameClock.sim.state.mode_id, "slashdot")


func test_top_bar_follows_the_sim() -> void:
	main.start_new_game("cypherpunk")
	await wait_process_frames(2)
	GameClock.step_days(700)
	await wait_process_frames(1)
	var bar: Node = _find(main, "TopBar")
	var labels: Array[String] = []
	for l: Label in bar.find_children("*", "Label", true, false):
		labels.append(l.text)
	assert_has(labels, Readouts.date(GameClock.sim))
	assert_has(labels, Fmt.hashrate(Readouts.hashrate_hs(GameClock.sim)))
	assert_has(labels, Fmt.usd(Readouts.cash_cents(GameClock.sim)))


func test_every_run_in_the_shell_reaches_act_2() -> void:
	main.start_new_game("slashdot")
	await wait_process_frames(2)
	var events: Dictionary = {}
	var count := func(e: Dictionary) -> void: events[e["type"]] = true
	EventBus.sim_event.connect(count)
	GameClock.step_days(1500)
	EventBus.sim_event.disconnect(count)
	await wait_process_frames(1)
	for type: String in ["historical_event", "feature_unlocked", "difficulty_adjusted", "subsidy_halved", "act_ended", "month_closed"]:
		assert_true(events.has(type), type)
	assert_eq(GameClock.sim.state.objectives.act, 2)
	assert_true(Save.has_save(Save.AUTOSAVE), "act end autosaved")


func test_save_and_continue() -> void:
	main.start_new_game("cypherpunk")
	await wait_process_frames(2)
	GameClock.step_days(200)
	var date: String = Readouts.date(GameClock.sim)
	assert_eq(Save.save_game(GameClock.sim, TEST_SLOT), OK)
	assert_eq(Save.describe(TEST_SLOT)["date"], date)
	main.show_title()
	await wait_process_frames(2)
	assert_null(GameClock.sim)
	main.continue_game(TEST_SLOT)
	await wait_process_frames(2)
	assert_eq(Readouts.date(GameClock.sim), date)
	assert_true(GameClock.paused, "a loaded game starts paused")


func test_keys_pause_and_change_speed() -> void:
	main.start_new_game("slashdot")
	await wait_process_frames(2)
	var key := InputEventKey.new()
	key.keycode = KEY_3
	key.pressed = true
	Input.parse_input_event(key)
	await wait_process_frames(2)
	assert_false(GameClock.paused)
	assert_eq(GameClock.speed_index, 2)
	key = InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await wait_process_frames(2)
	assert_true(GameClock.paused)


func test_escape_opens_the_pause_menu() -> void:
	main.start_new_game("slashdot")
	await wait_process_frames(2)
	GameClock.set_paused(false)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait_process_frames(2)
	assert_not_null(_find(main, "PauseMenu"))
	assert_true(GameClock.paused)
