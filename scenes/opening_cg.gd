extends Control

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const FADE_DURATION := 0.8
const HOLD_DURATION := 5.0

@onready var transition_rect: ColorRect = $TransitionColorRect


func _ready() -> void:
	transition_rect.color = Color.BLACK
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	move_child(transition_rect, get_child_count() - 1)
	transition_rect.visible = true
	transition_rect.modulate.a = 1.0

	var load_error := ResourceLoader.load_threaded_request(GAME_SCENE_PATH)
	if load_error != OK:
		push_error("Failed to start loading scene: " + GAME_SCENE_PATH)

	await _fade_from_black()
	await get_tree().create_timer(HOLD_DURATION).timeout
	await _fade_to_black()
	await _change_to_loaded_game_scene()


func _fade_from_black() -> void:
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	transition_rect.visible = false


func _fade_to_black() -> void:
	transition_rect.visible = true
	transition_rect.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished


func _change_to_loaded_game_scene() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)

	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(GAME_SCENE_PATH, progress)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Failed to load scene: " + GAME_SCENE_PATH)
		return

	var packed_scene := ResourceLoader.load_threaded_get(GAME_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Loaded resource is not a PackedScene: " + GAME_SCENE_PATH)
		return

	get_tree().change_scene_to_packed(packed_scene)
