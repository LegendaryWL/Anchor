class_name CandleExtinguishEvent
extends EventBase

const MAX_DURATION := 15.0

var elapsed: float = 0.0


func _init() -> void:
	event_id = "candle_extinguish"


func trigger(candle_id: String) -> void:
	if state == State.ACTIVE:
		return
	var candle := RoomStateManager.get_candle_state(candle_id)
	if candle.is_empty() or not candle["lit"]:
		return
	target_id = candle_id
	elapsed = 0.0
	_set_state(State.TRIGGERED)
	_set_state(State.ACTIVE)


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return

	elapsed += delta
	if elapsed >= MAX_DURATION:
		RoomStateManager.set_candle_lit(target_id, false)
		_set_state(State.FAILED)


func on_behavior_message(msg: BehaviorMessage) -> void:
	if state != State.ACTIVE:
		return
	if not msg.resolved:
		return
	if msg.target_id != target_id:
		return
	if msg.type != "expel_black_hand" and msg.type != "light_candle":
		return
	_set_state(State.RESOLVED)
