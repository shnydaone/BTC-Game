class_name DecisionMeter
extends Label
## Playtest instrument for the M3 gate (GDD 15.1): at least one meaningful decision per 2
## real minutes. A decision is a successful player command or a card choice with real
## alternatives. F3 shows the overlay; every session also logs to
## user://playtest/session_<time>.csv (seconds, game date, decision).

const WINDOW_SECONDS: float = 120.0
const LOG_DIR: String = "user://playtest/"

var decisions: Array[Dictionary] = []  # {t, date, what}
var _start_ms: int
var _log_path: String = ""


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color", UiTheme.ACCENT)
	add_theme_stylebox_override("normal", _bg())
	EventBus.command_applied.connect(func(cmd: Dictionary, r: Dictionary) -> void:
		if r["ok"]:
			record(String(cmd["type"])))
	EventBus.choice_made.connect(func(kind: String, choice: String) -> void: record("%s: %s" % [kind, choice]))


func _bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.75)
	s.set_content_margin_all(3)
	return s


func elapsed() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


func record(what: String) -> void:
	var d: Dictionary = {"t": elapsed(), "date": Readouts.date(GameClock.sim) if GameClock.sim != null else "", "what": what}
	decisions.append(d)
	_log(d)
	refresh()


## Decisions per WINDOW_SECONDS of real time so far, the gate's measure.
func rate() -> float:
	var minutes_window: float = maxf(elapsed(), 1.0) / WINDOW_SECONDS
	return decisions.size() / minutes_window


## Longest real-time stretch without a decision, counting the time since the last one.
func longest_gap() -> float:
	var gap: float = 0.0
	var last: float = 0.0
	for d: Dictionary in decisions:
		gap = maxf(gap, float(d["t"]) - last)
		last = float(d["t"])
	return maxf(gap, elapsed() - last)


func refresh() -> void:
	if not visible:
		return
	var recent: PackedStringArray = []
	for i: int in range(maxi(0, decisions.size() - 4), decisions.size()):
		recent.append("%4ds %s" % [int(decisions[i]["t"]), decisions[i]["what"]])
	text = "PLAYTEST (F3)  %d decisions in %.1f min = %.2f per 2 min (gate: 1.0)\nlongest gap %ds\n%s" % [
		decisions.size(), elapsed() / 60.0, rate(), int(longest_gap()), "\n".join(recent)]


func _process(_delta: float) -> void:
	if visible and Engine.get_process_frames() % 30 == 0:
		refresh()


func toggle() -> void:
	visible = not visible
	refresh()


func _log(d: Dictionary) -> void:
	if _log_path == "":
		DirAccess.make_dir_recursive_absolute(LOG_DIR)
		_log_path = LOG_DIR + "session_%s.csv" % Time.get_datetime_string_from_system().replace(":", "-")
		var header := FileAccess.open(_log_path, FileAccess.WRITE)
		if header == null:
			return
		header.store_line("seconds,game_date,decision")
		header.close()
	var f := FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%.1f,%s,%s" % [d["t"], d["date"], String(d["what"]).replace(",", ";")])
	f.close()
