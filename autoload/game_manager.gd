extends Node

signal san_changed(current: float, max_value: float)
signal anchor_progress_changed(value: float)
signal window_changed(window_id: String, durability: float, is_broken: bool)
signal candle_changed(candle_id: String, lit: bool)
signal phase_changed(phase: int)
signal room_changed(room_id: String)
signal attack_started(target_id: String, attack_type: String)
signal attack_resolved(target_id: String, attack_type: String)
signal game_over(result: String)

const PHASE_WINDOW := 1
const PHASE_CANDLE := 2

var phase: int = PHASE_WINDOW
var san: float = 100.0
var san_max: float = 100.0
var anchor_progress: float = 0.0
var anchor_target: float = 60.0
var current_room_id: String = "room_a"
var is_game_over: bool = false

var windows: Dictionary = {
	"window_room_a_0": {"room": "room_a", "durability": 100.0, "broken": false},
	"window_room_a_1": {"room": "room_a", "durability": 100.0, "broken": false},
	"window_room_b_0": {"room": "room_b", "durability": 100.0, "broken": false},
	"window_room_b_1": {"room": "room_b", "durability": 100.0, "broken": false},
}

var candles: Dictionary = {
	"candle_room_a_0": {"room": "room_a", "lit": true},
	"candle_room_a_1": {"room": "room_a", "lit": true},
	"candle_room_b_0": {"room": "room_b", "lit": true},
	"candle_room_b_1": {"room": "room_b", "lit": true},
}

var active_attack: Dictionary = {}
var attack_timer: float = 0.0
var next_attack_timer: float = 6.0
var attacks_enabled: bool = false


func _process(delta: float) -> void:
	if is_game_over:
		return
	_update_attack(delta)
	_update_san(delta)
	_check_game_over()


func repair_anchor(delta: float) -> void:
	if is_game_over:
		return
	anchor_progress = minf(anchor_progress + delta, anchor_target)
	anchor_progress_changed.emit(anchor_progress / anchor_target)


func repair_window(window_id: String, delta: float) -> void:
	if not windows.has(window_id):
		return
	var window: Dictionary = windows[window_id]
	if window["broken"]:
		return
	window["durability"] = minf(window["durability"] + 4.0 * delta, 100.0)
	window_changed.emit(window_id, window["durability"], window["broken"])
	if active_attack.get("target_id", "") == window_id:
		_resolve_attack()


func light_candle(candle_id: String) -> void:
	if not candles.has(candle_id):
		return
	candles[candle_id]["lit"] = true
	candle_changed.emit(candle_id, true)
	if active_attack.get("target_id", "") == candle_id:
		_resolve_attack()


func extinguish_candle(candle_id: String) -> void:
	_extinguish_candle(candle_id)


func expel_black_hand(candle_id: String) -> void:
	if active_attack.get("target_id", "") == candle_id:
		_resolve_attack()


func switch_room(room_id: String) -> void:
	current_room_id = room_id
	room_changed.emit(room_id)


func set_attacks_enabled(enabled: bool) -> void:
	attacks_enabled = enabled


func reset_game() -> void:
	phase = PHASE_WINDOW
	san = 100.0
	san_max = 100.0
	anchor_progress = 0.0
	current_room_id = "room_a"
	is_game_over = false
	active_attack = {}
	attack_timer = 0.0
	next_attack_timer = 6.0
	attacks_enabled = false

	for window_id in windows.keys():
		windows[window_id]["durability"] = 100.0
		windows[window_id]["broken"] = false

	for candle_id in candles.keys():
		candles[candle_id]["lit"] = true


func get_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"san": san,
		"san_max": san_max,
		"anchor_progress": anchor_progress / anchor_target,
		"current_room_id": current_room_id,
		"active_attack": active_attack.duplicate(),
		"is_game_over": is_game_over,
	}


func _update_san(delta: float) -> void:
	var all_lit := true
	for candle in candles.values():
		if not candle["lit"]:
			all_lit = false
			break

	if all_lit:
		san += delta * 1.5

	if not active_attack.is_empty() and active_attack["type"] == "window":
		san -= delta * 1.0

	if phase == PHASE_CANDLE:
		for candle in candles.values():
			if not candle["lit"]:
				san -= delta * 5.0
				break

	san = clampf(san, 0.0, san_max)
	san_changed.emit(san, san_max)


func _update_attack(delta: float) -> void:
	if not attacks_enabled:
		return

	if not active_attack.is_empty():
		attack_timer -= delta
		if active_attack["type"] == "window":
			_damage_window(active_attack["target_id"], delta)
		if attack_timer <= 0.0:
			_attack_timeout()
		return

	next_attack_timer -= delta
	if next_attack_timer <= 0.0:
		_start_random_attack()


func _start_random_attack() -> void:
	if phase == PHASE_WINDOW:
		var ids: Array = windows.keys()
		var target_id: String = ids[randi() % ids.size()]
		active_attack = {"type": "window", "target_id": target_id}
		attack_timer = randf_range(8.0, 15.0)
		attack_started.emit(target_id, "window")
	else:
		var lit_ids: Array[String] = []
		for id in candles.keys():
			if candles[id]["lit"]:
				lit_ids.append(id)
		if lit_ids.is_empty():
			next_attack_timer = 4.0
			return
		var target_id: String = lit_ids[randi() % lit_ids.size()]
		active_attack = {"type": "candle", "target_id": target_id}
		attack_timer = 15.0
		attack_started.emit(target_id, "candle")


func _damage_window(window_id: String, delta: float) -> void:
	var window: Dictionary = windows[window_id]
	if window["broken"]:
		return
	window["durability"] = maxf(window["durability"] - 5.0 * delta, 0.0)
	if window["durability"] <= 0.0:
		window["broken"] = true
		_enter_phase_2()
	window_changed.emit(window_id, window["durability"], window["broken"])


func _attack_timeout() -> void:
	if active_attack["type"] == "candle":
		_extinguish_candle(active_attack["target_id"])
	_resolve_attack()


func _extinguish_candle(candle_id: String) -> void:
	if not candles.has(candle_id):
		return
	candles[candle_id]["lit"] = false
	candle_changed.emit(candle_id, false)


func break_window(window_id: String) -> void:
	if not windows.has(window_id):
		return
	var window: Dictionary = windows[window_id]
	window["durability"] = 0.0
	window["broken"] = true
	window_changed.emit(window_id, 0.0, true)
	_enter_phase_2()


func _resolve_attack() -> void:
	if not active_attack.is_empty():
		attack_resolved.emit(active_attack["target_id"], active_attack["type"])
	active_attack = {}
	next_attack_timer = randf_range(6.0, 12.0)


func _enter_phase_2() -> void:
	if phase == PHASE_CANDLE:
		return
	phase = PHASE_CANDLE
	san_max = 80.0
	san = minf(san, san_max)
	phase_changed.emit(phase)
	san_changed.emit(san, san_max)


func _check_game_over() -> void:
	if san <= 0.0:
		is_game_over = true
		game_over.emit("lose")
	elif anchor_progress >= anchor_target:
		is_game_over = true
		game_over.emit("win")
