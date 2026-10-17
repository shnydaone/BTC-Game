class_name Events
extends RefCounted
## Fires the historical events in data/events/historical.json on their dates and applies
## their effects. Every effect type in the file has a handler here; the Act 3-4 types are
## registered as no-ops until their systems exist (M6).

## Effects whose economics already sit in the historical data, or that only inform.
const INFORMATIONAL: PackedStringArray = [
	"game_start",
	"network_disruption",  # the block counts in btc_daily.csv already include it
	"halving",  # the network applies halvings by height; tests check the heights agree
	"market_shock",  # the size comes from the price history
	"news",
]
## Act 3-4 effects, handled once their systems exist (M6).
const DEFERRED: PackedStringArray = [
	"forked_coins", "margin_pressure", "credit_tightening", "loan_recall",
	"rival_bankruptcy", "bank_freeze", "regional_ban", "investor_demand",
]
const ACTIVE: PackedStringArray = [
	"price_available", "unlock", "codex", "pizza_offer", "exchange_failure", "act_end", "hardware_speedup",
]
## Effects that still apply when a game starts after the event (Late to the party).
const PERSISTENT: PackedStringArray = ["price_available", "unlock", "exchange_failure", "hardware_speedup", "codex"]

var by_day: Dictionary = {}  # day index -> Array of event dictionaries


func _init(data: GameData) -> void:
	for e: Dictionary in data.events:
		var i: int = data.history.index_of(e["date"])
		if i < 0:
			push_error("Events: %s is outside the history" % e["id"])
			continue
		if not by_day.has(i):
			by_day[i] = []
		by_day[i].append(e)


static func handles(effect_type: String) -> bool:
	return INFORMATIONAL.has(effect_type) or DEFERRED.has(effect_type) or ACTIVE.has(effect_type)


static func add_feature(state: SimState, feature: String) -> bool:
	if state.events.features.has(feature):
		return false
	state.events.features.append(feature)
	return true


## Applies the lasting effects of every event before the first simulated day.
func catch_up(sim: Sim, start_day: int) -> void:
	var scratch := DayResult.new(start_day, "")
	for day: int in range(start_day):
		for e: Dictionary in by_day.get(day, []):
			sim.state.events.fired.append(e["id"])
			for fx: Dictionary in e["effects"]:
				if PERSISTENT.has(fx["type"]):
					_apply(sim, e, fx, scratch)


## Fires today's events. Returns the acts that end today; the Sim closes them after the
## day's other systems have run.
func step(sim: Sim, day: int, result: DayResult) -> Array[int]:
	var acts_ending: Array[int] = []
	for e: Dictionary in by_day.get(day, []):
		sim.state.events.fired.append(e["id"])
		result.add("historical_event", {
			"id": e["id"],
			"headline": e["headline"],
			"auto_pause": bool(e["auto_pause"]),
			"replay": e["replay"] != null,
		})
		for fx: Dictionary in e["effects"]:
			if fx["type"] == "act_end":
				acts_ending.append(int(fx["act"]))
			else:
				_apply(sim, e, fx, result)
	return acts_ending


func _apply(sim: Sim, e: Dictionary, fx: Dictionary, result: DayResult) -> void:
	var state: SimState = sim.state
	var type: String = fx["type"]
	match type:
		"price_available":
			add_feature(state, "price")
		"unlock":
			if add_feature(state, fx["feature"]):
				result.add("feature_unlocked", {"feature": fx["feature"]})
		"codex":
			if not state.events.codex.has(fx["entry"]):
				state.events.codex.append(fx["entry"])
				result.add("codex_unlocked", {"entry": fx["entry"]})
		"pizza_offer":
			sim.offers.offer_pizza(sim, result)
		"exchange_failure":
			sim.custody.exchange_failure(sim, fx["counterparty"], float(fx["haircut"]), result)
		"hardware_speedup":
			var t: String = fx["tier"]
			state.hardware.tier_multipliers[t] = state.hardware.tier_multipliers.get(t, 1.0) * float(fx["multiplier"])
			result.add("hardware_sped_up", {"tier": t, "multiplier": float(fx["multiplier"])})
		_:
			if not handles(type):
				push_error("Events: no handler for effect %s in %s" % [type, e["id"]])
