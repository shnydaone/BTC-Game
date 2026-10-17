class_name ConfirmDialog
extends CenterContainer
## Asks before an irreversible action. The clock pauses while it is open and resumes as it
## was afterwards. Enter confirms, Esc cancels.

var _text: String
var _on_yes: Callable
var _was_paused: bool


static func ask(host: Control, text: String, on_yes: Callable) -> ConfirmDialog:
	var d := ConfirmDialog.new(text, on_yes)
	host.add_child(d)
	return d


func _init(text: String, on_yes: Callable) -> void:
	_text = text
	_on_yes = on_yes
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_was_paused = GameClock.paused
	GameClock.set_paused(true)
	var panel := PanelContainer.new()
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := Label.new()
	l.text = _text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var no := UiTheme.button("Cancel", func() -> void: _close(false))
	var yes := UiTheme.button("Confirm", func() -> void: _close(true))
	row.add_child(no)
	row.add_child(yes)
	yes.grab_focus()


func _close(confirmed: bool) -> void:
	GameClock.set_paused(_was_paused)
	if confirmed:
		_on_yes.call()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(false)


## Dims the game behind the overlay. (A ColorRect child would shrink to nothing: a
## CenterContainer sizes children to their minimum.)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
