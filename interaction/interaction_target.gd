class_name InteractionTarget
extends Node

signal target_focused(target_id: String, interaction_type: String)
signal target_unfocused(target_id: String, interaction_type: String)
signal interaction_node_ready(target_id: String, interaction_type: String, interaction_node: Node)

@export_enum("repair_anchor", "fix_window", "light_candle", "expel_black_hand") var interaction_type := "repair_anchor"
@export var target_id := ""
@export var auto_create_interaction := true

@export var hold_interaction_path: NodePath
@export var click_interaction_path: NodePath

@export var prompt_text := ""
@export var required_hold_time := 1.0
@export var window_repair_rate := 4.0
@export_range(1, 30, 1) var required_clicks := 5
@export var reset_after_seconds := 2.0
@export var send_behavior_message_on_complete := true

var _interaction_node: Node
var _is_focused := false


func _ready() -> void:
	setup_interaction()


func setup_interaction() -> Node:
	_interaction_node = _resolve_interaction_node()
	_sync_interaction_settings()
	if _interaction_node != null:
		interaction_node_ready.emit(target_id, interaction_type, _interaction_node)
	return _interaction_node


func focus_target() -> void:
	if _is_focused:
		return
	_is_focused = true
	target_focused.emit(target_id, interaction_type)


func unfocus_target() -> void:
	if not _is_focused:
		return
	cancel_interaction()
	_is_focused = false
	target_unfocused.emit(target_id, interaction_type)


func primary_pressed() -> void:
	focus_target()
	if _is_click_interaction():
		_register_click()
	else:
		_begin_hold()


func primary_released() -> void:
	if _is_click_interaction():
		return
	_cancel_hold()


func primary_clicked() -> void:
	focus_target()
	if _is_click_interaction():
		_register_click()
	else:
		_begin_hold()


func cancel_interaction() -> void:
	if _is_click_interaction():
		if _interaction_node != null and _interaction_node.has_method("reset_clicks"):
			_interaction_node.call("reset_clicks")
	else:
		_cancel_hold()


func get_interaction_node() -> Node:
	if _interaction_node == null:
		setup_interaction()
	return _interaction_node


func bind_hold_interaction(interaction: Node) -> void:
	hold_interaction_path = get_path_to(interaction)
	_interaction_node = interaction
	_sync_interaction_settings()


func bind_click_interaction(interaction: Node) -> void:
	click_interaction_path = get_path_to(interaction)
	_interaction_node = interaction
	_sync_interaction_settings()


func _resolve_interaction_node() -> Node:
	if _is_click_interaction():
		return _resolve_click_interaction()
	return _resolve_hold_interaction()


func _resolve_hold_interaction() -> Node:
	var existing := get_node_or_null(hold_interaction_path)
	if existing != null:
		return existing

	for child in get_children():
		if child is HoldInteraction:
			return child

	if not auto_create_interaction:
		return null

	var interaction := HoldInteraction.new()
	interaction.name = "HoldInteraction"
	add_child(interaction)
	return interaction


func _resolve_click_interaction() -> Node:
	var existing := get_node_or_null(click_interaction_path)
	if existing != null:
		return existing

	for child in get_children():
		if child is ClickSpamInteraction:
			return child

	if not auto_create_interaction:
		return null

	var interaction := ClickSpamInteraction.new()
	interaction.name = "ClickSpamInteraction"
	add_child(interaction)
	return interaction


func _sync_interaction_settings() -> void:
	if _interaction_node == null:
		return

	if _interaction_node is HoldInteraction:
		_interaction_node.set("action_type", interaction_type)
		_interaction_node.set("target_id", target_id)
		_interaction_node.set("prompt_text", prompt_text)
		_interaction_node.set("required_hold_time", required_hold_time)
		_interaction_node.set("window_repair_rate", window_repair_rate)
		_interaction_node.set("send_behavior_message_on_complete", send_behavior_message_on_complete)
	elif _interaction_node is ClickSpamInteraction:
		_interaction_node.set("action_type", "expel_black_hand")
		_interaction_node.set("target_id", target_id)
		_interaction_node.set("required_clicks", required_clicks)
		_interaction_node.set("reset_after_seconds", reset_after_seconds)
		_interaction_node.set("send_behavior_message_on_complete", send_behavior_message_on_complete)


func _begin_hold() -> void:
	var interaction := get_interaction_node()
	if interaction != null and interaction.has_method("begin_hold"):
		interaction.call("begin_hold")


func _cancel_hold() -> void:
	var interaction := get_interaction_node()
	if interaction != null and interaction.has_method("cancel_hold"):
		interaction.call("cancel_hold")


func _register_click() -> void:
	var interaction := get_interaction_node()
	if interaction != null and interaction.has_method("register_click"):
		interaction.call("register_click")


func _is_click_interaction() -> bool:
	return interaction_type == "expel_black_hand"
