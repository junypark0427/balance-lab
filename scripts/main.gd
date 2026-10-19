extends Node3D

var failure_count: int = 0
@onready var ball: RigidBody3D = $Ball
@onready var status: Label = $HUD/Status
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# Godot cameras look along local -Z; look_at avoids Euler/sign mistakes.
	camera.look_at($Platform.global_position, Vector3.UP)
	camera.make_current()
	$Platform/Goal.body_entered.connect(_on_goal_body_entered)
	ball.respawned.connect(_on_ball_respawned)
	ball.fell.connect(_on_ball_fell)
	_on_ball_respawned()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		ball.request_reset()


func _on_goal_body_entered(body: Node3D) -> void:
	if body == ball and not ball.freeze:
		status.text = "GOAL!  Press R to try again."


func _on_ball_respawned() -> void:
	if ball.freeze:
		status.text = "Ball frozen. Check the Godot Output panel."
	elif failure_count > 0:
		status.text = "Falls: %d | Ball reset. Move to the green target. R: Retry" % failure_count
	else:
		status.text = "Move the ball to the green target. R: Retry"


func _on_ball_fell() -> void:
	failure_count += 1
	print("[Game] FALL #%d: resetting ball" % failure_count)
	ball.request_reset()
