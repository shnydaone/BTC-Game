class_name Toasts
extends VBoxContainer
## Brief, non-blocking notices stacked in the facility corner (GDD 5: difficulty
## adjustments are a toast, not a pause). Each fades after a few real seconds.

const SECONDS: float = 3.0
const MAX_SHOWN: int = 4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END


func show_text(text: String) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	p.add_child(l)
	add_child(p)
	while get_child_count() > MAX_SHOWN:
		var old: Node = get_child(0)
		remove_child(old)
		old.queue_free()
	var t := p.create_tween()
	t.tween_interval(SECONDS)
	t.tween_property(p, "modulate:a", 0.0, 0.5)
	t.tween_callback(p.queue_free)
