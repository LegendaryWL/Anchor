class_name CameraLookLimiter
extends Node3D

@export var enabled := true
@export var mouse_sensitivity := 0.08
@export var yaw_limit_degrees := 10.0
@export var pitch_limit_degrees := 5.0
@export var require_captured_mouse := false

var _base_rotation: Vector3
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	_base_rotation = rotation_degrees


func reset_look() -> void:
	_yaw = 0.0
	_pitch = 0.0
	rotation_degrees = _base_rotation


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if require_captured_mouse and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if not (event is InputEventMouseMotion):
		return

	var motion := event as InputEventMouseMotion
	_yaw = clampf(_yaw - motion.relative.x * mouse_sensitivity, -yaw_limit_degrees, yaw_limit_degrees)
	_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -pitch_limit_degrees, pitch_limit_degrees)
	rotation_degrees = _base_rotation + Vector3(_pitch, _yaw, 0.0)
