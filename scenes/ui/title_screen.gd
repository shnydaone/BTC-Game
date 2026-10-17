class_name TitleScreen
extends CenterContainer
## Title: new game, continue the latest save, load, quit.

var _main: Node


func _init(main: Node) -> void:
	_main = main
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var title := UiTheme.heading("PROOF OF WORK")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.dim(Label.new())
	sub.text = "A Bitcoin mining business, 2009 onward"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	box.add_child(UiTheme.button("New game", _main.show_mode_select))
	var latest: String = Save.latest_slot()
	var cont := UiTheme.button("Continue", func() -> void: _main.continue_game(latest))
	cont.disabled = latest == ""
	box.add_child(cont)
	box.add_child(UiTheme.button("Load game", func() -> void: _main.show_load(_main.show_title)))
	box.add_child(UiTheme.button("Quit", func() -> void: get_tree().quit()))
	(box.get_child(3) as Button).grab_focus()
