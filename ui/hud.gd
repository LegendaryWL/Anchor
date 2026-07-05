class_name HUD
extends Control

@export var san_label_path: NodePath
@export var san_bar_path: NodePath
@export var repair_label_path: NodePath
@export var repair_bar_path: NodePath
@export var phase_label_path: NodePath
@export var current_room_label_path: NodePath
@export var window_status_label_path: NodePath
@export var candle_status_label_path: NodePath
@export var game_over_overlay_path: NodePath
@export var game_over_title_label_path: NodePath
@export var game_over_body_label_path: NodePath
@export var disable_input_root_path: NodePath
@export var low_san_overlay_path: NodePath
@export var low_san_threshold := 20.0
@export_range(0.0, 1.0, 0.01) var low_san_max_alpha := 0.45

var _san_label: Label
var _san_bar: ProgressBar
var _repair_label: Label
var _repair_bar: ProgressBar
var _phase_label: Label
var _current_room_label: Label
var _window_status_label: Label
var _candle_status_label: Label
var _game_over_overlay: Control
var _game_over_title_label: Label
var _game_over_body_label: Label
var _disable_input_root: Node
var _low_san_overlay: Control
var _last_game_over_state := false


func _ready() -> void:
	_cache_nodes()
	_connect_signals()
	refresh_all()


func refresh_all() -> void:
	_on_san_changed(GameProcessManager.san_current, GameProcessManager.san_max)
	_on_repair_progress_changed(GameProcessManager.repair_time_accum, GameProcessManager.repair_time_target)
	_on_phase_changed(GameProcessManager.phase, GameProcessManager.phase)
	_on_room_changed(RoomStateManager.current_room_id)
	_refresh_game_over(GameProcessManager.game_over_reason)


func _cache_nodes() -> void:
	_san_label = get_node_or_null(san_label_path) as Label
	_san_bar = get_node_or_null(san_bar_path) as ProgressBar
	_repair_label = get_node_or_null(repair_label_path) as Label
	_repair_bar = get_node_or_null(repair_bar_path) as ProgressBar
	_phase_label = get_node_or_null(phase_label_path) as Label
	_current_room_label = get_node_or_null(current_room_label_path) as Label
	_window_status_label = get_node_or_null(window_status_label_path) as Label
	_candle_status_label = get_node_or_null(candle_status_label_path) as Label
	_game_over_overlay = get_node_or_null(game_over_overlay_path) as Control
	_game_over_title_label = get_node_or_null(game_over_title_label_path) as Label
	_game_over_body_label = get_node_or_null(game_over_body_label_path) as Label
	_disable_input_root = get_node_or_null(disable_input_root_path)
	_low_san_overlay = get_node_or_null(low_san_overlay_path) as Control


func _connect_signals() -> void:
	if not GameProcessManager.san_changed.is_connected(_on_san_changed):
		GameProcessManager.san_changed.connect(_on_san_changed)
	if not GameProcessManager.repair_progress_changed.is_connected(_on_repair_progress_changed):
		GameProcessManager.repair_progress_changed.connect(_on_repair_progress_changed)
	if not GameProcessManager.phase_changed.is_connected(_on_phase_changed):
		GameProcessManager.phase_changed.connect(_on_phase_changed)
	if not GameProcessManager.game_over.is_connected(_on_game_over):
		GameProcessManager.game_over.connect(_on_game_over)

	if not RoomStateManager.room_changed.is_connected(_on_room_changed):
		RoomStateManager.room_changed.connect(_on_room_changed)
	if not RoomStateManager.window_durability_changed.is_connected(_on_window_durability_changed):
		RoomStateManager.window_durability_changed.connect(_on_window_durability_changed)
	if not RoomStateManager.candle_lit_changed.is_connected(_on_candle_lit_changed):
		RoomStateManager.candle_lit_changed.connect(_on_candle_lit_changed)


func _on_san_changed(current: float, max_san: float) -> void:
	if _san_label != null:
		_san_label.text = "SAN：%.0f / %.0f" % [current, max_san]
	_set_bar_value(_san_bar, current, max_san)
	_refresh_low_san_overlay(current)


func _on_repair_progress_changed(accum: float, target: float) -> void:
	if _repair_label != null:
		_repair_label.text = "锚修理：%.1f / %.1f 秒" % [accum, target]
	_set_bar_value(_repair_bar, accum, target)


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	if _phase_label != null:
		_phase_label.text = "阶段：%d" % new_phase


func _on_game_over(reason: int) -> void:
	_refresh_game_over(reason)


func _on_room_changed(room_id: String) -> void:
	if _current_room_label != null:
		_current_room_label.text = "当前位置：%s" % _room_name(room_id)
	_refresh_window_status(room_id)
	_refresh_candle_status(room_id)


func _on_window_durability_changed(window_id: String, _durability: int) -> void:
	if _get_room_id_from_target(window_id, "window_") == RoomStateManager.current_room_id:
		_refresh_window_status(RoomStateManager.current_room_id)


func _on_candle_lit_changed(candle_id: String, _lit: bool) -> void:
	if _get_room_id_from_target(candle_id, "candle_") == RoomStateManager.current_room_id:
		_refresh_candle_status(RoomStateManager.current_room_id)


func _refresh_window_status(room_id: String) -> void:
	if _window_status_label == null:
		return

	var lines: Array[String] = []
	var ids := _get_sorted_ids_for_room(RoomStateManager.windows, room_id)
	for window_id in ids:
		var window := RoomStateManager.get_window_state(window_id)
		var durability := int(window.get("durability", 0))
		var max_durability := int(window.get("max_durability", 100))
		var suffix := "（破损）" if bool(window.get("is_broken", false)) else ""
		lines.append("%s：%d / %d%s" % [window_id, durability, max_durability, suffix])

	_window_status_label.text = "窗户：无" if lines.is_empty() else "窗户：\n%s" % "\n".join(lines)


func _refresh_candle_status(room_id: String) -> void:
	if _candle_status_label == null:
		return

	var lines: Array[String] = []
	var ids := _get_sorted_ids_for_room(RoomStateManager.candles, room_id)
	for candle_id in ids:
		var candle := RoomStateManager.get_candle_state(candle_id)
		lines.append("%s：%s" % [candle_id, "亮" if bool(candle.get("lit", false)) else "灭"])

	_candle_status_label.text = "蜡烛：无" if lines.is_empty() else "蜡烛：\n%s" % "\n".join(lines)


func _refresh_game_over(reason: int) -> void:
	var is_game_over := GameProcessManager.is_game_over
	if _game_over_overlay != null:
		_game_over_overlay.visible = is_game_over

	if is_game_over:
		var title := "游戏结束"
		var body := ""
		match reason:
			GameProcessManager.GameOverReason.VICTORY:
				title = "平安启航"
				body = "锚一归位，我就恢复了平静。"
			GameProcessManager.GameOverReason.DEFEAT:
				title = "坠海"
				body = "海水涌入我的咽喉。"

		if _game_over_title_label != null:
			_game_over_title_label.text = title
		if _game_over_body_label != null:
			_game_over_body_label.text = body

	if is_game_over != _last_game_over_state:
		_last_game_over_state = is_game_over
		if _disable_input_root != null:
			_set_buttons_disabled(_disable_input_root, is_game_over)


func _refresh_low_san_overlay(current: float) -> void:
	if _low_san_overlay == null:
		return

	var should_show := current > 0.0 and current < low_san_threshold and not GameProcessManager.is_game_over
	_low_san_overlay.visible = should_show
	if not should_show:
		return

	var danger_ratio := clampf(1.0 - (current / maxf(low_san_threshold, 0.01)), 0.0, 1.0)
	var alpha := lerpf(0.12, low_san_max_alpha, danger_ratio)
	if _low_san_overlay is ColorRect:
		(_low_san_overlay as ColorRect).color = Color(0.8, 0.0, 0.0, alpha)
	else:
		_low_san_overlay.modulate = Color(1.0, 0.0, 0.0, alpha)


func _set_bar_value(bar: ProgressBar, value: float, max_value: float) -> void:
	if bar == null:
		return

	bar.min_value = 0.0
	bar.max_value = maxf(max_value, 0.01)
	bar.value = clampf(value, 0.0, bar.max_value)


func _get_sorted_ids_for_room(source: Dictionary, room_id: String) -> Array[String]:
	var ids: Array[String] = []
	for id in source.keys():
		var state: Dictionary = source[id]
		if state.get("room_id", "") == room_id:
			ids.append(str(id))
	ids.sort()
	return ids


func _get_room_id_from_target(target_id: String, prefix: String) -> String:
	if not target_id.begins_with(prefix):
		return ""
	var text := target_id.trim_prefix(prefix)
	var parts := text.split("_")
	if parts.size() < 3:
		return ""
	parts.remove_at(parts.size() - 1)
	return "_".join(parts)


func _room_name(room_id: String) -> String:
	match room_id:
		"room_a":
			return "房间 A"
		"room_b":
			return "房间 B"
		"room_bow", "bow_room":
			return "船头"
		_:
			return room_id


func _set_buttons_disabled(root: Node, disabled: bool) -> void:
	if root is BaseButton:
		(root as BaseButton).disabled = disabled

	for child in root.get_children():
		_set_buttons_disabled(child, disabled)
