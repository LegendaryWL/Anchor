extends Control

const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"

@onready var return_button: Button = $ReturnButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	return_button.pressed.connect(_on_return_button_pressed)


func _on_return_button_pressed() -> void:
	if get_meta("opened_from_game", false):
		get_tree().paused = false
		queue_free()
		return
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
