extends Node
## One persistent player; a short fade-out/switch/fade-in never overlaps songs.
const LOBBY: StringName = &"lobby"
const NORMAL: StringName = &"normal"
const ICE: StringName = &"ice"
const TRACK_PATHS := {
	LOBBY: ["res://bgm/lobby.mp3"],
	# Support the requested filename and the actual existing file without renaming either.
	NORMAL: ["res://bgm/not ice.mp3", "res://bgm/ingame_not_ice.mp3"],
	ICE: ["res://bgm/ice.mp3"],
}

@export_range(0.4, 0.7, 0.05) var transition_seconds: float = 0.5
@export_range(-60.0, 0.0, 1.0) var music_volume_db: float = -18.0
var current_track: StringName = &""
var _requested_track: StringName = &""
var _gameplay: bool = false
var _player: AudioStreamPlayer
var _fade: Tween
var _streams: Dictionary = {}
var _warnings: Dictionary = {}


func _ready() -> void:
	# Pause/success overlays and the sensor panel should not interrupt the music.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus_index: int = AudioServer.get_bus_index(&"BGM")
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, &"BGM")
		AudioServer.set_bus_send(bus_index, &"Master")
	# Existing bus volume, mute, effects and Master/SFX settings are left untouched.
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = &"BGM"
	_player.max_polyphony = 1
	_player.volume_linear = 0.0
	add_child(_player)
	Session.ice_mode_changed.connect(_on_ice_mode_changed)


func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
	_streams.clear()


func play_lobby() -> void:
	_gameplay = false
	request_track(LOBBY)


func play_gameplay() -> void:
	_gameplay = true
	request_track(ICE if Session.ice_mode_enabled else NORMAL)


func _on_ice_mode_changed(enabled: bool) -> void:
	if _gameplay:
		request_track(ICE if enabled else NORMAL)


func resolve_track_path(track: StringName) -> String:
	for path: String in TRACK_PATHS.get(track, []):
		if ResourceLoader.exists(path, "AudioStreamMP3"):
			return path
	return ""


func _load_track(track: StringName) -> AudioStreamMP3:
	if _streams.has(track):
		return _streams[track] as AudioStreamMP3
	var path: String = resolve_track_path(track)
	if path.is_empty():
		_warn_once(track, "BGM file missing for '%s'; keeping the previous music." % track)
		return null
	var resource: Resource = ResourceLoader.load(path, "AudioStreamMP3")
	if not resource is AudioStreamMP3 or resource.get_length() <= 0.0:
		_warn_once(track, "BGM could not be decoded: " + path)
		return null
	# Loop settings belong to this manager, not to any shared SFX resource.
	var stream: AudioStreamMP3 = resource.duplicate() as AudioStreamMP3
	stream.loop = true
	stream.loop_offset = 0.0
	_streams[track] = stream
	return stream


func request_track(track: StringName) -> void:
	if not is_instance_valid(_player):
		_warn_once(&"player", "BGM player unavailable; gameplay can continue without music.")
		return
	if track == _requested_track and _player.playing:
		return
	# Validate before stopping a valid song, including during a pending transition.
	var stream: AudioStreamMP3 = _load_track(track)
	if stream == null:
		return
	_requested_track = track
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	_fade.finished.connect(_clear_fade)
	var half: float = transition_seconds * 0.5
	var target_volume: float = db_to_linear(music_volume_db)
	if current_track == track and _player.playing:
		# A -> B -> A before the switch: restore A without restarting its playback.
		_fade.tween_property(_player, "volume_linear", target_volume, half)
		return
	if _player.playing:
		_fade.tween_property(_player, "volume_linear", 0.0, half)
	_fade.tween_callback(_start_track.bind(track, stream))
	_fade.tween_property(_player, "volume_linear", target_volume, half)


func _clear_fade() -> void:
	# Completed callbacks must not retain their bound MP3 resources indefinitely.
	_fade = null


func _start_track(track: StringName, stream: AudioStreamMP3) -> void:
	if not is_instance_valid(_player) or track != _requested_track:
		return
	_player.stop()
	_player.stream = stream
	_player.volume_linear = 0.0
	_player.play()
	if not _player.has_stream_playback():
		current_track = &""
		_requested_track = &""
		_warn_once(&"playback", "BGM playback could not initialize; gameplay will continue.")
		return
	current_track = track


func _warn_once(key: StringName, message: String) -> void:
	if not _warnings.has(key):
		_warnings[key] = true
		push_warning(message)
