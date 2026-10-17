extends SceneTree
## Renders the game to PNGs for a legibility check (needs a window, not --headless):
##
##   godot --path . --resolution 640x360 --script res://tests/ui/screenshot.gd -- --out <dir>
##
## Writes title.png, game_start.png, game_running.png (Slashdot, late 2010, with a few
## machines), one PNG per right-panel tab, the inbox and a confirmation dialog, each at
## 1x base resolution, plus fonts.png showing both fonts at several sizes.

const FRAMES_TO_SETTLE: int = 5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else ProjectSettings.globalize_path("user://screens/")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred(out)


func _run(out: String) -> void:
	root.size = Vector2i(640, 360)
	await _font_sheet(out + "/fonts.png")
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot(out + "/title.png")
	main.start_new_game("slashdot")
	await _shot(out + "/game_start.png")
	var game_clock: Node = root.get_node("GameClock")
	game_clock.step_days(640)  # into the GPU era
	game_clock.apply({"type": "move_site", "site_id": "garage"})
	game_clock.sim.state.finance.cash_cents += 2_000_000
	game_clock.apply({"type": "buy_hardware", "unit_id": "gpu_card", "count": 12, "used": true})
	game_clock.apply({"type": "buy_hardware", "unit_id": "cpu_desktop", "count": 3, "used": true})
	game_clock.step_days(30)
	await _shot(out + "/game_running.png")
	var screen: Node = main.get_child(main.get_child_count() - 1)
	var tabs: Array = screen.right.TABS
	for i: int in tabs.size():
		screen.right.show_tab(i)
		await _shot(out + "/tab_%d_%s.png" % [i, String(tabs[i][0]).to_lower().replace(" & ", "_")])
	screen.open_inbox()
	await _shot(out + "/inbox.png")
	screen.get_child(screen.get_child_count() - 1).close()
	screen.right.show_tab(1)
	# UI classes are looked up at run time: they need the autoloads, which a --script
	# file does not see when it compiles.
	load("res://scenes/ui/confirm_dialog.gd").ask(screen, "Buy 5 GPU card new for $2,495? Arrives in 5 days.", func() -> void: pass)
	await _shot(out + "/confirm.png")
	print("Wrote screenshots to %s" % out)
	quit()


func _shot(path: String) -> void:
	for i: int in FRAMES_TO_SETTLE:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _font_sheet(path: String) -> void:
	var box := VBoxContainer.new()
	root.add_child(box)
	var bg := ColorRect.new()
	bg.color = Color("1e1f22")
	bg.size = Vector2(640, 360)
	bg.show_behind_parent = true
	box.add_child(bg)
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
