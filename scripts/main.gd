extends Node3D

@onready var ball: RigidBody3D = $Ball
@onready var status: Label = $HUD/Status
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# Godot cameras look along local -Z; look_at avoids Euler/sign mistakes.
	camera.look_at($Platform.global_position, Vector3.UP)
	camera.make_current()
	$Platform/Goal.body_entered.connect(_on_goal_body_entered)
	ball.respawned.connect(_on_ball_respawned)
	_on_ball_respawned()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		ball.request_reset()


func _on_goal_body_entered(body: Node3D) -> void:
	if body == ball and not ball.freeze:
		status.text = "GOAL!  Press R to try again."


func _on_ball_respawned() -> void:
	status.text = "TILT TEST: Ball frozen. Check the Godot Output panel." if ball.freeze else "Move the ball to the green target."
