extends Node3D

@onready var camera_room_a: Camera3D = $Cameras/camera_room_a
@onready var camera_room_b: Camera3D = $Cameras/camera_room_b
@onready var camera_bow: Camera3D = $Cameras/camera_bow

var current_room := ""
var _last_key_room := ""

func _ready() -> void:
	print("Camera switcher ready. Press 1/2/3 or Left/Right/Up.")
	switch_camera("room_a", true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var room_id := _room_from_key(key_event.keycode)
		if room_id == "":
			room_id = _room_from_key(key_event.physical_keycode)
		if room_id != "":
			switch_camera(room_id)

func _process(_delta: float) -> void:
	var room_id := ""
	if Input.is_physical_key_pressed(KEY_1) or Input.is_physical_key_pressed(KEY_KP_1) or Input.is_physical_key_pressed(KEY_LEFT):
		room_id = "room_a"
	elif Input.is_physical_key_pressed(KEY_2) or Input.is_physical_key_pressed(KEY_KP_2) or Input.is_physical_key_pressed(KEY_RIGHT):
		room_id = "room_b"
	elif Input.is_physical_key_pressed(KEY_3) or Input.is_physical_key_pressed(KEY_KP_3) or Input.is_physical_key_pressed(KEY_UP):
		room_id = "bow_room"

	if room_id == "":
		_last_key_room = ""
		return

	if room_id != _last_key_room:
		_last_key_room = room_id
		switch_camera(room_id)

func _room_from_key(keycode: Key) -> String:
	match keycode:
		KEY_1, KEY_KP_1, KEY_LEFT:
			return "room_a"
		KEY_2, KEY_KP_2, KEY_RIGHT:
			return "room_b"
		KEY_3, KEY_KP_3, KEY_UP:
			return "bow_room"
		_:
			return ""

func switch_camera(room_id: String, force: bool = false) -> void:
	if not force and current_room == room_id:
		return
	current_room = room_id

	match room_id:
		"room_a":
			camera_room_a.make_current()
		"room_b":
			camera_room_b.make_current()
		"bow_room":
			camera_bow.make_current()

	_sync_game_room(room_id)
	print("switch_camera -> ", room_id)

func _sync_game_room(room_id: String) -> void:
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("switch_room"):
		game_manager.switch_room(room_id)

	var room_state_manager := get_node_or_null("/root/RoomStateManager")
	if room_state_manager != null and room_state_manager.has_method("set_current_room"):
		room_state_manager.set_current_room(room_id)
