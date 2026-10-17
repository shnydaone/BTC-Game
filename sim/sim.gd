class_name Sim
extends RefCounted
## The simulation. Pure: no Nodes, no autoloads, runs headless.
##
## step_day() is the only thing that advances time. Systems run in a fixed order each
## day and report what happened in the returned DayResult.

var data: GameData
var consensus: Consensus
var network: Network
var state: SimState
var rng: SimRng


func _init(game_data: GameData) -> void:
	data = game_data
	consensus = Consensus.new(data)
	network = Network.new(data, consensus)


static func new_game(game_data: GameData, mode_id: String, seed_value: int) -> Sim:
	var sim := Sim.new(game_data)
	var mode: Dictionary = game_data.tuning("modes", mode_id)
	sim.state = SimState.new()
	sim.state.mode_id = mode_id
	sim.state.day_index = game_data.history.index_of(mode["clock_start"])
	sim.state.network = sim.network.initial_state(sim.state.day_index)
	sim.rng = SimRng.new(seed_value)
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
	return state.day_index >= data.history.size()


func step_day() -> DayResult:
	if is_finished():
		push_error("Sim: no history after %s" % data.history.last_date())
		return null
	var day: int = state.day_index
	var result := DayResult.new(day, data.history.dates[day])
	network.step(state, day, result)
	state.day_index += 1
	return result
