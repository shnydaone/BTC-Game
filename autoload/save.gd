extends Node
## Save and load: the sim's state as JSON under user://saves/. Autosaves at the start of
## each act (when the previous one ends).

const SAVE_DIR: String = "user://saves/"
const AUTOSAVE: String = "autosave"
const MANUAL_SLOTS: PackedStringArray = ["slot1", "slot2", "slot3"]

## Tests point this elsewhere so they never touch a player's saves.
var save_dir: String = SAVE_DIR


func _ready() -> void:
	EventBus.sim_event.connect(_on_sim_event)


func _on_sim_event(e: Dictionary) -> void:
	if e["type"] == "act_ended" and GameClock.sim != null:
		save_game(GameClock.sim, AUTOSAVE)


func save_game(sim: Sim, slot: String) -> Error:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(sim))
	f.close()
	EventBus.game_saved.emit(slot)
	return OK


func load_game(slot: String) -> Sim:
	var text: String = FileAccess.get_file_as_string(path(slot))
	if text == "":
		push_error("Save: no save in slot %s" % slot)
		return null
	return from_json(text)


func path(slot: String) -> String:
	return save_dir + slot + ".json"


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(path(slot))


## What a slot holds, for the load menu: {"slot", "date", "mode", "modified"}; empty if none.
func describe(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if not parsed is Dictionary:
		return {}
	var state: Dictionary = parsed["state"]
	var day: int = int(state["day_index"])
	var h: History = GameData.shared().history
	return {
		"slot": slot,
		"date": h.dates[mini(day, h.size() - 1)],
		"mode": String(state["mode_id"]),
		"modified": FileAccess.get_modified_time(path(slot)),
	}


## The most recently written save, or "".
func latest_slot() -> String:
	var best: String = ""
	var best_time: int = -1
	for slot: String in [AUTOSAVE] + Array(MANUAL_SLOTS):
		if has_save(slot) and FileAccess.get_modified_time(path(slot)) > best_time:
			best_time = FileAccess.get_modified_time(path(slot))
			best = slot
	return best


## Full precision keeps every float exact across a save and load.
static func to_json(sim: Sim) -> String:
	return JSON.stringify(sim.to_dict(), "", true, true)


static func from_json(text: String) -> Sim:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Save: unreadable save")
		return null
	return Sim.restore(GameData.shared(), parsed)
