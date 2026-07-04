## M2 验收：房间切换、修窗、点蜡烛、状态快照。
## 运行：打开 gameplay/m2_test.tscn，按 F6。
extends Node

const REPAIR_STEPS := 12
const REPAIR_DELTA := 1.0
const WINDOW_REPAIR_RATE := 4.0

@export var skip_auto_tests: bool = false

@onready var _hud_label: Label = $CanvasLayer/HUD/Label

var _passed := 0
var _failed := 0
var _manual_enabled := false


func _ready() -> void:
	GameManager.room_changed.connect(func(_id): _refresh_hud())
	GameManager.window_changed.connect(func(_id, _d, _b): _refresh_hud())
	GameManager.candle_changed.connect(func(_id, _lit): _refresh_hud())
	GameManager.san_changed.connect(func(_c, _m): _refresh_hud())
	_refresh_hud()

	await get_tree().process_frame
	if skip_auto_tests:
		_start_manual_mode("已跳过自动测试")
		return

	print("========== M2 自动验收开始 ==========")
	await _run_switch_room_test()
	await _run_repair_window_test()
	await _run_light_candle_test()
	await _run_broken_window_test()
	await _run_bow_view_test()
	print("========== M2 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	if _failed == 0:
		_start_manual_mode("M2 全部通过，进入手动测试")
	else:
		push_error("M2 自动验收失败，请检查上方 [FAIL]")
		_start_manual_mode("自动测试有失败项，仍可手动试")


func _start_manual_mode(message: String) -> void:
	GameManager.reset_game()
	_prepare_manual_window()
	print("========== %s ==========" % message)
	print("3=船长室 4=休息室 5/6=走廊两视角 | 2=损伤当前窗 | W=修当前窗 | L=点当前烛 | 1=灭当前烛 | R=重置")
	_manual_enabled = true
	_refresh_hud()


func _prepare_manual_window() -> void:
	var window_id := GameManager.get_primary_window_in_view()
	if window_id.is_empty():
		return
	GameManager.windows[window_id]["durability"] = 60


func _process(delta: float) -> void:
	_refresh_hud()
	if not _manual_enabled or GameManager.is_game_over:
		return
	if Input.is_key_pressed(KEY_W):
		var window_id := GameManager.get_primary_window_in_view()
		if not window_id.is_empty():
			GameManager.repair_window(window_id, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _manual_enabled:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			GameManager.reset_game()
			_prepare_manual_window()
			print("[手动] 已重置（当前视角首窗耐久 60 便于试修窗）")
		KEY_2:
			_try_chip_current_window()
		KEY_3:
			GameManager.switch_room("room_a")
			print("[手动] 切换到 room_a（船长室）")
		KEY_4:
			GameManager.switch_room("room_b")
			print("[手动] 切换到 room_b（休息室）")
		KEY_5:
			GameManager.switch_room("bow_room_0")
			print("[手动] 走廊视角0（船长室方向）")
		KEY_6:
			GameManager.switch_room("bow_room_1")
			print("[手动] 走廊视角1（休息室方向）")
		KEY_L:
			_try_light_current_candle()
		KEY_1:
			_try_extinguish_current_candle()


func _try_chip_current_window() -> void:
	var window_id := GameManager.get_primary_window_in_view()
	if window_id.is_empty():
		print("[手动] 当前视角无可操作窗户")
		return
	if GameManager.chip_window_damage(window_id, 15.0):
		print("[手动] %s 受损 -15" % window_id)
	else:
		print("[手动] 无法损伤 %s" % window_id)


func _try_light_current_candle() -> void:
	var candle_id := GameManager.get_primary_candle_in_view(true)
	if candle_id.is_empty():
		print("[手动] 当前视角无蜡烛")
		return
	if GameManager.light_candle(candle_id):
		print("[手动] 点亮 %s" % candle_id)
	else:
		print("[手动] 无法点亮 %s（需先熄灭或切换视角）" % candle_id)


func _try_extinguish_current_candle() -> void:
	var candle_id := GameManager.get_primary_lit_candle_in_view()
	if candle_id.is_empty():
		print("[手动] 当前视角无已点燃蜡烛")
		return
	if GameManager.extinguish_candle(candle_id):
		print("[手动] 熄灭 %s" % candle_id)
	else:
		print("[手动] 无法熄灭 %s" % candle_id)


func _run_switch_room_test() -> void:
	print("\n--- M2-A: 切换房间 ---")
	GameManager.reset_game()

	GameManager.switch_room("room_b")
	check("M2-A room_b", GameManager.current_room_id, "room_b")

	GameManager.switch_room("bow_room_0")
	check("M2-A bow_room logical", GameManager.current_room_id, "bow_room")
	check("M2-A bow_room_0 view", GameManager.current_view_id, "bow_room_0")

	GameManager.switch_room("bow_room_1")
	check("M2-A bow_room_1 view", GameManager.current_view_id, "bow_room_1")

	GameManager.switch_room("room_a")
	check("M2-A room_a", GameManager.current_room_id, "room_a")
	print_snapshot("M2-A")


func _run_repair_window_test() -> void:
	print("\n--- M2-B: 修窗耐久上升 ---")
	GameManager.reset_game()
	var start_dur: int = 50
	GameManager.windows["window_room_a_0"]["durability"] = start_dur

	for _step in REPAIR_STEPS:
		GameManager.repair_window("window_room_a_0", REPAIR_DELTA)

	var end_dur: int = GameManager.windows["window_room_a_0"]["durability"]
	check("M2-B durability increased", end_dur > start_dur, true)
	check_approx("M2-B expected durability", float(end_dur), 50.0 + REPAIR_STEPS * REPAIR_DELTA * WINDOW_REPAIR_RATE, 0.5)
	print_snapshot("M2-B")


func _run_light_candle_test() -> void:
	print("\n--- M2-C: 点蜡烛 ---")
	GameManager.reset_game()
	check("M2-C extinguished", GameManager.extinguish_candle("candle_room_a_1"), true)
	check("M2-C candle unlit", GameManager.candles["candle_room_a_1"]["lit"], false)

	check("M2-C relit", GameManager.light_candle("candle_room_a_1"), true)
	check("M2-C candle lit", GameManager.candles["candle_room_a_1"]["lit"], true)
	print_snapshot("M2-C")


func _run_broken_window_test() -> void:
	print("\n--- M2-D: 破碎窗户不可修 ---")
	GameManager.reset_game()
	check("M2-D break window", GameManager.break_window("window_room_a_0"), true)
	check("M2-D can_repair false", GameManager.can_repair_window("window_room_a_0"), false)

	for _step in 5:
		GameManager.repair_window("window_room_a_0", 1.0)

	check("M2-D still broken", GameManager.windows["window_room_a_0"]["broken"], true)
	check("M2-D durability zero", GameManager.windows["window_room_a_0"]["durability"], 0)
	print_snapshot("M2-D")


func _run_bow_view_test() -> void:
	print("\n--- M2-E: 走廊双视角仅可操作当前视角物体 ---")
	GameManager.reset_game()
	GameManager.windows["window_bow_room_0"]["durability"] = 50

	GameManager.switch_room("bow_room_0")
	check("M2-E wrong view cannot repair bow window", GameManager.can_repair_window("window_bow_room_0"), false)

	GameManager.switch_room("bow_room_1")
	check("M2-E correct view can repair bow window", GameManager.can_repair_window("window_bow_room_0"), true)
	check("M2-E bow window repaired", GameManager.repair_window("window_bow_room_0", 1.0), true)
	check("M2-E durability increased", GameManager.windows["window_bow_room_0"]["durability"] > 50.0, true)
	print_snapshot("M2-E")


func _refresh_hud() -> void:
	var snapshot: Dictionary = GameManager.get_snapshot()
	var windows: Dictionary = snapshot["windows"]
	var candles: Dictionary = snapshot["candles"]
	var current_window := GameManager.get_primary_window_in_view()
	var current_candle := GameManager.get_primary_candle_in_view()
	var unlit_candle := GameManager.get_primary_candle_in_view(true)

	_hud_label.text = """M2 测试 HUD
逻辑房间: %s  视角: %s  阶段: %d  SAN: %.1f/%.0f  灭烛:%d

窗户 a0:%.0f%s a1:%.0f%s | b0:%.0f%s b1:%.0f%s | bow0:%.0f%s
蜡烛 a0:%s a1:%s | b0:%s b1:%s | bow0:%s bow1:%s

3=船长室 4=休息室 5/6=走廊 | 2损伤 W修 L点烛 1灭烛 R重置
当前窗: %s
当前烛: %s  可点亮: %s""" % [
		snapshot["current_room_id"],
		snapshot["current_view_id"],
		snapshot["phase"],
		snapshot["san"],
		snapshot["san_max"],
		snapshot["unlit_candle_count"],
		windows["window_room_a_0"]["durability"], _broken_text(windows["window_room_a_0"]["broken"]),
		windows["window_room_a_1"]["durability"], _broken_text(windows["window_room_a_1"]["broken"]),
		windows["window_room_b_0"]["durability"], _broken_text(windows["window_room_b_0"]["broken"]),
		windows["window_room_b_1"]["durability"], _broken_text(windows["window_room_b_1"]["broken"]),
		windows["window_bow_room_0"]["durability"], _broken_text(windows["window_bow_room_0"]["broken"]),
		_lit_text(candles["candle_room_a_0"]["lit"]),
		_lit_text(candles["candle_room_a_1"]["lit"]),
		_lit_text(candles["candle_room_b_0"]["lit"]),
		_lit_text(candles["candle_room_b_1"]["lit"]),
		_lit_text(candles["candle_bow_room_0"]["lit"]),
		_lit_text(candles["candle_bow_room_1"]["lit"]),
		_current_window_hint(current_window),
		current_candle if not current_candle.is_empty() else "无",
		unlit_candle if not unlit_candle.is_empty() else "无",
	]


func _current_window_hint(window_id: String) -> String:
	if window_id.is_empty():
		return "无"
	return "%s (%s)" % [window_id, _repair_hint(window_id)]


func _broken_text(broken: bool) -> String:
	return "[碎]" if broken else ""


func _lit_text(lit: bool) -> String:
	return "亮" if lit else "灭"


func _repair_hint(window_id: String) -> String:
	var window: Dictionary = GameManager.windows[window_id]
	if window["broken"]:
		return "已碎，不可修"
	if window["durability"] >= GameManager.WINDOW_DURABILITY_MAX:
		return "已满，不可修"
	if GameManager.can_repair_window(window_id):
		return "可修"
	return "不可修"


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("  [OK] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])


func check_approx(label: String, actual: float, expected: float, tolerance: float = 0.5) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  [OK] %s (%.2f ≈ %.2f)" % [label, actual, expected])
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %.2f ± %.2f, got %.2f" % [label, expected, tolerance, actual])


func print_snapshot(tag: String) -> void:
	print("  [%s] %s" % [tag, JSON.stringify(GameManager.get_snapshot())])
