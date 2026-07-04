class_name AudioFeedback
extends Node

signal cue_played(cue_name: String)
signal cue_stopped(cue_name: String)

const CUE_WINDOW_ATTACK := "window_attack"
const CUE_WHISPER := "whisper"
const CUE_CANDLE_LIGHT := "candle_light"
const CUE_CANDLE_SNUFF := "candle_snuff"
const CUE_FOOTSTEP := "footstep"
const CUE_MOUSE_IN := "mouse_in"
const CUE_ANCHOR_MACHINE := "anchor_machine"
const CUE_LOW_SAN := "low_san"
const CUE_OPENING := "opening"

@export var auto_connect_game_signals := true
@export var low_san_threshold := 20.0
@export var audio_bus := "Master"

@export_file("*.mp3") var window_attack_path := "res://audio/assets/knocking_a_wooden_door2.mp3"
@export_file("*.mp3") var whisper_path := "res://audio/assets/freesound_community-whispers-loop-41891.mp3"
@export_file("*.mp3") var candle_light_path := "res://audio/assets/freesound_community-match-lighting-candle-81020.mp3"
@export_file("*.mp3") var candle_snuff_path := "res://audio/assets/candle_snuff.mp3"
@export_file("*.mp3") var footstep_path := "res://audio/assets/walking_on_floor1.mp3"
@export_file("*.mp3") var mouse_in_path := "res://audio/assets/mouse_in.mp3"
@export_file("*.mp3") var anchor_machine_path := "res://audio/assets/freesound_community-electric-hoist-75932.mp3"
@export_file("*.mp3") var low_san_path := "res://audio/assets/sanity2low.mp3"
@export_file("*.mp3") var opening_path := "res://audio/assets/opening_A_Turn_for_the_Worse.mp3"

var _players: Dictionary = {}


func _ready() -> void:
	_setup_players()
	if auto_connect_game_signals:
		_connect_game_signals()


func play_cue(cue_name: String) -> void:
	var player := _get_player(cue_name)
	if player == null or player.stream == null:
		return

	player.play()
	cue_played.emit(cue_name)


func stop_cue(cue_name: String) -> void:
	var player := _get_player(cue_name)
	if player == null:
		return

	player.stop()
	cue_stopped.emit(cue_name)


func play_opening() -> void:
	play_cue(CUE_OPENING)


func stop_opening() -> void:
	stop_cue(CUE_OPENING)


func stop_all_cues() -> void:
	for cue_name in _players.keys():
		stop_cue(str(cue_name))


func release_all_cues() -> void:
	for cue_name in _players.keys():
		var player := _get_player(str(cue_name))
		if player == null:
			continue
		player.stop()
		player.stream = null
		if player.get_parent() != null:
			player.get_parent().remove_child(player)
		player.free()
	_players.clear()


func is_cue_playing(cue_name: String) -> bool:
	var player := _get_player(cue_name)
	return player != null and player.playing


func has_cue_stream(cue_name: String) -> bool:
	var player := _get_player(cue_name)
	return player != null and player.stream != null


func bind_hold_interaction(interaction: Node) -> void:
	if interaction == null:
		return

	if not interaction.is_connected("hold_started", Callable(self, "_on_hold_started")):
		interaction.connect("hold_started", Callable(self, "_on_hold_started"))
	if not interaction.is_connected("hold_canceled", Callable(self, "_on_hold_canceled")):
		interaction.connect("hold_canceled", Callable(self, "_on_hold_canceled"))
	if not interaction.is_connected("hold_completed", Callable(self, "_on_hold_completed")):
		interaction.connect("hold_completed", Callable(self, "_on_hold_completed"))


func bind_ui_hover_root(root: Node) -> void:
	if root == null:
		return

	if root is BaseButton:
		var button := root as BaseButton
		if not button.mouse_entered.is_connected(_on_mouse_entered_ui):
			button.mouse_entered.connect(_on_mouse_entered_ui)

	for child in root.get_children():
		bind_ui_hover_root(child)


func _setup_players() -> void:
	_setup_player(CUE_WINDOW_ATTACK, window_attack_path, true)
	_setup_player(CUE_WHISPER, whisper_path, true)
	_setup_player(CUE_CANDLE_LIGHT, candle_light_path, false)
	_setup_player(CUE_CANDLE_SNUFF, candle_snuff_path, false)
	_setup_player(CUE_FOOTSTEP, footstep_path, false)
	_setup_player(CUE_MOUSE_IN, mouse_in_path, false)
	_setup_player(CUE_ANCHOR_MACHINE, anchor_machine_path, true)
	_setup_player(CUE_LOW_SAN, low_san_path, true)
	_setup_player(CUE_OPENING, opening_path, true)


func _setup_player(cue_name: String, path: String, should_loop: bool) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "%sPlayer" % cue_name.to_pascal_case()
	player.bus = audio_bus
	player.stream = _load_stream(path, should_loop)
	add_child(player)
	_players[cue_name] = player


func _load_stream(path: String, should_loop: bool) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("AudioFeedback: missing audio stream at %s" % path)
		return null

	var stream := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream
	if stream == null:
		push_warning("AudioFeedback: failed to load audio stream at %s" % path)
		return null

	_set_stream_loop(stream, should_loop)
	return stream


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = should_loop


func _connect_game_signals() -> void:
	if EventManager.window_attack_event != null and not EventManager.window_attack_event.state_changed.is_connected(_on_window_attack_state_changed):
		EventManager.window_attack_event.state_changed.connect(_on_window_attack_state_changed)
	if EventManager.candle_extinguish_event != null and not EventManager.candle_extinguish_event.state_changed.is_connected(_on_candle_extinguish_state_changed):
		EventManager.candle_extinguish_event.state_changed.connect(_on_candle_extinguish_state_changed)

	if not RoomStateManager.room_changed.is_connected(_on_room_changed):
		RoomStateManager.room_changed.connect(_on_room_changed)
	if not RoomStateManager.candle_lit_changed.is_connected(_on_candle_lit_changed):
		RoomStateManager.candle_lit_changed.connect(_on_candle_lit_changed)
	if not GameProcessManager.san_changed.is_connected(_on_san_changed):
		GameProcessManager.san_changed.connect(_on_san_changed)
	if not GameProcessManager.game_over.is_connected(_on_game_over):
		GameProcessManager.game_over.connect(_on_game_over)


func _on_window_attack_state_changed(_event_id: String, _old_state: int, new_state: int) -> void:
	if new_state == EventBase.State.ACTIVE:
		play_cue(CUE_WINDOW_ATTACK)
	else:
		stop_cue(CUE_WINDOW_ATTACK)


func _on_candle_extinguish_state_changed(_event_id: String, _old_state: int, new_state: int) -> void:
	if new_state == EventBase.State.ACTIVE:
		play_cue(CUE_WHISPER)
	else:
		stop_cue(CUE_WHISPER)


func _on_room_changed(_room_id: String) -> void:
	play_cue(CUE_FOOTSTEP)


func _on_candle_lit_changed(_candle_id: String, lit: bool) -> void:
	if lit:
		play_cue(CUE_CANDLE_LIGHT)
	else:
		play_cue(CUE_CANDLE_SNUFF)


func _on_san_changed(current: float, _max_san: float) -> void:
	if current > 0.0 and current < low_san_threshold:
		if not is_cue_playing(CUE_LOW_SAN):
			play_cue(CUE_LOW_SAN)
	else:
		stop_cue(CUE_LOW_SAN)


func _on_game_over(_reason: int) -> void:
	stop_cue(CUE_WINDOW_ATTACK)
	stop_cue(CUE_WHISPER)
	stop_cue(CUE_ANCHOR_MACHINE)
	stop_cue(CUE_LOW_SAN)


func _on_hold_started(action_type: String, _target_id: String, _prompt_text: String, _required_time: float) -> void:
	if action_type == "repair_anchor":
		play_cue(CUE_ANCHOR_MACHINE)


func _on_hold_canceled(action_type: String, _target_id: String, _elapsed: float) -> void:
	if action_type == "repair_anchor":
		stop_cue(CUE_ANCHOR_MACHINE)


func _on_hold_completed(action_type: String, _target_id: String) -> void:
	if action_type == "repair_anchor":
		stop_cue(CUE_ANCHOR_MACHINE)


func _on_mouse_entered_ui() -> void:
	play_cue(CUE_MOUSE_IN)


func _get_player(cue_name: String) -> AudioStreamPlayer:
	return _players.get(cue_name, null) as AudioStreamPlayer
