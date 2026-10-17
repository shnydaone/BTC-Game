class_name GameScreen
extends Control
## The game (GDD 12.3): top bar, facility view on the left with the inbox button and
## toasts, right panel tabs, news ticker at the bottom. Overlays (pause menu, inbox,
## confirmations) are children of this node so they cover the whole screen.
##
## Keys: Space pauses, 1-4 pick a speed, I opens the inbox, Esc opens the pause menu.
## Playtest: F3 shows the decision meter, F12 opens the tuning panel (debug builds).

const RIGHT_PANEL_W: int = 240
const TICKER_H: int = 14
const INBOX_TOP: int = 16

var inbox := Inbox.new()
var moments: Moments
var meter := DecisionMeter.new()
var main: Node:
	get:
		return _main
var right: RightPanel
var ticker := NewsTicker.new()

var _main: Node
var _toasts := Toasts.new()
var _inbox_button: Button
var _overlay: Control
var _layout := VBoxContainer.new()
var _prologue_banner := PanelContainer.new()


func _init(main: Node) -> void:
	_main = main
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 0)


func _ready() -> void:
	add_child(_layout)
	_layout.add_child(TopBar.new())
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	_layout.add_child(middle)

	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(left)
	var facility := FacilityView.new()
	facility.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_child(facility)
	_inbox_button = UiTheme.button("Inbox", open_inbox)
	_inbox_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_inbox_button.position = Vector2(-60, INBOX_TOP)
	_inbox_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	left.add_child(_inbox_button)
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.position = Vector2(-4, -16)
	left.add_child(_toasts)
	meter.position = Vector2(4, 16)
	left.add_child(meter)

	right = RightPanel.new(self)
	right.custom_minimum_size = Vector2(RIGHT_PANEL_W, 0)
	middle.add_child(right)

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, TICKER_H)
	ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(ticker)
	_layout.add_child(bar)
	_build_prologue_banner(left)
	moments = Moments.new(self)
	add_child(moments)
	add_child(MentorFeed.new(self))
	EventBus.day_simulated.connect(_on_day)
	_refresh_inbox_button()
	if GameClock.sim != null and not GameClock.sim.state.finance.living_chosen:
		moments.push(Cards.living_card(GameClock.sim))


func _on_day(result: DayResult) -> void:
	var sim: Sim = GameClock.sim
	if sim == null:
		return
	_prologue_banner.visible = GameClock.in_prologue()
	for e: Dictionary in result.events:
		var m: Dictionary = Messages.describe(sim, e)
		if m.is_empty():
			continue
		match m["kind"]:
			"toast":
				_toasts.show_text(m["text"])
			"news":
				ticker.push("%s  %s" % [result.date, m["text"]])
			"alert":
				_toasts.show_text(m["text"])
		inbox.add(result.date, m)
	_refresh_inbox_button()


func toast(text: String) -> void:
	_toasts.show_text(text)
	_refresh_inbox_button()


func _refresh_inbox_button() -> void:
	var n: int = inbox.unread()
	_inbox_button.text = "Inbox (%d)" % n if n > 0 else "Inbox"


func open_inbox() -> void:
	if _overlay_open():
		return
	_overlay = InboxView.new(inbox)
	_overlay.tree_exited.connect(_refresh_inbox_button)
	add_child(_overlay)
	_refresh_inbox_button()


func _overlay_open() -> bool:
	if _overlay != null and is_instance_valid(_overlay) and _overlay.is_inside_tree():
		return true
	for child: Node in get_children():
		if child is ConfirmDialog:
			return true
	return moments != null and moments.is_showing()


func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open():
		return
	if event.is_action_pressed("ui_cancel"):
		_overlay = PauseMenu.new(_main)
		add_child(_overlay)
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
		elif key == KEY_I:
			open_inbox()
			get_viewport().set_input_as_handled()
		elif key == KEY_F3:
			meter.toggle()
			get_viewport().set_input_as_handled()
		elif key == KEY_F12 and OS.is_debug_build():
			_overlay = TuningPanel.new()
			add_child(_overlay)
			get_viewport().set_input_as_handled()


## Slashdot prologue (decisions.md 2026-10-16): a banner over the empty bedroom and a
## way to skip ahead to the Slashdot story.
func _build_prologue_banner(parent: Control) -> void:
	_prologue_banner.set_anchors_preset(Control.PRESET_CENTER)
	_prologue_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prologue_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	_prologue_banner.add_child(box)
	box.add_child(UiTheme.heading("PROLOGUE"))
	var l := Label.new()
	l.text = "January 2009 to July 2010. You read about Bitcoin
on the mailing list and watch it grow.
Mining opens when Slashdot covers version 0.3."
	box.add_child(l)
	box.add_child(UiTheme.button("Skip to the Slashdot story", skip_prologue))
	parent.add_child(_prologue_banner)
	_prologue_banner.visible = GameClock.in_prologue()


## Fast-forwards to the day before mining opens without stopping for cards, then plays
## that day so the Slashdot card shows.
func skip_prologue() -> void:
	var sim: Sim = GameClock.sim
	if sim == null or not GameClock.in_prologue():
		return
	moments.clear()
	moments.enabled = false
	while GameClock.in_prologue() and not sim.is_finished():
		if _opens_mining_tomorrow(sim):
			break
		GameClock.step_days(1)
	moments.enabled = true
	GameClock.step_days(1)


func _opens_mining_tomorrow(sim: Sim) -> bool:
	for e: Dictionary in sim.events.by_day.get(sim.state.day_index, []):
		for fx: Dictionary in e["effects"]:
			if fx["type"] == "unlock" and fx.get("feature") == "mining":
				return true
	return false
