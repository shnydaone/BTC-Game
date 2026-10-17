class_name Sparkline
extends Control
## A 1px price line for the ticker, drawn at base resolution without anti-aliasing.

var values: PackedFloat64Array = []


func set_values(v: PackedFloat64Array) -> void:
	values = v
	queue_redraw()


func _draw() -> void:
	if values.size() < 2:
		return
	var lo: float = values[0]
	var hi: float = values[0]
	for v: float in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span: float = hi - lo if hi > lo else 1.0
	var points := PackedVector2Array()
	var w: float = size.x - 1.0
	var h: float = size.y - 1.0
	for i: int in values.size():
		var x: float = roundf(w * i / (values.size() - 1))
		var y: float = roundf(h - h * (values[i] - lo) / span)
		points.append(Vector2(x, y) + Vector2(0.5, 0.5))
	var color: Color = UiTheme.UP if values[-1] >= values[0] else UiTheme.DOWN
	draw_polyline(points, color, -1.0, false)
