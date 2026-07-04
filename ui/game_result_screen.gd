class_name GameResultScreen
extends Control

signal return_main_menu_requested

const VICTORY_TITLE := "平安启航"
const VICTORY_BODY := "锚一归位，我就恢复了平静。我筋疲力尽，扑倒在小床上。想必我睡着了，因为醒来时满脸映着星光。"
const DEFEAT_TITLE := "坠海"
const DEFEAT_BODY := "海水涌入我的咽喉，这座现实的地狱，终归不是人的王国。"

@export var title_label_path: NodePath
@export var body_label_path: NodePath
@export var return_button_path: NodePath
@export var input_root_path: NodePath
@export var auto_listen_game_over := true

var _title_label: Label
var _body_label: Label
var _return_button: BaseButton
var _input_root: Node
var _is_showing := false


func _ready() -> void:
	_title_label = get_node_or_null(title_label_path) as Label
	_body_label = get_node_or_null(body_label_path) as Label
	_return_button = get_node_or_null(return_button_path) as BaseButton
	_input_root = get_node_or_null(input_root_path)

	if _return_button != null and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)
	if auto_listen_game_over and not GameProcessManager.game_over.is_connected(show_result):
		GameProcessManager.game_over.connect(show_result)

	hide_result()


func show_result(reason: int) -> void:
	var title := "游戏结束"
	var body := ""
	match reason:
		GameProcessManager.GameOverReason.VICTORY:
			title = VICTORY_TITLE
			body = VICTORY_BODY
		GameProcessManager.GameOverReason.DEFEAT:
			title = DEFEAT_TITLE
			body = DEFEAT_BODY

	if _title_label != null:
		_title_label.text = title
	if _body_label != null:
		_body_label.text = body

	_is_showing = true
	show()
	_set_input_disabled(true)


func hide_result() -> void:
	_is_showing = false
	hide()
	_set_input_disabled(false)


func is_showing_result() -> bool:
	return _is_showing


func _on_return_pressed() -> void:
	hide_result()
	return_main_menu_requested.emit()


func _set_input_disabled(disabled: bool) -> void:
	if _input_root == null:
		return
	_set_buttons_disabled(_input_root, disabled)


func _set_buttons_disabled(root: Node, disabled: bool) -> void:
	if root is BaseButton:
		(root as BaseButton).disabled = disabled

	for child in root.get_children():
		_set_buttons_disabled(child, disabled)
