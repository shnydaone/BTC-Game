class_name HardwarePanel
extends SidePanel
## Mining mode, your machines (power, sell) and the shop (buy new or used).

const QUANTITIES: Array[int] = [1, 5, 10, 25]
const MAX_PAYBACK_SHOWN: float = 3650.0  # beyond ten years, "never"

var _qty: int = 1


func build(sim: Sim) -> void:
	section("MINING")
	var pool_ok: bool = sim.state.events.features.has("pool_mining")
	var mode: String = sim.state.mining.mode
	row("Mode", mode.capitalize(), "Solo: you keep whole blocks when you find one. Pool: steady daily share of expected value, less a %s fee." % Fmt.percent(sim.mining.pool_fee, 0))
	if pool_ok:
		var other: String = "pool" if mode == "solo" else "solo"
		buttons([action("Switch to %s" % other, {"type": "set_mining_mode", "mode": other})])
	var auto: bool = sim.state.hardware.shutoff_unprofitable
	buttons([action("Auto shut-off: %s" % ("on" if auto else "off"), {"type": "set_shutoff_unprofitable", "enabled": not auto}, "",
		"When on, machines that cost more in power than they earn stay off.")])

	section("YOUR MACHINES")
	for m: Dictionary in Readouts.fleet(sim):
		var state_text: String
		if m["arrives"] != "":
			state_text = "arrives %s" % m["arrives"]
		elif not bool(m["powered"]):
			state_text = "switched off"
		else:
			state_text = "%d running%s" % [m["running"], ", %d broken" % m["broken"] if int(m["broken"]) > 0 else ""]
		row("%d x %s" % [m["count"], m["label"]], state_text, Readouts.unit_tooltip(sim, m["unit_id"]))
		if m["arrives"] != "":
			continue
		var each: int = int(m["sale_cents"])
		var lot: int = int(m["lot_id"])
		var list: Array = [action("Off" if bool(m["powered"]) else "On", {"type": "set_powered", "lot_id": lot, "powered": not bool(m["powered"])})]
		if each > 0:
			list.append(action("Sell 1", {"type": "sell_hardware", "lot_id": lot, "count": 1},
				"Sell 1 %s for about %s?" % [m["label"], Fmt.usd(each)], "Used value %s each, book %s for the lot." % [Fmt.usd(each), Fmt.usd(m["book_cents"])]))
			if int(m["count"]) > 1:
				list.append(action("Sell all", {"type": "sell_hardware", "lot_id": lot, "count": m["count"]},
					"Sell all %d %s for about %s?" % [m["count"], m["label"], Fmt.usd(each * int(m["count"]))]))
		buttons(list)

	section("SHOP")
	var shop: Array[String] = Readouts.shop(sim)
	if shop.is_empty():
		note("Nothing for sale yet." if not sim.state.events.features.has("mining") else "Nothing for sale today.")
		return
	var qty_row: Array = []
	for q: int in QUANTITIES:
		var b := UiTheme.button("x%d" % q, func() -> void:
			_qty = q
			rebuild())
		b.toggle_mode = true
		b.set_pressed_no_signal(q == _qty)
		qty_row.append(b)
	buttons(qty_row)
	for unit_id: String in shop:
		var s: Dictionary = Readouts.unit_stats(sim, unit_id)
		var tip: String = Readouts.unit_tooltip(sim, unit_id)
		row(s["label"], Fmt.usd(s["new_cents"]) + " new", tip)
		var detail: String = "%s, %s" % [Fmt.hashrate(s["hashrate_hs"]), Fmt.watts(s["watts"])]
		if not is_nan(s["margin_cents_day"]):
			detail += ", %s/day" % Fmt.usd(roundi(s["margin_cents_day"]))
			detail += ", payback %s" % ("never" if s["payback_days"] > MAX_PAYBACK_SHOWN else "%dd" % ceili(s["payback_days"]))
		note(detail).tooltip_text = tip
		var new_cost: int = sim.hardware.quote_cents(sim, unit_id, _qty, false)
		var used_cost: int = sim.hardware.quote_cents(sim, unit_id, _qty, true)
		buttons([
			action("Buy %d new" % _qty, {"type": "buy_hardware", "unit_id": unit_id, "count": _qty},
				"Buy %d %s new for %s? Arrives in %d days." % [_qty, s["label"], Fmt.usd(new_cost), s["lead_days"]], "", new_cost > sim.state.finance.cash_cents),
			action("Buy %d used" % _qty, {"type": "buy_hardware", "unit_id": unit_id, "count": _qty, "used": true},
				"Buy %d %s used for %s? Arrives today, already aged." % [_qty, s["label"], Fmt.usd(used_cost)], "", used_cost > sim.state.finance.cash_cents),
		])
