class_name GameScreen
extends VBoxContainer
## The game (GDD 12.3): top bar, facility view on the left, right panel tabs, news ticker
## at the bottom. The right panel's tabs arrive in M3-2.
##
## Keys: Space pauses, 1-4 pick a speed, Esc opens the pause menu.

const RIGHT_PANEL_W: int = 240
const TICKER_H: int = 14

var _main: Node
var _news := Label.new()
var _menu: PauseMenu


func _init(main: Node) -> void:
	_main = main
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 0)


func _ready() -> void:
	add_child(TopBar.new())
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	add_child(middle)
	var facility := FacilityView.new()
	facility.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(facility)
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_PANEL_W, 0)
	middle.add_child(right)
	var tabs := Label.new()
	tabs.text = "Market | Hardware | Sites & Power\nFinance | Treasury | Codex\n\n(panels arrive in M3-2)"
	UiTheme.dim(tabs)
	right.add_child(tabs)
	var ticker := PanelContainer.new()
	ticker.custom_minimum_size = Vector2(0, TICKER_H)
	ticker.add_child(_news)
	add_child(ticker)
	_news.text = "Press Space or a speed button to start the clock."
	_news.clip_text = true
	EventBus.day_simulated.connect(_on_day)


func _on_day(result: DayResult) -> void:
	for e: Dictionary in result.of_type("historical_event"):
		_news.text = "%s  %s" % [result.date, e["headline"]]


func _unhandled_input(event: InputEvent) -> void:
	if _menu != null and is_instance_valid(_menu):
		return
	if event.is_action_pressed("ui_cancel"):
		_menu = PauseMenu.new(_main)
		add_child(_menu)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: Key = (event as InputEventKey).keycode
		if key == KEY_SPACE:
			GameClock.toggle_pause()
			get_viewport().set_input_as_handled()
		elif key >= KEY_1 and key <= KEY_4:
			GameClock.set_speed(key - KEY_1)
			GameClock.set_paused(false)
			get_viewport().set_input_as_handled()
