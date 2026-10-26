extends RefCounted
## Add a scene path and unlock a row here when a new map is actually available.
const LEVELS: Array[Dictionary] = [
	{"id": "01", "title": "CALIBRATION", "subtitle": "Find your balance. Together.", "scene": "res://scenes/main.tscn", "unlocked": true},
	{"id": "02", "title": "THE LABYRINTH", "subtitle": "Navigate the long experiment together.", "scene": "res://scenes/level_02.tscn", "unlocked": true},
	{"id": "03", "title": "NEW HORIZONS", "subtitle": "Master the curves. Cross the gate.", "scene": "res://scenes/level_03.tscn", "unlocked": true},
	{"id": "04", "title": "FINAL ORBIT", "subtitle": "The final experiment. Find your way through.", "scene": "res://scenes/level_04.tscn", "unlocked": true, "final": true}
]
