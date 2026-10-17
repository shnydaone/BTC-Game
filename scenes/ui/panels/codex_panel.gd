class_name CodexPanel
extends SidePanel
## Codex entries unlock on first encounter (GDD 11.1), newest first.


func build(sim: Sim) -> void:
	section("CODEX")
	var entries: PackedStringArray = sim.state.events.codex
	if entries.is_empty():
		note("Entries unlock as you meet each idea.")
		return
	for i: int in range(entries.size() - 1, -1, -1):
		var l := Label.new()
		l.text = Readouts.codex_title(entries[i])
		add_child(l)
		note(Readouts.codex_text(entries[i]))
