class_name ProgressPrompt
extends Control

@export var label_path: NodePath
@export var progress_bar_path: NodePath
@export var hide_when_idle := true

var _label: Label
var _progress_bar: ProgressBar


func _ready() -> void:
	_label = get_node_or_null(label_path) as Label
	_progress_bar = get_node_or_null(progress_bar_path) as ProgressBar
	if _progress_bar != null:
		_progress_bar.min_value = 0.0
		_progress_bar.max_value = 1.0
		_progress_bar.value = 0.0
	if hide_when_idle:
		hide()


func bind_hold_interaction(interaction: Node) -> void:
	if interaction == null:
		return

	if not interaction.is_connected("hold_started", Callable(self, "_on_hold_started")):
		interaction.connect("hold_started", Callable(self, "_on_hold_started"))
	if not interaction.is_connected("progress_changed", Callable(self, "_on_progress_changed")):
		interaction.connect("progress_changed", Callable(self, "_on_progress_changed"))
	if not interaction.is_connected("hold_canceled", Callable(self, "_on_hold_canceled")):
		interaction.connect("hold_canceled", Callable(self, "_on_hold_canceled"))
	if not interaction.is_connected("hold_completed", Callable(self, "_on_hold_completed")):
		interaction.connect("hold_completed", Callable(self, "_on_hold_completed"))


func _on_hold_started(_action_type: String, _target_id: String, prompt_text: String, _required_time: float) -> void:
	if _label != null:
		_label.text = prompt_text
	if _progress_bar != null:
		_progress_bar.value = 0.0
	show()


func _on_progress_changed(_action_type: String, _target_id: String, ratio: float, _elapsed: float, _required_time: float) -> void:
	if _progress_bar != null:
		_progress_bar.value = clampf(ratio, 0.0, 1.0)


func _on_hold_canceled(_action_type: String, _target_id: String, _elapsed: float) -> void:
	if _progress_bar != null:
		_progress_bar.value = 0.0
	if hide_when_idle:
		hide()


func _on_hold_completed(_action_type: String, _target_id: String) -> void:
	if _progress_bar != null:
		_progress_bar.value = 1.0
	if hide_when_idle:
		hide()
