extends RefCounted
## Add a scene path and unlock a row here when a new map is actually available.
const LEVELS: Array[Dictionary] = [
	{"id": "01", "title": "CALIBRATION", "subtitle": "Find your balance. Together.", "scene": "res://scenes/main.tscn", "unlocked": true},
	{"id": "02", "title": "THE LABYRINTH", "subtitle": "Navigate the long experiment together.", "scene": "res://scenes/level_02.tscn", "unlocked": true},
	{"id": "03", "title": "NEW HORIZONS", "subtitle": "Future experiment", "scene": "", "unlocked": false}
]
