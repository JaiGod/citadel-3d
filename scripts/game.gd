extends Node
## Autoload "G": settings and saved records (best wave per map/mode, victories).

const SAVE_PATH := "user://citadel3d.cfg"
var sound_on := true
var best := {}
var wins := {}
var plays := 0

func _ready() -> void:
	load_save()

func load_save() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	sound_on = bool(c.get_value("s", "sound", true))
	var b = c.get_value("s", "best", {})
	var w = c.get_value("s", "wins", {})
	best = b if b is Dictionary else {}
	wins = w if w is Dictionary else {}
	plays = int(c.get_value("s", "plays", 0))

func save() -> void:
	var c := ConfigFile.new()
	c.set_value("s", "sound", sound_on)
	c.set_value("s", "best", best)
	c.set_value("s", "wins", wins)
	c.set_value("s", "plays", plays)
	c.save(SAVE_PATH)

func key(map_i: int, mode: String) -> String:
	return "%d:%s" % [map_i, mode]

func get_best(map_i: int, mode: String) -> int:
	return int(best.get(key(map_i, mode), 0))

func get_wins(map_i: int, mode: String) -> int:
	return int(wins.get(key(map_i, mode), 0))

func record(map_i: int, mode: String, wave: int, won: bool) -> bool:
	var k := key(map_i, mode)
	var improved := wave > int(best.get(k, 0))
	if improved:
		best[k] = wave
	if won:
		wins[k] = int(wins.get(k, 0)) + 1
	save()
	return improved

func delete_save() -> void:
	best = {}
	wins = {}
	plays = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
