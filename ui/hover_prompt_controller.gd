class_name HoverPromptController
extends Node

@export var object_label_path: NodePath
@export var operation_label_path: NodePath
@export var progress_panel_path: NodePath
@export var progress_label_path: NodePath
@export var progress_bar_path: NodePath
@export var hover_delay_seconds := 10.0
@export var hide_operation_after_click_seconds := 3.0
@export var ray_length := 100.0
@export var only_show_when_interactable := false
@export var fade_seconds := 0.18
@export var operation_blink_count := 2
@export var operation_blink_low_alpha := 0.45
@export var operation_blink_step_seconds := 0.08

var _object_label: Label
var _operation_label: Label
var _progress_panel: CanvasItem
var _progress_label: Label
var _progress_bar: ProgressBar
var _object_tween: Tween
var _operation_tween: Tween
var _hovered_id := ""
var _hover_time := 0.0
var _operation_visible := false
var _operation_hide_timer := 0.0


func _ready() -> void:
	_object_label = get_node_or_null(object_label_path) as Label
	_operation_label = get_node_or_null(operation_label_path) as Label
	_progress_panel = get_node_or_null(progress_panel_path) as CanvasItem
	_progress_label = get_node_or_null(progress_label_path) as Label
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	_hide_label_immediate(_object_label)
	_hide_label_immediate(_operation_label)
	_hide_progress_panel()
	if _progress_bar != null:
		_progress_bar.min_value = 0.0
		_progress_bar.max_value = 100.0


func _process(delta: float) -> void:
	var id := _get_hovered_interactable_id()
	if id != _hovered_id:
		_set_hovered_id(id)

	if _hovered_id != "":
		_hover_time += delta
		if _hover_time >= hover_delay_seconds and not _operation_visible:
			_show_operation_label(_hovered_id)

	_update_progress_panel(_hovered_id)

	if _operation_hide_timer > 0.0:
		_operation_hide_timer -= delta
		if _operation_hide_timer <= 0.0:
			_hide_operation_label()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _operation_visible:
				_operation_hide_timer = hide_operation_after_click_seconds


func _set_hovered_id(id: String) -> void:
	_hovered_id = id
	_hover_time = 0.0
	_operation_hide_timer = 0.0
	_hide_operation_label()

	if _hovered_id == "":
		_hide_object_label()
		_hide_progress_panel()
	else:
		_show_object_label(_hovered_id)
		_update_progress_panel(_hovered_id)


func _get_hovered_interactable_id() -> String:
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
	if collider == null:
		return ""

	var area := collider as Area3D
	if area == null:
		return ""

	var id := String(area.name)
	if not _is_known_target(id):
		return ""

	if only_show_when_interactable and not _is_interactable_now(id):
		return ""

	return id


func _is_interactable_now(id: String) -> bool:
	if GameManager.is_game_over:
		return false

	if id == "anchor_device":
		if GameManager.has_method("can_repair_anchor"):
			return bool(GameManager.call("can_repair_anchor"))
		return true

	if id.begins_with("window_"):
		return GameManager.can_repair_window(id)

	if id.begins_with("candle_"):
		return GameManager.can_light_candle(id)

	if id == "black_hand":
		var target := GameManager.get_candle_under_attack_in_view()
		return target != "" and GameManager.can_expel_black_hand(target)

	return false


func _is_known_target(id: String) -> bool:
	return (
		id == "anchor_device"
		or id == "black_hand"
		or id.begins_with("window_")
		or id.begins_with("candle_")
	)


func _show_object_label(id: String) -> void:
	if _object_label == null:
		return
	_object_label.text = _get_object_text(id)
	_fade_label_in(_object_label, true)


func _hide_object_label() -> void:
	if _object_label != null:
		_fade_label_out(_object_label, true)


func _show_operation_label(id: String) -> void:
	if _operation_label == null:
		return
	_operation_label.text = _get_operation_text(id)
	_operation_visible = true
	_show_operation_with_blink()


func _hide_operation_label() -> void:
	if _operation_label != null:
		_fade_label_out(_operation_label, false)
	_operation_visible = false


func _hide_label_immediate(label: Label) -> void:
	if label == null:
		return
	label.visible = false
	label.modulate.a = 0.0


func _update_progress_panel(id: String) -> void:
	if id.begins_with("window_"):
		_show_window_progress(id)
	elif id == "anchor_device":
		_show_anchor_progress()
	else:
		_hide_progress_panel()


func _show_window_progress(window_id: String) -> void:
	var value := clampf(GameManager.get_window_durability_value(window_id), 0.0, 100.0)
	if _progress_label != null:
		_progress_label.text = "窗户耐久" % int(round(value))
	if _progress_bar != null:
		_progress_bar.value = value
	_show_progress_panel()


func _show_anchor_progress() -> void:
	var snapshot := GameManager.get_snapshot()
	var progress := clampf(float(snapshot.get("anchor_progress", 0.0)) * 100.0, 0.0, 100.0)
	if _progress_label != null:
		_progress_label.text = "锚回收进度" % int(round(progress))
	if _progress_bar != null:
		_progress_bar.value = progress
	_show_progress_panel()


func _show_progress_panel() -> void:
	if _progress_panel != null:
		_progress_panel.visible = true


func _hide_progress_panel() -> void:
	if _progress_panel != null:
		_progress_panel.visible = false


func _fade_label_in(label: Label, is_object_label: bool) -> void:
	var tween := _replace_tween(is_object_label)
	label.visible = true
	label.modulate.a = 0.0
	tween.tween_property(label, "modulate:a", 1.0, fade_seconds)


func _fade_label_out(label: Label, is_object_label: bool) -> void:
	var tween := _replace_tween(is_object_label)
	tween.tween_property(label, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(func() -> void:
		label.visible = false
	)


func _show_operation_with_blink() -> void:
	var tween := _replace_tween(false)
	_operation_label.visible = true
	_operation_label.modulate.a = 0.0
	tween.tween_property(_operation_label, "modulate:a", 1.0, fade_seconds)
	for _index in operation_blink_count:
		tween.tween_property(_operation_label, "modulate:a", operation_blink_low_alpha, operation_blink_step_seconds)
		tween.tween_property(_operation_label, "modulate:a", 1.0, operation_blink_step_seconds)


func _replace_tween(is_object_label: bool) -> Tween:
	var existing := _object_tween if is_object_label else _operation_tween
	if existing != null:
		existing.kill()

	var tween := create_tween()
	if is_object_label:
		_object_tween = tween
	else:
		_operation_tween = tween
	return tween


func _get_object_text(id: String) -> String:
	if id == "anchor_device":
		return "起锚器"
	if id == "black_hand":
		return "快赶走它！！！"
	if id.begins_with("window_"):
		return "窗户"
	if id.begins_with("candle_"):
		return "蜡烛"
	return id


func _get_operation_text(id: String) -> String:
	if id == "anchor_device":
		return "长按鼠标左键修理起锚器"
	if id == "black_hand":
		return "连续点击鼠标左键！！！"
	if id.begins_with("window_"):
		return "长按鼠标左键修补窗户"
	if id.begins_with("candle_"):
		return "长按鼠标左键点亮蜡烛"
	return "点击鼠标左键互动"
