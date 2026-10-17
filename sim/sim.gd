class_name Sim
extends RefCounted
## The simulation. Pure: no Nodes, no autoloads, runs headless.
##
## step_day() is the only thing that advances time. Systems run in a fixed order each day
## and report what happened in the returned DayResult. Player actions go in through
## apply() between days. Systems hold only configuration; all state lives in SimState.

var data: GameData
var consensus: Consensus
var network: Network
var events: Events
var hardware: Hardware
var sites: Sites
var power: Power
var mining: Mining
var finance: Finance
var market: Market
var custody: Custody
var treasury: Treasury
var offers: Offers
var objectives: Objectives
var restructuring: Restructuring
var state: SimState
var rng: SimRng


func _init(game_data: GameData) -> void:
	data = game_data
	reload_config()


## Rebuilds every system from data, keeping state and RNG. The F12 tuning panel calls
## this after editing values live.
func reload_config() -> void:
	consensus = Consensus.new(data)
	network = Network.new(data, consensus)
	events = Events.new(data)
	hardware = Hardware.new(data)
	sites = Sites.new(data)
	power = Power.new()
	mining = Mining.new(data)
	finance = Finance.new(data)
	market = Market.new(data)
	custody = Custody.new(data)
	treasury = Treasury.new(data)
	offers = Offers.new(data)
	objectives = Objectives.new(data)
	restructuring = Restructuring.new(data)


## An empty mode_id starts the default mode.
static func new_game(game_data: GameData, mode_id: String, seed_value: int) -> Sim:
	var sim := Sim.new(game_data)
	if mode_id == "":
		mode_id = game_data.tuning("modes", "default_mode")
	var mode: Dictionary = game_data.tuning("modes", mode_id)
	var s := SimState.new()
	sim.state = s
	sim.rng = SimRng.new(seed_value)
	s.mode_id = mode_id
	s.day_index = game_data.history.index_of(mode["clock_start"])
	s.network = sim.network.initial_state(s.day_index)
	s.objectives.act = int(mode["start_act"])
	s.finance.cash_cents = sim.finance.savings_cents
	sim.finance.set_living(s, sim.finance.default_living)
	s.hardware.site_id = sim.sites.starting_site
	s.mining.mode = sim.mining.default_mode
	s.market.policy = game_data.tuning("treasury", "default_policy")
	for unit_id: String in mode["starting_hardware"]:
		sim.hardware.add_lot(s, unit_id, 1, 0, s.day_index)
	if bool(mode["mining_unlocked_at_start"]):
		Events.add_feature(s, "mining")
	sim.events.catch_up(sim, s.day_index)
	return sim


static func restore(game_data: GameData, d: Dictionary) -> Sim:
	var state := SimState.from_dict(d["state"])
	if state == null:
		return null
	var sim := Sim.new(game_data)
	sim.state = state
	sim.rng = SimRng.from_dict(d["rng"])
	return sim


func to_dict() -> Dictionary:
	return {"state": state.to_dict(), "rng": rng.to_dict()}


func current_date() -> String:
	return data.history.dates[state.day_index]


func is_finished() -> bool:
	return state.day_index >= data.history.size() or state.objectives.act_lost


func apply(cmd: Dictionary) -> Dictionary:
	return Commands.apply(self, cmd)


func step_day() -> DayResult:
	if is_finished():
		push_error("Sim: the game is over on %s" % data.history.dates[mini(state.day_index, data.history.size() - 1)])
		return null
	var day: int = state.day_index
	var result := DayResult.new(day, data.history.dates[day])
	Ledger.roll(state, result.date, result)
	market.start_day(state)
	var acts_ending: Array[int] = events.step(self, day, result)
	custody.step(self, day, result)
	finance.step(self, day, result)
	hardware.step(self, day, result)
	power.step(self, day, result)
	network.step(state, day, result)
	mining.step(self, day, result)
	treasury.step(self, day, result)
	offers.step(self, day, result)
	objectives.step(self, day, result)
	restructuring.settle(self, day, result)
	for act: int in acts_ending:
		objectives.end_act(self, act, result)
	events.unlock_codex_triggers(self, result)
	state.day_index += 1
	return result
