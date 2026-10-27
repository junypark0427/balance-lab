extends Node
## USB and calibration live in Python. This adapter accepts loopback UDP only.
const UI = preload("res://scripts/ui/lab_ui.gd")
const TIMEOUT_MS := 300
var listen_port: int = 6171
var command_port: int = 6172
var packet: Dictionary = {}
var last_received_ms: int = -10000
var rejected_packets: int = 0
var _udp := PacketPeerUDP.new()
var _sender := PacketPeerUDP.new()
var _session: String = ""
var _sequence: int = -1
var _listening: bool = false
var _panel: Control
var _status: Label
var _devices: Label
var _badge: Button
var _rows: Array[Dictionary] = []
var _previous_pause: bool = false
var _ui_elapsed: float = 0
var init_status: String = ""
var init_status_text: String = ""
var _init_request: String = ""
var _init_deadline: int = 0
var _notice_until: int = 0
var _notice: PanelContainer
var _notice_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -30
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--sensor-port="):
			listen_port = argument.trim_prefix("--sensor-port=").to_int()
		elif argument.begins_with("--sensor-command-port="):
			command_port = argument.trim_prefix("--sensor-command-port=").to_int()
	_listening = _udp.bind(listen_port, "127.0.0.1") == OK
	_sender.set_dest_address("127.0.0.1", command_port)
	_build_ui()
	if not _listening:
		push_warning("Sensor UDP port is occupied. Keyboard control remains available.")

func _process(delta: float) -> void:
	for _i in range(64):
		if not _listening or _udp.get_available_packet_count() == 0:
			break
		var data: PackedByteArray = _udp.get_packet()
		if _udp.get_packet_ip() != "127.0.0.1" or data.size() > 4096:
			rejected_packets += 1
			continue
		accept_packet(JSON.parse_string(data.get_string_from_utf8()))
	if not _init_request.is_empty() and Time.get_ticks_msec()>_init_deadline:
		_finish_init(false,"INIT 실패: 중계 응답이 없습니다. 다시 C를 눌러 주세요.")
	if _notice.visible and Time.get_ticks_msec()>_notice_until:
		_notice.hide()
	_ui_elapsed += delta
	if _ui_elapsed >= 0.1:
		_ui_elapsed = 0
		_refresh_ui()

func is_connected_to_bridge() -> bool:
	return _listening and Time.get_ticks_msec() - last_received_ms < TIMEOUT_MS

func sensor_mode_enabled() -> bool:
	return is_connected_to_bridge() and packet.get("mode", "keyboard") == "sensor"

func get_axes() -> Vector2:
	if not sensor_mode_enabled():
		return Vector2.ZERO
	var axes := Vector2.ZERO
	for i in range(2):
		var p: Dictionary = packet.players[i]
		if p.connected and p.calibrated and not p.calibrating and p.age_ms >= 0 and p.age_ms < 250:
			axes[i] = float(p.value)
	return axes

func accept_packet(value: Variant) -> bool:
	if not value is Dictionary or value.get("v") != 1 or value.get("kind") != "balance_sensors":
		return _reject()
	if not value.get("session") is String or not value.get("seq") is float and not value.get("seq") is int:
		return _reject()
	if not (value.get("sent_unix_ms") is float or value.get("sent_unix_ms") is int):
		return _reject()
	if not is_finite(float(value.sent_unix_ms)) or absf(Time.get_unix_time_from_system()*1000.0-float(value.sent_unix_ms))>TIMEOUT_MS:
		return _reject() # Queued old data must not reactivate a disconnected controller.
	if not value.get("mode") in ["keyboard", "sensor"] or not value.get("players") is Array or value.players.size() != 2:
		return _reject()
	if not value.get("devices") is Array or value.devices.size()>16:
		return _reject()
	for device: Variant in value.devices:
		if not device is Dictionary or not device.get("id") is String:
			return _reject()
	var identities: Array[String] = []
	for p: Variant in value.players:
		if not p is Dictionary or not p.get("id") is String:
			return _reject()
		for key: String in ["value", "angle", "age_ms"]:
			if not (p.get(key) is float or p.get(key) is int) or not is_finite(float(p[key])):
				return _reject()
		if absf(float(p.value)) > 1.0 or float(p.age_ms) < -1.0:
			return _reject()
		for key: String in ["connected", "calibrated", "calibrating"]:
			if not p.get(key) is bool:
				return _reject()
		if not p.id.is_empty():
			if p.id in identities:
				return _reject()
			identities.append(p.id)
	if not is_finite(float(value.seq)) or float(value.seq) < 0 or float(value.seq) != floor(float(value.seq)):
		return _reject()
	if value.session == _session and int(value.seq) <= _sequence:
		return false # Replayed packets never keep a disconnected device alive.
	_session = value.session
	_sequence = int(value.seq)
	packet = value
	last_received_ms = Time.get_ticks_msec()
	var result: Variant = packet.get("init",{})
	if not _init_request.is_empty() and result is Dictionary and result.get("request")==_init_request:
		if result.get("status")=="ok":
			var names: PackedStringArray = []
			for player: Variant in result.get("players",[]):
				names.append("P%d" % int(player))
			_finish_init(true,"INIT 완료 — %s 현재 자세가 중립입니다." % ", ".join(names))
		elif result.get("status")=="error":
			var reason: String = str(result.get("reason",""))
			var detail: String = "손목을 멈춘 뒤 C를 다시 눌러 주세요."
			if reason=="not_connected": detail="연결된 컨트롤러가 없습니다."
			elif reason=="busy": detail="정밀 보정이 진행 중입니다."
			elif reason=="save_failed": detail="영점 설정을 저장하지 못했습니다."
			_finish_init(false,"INIT 실패: "+detail)
	return true

func _reject() -> bool:
	rejected_packets += 1
	last_received_ms = -10000
	return false

func send_command(command: Dictionary) -> void:
	_sender.put_packet(JSON.stringify(command).to_utf8_buffer())

func request_init() -> void:
	if not _init_request.is_empty():
		return
	if not is_connected_to_bridge():
		_finish_init(false,"INIT 실패: 센서 중계가 연결되지 않았습니다.")
		return
	_init_request=str(Time.get_ticks_usec())
	_init_deadline=Time.get_ticks_msec()+2000
	init_status="waiting"
	_show_notice("INIT 중 — 손목을 잠시 멈춰 주세요.",UI.CYAN)
	send_command({"action":"recenter","request":_init_request})

func _finish_init(success: bool, text: String) -> void:
	_init_request=""
	init_status="ok" if success else "error"
	_show_notice(text,Color("84f5b0") if success else UI.ORANGE)
	print("[Sensor INIT] ",text)

func _show_notice(text: String, color: Color) -> void:
	init_status_text=text
	_notice_label.text=text
	_notice_label.add_theme_color_override("font_color",color)
	_notice_until=Time.get_ticks_msec()+4000
	_notice.show()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F4:
		show_panel(not _panel.visible)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_C:
		request_init()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_F8:
		send_command({"action":"mode", "mode":"keyboard" if sensor_mode_enabled() else "sensor"})
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_ESCAPE and _panel.visible:
		show_panel(false)
		get_viewport().set_input_as_handled()

func show_panel(value: bool) -> void:
	if value == _panel.visible:
		return
	if value:
		_previous_pause = get_tree().paused
		get_tree().paused = true
	else:
		get_tree().paused = _previous_pause
	_panel.visible = value
	_refresh_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_badge = UI.button("SENSORS [F4]  /  KEYBOARD")
	_badge.add_theme_font_size_override("font_size", 16)
	_badge.custom_minimum_size = Vector2(320, 34)
	layer.add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_badge.offset_left=48
	_badge.offset_right=560
	_badge.offset_top=-158
	_badge.offset_bottom=-116
	_badge.tooltip_text="C: 현재 손목 자세로 INIT / F4: 센서 설정 / F8: 입력 모드"
	_badge.pressed.connect(func(): show_panel(true))
	_panel = Control.new()
	layer.add_child(_panel)
	UI.full_rect(_panel)
	var shade := ColorRect.new()
	shade.color = Color("030b14ed")
	_panel.add_child(shade)
	UI.full_rect(shade)
	var center := CenterContainer.new()
	_panel.add_child(center)
	UI.full_rect(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 980
	panel.add_theme_stylebox_override("panel", UI.panel(Color("0a1b2ef5"), UI.CYAN, 14))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(UI.label("WRIST CONTROLLERS  /  F4", 30, UI.CYAN))
	_status = UI.label("Start the USB sensor bridge.", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_devices = UI.label("", 16, UI.MUTED)
	box.add_child(_devices)
	for index in range(2):
		var column := VBoxContainer.new()
		box.add_child(column)
		var label := UI.label("PLAYER 1 / LEFT-RIGHT" if index==0 else "PLAYER 2 / FORWARD-BACK", 19, UI.CYAN if index == 0 else UI.ORANGE)
		column.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		column.add_child(row)
		var device := OptionButton.new()
		device.custom_minimum_size.x = 330
		row.add_child(device)
		device.item_selected.connect(func(item: int): send_command({"action":"assign", "player":index+1, "id":device.get_item_metadata(item)}))
		var axis := OptionButton.new()
		axis.add_item("ROLL"); axis.add_item("PITCH")
		row.add_child(axis)
		axis.item_selected.connect(func(item: int): send_command({"action":"configure", "player":index+1, "axis":"roll" if item==0 else "pitch"}))
		var invert := CheckButton.new()
		invert.text = "INVERT"
		row.add_child(invert)
		invert.toggled.connect(func(enabled: bool): send_command({"action":"configure", "player":index+1, "invert":enabled}))
		var calibrate := UI.button("ZERO P%d" % (index+1))
		calibrate.custom_minimum_size = Vector2(160,44)
		row.add_child(calibrate)
		calibrate.pressed.connect(func(): send_command({"action":"calibrate", "player":index+1}))
		var tuning := HBoxContainer.new()
		column.add_child(tuning)
		var spins: Dictionary = {}
		for setting: String in ["deadzone", "limit"]:
			tuning.add_child(UI.label("DEADZONE (deg)" if setting=="deadzone" else "FULL TILT (deg)", 16))
			var spin := SpinBox.new()
			spin.min_value = 0 if setting=="deadzone" else 5
			spin.max_value = 10 if setting=="deadzone" else 75
			spin.step = 0.5
			spin.custom_minimum_size.x = 100
			tuning.add_child(spin)
			spin.value_changed.connect(func(v: float): send_command({"action":"configure", "player":index+1, setting:v}))
			spins[setting] = spin
		_rows.append({"label":label, "device":device, "axis":axis, "invert":invert, "spins":spins})
		UI.line(box)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	for mode: String in ["keyboard", "sensor"]:
		var button := UI.button(mode.to_upper() + " [F8]", mode=="sensor")
		actions.add_child(button)
		button.pressed.connect(func(): send_command({"action":"mode", "mode":mode}))
	var zero := UI.button("ZERO BOTH")
	actions.add_child(zero)
	zero.pressed.connect(func(): send_command({"action":"calibrate", "player":0}))
	var quick := UI.button("INIT CURRENT POSE  [C]")
	box.add_child(quick)
	quick.pressed.connect(request_init)
	var note := UI.label("C: initialize the current steady wrist pose. Watch for INIT completion.\nZERO P1/P2/BOTH: 3-second precision calibration. A/D and arrows remain available.", 17, UI.MUTED)
	box.add_child(note)
	var close := UI.button("RETURN TO GAME / MENU")
	box.add_child(close)
	close.pressed.connect(func(): show_panel(false))
	_panel.hide()
	_notice=PanelContainer.new()
	_notice.name="InitNotice"
	_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_stylebox_override("panel",UI.panel(Color("081727f5"),UI.CYAN,8))
	layer.add_child(_notice)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice.offset_left=-420
	_notice.offset_right=420
	_notice.offset_top=132
	_notice.offset_bottom=202
	_notice_label=UI.label("",25,UI.CYAN)
	_notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_child(_notice_label)
	_notice.hide()

func _refresh_ui() -> void:
	var connected: bool = is_connected_to_bridge()
	_badge.text = "[C] INIT / [F4] SENSORS / " + ("SENSOR" if sensor_mode_enabled() else "KEYBOARD")
	if not _panel.visible:
		return
	_status.text = ("MODE: %s  |  %s" % [packet.get("mode", "keyboard").to_upper(), packet.get("message", "")]) if connected else "BRIDGE OFFLINE / start hardware/start_sensors.command. Keyboard remains available."
	if not connected:
		_devices.text = ""
		return
	var devices: Array = packet.get("devices", [])
	var device_lines: PackedStringArray = []
	for d: Dictionary in devices:
		device_lines.append("%s / %s / Roll %.1f  Pitch %.1f" % [d.id, "ONLINE" if d.get("connected", false) else "OFFLINE", d.get("roll", 0.0), d.get("pitch", 0.0)])
	_devices.text = "\n".join(device_lines)
	for index in range(2):
		var p: Dictionary = packet.players[index]
		var row: Dictionary = _rows[index]
		row.label.text = "%s / %s / %s / %.1f deg -> %.2f" % ["P1 LEFT-RIGHT" if index==0 else "P2 FORWARD-BACK", "ONLINE" if p.connected else "OFFLINE", "ZEROING" if p.calibrating else ("READY" if p.calibrated else "NEEDS ZERO"), p.angle, p.value]
		var ids: Array[String] = [""]
		for d: Dictionary in devices:
			if d.get("id") is String:
				ids.append(d.id)
		if not p.id in ids:
			ids.append(p.id)
		var option: OptionButton = row.device
		var previous_ids: Array = []
		for item in range(option.item_count):
			previous_ids.append(option.get_item_metadata(item))
		if previous_ids != ids:
			option.clear()
			for id: String in ids:
				option.add_item("SELECT DEVICE ID" if id.is_empty() else id)
				option.set_item_metadata(option.item_count-1, id)
		option.select(ids.find(p.id))
		row.axis.select(0 if p.get("axis", "roll")=="roll" else 1)
		row.invert.set_pressed_no_signal(p.get("invert", false))
		for setting: String in ["deadzone", "limit"]:
			row.spins[setting].set_value_no_signal(p.get(setting, 2.5 if setting=="deadzone" else 25.0))

func _exit_tree() -> void:
	_udp.close()
	_sender.close()
