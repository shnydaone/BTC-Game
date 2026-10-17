extends Control
## Screen router: title, mode select, the game, and the load menu. One screen at a time.

var _screen: Control


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	show_title()


func show_title() -> void:
	GameClock.stop()
	_swap(TitleScreen.new(self))


func show_mode_select() -> void:
	_swap(ModeSelectScreen.new(self))


func show_load(back: Callable) -> void:
	_swap(LoadScreen.new(self, back))


func start_new_game(mode_id: String) -> void:
	GameClock.new_game(mode_id, randi())
	show_game()


func continue_game(slot: String) -> void:
	var sim: Sim = Save.load_game(slot)
	if sim == null:
		return
	GameClock.start(sim, true)
	show_game()


func show_game() -> void:
	_swap(GameScreen.new(self))


func _swap(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(_screen)
