class_name LoadScreen
extends CenterContainer
## Lists the autosave and the manual slots.

var _main: Node
var _back: Callable


func _init(main: Node, back: Callable) -> void:
	_main = main
	_back = back
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UiTheme.heading("LOAD GAME"))
	for slot: String in [Save.AUTOSAVE] + Array(Save.MANUAL_SLOTS):
		var info: Dictionary = Save.describe(slot)
		var label: String = "%s: empty" % slot.capitalize() if info.is_empty() else "%s: %s, %s mode" % [slot.capitalize(), info["date"], String(info["mode"]).capitalize()]
		var b := UiTheme.button(label, func() -> void: _main.continue_game(slot))
		b.disabled = info.is_empty()
		box.add_child(b)
	box.add_child(UiTheme.button("Back", _back))
