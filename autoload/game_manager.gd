extends Node

signal san_changed(current: float, max_value: float)
signal anchor_progress_changed(value: float)
signal window_changed(window_id: String, durability: int, is_broken: bool)
signal candle_changed(candle_id: String, lit: bool)
signal phase_changed(phase: int)
signal room_changed(room_id: String)
signal attack_started(target_id: String, attack_type: String)
signal attack_resolved(target_id: String, attack_type: String)
signal black_hand_expel_changed(target_id: String, progress: int, required: int)
signal game_over(result: String)

const PHASE_WINDOW := 1
const PHASE_CANDLE := 2
const WINDOW_DURABILITY_MAX := 100
const GAME_TIME_PASSIVE_DECAY_SEC := 120.0
const WINDOW_REPAIR_RATE := 4.0
const WINDOW_ATTACK_RATE := 5.0
const WINDOW_PASSIVE_DECAY_RATE := 8.0
const ATTACK_DURATION_MIN := 8.0
const ATTACK_DURATION_MAX := 15.0
const ATTACK_COOLDOWN_MIN := 6.0
const ATTACK_COOLDOWN_MAX := 12.0
const CANDLE_ATTACK_DURATION := 15.0
const BLACK_HAND_EXPEL_MIN := 5
const BLACK_HAND_EXPEL_MAX := 8

var phase: int = PHASE_WINDOW
var san: float = 100.0
var san_max: float = 100.0
var anchor_progress: float = 0.0
var anchor_target: float = 60.0
var current_room_id: String = "room_a"
var current_view_id: String = "room_a"
var is_game_over: bool = false
var game_time: float = 0.0

const BOW_VIEWS := ["bow_room_0", "bow_room_1"]

var windows: Dictionary = {
	"window_room_a_0": {"room": "room_a", "view": "room_a", "durability": 100, "broken": false},
	"window_room_a_1": {"room": "room_a", "view": "room_a", "durability": 100, "broken": false},
	"window_room_b_0": {"room": "room_b", "view": "room_b", "durability": 100, "broken": false},
	"window_room_b_1": {"room": "room_b", "view": "room_b", "durability": 100, "broken": false},
	"window_bow_room_0": {"room": "bow_room", "view": "bow_room_1", "durability": 100, "broken": false},
}

var candles: Dictionary = {
	"candle_room_a_0": {"room": "room_a", "view": "room_a", "lit": true},
	"candle_room_a_1": {"room": "room_a", "view": "room_a", "lit": true},
	"candle_room_b_0": {"room": "room_b", "view": "room_b", "lit": true},
	"candle_room_b_1": {"room": "room_b", "view": "room_b", "lit": true},
	"candle_bow_room_0": {"room": "bow_room", "view": "bow_room_0", "lit": true},
	"candle_bow_room_1": {"room": "bow_room", "view": "bow_room_1", "lit": true},
}

var active_attack: Dictionary = {}
var attack_timer: float = 0.0
var next_attack_timer: float = 6.0
var attacks_enabled: bool = false


func _process(delta: float) -> void:
	if is_game_over:
		return
	game_time += delta
	_update_window_passive_decay(delta)
	_update_attack(delta)
	_update_san(delta)
	_check_game_over()


func repair_anchor(delta: float) -> void:
	if is_game_over:
		return
	anchor_progress = minf(anchor_progress + delta, anchor_target)
	anchor_progress_changed.emit(anchor_progress / anchor_target)


func repair_window(window_id: String, delta: float) -> bool:
	if is_game_over:
		return false
	if not windows.has(window_id):
		return false
	var window: Dictionary = windows[window_id]
	if window["broken"]:
		return false
	if not _can_interact_in_current_view(window):
		return false
	_apply_window_durability_change(window_id, window, WINDOW_REPAIR_RATE * delta)
	window_changed.emit(window_id, window["durability"], window["broken"])
	if active_attack.get("target_id", "") == window_id:
		_resolve_attack()
	return true


func light_candle(candle_id: String) -> bool:
	if is_game_over:
		return false
	if not candles.has(candle_id):
		return false
	var candle: Dictionary = candles[candle_id]
	if not _can_interact_in_current_view(candle):
		return false
	candle["lit"] = true
	candle_changed.emit(candle_id, true)
	return true


func extinguish_candle(candle_id: String) -> bool:
	if is_game_over:
		return false
	if not candles.has(candle_id):
		return false
	var candle: Dictionary = candles[candle_id]
	if not _can_interact_in_current_view(candle):
		return false
	_extinguish_candle(candle_id)
	return true


func expel_black_hand(candle_id: String) -> bool:
	if is_game_over:
		return false
	if not candles.has(candle_id):
		return false
	if not _can_interact_in_current_view(candles[candle_id]):
		return false
	if (
		active_attack.is_empty()
		or active_attack.get("type") != "candle"
		or active_attack.get("target_id", "") != candle_id
	):
		return false
	var progress: int = int(active_attack.get("expel_progress", 0)) + 1
	var required: int = int(active_attack.get("expel_required", BLACK_HAND_EXPEL_MIN))
	active_attack["expel_progress"] = progress
	black_hand_expel_changed.emit(candle_id, progress, required)
	if progress >= required:
		_resolve_attack()
	return true


func can_expel_black_hand(candle_id: String) -> bool:
	if is_game_over or not candles.has(candle_id):
		return false
	return (
		_can_interact_in_current_view(candles[candle_id])
		and is_candle_under_attack(candle_id)
	)


func switch_room(view_id: String) -> void:
	if is_game_over:
		return
	if view_id in BOW_VIEWS:
		current_room_id = "bow_room"
		current_view_id = view_id
	else:
		current_room_id = view_id
		current_view_id = view_id
	room_changed.emit(view_id)


func can_repair_window(window_id: String) -> bool:
	if is_game_over or not windows.has(window_id):
		return false
	var window: Dictionary = windows[window_id]
	return (
		not window["broken"]
		and window["durability"] < WINDOW_DURABILITY_MAX
		and _can_interact_in_current_view(window)
	)


func can_light_candle(candle_id: String) -> bool:
	if is_game_over or not candles.has(candle_id):
		return false
	var candle: Dictionary = candles[candle_id]
	return not candle["lit"] and _can_interact_in_current_view(candle)


func count_unlit_candles() -> int:
	var count := 0
	for candle in candles.values():
		if not candle["lit"]:
			count += 1
	return count


func _can_interact_in_current_view(entity: Dictionary) -> bool:
	return entity.get("view", entity["room"]) == current_view_id


func get_window_ids_in_current_view() -> Array[String]:
	var ids: Array[String] = []
	for window_id in windows.keys():
		if _can_interact_in_current_view(windows[window_id]):
			ids.append(window_id)
	return ids


func get_candle_ids_in_current_view() -> Array[String]:
	var ids: Array[String] = []
	for candle_id in candles.keys():
		if _can_interact_in_current_view(candles[candle_id]):
			ids.append(candle_id)
	return ids


func get_primary_window_in_view() -> String:
	for window_id in get_window_ids_in_current_view():
		if can_repair_window(window_id):
			return window_id
	for window_id in get_window_ids_in_current_view():
		var window: Dictionary = windows[window_id]
		if not window["broken"]:
			return window_id
	return ""


func get_primary_candle_in_view(prefer_unlit: bool = false) -> String:
	if prefer_unlit:
		for candle_id in get_candle_ids_in_current_view():
			if not candles[candle_id]["lit"]:
				return candle_id
	for candle_id in get_candle_ids_in_current_view():
		return candle_id
	return ""


func get_primary_lit_candle_in_view() -> String:
	for candle_id in get_candle_ids_in_current_view():
		if candles[candle_id]["lit"]:
			return candle_id
	return ""


func chip_window_damage(window_id: String, amount: int) -> bool:
	if is_game_over or not windows.has(window_id):
		return false
	var window: Dictionary = windows[window_id]
	if window["broken"]:
		return false
	if not _can_interact_in_current_view(window):
		return false
	_apply_window_durability_change(window_id, window, -float(amount))
	window_changed.emit(window_id, window["durability"], window["broken"])
	return true


func get_window_state(window_id: String) -> Dictionary:
	return windows.get(window_id, {}).duplicate()


func get_candle_state(candle_id: String) -> Dictionary:
	return candles.get(candle_id, {}).duplicate()


func get_window_durability_value(window_id: String) -> float:
	if not windows.has(window_id):
		return 0.0
	var window: Dictionary = windows[window_id]
	return float(window["durability"]) + float(window.get("_durability_frac", 0.0))


func get_windows_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for window_id in windows.keys():
		var window: Dictionary = windows[window_id]
		snapshot[window_id] = {
			"room": window["room"],
			"view": window.get("view", window["room"]),
			"durability": window["durability"],
			"durability_exact": get_window_durability_value(window_id),
			"broken": window["broken"],
		}
	return snapshot


func get_candles_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for candle_id in candles.keys():
		var candle: Dictionary = candles[candle_id]
		snapshot[candle_id] = {
			"room": candle["room"],
			"view": candle.get("view", candle["room"]),
			"lit": candle["lit"],
		}
	return snapshot


func set_attacks_enabled(enabled: bool) -> void:
	attacks_enabled = enabled


func skip_attack_cooldown() -> void:
	next_attack_timer = 0.0


func force_window_attack(window_id: String, duration: float = 10.0) -> bool:
	if is_game_over or not attacks_enabled or phase != PHASE_WINDOW:
		return false
	if not windows.has(window_id):
		return false
	var window: Dictionary = windows[window_id]
	if window["broken"]:
		return false
	if not active_attack.is_empty():
		return false
	active_attack = {"type": "window", "target_id": window_id}
	attack_timer = maxf(duration, 0.1)
	attack_started.emit(window_id, "window")
	return true


func is_window_under_attack(window_id: String) -> bool:
	return (
		not active_attack.is_empty()
		and active_attack.get("type") == "window"
		and active_attack.get("target_id", "") == window_id
	)


func force_candle_attack(
	candle_id: String,
	duration: float = CANDLE_ATTACK_DURATION,
	expel_required: int = -1,
) -> bool:
	if is_game_over or not attacks_enabled or phase != PHASE_CANDLE:
		return false
	if not candles.has(candle_id):
		return false
	if not candles[candle_id]["lit"]:
		return false
	if not active_attack.is_empty():
		return false
	_begin_candle_attack(candle_id, maxf(duration, 0.1), expel_required)
	return true


func is_candle_under_attack(candle_id: String) -> bool:
	return (
		not active_attack.is_empty()
		and active_attack.get("type") == "candle"
		and active_attack.get("target_id", "") == candle_id
	)


func get_candle_under_attack_in_view() -> String:
	if active_attack.get("type") != "candle":
		return ""
	var candle_id: String = active_attack.get("target_id", "")
	if not candles.has(candle_id):
		return ""
	if not _can_interact_in_current_view(candles[candle_id]):
		return ""
	return candle_id


func get_black_hand_expel_state() -> Dictionary:
	if active_attack.get("type") != "candle":
		return {}
	return {
		"target_id": active_attack.get("target_id", ""),
		"expel_progress": int(active_attack.get("expel_progress", 0)),
		"expel_required": int(active_attack.get("expel_required", 0)),
		"time_left": attack_timer,
	}


func enter_phase_2_for_test() -> void:
	_enter_phase_2()


func get_active_attack_target() -> String:
	return active_attack.get("target_id", "")


func reset_game() -> void:
	phase = PHASE_WINDOW
	san = 100.0
	san_max = 100.0
	anchor_progress = 0.0
	current_room_id = "room_a"
	current_view_id = "room_a"
	is_game_over = false
	game_time = 0.0
	active_attack = {}
	attack_timer = 0.0
	next_attack_timer = 6.0
	attacks_enabled = false

	for window_id in windows.keys():
		windows[window_id]["durability"] = WINDOW_DURABILITY_MAX
		windows[window_id]["broken"] = false
		windows[window_id]["_durability_frac"] = 0.0

	for candle_id in candles.keys():
		candles[candle_id]["lit"] = true


func get_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"san": san,
		"san_max": san_max,
		"anchor_progress": anchor_progress / anchor_target,
		"current_room_id": current_room_id,
		"current_view_id": current_view_id,
		"game_time": game_time,
		"attacks_enabled": attacks_enabled,
		"attack_timer": attack_timer,
		"next_attack_timer": next_attack_timer,
		"unlit_candle_count": count_unlit_candles(),
		"active_attack": active_attack.duplicate(),
		"black_hand": get_black_hand_expel_state(),
		"is_game_over": is_game_over,
		"windows": get_windows_snapshot(),
		"candles": get_candles_snapshot(),
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
		var unlit_count := count_unlit_candles()
		if unlit_count > 0:
			san -= delta * 5.0 * float(unlit_count)

	san = clampf(san, 0.0, san_max)
	san_changed.emit(san, san_max)


func _update_window_passive_decay(delta: float) -> void:
	if game_time <= GAME_TIME_PASSIVE_DECAY_SEC:
		return
	for window_id in windows.keys():
		var window: Dictionary = windows[window_id]
		if window["broken"]:
			continue
		var before: int = window["durability"]
		_apply_window_durability_change(window_id, window, -WINDOW_PASSIVE_DECAY_RATE * delta)
		if window["durability"] != before or window["broken"]:
			window_changed.emit(window_id, window["durability"], window["broken"])


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
		var ids: Array[String] = []
		for window_id in windows.keys():
			var window: Dictionary = windows[window_id]
			if not window["broken"]:
				ids.append(window_id)
		if ids.is_empty():
			next_attack_timer = 4.0
			return
		var target_id: String = ids[randi() % ids.size()]
		active_attack = {"type": "window", "target_id": target_id}
		attack_timer = randf_range(ATTACK_DURATION_MIN, ATTACK_DURATION_MAX)
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
		_begin_candle_attack(target_id, CANDLE_ATTACK_DURATION)


func _begin_candle_attack(target_id: String, duration: float, expel_required: int = -1) -> void:
	var required: int = expel_required
	if required < 0:
		required = randi_range(BLACK_HAND_EXPEL_MIN, BLACK_HAND_EXPEL_MAX)
	active_attack = {
		"type": "candle",
		"target_id": target_id,
		"expel_required": required,
		"expel_progress": 0,
	}
	attack_timer = duration
	attack_started.emit(target_id, "candle")
	black_hand_expel_changed.emit(target_id, 0, required)


func _damage_window(window_id: String, delta: float) -> void:
	var window: Dictionary = windows[window_id]
	if window["broken"]:
		return
	_apply_window_durability_change(window_id, window, -WINDOW_ATTACK_RATE * delta)
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


func _apply_window_durability_change(window_id: String, window: Dictionary, delta: float) -> void:
	if window["broken"]:
		return
	var was_broken := false
	var total: float = float(window["durability"]) + float(window.get("_durability_frac", 0.0)) + delta
	total = clampf(total, 0.0, float(WINDOW_DURABILITY_MAX))
	window["durability"] = int(total)
	window["_durability_frac"] = total - float(window["durability"])
	if window["durability"] <= 0:
		window["durability"] = 0
		window["_durability_frac"] = 0.0
		window["broken"] = true
		was_broken = true
		_enter_phase_2()
	if was_broken and is_window_under_attack(window_id):
		_resolve_attack()


func break_window(window_id: String) -> bool:
	if not windows.has(window_id):
		return false
	var window: Dictionary = windows[window_id]
	if not _can_interact_in_current_view(window):
		return false
	window["durability"] = 0
	window["_durability_frac"] = 0.0
	window["broken"] = true
	window_changed.emit(window_id, 0, true)
	_enter_phase_2()
	if is_window_under_attack(window_id):
		_resolve_attack()
	return true


func _resolve_attack() -> void:
	if not active_attack.is_empty():
		attack_resolved.emit(active_attack["target_id"], active_attack["type"])
	active_attack = {}
	next_attack_timer = randf_range(ATTACK_COOLDOWN_MIN, ATTACK_COOLDOWN_MAX)


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
