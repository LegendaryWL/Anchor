extends Node

const WINDOW_ID := "window_room_a_0"
const CANDLE_ID := "candle_room_a_0"

@onready var _anchor_target: Node = $AnchorTarget
@onready var _window_target: Node = $WindowTarget
@onready var _candle_target: Node = $CandleTarget
@onready var _black_hand_target: Node = $BlackHandTarget

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	_reset_demo_state()

	if DisplayServer.get_name() == "headless":
		_run_headless_checks()


func _reset_demo_state() -> void:
	GameProcessManager.reset()
	RoomStateManager.reset_to_default()
	EventManager.reset()
	RoomStateManager.set_window_durability(WINDOW_ID, 40)
	RoomStateManager.set_candle_lit(CANDLE_ID, false)


func _run_headless_checks() -> void:
	print("========== Interaction Target Mock 开始 ==========")

	_anchor_target.call("primary_pressed")
	var anchor_interaction: Node = _anchor_target.call("get_interaction_node")
	anchor_interaction.call("advance", 1.2)
	_anchor_target.call("primary_released")
	_check("anchor target repairs", GameProcessManager.repair_time_accum > 1.0, true)

	var window_before := float(RoomStateManager.get_window_state(WINDOW_ID)["durability"])
	_window_target.call("primary_pressed")
	var window_interaction: Node = _window_target.call("get_interaction_node")
	window_interaction.call("advance", 2.1)
	var window_after := float(RoomStateManager.get_window_state(WINDOW_ID)["durability"])
	_check("window target fixes", window_after > window_before, true)

	_check("candle starts unlit", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], false)
	_candle_target.call("primary_pressed")
	var candle_interaction: Node = _candle_target.call("get_interaction_node")
	candle_interaction.call("advance", 1.1)
	_check("candle target lights", RoomStateManager.get_candle_state(CANDLE_ID)["lit"], true)

	EventManager.trigger_candle_extinguish(CANDLE_ID)
	_check("candle event active", EventManager.get_candle_extinguish_state(), EventBase.State.ACTIVE)
	for _index in 5:
		_black_hand_target.call("primary_clicked")
	_check("black hand target expels", EventManager.get_candle_extinguish_state(), EventBase.State.RESOLVED)

	print("========== Interaction Target Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])
