class_name ClickSpamInteraction
extends Node

signal click_started(action_type: String, target_id: String, required_clicks: int)
signal click_progress_changed(action_type: String, target_id: String, clicks: int, required_clicks: int, ratio: float)
signal click_completed(action_type: String, target_id: String)
signal click_reset(action_type: String, target_id: String)

@export_enum("expel_black_hand") var action_type := "expel_black_hand"
@export var target_id := ""
@export_range(1, 30, 1) var required_clicks: int = 5
@export var reset_after_seconds := 2.0
@export var send_behavior_message_on_complete := true

var clicks := 0
var is_tracking := false
var is_completed := false

var _seconds_since_click := 0.0


func _ready() -> void:
	set_process(false)


func register_click() -> void:
	if required_clicks <= 0:
		push_warning("ClickSpamInteraction: required_clicks must be greater than 0.")
		return

	if is_completed:
		reset_clicks()

	if clicks == 0:
		is_tracking = true
		_seconds_since_click = 0.0
		set_process(reset_after_seconds > 0.0)
		click_started.emit(action_type, target_id, required_clicks)

	clicks = mini(clicks + 1, required_clicks)
	_seconds_since_click = 0.0

	var ratio := float(clicks) / float(required_clicks)
	click_progress_changed.emit(action_type, target_id, clicks, required_clicks, ratio)

	if clicks >= required_clicks:
		_complete_clicks()


func reset_clicks() -> void:
	if clicks == 0 and not is_tracking and not is_completed:
		return

	clicks = 0
	is_tracking = false
	is_completed = false
	_seconds_since_click = 0.0
	set_process(false)
	click_progress_changed.emit(action_type, target_id, clicks, required_clicks, 0.0)
	click_reset.emit(action_type, target_id)


func _process(delta: float) -> void:
	if not is_tracking or clicks <= 0:
		return

	_seconds_since_click += maxf(delta, 0.0)
	if reset_after_seconds > 0.0 and _seconds_since_click >= reset_after_seconds:
		reset_clicks()


func _complete_clicks() -> void:
	if is_completed:
		return

	is_tracking = false
	is_completed = true
	set_process(false)

	if send_behavior_message_on_complete:
		EventManager.on_behavior_message(BehaviorMessage.create(
			action_type,
			target_id,
			true,
			{"clicks": clicks}
		))

	click_completed.emit(action_type, target_id)
