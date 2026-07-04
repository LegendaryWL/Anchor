class_name EventBase
extends Node

enum State {
	IDLE,
	TRIGGERED,
	ACTIVE,
	RESOLVED,
	FAILED,
}

signal state_changed(event_id: String, old_state: int, new_state: int)

var event_id: String = ""
var state: int = State.IDLE
var target_id: String = ""


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	var old_state := state
	state = new_state
	state_changed.emit(event_id, old_state, new_state)


func reset() -> void:
	target_id = ""
	_set_state(State.IDLE)


func on_behavior_message(_msg: BehaviorMessage) -> void:
	pass


func tick(_delta: float) -> void:
	pass
