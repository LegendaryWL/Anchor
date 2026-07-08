## M3 验收：Phase 1 破窗袭击、修窗化解、SAN 损耗。
## 运行：打开 gameplay/m3_test.tscn，按 F6。
extends Node

const ATTACK_TARGET := "window_room_a_0"
const ATTACK_WAIT_SEC := 15.0
const DAMAGE_WAIT_SEC := 1.5
const SAN_WAIT_SEC := 2.0

@export var skip_auto_tests: bool = false

@onready var _hud_label: Label = $CanvasLayer/HUD/Label

var _passed := 0
var _failed := 0
var _manual_enabled := false
var _last_attack_started := ""
var _last_attack_resolved := ""


func _ready() -> void:
	GameManager.attack_started.connect(_on_attack_started)
	GameManager.attack_resolved.connect(_on_attack_resolved)
	GameManager.window_changed.connect(func(_id, _d, _b): _refresh_hud())
	GameManager.san_changed.connect(func(_c, _m): _refresh_hud())
	GameManager.phase_changed.connect(func(_p): _refresh_hud())
	_refresh_hud()

	await get_tree().process_frame
	if skip_auto_tests:
		_start_manual_mode("已跳过自动测试")
		return

	print("========== M3 自动验收开始 ==========")
	await _run_random_attack_test()
	await _run_attack_damage_test()
	await _run_repair_continues_test()
	await _run_san_drain_test()
	await _run_skip_broken_window_test()
	await _run_break_clears_attack_test()
	print("========== M3 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	if _failed == 0:
		_start_manual_mode("M3 全部通过，进入手动测试")
	else:
		push_error("M3 自动验收失败，请检查上方 [FAIL]")
		_start_manual_mode("自动测试有失败项，仍可手动试")


func _start_manual_mode(message: String) -> void:
	_reset_for_m3()
	print("========== %s ==========" % message)
	print("袭击已开启 | W=修当前窗 | T=强制袭击当前窗 | 3/4/5/6=切房间 | R=重置")
	_manual_enabled = true
	_refresh_hud()


func _reset_for_m3() -> void:
	GameManager.reset_game()
	GameManager.set_attacks_enabled(true)
	GameManager.skip_attack_cooldown()
	_last_attack_started = ""
	_last_attack_resolved = ""


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
			_reset_for_m3()
			print("[手动] 已重置并开启袭击")
		KEY_T:
			var window_id := GameManager.get_primary_window_in_view()
			if window_id.is_empty():
				print("[手动] 当前视角无窗户")
			elif GameManager.force_window_attack(window_id, 12.0):
				print("[手动] 强制袭击 %s" % window_id)
			else:
				print("[手动] 无法袭击 %s（可能已有袭击进行中）" % window_id)
		KEY_3:
			GameManager.switch_room("room_a")
		KEY_4:
			GameManager.switch_room("room_b")
		KEY_5:
			GameManager.switch_room("bow_room_0")
		KEY_6:
			GameManager.switch_room("bow_room_1")


func _run_random_attack_test() -> void:
	print("\n--- M3-A: 随机袭击启动 ---")
	_reset_for_m3()
	var target := await _wait_for_window_attack(ATTACK_WAIT_SEC)
	check("M3-A attack started", not target.is_empty(), true)
	check("M3-A valid window target", GameManager.windows.has(target), true)
	check("M3-A target not broken", GameManager.windows[target]["broken"], false)
	print_snapshot("M3-A")


func _run_attack_damage_test() -> void:
	print("\n--- M3-B: 袭击降低耐久 ---")
	_reset_for_m3()
	var start_dur: int = GameManager.windows[ATTACK_TARGET]["durability"]
	check("M3-B force attack", GameManager.force_window_attack(ATTACK_TARGET, 12.0), true)
	await _wait_seconds(DAMAGE_WAIT_SEC)
	var end_dur: int = GameManager.windows[ATTACK_TARGET]["durability"]
	check("M3-B durability decreased", end_dur < start_dur, true)
	print_snapshot("M3-B")


func _run_repair_continues_test() -> void:
	print("\n--- M3-C: 修窗时袭击继续 ---")
	_reset_for_m3()
	check("M3-C force attack", GameManager.force_window_attack(ATTACK_TARGET, 12.0), true)
	check("M3-C under attack", GameManager.is_window_under_attack(ATTACK_TARGET), true)
	check("M3-C repair while attacked", GameManager.repair_window(ATTACK_TARGET, 1.0), true)
	check("M3-C attack still active", GameManager.is_window_under_attack(ATTACK_TARGET), true)
	check("M3-C no resolved signal", _last_attack_resolved, "")
	print_snapshot("M3-C")


func _run_san_drain_test() -> void:
	print("\n--- M3-D: 袭击期间 SAN 下降 ---")
	_reset_for_m3()
	_extinguish_all_candles()
	GameManager.san = 100.0
	check("M3-D force attack", GameManager.force_window_attack(ATTACK_TARGET, 12.0), true)
	var start_san: float = GameManager.san
	await _wait_seconds(SAN_WAIT_SEC)
	check("M3-D san decreased", GameManager.san < start_san, true)
	print_snapshot("M3-D")


func _run_skip_broken_window_test() -> void:
	print("\n--- M3-E: 已碎窗户不会被选为目标 ---")
	_reset_for_m3()
	GameManager.windows[ATTACK_TARGET]["durability"] = 0
	GameManager.windows[ATTACK_TARGET]["broken"] = true
	for _attempt in 8:
		GameManager.active_attack = {}
		GameManager.skip_attack_cooldown()
		var target := await _wait_for_window_attack(3.0)
		if target.is_empty():
			continue
		check("M3-E skip broken window", target != ATTACK_TARGET, true)
	print_snapshot("M3-E")


func _run_break_clears_attack_test() -> void:
	print("\n--- M3-F: 袭击打碎窗户后事件结束并进 Phase 2 ---")
	_reset_for_m3()
	GameManager.windows[ATTACK_TARGET]["durability"] = 25
	GameManager.windows[ATTACK_TARGET]["_durability_frac"] = 0.0
	check("M3-F force attack", GameManager.force_window_attack(ATTACK_TARGET, 30.0), true)
	await _wait_until(func(): return GameManager.phase == GameManager.PHASE_CANDLE)
	check("M3-F entered phase 2", GameManager.phase, GameManager.PHASE_CANDLE)
	check("M3-F attack cleared after break", GameManager.active_attack.is_empty(), true)
	check("M3-F window broken", GameManager.windows[ATTACK_TARGET]["broken"], true)
	print_snapshot("M3-F")


func _wait_for_window_attack(timeout_sec: float) -> String:
	var elapsed := 0.0
	while elapsed < timeout_sec:
		if (
			not GameManager.active_attack.is_empty()
			and GameManager.active_attack.get("type") == "window"
		):
			return GameManager.active_attack["target_id"]
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return ""


func _wait_seconds(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _wait_until(condition: Callable) -> void:
	while not condition.call():
		await get_tree().process_frame


func _extinguish_all_candles() -> void:
	for candle_id in GameManager.candles.keys():
		GameManager.candles[candle_id]["lit"] = false


func _on_attack_started(target_id: String, _attack_type: String) -> void:
	_last_attack_started = target_id
	print("  [事件] attack_started: %s" % target_id)
	_refresh_hud()


func _on_attack_resolved(target_id: String, _attack_type: String) -> void:
	_last_attack_resolved = target_id
	print("  [事件] attack_resolved: %s" % target_id)
	_refresh_hud()


func _refresh_hud() -> void:
	var snapshot: Dictionary = GameManager.get_snapshot()
	var windows: Dictionary = snapshot["windows"]
	var attack_text := "无"
	var attack_target := GameManager.get_active_attack_target()
	if not snapshot["active_attack"].is_empty():
		attack_text = "%s (%s) %.1fs" % [
			snapshot["active_attack"]["target_id"],
			snapshot["active_attack"]["type"],
			snapshot["attack_timer"],
		]

	_hud_label.text = """M3 测试 HUD
阶段: %d  SAN: %.1f/%.0f  游戏时间: %.0fs
袭击: %s  下次: %.1fs  开启: %s

窗户（* = 正在被袭击，显示含小数余量）
%s
%s
%s
%s
%s

W=修窗 T=强制袭击 3/4/5/6=切房间 R=重置""" % [
		snapshot["phase"],
		snapshot["san"],
		snapshot["san_max"],
		snapshot["game_time"],
		attack_text,
		snapshot["next_attack_timer"],
		"是" if snapshot["attacks_enabled"] else "否",
		_window_hud_line("window_room_a_0", windows, attack_target),
		_window_hud_line("window_room_a_1", windows, attack_target),
		_window_hud_line("window_room_b_0", windows, attack_target),
		_window_hud_line("window_room_b_1", windows, attack_target),
		_window_hud_line("window_bow_room_0", windows, attack_target),
	]


func _window_hud_line(window_id: String, windows: Dictionary, attack_target: String) -> String:
	var window: Dictionary = windows[window_id]
	var marker := "* " if window_id == attack_target else "  "
	var broken := " [碎]" if window["broken"] else ""
	return "%s%s: %.1f%s" % [marker, window_id, window["durability_exact"], broken]


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("  [OK] %s" % label)
	else:
		_failed += 1
		push_error("  [FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])


func print_snapshot(tag: String) -> void:
	print("  [%s] %s" % [tag, JSON.stringify(GameManager.get_snapshot())])
