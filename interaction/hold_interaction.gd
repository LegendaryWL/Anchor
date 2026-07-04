class_name HoldInteraction
extends Node

signal hold_started(action_type: String, target_id: String, prompt_text: String, required_time: float)
signal progress_changed(action_type: String, target_id: String, ratio: float, elapsed: float, required_time: float)
signal hold_canceled(action_type: String, target_id: String, elapsed: float)
signal hold_completed(action_type: String, target_id: String)

@export_enum("repair_anchor", "fix_window", "light_candle") var action_type := "repair_anchor"
@export var target_id := ""
@export var prompt_text := ""
@export var required_hold_time := 1.0
@export var window_repair_rate := 4.0
@export var send_behavior_message_on_complete := true

var is_holding := false
var elapsed := 0.0


func _ready() -> void:
	set_process(false)


func begin_hold() -> void:
	if is_holding:
		return
	if required_hold_time <= 0.0:
		push_warning("HoldInteraction: required_hold_time must be greater than 0.")
		return

	is_holding = true
	elapsed = 0.0
	set_process(true)
	hold_started.emit(action_type, target_id, _get_prompt_text(), required_hold_time)
	progress_changed.emit(action_type, target_id, 0.0, elapsed, required_hold_time)


func cancel_hold() -> void:
	if not is_holding:
		return

	is_holding = false
	set_process(false)
	hold_canceled.emit(action_type, target_id, elapsed)
	elapsed = 0.0


func advance(delta: float) -> void:
	if not is_holding:
		return

	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return

	elapsed += step
	_apply_continuous_effect(step)

	var ratio := clampf(elapsed / required_hold_time, 0.0, 1.0)
	progress_changed.emit(action_type, target_id, ratio, elapsed, required_hold_time)

	if elapsed >= required_hold_time:
		_complete_hold()


func _process(delta: float) -> void:
	advance(delta)


func _complete_hold() -> void:
	if not is_holding:
		return

	is_holding = false
	set_process(false)
	_apply_completion_effect()
	hold_completed.emit(action_type, target_id)
	elapsed = 0.0


func _apply_continuous_effect(delta: float) -> void:
	match action_type:
		"repair_anchor":
			GameProcessManager.add_repair_time(delta)
		"fix_window":
			if RoomStateManager.can_fix_window(target_id):
				RoomStateManager.modify_window_durability(target_id, window_repair_rate * delta)


func _apply_completion_effect() -> void:
	match action_type:
		"fix_window":
			if send_behavior_message_on_complete:
				EventManager.on_behavior_message(BehaviorMessage.create("fix_window", target_id, true))
		"light_candle":
			RoomStateManager.set_candle_lit(target_id, true)
			if send_behavior_message_on_complete:
				EventManager.on_behavior_message(BehaviorMessage.create("light_candle", target_id, true))


func _get_prompt_text() -> String:
	if not prompt_text.is_empty():
		return prompt_text

	match action_type:
		"repair_anchor":
			return "修理锚回收装置"
		"fix_window":
			return "修补窗户"
		"light_candle":
			return "点亮蜡烛"
		_:
			return "交互"
