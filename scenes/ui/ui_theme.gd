class_name UiTheme
extends RefCounted
## The greybox look: flat greys, two pixel fonts, no anti-aliasing. Placeholder until the
## M4 style lock replaces the palette.

const BODY_FONT: String = "res://assets/fonts/monogram.ttf"
const HEADING_FONT: String = "res://assets/fonts/kenney_pixel.ttf"
const BODY_SIZE: int = 16
const HEADING_SIZE: int = 16
const BUTTON_MARGIN: int = 3

const BG := Color("1e1f22")
const PANEL := Color("2a2c30")
const PANEL_LIGHT := Color("3a3d42")
const BORDER := Color("50545a")
const TEXT := Color("d6d8db")
const TEXT_DIM := Color("8b9096")
const UP := Color("7fbf7f")
const DOWN := Color("d47272")
const ACCENT := Color("e0c060")
const MACHINE_ON := Color("b9bdc2")
const MACHINE_OFF := Color("5d6168")
const MACHINE_BROKEN := Color("d47272")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func body_font() -> Font:
	return get_theme().default_font


static func heading_font() -> Font:
	return _crisp(load(HEADING_FONT))


static func _crisp(font: FontFile) -> FontFile:
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	font.multichannel_signed_distance_field = false
	return font


static func _box(color: Color, border: Color = Color.TRANSPARENT, margin: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.anti_aliasing = false
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = _crisp(load(BODY_FONT))
	t.default_font_size = BODY_SIZE
	for type: String in ["Label", "Button", "LinkButton", "TooltipLabel", "RichTextLabel"]:
		t.set_color("font_color", type, TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, BORDER, BUTTON_MARGIN))
	t.set_stylebox("hover", "Button", _box(BORDER, TEXT_DIM, BUTTON_MARGIN))
	t.set_stylebox("pressed", "Button", _box(PANEL, ACCENT, BUTTON_MARGIN))
	t.set_stylebox("disabled", "Button", _box(PANEL, PANEL_LIGHT, BUTTON_MARGIN))
	t.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, ACCENT, BUTTON_MARGIN))
	t.set_stylebox("panel", "Panel", _box(PANEL, BORDER))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 4))
	t.set_stylebox("panel", "TooltipPanel", _box(BG, ACCENT, 4))
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("separation", "VBoxContainer", 3)
	return t


## A label with the theme's dim color.
static func dim(label: Label) -> Label:
	label.add_theme_color_override("font_color", TEXT_DIM)
	return label


static func heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", heading_font())
	l.add_theme_font_size_override("font_size", HEADING_SIZE)
	l.add_theme_color_override("font_color", ACCENT)
	return l


static func button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(pressed)
	return b
