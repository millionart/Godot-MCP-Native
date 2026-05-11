class_name MCPRuntimeProbe
extends Node

const CAPTURE_PREFIX: StringName = &"mcp"

func _ready() -> void:
	if EngineDebugger.is_active() and not EngineDebugger.has_capture(CAPTURE_PREFIX):
		EngineDebugger.register_message_capture(CAPTURE_PREFIX, Callable(self, "_capture_mcp_message"))
		EngineDebugger.send_message("mcp:probe_ready", [_get_runtime_info()])

func _exit_tree() -> void:
	if EngineDebugger.is_active() and EngineDebugger.has_capture(CAPTURE_PREFIX):
		EngineDebugger.unregister_message_capture(CAPTURE_PREFIX)

func _capture_mcp_message(message: String, data: Array) -> bool:
	match message:
		"ping":
			EngineDebugger.send_message("mcp:pong", [_get_runtime_info()])
			return true
		"get_runtime_info":
			EngineDebugger.send_message("mcp:runtime_info", [_get_runtime_info()])
			return true
		"get_scene_tree":
			var max_depth: int = 6
			if not data.is_empty() and data[0] is int:
				max_depth = data[0]
			var root: Node = get_tree().current_scene
			if not root:
				root = get_tree().root
			EngineDebugger.send_message("mcp:scene_tree", [_serialize_node(root, 0, max_depth)])
			return true
		"inspect_node":
			if data.is_empty():
				EngineDebugger.send_message("mcp:error", [{"message": "inspect_node requires a NodePath string"}])
				return true
			var node: Node = get_node_or_null(NodePath(str(data[0])))
			if not node:
				EngineDebugger.send_message("mcp:error", [{"message": "Node not found: " + str(data[0])}])
				return true
			EngineDebugger.send_message("mcp:node", [_serialize_node(node, 0, 1, true)])
			return true
		"debug_break":
			EngineDebugger.debug(true, false)
			return true
		_:
			return false

func _get_runtime_info() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"physics_frames": Engine.get_physics_frames(),
		"process_frames": Engine.get_process_frames(),
		"debugger_active": EngineDebugger.is_active(),
		"current_scene": str(get_tree().current_scene.get_path()) if get_tree().current_scene else "",
		"node_count": _count_nodes(get_tree().root)
	}

func _serialize_node(node: Node, depth: int, max_depth: int, include_properties: bool = false) -> Dictionary:
	var result: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"child_count": node.get_child_count()
	}
	if include_properties:
		result["properties"] = _serialize_properties(node)
	if max_depth >= 0 and depth >= max_depth:
		return result
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_serialize_node(child, depth + 1, max_depth))
	result["children"] = children
	return result

func _serialize_properties(node: Node) -> Dictionary:
	var properties: Dictionary = {}
	for property in node.get_property_list():
		var name: String = property.get("name", "")
		var usage: int = property.get("usage", 0)
		if name.begins_with("_") \
				or (usage & PROPERTY_USAGE_CATEGORY) != 0 \
				or (usage & PROPERTY_USAGE_GROUP) != 0 \
				or (usage & PROPERTY_USAGE_SUBGROUP) != 0:
			continue
		var value: Variant = node.get(name)
		match typeof(value):
			TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
				properties[name] = value
			TYPE_VECTOR2:
				properties[name] = {"x": value.x, "y": value.y}
			TYPE_VECTOR3:
				properties[name] = {"x": value.x, "y": value.y, "z": value.z}
			TYPE_COLOR:
				properties[name] = {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
			_:
				properties[name] = str(value)
	return properties

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
