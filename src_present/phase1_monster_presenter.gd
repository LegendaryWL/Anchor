extends Node3D

@export var monster_sprite_path: NodePath
@export var spawn_root_path: NodePath
@export var window_area_root_path: NodePath
@export var break_particles_path: NodePath
@export_file("*.mp3") var phase_end_sfx_path := "res://audio/assets/knocking_an_iron_door1.mp3"
@export var phase_end_audio_unit_size := 2.0

var monster_sprite: Sprite3D
var monster_audio: AudioStreamPlayer3D
var phase_end_audio: AudioStreamPlayer3D
var spawn_root: Node3D
var window_area_root: Node3D
var break_particles: Node3D


func _ready() -> void:
	monster_sprite = get_node(monster_sprite_path) as Sprite3D
	spawn_root = get_node(spawn_root_path) as Node3D
	window_area_root = get_node_or_null(window_area_root_path) as Node3D
	break_particles = get_node_or_null(break_particles_path) as Node3D
	monster_audio = monster_sprite.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	_setup_phase_end_audio()

	monster_sprite.visible = false
	if monster_audio != null:
		_set_stream_loop(monster_audio.stream, true)
		monster_audio.stop()

	GameManager.attack_started.connect(_on_attack_started)
	GameManager.attack_resolved.connect(_on_attack_resolved)
	GameManager.phase1_ended.connect(_on_phase1_ended)


func _on_attack_started(target_id: String, attack_type: String) -> void:
	if attack_type != "window":
		return

	var spawn := spawn_root.get_node_or_null(target_id) as Node3D
	if spawn == null:
		push_warning("No monster spawn point for: " + target_id)
		return

	monster_sprite.global_position = spawn.global_position
	monster_sprite.global_rotation = spawn.global_rotation
	monster_sprite.visible = true
	if monster_audio != null and not monster_audio.playing:
		monster_audio.play()


func _on_attack_resolved(_target_id: String, attack_type: String) -> void:
	if attack_type != "window":
		return

	monster_sprite.visible = false
	if monster_audio != null:
		monster_audio.stop()


func _on_phase1_ended(broken_window_id: String) -> void:
	monster_sprite.visible = false
	if monster_audio != null:
		monster_audio.stop()

	var window_area := _get_window_area(broken_window_id)
	var effect_position := _get_effect_position(broken_window_id, window_area)
	if phase_end_audio != null and phase_end_audio.stream != null:
		phase_end_audio.global_position = effect_position
		phase_end_audio.play()

	if break_particles == null:
		push_warning("No window break particles node assigned.")
		return
	if broken_window_id.is_empty():
		return

	break_particles.global_position = effect_position
	break_particles.global_rotation = _get_effect_rotation(broken_window_id, window_area)
	_emit_particles(break_particles)


func _get_effect_position(window_id: String, window_area: Node3D) -> Vector3:
	if window_area != null:
		return window_area.global_position
	var spawn := spawn_root.get_node_or_null(window_id) as Node3D
	if spawn != null:
		return spawn.global_position
	return global_position


func _get_effect_rotation(window_id: String, window_area: Node3D) -> Vector3:
	if window_area != null:
		return window_area.global_rotation
	var spawn := spawn_root.get_node_or_null(window_id) as Node3D
	if spawn != null:
		return spawn.global_rotation
	return Vector3.ZERO


func _get_window_area(window_id: String) -> Node3D:
	if window_area_root == null or window_id.is_empty():
		return null
	var node := window_area_root.get_node_or_null(window_id)
	if node == null:
		push_warning("No window Area3D for: " + window_id)
		return null
	return node as Node3D


func _setup_phase_end_audio() -> void:
	phase_end_audio = AudioStreamPlayer3D.new()
	phase_end_audio.name = "PhaseEndAudioStreamPlayer3D"
	phase_end_audio.unit_size = phase_end_audio_unit_size
	if ResourceLoader.exists(phase_end_sfx_path):
		phase_end_audio.stream = ResourceLoader.load(phase_end_sfx_path) as AudioStream
		_set_stream_loop(phase_end_audio.stream, false)
	add_child(phase_end_audio)


func _emit_particles(root: Node) -> void:
	if root is GPUParticles3D:
		var gpu_particles := root as GPUParticles3D
		gpu_particles.restart()
		gpu_particles.emitting = true
	elif root is CPUParticles3D:
		var cpu_particles := root as CPUParticles3D
		cpu_particles.restart()
		cpu_particles.emitting = true

	for child in root.get_children():
		_emit_particles(child)


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = should_loop
	elif stream is AudioStreamOggVorbis:
		stream.loop = should_loop
