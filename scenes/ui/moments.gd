class_name Moments
extends Node
## The auto-pause queue (GDD 5): historical events flagged auto_pause or with a replay,
## offers with deadlines, the quit-job goal, cure-clock warnings, act ends, Chapter 11 and
## act lost all pause the clock and show a card, one at a time. When the last card is
## dismissed the clock resumes if it was running. Difficulty adjustments stay toasts.

var screen: Control
var enabled: bool = true
var queue: Array[Dictionary] = []
var current: CardView

var _resume: bool = false


func _init(owner_screen: Control) -> void:
	screen = owner_screen


func _ready() -> void:
	EventBus.day_simulated.connect(_on_day)


func _on_day(result: DayResult) -> void:
	if GameClock.sim == null:
		return
	for spec: Dictionary in Cards.from_day(GameClock.sim, result, screen):
		push(spec)


func push(spec: Dictionary) -> void:
	if not enabled:
		return
	queue.append(spec)
	if current == null:
		_resume = not GameClock.paused
		_show_next()


func _show_next() -> void:
	if queue.is_empty():
		if _resume:
			GameClock.set_paused(false)
		_resume = false
		return
	GameClock.set_paused(true)
	current = CardView.new(queue.pop_front(), self)
	screen.add_child(current)


func finished(card: CardView) -> void:
	if card != current:
		return
	current = null
	_show_next()


func is_showing() -> bool:
	return current != null and is_instance_valid(current)


## Drops every pending card (tests, skipping the prologue).
func clear() -> void:
	queue.clear()
	if is_showing():
		current.queue_free()
	current = null
	_resume = false
