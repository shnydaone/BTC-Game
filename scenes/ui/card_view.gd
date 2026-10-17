class_name CardView
extends CenterContainer
## One card from the moment queue, over a dimmed game: an optional replay chart, the
## headline, the text, impact lines and choices. With a replay, the choices wait until
## the line has drawn (click the chart to skip). Enter picks the first choice.

const WIDTH: int = 460
const CHART_HEIGHT: int = 120
const TEXT_MAX_HEIGHT: int = 150

var spec: Dictionary
var chart: ReplayChart
var _moments: Moments
var _choices: Array[Button] = []


func _init(card: Dictionary, moments: Moments) -> void:
	spec = card
	_moments = moments
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	if spec.has("replay") and GameClock.sim != null:
		chart = ReplayChart.new()
		chart.setup(GameClock.sim, spec["replay"])
		chart.custom_minimum_size = Vector2(WIDTH - 8, CHART_HEIGHT)
		chart.finished.connect(_enable_choices)
		box.add_child(chart)
	var title := UiTheme.heading(String(spec.get("title", "")).to_upper())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = WIDTH - 8
	box.add_child(title)
	if spec.has("date"):
		var d := UiTheme.dim(Label.new())
		d.text = spec["date"]
		box.add_child(d)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	for para: String in spec.get("body", []):
		var l := Label.new()
		l.text = para
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH - 20
		text.add_child(l)
	for line: Array in spec.get("lines", []):
		var row := HBoxContainer.new()
		var k := UiTheme.dim(Label.new())
		k.text = line[0]
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v := Label.new()
		v.text = line[1]
		row.add_child(v)
		text.add_child(row)
	scroll.custom_minimum_size.y = mini(TEXT_MAX_HEIGHT, int(text.get_combined_minimum_size().y) + 2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var choices: Array = spec.get("choices", [{"text": "Continue"}])
	for c: Dictionary in choices:
		var b := UiTheme.button(c["text"], func() -> void: choose(c))
		b.disabled = chart != null
		row.add_child(b)
		_choices.append(b)
	if chart == null:
		_choices[0].grab_focus()


func _enable_choices() -> void:
	for b: Button in _choices:
		b.disabled = false
	_choices[0].grab_focus()


func choose(c: Dictionary) -> void:
	if c.has("cmd"):
		GameClock.apply(c["cmd"])
	queue_free()
	_moments.finished(self)
	if c.has("call"):
		(c["call"] as Callable).call()


## Choice index by its text, for tests and keyboard play.
func choose_text(text: String) -> void:
	for c: Dictionary in spec.get("choices", [{"text": "Continue"}]):
		if c["text"] == text:
			choose(c)
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and chart != null and not chart.is_done():
		chart.skip()
		get_viewport().set_input_as_handled()


## Dims the game behind the card.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
