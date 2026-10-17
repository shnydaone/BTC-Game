class_name LaptopWhaleBot
extends Bot
## Measurement bot for the 2009 stack (decisions.md 2026-10-16), meant for Cypherpunk
## mode. Keeps the starting laptop running, optionally adds one desktop on day one, never
## sells and keeps every coin cold. It has no pass/fail outcome; run_bots.gd reports
## what it holds.

var with_desktop: bool


func _init(add_desktop: bool = true) -> void:
	with_desktop = add_desktop
	name = "laptop_whale_desktop" if add_desktop else "laptop_whale"


func decide(sim: Sim) -> void:
	if with_desktop and sim.state.hardware.lots.size() == 1 and sim.hardware.is_available(sim, "cpu_desktop"):
		sim.apply({"type": "buy_hardware", "unit_id": "cpu_desktop", "count": 1})
