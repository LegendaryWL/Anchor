class_name RoomSwitcher
extends Node

signal room_switch_requested(room_id: String)
signal camera_changed(room_id: String, camera: Camera3D)

@export var room_a_id := "room_a"
@export var room_b_id := "room_b"
@export var bow_room_id := "bow_room"

@export var room_a_camera_path: NodePath
@export var room_b_camera_path: NodePath
@export var bow_room_camera_path: NodePath

var _room_cameras: Dictionary = {}


func _ready() -> void:
	_cache_camera(room_a_id, room_a_camera_path)
	_cache_camera(room_b_id, room_b_camera_path)
	_cache_camera(bow_room_id, bow_room_camera_path)

	if not RoomStateManager.room_changed.is_connected(_on_room_changed):
		RoomStateManager.room_changed.connect(_on_room_changed)

	_on_room_changed(RoomStateManager.current_room_id)


func request_switch_room(room_id: String) -> void:
	if room_id.is_empty():
		return
	if room_id == RoomStateManager.current_room_id:
		return

	room_switch_requested.emit(room_id)
	RoomStateManager.set_current_room(room_id)


func register_room_camera(room_id: String, camera: Camera3D) -> void:
	if room_id.is_empty() or camera == null:
		return

	_room_cameras[room_id] = camera
	if room_id == RoomStateManager.current_room_id:
		_activate_camera(room_id, camera)


func get_camera_for_room(room_id: String) -> Camera3D:
	return _room_cameras.get(room_id)


func _cache_camera(room_id: String, camera_path: NodePath) -> void:
	if room_id.is_empty() or camera_path.is_empty():
		return

	var camera := get_node_or_null(camera_path) as Camera3D
	if camera == null:
		push_warning("RoomSwitcher: camera path for %s is not a Camera3D: %s" % [room_id, camera_path])
		return

	_room_cameras[room_id] = camera


func _on_room_changed(room_id: String) -> void:
	var camera := get_camera_for_room(room_id)
	if camera == null:
		return

	_activate_camera(room_id, camera)


func _activate_camera(room_id: String, camera: Camera3D) -> void:
	for candidate in _room_cameras.values():
		if candidate is Camera3D:
			candidate.current = candidate == camera

	camera_changed.emit(room_id, camera)
