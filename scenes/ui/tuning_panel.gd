class_name TuningPanel
extends CenterContainer
## F12 debug tuning panel (GDD 13.1): pick a tuning file, edit values as JSON, apply them
## to the running game, and dump the edited files to user://tuning_dump/ to copy into
## data/tuning. Edits last for this session only. Debug builds only.

const DUMP_DIR: String = "user://tuning_dump/"

var _file: String = ""
var _edits: Dictionary = {}  # key -> LineEdit
var _list := VBoxContainer.new()
var _status := Label.new()
var _files := HBoxContainer.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	GameClock.set_paused(true)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 330)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiTheme.heading("TUNING (F12)"))
	var files_scroll := ScrollContainer.new()
	files_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	files_scroll.custom_minimum_size.y = 22
	files_scroll.add_child(_files)
	box.add_child(files_scroll)
	for file: String in Data.game.tuning_files():
		_files.add_child(UiTheme.button(file, func() -> void: show_file(file)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_child(UiTheme.button("Apply", apply))
	row.add_child(UiTheme.button("Dump to file", dump))
	row.add_child(UiTheme.button("Close (F12)", queue_free))
	UiTheme.dim(_status)
	row.add_child(_status)
	box.add_child(row)
	show_file(Data.game.tuning_files()[0])


func show_file(file: String) -> void:
	_file = file
	_edits.clear()
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var entries: Dictionary = Data.game.tuning_entries(file)
	for key: String in entries:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = key
		l.custom_minimum_size.x = 200
		l.tooltip_text = "%s (%s): %s" % [entries[key].get("unit", ""), entries[key].get("basis", ""), entries[key].get("note", "")]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		h.add_child(l)
		var e := LineEdit.new()
		e.text = JSON.stringify(entries[key]["value"])
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(e)
		_list.add_child(h)
		_edits[key] = e
	_status.text = file


## Sets every changed value and rebuilds the sim's systems. Returns how many changed.
func apply() -> int:
	var changed: int = 0
	var entries: Dictionary = Data.game.tuning_entries(_file)
	for key: String in _edits:
		var parsed: Variant = JSON.parse_string((_edits[key] as LineEdit).text)
		if parsed == null and (_edits[key] as LineEdit).text != "null":
			_status.text = "Not valid JSON: %s" % key
			return 0
		if JSON.stringify(parsed) != JSON.stringify(entries[key]["value"]):
			Data.game.set_tuning(_file, key, parsed)
			changed += 1
	if GameClock.sim != null:
		GameClock.sim.reload_config()
	_status.text = "Applied %d change(s) to %s." % [changed, _file]
	return changed


## Writes every tuning file, edits included, to user://tuning_dump/. Returns the folder.
func dump() -> String:
	DirAccess.make_dir_recursive_absolute(DUMP_DIR)
	for file: String in Data.game.tuning_files():
		var doc: Dictionary = {"schema_version": 1, "notes": "Dumped from the F12 tuning panel.", "values": Data.game.tuning_entries(file)}
		var f := FileAccess.open(DUMP_DIR + file + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(doc, "  ", false))
		f.close()
	var path: String = ProjectSettings.globalize_path(DUMP_DIR)
	_status.text = "Dumped to %s" % path
	return path


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F12:
		get_viewport().set_input_as_handled()
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
