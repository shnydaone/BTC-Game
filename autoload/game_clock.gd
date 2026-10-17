extends Node
## Real-time driver for the sim: owns the running game, turns frame time into game days at
## the chosen speed, sends player commands in, and relays each DayResult to the EventBus.
## Holds no economics.

var sim: Sim
var paused: bool = true
var speed_index: int = 0

var _accumulated: float = 0.0


func new_game(mode_id: String, seed_value: int) -> void:
	start(Sim.new_game(Data.game, mode_id, seed_value), true)


## A new game starts paused so the player can look around first.
func start(new_sim: Sim, start_paused: bool = false) -> void:
	sim = new_sim
	_accumulated = 0.0
	EventBus.game_started.emit(sim)
	set_paused(start_paused)


func stop() -> void:
	sim = null
	paused = true
	EventBus.game_stopped.emit()


func set_paused(value: bool) -> void:
	paused = value
	EventBus.speed_changed.emit(speed_index, paused)


func toggle_pause() -> void:
	set_paused(not paused)


func speeds() -> Array:
	return Data.game.tuning("clock", "speed_multipliers")


func set_speed(index: int) -> void:
	speed_index = clampi(index, 0, speeds().size() - 1)
	EventBus.speed_changed.emit(speed_index, paused)


## Every player action goes through here, so the UI and the playtest meter see it.
func apply(cmd: Dictionary) -> Dictionary:
	if sim == null:
		return {"ok": false, "reason": "no game running"}
	var result: Dictionary = sim.apply(cmd)
	EventBus.command_applied.emit(cmd, result)
	return result


## Advances n days at once (tests and the debug fast-forward).
func step_days(n: int) -> void:
	for i: int in n:
		if sim == null or sim.is_finished():
			return
		EventBus.relay(sim.step_day())


func _process(delta: float) -> void:
	if sim == null or paused or sim.is_finished():
		return
	var game := Data.game
	var seconds_per_day: float = game.tuning("clock", "seconds_per_day_1x")
	var max_days: int = game.tuning("clock", "max_days_per_frame")
	_accumulated += delta * float(speeds()[speed_index])
	var days: int = 0
	while _accumulated >= seconds_per_day and days < max_days and not sim.is_finished():
		_accumulated -= seconds_per_day
		days += 1
		EventBus.relay(sim.step_day())
	if days == max_days:
		_accumulated = 0.0
