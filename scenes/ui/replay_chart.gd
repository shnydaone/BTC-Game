class_name ReplayChart
extends Control
## The cinematic replay (GDD 10): the chart zooms to the event window and the line draws
## itself over a few seconds while a gain or drawdown counter ticks; pins mark other
## events in the window. Click to skip ahead. Emits finished when the line is complete.

signal finished

const PAD := Vector2(4, 14)

var values: PackedFloat64Array = []
var dates: PackedStringArray = []
var pins: Array = []  # [index into values, label]
var progress: float = 0.0
var seconds: float = 4.0
var log_scale: bool = true

var _done: bool = false


## Series: "price" (closes), "hashrate" (world hashrate) or "pizza" (10,000 BTC in USD).
func setup(sim: Sim, replay: Dictionary) -> void:
	var h: History = sim.data.history
	var start: int = int(replay["start"])
	var end: int = int(replay["end"])
	for i: int in range(start, end + 1):
		var v: float
		match String(replay["series"]):
			"hashrate":
				v = h.hashrate_hs[i]
			"pizza":
				v = h.price_usd[i] * float(sim.data.tuning("offers", "pizza_btc")) if h.has_price(i) else NAN
			_:
				v = h.price_usd[i]
		if is_nan(v) or v <= 0.0:
			continue
		values.append(v)
		dates.append(h.dates[i])
		for p: Array in replay["pins"]:
			if int(p[0]) == i:
				pins.append([values.size() - 1, p[1]])
	seconds = float(sim.data.tuning("clock", "replay_seconds"))
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_done() -> bool:
	return _done


func skip() -> void:
	progress = 1.0


func _process(delta: float) -> void:
	if _done:
		return
	progress = minf(1.0, progress + delta / seconds)
	queue_redraw()
	if progress >= 1.0:
		_done = true
		finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()


## Change shown by the counter: drawdown from the peak so far when below it, else gain.
func counter(upto: int) -> float:
	if upto < 1:
		return 0.0
	var peak: float = values[0]
	for i: int in upto + 1:
		peak = maxf(peak, values[i])
	return values[upto] / peak - 1.0 if values[upto] < peak else values[upto] / values[0] - 1.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	if values.size() < 2:
		return
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var lo: float = values[0]
	var hi: float = values[0]
	for v: float in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var plot := Rect2(PAD, size - PAD * 2.0)
	var to_y := func(v: float) -> float:
		var t: float = (log(v) - log(lo)) / maxf(log(hi) - log(lo), 1e-9) if log_scale else (v - lo) / maxf(hi - lo, 1e-9)
		return roundf(plot.end.y - t * plot.size.y) + 0.5
	var to_x := func(i: int) -> float:
		return roundf(plot.position.x + float(i) / (values.size() - 1) * plot.size.x) + 0.5
	var upto: int = roundi(progress * (values.size() - 1))
	for p: Array in pins:
		if int(p[0]) <= upto:
			var x: float = to_x.call(int(p[0]))
			draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), UiTheme.PANEL_LIGHT, 1.0, false)
	var points := PackedVector2Array()
	for i: int in upto + 1:
		points.append(Vector2(to_x.call(i), to_y.call(values[i])))
	if points.size() > 1:
		var c: float = counter(upto)
		draw_polyline(points, UiTheme.UP if c >= 0.0 else UiTheme.DOWN, -1.0, false)
	var change: float = counter(upto)
	draw_string(font, Vector2(PAD.x, 11), "%s  %s" % [dates[upto], Fmt.signed_percent(change)], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.UP if change >= 0.0 else UiTheme.DOWN)
	draw_string(font, Vector2(PAD.x, size.y - 2), dates[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
	draw_string(font, Vector2(size.x - 64, size.y - 2), dates[-1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
