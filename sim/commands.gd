class_name Commands
extends RefCounted
## Every player action, from the UI or a bot, enters the sim here between days.
## A command is a Dictionary with a "type" and its arguments. apply() returns
## {"ok": bool, "reason": String} plus any details from the system that handled it.

const TYPES: PackedStringArray = [
	"buy_hardware", "sell_hardware", "set_powered", "set_shutoff_unprofitable", "move_site",
	"set_mining_mode", "sell_btc", "buy_btc", "transfer_btc", "set_exchange", "backup_wallet",
	"set_treasury_policy", "accept_offer", "decline_offer",
	"quit_job", "rejoin_job", "incorporate", "take_loan", "choose_living",
]


static func apply(sim: Sim, cmd: Dictionary) -> Dictionary:
	if sim.is_finished():
		return _result("the game is over")
	var type: String = cmd.get("type", "")
	match type:
		"buy_hardware":
			return sim.hardware.buy(sim, cmd["unit_id"], int(cmd.get("count", 1)), bool(cmd.get("used", false)))
		"sell_hardware":
			return sim.hardware.sell(sim, int(cmd["lot_id"]), int(cmd.get("count", 1)))
		"set_powered":
			return _result(sim.hardware.set_powered(sim, int(cmd["lot_id"]), bool(cmd["powered"])))
		"set_shutoff_unprofitable":
			sim.state.hardware.shutoff_unprofitable = bool(cmd["enabled"])
			return _result("")
		"move_site":
			return _result(sim.sites.move(sim, cmd["site_id"]))
		"set_mining_mode":
			return _result(sim.mining.set_mode(sim, cmd["mode"]))
		"sell_btc":
			return sim.market.sell(sim, int(cmd["sats"]))
		"buy_btc":
			return sim.market.buy(sim, int(cmd["cents"]))
		"transfer_btc":
			return _result(sim.custody.transfer(sim, cmd["from"], cmd["to"], int(cmd["sats"])))
		"set_exchange":
			return _result(sim.custody.set_active_exchange(sim, cmd["exchange"]))
		"backup_wallet":
			return _result(sim.custody.backup_wallet(sim))
		"set_treasury_policy":
			return _result(sim.treasury.set_policy(sim, cmd["policy"], float(cmd.get("percent", 0.0))))
		"accept_offer":
			return _result(sim.offers.accept(sim, int(cmd["id"])))
		"decline_offer":
			return _result(sim.offers.decline(sim, int(cmd["id"])))
		"quit_job":
			return _result(sim.finance.quit_job(sim))
		"rejoin_job":
			return _result(sim.finance.rejoin_job(sim))
		"incorporate":
			return _result(sim.finance.incorporate(sim))
		"take_loan":
			return _result(sim.finance.take_loan(sim))
		"choose_living":
			return _result(sim.finance.choose_living(sim, cmd["situation"]))
	return _result("unknown command %s" % type)


static func _result(reason: String) -> Dictionary:
	return {"ok": reason == "", "reason": reason}
