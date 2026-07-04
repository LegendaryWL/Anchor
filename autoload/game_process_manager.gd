extends Node

enum Phase {
	ONE = 1,
	TWO = 2,
}

enum GameOverReason {
	NONE,
	VICTORY,
	DEFEAT,
}

signal phase_changed(old_phase: int, new_phase: int)
signal san_changed(current: float, max_san: float)
signal game_over(reason: int)
signal repair_progress_changed(accum: float, target: float)

var phase: int = Phase.ONE
var san_current: float = 100.0
var san_max: float = 100.0
var repair_time_accum: float = 0.0
var repair_time_target: float = 60.0
var game_over_reason: int = GameOverReason.NONE
var is_game_over: bool = false


func reset() -> void:
	phase = Phase.ONE
	san_current = 100.0
	san_max = 100.0
	repair_time_accum = 0.0
	game_over_reason = GameOverReason.NONE
	is_game_over = false


func tick(delta: float) -> void:
	if is_game_over:
		return

	var san_delta := 0.0
	if RoomStateManager.all_candles_lit():
		san_delta += delta * 1.5

	if EventManager.has_active_window_attack():
		san_delta -= delta * 1.0

	if phase == Phase.TWO and not RoomStateManager.all_candles_lit():
		san_delta -= delta * 5.0

	san_current = clampf(san_current + san_delta, 0.0, san_max)
	san_changed.emit(san_current, san_max)

	if san_current <= 0.0:
		_trigger_game_over(GameOverReason.DEFEAT)


func add_repair_time(delta: float) -> void:
	if is_game_over:
		return

	repair_time_accum += delta
	repair_progress_changed.emit(repair_time_accum, repair_time_target)
	if repair_time_accum >= repair_time_target and san_current > 0.0:
		_trigger_game_over(GameOverReason.VICTORY)


func enter_phase_2() -> void:
	if phase == Phase.TWO:
		return

	var old_phase := phase
	phase = Phase.TWO
	set_san_max(80.0)
	phase_changed.emit(old_phase, phase)


func set_san_max(value: float) -> void:
	san_max = value
	san_current = minf(san_current, san_max)
	san_changed.emit(san_current, san_max)


func get_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"san": san_current,
		"san_max": san_max,
		"repair_time_accum": repair_time_accum,
		"current_room_id": RoomStateManager.current_room_id,
		"active_events": EventManager.get_active_event_ids(),
		"is_game_over": is_game_over,
		"game_over_reason": game_over_reason,
	}


func _trigger_game_over(reason: int) -> void:
	if is_game_over:
		return
	is_game_over = true
	game_over_reason = reason
	game_over.emit(reason)
