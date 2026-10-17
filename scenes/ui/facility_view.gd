class_name FacilityView
extends Control
## Greybox facility (GDD 12.2): the site floor on a 16px grid with one box per machine.
## Light = running, dark = off or idle, red outline = broken, outline only = in transit.
## When the floor is full, the rest of the fleet shows as a count.

const TILE: int = 16
const GAP: int = 1
const HEADER_H: int = 14
const LEGEND_H: int = 12

var _machines: Array[Dictionary] = []
var _site: String = ""
var _used_w: float = 0.0
var _capacity_w: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.day_simulated.connect(func(_r: DayResult) -> void: refresh())
	EventBus.command_applied.connect(func(_c: Dictionary, _r: Dictionary) -> void: refresh())
	resized.connect(queue_redraw)
	refresh()


func refresh() -> void:
	var sim: Sim = GameClock.sim
	if sim == null:
		return
	_machines = Readouts.machines(sim)
	_site = Readouts.site_name(sim)
	_used_w = Readouts.running_w(sim)
	_capacity_w = Readouts.capacity_w(sim)
	tooltip_text = Readouts.power_tooltip(sim)
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fsize: int = get_theme_default_font_size()
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.PANEL)
	# Header: site name and power use.
	draw_string(font, Vector2(4, 11), "%s  %s / %s" % [_site.to_upper(), Fmt.watts(_used_w), Fmt.watts(_capacity_w)], HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, UiTheme.TEXT)
	var bar := Rect2(size.x - 84, 4, 80, 6)
	draw_rect(bar, UiTheme.PANEL_LIGHT)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(_used_w / _capacity_w, 0.0, 1.0)), bar.size.y)), UiTheme.ACCENT)
	# Floor grid.
	var floor := Rect2(4, HEADER_H + 2, size.x - 8, size.y - HEADER_H - LEGEND_H - 4)
	var cols: int = maxi(1, int(floor.size.x) / TILE)
	var rows: int = maxi(1, int(floor.size.y) / TILE)
	for c: int in cols + 1:
		draw_line(Vector2(floor.position.x + c * TILE, floor.position.y), Vector2(floor.position.x + c * TILE, floor.position.y + rows * TILE), UiTheme.BG, 1.0, false)
	for r: int in rows + 1:
		draw_line(Vector2(floor.position.x, floor.position.y + r * TILE), Vector2(floor.position.x + cols * TILE, floor.position.y + r * TILE), UiTheme.BG, 1.0, false)
	# Machines, row by row; each takes footprint tiles side by side.
	var col: int = 0
	var row: int = 0
	var hidden: int = 0
	for m: Dictionary in _machines:
		var states: Array = _unit_states(m)
		for s: String in states:
			var w: int = int(m["tiles"])
			if col + w > cols:
				col = 0
				row += 1
			if row >= rows:
				hidden += 1
				continue
			var r := Rect2(floor.position + Vector2(col * TILE + GAP, row * TILE + GAP), Vector2(w * TILE - 2 * GAP, TILE - 2 * GAP))
			_draw_unit(r, s)
			col += w
	if hidden > 0:
		draw_string(font, Vector2(floor.position.x, floor.end.y + 10), "+%s more machines" % Fmt.thousands(hidden), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, UiTheme.ACCENT)
	else:
		draw_string(font, Vector2(floor.position.x, floor.end.y + 10), "light: running  dark: off  red: broken  outline: arriving", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, UiTheme.TEXT_DIM)


## Per-unit state list for a lot: running first, then idle, then broken.
func _unit_states(m: Dictionary) -> Array:
	var out: Array = []
	if bool(m["in_transit"]):
		out.resize(int(m["count"]))
		out.fill("transit")
		return out
	for i: int in int(m["running"]):
		out.append("on")
	for i: int in int(m["count"]) - int(m["running"]) - int(m["broken"]):
		out.append("off")
	for i: int in int(m["broken"]):
		out.append("broken")
	return out


func _draw_unit(r: Rect2, state: String) -> void:
	match state:
		"on":
			draw_rect(r, UiTheme.MACHINE_ON)
		"off":
			draw_rect(r, UiTheme.MACHINE_OFF)
		"broken":
			draw_rect(r, UiTheme.MACHINE_OFF)
			draw_rect(r, UiTheme.MACHINE_BROKEN, false, 1.0)
		"transit":
			draw_rect(r, UiTheme.MACHINE_ON, false, 1.0)
