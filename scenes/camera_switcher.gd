extends Node3D

const INTRO_FADE_DURATION := 0.8
const GOOD_END_SCENE := "res://scenes/end_good.tscn"
const BAD_END_SCENE := "res://scenes/end_bad.tscn"
const GUIDE_SCENE := "res://scenes/guide_menu.tscn"

@onready var camera_room_a: Camera3D = $Cameras/camera_room_a
@onready var camera_room_b: Camera3D = $Cameras/camera_room_b
@onready var camera_bow: Camera3D = $Cameras/camera_bow

var current_room := ""
var _last_key_room := ""
var _message := ""
var _intro_fade_rect: ColorRect

func _ready() -> void:
	_fade_from_black()
	if _gm() != null:
		_gm().call("reset_game")
		_gm().call("set_attacks_enabled", true)
		if not _gm().is_connected("game_over", Callable(self, "_on_game_over")):
			_gm().connect("game_over", Callable(self, "_on_game_over"))
	switch_camera("bow_room", true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_H or key_event.physical_keycode == KEY_H:
			_open_guide_overlay()
			get_viewport().set_input_as_handled()
			return
		var room_id := _room_from_key(key_event.keycode)
		if room_id == "":
			room_id = _room_from_key(key_event.physical_keycode)
		if room_id != "":
			switch_camera(room_id)


func _process(_delta: float) -> void:
	_poll_room_keys()


func _poll_room_keys() -> void:
	var room_id := ""
	if Input.is_physical_key_pressed(KEY_1) or Input.is_physical_key_pressed(KEY_KP_1):
		room_id = "room_a"
	elif Input.is_physical_key_pressed(KEY_2) or Input.is_physical_key_pressed(KEY_KP_2):
		room_id = "room_b"
	elif Input.is_physical_key_pressed(KEY_3) or Input.is_physical_key_pressed(KEY_KP_3):
		room_id = "bow_room"

	if room_id == "":
		_last_key_room = ""
		return

	if room_id != _last_key_room:
		_last_key_room = room_id
		switch_camera(room_id)


func _room_from_key(keycode: Key) -> String:
	match keycode:
		KEY_1, KEY_KP_1:
			return "room_a"
		KEY_2, KEY_KP_2:
			return "room_b"
		KEY_3, KEY_KP_3:
			return "bow_room"
		_:
			return ""


func switch_camera(room_id: String, force: bool = false) -> void:
	if not force and current_room == room_id:
		return
	current_room = room_id

	var camera: Camera3D = null
	match room_id:
		"room_a":
			camera = camera_room_a
		"room_b":
			camera = camera_room_b
		"bow_room":
			camera = camera_bow

	if camera == null:
		push_error("No camera found for room_id: " + room_id)
		return

	camera.make_current()
	if camera.has_method("reset_look"):
		camera.call("reset_look")
	
	_sync_game_room(room_id)

func _sync_game_room(room_id: String) -> void:
	var view_id := room_id
	if room_id == "bow_room":
		view_id = "bow_room_1"

	if _gm() != null:
		_gm().call("switch_room", view_id)

	var room_state_manager := get_node_or_null("/root/RoomStateManager")
	if room_state_manager != null and room_state_manager.has_method("set_current_room"):
		room_state_manager.set_current_room(room_id)

func _on_game_over(result: String) -> void:
	_message = "GAME OVER: " + result
	var scene_path := GOOD_END_SCENE if result == "win" else BAD_END_SCENE
	get_tree().change_scene_to_file(scene_path)

func _open_guide_overlay() -> void:
	if get_node_or_null("GuideMenuOverlay") != null:
		return
	var packed_scene := load(GUIDE_SCENE) as PackedScene
	if packed_scene == null:
		push_error("Failed to load guide scene: " + GUIDE_SCENE)
		return
	var guide := packed_scene.instantiate()
	guide.name = "GuideMenuOverlay"
	guide.set_meta("opened_from_game", true)
	add_child(guide)
	get_tree().paused = true


func set_status_message(message: String) -> void:
	_message = message

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _fade_from_black() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IntroFadeLayer"
	layer.layer = 100
	add_child(layer)

	_intro_fade_rect = ColorRect.new()
	_intro_fade_rect.name = "FadeRect"
	_intro_fade_rect.color = Color.BLACK
	_intro_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_intro_fade_rect)

	_intro_fade_rect.visible = true
	_intro_fade_rect.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(_intro_fade_rect, "modulate:a", 0.0, INTRO_FADE_DURATION)
	tween.finished.connect(func() -> void:
		layer.queue_free()
	)
