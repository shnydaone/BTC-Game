class_name MarketChart
extends Control
## The full price chart (GDD 10): past closes only, log or linear, a range preset, halving
## lines, and your buy and sell days. 1px lines, no anti-aliasing.

const RANGES: Array[Array] = [["3M", 90], ["1Y", 365], ["All", 0]]
const PAD_LEFT: int = 2
const PAD_BOTTOM: int = 10

var log_scale: bool = true
var range_days: int = 365


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.day_simulated.connect(func(_r: DayResult) -> void: queue_redraw())
	EventBus.command_applied.connect(func(_c: Dictionary, _r: Dictionary) -> void: queue_redraw())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	var sim: Sim = GameClock.sim
	if sim == null:
		return
	var h: History = sim.data.history
	var end: int = Readouts.last_close_day(sim)
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	if end < 0:
		draw_string(font, Vector2(4, size.y / 2), "No market exists yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
		return
	var start: int = 0 if range_days == 0 else maxi(0, end - range_days)
	while start < end and not h.has_price(start):
		start += 1
	var lo: float = INF
	var hi: float = 0.0
	for i: int in range(start, end + 1):
		if h.has_price(i):
			lo = minf(lo, h.price_usd[i])
			hi = maxf(hi, h.price_usd[i])
	var plot := Rect2(PAD_LEFT, 1, size.x - PAD_LEFT - 1, size.y - PAD_BOTTOM - 2)
	var to_y := func(p: float) -> float:
		var t: float = (log(p) - log(lo)) / maxf(log(hi) - log(lo), 1e-9) if log_scale else (p - lo) / maxf(hi - lo, 1e-9)
		return roundf(plot.end.y - t * plot.size.y) + 0.5
	var to_x := func(i: int) -> float:
		return roundf(plot.position.x + float(i - start) / maxf(end - start, 1) * plot.size.x) + 0.5
	# Halvings: the days chain height crossed a halving.
	for i: int in range(maxi(start, 1), end + 1):
		if sim.consensus.halvings_at(h.height_end[i]) > sim.consensus.halvings_at(h.height_end[i - 1]):
			draw_line(Vector2(to_x.call(i), plot.position.y), Vector2(to_x.call(i), plot.end.y), UiTheme.PANEL_LIGHT, 1.0, false)
	var points := PackedVector2Array()
	for i: int in range(start, end + 1):
		if h.has_price(i):
			points.append(Vector2(to_x.call(i), to_y.call(h.price_usd[i])))
	if points.size() > 1:
		draw_polyline(points, UiTheme.TEXT, -1.0, false)
	# Your trades.
	for t: SimState.Trade in sim.state.market.trades:
		if t.day < start or t.day > end or not h.has_price(t.day):
			continue
		var p := Vector2(to_x.call(t.day), to_y.call(h.price_usd[t.day]))
		var color: Color = UiTheme.UP if t.side == "buy" else UiTheme.DOWN
		draw_line(p + Vector2(0, -3), p + Vector2(0, 3), color, 1.0, false)
	draw_string(font, Vector2(2, size.y - 1), h.dates[start], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
	draw_string(font, Vector2(size.x - 62, size.y - 1), h.dates[end], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
	draw_string(font, Vector2(4, 10), Fmt.price(hi), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
	draw_string(font, Vector2(4, plot.end.y - 1), Fmt.price(lo), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
	tooltip_text = "Closes %s to %s, %s scale. Grey lines: halvings. Ticks: your buys (green) and sells (red)." % [h.dates[start], h.dates[end], "log" if log_scale else "linear"]
