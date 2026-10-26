extends Control
const UI = preload("res://scripts/ui/lab_ui.gd")
signal retry_requested
signal lobby_requested
var _panel: PanelContainer
var _time: Label
var _level: Label
var _subtitle: Label
var _retry: Button
var _shown: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.07, 0.73)
	add_child(shade)
	UI.full_rect(shade)
	var center := CenterContainer.new()
	add_child(center)
	UI.full_rect(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 820
	var style := UI.panel(Color("091e31f5"), UI.CYAN, 16)
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 42
	style.content_margin_bottom = 42
	style.shadow_color = Color(0.1, 0.65, 1, 0.22)
	style.shadow_size = 28
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_panel.add_child(box)
	_level = UI.label("EXPERIMENT COMPLETE", 18, UI.CYAN)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_level)
	var title := UI.label("MISSION SUCCESS!", 61)
	title.name = "SuccessTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI.font(true))
	box.add_child(title)
	_subtitle = UI.label("A shared balance. A shared breakthrough.", 22, UI.MUTED)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	UI.line(box)
	var caption := UI.label("CLEAR TIME", 17, UI.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	_time = UI.label("00:00.0", 66, UI.ORANGE)
	_time.name = "ClearTime"
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_time)
	UI.line(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var lobby := UI.button("LOBBY")
	lobby.name = "LobbyButton"
	lobby.custom_minimum_size = Vector2(300, 76)
	row.add_child(lobby)
	lobby.pressed.connect(func(): lobby_requested.emit())
	_retry = UI.button("RETRY", true)
	_retry.name = "RetryButton"
	_retry.custom_minimum_size = Vector2(300, 76)
	row.add_child(_retry)
	_retry.pressed.connect(func(): retry_requested.emit())
	hide()

func present(clear_time: float, level: String, final_level: bool = false) -> void:
	if _shown:
		return
	_shown = true
	_time.text = "%02d:%02d.%d" % [int(clear_time / 60.0), int(clear_time) % 60, int(clear_time * 10.0) % 10]
	_level.text = "LEVEL " + level + ("     /     FINAL EXPERIMENT COMPLETE" if final_level else "     /     EXPERIMENT COMPLETE")
	_subtitle.text = "Final experiment complete. Thank you for balancing together." if final_level else "A shared balance. A shared breakthrough."
	modulate.a = 0.0
	show()
	# Wait for the containers to lay out the panel before scaling around its center.
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE if Session.reduced_motion else Vector2.ONE * 0.94
	var duration: float = 0.05 if Session.reduced_motion else 0.4
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, duration)
	tween.tween_property(_panel, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_retry.grab_focus()
