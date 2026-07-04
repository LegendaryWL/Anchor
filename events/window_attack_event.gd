class_name WindowAttackEvent
extends EventBase

const DURABILITY_DRAIN_RATE := 5.0

var duration: float = 0.0
var elapsed: float = 0.0


func _init() -> void:
	event_id = "window_attack"


func trigger(window_id: String, attack_duration: float) -> void:
	if state == State.ACTIVE:
		return
	target_id = window_id
	duration = attack_duration
	elapsed = 0.0
	_set_state(State.TRIGGERED)
	_set_state(State.ACTIVE)


func tick(delta: float) -> void:
	if state != State.ACTIVE:
		return

	elapsed += delta
	RoomStateManager.modify_window_durability(target_id, -DURABILITY_DRAIN_RATE * delta)

	if elapsed >= duration:
		_set_state(State.RESOLVED)


func on_behavior_message(msg: BehaviorMessage) -> void:
	if state != State.ACTIVE:
		return
	if not msg.resolved:
		return
	if msg.type != "fix_window":
		return
	if msg.target_id != target_id:
		return
	_set_state(State.RESOLVED)
