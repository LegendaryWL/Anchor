extends Node

const CUE_WINDOW_ATTACK := "window_attack"
const CUE_WHISPER := "whisper"
const CUE_CANDLE_LIGHT := "candle_light"
const CUE_CANDLE_SNUFF := "candle_snuff"
const CUE_FOOTSTEP := "footstep"
const CUE_MOUSE_IN := "mouse_in"
const CUE_ANCHOR_MACHINE := "anchor_machine"
const CUE_LOW_SAN := "low_san"
const CUE_OPENING := "opening"

@onready var _audio_feedback: Node = $AudioFeedback
@onready var _hold_anchor: Node = $HoldAnchor
@onready var _action_panel: Control = $CanvasLayer/UI/ActionPanel
@onready var _status_label: Label = $CanvasLayer/UI/ActionPanel/VBox/StatusLabel
@onready var _opening_button: BaseButton = $CanvasLayer/UI/ActionPanel/VBox/OpeningButton
@onready var _window_attack_button: BaseButton = $CanvasLayer/UI/ActionPanel/VBox/WindowAttackButton
@onready var _candle_attack_button: BaseButton = $CanvasLayer/UI/ActionPanel/VBox/CandleAttackButton
@onready var _low_san_button: BaseButton = $CanvasLayer/UI/ActionPanel/VBox/LowSanButton
@onready var _anchor_button: BaseButton = $CanvasLayer/UI/ActionPanel/VBox/AnchorButton

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	_reset_demo_state()
	_connect_runtime()

	if DisplayServer.get_name() == "headless":
		_run_headless_checks()


func _reset_demo_state() -> void:
	GameProcessManager.reset()
	RoomStateManager.reset_to_default()
	EventManager.reset()


func _connect_runtime() -> void:
	_audio_feedback.call("bind_hold_interaction", _hold_anchor)
	_audio_feedback.call("bind_ui_hover_root", _action_panel)

	_opening_button.pressed.connect(_on_opening_pressed)
	_window_attack_button.pressed.connect(_on_window_attack_pressed)
	_candle_attack_button.pressed.connect(_on_candle_attack_pressed)
	_low_san_button.pressed.connect(_on_low_san_pressed)
	_anchor_button.button_down.connect(_hold_anchor.call.bind("begin_hold"))
	_anchor_button.button_up.connect(_hold_anchor.call.bind("cancel_hold"))


func _on_opening_pressed() -> void:
	_audio_feedback.call("play_opening")
	_status_label.text = "开场音乐播放"


func _on_window_attack_pressed() -> void:
	EventManager.trigger_window_attack("window_room_a_0", 10.0)
	_status_label.text = "攻窗音效播放"


func _on_candle_attack_pressed() -> void:
	RoomStateManager.set_candle_lit("candle_room_a_0", true)
	EventManager.trigger_candle_extinguish("candle_room_a_0")
	_status_label.text = "低语音效播放"


func _on_low_san_pressed() -> void:
	GameProcessManager.san_current = 19.0
	GameProcessManager.san_changed.emit(GameProcessManager.san_current, GameProcessManager.san_max)
	_status_label.text = "低 SAN 音效播放"


func _run_headless_checks() -> void:
	print("========== M6 Audio Feedback Mock 开始 ==========")

	for cue in [
		CUE_WINDOW_ATTACK,
		CUE_WHISPER,
		CUE_CANDLE_LIGHT,
		CUE_CANDLE_SNUFF,
		CUE_FOOTSTEP,
		CUE_MOUSE_IN,
		CUE_ANCHOR_MACHINE,
		CUE_LOW_SAN,
		CUE_OPENING,
	]:
		_check("stream loaded: %s" % cue, _audio_feedback.call("has_cue_stream", cue), true)

	_audio_feedback.call("play_opening")
	_check("opening plays", _audio_feedback.call("is_cue_playing", CUE_OPENING), true)
	_audio_feedback.call("stop_opening")
	_check("opening stops", _audio_feedback.call("is_cue_playing", CUE_OPENING), false)

	EventManager.trigger_window_attack("window_room_a_0", 10.0)
	_check("window attack cue starts", _audio_feedback.call("is_cue_playing", CUE_WINDOW_ATTACK), true)
	EventManager.on_behavior_message(BehaviorMessage.create("fix_window", "window_room_a_0", true))
	_check("window attack cue stops", _audio_feedback.call("is_cue_playing", CUE_WINDOW_ATTACK), false)

	EventManager.trigger_candle_extinguish("candle_room_a_0")
	_check("whisper cue starts", _audio_feedback.call("is_cue_playing", CUE_WHISPER), true)
	EventManager.on_behavior_message(BehaviorMessage.create("expel_black_hand", "candle_room_a_0", true))
	_check("whisper cue stops", _audio_feedback.call("is_cue_playing", CUE_WHISPER), false)

	RoomStateManager.set_candle_lit("candle_room_a_0", false)
	_check("candle snuff cue plays", _audio_feedback.call("is_cue_playing", CUE_CANDLE_SNUFF), true)
	RoomStateManager.set_candle_lit("candle_room_a_0", true)
	_check("candle light cue plays", _audio_feedback.call("is_cue_playing", CUE_CANDLE_LIGHT), true)

	RoomStateManager.set_current_room("room_b")
	_check("footstep cue plays on room change", _audio_feedback.call("is_cue_playing", CUE_FOOTSTEP), true)

	_action_panel.get_node("VBox/OpeningButton").mouse_entered.emit()
	_check("mouse hover cue plays", _audio_feedback.call("is_cue_playing", CUE_MOUSE_IN), true)

	_hold_anchor.call("begin_hold")
	_check("anchor machine cue starts on hold", _audio_feedback.call("is_cue_playing", CUE_ANCHOR_MACHINE), true)
	_hold_anchor.call("cancel_hold")
	_check("anchor machine cue stops on cancel", _audio_feedback.call("is_cue_playing", CUE_ANCHOR_MACHINE), false)

	GameProcessManager.san_current = 19.0
	GameProcessManager.san_changed.emit(GameProcessManager.san_current, GameProcessManager.san_max)
	_check("low san cue starts", _audio_feedback.call("is_cue_playing", CUE_LOW_SAN), true)
	GameProcessManager.san_current = 50.0
	GameProcessManager.san_changed.emit(GameProcessManager.san_current, GameProcessManager.san_max)
	_check("low san cue stops", _audio_feedback.call("is_cue_playing", CUE_LOW_SAN), false)

	_audio_feedback.call("stop_all_cues")
	_audio_feedback.call("release_all_cues")
	_audio_feedback.queue_free()
	await get_tree().process_frame
	print("========== M6 Audio Feedback Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])
