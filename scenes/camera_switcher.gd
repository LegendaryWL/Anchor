extends Node3D

@onready var camera_room_a: Camera3D = $Cameras/camera_room_a
@onready var camera_room_b: Camera3D = $Cameras/camera_room_b
@onready var camera_bow: Camera3D = $Cameras/camera_bow

const HEAD_TURN_STEP_DEGREES := 20.0
const HEAD_TURN_LIMIT_DEGREES := 20.0
const HEAD_TURN_SPEED_DEGREES := 80.0

const ROOM_VIEW_CONFIGS := {
	"room_a": [
		{
			"label": "front wall",
			"position": Vector3(56.15, 0.36, -2.54),
			"target": Vector3(55.509, 0.212, -3.288),
		},
		{
			"label": "left wall",
			"position": Vector3(56.1, 0.36, -2.72),
			"target": Vector3(55.18, 0.212, -2.98),
		},
		{
			"label": "door side",
			"position": Vector3(55.98, 0.36, -2.96),
			"target": Vector3(55.12, 0.212, -3.1),
		},
		{
			"label": "right wall",
			"position": Vector3(56.12, 0.36, -2.66),
			"target": Vector3(55.82, 0.212, -3.68),
		},
	],
	"room_b": [
		{
			"label": "front wall",
			"position": Vector3(55.895, 0.43, -0.93),
			"target": Vector3(55.542, 0.266, -1.387),
		},
		{
			"label": "left wall",
			"position": Vector3(55.87, 0.43, -0.96),
			"target": Vector3(55.16, 0.266, -1.13),
		},
		{
			"label": "door side",
			"position": Vector3(55.895, 0.43, -0.93),
			"target": Vector3(55.542, 0.266, -1.387),
		},
		{
			"label": "right wall",
			"position": Vector3(55.895, 0.43, -0.93),
			"target": Vector3(55.542, 0.266, -1.387),
		},
	],
	"bow_room": [
		{
			"label": "front wall",
			"position": Vector3(55.98, 0.36, 2.22),
			"target": Vector3(55.42, 0.214, 2.15),
		},
		{
			"label": "left wall",
			"position": Vector3(55.98, 0.36, 2.22),
			"target": Vector3(55.42, 0.214, 2.15),
		},
		{
			"label": "door side",
			"position": Vector3(55.98, 0.36, 2.22),
			"target": Vector3(55.4, 0.214, 2.62),
		},
		{
			"label": "right wall",
			"position": Vector3(55.98, 0.36, 2.22),
			"target": Vector3(55.4, 0.214, 2.62),
		},
	],
}

var current_room := ""
var _hud_label: Label
var _message := ""
var _room_cameras: Dictionary = {}
var _camera_turn_steps: Dictionary = {}
var _head_turn_current_radians := 0.0
var _head_turn_target_radians := 0.0

func _ready() -> void:
	_setup_room_cameras()
	_setup_temp_hud()
	if _gm() != null:
		_gm().call("reset_game")
		_gm().call("set_attacks_enabled", true)
		if not _gm().is_connected("game_over", Callable(self, "_on_game_over")):
			_gm().connect("game_over", Callable(self, "_on_game_over"))
	print("Playable temp controller ready. 1/2/3 switch rooms, Left/Right switch fixed room views, A/D turn head, hold Q anchor, hold W window, E candle, Space black hand.")
	switch_camera("room_a", true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var room_id := _room_from_key(key_event.keycode)
		if room_id == "":
			room_id = _room_from_key(key_event.physical_keycode)
		if room_id != "":
			switch_camera(room_id, true)
			return

		if _handle_turn_key(key_event.keycode):
			return
		if _handle_turn_key(key_event.physical_keycode):
			return

		match key_event.keycode:
			KEY_E:
				_light_candle_in_view()
			KEY_SPACE:
				_expel_black_hand_in_view()
			KEY_F:
				_force_attack_for_testing()
			KEY_P:
				_gm().call("enter_phase_2_for_test")
				_message = "Debug: entered phase 2"
			KEY_R:
				_gm().call("reset_game")
				_gm().call("set_attacks_enabled", true)
				switch_camera("room_a", true)
				_message = "Game reset"

func _process(delta: float) -> void:
	_update_head_turn(delta)
	_poll_hold_actions(delta)
	_update_temp_hud()

func _poll_hold_actions(delta: float) -> void:
	if bool(_gm().get("is_game_over")):
		return

	if Input.is_physical_key_pressed(KEY_Q):
		_gm().call("repair_anchor", delta)
		_message = "Repairing anchor..."

	if Input.is_physical_key_pressed(KEY_W):
		var window_id := str(_gm().call("get_primary_window_in_view"))
		if window_id == "":
			_message = "No window in current view"
		elif bool(_gm().call("repair_window", window_id, delta)):
			_message = "Repairing " + window_id
		else:
			_message = "Cannot repair " + window_id

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

func _handle_turn_key(keycode: Key) -> bool:
	match keycode:
		KEY_LEFT:
			_turn_current_view(1)
			return true
		KEY_RIGHT:
			_turn_current_view(-1)
			return true
		KEY_A:
			_adjust_head_turn(HEAD_TURN_STEP_DEGREES)
			return true
		KEY_D:
			_adjust_head_turn(-HEAD_TURN_STEP_DEGREES)
			return true
		KEY_UP, KEY_DOWN:
			return true
		_:
			return false

func switch_camera(room_id: String, force: bool = false) -> void:
	if not force and current_room == room_id:
		return
	current_room = room_id
	_reset_view_turn(room_id)

	var camera := _camera_for_room(room_id)
	if camera != null:
		camera.make_current()

	_sync_game_room(room_id)
	print("switch_camera -> ", room_id)

func _setup_room_cameras() -> void:
	_room_cameras = {
		"room_a": camera_room_a,
		"room_b": camera_room_b,
		"bow_room": camera_bow,
	}

	for room_id in _room_cameras.keys():
		var camera: Camera3D = _camera_for_room(room_id)
		if camera == null:
			continue
		_camera_turn_steps[room_id] = 0

func _camera_for_room(room_id: String) -> Camera3D:
	return _room_cameras.get(room_id, null) as Camera3D

func _turn_current_view(step_delta: int) -> void:
	if current_room.is_empty():
		return

	var room_views: Array = ROOM_VIEW_CONFIGS.get(current_room, []) as Array
	if room_views.is_empty():
		return

	var step: int = int(_camera_turn_steps.get(current_room, 0))
	step = wrapi(step + step_delta, 0, room_views.size())
	_camera_turn_steps[current_room] = step
	_reset_head_turn()
	_apply_view_turn(current_room)
	_message = "View: " + _view_name_from_step(step)

func _reset_view_turn(room_id: String) -> void:
	_camera_turn_steps[room_id] = 0
	_reset_head_turn()
	_apply_view_turn(room_id)
	_message = "View: front wall"

func _apply_view_turn(room_id: String) -> void:
	var camera := _camera_for_room(room_id)
	if camera == null:
		return

	var room_views: Array = ROOM_VIEW_CONFIGS.get(room_id, []) as Array
	if room_views.is_empty():
		return

	var step: int = int(_camera_turn_steps.get(room_id, 0))
	step = clampi(step, 0, room_views.size() - 1)
	var view: Dictionary = room_views[step] as Dictionary
	_apply_camera_view(camera, view, _head_turn_current_radians)

func _apply_camera_view(camera: Camera3D, view: Dictionary, head_turn_radians: float) -> void:
	var view_position: Vector3 = view.get("position", camera.position)
	var base_target: Vector3 = view.get("target", view_position + Vector3.FORWARD)
	var look_direction := base_target - view_position
	if look_direction.length_squared() <= 0.000001:
		look_direction = Vector3.FORWARD
	look_direction = look_direction.rotated(Vector3.UP, head_turn_radians)
	camera.position = view_position
	camera.look_at(view_position + look_direction, Vector3.UP)

func _adjust_head_turn(delta_degrees: float) -> void:
	var next_target_degrees := rad_to_deg(_head_turn_target_radians) + delta_degrees
	next_target_degrees = clampf(next_target_degrees, -HEAD_TURN_LIMIT_DEGREES, HEAD_TURN_LIMIT_DEGREES)
	_head_turn_target_radians = deg_to_rad(next_target_degrees)

func _reset_head_turn() -> void:
	_head_turn_current_radians = 0.0
	_head_turn_target_radians = 0.0

func _update_head_turn(delta: float) -> void:
	if current_room.is_empty():
		return
	if is_equal_approx(_head_turn_current_radians, _head_turn_target_radians):
		return

	var turn_speed := deg_to_rad(HEAD_TURN_SPEED_DEGREES) * delta
	_head_turn_current_radians = move_toward(_head_turn_current_radians, _head_turn_target_radians, turn_speed)
	_apply_view_turn(current_room)

func _view_name_from_step(step: int) -> String:
	var room_views: Array = ROOM_VIEW_CONFIGS.get(current_room, []) as Array
	if step < 0 or step >= room_views.size():
		return "front wall"
	var view: Dictionary = room_views[step] as Dictionary
	return str(view.get("label", "front wall"))

func _sync_game_room(room_id: String) -> void:
	var view_id := room_id
	if room_id == "bow_room":
		view_id = "bow_room_1"

	if _gm() != null:
		_gm().call("switch_room", view_id)

	var room_state_manager := get_node_or_null("/root/RoomStateManager")
	if room_state_manager != null and room_state_manager.has_method("set_current_room"):
		room_state_manager.set_current_room(room_id)

func _light_candle_in_view() -> void:
	var candle_id := str(_gm().call("get_primary_candle_in_view", true))
	if candle_id == "":
		_message = "No candle in current view"
		return
	if bool(_gm().call("light_candle", candle_id)):
		_message = "Lit " + candle_id
	else:
		_message = "Cannot light " + candle_id

func _expel_black_hand_in_view() -> void:
	var candle_id := str(_gm().call("get_candle_under_attack_in_view"))
	if candle_id == "":
		_message = "No black hand in current view"
		return
	if bool(_gm().call("expel_black_hand", candle_id)):
		_message = "Expelling black hand: " + candle_id
	else:
		_message = "Cannot expel black hand"

func _force_attack_for_testing() -> void:
	if int(_gm().get("phase")) == 1:
		var window_id := str(_gm().call("get_primary_window_in_view"))
		if window_id != "" and bool(_gm().call("force_window_attack", window_id, 12.0)):
			_message = "Debug attack: " + window_id
		else:
			_message = "Cannot force window attack"
	else:
		var candle_id := str(_gm().call("get_primary_lit_candle_in_view"))
		if candle_id != "" and bool(_gm().call("force_candle_attack", candle_id, 12.0, 5)):
			_message = "Debug black hand: " + candle_id
		else:
			_message = "Cannot force candle attack"

func _on_game_over(result: String) -> void:
	_message = "GAME OVER: " + result

func _setup_temp_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TempPlayableHud"
	add_child(layer)

	_hud_label = Label.new()
	_hud_label.name = "TempStatus"
	_hud_label.position = Vector2(16, 16)
	_hud_label.size = Vector2(760, 220)
	_hud_label.add_theme_font_size_override("font_size", 18)
	layer.add_child(_hud_label)

func _update_temp_hud() -> void:
	if _hud_label == null or _gm() == null:
		return

	var snapshot: Dictionary = _gm().call("get_snapshot")
	var active_attack: Dictionary = snapshot.get("active_attack", {})
	var attack_text := "none"
	if not active_attack.is_empty():
		attack_text = "%s %s %.1fs" % [active_attack.get("type", ""), active_attack.get("target_id", ""), snapshot.get("attack_timer", 0.0)]

	_hud_label.text = "\n".join([
		"TEMP PLAYABLE BUILD",
		"1/2/3: switch rooms | Left/Right: switch fixed room views",
		"A/D: turn head 20 deg | Up/Down: unbound",
		"Hold Q: repair anchor | Hold W: repair window",
		"E: light candle | Space: expel black hand | F: force attack | P: phase2 | R: reset",
		"Room/View: %s / %s" % [snapshot.get("current_room_id", ""), snapshot.get("current_view_id", "")],
		"SAN: %.0f / %.0f   Phase: %d" % [snapshot.get("san", 0.0), snapshot.get("san_max", 0.0), snapshot.get("phase", 0)],
		"Anchor: %.0f%%   Attack: %s" % [snapshot.get("anchor_progress", 0.0) * 100.0, attack_text],
		"Message: " + _message,
	])

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")
