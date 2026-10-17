class_name RightPanel
extends PanelContainer
## The right-hand tabs (GDD 12.3): Market, Hardware, Sites & Power, Finance, Treasury,
## Codex. Two rows of tab buttons, a status line for command feedback, and the panel.

const TABS: Array[Array] = [
	["Market", "MarketPanel"], ["Hardware", "HardwarePanel"], ["Sites & Power", "SitesPanel"],
	["Finance", "FinancePanel"], ["Treasury", "TreasuryPanel"], ["Codex", "CodexPanel"],
]

const SCROLLBAR_ROOM: int = 10

var host: Control
var status := Label.new()
var _buttons: Array[Button] = []
var _panels: Array[SidePanel] = []


func _init(dialog_host: Control) -> void:
	host = dialog_host


func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	status.add_theme_color_override("font_color", UiTheme.DOWN)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", SCROLLBAR_ROOM)
	scroll.add_child(margin)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	for i: int in TABS.size():
		var b := UiTheme.button(TABS[i][0], func() -> void: show_tab(i))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		_buttons.append(b)
		var panel: SidePanel = _make(TABS[i][1])
		panel.host = host
		panel.status = status
		panel.visible = false
		stack.add_child(panel)
		_panels.append(panel)
	show_tab(1)


func _make(class_id: String) -> SidePanel:
	match class_id:
		"MarketPanel":
			return MarketPanel.new()
		"HardwarePanel":
			return HardwarePanel.new()
		"SitesPanel":
			return SitesPanel.new()
		"FinancePanel":
			return FinancePanel.new()
		"TreasuryPanel":
			return TreasuryPanel.new()
	return CodexPanel.new()


func show_tab(index: int) -> void:
	status.text = ""
	for i: int in _panels.size():
		_panels[i].visible = i == index
		_buttons[i].set_pressed_no_signal(i == index)


func panel(index: int) -> SidePanel:
	return _panels[index]
