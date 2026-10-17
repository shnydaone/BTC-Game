class_name TreasuryPanel
extends SidePanel
## Where your BTC sits, moving it, trading within today's limit, the standing policy,
## and trade offers (GDD 7.6). Not your keys, not your coins.

const FRACTIONS: Array[float] = [0.1, 0.5, 1.0]


func build(sim: Sim) -> void:
	section("HOLDINGS")
	row("Cold storage", Fmt.btc(Readouts.cold_sats(sim)) + " BTC", "Safe. Takes a day to reach an exchange.")
	var exchanges: Array[Dictionary] = Readouts.exchanges(sim)
	for e: Dictionary in exchanges:
		row(String(e["label"]) + (" (active)" if bool(e["active"]) else ""), Fmt.btc(e["sats"]) + " BTC", "Sellable now. Lost if this exchange fails.")
	for t: Dictionary in Readouts.transfers(sim):
		row("Moving to %s" % t["to"], Fmt.btc(t["sats"]) + " BTC", "Arrives %s." % t["arrives"])
	if exchanges.is_empty():
		note("No exchange exists yet. Coins can only be held.")
	var active: String = sim.state.custody.active_exchange
	if exchanges.size() > 1:
		var picks: Array = []
		for e: Dictionary in exchanges:
			if not bool(e["active"]):
				picks.append(action("Use %s" % e["label"], {"type": "set_exchange", "exchange": e["id"]}))
		buttons(picks)
	if active != "":
		var cold: int = Readouts.cold_sats(sim)
		var moves: Array = []
		for f: float in FRACTIONS:
			var sats: int = floori(cold * f)
			moves.append(action("To exch %d%%" % roundi(f * 100.0), {"type": "transfer_btc", "from": "cold", "to": active, "sats": sats}, "", "Move %s BTC from cold storage to %s. Arrives tomorrow." % [Fmt.btc(sats), Readouts.exchange_label(sim, active)], sats <= 0))
		buttons(moves)
		var on_active: int = sim.custody.exchange_balance(sim.state, active)
		buttons([action("Withdraw all to cold", {"type": "transfer_btc", "from": active, "to": "cold", "sats": on_active}, "", "Arrives tomorrow.", on_active <= 0)])
	if bool(sim.custody.wallet_loss_enabled) and not sim.state.custody.backed_up:
		buttons([action("Back up wallet", {"type": "backup_wallet"}, "", "An unbacked wallet can be lost with its disk.")])

	section("TRADE TODAY")
	var lim: Dictionary = Readouts.trade_limits(sim)
	if lim["blocked"] != "":
		note(lim["blocked"])
	else:
		row("Last close", Fmt.price(Readouts.price(sim)), Readouts.price_tooltip(sim))
		row("Sell limit", Fmt.btc(lim["sell_sats"]) + " BTC", "A share of today's real exchange volume, up to what you hold on the exchange. Big sales fill lower (slippage).")
		if Readouts.exchange_sats(sim) == 0 and Readouts.cold_sats(sim) > 0:
			note("Your coins are in cold storage. Move some to the exchange to sell them.")
		var sells: Array = []
		for f: float in FRACTIONS:
			var sats: int = floori(lim["sell_sats"] * f)
			sells.append(action("Sell %d%%" % roundi(f * 100.0), {"type": "sell_btc", "sats": sats},
				"Sell %s BTC at today's close? About %s at the last close, before slippage." % [Fmt.btc(sats), Fmt.usd(Readouts.estimate_sale_cents(sim, sats))], "", sats <= 0))
		buttons(sells)
		row("Buy limit", Fmt.usd(lim["buy_cents"]))
		var buys: Array = []
		for f: float in FRACTIONS:
			var cents: int = mini(floori(sim.state.finance.cash_cents * f), int(lim["buy_cents"]))
			buys.append(action("Spend %s" % Fmt.usd(cents), {"type": "buy_btc", "cents": cents},
				"Spend %s on BTC at today's close?" % Fmt.usd(cents), "", cents <= 0))
		buttons(buys)

	section("STANDING POLICY")
	var policy: String = sim.state.market.policy
	var pct: float = sim.state.market.sell_percent
	row("Now", "sell %s of mining" % Fmt.percent(pct, 0) if policy == "sell_percent" else policy.replace("_", " "),
		"HODL keeps every mined coin cold. Selling policies send mined coins to the active exchange and sell from there.")
	buttons([
		action("HODL", {"type": "set_treasury_policy", "policy": "hodl"}),
		action("Sell 50%", {"type": "set_treasury_policy", "policy": "sell_percent", "percent": 0.5}),
		action("Cover costs", {"type": "set_treasury_policy", "policy": "cover_costs"}, "", "Sells exchange BTC whenever cash drops below %d days of costs." % sim.treasury.buffer_days),
	])

	var offers: Array[Dictionary] = Readouts.offers(sim)
	if not offers.is_empty() or sim.state.offers.spent_sats > 0:
		section("TRADE OFFERS")
	for o: Dictionary in offers:
		var what: String = "two pizzas" if o["kind"] == "pizza" else "goods"
		row("%s for %s BTC" % [what.capitalize(), Fmt.btc(o["sats"])], "until %s" % o["expires"],
			"Saves %s of cash you would have spent anyway." % Fmt.usd(o["value_cents"]))
		buttons([
			action("Accept", {"type": "accept_offer", "id": o["id"]}, "Pay %s BTC for %s worth %s?" % [Fmt.btc(o["sats"]), what, Fmt.usd(o["value_cents"])]),
			action("Decline", {"type": "decline_offer", "id": o["id"]}),
		])
	if sim.state.offers.spent_sats > 0:
		row("Regret counter", Fmt.usd(Readouts.regret_cents(sim)), "What the %s BTC you spent on goods is worth today." % Fmt.btc(sim.state.offers.spent_sats), UiTheme.DOWN)
