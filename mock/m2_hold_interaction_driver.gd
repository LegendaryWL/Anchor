extends Node

const WINDOW_ID := "window_room_a_0"
const CANDLE_ID := "candle_room_a_0"

@onready var _anchor_interaction: Node = $HoldAnchor
@onready var _window_interaction: Node = $HoldWindow
@onready var _candle_interaction: Node = $HoldCandle
@onready var _progress_prompt: Node = $CanvasLayer/UI/ProgressPrompt
@onready var _anchor_button: BaseButton = $CanvasLayer/UI/Panel/VBox/AnchorButton
@onready var _window_button: BaseButton = $CanvasLayer/UI/Panel/VBox/WindowButton
@onready var _candle_button: BaseButton = $CanvasLayer/UI/Panel/VBox/CandleButton
@onready var _status_label: Label = $CanvasLayer/UI/Panel/VBox/StatusLabel
@onready var _anchor_label: Label = $CanvasLayer/UI/Panel/VBox/AnchorLabel
@onready var _window_label: Label = $CanvasLayer/UI/Panel/VBox/WindowLabel
@onready var _candle_label: Label = $CanvasLayer/UI/Panel/VBox/CandleLabel

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	_reset_demo_state()
	_connect_runtime()
	_refresh_status()

	if DisplayServer.get_name() == "headless":
		_run_headless_checks()


func _reset_demo_state() -> void:
	GameProcessManager.reset()
	RoomStateManager.reset_to_default()
	EventManager.reset()
	RoomStateManager.set_window_durability(WINDOW_ID, 40)
	RoomStateManager.set_candle_lit(CANDLE_ID, false)


func _connect_runtime() -> void:
	_progress_prompt.call("bind_hold_interaction", _anchor_interaction)
	_progress_prompt.call("bind_hold_interaction", _window_interaction)
	_progress_prompt.call("bind_hold_interaction", _candle_interaction)

	_bind_button_to_hold(_anchor_button, _anchor_interaction)
	_bind_button_to_hold(_window_button, _window_interaction)
	_bind_button_to_hold(_candle_button, _candle_interaction)

	if not GameProcessManager.repair_progress_changed.is_connected(_on_repair_progress_changed):
		GameProcessManager.repair_progress_changed.connect(_on_repair_progress_changed)
	if not RoomStateManager.window_durability_changed.is_connected(_on_window_durability_changed):
		RoomStateManager.window_durability_changed.connect(_on_window_durability_changed)
	if not RoomStateManager.candle_lit_changed.is_connected(_on_candle_lit_changed):
		RoomStateManager.candle_lit_changed.connect(_on_candle_lit_changed)


func _bind_button_to_hold(button: BaseButton, interaction: Node) -> void:
	button.button_down.connect(interaction.call.bind("begin_hold"))
	button.button_up.connect(interaction.call.bind("cancel_hold"))
	button.mouse_exited.connect(interaction.call.bind("cancel_hold"))


func _refresh_status() -> void:
	_on_repair_progress_changed(GameProcessManager.repair_time_accum, GameProcessManager.repair_time_target)
	var window := RoomStateManager.get_window_state(WINDOW_ID)
	_on_window_durability_changed(WINDOW_ID, int(window.get("durability", 0)))
	var candle := RoomStateManager.get_candle_state(CANDLE_ID)
	_on_candle_lit_changed(CANDLE_ID, bool(candle.get("lit", false)))


func _on_repair_progress_changed(accum: float, target: float) -> void:
	_anchor_label.text = "锚修理进度：%.1f / %.1f 秒" % [accum, target]


func _on_window_durability_changed(window_id: String, durability: int) -> void:
	if window_id != WINDOW_ID:
		return
	_window_label.text = "窗户耐久：%d / 100" % durability


func _on_candle_lit_changed(candle_id: String, lit: bool) -> void:
	if candle_id != CANDLE_ID:
		return
	_candle_label.text = "蜡烛状态：%s" % ("已点亮" if lit else "已熄灭")


func _run_headless_checks() -> void:
	print("========== M2 Hold Interaction Mock 开始 ==========")

	_anchor_interaction.call("begin_hold")
	_anchor_interaction.call("advance", 1.6)
	_check("anchor repair advanced", GameProcessManager.repair_time_accum > 1.4, true)

	var window_before := float(RoomStateManager.get_window_state(WINDOW_ID)["durability"])
	_window_interaction.call("begin_hold")
	_window_interaction.call("advance", 2.1)
	var window_after := float(RoomStateManager.get_window_state(WINDOW_ID)["durability"])
	_check("window durability increased", window_after > window_before, true)

	_check("candle starts unlit", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], false)
	_candle_interaction.call("begin_hold")
	_candle_interaction.call("advance", 1.1)
	_check("candle lit after hold", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], true)

	print("========== M2 Hold Interaction Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])
