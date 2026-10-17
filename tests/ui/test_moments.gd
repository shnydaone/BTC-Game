extends GutTest
## The moment queue: cards pause the clock, replays gate their choices, act ends and
## failures show their screens, and the Slashdot prologue can be skipped.

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


func _start(mode_id: String) -> void:
	main.start_new_game(mode_id)
	await wait_process_frames(2)
	screen = main.get_child(main.get_child_count() - 1)


func _card() -> CardView:
	return screen.moments.current if screen.moments.is_showing() else null


## Runs to the day before `date` with cards off, then plays that day with cards on.
func _arrive(date: String) -> void:
	screen.moments.clear()
	screen.moments.enabled = false
	var h: History = GameClock.sim.data.history
	GameClock.step_days(h.index_of(date) - GameClock.sim.state.day_index)
	screen.moments.enabled = true
	GameClock.step_days(1)
	await wait_process_frames(2)


func test_new_game_asks_where_you_live() -> void:
	await _start("cypherpunk")
	assert_eq(_card().spec["kind"], "living")
	_card().choose_text("Roommates %s/mo" % Fmt.usd(GameClock.sim.finance.living_situations["roommates"]))
	await wait_process_frames(1)
	assert_true(GameClock.sim.state.finance.living_chosen)
	assert_eq(GameClock.sim.state.finance.living_situation, "roommates")


func test_auto_pause_events_show_a_card() -> void:
	await _start("slashdot")
	screen.moments.clear()
	GameClock.set_paused(false)
	GameClock.step_days(1)  # the Genesis block
	await wait_process_frames(1)
	assert_eq(_card().spec["id"], "genesis_block")
	assert_true(GameClock.paused)
	_card().choose_text("Continue")
	await wait_process_frames(1)
	assert_false(GameClock.paused, "resumes when the last card closes")


func test_skip_prologue_lands_on_the_slashdot_card() -> void:
	await _start("slashdot")
	screen.moments.clear()
	assert_true(GameClock.in_prologue())
	screen.skip_prologue()
	await wait_process_frames(1)
	assert_false(GameClock.in_prologue())
	assert_eq(Readouts.date(GameClock.sim), "2010-07-12")
	assert_eq(_card().spec["id"], "slashdot_v03")
	assert_false(screen._prologue_banner.visible)


func test_replays_hold_their_choices_until_drawn() -> void:
	await _start("cypherpunk")
	await _arrive("2011-11-18")
	var card := _card()
	assert_eq(card.spec["id"], "bottom_2011")
	assert_not_null(card.chart)
	assert_lt(card.chart.counter(card.chart.values.size() - 1), -0.8, "the 2011 crash")
	assert_true(card._choices[0].disabled)
	card.chart.skip()
	await wait_process_frames(2)
	assert_false(card._choices[0].disabled)


func test_act_end_shows_the_report_card() -> void:
	await _start("slashdot")
	await _arrive("2012-11-28")
	var kinds: Array = [_card().spec["kind"]] + screen.moments.queue.map(func(s: Dictionary) -> String: return s["kind"])
	assert_has(kinds, "report")


func test_chapter_11_then_act_lost() -> void:
	await _start("late")
	screen.moments.clear()
	var sim: Sim = GameClock.sim
	GameClock.apply({"type": "incorporate"})
	sim.state.finance.ownership = 0.12
	sim.state.finance.cash_cents = -1_000_00
	sim.state.finance.overdue_since_day = sim.state.day_index - sim.restructuring.cure_days
	GameClock.step_days(1)
	await wait_process_frames(1)
	var kinds: Array = [_card().spec["kind"]] + screen.moments.queue.map(func(s: Dictionary) -> String: return s["kind"])
	assert_has(kinds, "chapter11")
	assert_has(kinds, "act_lost")
	while _card() != null and _card().spec["kind"] != "act_lost":
		_card().choose(_card().spec.get("choices", [{"text": "Continue"}])[0])
		await wait_process_frames(1)
	_card().choose_text("Quit to title")
	await wait_process_frames(2)
	assert_null(GameClock.sim)


func test_quit_job_card_sends_the_command() -> void:
	await _start("cypherpunk")
	screen.moments.clear()
	screen.moments.push(Cards.objective_card("2011-01-01"))
	_card().choose_text("Quit the day job")
	assert_false(GameClock.sim.state.finance.employed)
