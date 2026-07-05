extends Node

const VICTORY_TITLE := "平安启航"
const VICTORY_BODY := "锚一归位，我就恢复了平静。我筋疲力尽，扑倒在小床上。想必我睡着了，因为醒来时满脸映着星光。"
const DEFEAT_TITLE := "坠海"
const DEFEAT_BODY := "海水涌入我的咽喉，这座现实的地狱，终归不是人的王国。"

@onready var _exit_dialog: Control = $CanvasLayer/UI/ExitDialog
@onready var _result_screen: Control = $CanvasLayer/UI/GameResultScreen
@onready var _main_menu: Control = $CanvasLayer/UI/MainMenu
@onready var _game_panel: Control = $CanvasLayer/UI/GamePanel
@onready var _exit_button: BaseButton = $CanvasLayer/UI/GamePanel/ExitButton
@onready var _confirm_exit_button: BaseButton = $CanvasLayer/UI/ExitDialog/DialogPanel/VBox/ConfirmButton
@onready var _start_button: BaseButton = $CanvasLayer/UI/MainMenu/VBox/StartButton
@onready var _victory_button: BaseButton = $CanvasLayer/UI/GamePanel/ActionPanel/VBox/VictoryButton
@onready var _defeat_button: BaseButton = $CanvasLayer/UI/GamePanel/ActionPanel/VBox/DefeatButton
@onready var _return_button: BaseButton = $CanvasLayer/UI/GameResultScreen/VBox/ReturnButton
@onready var _result_title: Label = $CanvasLayer/UI/GameResultScreen/VBox/TitleLabel
@onready var _result_body: Label = $CanvasLayer/UI/GameResultScreen/VBox/BodyLabel
@onready var _status_label: Label = $CanvasLayer/UI/GamePanel/ActionPanel/VBox/StatusLabel

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	_reset_game_state()
	_connect_runtime()
	_show_game()

	if DisplayServer.get_name() == "headless":
		_run_headless_checks()


func _connect_runtime() -> void:
	if not _exit_dialog.is_connected("exit_confirmed", Callable(self, "_on_exit_confirmed")):
		_exit_dialog.connect("exit_confirmed", Callable(self, "_on_exit_confirmed"))
	if not _result_screen.is_connected("return_main_menu_requested", Callable(self, "_on_return_main_menu_requested")):
		_result_screen.connect("return_main_menu_requested", Callable(self, "_on_return_main_menu_requested"))

	_start_button.pressed.connect(_on_start_pressed)
	_victory_button.pressed.connect(_on_victory_pressed)
	_defeat_button.pressed.connect(_on_defeat_pressed)


func _reset_game_state() -> void:
	GameProcessManager.reset()
	GameProcessManager.repair_time_target = 60.0
	RoomStateManager.reset_to_default()
	EventManager.reset()


func _show_main_menu() -> void:
	_main_menu.show()
	_game_panel.hide()
	_status_label.text = "已返回主界面"


func _show_game() -> void:
	_main_menu.hide()
	_game_panel.show()
	_status_label.text = "游戏中"


func _on_exit_confirmed() -> void:
	_reset_game_state()
	_result_screen.call("hide_result")
	_show_main_menu()


func _on_return_main_menu_requested() -> void:
	_reset_game_state()
	_show_main_menu()


func _on_start_pressed() -> void:
	_reset_game_state()
	_result_screen.call("hide_result")
	_show_game()


func _on_victory_pressed() -> void:
	GameProcessManager.repair_time_target = GameProcessManager.repair_time_accum + 1.0
	GameProcessManager.add_repair_time(1.1)


func _on_defeat_pressed() -> void:
	GameProcessManager.san_current = 1.0
	GameProcessManager.phase = GameProcessManager.Phase.TWO
	RoomStateManager.set_candle_lit("candle_room_a_0", false)
	EventManager.simulate_step(1.0)


func _run_headless_checks() -> void:
	print("========== M5 Flow Mock 开始 ==========")

	_check("exit dialog starts hidden", _exit_dialog.call("is_dialog_visible"), false)
	_exit_button.pressed.emit()
	_check("exit dialog opens", _exit_dialog.call("is_dialog_visible"), true)
	_confirm_exit_button.pressed.emit()
	_check("exit dialog closes after confirm", _exit_dialog.call("is_dialog_visible"), false)
	_check("main menu visible after exit", _main_menu.visible, true)
	_check("game hidden after exit", _game_panel.visible, false)

	_start_button.pressed.emit()
	_check("start returns to game", _game_panel.visible, true)

	_victory_button.pressed.emit()
	_check("victory screen visible", _result_screen.call("is_showing_result"), true)
	_check("victory title", _result_title.text, VICTORY_TITLE)
	_check("victory body", _result_body.text, VICTORY_BODY)
	_check("game input disabled after result", _victory_button.disabled, true)
	_return_button.pressed.emit()
	_check("main menu visible after return button", _main_menu.visible, true)
	_check("result hidden after return button", _result_screen.call("is_showing_result"), false)

	_start_button.pressed.emit()
	_defeat_button.pressed.emit()
	_check("defeat screen visible", _result_screen.call("is_showing_result"), true)
	_check("defeat title", _result_title.text, DEFEAT_TITLE)
	_check("defeat body", _result_body.text, DEFEAT_BODY)

	print("========== M5 Flow Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])
