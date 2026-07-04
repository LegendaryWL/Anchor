extends Node

signal window_durability_changed(window_id: String, durability: int)
signal candle_lit_changed(candle_id: String, lit: bool)
signal room_changed(room_id: String)

var current_room_id: String = "room_a"
var windows: Dictionary = {}
var candles: Dictionary = {}


func _ready() -> void:
	reset_to_default()


func reset_to_default() -> void:
	current_room_id = "room_a"
	windows.clear()
	candles.clear()

	for room_id in ["room_a", "room_b"]:
		for index in 2:
			var window_id := "window_%s_%d" % [room_id, index]
			windows[window_id] = {
				"id": window_id,
				"room_id": room_id,
				"durability": 100.0,
				"max_durability": 100,
				"is_broken": false,
			}
			var candle_id := "candle_%s_%d" % [room_id, index]
			candles[candle_id] = {
				"id": candle_id,
				"room_id": room_id,
				"lit": true,
			}


func get_window_state(window_id: String) -> Dictionary:
	return windows.get(window_id, {})


func get_candle_state(candle_id: String) -> Dictionary:
	return candles.get(candle_id, {})


func set_current_room(room_id: String) -> void:
	current_room_id = room_id
	room_changed.emit(room_id)


func all_candles_lit() -> bool:
	for candle in candles.values():
		if not candle["lit"]:
			return false
	return true


func can_fix_window(window_id: String) -> bool:
	var window := get_window_state(window_id)
	if window.is_empty():
		return false
	return not window["is_broken"] and window["durability"] < float(window["max_durability"])


func modify_window_durability(window_id: String, delta: float) -> void:
	if not windows.has(window_id):
		return

	var window: Dictionary = windows[window_id]
	if window["is_broken"]:
		return

	window["durability"] = clampf(
		float(window["durability"]) + delta,
		0.0,
		float(window["max_durability"])
	)
	if window["durability"] <= 0.0:
		window["is_broken"] = true
		window["durability"] = 0.0
		_check_phase_transition()

	window_durability_changed.emit(window_id, int(window["durability"]))


func set_window_durability(window_id: String, value: int) -> void:
	if not windows.has(window_id):
		return

	var window: Dictionary = windows[window_id]
	window["durability"] = clampf(float(value), 0.0, float(window["max_durability"]))
	window["is_broken"] = window["durability"] <= 0.0
	if window["is_broken"]:
		window["durability"] = 0.0
		_check_phase_transition()

	window_durability_changed.emit(window_id, int(window["durability"]))


func set_candle_lit(candle_id: String, lit: bool) -> void:
	if not candles.has(candle_id):
		return
	candles[candle_id]["lit"] = lit
	candle_lit_changed.emit(candle_id, lit)


func _check_phase_transition() -> void:
	if GameProcessManager.phase != GameProcessManager.Phase.ONE:
		return
	GameProcessManager.enter_phase_2()
