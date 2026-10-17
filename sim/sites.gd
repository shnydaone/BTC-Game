class_name Sites
extends RefCounted
## Where the machines run (GDD 7.3): each site caps power in kW and sets the power price,
## PUE and rent. Acts 1-2 have the bedroom, the garage and, from Act 2, a leased warehouse.

const WATTS_PER_KW: float = 1000.0

var sites: Dictionary  # site id -> {capacity_kw, power_usd_per_kwh, pue, rent_usd_month, move_cost_usd, available_act}
var starting_site: String


func _init(data: GameData) -> void:
	sites = data.tuning("sites", "sites")
	starting_site = data.tuning("sites", "starting_site")


func site(state: SimState) -> Dictionary:
	return sites[state.hardware.site_id]


func capacity_w(state: SimState) -> float:
	return float(site(state)["capacity_kw"]) * WATTS_PER_KW


func rent_cents(state: SimState) -> int:
	return Finance.usd_to_cents(site(state)["rent_usd_month"])


func move(sim: Sim, site_id: String) -> String:
	if not sites.has(site_id):
		return "no site %s" % site_id
	if site_id == sim.state.hardware.site_id:
		return "already there"
	var cfg: Dictionary = sites[site_id]
	if sim.state.objectives.act < int(cfg["available_act"]):
		return "%s unlocks in act %d" % [site_id, int(cfg["available_act"])]
	if bool(cfg["requires_incorporation"]) and not sim.state.finance.incorporated:
		return "%s needs a company" % site_id
	var cost: int = Finance.usd_to_cents(cfg["move_cost_usd"])
	if cost > sim.state.finance.cash_cents:
		return "not enough cash"
	Finance.debit(sim.state, cost, "site_move")
	sim.state.hardware.site_id = site_id
	return ""
