extends Node

const BROKEN_WINDOW_ID := "window_room_a_0"
const CANDLE_ID := "candle_room_a_0"

@onready var _click_interaction: Node = $ClickExpelHand
@onready var _relight_interaction: Node = $HoldRelightCandle
@onready var _progress_prompt: Node = $CanvasLayer/UI/ProgressPrompt
@onready var _trigger_button: BaseButton = $CanvasLayer/UI/Panel/VBox/TriggerButton
@onready var _black_hand_button: BaseButton = $CanvasLayer/UI/Panel/VBox/BlackHandButton
@onready var _relight_button: BaseButton = $CanvasLayer/UI/Panel/VBox/RelightButton
@onready var _status_label: Label = $CanvasLayer/UI/Panel/VBox/StatusLabel
@onready var _phase_label: Label = $CanvasLayer/UI/Panel/VBox/PhaseLabel
@onready var _candle_label: Label = $CanvasLayer/UI/Panel/VBox/CandleLabel
@onready var _event_label: Label = $CanvasLayer/UI/Panel/VBox/EventLabel
@onready var _click_label: Label = $CanvasLayer/UI/Panel/VBox/ClickLabel

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
	RoomStateManager.set_window_durability(BROKEN_WINDOW_ID, 0)
	RoomStateManager.set_candle_lit(CANDLE_ID, true)


func _connect_runtime() -> void:
	_progress_prompt.call("bind_hold_interaction", _relight_interaction)

	_trigger_button.pressed.connect(_on_trigger_pressed)
	_black_hand_button.pressed.connect(_on_black_hand_pressed)
	_relight_button.button_down.connect(_relight_interaction.call.bind("begin_hold"))
	_relight_button.button_up.connect(_relight_interaction.call.bind("cancel_hold"))
	_relight_button.mouse_exited.connect(_relight_interaction.call.bind("cancel_hold"))

	if not _click_interaction.is_connected("click_started", Callable(self, "_on_click_started")):
		_click_interaction.connect("click_started", Callable(self, "_on_click_started"))
	if not _click_interaction.is_connected("click_progress_changed", Callable(self, "_on_click_progress_changed")):
		_click_interaction.connect("click_progress_changed", Callable(self, "_on_click_progress_changed"))
	if not _click_interaction.is_connected("click_completed", Callable(self, "_on_click_completed")):
		_click_interaction.connect("click_completed", Callable(self, "_on_click_completed"))
	if not _click_interaction.is_connected("click_reset", Callable(self, "_on_click_reset")):
		_click_interaction.connect("click_reset", Callable(self, "_on_click_reset"))

	if not GameProcessManager.phase_changed.is_connected(_on_phase_changed):
		GameProcessManager.phase_changed.connect(_on_phase_changed)
	if not RoomStateManager.candle_lit_changed.is_connected(_on_candle_lit_changed):
		RoomStateManager.candle_lit_changed.connect(_on_candle_lit_changed)
	if not EventManager.candle_extinguish_event.state_changed.is_connected(_on_event_state_changed):
		EventManager.candle_extinguish_event.state_changed.connect(_on_event_state_changed)


func _on_trigger_pressed() -> void:
	_click_interaction.call("reset_clicks")
	RoomStateManager.set_candle_lit(CANDLE_ID, true)
	EventManager.trigger_candle_extinguish(CANDLE_ID)
	_status_label.text = "黑手出现：连续点击黑手 5 次驱赶"
	_refresh_status()


func _on_black_hand_pressed() -> void:
	_click_interaction.call("register_click")
	_refresh_status()


func _on_click_started(_action_type: String, _target_id: String, _required_clicks: int) -> void:
	_status_label.text = "正在驱赶黑手"


func _on_click_progress_changed(_action_type: String, _target_id: String, clicks: int, required_clicks: int, _ratio: float) -> void:
	_click_label.text = "驱赶点击：%d / %d" % [clicks, required_clicks]
	_black_hand_button.text = "连点黑手 %d/%d" % [clicks, required_clicks]


func _on_click_completed(_action_type: String, _target_id: String) -> void:
	_status_label.text = "黑手已被驱赶"
	_refresh_status()


func _on_click_reset(_action_type: String, _target_id: String) -> void:
	_status_label.text = "点击间隔过久，驱赶进度重置"
	_refresh_status()


func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	_phase_label.text = "阶段：%d" % new_phase


func _on_candle_lit_changed(candle_id: String, lit: bool) -> void:
	if candle_id != CANDLE_ID:
		return
	_candle_label.text = "蜡烛状态：%s" % ("已点亮" if lit else "已熄灭")


func _on_event_state_changed(_event_id: String, _old_state: int, _new_state: int) -> void:
	_refresh_status()


func _refresh_status() -> void:
	_phase_label.text = "阶段：%d" % GameProcessManager.phase
	_candle_label.text = "蜡烛状态：%s" % ("已点亮" if RoomStateManager.get_candle_state(CANDLE_ID).get("lit", false) else "已熄灭")
	_event_label.text = "黑手事件：%s" % _event_state_to_text(EventManager.get_candle_extinguish_state())
	_click_label.text = "驱赶点击：%d / %d" % [_click_interaction.get("clicks"), _click_interaction.get("required_clicks")]

	var event_active := EventManager.get_candle_extinguish_state() == EventBase.State.ACTIVE
	_black_hand_button.visible = event_active
	_black_hand_button.disabled = not event_active
	if not event_active:
		_black_hand_button.text = "等待黑手出现"


func _event_state_to_text(state: int) -> String:
	match state:
		EventBase.State.IDLE:
			return "待机"
		EventBase.State.TRIGGERED:
			return "已触发"
		EventBase.State.ACTIVE:
			return "正在攻击蜡烛"
		EventBase.State.RESOLVED:
			return "已驱赶"
		EventBase.State.FAILED:
			return "蜡烛已被熄灭"
		_:
			return "未知"


func _run_headless_checks() -> void:
	print("========== M3 Black Hand Interaction Mock 开始 ==========")

	_check("phase two entered", GameProcessManager.phase, GameProcessManager.Phase.TWO)
	_check("candle starts lit", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], true)

	EventManager.trigger_candle_extinguish(CANDLE_ID)
	_check("candle event active", EventManager.get_candle_extinguish_state(), EventBase.State.ACTIVE)

	for _index in 4:
		_click_interaction.call("register_click")
	_check("event still active after four clicks", EventManager.get_candle_extinguish_state(), EventBase.State.ACTIVE)

	_click_interaction.call("register_click")
	_check("event resolved after five clicks", EventManager.get_candle_extinguish_state(), EventBase.State.RESOLVED)
	_check("candle remains lit after expel", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], true)

	EventManager.reset()
	_click_interaction.call("reset_clicks")
	RoomStateManager.set_candle_lit(CANDLE_ID, true)
	EventManager.trigger_candle_extinguish(CANDLE_ID)
	EventManager.simulate_step(15.1)
	_check("event failed after timeout", EventManager.get_candle_extinguish_state(), EventBase.State.FAILED)
	_check("candle unlit after timeout", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], false)

	_relight_interaction.call("begin_hold")
	_relight_interaction.call("advance", 1.1)
	_check("candle lit after relight hold", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], true)

	print("========== M3 Black Hand Interaction Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])
