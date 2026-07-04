class_name Minimap
extends Control

signal room_button_pressed(room_id: String)

@export var room_switcher_path: NodePath

@export var room_a_id := "room_a"
@export var room_b_id := "room_b"
@export var bow_room_id := "bow_room"

@export var room_a_button_path: NodePath
@export var room_b_button_path: NodePath
@export var bow_room_button_path: NodePath

@export var disable_current_room_button := true

var _buttons: Dictionary = {}
var _room_switcher: Node


func _ready() -> void:
	_room_switcher = get_node_or_null(room_switcher_path)

	_bind_button(room_a_id, room_a_button_path)
	_bind_button(room_b_id, room_b_button_path)
	_bind_button(bow_room_id, bow_room_button_path)

	if not RoomStateManager.room_changed.is_connected(_on_room_changed):
		RoomStateManager.room_changed.connect(_on_room_changed)

	_on_room_changed(RoomStateManager.current_room_id)


func request_room(room_id: String) -> void:
	if room_id.is_empty():
		return

	room_button_pressed.emit(room_id)
	if _room_switcher != null and _room_switcher.has_method("request_switch_room"):
		_room_switcher.call("request_switch_room", room_id)
	else:
		RoomStateManager.set_current_room(room_id)


func _bind_button(room_id: String, button_path: NodePath) -> void:
	if room_id.is_empty() or button_path.is_empty():
		return

	var button := get_node_or_null(button_path) as BaseButton
	if button == null:
		push_warning("Minimap: button path for %s is not a BaseButton: %s" % [room_id, button_path])
		return

	_buttons[room_id] = button
	if not button.pressed.is_connected(_on_button_pressed.bind(room_id)):
		button.pressed.connect(_on_button_pressed.bind(room_id))


func _on_button_pressed(room_id: String) -> void:
	request_room(room_id)


func _on_room_changed(room_id: String) -> void:
	for id in _buttons.keys():
		var button := _buttons[id] as BaseButton
		if button == null:
			continue

		button.button_pressed = id == room_id
		if disable_current_room_button:
			button.disabled = id == room_id
