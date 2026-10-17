class_name GameData
extends RefCounted
## Everything the sim reads from data/: history, events, hardware, protocol constants
## and tuning. Loaded once; read-only after loading.
##
## Tuning reads are recorded so a test can flag tuning values nothing uses.

const DEFAULT_ROOT: String = "res://data/"
const HISTORY_FILE: String = "history/btc_daily.csv"
const EVENTS_FILE: String = "events/historical.json"
const HARDWARE_FILE: String = "hardware/hardware.json"
const PROTOCOL_FILE: String = "protocol/consensus.json"
const TUNING_DIR: String = "tuning/"

static var _shared: GameData

var root: String
var history: History
var events: Array = []
var hardware: Array = []
var tuning_reads: Dictionary = {}  # "file.key" -> true

var _protocol: Dictionary = {}
var _tuning: Dictionary = {}  # file name without extension -> values dictionary
var _ok: bool = false


## The dataset under res://data, loaded on first use and shared afterwards.
static func shared() -> GameData:
	if _shared == null:
		_shared = GameData.load_from(DEFAULT_ROOT)
	return _shared


static func load_from(data_root: String) -> GameData:
	var d := GameData.new()
	d.root = data_root
	d._ok = d._load()
	return d


func is_ok() -> bool:
	return _ok


func protocol(key: String) -> Variant:
	if not _protocol.has(key):
		push_error("GameData: no protocol value %s" % key)
		return null
	return _protocol[key]["value"]


func protocol_int(key: String) -> int:
	return int(protocol(key))


func protocol_float(key: String) -> float:
	return float(protocol(key))


func tuning(file: String, key: String) -> Variant:
	if not _tuning.has(file) or not _tuning[file].has(key):
		push_error("GameData: no tuning value %s.%s" % [file, key])
		return null
	tuning_reads["%s.%s" % [file, key]] = true
	return _tuning[file][key]["value"]


func has_tuning(file: String, key: String) -> bool:
	return _tuning.has(file) and _tuning[file].has(key)


## Every "file.key" in data/tuning, for the unused-value check.
func tuning_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	for file: String in _tuning:
		for key: String in _tuning[file]:
			keys.append("%s.%s" % [file, key])
	return keys


func _load() -> bool:
	history = History.load_csv(root + HISTORY_FILE)
	var events_doc: Variant = _read_json(root + EVENTS_FILE)
	var hardware_doc: Variant = _read_json(root + HARDWARE_FILE)
	var protocol_doc: Variant = _read_json(root + PROTOCOL_FILE)
	if history == null or events_doc == null or hardware_doc == null or protocol_doc == null:
		return false
	events = events_doc["events"]
	hardware = hardware_doc["units"]
	_protocol = protocol_doc["values"]
	var dir := DirAccess.open(root + TUNING_DIR)
	if dir == null:
		push_error("GameData: no tuning directory under %s" % root)
		return false
	for file: String in dir.get_files():
		if file.get_extension() != "json":
			continue
		var doc: Variant = _read_json(root + TUNING_DIR + file)
		if doc == null:
			return false
		_tuning[file.get_basename()] = doc["values"]
	return true


static func _read_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		push_error("GameData: cannot read %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: invalid JSON in %s" % path)
	return parsed
