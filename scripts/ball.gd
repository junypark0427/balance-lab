extends RigidBody3D

signal respawned

@export var platform: Node3D
@export var spawn_local_position: Vector3 = Vector3(0.0, 0.85, 0.0)
@export var fall_height: float = -4.0
var _reset_requested: bool = false
var _initial_transform: Transform3D


func _ready() -> void:
	_initial_transform = global_transform


func request_reset() -> void:
	# Frozen bodies do not receive force integration callbacks.
	if freeze:
		_reset_requested = false
		global_transform = _initial_transform
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		reset_physics_interpolation()
		respawned.emit()
		return
	_reset_requested = true
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if freeze:
		return
	if not _reset_requested and state.transform.origin.y >= fall_height:
		return
	# Reset through the physics state, including all momentum.
	var spawn_position: Vector3 = spawn_local_position
	if is_instance_valid(platform):
		spawn_position = platform.to_global(spawn_local_position)
	state.transform = Transform3D(Basis.IDENTITY, spawn_position)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.sleeping = false
	_reset_requested = false
	reset_physics_interpolation()
	respawned.emit()
