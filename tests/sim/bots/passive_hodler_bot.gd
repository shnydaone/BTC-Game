class_name PassiveHodlerBot
extends Bot
## GDD 14 Passive HODLer: minimal decisions, holds everything. It keeps the starting
## laptop and the day job, mines solo into the cold wallet and never sells or buys.


func _init() -> void:
	name = "passive_hodler"


func decide(_sim: Sim) -> void:
	pass
