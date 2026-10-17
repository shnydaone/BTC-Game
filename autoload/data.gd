extends Node
## The game's data, loaded on first use. Thin wrapper so scenes can reach it; the sim
## itself takes a GameData directly and never touches this autoload.

var game: GameData:
	get:
		return GameData.shared()
