class_name PauseMenu
extends CenterContainer
## Esc menu: resume, save to a slot, load, quit to title. Pauses the game while open.

var _main: Node
var _box := VBoxContainer.new()
var _status := Label.new()


func _init(main: Node) -> void:
	_main = main
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.add_child(_box)
	_box.add_child(UiTheme.heading("PAUSED"))
	_box.add_child(UiTheme.button("Resume (Esc)", close))
	for slot: String in Save.MANUAL_SLOTS:
		_box.add_child(UiTheme.button("Save to %s" % slot.capitalize(), func() -> void: _save(slot)))
	_box.add_child(UiTheme.button("Load game", func() -> void: _main.show_load(_main.show_game)))
	_box.add_child(UiTheme.button("Quit to title", _main.show_title))
	UiTheme.dim(_status)
	_box.add_child(_status)
	GameClock.set_paused(true)
	(_box.get_child(1) as Button).grab_focus()


func _save(slot: String) -> void:
	var err: Error = Save.save_game(GameClock.sim, slot)
	_status.text = "Saved to %s." % slot.capitalize() if err == OK else "Save failed (%s)." % error_string(err)


func close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Dims the game behind the overlay. (A ColorRect child would shrink to nothing: a
## CenterContainer sizes children to their minimum.)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
