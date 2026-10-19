extends Button

var _tween: Tween

func _ready() -> void:
	mouse_entered.connect(_highlight.bind(true))
	mouse_exited.connect(_highlight.bind(false))
	focus_entered.connect(_highlight.bind(true))
	focus_exited.connect(_highlight.bind(false))
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func _highlight(active: bool) -> void:
	if disabled:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate", Color(1.15, 1.15, 1.15) if active else Color.WHITE, 0.12)

func _press(down: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (0.975 if down else 1.0), 0.09)
