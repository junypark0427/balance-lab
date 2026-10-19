extends Control
const UI = preload("res://scripts/ui/lab_ui.gd")
var page: String = "home"
var _content: VBoxContainer
var _footer: Label

func _ready() -> void:
	UI.veil(self, 0.22)
	var margins := UI.margin(self, 52)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margins.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(UI.label("B / L     ·     COOPERATIVE PHYSICS", 17, UI.CYAN))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(space)
	header.add_child(UI.label("●  SYSTEM ONLINE     /     LOCAL 2P", 16, UI.MUTED))
	UI.line(column)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 1040
	_content.add_theme_constant_override("separation", 12)
	center.add_child(_content)
	UI.line(column)
	var footer_panel := PanelContainer.new()
	var footer_style := UI.panel(Color("061321e8"), Color("294355"), 4)
	footer_style.content_margin_top = 10
	footer_style.content_margin_bottom = 10
	footer_panel.add_theme_stylebox_override("panel", footer_style)
	column.add_child(footer_panel)
	var foot := HBoxContainer.new()
	footer_panel.add_child(foot)
	_footer = UI.label("EXPERIMENT 001     /     SYNCHRONIZE. BALANCE. ADVANCE.", 16, UI.MUTED)
	foot.add_child(_footer)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	foot.add_child(UI.label("TWO PLAYERS     /     ONE EXPERIMENT", 15, UI.MUTED))
	show_home()

func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_content.modulate.a = 0
	create_tween().tween_property(_content, "modulate:a", 1.0, 0.05 if Session.reduced_motion else 0.22)

func _heading(kicker: String, title: String, subtitle: String) -> void:
	var tag := UI.label(kicker, 17, UI.CYAN)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tag)
	var heading := UI.label(title, 64)
	heading.add_theme_font_override("font", UI.font(true))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(heading)
	var description := UI.label(subtitle, 20, UI.MUTED)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(description)
	_gap(24)

func _gap(height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	_content.add_child(gap)

func _center_button(text: String, callback: Callable, primary: bool = false, node_name: String = "") -> Button:
	var holder := CenterContainer.new()
	_content.add_child(holder)
	var button := UI.button(text, primary)
	if not node_name.is_empty():
		button.name = node_name
	holder.add_child(button)
	button.pressed.connect(callback)
	return button

func show_home() -> void:
	page = "home"
	_clear()
	var tag := UI.label("T H E   C O O P E R A T I O N   E X P E R I M E N T", 16, UI.CYAN)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(tag)
	var title := UI.label("BALANCE LAB", 136)
	title.add_theme_font_override("font", UI.font(true))
	title.add_theme_color_override("font_shadow_color", Color("3174a5"))
	title.add_theme_constant_override("shadow_outline_size", 9)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	var slogan := UI.label("TILT TOGETHER, REACH FURTHER", 24, Color("b9e3f5"))
	slogan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(slogan)
	_gap(0)
	var start := _center_button("GAME START", func(): Session.start_level(0), true, "StartButton")
	_center_button("LEVEL SELECT", show_levels, false, "LevelSelectButton")
	_center_button("SETTINGS", show_settings, false, "SettingsButton")
	_gap(16)
	var hint := UI.label("TWO PLAYERS. ONE PLATFORM. A SHARED WAY FORWARD.", 15, UI.WHITE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint_style := UI.panel(Color("081a2bdd"), Color("294355"), 4)
	hint_style.content_margin_top = 8
	hint_style.content_margin_bottom = 8
	hint.add_theme_stylebox_override("normal", hint_style)
	var hint_center := CenterContainer.new()
	_content.add_child(hint_center)
	hint_center.add_child(hint)
	# The lower third is deliberately left open for the real 3D maze.
	_gap(268)
	start.grab_focus()

func show_levels() -> void:
	page = "levels"
	_clear()
	_heading("EXPERIMENT DIRECTORY", "LEVEL SELECT", "Every breakthrough starts with balance.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_content.add_child(row)
	for index in range(Session.CATALOG.LEVELS.size()):
		var entry: Dictionary = Session.CATALOG.LEVELS[index]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(320, 300)
		card.add_theme_stylebox_override("panel", UI.panel(Color("091e30ee"), UI.CYAN if entry.unlocked else Color("294253")))
		row.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 15)
		card.add_child(box)
		box.add_child(UI.label("EXPERIMENT  /  " + entry.id, 16, UI.CYAN if entry.unlocked else UI.MUTED))
		box.add_child(UI.label(entry.title, 26))
		var sub := UI.label(entry.subtitle, 17, UI.MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sub)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		var button := UI.button("ENTER LAB" if entry.unlocked else "LOCKED", entry.unlocked)
		button.name = "Level" + entry.id
		button.custom_minimum_size = Vector2(240, 62)
		button.disabled = not entry.unlocked
		box.add_child(button)
		button.pressed.connect(Session.start_level.bind(index))
	_gap(25)
	_center_button("BACK TO MAIN MENU", show_home, false, "BackButton").grab_focus()
	_gap(180)

func show_settings() -> void:
	page = "settings"
	_clear()
	_heading("CONTROL ROOM", "SETTINGS", "Make the lab feel right for you.")
	var center := CenterContainer.new()
	_content.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 740
	panel.add_theme_stylebox_override("panel", UI.panel())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_toggle(box, "INPUT DIAGNOSTICS", "Show live input and physics telemetry in game.  [F3]", Session.diagnostics_enabled, func(value: bool): Session.diagnostics_enabled = value)
	UI.line(box)
	_toggle(box, "REDUCED MOTION", "Still lab preview and shorter screen transitions.", Session.reduced_motion, func(value: bool): Session.reduced_motion = value)
	UI.line(box)
	var fullscreen := _toggle(box, "FULLSCREEN", "Available in a standalone game window." if Session.is_embedded() else "Use the full display for your experiment.", Session.fullscreen_enabled and not Session.is_embedded(), func(value: bool):
		Session.fullscreen_enabled = value
		Session.apply_fullscreen()
	)
	fullscreen.disabled = Session.is_embedded()
	_gap(12)
	var note := UI.label("Preferences are saved on this device.", 16, UI.MUTED)
	note.name = "SettingsNotice"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(note)
	_center_button("BACK TO MAIN MENU", show_home, false, "BackButton").grab_focus()
	_gap(160)

func _toggle(parent: Node, title: String, description: String, value: bool, callback: Callable) -> CheckButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UI.label(title, 21))
	text.add_child(UI.label(description, 16, UI.MUTED))
	var check := CheckButton.new()
	check.name = title.to_pascal_case() + "Toggle"
	check.custom_minimum_size = Vector2(86, 62)
	check.button_pressed = value
	check.text = "ON" if value else "OFF"
	check.add_theme_font_override("font", UI.font(true))
	check.add_theme_font_size_override("font_size", 17)
	check.add_theme_color_override("font_color", UI.CYAN)
	row.add_child(check)
	check.toggled.connect(func(enabled: bool):
		check.text = "ON" if enabled else "OFF"
		callback.call(enabled)
		var error: Error = Session.save_preferences()
		var notice := find_child("SettingsNotice", true, false) as Label
		if notice:
			notice.text = "Preferences saved." if error == OK else "Could not save preferences on this device."
	)
	return check

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and page != "home":
		show_home()
		get_viewport().set_input_as_handled()
