class_name MarketPanel
extends SidePanel
## The price chart and the network numbers that drive mining revenue.

const CHART_HEIGHT: int = 110

var _chart := MarketChart.new()


## Keeps the chart (and its range and scale) across rebuilds.
func rebuild() -> void:
	if _chart.get_parent() == self:
		remove_child(_chart)
	super.rebuild()


func build(sim: Sim) -> void:
	_chart.custom_minimum_size = Vector2(0, CHART_HEIGHT)
	add_child(_chart)
	_chart.queue_redraw()
	var controls: Array = []
	for r: Array in MarketChart.RANGES:
		var b := UiTheme.button(r[0], func() -> void:
			_chart.range_days = r[1]
			rebuild())
		b.toggle_mode = true
		b.set_pressed_no_signal(_chart.range_days == r[1])
		controls.append(b)
	controls.append(UiTheme.button("Log" if _chart.log_scale else "Linear", func() -> void:
		_chart.log_scale = not _chart.log_scale
		rebuild()))
	buttons(controls)

	section("PRICE")
	var p: float = Readouts.price(sim)
	row("Last close", "--" if is_nan(p) else Fmt.price(p), Readouts.price_tooltip(sim))
	var c: float = Readouts.change_24h(sim)
	if not is_nan(c):
		row("24h", Fmt.signed_percent(c), "", UiTheme.UP if c >= 0.0 else UiTheme.DOWN)
	var hp: float = Readouts.hashprice(sim)
	row("Hashprice", "--" if is_nan(hp) else "%s/TH/day" % Fmt.price(hp), Readouts.hashprice_tooltip(sim))

	section("NETWORK")
	var n: Dictionary = Readouts.network(sim)
	row("World hashrate", Fmt.hashrate(n["world_hs"]), "Everyone else's mining, from the historical record.")
	row("Your share", Fmt.percent(Readouts.share(sim), 3), Readouts.share_tooltip(sim))
	row("Difficulty", Fmt.thousands(roundi(n["difficulty"])) if n["difficulty"] >= 10.0 else "%.2f" % n["difficulty"],
		"Retargets every 2,016 blocks to keep blocks about 10 minutes apart. Your own hashrate pushes it up.")
	row("Blocks today", str(n["blocks_today"]))
	row("Block reward", "%s BTC" % String.num(n["subsidy_btc"], 4), "New coins per block. Halves every 210,000 blocks.")
	row("To next retarget", "%s blocks" % Fmt.thousands(n["blocks_to_retarget"]))
	row("To next halving", "%s blocks" % Fmt.thousands(n["blocks_to_halving"]))
