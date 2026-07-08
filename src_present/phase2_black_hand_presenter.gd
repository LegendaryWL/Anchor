extends Node

@export var black_hand_path: NodePath
@export var spawn_root_path: NodePath
@export var candle_light_root_path: NodePath
@export_file("*.mp3") var candle_attack_sfx_path := "res://audio/assets/freesound_community-whispers-loop-41891.mp3"
@export var candle_attack_fade_in_seconds := 0.8
@export var candle_attack_fade_out_seconds := 0.8
@export var candle_attack_volume_db := 0.0
@export var candle_attack_silent_db := -40.0

var black_hand: Node3D
var spawn_root: Node3D
var candle_light_root: Node
var candle_attack_audio: AudioStreamPlayer
var _home_transform: Transform3D
var _candle_attack_audio_tween: Tween


func _ready() -> void:
	black_hand = get_node_or_null(black_hand_path) as Node3D
	spawn_root = get_node_or_null(spawn_root_path) as Node3D
	candle_light_root = get_node_or_null(candle_light_root_path)
	if black_hand != null:
		_home_transform = black_hand.global_transform
	_setup_candle_attack_audio()

	GameManager.attack_started.connect(_on_attack_started)
	GameManager.attack_resolved.connect(_on_attack_resolved)
	GameManager.candle_changed.connect(_on_candle_changed)
	GameManager.game_over.connect(_on_game_over)
	_sync_all_candle_lights()


func _on_attack_started(target_id: String, attack_type: String) -> void:
	if attack_type != "candle":
		return
	if black_hand == null or spawn_root == null:
		return

	var spawn := spawn_root.get_node_or_null(target_id) as Node3D
	if spawn == null:
		push_warning("No black hand spawn point for: " + target_id)
		return

	black_hand.global_transform = spawn.global_transform
	black_hand.visible = true
	_play_candle_attack_audio()


func _on_attack_resolved(_target_id: String, attack_type: String) -> void:
	if attack_type != "candle":
		return
	_restore_black_hand()


func _on_game_over(_result: String) -> void:
	_restore_black_hand()


func _restore_black_hand() -> void:
	if black_hand == null:
		_stop_candle_attack_audio()
		return
	black_hand.global_transform = _home_transform
	_stop_candle_attack_audio()


func _on_candle_changed(candle_id: String, lit: bool) -> void:
	_set_candle_light_visible(candle_id, lit)


func _sync_all_candle_lights() -> void:
	var snapshot := GameManager.get_snapshot()
	var candles: Dictionary = snapshot.get("candles", {})
	for candle_id in candles.keys():
		var candle: Dictionary = candles[candle_id]
		_set_candle_light_visible(str(candle_id), bool(candle.get("lit", true)))


func _set_candle_light_visible(candle_id: String, lit: bool) -> void:
	if candle_light_root == null:
		return
	var light := candle_light_root.get_node_or_null(candle_id) as Node3D
	if light == null:
		push_warning("No candle light for: " + candle_id)
		return
	light.visible = lit


func _setup_candle_attack_audio() -> void:
	candle_attack_audio = AudioStreamPlayer.new()
	candle_attack_audio.name = "CandleAttackAudioPlayer"
	candle_attack_audio.volume_db = candle_attack_silent_db
	if ResourceLoader.exists(candle_attack_sfx_path):
		candle_attack_audio.stream = ResourceLoader.load(candle_attack_sfx_path) as AudioStream
		if candle_attack_audio.stream is AudioStreamMP3:
			(candle_attack_audio.stream as AudioStreamMP3).loop = true
		elif candle_attack_audio.stream is AudioStreamOggVorbis:
			(candle_attack_audio.stream as AudioStreamOggVorbis).loop = true
	add_child(candle_attack_audio)


func _play_candle_attack_audio() -> void:
	if candle_attack_audio == null or candle_attack_audio.stream == null:
		return
	_kill_candle_attack_audio_tween()
	if not candle_attack_audio.playing:
		candle_attack_audio.volume_db = candle_attack_silent_db
		candle_attack_audio.play()
	_candle_attack_audio_tween = create_tween()
	_candle_attack_audio_tween.tween_property(
		candle_attack_audio,
		"volume_db",
		candle_attack_volume_db,
		candle_attack_fade_in_seconds
	)


func _stop_candle_attack_audio() -> void:
	if candle_attack_audio == null:
		return
	_kill_candle_attack_audio_tween()
	if not candle_attack_audio.playing:
		candle_attack_audio.volume_db = candle_attack_silent_db
		return
	_candle_attack_audio_tween = create_tween()
	_candle_attack_audio_tween.tween_property(
		candle_attack_audio,
		"volume_db",
		candle_attack_silent_db,
		candle_attack_fade_out_seconds
	)
	_candle_attack_audio_tween.tween_callback(func() -> void:
		candle_attack_audio.stop()
	)


func _kill_candle_attack_audio_tween() -> void:
	if _candle_attack_audio_tween != null and _candle_attack_audio_tween.is_valid():
		_candle_attack_audio_tween.kill()
	_candle_attack_audio_tween = null
