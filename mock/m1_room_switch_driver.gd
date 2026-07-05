extends Node

@onready var _room_switcher: Node = $RoomSwitcher
@onready var _minimap: Control = $CanvasLayer/Minimap
@onready var _room_a_camera: Camera3D = $RoomA/Camera3D
@onready var _room_b_camera: Camera3D = $RoomB/Camera3D
@onready var _bow_camera: Camera3D = $RoomBow/Camera3D

var _passed := 0
var _failed := 0


func _ready() -> void:
	await get_tree().process_frame
	print("========== M1 Room Switch Mock 开始 ==========")

	RoomStateManager.set_current_room("room_a")
	await get_tree().process_frame
	_check("initial room", RoomStateManager.current_room_id, "room_a")
	_check("room_a camera current", _room_a_camera.current, true)

	_press_button("RoomBButton")
	await get_tree().process_frame
	_check("switch to room_b", RoomStateManager.current_room_id, "room_b")
	_check("room_b camera current", _room_b_camera.current, true)
	_check("room_a camera off", _room_a_camera.current, false)

	_press_button("BowRoomButton")
	await get_tree().process_frame
	_check("switch to bow_room", RoomStateManager.current_room_id, "bow_room")
	_check("bow camera current", _bow_camera.current, true)

	_room_switcher.call("request_switch_room", "room_a")
	await get_tree().process_frame
	_check("switcher direct room_a", RoomStateManager.current_room_id, "room_a")
	_check("room_a camera current again", _room_a_camera.current, true)

	print("========== M1 Room Switch Mock 结果: %d 通过, %d 失败 ==========" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _failed > 0 else 0)


func _press_button(button_name: String) -> void:
	var button := _minimap.get_node(button_name) as BaseButton
	button.pressed.emit()


func _check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		print("[PASS] %s -> %s" % [label, str(actual)])
		return

	_failed += 1
	push_error("[FAIL] %s expected=%s actual=%s" % [label, str(expected), str(actual)])
