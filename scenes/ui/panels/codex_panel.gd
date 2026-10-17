class_name CodexPanel
extends SidePanel
## Codex entries unlock on first encounter (GDD 11.1). Titles only until the M3-4
## content pass writes the entries.


func build(sim: Sim) -> void:
	section("CODEX")
	var entries: PackedStringArray = sim.state.events.codex
	if entries.is_empty():
		note("Entries unlock as you meet each idea.")
		return
	for e: String in entries:
		row(Readouts.codex_title(e), "")
	note("Entry text arrives with the M3-4 content pass.")
