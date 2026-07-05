extends Node3D

@onready var camera_room_a: Camera3D = $Cameras/camera_room_a
@onready var camera_room_b: Camera3D = $Cameras/camera_room_b
@onready var camera_bow: Camera3D = $Cameras/camera_bow

var current_room := ""
var _last_key_room := ""
var _hud_label: Label
var _message := ""

func _ready() -> void:
	_setup_temp_hud()
	if _gm() != null:
		_gm().call("reset_game")
		_gm().call("set_attacks_enabled", true)
		if not _gm().is_connected("game_over", Callable(self, "_on_game_over")):
			_gm().connect("game_over", Callable(self, "_on_game_over"))
	print("Playable temp controller ready. 1/2/3 switch, hold Q anchor, hold W window, E candle, Space black hand.")
	switch_camera("room_a", true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var room_id := _room_from_key(key_event.keycode)
		if room_id == "":
			room_id = _room_from_key(key_event.physical_keycode)
		if room_id != "":
			switch_camera(room_id)
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
	_poll_room_keys()
	_poll_hold_actions(delta)
	_update_temp_hud()

func _poll_room_keys() -> void:
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
		"1/2/3: switch rooms | Hold Q: repair anchor | Hold W: repair window",
		"E: light candle | Space: expel black hand | F: force attack | P: phase2 | R: reset",
		"Room/View: %s / %s" % [snapshot.get("current_room_id", ""), snapshot.get("current_view_id", "")],
		"SAN: %.0f / %.0f   Phase: %d" % [snapshot.get("san", 0.0), snapshot.get("san_max", 0.0), snapshot.get("phase", 0)],
		"Anchor: %.0f%%   Attack: %s" % [snapshot.get("anchor_progress", 0.0) * 100.0, attack_text],
		"Message: " + _message,
	])

func _gm() -> Node:
	return get_node_or_null("/root/GameManager")
