extends Node3D

@onready var camera_room_a: Camera3D = $Cameras/camera_room_a
@onready var camera_room_b: Camera3D = $Cameras/camera_room_b
@onready var camera_bow: Camera3D = $Cameras/camera_bow

var current_room := ""

func _ready() -> void:
	print("Camera switcher ready. Press 1/2/3.")
	switch_camera("room_a")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_KP_1:
				switch_camera("room_a")
			KEY_2, KEY_KP_2:
				switch_camera("room_b")
			KEY_3, KEY_KP_3:
				switch_camera("bow_room")

func switch_camera(room_id: String) -> void:
	if current_room == room_id:
		return
	current_room = room_id
	match room_id:
		"room_a":
			camera_room_a.make_current()
		"room_b":
			camera_room_b.make_current()
		"bow_room":
			camera_bow.make_current()
	print("switch_camera -> ", room_id)
