extends Camera3D
## World-upright quarter view: damp position, never inherit platform orientation.
@export var target: RigidBody3D
@export var platform: Node3D
@export_range(5.0, 30.0, 0.5) var height: float = 14.0
@export_range(3.0, 25.0, 0.5) var distance: float = 11.0
@export_range(0.5, 15.0, 0.5) var tracking_speed: float = 5.0
@export_range(0.5, 10.0, 0.5) var vertical_tracking_speed: float = 2.0
@export var look_ahead: Vector2 = Vector2(0, -2.4)
@export var camera_offset: Vector3 = Vector3.ZERO
@export var bounds_padding: Vector2 = Vector2(3.0, 0.5)
@export_range(8.0, 30.0, 0.5) var view_size: float = 14.0
@export_range(0.0, 0.95, 0.05) var occlusion_transparency: float = 0.8
var focus: Vector3
var focus_bounds: Rect2
var _diagnostics: bool = false
var _occluders: Array[Node] = []

func _ready() -> void:
	if not is_instance_valid(target) or not is_instance_valid(platform):
		push_error("FollowCamera: assign Ball and Platform.")
		set_process(false)
		return
	var half: Vector2 = platform.floor_size * 0.5
	focus_bounds = Rect2(-half + bounds_padding, (half - bounds_padding) * 2)
	focus = _desired_focus()
	_occluders = get_tree().get_nodes_in_group("level02_visual_parts")
	for part in _occluders:
		# Per-part materials prevent a faded wall from changing the whole maze.
		part.material_override = part.material_override.duplicate()
	_place_camera()
	make_current()

func set_diagnostics_visible(value: bool) -> void:
	_diagnostics = value
	size = view_size + (4.0 if value else 0.0)

func _desired_focus() -> Vector3:
	var desired: Vector3 = target.global_position + Vector3(look_ahead.x, 0, look_ahead.y)
	desired.x = clampf(desired.x, focus_bounds.position.x, focus_bounds.end.x)
	desired.z = clampf(desired.z, focus_bounds.position.y, focus_bounds.end.y)
	return desired

func _place_camera() -> void:
	global_position = focus + Vector3(0, height, distance) + camera_offset
	look_at(focus, Vector3.UP)
	size = view_size + (4.0 if _diagnostics else 0.0)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired: Vector3 = _desired_focus()
	var weight: float = 1.0 - exp(-tracking_speed * delta)
	focus.x = lerpf(focus.x, desired.x, weight)
	focus.z = lerpf(focus.z, desired.z, weight)
	focus.y = lerpf(focus.y, desired.y, 1.0 - exp(-vertical_tracking_speed * delta))
	_place_camera()
	# Fade only the imported solids that hide the ball; collisions and model geometry stay intact.
	for part in _occluders:
		if not is_instance_valid(part):
			continue
		var hit: Variant = part.get_aabb().intersects_segment(part.to_local(global_position), part.to_local(target.global_position + Vector3.UP * 0.2))
		var fade: float = occlusion_transparency if hit != null else 0.0
		part.transparency = lerpf(part.transparency, fade, 1.0 - exp(-10.0 * delta))
		# Explicit alpha blending avoids an opaque depth prepass hiding the ball on Metal.
		part.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if part.transparency > 0.001 else BaseMaterial3D.TRANSPARENCY_DISABLED
