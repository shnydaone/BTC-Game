class_name NewsTicker
extends Control
## The bottom news ticker (GDD 12.3): recent headlines and your own news scroll left in
## a loop. Runs in real time, so it keeps moving while the game is paused.

const SPEED_PX_PER_SEC: float = 30.0
const KEEP: int = 8
const SEPARATOR: String = "     *     "

var _items: Array[String] = []
var _text: String = ""
var _offset: float = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	push("Press Space or a speed button to start the clock.")


func push(line: String) -> void:
	_items.push_front(line)
	if _items.size() > KEEP:
		_items.pop_back()
	_text = SEPARATOR.join(_items) + SEPARATOR
	_offset = 0.0
	queue_redraw()


func text() -> String:
	return _text


func _process(delta: float) -> void:
	_offset += delta * SPEED_PX_PER_SEC
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()
	var width: float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if width <= 0.0:
		return
	var x: float = -fmod(_offset, width)
	var baseline: float = roundf((size.y + font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	while x < size.x:
		draw_string(font, Vector2(roundf(x), baseline), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT_DIM)
		x += width
