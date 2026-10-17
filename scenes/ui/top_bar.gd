class_name TopBar
extends PanelContainer
## Date, time controls, price ticker, cash, BTC, hashrate and network share (GDD 12.3).
## Every value comes from Readouts, with its tooltip.

const SPARK_SIZE := Vector2(40, 10)

var _date := Label.new()
var _speed_buttons: Array[Button] = []
var _price := Label.new()
var _change := Label.new()
var _spark := Sparkline.new()
var _cash := Label.new()
var _btc := Label.new()
var _hash := Label.new()
var _share := Label.new()


func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	row.add_child(_date)
	var pause := UiTheme.button("||", GameClock.toggle_pause)
	pause.tooltip_text = "Pause (Space)"
	pause.toggle_mode = true
	_speed_buttons.append(pause)
	row.add_child(pause)
	var speeds: Array = GameClock.speeds()
	for i: int in speeds.size():
		var b := UiTheme.button("%dx" % int(speeds[i]), func() -> void: _set_speed(i))
		b.toggle_mode = true
		b.tooltip_text = "%dx speed (%d)" % [int(speeds[i]), i + 1]
		_speed_buttons.append(b)
		row.add_child(b)
	for l: Label in [_price, _change]:
		row.add_child(l)
	_spark.custom_minimum_size = SPARK_SIZE
	_spark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_spark)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for l: Label in [_cash, _btc, _hash, _share]:
		row.add_child(l)
	for l: Label in [_date, _price, _change, _cash, _btc, _hash, _share]:
		l.mouse_filter = Control.MOUSE_FILTER_STOP
	EventBus.day_simulated.connect(func(_r: DayResult) -> void: refresh())
	EventBus.command_applied.connect(func(_c: Dictionary, _r: Dictionary) -> void: refresh())
	EventBus.speed_changed.connect(func(_i: int, _p: bool) -> void: _refresh_speed())
	refresh()
	_refresh_speed()


func _set_speed(i: int) -> void:
	GameClock.set_speed(i)
	GameClock.set_paused(false)


func _refresh_speed() -> void:
	_speed_buttons[0].set_pressed_no_signal(GameClock.paused)
	for i: int in range(1, _speed_buttons.size()):
		_speed_buttons[i].set_pressed_no_signal(not GameClock.paused and GameClock.speed_index == i - 1)


func refresh() -> void:
	var sim: Sim = GameClock.sim
	if sim == null:
		return
	_date.text = Readouts.date(sim)
	_date.tooltip_text = Readouts.date_tooltip(sim)
	var p: float = Readouts.price(sim)
	_price.text = "BTC %s" % ("--" if is_nan(p) else Fmt.price(p))
	_price.tooltip_text = Readouts.price_tooltip(sim)
	var c: float = Readouts.change_24h(sim)
	_change.text = "" if is_nan(c) else Fmt.signed_percent(c)
	_change.add_theme_color_override("font_color", UiTheme.UP if c >= 0.0 else UiTheme.DOWN)
	_change.tooltip_text = _price.tooltip_text
	_spark.set_values(Readouts.sparkline(sim))
	_spark.tooltip_text = "Last %d closes." % Readouts.SPARKLINE_DAYS
	_cash.text = Fmt.usd(Readouts.cash_cents(sim))
	_cash.tooltip_text = Readouts.cash_tooltip(sim)
	var on_exchange: int = Readouts.exchange_sats(sim)
	_btc.text = "%s BTC" % Fmt.btc(sim.custody.total_sats(sim.state))
	if on_exchange > 0:
		_btc.text += " (%s exch)" % Fmt.btc(on_exchange)
	_btc.tooltip_text = Readouts.btc_tooltip(sim)
	_hash.text = Fmt.hashrate(Readouts.hashrate_hs(sim))
	_hash.tooltip_text = Readouts.hashrate_tooltip(sim)
	_share.text = Fmt.percent(Readouts.share(sim), 2)
	_share.tooltip_text = Readouts.share_tooltip(sim)
