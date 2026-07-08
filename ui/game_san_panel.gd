extends Panel

@export var low_san_threshold := 20.0
@export_range(0.0, 1.0, 0.01) var low_san_max_alpha := 0.42
@export_file("*.mp3") var low_san_audio_path := "res://audio/assets/sanity2low.mp3"

@onready var san_bar: ProgressBar = $SANProgressBar
@onready var san_label: Label = $Label

var _low_san_overlay: ColorRect
var _low_san_player: AudioStreamPlayer


func _ready() -> void:
	_setup_low_san_overlay()
	_setup_low_san_audio()

	if not GameManager.san_changed.is_connected(_on_san_changed):
		GameManager.san_changed.connect(_on_san_changed)
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)

	var snapshot := GameManager.get_snapshot()
	_on_san_changed(float(snapshot.get("san", 100.0)), float(snapshot.get("san_max", 100.0)))


func _on_san_changed(current: float, max_san: float) -> void:
	if san_bar != null:
		san_bar.min_value = 0.0
		san_bar.max_value = maxf(max_san, 0.01)
		san_bar.value = clampf(current, 0.0, san_bar.max_value)

	if san_label != null:
		san_label.text = "SAN %.0f / %.0f" % [current, max_san]

	_refresh_low_san_feedback(current)


func _on_game_over(_result: String) -> void:
	_stop_low_san_feedback()


func _setup_low_san_overlay() -> void:
	_low_san_overlay = ColorRect.new()
	_low_san_overlay.name = "LowSanOverlay"
	_low_san_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_low_san_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_san_overlay.color = Color(0.85, 0.0, 0.0, 0.0)
	_low_san_overlay.visible = false

	var overlay_parent := get_parent()
	if overlay_parent != null:
		overlay_parent.add_child(_low_san_overlay)


func _setup_low_san_audio() -> void:
	_low_san_player = AudioStreamPlayer.new()
	_low_san_player.name = "LowSanAudioPlayer"
	if ResourceLoader.exists(low_san_audio_path):
		_low_san_player.stream = ResourceLoader.load(low_san_audio_path) as AudioStream
		if _low_san_player.stream is AudioStreamMP3:
			(_low_san_player.stream as AudioStreamMP3).loop = true
	add_child(_low_san_player)


func _refresh_low_san_feedback(current: float) -> void:
	var should_warn := current > 0.0 and current < low_san_threshold and not GameManager.is_game_over
	if not should_warn:
		_stop_low_san_feedback()
		return

	var danger_ratio := clampf(1.0 - (current / maxf(low_san_threshold, 0.01)), 0.0, 1.0)
	var alpha := lerpf(0.12, low_san_max_alpha, danger_ratio)
	if _low_san_overlay != null:
		_low_san_overlay.visible = true
		_low_san_overlay.color = Color(0.85, 0.0, 0.0, alpha)

	if _low_san_player != null and _low_san_player.stream != null and not _low_san_player.playing:
		_low_san_player.play()


func _stop_low_san_feedback() -> void:
	if _low_san_overlay != null:
		_low_san_overlay.visible = false
	if _low_san_player != null:
		_low_san_player.stop()
