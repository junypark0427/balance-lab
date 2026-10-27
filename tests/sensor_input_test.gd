extends SceneTree
## Synthetic network checks, not evidence that real wrists can clear a level.
var failures: int = 0
var passes: int = 0
var _sequence: int = 0
var _hub: Node
var _sender := PacketPeerUDP.new()

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func _frame(axes: Vector2, connected: Array = [true,true]) -> Dictionary:
	_sequence += 1
	var players: Array = []
	for i in range(2):
		players.append({"id":"esp32-00000000000%d" % i,"value":axes[i],"angle":axes[i]*25,"age_ms":0,"connected":connected[i],"calibrated":true,"calibrating":false})
	return {"v":1,"kind":"balance_sensors","session":"network-test","seq":_sequence,"sent_unix_ms":Time.get_unix_time_from_system()*1000.0,"mode":"sensor","players":players,"devices":[]}

func _send(axes: Vector2, connected: Array = [true,true]) -> void:
	_sender.put_packet(JSON.stringify(_frame(axes,connected)).to_utf8_buffer())
	await process_frame
	await process_frame

func _button(node: Node, title: String) -> Button:
	if node is Button and node.text==title:
		return node
	for child: Node in node.get_children():
		var result: Button = _button(child,title)
		if result!=null: return result
	return null

func _wait_command(receiver: PacketPeerUDP) -> Dictionary:
	# A process frame can be shorter than loopback delivery in headless runs.
	# Wait for the actual datagram instead of assuming one frame is sufficient.
	var deadline: int = Time.get_ticks_msec() + 500
	while receiver.get_available_packet_count() == 0 and Time.get_ticks_msec() < deadline:
		await create_timer(0.005).timeout
	if receiver.get_available_packet_count() == 0:
		return {}
	var value: Variant = JSON.parse_string(receiver.get_packet().get_string_from_utf8())
	return value if value is Dictionary else {}

func _command_test() -> void:
	var receiver := PacketPeerUDP.new()
	if receiver.bind(_hub.command_port,"127.0.0.1")!=OK:
		_check(false,"Isolated command test port is available")
		return
	_hub.accept_packet(_frame(Vector2.ZERO))
	for title: String in ["ZERO P1","ZERO P2","ZERO BOTH","SENSOR [F8]","KEYBOARD [F8]"]:
		var button: Button = _button(_hub,title)
		if button==null:
			_check(false,title+" exists")
			continue
		button.pressed.emit()
		var command: Dictionary = await _wait_command(receiver)
		if command.is_empty():
			_check(false,title+" sends a real UDP command")
			continue
		if title.begins_with("ZERO"):
			var player: int = 1 if title=="ZERO P1" else (2 if title=="ZERO P2" else 0)
			_check(command.get("action")=="calibrate" and command.get("player")==player,title+" addresses correct player over actual UDP")
		else:
			_check(command.get("action")=="mode" and command.get("mode")==("sensor" if title.begins_with("SENSOR") else "keyboard"),title+" sends correct mode over actual UDP")
	var key := InputEventKey.new()
	key.physical_keycode=KEY_C
	key.keycode=KEY_C
	key.pressed=true
	Input.parse_input_event(key)
	var init_command: Dictionary = await _wait_command(receiver)
	_check(init_command.get("action")=="recenter" and _hub.init_status=="waiting","C sends INIT request and displays pending status")
	key.echo=true
	Input.parse_input_event(key)
	await process_frame
	_check(receiver.get_available_packet_count()==0,"Held C does not repeatedly reset neutral")
	var confirmed: Dictionary = _frame(Vector2.ZERO)
	confirmed.init={"request":init_command.get("request",""),"status":"ok","players":[1,2],"reason":""}
	_hub.accept_packet(confirmed)
	_check(_hub.init_status=="ok" and "INIT 완료" in _hub.init_status_text and _hub.find_child("InitNotice",true,false).visible,"Actual completion acknowledgement displays INIT 완료")
	_check(root.get_visible_rect().encloses(_hub.find_child("InitNotice",true,false).get_global_rect()),"INIT notification is visible inside the screen")
	var release := InputEventKey.new()
	release.physical_keycode=KEY_C
	release.keycode=KEY_C
	release.pressed=false
	Input.parse_input_event(release)
	await process_frame
	await process_frame
	key=InputEventKey.new()
	key.physical_keycode=KEY_C
	key.keycode=KEY_C
	key.pressed=true
	Input.parse_input_event(key)
	init_command=await _wait_command(receiver)
	if not init_command.is_empty():
		confirmed=_frame(Vector2.ZERO)
		confirmed.init={"request":init_command.request,"status":"error","players":[1,2],"reason":"moving"}
		_hub.accept_packet(confirmed)
		_check(_hub.init_status=="error" and "INIT 실패" in _hub.init_status_text,"Motion rejection displays failure instead of false success")
	else:
		_check(false,"A second C press sends another INIT request")
	var final_release := InputEventKey.new()
	final_release.physical_keycode=KEY_C
	final_release.keycode=KEY_C
	final_release.pressed=false
	Input.parse_input_event(final_release)
	receiver.close()

func _run() -> void:
	await process_frame
	_hub=root.get_node("SensorHub")
	_sender.set_dest_address("127.0.0.1",_hub.listen_port)
	await _command_test()
	await _send(Vector2(.4,-.7))
	_check(_hub.get_axes().is_equal_approx(Vector2(.4,-.7)),"Actual loopback UDP delivers two analog axes")
	var previous: int = _hub.last_received_ms
	_check(not _hub.accept_packet(_hub.packet.duplicate(true)),"Repeated sequence is rejected")
	_check(_hub.last_received_ms==previous,"Replay does not refresh timeout")
	var invalid: Dictionary = _frame(Vector2.ONE)
	invalid.players[0].value=1.5
	_check(not _hub.accept_packet(invalid) and _hub.get_axes()==Vector2.ZERO,"Out-of-range UDP is fail-safe neutral")
	invalid=_frame(Vector2.ONE)
	invalid.sent_unix_ms-=1000
	_check(not _hub.accept_packet(invalid),"Old queued UDP cannot reactivate input")
	for path: String in ["res://scenes/main.tscn","res://scenes/level_02.tscn","res://scenes/level_03.tscn","res://scenes/level_04.tscn"]:
		var game: Node = load(path).instantiate()
		game.get_node("TiltInput").debug_logging=false
		game.get_node("Platform").debug_logging=false
		root.add_child(game)
		var source: Node = game.get_node("TiltInput")
		var platform: Node = game.get_node("Platform")
		var ball: RigidBody3D = game.get_node("Ball")
		var started: Vector3 = ball.position
		for tick in range(90):
			await _send(Vector2(.55,-.55))
			await physics_frame
		_check(platform.last_received_axes.is_equal_approx(Vector2(.55,-.55)),path+" sensor reaches existing platform input")
		_check(platform.rotation_degrees.x<-.5 and platform.rotation_degrees.z<-.5,path+" both axes physically tilt")
		_check(absf(platform.rotation_degrees.x)<=15.01 and absf(platform.rotation_degrees.z)<=15.01,path+" keeps +/-15 degree limits")
		_check(not ball.freeze and ball.position.distance_to(started)>.1,path+" existing RigidBody moves under actual physics")
		Input.action_press("tilt_left")
		_check(source.get_tilt_axes().x==-1 and is_equal_approx(source.get_tilt_axes().y,-.55),path+" keyboard overrides one axis while other sensor remains active")
		Input.action_release("tilt_left")
		await _send(Vector2.ONE,[false,true])
		_check(source.get_tilt_axes().x==0 and source.get_tilt_axes().y==1,path+" one controller loss affects only its axis")
		_hub.last_received_ms=Time.get_ticks_msec()-1000
		_check(source.get_tilt_axes()==Vector2.ZERO,path+" bridge loss neutralizes both axes")
		game.queue_free()
		await process_frame
	_hub.show_panel(true)
	_check(paused,"Controller panel pauses gameplay for pairing/zeroing")
	_hub.show_panel(false)
	_check(not paused,"Closing panel restores previous pause state")
	_sender.close()
	print("SENSOR INPUT RESULTS: %d passed, %d failed" % [passes,failures])
	quit(1 if failures else 0)
