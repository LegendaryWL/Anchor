class_name BehaviorMessage
extends RefCounted

var type: String = ""
var target_id: String = ""
var resolved: bool = false
var payload: Dictionary = {}


static func create(
	p_type: String,
	p_target_id: String,
	p_resolved: bool = true,
	p_payload: Dictionary = {}
) -> BehaviorMessage:
	var message := BehaviorMessage.new()
	message.type = p_type
	message.target_id = p_target_id
	message.resolved = p_resolved
	message.payload = p_payload
	return message
