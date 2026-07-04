## M1 验收：修锚胜利、SAN 变化、SAN 归零失败。
## 运行：打开 gameplay/m1_test.tscn，按 F6。
## 左上角 HUD 实时显示 SAN / 锚进度 / 阶段等。
## 自动测试结束后可手动：
##   按住 SPACE = 修锚 | 1 = 灭烛 | 2 = 破窗 | R = 重置
extends Node

const LOSE_WAIT_SECONDS := 18.0

@export var skip_auto_tests: bool = false

@onready var _hud_label: Label = $CanvasLayer/HUD/Label

var _passed := 0
var _failed := 0
var _manual_enabled := false
var _last_game_over_result := ""


func _ready() -> void:
	GameManager.san_changed.connect(func(_c, _m): _refresh_hud())
	GameManager.anchor_progress_changed.connect(func(_v): _refresh_hud())
	GameManager.phase_changed.connect(func(_p): _refresh_hud())
	GameManager.candle_changed.connect(func(_id, _lit): _refresh_hud())
	GameManager.window_changed.connect(func(_id, _d, _b): _refresh_hud())
	GameManager.game_over.connect(_on_game_over)
	_refresh_hud()

	await get_tree().process_frame
	if skip_auto_tests:
		_start_manual_mode("已跳过自动测试")
		return

	print("========== M1 自动验收开始 ==========")
	await _run_win_test()
	await _run_lose_test()
	print("========== M1 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	if _failed == 0:
		_start_manual_mode("M1 全部通过，进入手动测试")
	else:
		push_error("M1 自动验收失败，请检查上方 [FAIL]")
		_start_manual_mode("自动测试有失败项，仍可手动试")


func _start_manual_mode(message: String) -> void:
	print("========== %s ==========" % message)
	print("SPACE=修锚 | 1=灭烛 | 2=破窗 | R=重置")
	_manual_enabled = true
	_refresh_hud()


func _process(delta: float) -> void:
	_refresh_hud()
	if not _manual_enabled or GameManager.is_game_over:
		return
	if Input.is_key_pressed(KEY_SPACE):
		GameManager.repair_anchor(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _manual_enabled:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			GameManager.reset_game()
			_last_game_over_result = ""
			print("[手动] 已重置")
		KEY_1:
			var candle_id := GameManager.get_primary_lit_candle_in_view()
			if candle_id.is_empty():
				print("[手动] 当前视角无已点燃蜡烛")
			elif GameManager.extinguish_candle(candle_id):
				print("[手动] 熄灭 %s" % candle_id)
			else:
				print("[手动] 无法熄灭 %s" % candle_id)
		KEY_2:
			var window_id := GameManager.get_primary_window_in_view()
			if window_id.is_empty():
				print("[手动] 当前视角无可操作窗户")
			elif GameManager.break_window(window_id):
				print("[手动] 打碎 %s" % window_id)
			else:
				print("[手动] 无法打碎 %s" % window_id)


func _refresh_hud() -> void:
	var candle_id := GameManager.get_primary_candle_in_view()
	var candle_lit: bool = GameManager.candles[candle_id]["lit"] if not candle_id.is_empty() else true
	var window_id := GameManager.get_primary_window_in_view()
	var window: Dictionary = GameManager.windows[window_id] if not window_id.is_empty() else {}
	var san_rate: String = _describe_san_rate()

	_hud_label.text = """M1 测试 HUD
SAN: %.1f / %.0f  (%s)
锚进度: %.0f%% (%.1f / %.0f s)
阶段: %d  房间: %s  视角: %s
当前烛: %s (%s)
当前窗: %s (%.0f 破碎:%s)
游戏结束: %s %s

操作: SPACE修锚 | 1灭当前烛 | 2破当前窗 | R重置
提示: 全蜡烛亮 SAN↑+1.5/s | Phase2灭烛 SAN↓-5/s""" % [
		GameManager.san,
		GameManager.san_max,
		san_rate,
		GameManager.anchor_progress / GameManager.anchor_target * 100.0,
		GameManager.anchor_progress,
		GameManager.anchor_target,
		GameManager.phase,
		GameManager.current_room_id,
		GameManager.current_view_id,
		candle_id if not candle_id.is_empty() else "无",
		"亮" if candle_lit else "灭",
		window_id if not window_id.is_empty() else "无",
		window.get("durability", 0.0),
		"是" if window.get("broken", false) else "否",
		"是" if GameManager.is_game_over else "否",
		("(%s)" % _last_game_over_result) if _last_game_over_result else "",
	]


func _describe_san_rate() -> String:
	if GameManager.is_game_over:
		return "已结束"
	var all_lit := true
	for candle in GameManager.candles.values():
		if not candle["lit"]:
			all_lit = false
			break
	if GameManager.phase == GameManager.PHASE_CANDLE:
		var unlit: int = GameManager.count_unlit_candles()
		if unlit > 0:
			return "下降 -%.0f/s" % (5.0 * unlit)
	if all_lit:
		return "恢复 +1.5/s"
	return "持平"


func _run_win_test() -> void:
	print("\n--- M1-A: 修锚 60s -> 胜利 ---")
	GameManager.reset_game()
	_last_game_over_result = ""

	for _step in 65:
		if GameManager.is_game_over:
			break
		GameManager.repair_anchor(1.0)
		await get_tree().process_frame

	check("M1-A game over", GameManager.is_game_over, true)
	check("M1-A win", _last_game_over_result, "win")
	check_approx("M1-A anchor full", GameManager.anchor_progress, GameManager.anchor_target)
	print_snapshot("M1-A")


func _run_lose_test() -> void:
	print("\n--- M1-B: Phase2 灭烛 -> SAN 归零 ---")
	GameManager.reset_game()
	_last_game_over_result = ""
	check("M1-B break window", GameManager.break_window("window_room_a_0"), true)
	check("M1-B extinguish candle", GameManager.extinguish_candle("candle_room_a_0"), true)

	var elapsed := 0.0
	while elapsed < LOSE_WAIT_SECONDS and not GameManager.is_game_over:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	check("M1-B game over", GameManager.is_game_over, true)
	check("M1-B lose", _last_game_over_result, "lose")
	check_approx("M1-B san zero", GameManager.san, 0.0)
	print_snapshot("M1-B")


func _on_game_over(result: String) -> void:
	_last_game_over_result = result
	print("  [事件] game_over: %s" % result)
	_refresh_hud()


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("  [OK] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])


func check_approx(label: String, actual: float, expected: float, tolerance: float = 0.2) -> void:
	if absf(actual - expected) <= tolerance:
		_passed += 1
		print("  [OK] %s (%.2f ≈ %.2f)" % [label, actual, expected])
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %.2f ± %.2f, got %.2f" % [label, expected, tolerance, actual])


func print_snapshot(tag: String) -> void:
	print("  [%s] %s" % [tag, JSON.stringify(GameManager.get_snapshot())])
