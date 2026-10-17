class_name ModeSelectScreen
extends CenterContainer
## Choose when you got into Bitcoin (decisions.md 2026-10-16). Placeholder copy until the
## M3-4 content pass.

const MODES: Array[Array] = [
	["slashdot", "Slashdot (default)", "Follow Bitcoin from the Genesis block. You start mining when\nSlashdot covers version 0.3 in July 2010."],
	["cypherpunk", "Cypherpunk (easy)", "Mine from the Genesis block. A laptop left on in 2009\nmakes you a whale. Scores only compare within this mode."],
	["late", "Late to the party (hard)", "Start at the first halving, November 2012, with savings\nand a day job. ASICs are weeks away. No mentor."],
]

var _main: Node


func _init(main: Node) -> void:
	_main = main
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(UiTheme.heading("WHEN DID YOU GET IN?"))
	for m: Array in MODES:
		var row := VBoxContainer.new()
		var b := UiTheme.button(m[1], func() -> void: _main.start_new_game(m[0]))
		row.add_child(b)
		var blurb := UiTheme.dim(Label.new())
		blurb.text = m[2]
		row.add_child(blurb)
		box.add_child(row)
	box.add_child(UiTheme.button("Back", _main.show_title))
	(box.get_child(1).get_child(0) as Button).grab_focus()
