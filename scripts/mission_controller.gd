extends Node
## Reusable completion gate. Assign nodes in each map; no goal coordinates are assumed.
signal completed

@export var goal: Area3D
@export var ball: RigidBody3D
@export var platform: Node3D
@export var particles_enabled: bool = true
var is_completed: bool = false

func _ready() -> void:
	if not is_instance_valid(goal) or not is_instance_valid(ball) or not is_instance_valid(platform):
		push_error("MissionController: assign Goal Area3D, Ball and Platform in the Inspector.")
		return
	goal.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_completed or body != ball or ball.freeze:
		return
	# Latch before signals/deferred work so multiple contacts cannot complete twice.
	is_completed = true
	platform.set_physics_process(false)
	# Report zero consumed input while leaving the input adapter available for diagnostics.
	if "last_received_axes" in platform:
		platform.last_received_axes = Vector2.ZERO
	goal.set_deferred("monitoring", false)
	_lock_ball.call_deferred()
	if particles_enabled and not Session.reduced_motion:
		_burst.call_deferred()
	completed.emit()

func _lock_ball() -> void:
	# body_entered runs during physics query flushing; freeze after that phase.
	if not is_instance_valid(ball):
		return
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func _burst() -> void:
	if not is_instance_valid(goal):
		return
	var particles := CPUParticles3D.new()
	particles.name = "MissionSuccessBurst"
	particles.add_to_group("mission_success_particles")
	particles.emitting = false
	particles.amount = 64
	particles.lifetime = 1.7
	particles.one_shot = true
	particles.explosiveness = 0.96
	particles.direction = Vector3.UP
	particles.spread = 65.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0
	particles.gravity = Vector3(0, -2.5, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.3
	particles.local_coords = false
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("70e7ff")
	material.emission_enabled = true
	material.emission = Color("39caff")
	material.emission_energy_multiplier = 2.0
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color("94efff"), Color("ffbe75"), Color(1, 0.65, 0.3, 0)])
	particles.color_ramp = gradient
	goal.add_child(particles)
	particles.top_level = true
	particles.global_position = goal.global_position + Vector3.UP * 0.2
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
