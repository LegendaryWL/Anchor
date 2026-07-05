## M4 验收：Phase 2 黑手、熄烛、点蜡烛、驱赶黑手。
## 运行：打开 gameplay/m4_test.tscn，按 F6。
extends Node

const CANDLE_TARGET := "candle_room_a_0"
const WINDOW_TARGET := "window_room_a_0"
const EXPEL_REQUIRED := 5

@export var skip_auto_tests: bool = false

@onready var _hud_label: Label = $CanvasLayer/HUD/Label

var _passed := 0
var _failed := 0
var _manual_enabled := false
var _last_attack_resolved := ""


func _ready() -> void:
	GameManager.attack_started.connect(func(id, _t): _refresh_hud())
	GameManager.attack_resolved.connect(_on_attack_resolved)
	GameManager.black_hand_expel_changed.connect(func(_id, _p, _r): _refresh_hud())
	GameManager.candle_changed.connect(func(_id, _lit): _refresh_hud())
	GameManager.san_changed.connect(func(_c, _m): _refresh_hud())
	GameManager.phase_changed.connect(func(_p): _refresh_hud())
	_refresh_hud()

	await get_tree().process_frame
	if skip_auto_tests:
		_start_manual_mode("已跳过自动测试")
		return

	print("========== M4 自动验收开始 ==========")
	await _run_enter_phase_2_test()
	await _run_candle_attack_start_test()
	await _run_timeout_extinguish_test()
	await _run_expel_resolves_test()
	await _run_partial_expel_test()
	await _run_light_after_extinguish_test()
	await _run_phase2_san_drain_test()
	await _run_expel_second_candle_test()
	print("========== M4 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	if _failed == 0:
		_start_manual_mode("M4 全部通过，进入手动测试")
	else:
		push_error("M4 自动验收失败，请检查上方 [FAIL]")
		_start_manual_mode("自动测试有失败项，仍可手动试")


func _start_manual_mode(message: String) -> void:
	_reset_for_m4()
	print("========== %s ==========" % message)
	print("E=驱赶被袭烛 | 1/2=强制黑手袭击当前视角第1/2根烛 | L=点当前烛 | 3/4/5/6=切房间 | R=重置")
	_manual_enabled = true
	_refresh_hud()


func _reset_for_m4() -> void:
	GameManager.reset_game()
	GameManager.set_attacks_enabled(true)
	_enter_phase_2_via_window()
	_last_attack_resolved = ""


func _enter_phase_2_via_window() -> void:
	GameManager.windows[WINDOW_TARGET]["durability"] = 0
	GameManager.windows[WINDOW_TARGET]["broken"] = true
	GameManager.enter_phase_2_for_test()


func _process(_delta: float) -> void:
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not _manual_enabled:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			_reset_for_m4()
			print("[手动] 已重置并进入 Phase 2")
		KEY_E:
			_try_expel_attacked_candle()
		KEY_1:
			_try_force_candle_attack_at(0)
		KEY_2:
			_try_force_candle_attack_at(1)
		KEY_L:
			_try_light_current_candle()
		KEY_3:
			GameManager.switch_room("room_a")
		KEY_4:
			GameManager.switch_room("room_b")
		KEY_5:
			GameManager.switch_room("bow_room_0")
		KEY_6:
			GameManager.switch_room("bow_room_1")


func _try_expel_attacked_candle() -> void:
	var candle_id := GameManager.get_candle_under_attack_in_view()
	if candle_id.is_empty():
		var target := GameManager.get_active_attack_target()
		if target.is_empty():
			print("[手动] 当前无黑手袭击")
		else:
			print("[手动] 黑手正在袭击 %s，请切到对应视角再按 E" % target)
		return
	if GameManager.expel_black_hand(candle_id):
		var state: Dictionary = GameManager.get_black_hand_expel_state()
		if state.is_empty():
			print("[手动] 驱赶成功，黑手已化解")
		else:
			print("[手动] 驱赶 %s (%d/%d)" % [
				candle_id, state["expel_progress"], state["expel_required"],
			])
	else:
		print("[手动] 无法驱赶 %s" % candle_id)


func _try_force_candle_attack_at(index: int) -> void:
	var ids := GameManager.get_candle_ids_in_current_view()
	if index >= ids.size():
		print("[手动] 当前视角没有第 %d 根蜡烛" % (index + 1))
		return
	var candle_id: String = ids[index]
	if not GameManager.candles[candle_id]["lit"]:
		print("[手动] %s 已熄灭，无法袭击" % candle_id)
		return
	if GameManager.force_candle_attack(candle_id, 15.0):
		print("[手动] 强制黑手袭击 %s" % candle_id)
	else:
		print("[手动] 无法袭击 %s（可能已有袭击进行中）" % candle_id)


func _try_light_current_candle() -> void:
	var candle_id := GameManager.get_primary_candle_in_view(true)
	if candle_id.is_empty():
		print("[手动] 当前视角无已熄灭蜡烛")
		return
	if GameManager.light_candle(candle_id):
		print("[手动] 点亮 %s" % candle_id)
	else:
		print("[手动] 无法点亮 %s" % candle_id)


func _run_enter_phase_2_test() -> void:
	print("\n--- M4-A: 破窗进入 Phase 2 ---")
	GameManager.reset_game()
	GameManager.break_window(WINDOW_TARGET)
	check("M4-A phase 2", GameManager.phase, GameManager.PHASE_CANDLE)
	check("M4-A san max", GameManager.san_max, 80.0)
	print_snapshot("M4-A")


func _run_candle_attack_start_test() -> void:
	print("\n--- M4-B: Phase 2 黑手袭击启动 ---")
	_reset_for_m4()
	check("M4-B force candle attack", GameManager.force_candle_attack(CANDLE_TARGET, 12.0, EXPEL_REQUIRED), true)
	check("M4-B under attack", GameManager.is_candle_under_attack(CANDLE_TARGET), true)
	var state: Dictionary = GameManager.get_black_hand_expel_state()
	check("M4-B expel required", state["expel_required"], EXPEL_REQUIRED)
	print_snapshot("M4-B")


func _run_timeout_extinguish_test() -> void:
	print("\n--- M4-C: 超时熄灭蜡烛 ---")
	_reset_for_m4()
	check("M4-C force short attack", GameManager.force_candle_attack(CANDLE_TARGET, 0.4, EXPEL_REQUIRED), true)
	await _wait_seconds(0.8)
	check("M4-C candle extinguished", GameManager.candles[CANDLE_TARGET]["lit"], false)
	check("M4-C attack cleared", GameManager.active_attack.is_empty(), true)
	print_snapshot("M4-C")


func _run_expel_resolves_test() -> void:
	print("\n--- M4-D: 连点驱赶化解黑手 ---")
	_reset_for_m4()
	check("M4-D force attack", GameManager.force_candle_attack(CANDLE_TARGET, 12.0, EXPEL_REQUIRED), true)
	for _i in EXPEL_REQUIRED:
		check("M4-D expel click", GameManager.expel_black_hand(CANDLE_TARGET), true)
	check("M4-D attack cleared", GameManager.active_attack.is_empty(), true)
	check("M4-D candle still lit", GameManager.candles[CANDLE_TARGET]["lit"], true)
	check("M4-D resolved signal", _last_attack_resolved, CANDLE_TARGET)
	print_snapshot("M4-D")


func _run_partial_expel_test() -> void:
	print("\n--- M4-E: 未达次数不化解 ---")
	_reset_for_m4()
	check("M4-E force attack", GameManager.force_candle_attack(CANDLE_TARGET, 12.0, EXPEL_REQUIRED), true)
	for _i in EXPEL_REQUIRED - 1:
		GameManager.expel_black_hand(CANDLE_TARGET)
	check("M4-E attack still active", GameManager.is_candle_under_attack(CANDLE_TARGET), true)
	var state: Dictionary = GameManager.get_black_hand_expel_state()
	check("M4-E partial progress", state["expel_progress"], EXPEL_REQUIRED - 1)
	print_snapshot("M4-E")


func _run_light_after_extinguish_test() -> void:
	print("\n--- M4-F: 熄灭后点蜡烛重燃 ---")
	_reset_for_m4()
	GameManager.candles[CANDLE_TARGET]["lit"] = false
	check("M4-F light candle", GameManager.light_candle(CANDLE_TARGET), true)
	check("M4-F candle lit", GameManager.candles[CANDLE_TARGET]["lit"], true)
	print_snapshot("M4-F")


func _run_phase2_san_drain_test() -> void:
	print("\n--- M4-G: Phase 2 灭烛扣 SAN ---")
	_reset_for_m4()
	GameManager.candles[CANDLE_TARGET]["lit"] = false
	GameManager.san = 80.0
	var start_san: float = GameManager.san
	await _wait_seconds(1.5)
	check("M4-G san decreased", GameManager.san < start_san, true)
	print_snapshot("M4-G")


func _run_expel_second_candle_test() -> void:
	print("\n--- M4-H: 驱赶 candle_room_a_1 ---")
	_reset_for_m4()
	const TARGET := "candle_room_a_1"
	check("M4-H force attack a1", GameManager.force_candle_attack(TARGET, 12.0, EXPEL_REQUIRED), true)
	for _i in EXPEL_REQUIRED:
		check("M4-H expel click", GameManager.expel_black_hand(TARGET), true)
	check("M4-H attack cleared", GameManager.active_attack.is_empty(), true)
	check("M4-H candle still lit", GameManager.candles[TARGET]["lit"], true)
	print_snapshot("M4-H")


func _wait_seconds(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _on_attack_resolved(target_id: String, _attack_type: String) -> void:
	_last_attack_resolved = target_id
	print("  [事件] attack_resolved: %s" % target_id)
	_refresh_hud()


func _refresh_hud() -> void:
	var snapshot: Dictionary = GameManager.get_snapshot()
	var black_hand: Dictionary = snapshot["black_hand"]
	var attack_text := "无"
	if not snapshot["active_attack"].is_empty():
		attack_text = "%s (%s) %.1fs" % [
			snapshot["active_attack"]["target_id"],
			snapshot["active_attack"]["type"],
			snapshot["attack_timer"],
		]
	var expel_text := "无"
	if not black_hand.is_empty():
		expel_text = "%s %d/%d" % [
			black_hand["target_id"],
			black_hand["expel_progress"],
			black_hand["expel_required"],
		]

	_hud_label.text = """M4 测试 HUD
阶段: %d  SAN: %.1f/%.0f  灭烛: %d
黑手: %s  袭击: %s

a0烛: %s  a1烛: %s
b0烛: %s  b1烛: %s
bow0烛: %s  bow1烛: %s
(* = 黑手正在袭击该烛)

E=驱赶被袭烛 1/2=强制袭击第1/2烛 L=点烛 3/4/5/6=切房间 R=重置""" % [
		snapshot["phase"],
		snapshot["san"],
		snapshot["san_max"],
		snapshot["unlit_candle_count"],
		expel_text,
		attack_text,
		_lit_text(snapshot["candles"]["candle_room_a_0"]["lit"], "candle_room_a_0", black_hand),
		_lit_text(snapshot["candles"]["candle_room_a_1"]["lit"], "candle_room_a_1", black_hand),
		_lit_text(snapshot["candles"]["candle_room_b_0"]["lit"], "candle_room_b_0", black_hand),
		_lit_text(snapshot["candles"]["candle_room_b_1"]["lit"], "candle_room_b_1", black_hand),
		_lit_text(snapshot["candles"]["candle_bow_room_0"]["lit"], "candle_bow_room_0", black_hand),
		_lit_text(snapshot["candles"]["candle_bow_room_1"]["lit"], "candle_bow_room_1", black_hand),
	]


func _lit_text(lit: bool, candle_id: String, black_hand: Dictionary) -> String:
	var state := "亮" if lit else "灭"
	if not black_hand.is_empty() and black_hand.get("target_id", "") == candle_id:
		return "%s*" % state
	return state


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("  [OK] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])


func print_snapshot(tag: String) -> void:
	print("  [%s] %s" % [tag, JSON.stringify(GameManager.get_snapshot())])
