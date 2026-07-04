## Mock 驱动：用代码模拟玩家行为与怪物事件，验证进程/事件/状态规则。
## 运行：在 Godot 中打开 mock/mock_main.tscn，按 F6（运行当前场景）。
extends Node

const STEP := 0.1
const FIX_WINDOW_RATE := 4.0
const FLOAT_EPS := 0.15

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	print("========== CiGA2026 Mock 开始 ==========")
	run_scenario_phase1_fix_window()
	run_scenario_window_break_phase2()
	run_scenario_candle_extinguish_failed()
	run_scenario_expel_black_hand()
	run_scenario_repair_victory()
	run_scenario_san_defeat()
	run_scenario_light_candle()
	run_scenario_attack_expires_naturally()
	run_scenario_broken_window_cannot_fix()
	_finish()


func _finish() -> void:
	print("========== Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	if _failed > 0:
		print("========== Mock 失败，请向上查看 [FAIL] ==========")
	else:
		print("========== Mock 全部通过 ==========")

	# 编辑器内 F6 调试不自动退出，避免误以为异常中断；命令行/CI 再 quit
	if OS.has_feature("editor"):
		print("（编辑器模式：进程保持运行，输出面板可继续查看）")
		return

	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit()


func reset_game() -> void:
	GameProcessManager.reset()
	RoomStateManager.reset_to_default()
	EventManager.reset()


func simulate_time(seconds: float, action: Callable = Callable()) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not GameProcessManager.is_game_over:
		var delta := minf(STEP, seconds - elapsed)
		if action.is_valid():
			action.call(delta)
		EventManager.simulate_step(delta)
		elapsed += delta


func mock_switch_camera(room_id: String) -> void:
	RoomStateManager.set_current_room(room_id)
	print("  [行为] switch_camera -> %s" % room_id)


func mock_fix_window(window_id: String, duration: float, send_resolve: bool = true) -> void:
	print("  [行为] fix_window %s, %.1fs" % [window_id, duration])

	var fix_action := func(delta: float) -> void:
		if RoomStateManager.can_fix_window(window_id):
			RoomStateManager.modify_window_durability(window_id, FIX_WINDOW_RATE * delta)

	simulate_time(duration, fix_action)
	if send_resolve:
		EventManager.on_behavior_message(BehaviorMessage.create("fix_window", window_id, true))


func mock_expel_black_hand(candle_id: String) -> void:
	print("  [行为] expel_black_hand -> %s" % candle_id)
	EventManager.on_behavior_message(BehaviorMessage.create("expel_black_hand", candle_id, true))


func mock_light_candle(candle_id: String) -> void:
	print("  [行为] light_candle -> %s" % candle_id)
	RoomStateManager.set_candle_lit(candle_id, true)
	EventManager.on_behavior_message(BehaviorMessage.create("light_candle", candle_id, true))


func mock_repair_anchor(duration: float) -> void:
	print("  [行为] repair_anchor %.1fs" % duration)
	var repair_action := func(delta: float) -> void:
		GameProcessManager.add_repair_time(delta)
	simulate_time(duration, repair_action)


func run_scenario_phase1_fix_window() -> void:
	print("\n--- 剧本 A: Phase1 修窗化解窗户攻击 ---")
	reset_game()

	EventManager.trigger_window_attack("window_room_a_0", 10.0)
	simulate_time(1.0)
	mock_switch_camera("room_a")
	mock_fix_window("window_room_a_0", 5.0)

	var window := RoomStateManager.get_window_state("window_room_a_0")
	check("A phase", GameProcessManager.phase, GameProcessManager.Phase.ONE)
	check("A attack resolved", EventManager.get_window_attack_state(), EventBase.State.RESOLVED)
	check("A window not broken", window["is_broken"], false)
	check("A window damaged", window["durability"] < 100, true)
	check_approx("A window durability", window["durability"], 90, 2.0)
	check("A not game over", GameProcessManager.is_game_over, false)
	print_snapshot("A 结束")


func run_scenario_window_break_phase2() -> void:
	print("\n--- 剧本 B: 窗户耐久归零 -> Phase2, san_max=80 ---")
	reset_game()

	RoomStateManager.set_window_durability("window_room_a_0", 0)

	check("B phase", GameProcessManager.phase, GameProcessManager.Phase.TWO)
	check("B san_max", GameProcessManager.san_max, 80.0)
	check_approx("B san clamped", GameProcessManager.san_current, 80.0)
	check("B window broken", RoomStateManager.get_window_state("window_room_a_0")["is_broken"], true)
	print_snapshot("B 结束")


func run_scenario_candle_extinguish_failed() -> void:
	print("\n--- 剧本 C: Phase2 黑手未驱逐 -> 蜡烛熄灭 ---")
	reset_game()
	RoomStateManager.set_window_durability("window_room_a_0", 0)

	EventManager.trigger_candle_extinguish("candle_room_b_1")
	simulate_time(16.0)

	var candle := RoomStateManager.get_candle_state("candle_room_b_1")
	check("C phase", GameProcessManager.phase, GameProcessManager.Phase.TWO)
	check("C event failed", EventManager.get_candle_extinguish_state(), EventBase.State.FAILED)
	check("C candle unlit", candle["lit"], false)
	check("C san dropped", GameProcessManager.san_current < 80.0, true)
	print_snapshot("C 结束")


func run_scenario_expel_black_hand() -> void:
	print("\n--- 剧本 D: Phase2 驱逐黑手化解事件 ---")
	reset_game()
	RoomStateManager.set_window_durability("window_room_a_0", 0)

	EventManager.trigger_candle_extinguish("candle_room_b_0")
	simulate_time(5.0)
	mock_switch_camera("room_b")
	mock_expel_black_hand("candle_room_b_0")

	check("D event resolved", EventManager.get_candle_extinguish_state(), EventBase.State.RESOLVED)
	check("D candle still lit", RoomStateManager.get_candle_state("candle_room_b_0")["lit"], true)
	print_snapshot("D 结束")


func run_scenario_repair_victory() -> void:
	print("\n--- 剧本 E: 修理锚 60s -> 胜利 ---")
	reset_game()

	mock_switch_camera("room_bow")
	mock_repair_anchor(60.0)

	check("E victory", GameProcessManager.game_over_reason, GameProcessManager.GameOverReason.VICTORY)
	check("E repair done", GameProcessManager.repair_time_accum >= 60.0, true)
	print_snapshot("E 结束")


func run_scenario_san_defeat() -> void:
	print("\n--- 剧本 F: SAN 归零 -> 失败 ---")
	reset_game()
	RoomStateManager.set_window_durability("window_room_a_0", 0)
	RoomStateManager.set_candle_lit("candle_room_a_0", false)

	simulate_time(17.0)

	check("F is game over", GameProcessManager.is_game_over, true)
	check("F defeat", GameProcessManager.game_over_reason, GameProcessManager.GameOverReason.DEFEAT)
	check_approx("F san zero", GameProcessManager.san_current, 0.0)
	print_snapshot("F 结束")


func run_scenario_light_candle() -> void:
	print("\n--- 剧本 G: light_candle 化解事件 / 重燃后 SAN 恢复 ---")
	reset_game()
	RoomStateManager.set_window_durability("window_room_a_0", 0)

	EventManager.trigger_candle_extinguish("candle_room_b_1")
	simulate_time(5.0)
	mock_light_candle("candle_room_b_1")

	check("G1 event resolved", EventManager.get_candle_extinguish_state(), EventBase.State.RESOLVED)
	check("G1 candle lit", RoomStateManager.get_candle_state("candle_room_b_1")["lit"], true)

	var san_before_recovery := GameProcessManager.san_current
	simulate_time(5.0)
	check("G1 all candles lit", RoomStateManager.all_candles_lit(), true)
	check(
		"G1 san stable",
		GameProcessManager.san_current >= san_before_recovery - FLOAT_EPS,
		true
	)

	reset_game()
	RoomStateManager.set_window_durability("window_room_a_0", 0)
	EventManager.trigger_candle_extinguish("candle_room_a_1")
	simulate_time(16.0)

	var san_after_fail := GameProcessManager.san_current
	check("G2 candle unlit after fail", RoomStateManager.get_candle_state("candle_room_a_1")["lit"], false)

	mock_light_candle("candle_room_a_1")
	simulate_time(3.0)

	check("G2 candle relit", RoomStateManager.get_candle_state("candle_room_a_1")["lit"], true)
	check_approx(
		"G2 san recovers after relight",
		GameProcessManager.san_current,
		san_after_fail + 3.0 * 1.5,
		0.6
	)
	print_snapshot("G 结束")


func run_scenario_attack_expires_naturally() -> void:
	print("\n--- 剧本 H: 攻窗超时未修 -> 怪物自行离开 ---")
	reset_game()

	EventManager.trigger_window_attack("window_room_a_1", 10.0)
	simulate_time(11.0)

	check("H attack resolved", EventManager.get_window_attack_state(), EventBase.State.RESOLVED)
	check("H no active events", EventManager.get_active_event_ids().is_empty(), true)
	check("H window damaged", RoomStateManager.get_window_state("window_room_a_1")["durability"] < 100, true)
	check_approx("H window durability", RoomStateManager.get_window_state("window_room_a_1")["durability"], 50, 2.0)
	print_snapshot("H 结束")


func run_scenario_broken_window_cannot_fix() -> void:
	print("\n--- 剧本 I: 破碎窗户不可再修 ---")
	reset_game()

	RoomStateManager.set_window_durability("window_room_a_0", 0)
	check("I can_fix false", RoomStateManager.can_fix_window("window_room_a_0"), false)

	mock_fix_window("window_room_a_0", 3.0)

	var window := RoomStateManager.get_window_state("window_room_a_0")
	check("I still broken", window["is_broken"], true)
	check("I durability zero", window["durability"], 0)
	print_snapshot("I 结束")


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("  [OK] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])


func check_approx(label: String, actual: float, expected: float, tolerance: float = FLOAT_EPS) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  [OK] %s (%.2f ≈ %.2f)" % [label, actual, expected])
	else:
		_failed += 1
		push_error(
			"  [FAIL] %s: expected %.2f ± %.2f, got %.2f" % [label, expected, tolerance, actual]
		)


func print_snapshot(tag: String) -> void:
	var snapshot := GameProcessManager.get_snapshot()
	print(
		"  [%s] phase=%s san=%.1f/%.0f room=%s events=%s game_over=%s" % [
			tag,
			str(snapshot["phase"]),
			snapshot["san"],
			snapshot["san_max"],
			snapshot["current_room_id"],
			str(snapshot["active_events"]),
			str(snapshot["is_game_over"]),
		]
	)
