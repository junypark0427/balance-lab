extends Node3D

var failure_count: int = 0
var elapsed_seconds: float = 0.0
var game_status: String = "IN PROGRESS"
var goal_reached: bool = false
var _reset_notice_left: float = 0.0
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


func _physics_process(delta: float) -> void:
	if not goal_reached:
		elapsed_seconds += delta
		if _reset_notice_left > 0:
			_reset_notice_left = maxf(0.0, _reset_notice_left - delta)
			if _reset_notice_left == 0.0:
				game_status = "IN PROGRESS"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		ball.request_reset()


func _on_goal_body_entered(body: Node3D) -> void:
	if body == ball and not ball.freeze:
		goal_reached = true
		game_status = "COMPLETE"
		status.text = "GOAL!  Press R to try again."


func _on_ball_respawned() -> void:
	goal_reached = false
	game_status = "IN PROGRESS" if failure_count == 0 else "BALL RESET"
	_reset_notice_left = 2.0 if failure_count > 0 else 0.0
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
