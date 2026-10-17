class_name SidePanel
extends VBoxContainer
## Base for the right-panel tabs. Each panel rebuilds its rows from Readouts when the day
## advances or a command lands, and only while it is on screen. Actions go through
## GameClock.apply(); irreversible ones ask first.

const WRAP_WIDTH: int = 218

var host: Control  # where dialogs open
var status: Label  # shared status line for command feedback


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EventBus.day_simulated.connect(func(_r: DayResult) -> void: _maybe_rebuild())
	EventBus.command_applied.connect(func(_c: Dictionary, _r: Dictionary) -> void: _maybe_rebuild())
	visibility_changed.connect(_maybe_rebuild)
	rebuild()


func _maybe_rebuild() -> void:
	if is_visible_in_tree():
		rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if GameClock.sim != null:
		build(GameClock.sim)


## Override: add this panel's rows for the current sim.
func build(_sim: Sim) -> void:
	pass


# ---------------------------------------------------------------- rows


func section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	add_child(l)
	return l


func row(label: String, value: String, tip: String = "", color: Color = UiTheme.TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UiTheme.dim(Label.new())
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", color)
	h.add_child(v)
	if tip != "":
		for c: Control in [l, v]:
			c.tooltip_text = tip
			c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(h)
	return h


func note(text: String, color: Color = UiTheme.TEXT_DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WRAP_WIDTH
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func buttons(list: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	for b: Button in list:
		h.add_child(b)
	add_child(h)
	return h


## A button that sends cmd, asking "confirm" first when given.
func action(text: String, cmd: Dictionary, confirm: String = "", tip: String = "", disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.disabled = disabled
	b.pressed.connect(func() -> void:
		if confirm == "":
			send(cmd)
		else:
			ConfirmDialog.ask(host, confirm, func() -> void: send(cmd)))
	return b


func send(cmd: Dictionary) -> Dictionary:
	var r: Dictionary = GameClock.apply(cmd)
	if status != null:
		status.text = "" if r["ok"] else String(r["reason"]).capitalize()
	return r
