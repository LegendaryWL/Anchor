extends Node

var window_attack_event: WindowAttackEvent
var candle_extinguish_event: CandleExtinguishEvent


func _ready() -> void:
	window_attack_event = WindowAttackEvent.new()
	window_attack_event.name = "WindowAttackEvent"
	add_child(window_attack_event)

	candle_extinguish_event = CandleExtinguishEvent.new()
	candle_extinguish_event.name = "CandleExtinguishEvent"
	add_child(candle_extinguish_event)

	set_process(false)


func reset() -> void:
	window_attack_event.reset()
	candle_extinguish_event.reset()


func simulate_step(delta: float) -> void:
	window_attack_event.tick(delta)
	candle_extinguish_event.tick(delta)
	GameProcessManager.tick(delta)


func trigger_window_attack(window_id: String, attack_duration: float = 10.0) -> void:
	window_attack_event.trigger(window_id, attack_duration)


func trigger_candle_extinguish(candle_id: String) -> void:
	candle_extinguish_event.trigger(candle_id)


func on_behavior_message(msg: BehaviorMessage) -> void:
	window_attack_event.on_behavior_message(msg)
	candle_extinguish_event.on_behavior_message(msg)


func has_active_window_attack() -> bool:
	return window_attack_event.state == EventBase.State.ACTIVE


func get_active_event_ids() -> Array[String]:
	var ids: Array[String] = []
	if window_attack_event.state == EventBase.State.ACTIVE:
		ids.append(window_attack_event.event_id)
	if candle_extinguish_event.state == EventBase.State.ACTIVE:
		ids.append(candle_extinguish_event.event_id)
	return ids


func get_window_attack_state() -> int:
	return window_attack_event.state


func get_candle_extinguish_state() -> int:
	return candle_extinguish_event.state
