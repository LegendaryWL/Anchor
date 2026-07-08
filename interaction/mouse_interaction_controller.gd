class_name MouseInteractionController
extends Node

signal status_changed(message: String)

@export var ray_length := 100.0
@export var candle_hold_seconds := 0.8

var _held_target_id := ""
var _held_action := ""
var _held_elapsed := 0.0
var _candle_completed := false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_primary_action()
		else:
			_end_primary_action()


func _process(delta: float) -> void:
	if _held_target_id == "":
		return

	match _held_action:
		"repair_anchor":
			if GameManager.repair_anchor(delta):
				_set_status("Repairing anchor...")
			else:
				_set_status("Anchor can only be repaired in bow_room")
				_clear_hold()
		"repair_window":
			if GameManager.repair_window(_held_target_id, delta):
				_set_status("Repairing " + _held_target_id)
			else:
				_set_status("Cannot repair " + _held_target_id)
				_clear_hold()
		"light_candle":
			_held_elapsed += delta
			if _held_elapsed >= candle_hold_seconds and not _candle_completed:
				_candle_completed = true
				if GameManager.light_candle(_held_target_id):
					_set_status("Lit " + _held_target_id)
				else:
					_set_status("Cannot light " + _held_target_id)
				_clear_hold()


func _begin_primary_action() -> void:
	var target_id := _get_hovered_area_id()
	if target_id == "":
		_clear_hold()
		return

	if target_id == "black_hand":
		_expel_black_hand()
		return

	if target_id == "anchor_device":
		if _can_repair_anchor():
			_start_hold(target_id, "repair_anchor")
			_set_status("Hold LMB: repairing anchor")
		else:
			_set_status("Anchor can only be repaired in bow_room")
		return

	if target_id.begins_with("window_"):
		if GameManager.can_repair_window(target_id):
			_start_hold(target_id, "repair_window")
			_set_status("Hold LMB: repairing " + target_id)
		else:
			_set_status("Cannot repair " + target_id)
		return

	if target_id.begins_with("candle_"):
		if GameManager.can_light_candle(target_id):
			_start_hold(target_id, "light_candle")
			_set_status("Hold LMB: lighting " + target_id)
		else:
			_set_status("Cannot light " + target_id)
		return

	_set_status("No interaction for " + target_id)


func _end_primary_action() -> void:
	if _held_action != "":
		_set_status("Stopped " + _held_action)
	_clear_hold()


func _start_hold(target_id: String, action: String) -> void:
	_held_target_id = target_id
	_held_action = action
	_held_elapsed = 0.0
	_candle_completed = false


func _clear_hold() -> void:
	_held_target_id = ""
	_held_action = ""
	_held_elapsed = 0.0
	_candle_completed = false


func _expel_black_hand() -> void:
	var candle_id := GameManager.get_candle_under_attack_in_view()
	if candle_id == "":
		_set_status("No black hand in current view")
		return
	if GameManager.expel_black_hand(candle_id):
		var state := GameManager.get_black_hand_expel_state()
		if state.is_empty():
			_set_status("Black hand expelled")
		else:
			_set_status(
				"Expelling black hand: %d / %d" % [
					int(state.get("expel_progress", 0)),
					int(state.get("expel_required", 0)),
				]
			)
	else:
		_set_status("Cannot expel black hand")


func _get_hovered_area_id() -> String:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return ""

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * ray_length
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ""

	var collider := result.get("collider") as Node
	if collider is Area3D:
		return String(collider.name)
	return ""


func _can_repair_anchor() -> bool:
	if GameManager.has_method("can_repair_anchor"):
		return bool(GameManager.call("can_repair_anchor"))
	return not GameManager.is_game_over


func _set_status(message: String) -> void:
	status_changed.emit(message)
	var parent := get_parent()
	if parent != null and parent.has_method("set_status_message"):
		parent.call("set_status_message", message)
