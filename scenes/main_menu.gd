extends Control

const OPENING_SCENE_PATH := "res://scenes/opening_CG.tscn"
const FADE_DURATION := 0.8

@onready var start_button: Button = $StartButton
@onready var guide_button: Button = $GuideButton
@onready var exit_button: Button = $ExitButton
@onready var color_rect: ColorRect = $ColorRect

var _is_transitioning := false


func _ready() -> void:
	color_rect.color = Color.BLACK
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	move_child(color_rect, get_child_count() - 1)
	color_rect.visible = true
	color_rect.modulate.a = 1.0
	start_button.disabled = true
	guide_button.disabled = true
	exit_button.disabled = true

	start_button.pressed.connect(_on_start_button_pressed)
	guide_button.pressed.connect(_on_guide_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	_fade_from_black()


func _on_start_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	start_button.disabled = true
	guide_button.disabled = true
	exit_button.disabled = true

	var load_error := ResourceLoader.load_threaded_request(OPENING_SCENE_PATH)
	if load_error != OK:
		push_error("Failed to start loading scene: " + OPENING_SCENE_PATH)
		_is_transitioning = false
		start_button.disabled = false
		guide_button.disabled = false
		exit_button.disabled = false
		return

	await _fade_to_black()
	await _change_to_loaded_game_scene()


func _on_guide_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	start_button.disabled = true
	guide_button.disabled = true
	exit_button.disabled = true
	await _fade_to_black()
	get_tree().change_scene_to_file("res://scenes/guide_menu.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _fade_to_black() -> void:
	color_rect.visible = true
	color_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished


func _fade_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	color_rect.visible = false
	start_button.disabled = false
	guide_button.disabled = false
	exit_button.disabled = false


func _change_to_loaded_game_scene() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(OPENING_SCENE_PATH, progress)

	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(OPENING_SCENE_PATH, progress)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Failed to load scene: " + OPENING_SCENE_PATH)
		_is_transitioning = false
		start_button.disabled = false
		guide_button.disabled = false
		exit_button.disabled = false
		return

	var packed_scene := ResourceLoader.load_threaded_get(OPENING_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Loaded resource is not a PackedScene: " + OPENING_SCENE_PATH)
		_is_transitioning = false
		start_button.disabled = false
		guide_button.disabled = false
		exit_button.disabled = false
		return

	get_tree().change_scene_to_packed(packed_scene)
