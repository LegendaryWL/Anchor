class_name ExitDialog
extends Control

signal exit_confirmed

@export var entry_button_path: NodePath
@export var dialog_root_path: NodePath
@export var confirm_button_path: NodePath

var _entry_button: BaseButton
var _dialog_root: Control
var _confirm_button: BaseButton


func _ready() -> void:
	_entry_button = get_node_or_null(entry_button_path) as BaseButton
	_dialog_root = get_node_or_null(dialog_root_path) as Control
	_confirm_button = get_node_or_null(confirm_button_path) as BaseButton

	if _entry_button != null and not _entry_button.pressed.is_connected(show_dialog):
		_entry_button.pressed.connect(show_dialog)
	if _confirm_button != null and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)

	hide_dialog()


func show_dialog() -> void:
	if _dialog_root != null:
		_dialog_root.show()


func hide_dialog() -> void:
	if _dialog_root != null:
		_dialog_root.hide()


func is_dialog_visible() -> bool:
	return _dialog_root != null and _dialog_root.visible


func _on_confirm_pressed() -> void:
	hide_dialog()
	exit_confirmed.emit()
