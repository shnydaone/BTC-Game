class_name InboxView
extends CenterContainer
## The inbox overlay: messages newest first. Opening it marks them read.

var _inbox: Inbox


func _init(inbox: Inbox) -> void:
	_inbox = inbox
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 260)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UiTheme.heading("INBOX"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if _inbox.messages.is_empty():
		list.add_child(UiTheme.dim(Label.new()))
		(list.get_child(0) as Label).text = "No messages yet."
	for m: Dictionary in _inbox.messages:
		var l := Label.new()
		l.text = "%s  %s" % [m["date"], m["text"]]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		var color: Color = UiTheme.TEXT
		match m["kind"]:
			"alert":
				color = UiTheme.ACCENT
			"news":
				color = UiTheme.TEXT_DIM
			"mentor":
				color = UiTheme.UP
		if not m["read"]:
			l.text = "* " + l.text
		l.add_theme_color_override("font_color", color)
		list.add_child(l)
	box.add_child(UiTheme.button("Close (Esc)", close))
	_inbox.mark_all_read()


func close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Dims the game behind the overlay. (A ColorRect child would shrink to nothing: a
## CenterContainer sizes children to their minimum.)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
