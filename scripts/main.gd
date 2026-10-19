extends Node3D

signal mission_succeeded(clear_time: float)

var failure_count: int = 0
var elapsed_seconds: float = 0.0
var game_status: String = "IN PROGRESS"
var goal_reached: bool = false
var clear_time: float = -1.0
var _reset_notice_left: float = 0.0
@onready var ball: RigidBody3D = $Ball
@onready var status: Label = $HUD/Status
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# Godot cameras look along local -Z; look_at avoids Euler/sign mistakes.
	camera.look_at($Platform.global_position, Vector3.UP)
	camera.make_current()
	$MissionController.completed.connect(_on_mission_completed)
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
	if not goal_reached and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		ball.request_reset()


func _on_mission_completed() -> void:
	if goal_reached:
		return
	goal_reached = true
	clear_time = elapsed_seconds
	game_status = "COMPLETE"
	status.text = "GOAL! MISSION SUCCESS!"
	mission_succeeded.emit(clear_time)


func _on_ball_respawned() -> void:
	if goal_reached:
		return
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
	if goal_reached:
		return
	failure_count += 1
	print("[Game] FALL #%d: resetting ball" % failure_count)
	ball.request_reset()
