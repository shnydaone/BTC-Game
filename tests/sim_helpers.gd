class_name SimHelpers
extends RefCounted
## Shared setup for sim tests.


static func game(mode_id: String = "slashdot", seed_value: int = 1) -> Sim:
	return Sim.new_game(GameData.shared(), mode_id, seed_value)


## Steps until the next day to simulate is iso_date. Returns every event on the way.
static func run_until(sim: Sim, iso_date: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	while sim.current_date() < iso_date and not sim.is_finished():
		events.append_array(sim.step_day().events)
	return events


static func of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


static func lot_of(sim: Sim, unit_id: String) -> SimState.Lot:
	for lot: SimState.Lot in sim.state.hardware.lots:
		if lot.unit_id == unit_id:
			return lot
	return null


static func btc(sats: int) -> float:
	return sats / 1.0e8
