extends RefCounted
## Applied once after a level's children finish building. Source resources stay untouched.
const FLOOR_SHADER = preload("res://shaders/ice_floor.gdshader")
const FRICTION: float = 0.02
const LINEAR_DAMP: float = 0.012
const ANGULAR_DAMP: float = 0.025

static func apply(game: Node3D) -> void:
	var platform: PhysicsBody3D = game.get_node("Platform")
	var ball: RigidBody3D = game.get_node("Ball")
	platform.physics_material_override = _slippery(platform.physics_material_override)
	ball.physics_material_override = _slippery(ball.physics_material_override)
	# Replace also removes the project default damping; Add would leave hidden drag.
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = LINEAR_DAMP
	ball.angular_damp = ANGULAR_DAMP
	var floor_mesh: MeshInstance3D = platform.get_node("MeshInstance3D")
	var ice := ShaderMaterial.new()
	ice.shader = FLOOR_SHADER
	floor_mesh.material_override = ice
	# The generated OBJ parts and basic maze retain their geometry and identifying colors.
	_tint_obstacles(platform, floor_mesh)
	var world: WorldEnvironment = game.get_node("WorldEnvironment")
	world.environment = world.environment.duplicate()
	world.environment.background_color = Color("071629")
	world.environment.ambient_light_color = Color("b5dcff")
	_add_indicator(game)

static func _slippery(original: PhysicsMaterial) -> PhysicsMaterial:
	var material: PhysicsMaterial = original.duplicate() if original != null else PhysicsMaterial.new()
	material.friction = FRICTION
	material.rough = false
	# Keep each level's existing bounce/absorbent response, mass, gravity and CCD.
	return material

static func _tint_obstacles(node: Node, floor_mesh: MeshInstance3D) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D and child != floor_mesh and child.visible:
			var mesh := child as MeshInstance3D
			# Goal remains green, including the original imported LEVEL04 round disc.
			var material: Material = mesh.get_active_material(0) if mesh.mesh != null and mesh.mesh.get_surface_count()>0 else null
			if material is StandardMaterial3D and mesh.name != "GoalMarker":
				var color: Color = material.albedo_color
				var green_marker: bool = color.g > color.r * 1.4 and color.g > color.b * 1.2
				if not green_marker:
					var frozen: StandardMaterial3D = material.duplicate()
					frozen.albedo_color = color.lerp(Color("a0d3ef"), 0.24)
					frozen.roughness = minf(material.roughness, 0.3)
					frozen.metallic = minf(material.metallic, 0.35)
					mesh.material_override = frozen
		_tint_obstacles(child, floor_mesh)

static func _add_indicator(game: Node) -> void:
	var badge := Label.new()
	badge.name = "IceModeBadge"
	badge.text = "ICE MODE  /  EXTREME CHALLENGE"
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color("bdeeff"))
	badge.add_theme_color_override("font_shadow_color", Color("07111f"))
	badge.add_theme_constant_override("shadow_outline_size", 6)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud: Control = game.get_node("HUD/GameplayUI")
	hud.add_child(badge)
	# Main is ready after the HUD builds its overlays. Keep this late-added
	# gameplay label behind both PauseMenu and the mission result's shade.
	hud.move_child(badge, 0)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	badge.offset_top = 142
	badge.offset_bottom = 176
