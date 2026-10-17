extends Node
## Real-time driver for the sim: turns frame time into game days at the chosen speed and
## relays each DayResult to the EventBus. Holds no economics.

var sim: Sim
var paused: bool = true
var speed_index: int = 0

var _accumulated: float = 0.0


func start(new_sim: Sim) -> void:
	sim = new_sim
	_accumulated = 0.0
	set_paused(false)


func set_paused(value: bool) -> void:
	paused = value
	EventBus.speed_changed.emit(speed_index, paused)


func set_speed(index: int) -> void:
	var speeds: Array = Data.game.tuning("clock", "speed_multipliers")
	speed_index = clampi(index, 0, speeds.size() - 1)
	EventBus.speed_changed.emit(speed_index, paused)


func _process(delta: float) -> void:
	if sim == null or paused or sim.is_finished():
		return
	var game := Data.game
	var seconds_per_day: float = game.tuning("clock", "seconds_per_day_1x")
	var speeds: Array = game.tuning("clock", "speed_multipliers")
	var max_days: int = game.tuning("clock", "max_days_per_frame")
	_accumulated += delta * float(speeds[speed_index])
	var days: int = 0
	while _accumulated >= seconds_per_day and days < max_days and not sim.is_finished():
		_accumulated -= seconds_per_day
		days += 1
		EventBus.relay(sim.step_day())
	if days == max_days:
		_accumulated = 0.0
