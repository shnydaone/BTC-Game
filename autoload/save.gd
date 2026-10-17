extends Node
## Save and load: the sim's state as JSON under user://saves/.

const SAVE_DIR: String = "user://saves/"


func save_game(sim: Sim, slot: String) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SAVE_DIR + slot + ".json", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(sim))
	return OK


func load_game(slot: String) -> Sim:
	var text: String = FileAccess.get_file_as_string(SAVE_DIR + slot + ".json")
	if text == "":
		push_error("Save: no save in slot %s" % slot)
		return null
	return from_json(text)


## Full precision keeps every float exact across a save and load.
static func to_json(sim: Sim) -> String:
	return JSON.stringify(sim.to_dict(), "", true, true)


static func from_json(text: String) -> Sim:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Save: unreadable save")
		return null
	return Sim.restore(GameData.shared(), parsed)
