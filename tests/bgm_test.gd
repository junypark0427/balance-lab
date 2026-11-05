extends SceneTree
## Real MP3 playback/mixer and scene flows. Does not certify speaker listening quality.
const PATHS := ["res://scenes/main.tscn", "res://scenes/level_02.tscn", "res://scenes/level_03.tscn", "res://scenes/level_04.tscn"]
var passes: int = 0
var failures: int = 0
var manager: Node
var session: Node
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var bgm_bus: int
var original_master_mute: bool
var unexpected_finishes: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	print("[BGM TEST] ", "PASS " if ok else "FAIL ", description)
	if ok:
		passes += 1
	else:
		failures += 1

func frames(count: int = 3) -> void:
	for i in range(count):
		await process_frame

func wait(seconds: float = 0.65) -> void:
	await create_timer(seconds, true, false, true).timeout

func playback_id() -> int:
	return player.get_stream_playback().get_instance_id() if player.has_stream_playback() else 0

func wait_scene(path: String) -> bool:
	var until: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and not session.transitioning:
			await frames()
			return true
	return false

func audio_peak() -> float:
	var peak: float = 0.0
	var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	for sample: Vector2 in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return peak

func run() -> void:
	manager = root.get_node("BGMManager")
	session = root.get_node("Session")
	player = manager.get_node("MusicPlayer")
	session.preferences_path = "/tmp/balance-bgm-settings-%d.cfg" % OS.get_process_id()
	session.ice_mode_enabled = false
	session.reduced_motion = true
	session.diagnostics_enabled = false
	session.fullscreen_enabled = false
	session.apply_fullscreen()
	bgm_bus = AudioServer.get_bus_index("BGM")
	check(bgm_bus > 0 and player.bus == &"BGM", "Dedicated BGM bus routes to Master")
	check(AudioServer.get_bus_send(bgm_bus) == &"Master", "BGM leaves other bus routing intact")
	var master_volume: float = AudioServer.get_bus_volume_db(0)
	original_master_mute = AudioServer.is_bus_mute(0)
	# Capture the actual mixer before Master; do not play a test session over the speakers.
	AudioServer.set_bus_mute(0, true)
	capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(bgm_bus, capture)
	player.finished.connect(func(): unexpected_finishes += 1)
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus < 0:
		AudioServer.add_bus()
		sfx_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus, "SFX")
	AudioServer.set_bus_volume_db(sfx_bus, -7.0)
	AudioServer.set_bus_mute(sfx_bus, true)
	var sfx := AudioStreamPlayer.new()
	# Silent PCM fixture exists only in memory; no extra music/SFX asset is created.
	var sfx_stream := AudioStreamWAV.new()
	sfx_stream.mix_rate = 8000
	sfx_stream.format = AudioStreamWAV.FORMAT_16_BITS
	var silence := PackedByteArray()
	silence.resize(8000 * 2 * 120)
	sfx_stream.data = silence
	sfx.stream = sfx_stream
	sfx.bus = &"SFX"
	root.add_child(sfx)
	sfx.play()

	check(change_scene_to_file("res://scenes/menu.tscn") == OK, "Real main menu scene loads")
	await wait_scene("res://scenes/menu.tscn")
	await wait()
	check(manager.current_track == manager.LOBBY and player.playing, "First lobby automatically plays lobby.mp3")
	var lobby_playback: int = playback_id()
	var menu: Control = current_scene.get_node("CanvasLayer/MenuUI")
	menu.show_settings()
	await frames()
	var toggle: CheckButton = menu.find_child("IceModeToggle", true, false)
	toggle.button_pressed = true
	await wait()
	check(session.ice_mode_enabled and manager.current_track == manager.LOBBY and playback_id() == lobby_playback, "SETTINGS ICE toggle keeps lobby music without restart")
	var saved := ConfigFile.new()
	check(saved.load(session.preferences_path) == OK and saved.get_value("gameplay", "ice_mode", false), "Existing ICE preference save still works")
	toggle.button_pressed = false
	menu.show_levels()
	await frames()
	check(manager.current_track == manager.LOBBY and playback_id() == lobby_playback, "Level selection retains the same lobby playback")

	# Observe both halves of the actual 0.5-second fade, not only its final state.
	var gain: float = player.volume_linear
	manager.play_gameplay()
	await wait(0.1)
	check(manager.current_track == manager.LOBBY and player.volume_linear < gain and player.volume_linear > 0.0, "Track switch first fades out the old song")
	await wait(0.22)
	check(manager.current_track == manager.NORMAL and player.playing and player.volume_linear > 0.0 and player.volume_linear < gain, "Next song starts silently then fades in without overlap")
	await wait(0.3)
	check(is_equal_approx(player.volume_linear, db_to_linear(manager.music_volume_db)), "0.5-second transition reaches configured music volume")

	for i in range(PATHS.size()):
		var previous: int = playback_id()
		session.start_level(i)
		check(await wait_scene(PATHS[i]), "Normal LEVEL %02d loads" % (i + 1))
		check(manager.current_track == manager.NORMAL and playback_id() == previous, "Normal LEVEL %02d continues music without restarting" % (i + 1))
		current_scene.get_node("Platform").debug_logging = false
		current_scene.get_node("TiltInput").debug_logging = false

	var game: Node = current_scene
	var hud: Control = game.get_node("HUD/GameplayUI")
	var before_pause: float = player.get_playback_position()
	var continuous_id: int = playback_id()
	hud.set_paused(true)
	await wait(0.2)
	check(paused and player.playing and not player.stream_paused and player.get_playback_position() > before_pause, "BGM continues through the existing pause overlay")
	# The setting changes music immediately, including when the game tree is paused.
	session.ice_mode_enabled = true
	check(manager._requested_track == manager.ICE, "ICE setting signal requests the correct track immediately in gameplay")
	await wait()
	check(manager.current_track == manager.ICE and player.playing, "ICE track fade completes while gameplay is paused")
	check(not game.ice_mode_active, "Changing music does not mutate the current run's snapshotted physics mode")
	hud.set_paused(false)
	session.ice_mode_enabled = false
	await wait()
	check(manager.current_track == manager.NORMAL, "Turning ICE off immediately restores normal gameplay music")
	continuous_id = playback_id()
	game.get_node("Ball").request_reset()
	await frames(5)
	check(playback_id() == continuous_id, "Ball reset does not restart BGM")
	# Goal fixture verifies the actual success overlay, not a start-to-goal playthrough.
	game.get_node("MissionController")._on_body_entered(game.get_node("Ball"))
	await frames(5)
	check(game.goal_reached and hud.success_menu.visible and playback_id() == continuous_id, "Mission Success keeps the current gameplay song")
	hud.success_menu.retry_requested.emit()
	check(await wait_scene(PATHS[3]), "Existing result RETRY reloads the current level")
	check(playback_id() == continuous_id and manager.current_track == manager.NORMAL, "Same-mode scene reload does not restart playback")

	# All four ICE scenes use the same persistent player and the existing mode setting.
	session.ice_mode_enabled = true
	await wait()
	for i in range(PATHS.size()):
		var previous: int = playback_id()
		session.start_level(i)
		check(await wait_scene(PATHS[i]), "ICE LEVEL %02d loads" % (i + 1))
		check(current_scene.ice_mode_active and manager.current_track == manager.ICE and playback_id() == previous, "ICE LEVEL %02d retains the same ice.mp3 playback" % (i + 1))
		current_scene.get_node("Platform").debug_logging = false
		current_scene.get_node("TiltInput").debug_logging = false
	game = current_scene
	hud = game.get_node("HUD/GameplayUI")
	hud.set_paused(true)
	hud.find_child("MainMenuButton", true, false).pressed.emit()
	check(await wait_scene("res://scenes/menu.tscn"), "Pause menu MAIN MENU uses the existing lobby route")
	await wait()
	check(manager.current_track == manager.LOBBY and not paused, "Returning to lobby restores lobby.mp3 even with ICE enabled")
	continuous_id = playback_id()
	manager.play_gameplay()
	await wait(0.06)
	manager.play_lobby()
	await wait()
	check(manager.current_track == manager.LOBBY and playback_id() == continuous_id, "Rapid A-B-A transition cancels stale callbacks without restarting A")

	for track: StringName in [manager.LOBBY, manager.NORMAL, manager.ICE]:
		manager.request_track(track)
		await wait()
		check(player.stream is AudioStreamMP3 and player.stream.loop and player.stream.loop_offset == 0.0, "%s MP3 has native repeat enabled" % track)
		capture.clear_buffer()
		await wait(0.3)
		check(audio_peak() > 0.000001, "%s produces real decoded audio samples via %s" % [track, AudioServer.get_driver_name()])
		player.seek(player.stream.get_length() - 0.12)
		# seek() itself can replace the engine playback object; looping must not.
		await frames(2)
		var loop_id: int = playback_id()
		await wait(0.4)
		check(player.playing and player.get_playback_position() < 1.0 and playback_id() == loop_id, "%s actually wraps from its end without a stop or new playback" % track)
	check(unexpected_finishes == 0, "No MP3 emits finished while looping")
	check(manager.find_children("*", "AudioStreamPlayer", true, false).size() == 1 and player.max_polyphony == 1, "Exactly one BGM player across all scene/mode changes")
	check(sfx.playing and sfx.bus == &"SFX" and AudioServer.is_bus_mute(sfx_bus) and AudioServer.get_bus_volume_db(sfx_bus) == -7.0 and AudioServer.get_bus_volume_db(0) == master_volume, "Existing SFX player and SFX/Master volume/mute are preserved")

	continuous_id = playback_id()
	manager.request_track(&"missing-test-track")
	manager.request_track(&"missing-test-track")
	check(player.playing and playback_id() == continuous_id and manager._warnings.size() == 1, "Missing track keeps valid music and warns only once")
	manager._player = null
	manager.request_track(manager.LOBBY)
	manager._player = player
	check(player.playing and playback_id() == continuous_id, "Unavailable audio player fails safely without touching other playback")

	# An import-remap alias tests a filename containing a space without renaming/copying music.
	var pack := PCKPacker.new()
	var pack_path: String = "/tmp/balance-bgm-space-%d.pck" % OS.get_process_id()
	var packed: bool = pack.pck_start(pack_path) == OK
	packed = packed and pack.add_file("res://bgm/not ice.mp3.import", "res://bgm/ingame_not_ice.mp3.import") == OK
	packed = packed and pack.flush() == OK
	check(packed and ProjectSettings.load_resource_pack(pack_path), "Temporary filename-with-space fixture mounts without moving source MP3s")
	manager._streams.erase(manager.NORMAL)
	check(manager.resolve_track_path(manager.NORMAL) == "res://bgm/not ice.mp3" and manager._load_track(manager.NORMAL) != null, "Exact not ice.mp3 path loads successfully when present")

	# Remove test-only mixer effects/players and avoid outstanding audio objects on exit.
	sfx.stop()
	sfx.stream = null
	sfx.queue_free()
	player.stop()
	player.stream = null
	manager._streams.clear()
	AudioServer.remove_bus_effect(bgm_bus, AudioServer.get_bus_effect_count(bgm_bus) - 1)
	capture = null
	AudioServer.set_bus_mute(0, original_master_mute)
	await wait(0.15)
	print("[BGM TEST] RESULTS: %d passed, %d failed" % [passes, failures])
	quit(1 if failures else 0)
