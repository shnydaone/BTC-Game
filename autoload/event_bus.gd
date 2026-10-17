extends Node
## Signals from the sim to presentation. Scenes and UI listen here and never compute
## economics. sim_event carries every DayResult event (its "type" is a past-tense name
## such as block_found or exchange_failed); the typed signals cover the common ones.

signal day_simulated(result: DayResult)
signal sim_event(event: Dictionary)
signal difficulty_adjusted(height: int, difficulty: float, change: float)
signal subsidy_halved(height: int, subsidy_sats: int)
signal speed_changed(speed_index: int, paused: bool)
signal game_started(sim: Sim)
signal game_stopped()
signal command_applied(command: Dictionary, result: Dictionary)
signal game_saved(slot: String)
signal choice_made(kind: String, choice: String)  # a card choice with real alternatives


func relay(result: DayResult) -> void:
	for e: Dictionary in result.events:
		match e["type"]:
			"difficulty_adjusted":
				difficulty_adjusted.emit(e["height"], e["difficulty"], e["change"])
			"subsidy_halved":
				subsidy_halved.emit(e["height"], e["subsidy_sats"])
		sim_event.emit(e)
	day_simulated.emit(result)
