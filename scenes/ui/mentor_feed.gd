class_name MentorFeed
extends Node
## Delivers the mentor's Act 1 messages (data/mentor/act1.json, GDD 11.2) to the inbox,
## with a toast, or as a card when the message pauses. Each message fires once per game:
## delivered ids live in SimState.ui_seen so a loaded game does not repeat them. Modes
## without a mentor (Late to the party) get none.

const SEEN_PREFIX: String = "mentor:"

var screen: Control


func _init(owner_screen: Control) -> void:
	screen = owner_screen


func _ready() -> void:
	EventBus.day_simulated.connect(_on_day)


static func has_mentor(sim: Sim) -> bool:
	return bool(sim.data.tuning("modes", sim.state.mode_id)["mentor"])


## Messages due today, in file order; marks expired ones as seen so they never fire late.
static func due(sim: Sim, result: DayResult) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_mentor(sim):
		return out
	var mining: bool = sim.state.events.features.has("mining")
	for m: Dictionary in sim.data.mentor:
		var key: String = SEEN_PREFIX + String(m["id"])
		if sim.state.ui_seen.has(key):
			continue
		if m.has("modes") and not (m["modes"] as Array).has(sim.state.mode_id):
			continue
		if m.has("mining") and bool(m["mining"]) != mining:
			continue
		if m.has("expires") and result.date > String(m["expires"]):
			sim.state.ui_seen.append(key)
			continue
		var fires: bool = false
		if m.has("date"):
			fires = result.date >= String(m["date"])
		elif m.has("sim_event"):
			fires = not result.of_type(m["sim_event"]).is_empty()
		if fires:
			sim.state.ui_seen.append(key)
			out.append(m)
	return out


func _on_day(result: DayResult) -> void:
	var sim: Sim = GameClock.sim
	if sim == null:
		return
	var handle: String = Readouts.mentor_handle(sim)
	for m: Dictionary in due(sim, result):
		screen.inbox.add(result.date, {"kind": "mentor", "text": "%s: %s. %s" % [handle, m["subject"], m["text"]]})
		if bool(m.get("pause", false)):
			screen.moments.push({"kind": "mentor", "title": "%s: %s" % [handle, m["subject"]], "date": result.date, "body": [String(m["text"])]})
		else:
			screen.toast("New message from %s (I)" % handle)
