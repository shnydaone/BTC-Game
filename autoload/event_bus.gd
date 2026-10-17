extends Node
## Signals from the sim to presentation. Scenes and UI listen here and never compute
## economics. Signal names match DayResult event types.

signal day_simulated(result: DayResult)
signal difficulty_adjusted(height: int, difficulty: float, change: float)
signal subsidy_halved(height: int, subsidy_sats: int)
signal speed_changed(speed_index: int, paused: bool)


func relay(result: DayResult) -> void:
	for e: Dictionary in result.events:
		match e["type"]:
			"difficulty_adjusted":
				difficulty_adjusted.emit(e["height"], e["difficulty"], e["change"])
			"subsidy_halved":
				subsidy_halved.emit(e["height"], e["subsidy_sats"])
			_:
				push_warning("EventBus: no signal for sim event %s" % e["type"])
	day_simulated.emit(result)
