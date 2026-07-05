extends Node

@onready var _hud: Control = $CanvasLayer/UI/HUD
@onready var _repair_button: BaseButton = $CanvasLayer/UI/HUD/ActionPanel/VBox/RepairButton
@onready var _damage_window_button: BaseButton = $CanvasLayer/UI/HUD/ActionPanel/VBox/DamageWindowButton
@onready var _toggle_candle_button: BaseButton = $CanvasLayer/UI/HUD/ActionPanel/VBox/ToggleCandleButton
@onready var _phase_button: BaseButton = $CanvasLayer/UI/HUD/ActionPanel/VBox/PhaseButton
@onready var _victory_button: BaseButton = $CanvasLayer/UI/HUD/ActionPanel/VBox/VictoryButton
@onready var _room_b_button: BaseButton = $CanvasLayer/UI/HUD/Minimap/RoomBButton
@onready var _san_bar: ProgressBar = $CanvasLayer/UI/HUD/TopLeftPanel/VBox/SanBar
@onready var _repair_bar: ProgressBar = $CanvasLayer/UI/HUD/RepairPanel/VBox/RepairBar
@onready var _phase_label: Label = $CanvasLayer/UI/HUD/TopLeftPanel/VBox/PhaseLabel
@onready var _room_label: Label = $CanvasLayer/UI/HUD/TopLeftPanel/VBox/RoomLabel
@onready var _window_label: Label = $CanvasLayer/UI/HUD/StatusPanel/VBox/WindowStatusLabel
@onready var _candle_label: Label = $CanvasLayer/UI/HUD/StatusPanel/VBox/CandleStatusLabel
@onready var _game_over_overlay: Control = $CanvasLayer/UI/HUD/GameOverOverlay
@onready var _game_over_title: Label = $CanvasLayer/UI/HUD/GameOverOverlay/VBox/GameOverTitleLabel
@onready var _low_san_overlay: ColorRect = $CanvasLayer/UI/HUD/LowSanOverlay

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	_reset_demo_state()
	_connect_runtime()
	_hud.call("refresh_all")

	if DisplayServer.get_name() == "headless":
		_run_headless_checks()


func _reset_demo_state() -> void:
	GameProcessManager.reset()
	GameProcessManager.repair_time_target = 60.0
	RoomStateManager.reset_to_default()
	EventManager.reset()


func _connect_runtime() -> void:
	_repair_button.pressed.connect(_on_repair_pressed)
	_damage_window_button.pressed.connect(_on_damage_window_pressed)
	_toggle_candle_button.pressed.connect(_on_toggle_candle_pressed)
	_phase_button.pressed.connect(_on_phase_pressed)
	_victory_button.pressed.connect(_on_victory_pressed)


func _on_repair_pressed() -> void:
	GameProcessManager.add_repair_time(10.0)


func _on_damage_window_pressed() -> void:
	var window_id := _first_window_id_for_room(RoomStateManager.current_room_id)
	if window_id.is_empty():
		return
	var current := int(RoomStateManager.get_window_state(window_id).get("durability", 0))
	RoomStateManager.set_window_durability(window_id, current - 25)


func _on_toggle_candle_pressed() -> void:
	var candle_id := _first_candle_id_for_room(RoomStateManager.current_room_id)
	if candle_id.is_empty():
		return
	var lit := bool(RoomStateManager.get_candle_state(candle_id).get("lit", false))
	RoomStateManager.set_candle_lit(candle_id, not lit)


func _on_phase_pressed() -> void:
	RoomStateManager.set_window_durability("window_room_a_0", 0)


func _on_victory_pressed() -> void:
	GameProcessManager.repair_time_target = GameProcessManager.repair_time_accum + 1.0
	GameProcessManager.add_repair_time(1.1)


func _run_headless_checks() -> void:
	print("========== M4 HUD Mock 开始 ==========")

	_check("initial san bar", _san_bar.value, 100.0)
	_check("initial repair bar", _repair_bar.value, 0.0)
	_check("initial room label", _room_label.text, "当前位置：驾驶室")

	GameProcessManager.add_repair_time(12.0)
	_check("repair bar follows signal", _repair_bar.value, 12.0)

	_room_b_button.pressed.emit()
	_check("room label updates", _room_label.text, "当前位置：休息室")

	RoomStateManager.set_window_durability("window_room_b_0", 64)
	_check_contains("window status follows current room", _window_label.text, "window_room_b_0：64 / 100")

	RoomStateManager.set_candle_lit("candle_room_b_1", false)
	_check_contains("candle status follows current room", _candle_label.text, "candle_room_b_1：灭")

	GameProcessManager.san_current = 19.0
	GameProcessManager.san_changed.emit(GameProcessManager.san_current, GameProcessManager.san_max)
	_check("low san overlay visible", _low_san_overlay.visible, true)
	_check("low san overlay has alpha", _low_san_overlay.color.a > 0.0, true)
	GameProcessManager.san_current = 50.0
	GameProcessManager.san_changed.emit(GameProcessManager.san_current, GameProcessManager.san_max)
	_check("low san overlay hidden after recovery", _low_san_overlay.visible, false)

	RoomStateManager.set_window_durability("window_room_a_0", 0)
	_check("phase label updates", _phase_label.text, "阶段：2")
	_check("san max follows phase two", _san_bar.max_value, 80.0)

	GameProcessManager.repair_time_target = GameProcessManager.repair_time_accum + 1.0
	GameProcessManager.add_repair_time(1.1)
	_check("game over overlay visible", _game_over_overlay.visible, true)
	_check("victory title visible", _game_over_title.text, "平安启航")
	_check("input disabled after game over", _repair_button.disabled, true)

	print("========== M4 HUD Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _first_window_id_for_room(room_id: String) -> String:
	var ids: Array[String] = []
	for id in RoomStateManager.windows.keys():
		var window: Dictionary = RoomStateManager.windows[id]
		if window.get("room_id", "") == room_id:
			ids.append(str(id))
	ids.sort()
	return "" if ids.is_empty() else ids[0]


func _first_candle_id_for_room(room_id: String) -> String:
	var ids: Array[String] = []
	for id in RoomStateManager.candles.keys():
		var candle: Dictionary = RoomStateManager.candles[id]
		if candle.get("room_id", "") == room_id:
			ids.append(str(id))
	ids.sort()
	return "" if ids.is_empty() else ids[0]


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])


func _check_contains(label: String, text: String, expected_part: String) -> void:
	if text.find(expected_part) >= 0:
		_passed += 1
		print("[PASS] %s -> %s" % [label, expected_part])
		return

	_failed += 1
	push_error("[FAIL] %s expected text to contain=%s actual=%s" % [label, expected_part, text])
