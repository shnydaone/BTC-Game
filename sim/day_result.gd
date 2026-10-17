class_name DayResult
extends RefCounted
## What happened on one simulated day. Sim.step_day() returns one; the GameClock autoload
## relays its events onto EventBus signals of the same (past tense) name.

var day_index: int
var date: String
var events: Array[Dictionary] = []


func _init(index: int, iso_date: String) -> void:
	day_index = index
	date = iso_date


func add(type: String, payload: Dictionary = {}) -> void:
	var e: Dictionary = payload.duplicate()
	e["type"] = type
	events.append(e)


func of_type(type: String) -> Array[Dictionary]:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)
