extends SceneTree
## Renders the game to PNGs for a legibility check (needs a window, not --headless):
##
##   godot --path . --resolution 640x360 --script res://tests/ui/screenshot.gd -- --out <dir>
##
## Slashdot run: title, the living-situation card, the prologue, the Slashdot card, the
## game in late 2010 with machines, every right-panel tab, the inbox, a confirmation, the
## 2011 crash replay (drawing and drawn) and the Act 1 report card. Plus fonts.png.
##
## UI classes are looked up at run time: they need the autoloads, which a --script file
## does not see when it compiles.

const FRAMES_TO_SETTLE: int = 5

var main: Control
var clock: Node
var screen: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else ProjectSettings.globalize_path("user://screens/")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred(out)


func _run(out: String) -> void:
	root.size = Vector2i(640, 360)
	await _font_sheet(out + "/fonts.png")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	clock = root.get_node("GameClock")
	await _shot(out + "/title.png")

	main.start_new_game("slashdot")
	screen = main.get_child(main.get_child_count() - 1)
	await _shot(out + "/living_card.png")
	screen.moments.current.choose(screen.moments.current.spec["choices"][1])
	await _shot(out + "/prologue.png")
	screen.skip_prologue()
	await _shot(out + "/slashdot_card.png")

	_cards(false)
	clock.step_days(84)  # into the GPU era
	clock.apply({"type": "move_site", "site_id": "garage"})
	clock.sim.state.finance.cash_cents += 2_000_000
	clock.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 12, "used": true})
	clock.apply({"type": "buy_hardware", "unit_id": "cpu_desktop", "count": 3, "used": true})
	clock.step_days(30)
	await _shot(out + "/game_running.png")
	var tabs: Array = screen.right.TABS
	for i: int in tabs.size():
		screen.right.show_tab(i)
		await _shot(out + "/tab_%d_%s.png" % [i, String(tabs[i][0]).to_lower().replace(" & ", "_")])
	screen.open_inbox()
	await _shot(out + "/inbox.png")
	screen.get_child(screen.get_child_count() - 1).close()
	screen.right.show_tab(1)
	var dialog: Node = load("res://scenes/ui/confirm_dialog.gd").ask(screen, "Buy 5 GPU card new for $2,495? Arrives in 5 days.", func() -> void: pass)
	await _shot(out + "/confirm.png")
	dialog._close(false)

	await _arrive("2011-11-18")
	await _shot(out + "/replay_drawing.png", 40)
	screen.moments.current.chart.skip()
	await _shot(out + "/replay_drawn.png")
	await _arrive("2012-11-28")
	while screen.moments.is_showing() and screen.moments.current.spec["kind"] != "report":
		var card: Node = screen.moments.current
		if card.chart != null:
			card.chart.skip()
			await process_frame
		card.choose(card.spec.get("choices", [{"text": "Continue"}])[0])
		await process_frame
	await _shot(out + "/report_card.png")
	print("Wrote screenshots to %s" % out)
	quit()


func _cards(on: bool) -> void:
	screen.moments.clear()
	screen.moments.enabled = on


## Runs to the day before `date` without cards, then plays that day with cards.
func _arrive(date: String) -> void:
	_cards(false)
	var h: History = clock.sim.data.history
	clock.step_days(h.index_of(date) - clock.sim.state.day_index)
	_cards(true)
	clock.step_days(1)


func _shot(path: String, frames: int = FRAMES_TO_SETTLE) -> void:
	for i: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _font_sheet(path: String) -> void:
	var box := VBoxContainer.new()
	root.add_child(box)
	for spec: Array in [["monogram.ttf", [12, 16, 24]], ["kenney_pixel.ttf", [16, 32]]]:
		for size: int in spec[1]:
			var l := Label.new()
			var font: FontFile = load("res://assets/fonts/" + spec[0])
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			l.add_theme_font_override("font", font)
			l.add_theme_font_size_override("font_size", size)
			l.text = "%s %d: BTC $0.08 +3.2%% 1,234 TH/s Hashprice 0123456789" % [spec[0], size]
			box.add_child(l)
	await _shot(path)
	box.queue_free()
