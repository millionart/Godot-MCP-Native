class_name MCPToolClassifier
extends RefCounted

const CORE_MAX_COUNT: int = 40

var _tool_classifications: Dictionary = {}

func _init() -> void:
	_build_classifications()

func _build_classifications() -> void:
	var classifications: Array[Dictionary] = [
		{"name": "create_node", "category": "core", "group": "Node-Write"},
		{"name": "delete_node", "category": "core", "group": "Node-Write"},
		{"name": "update_node_property", "category": "core", "group": "Node-Write"},
		{"name": "get_node_properties", "category": "core", "group": "Node-Read"},
		{"name": "list_nodes", "category": "core", "group": "Node-Read"},
		{"name": "get_scene_tree", "category": "core", "group": "Node-Read"},
		{"name": "duplicate_node", "category": "core", "group": "Node-Write"},
		{"name": "move_node", "category": "core", "group": "Node-Write"},
		{"name": "rename_node", "category": "core", "group": "Node-Write"},
		{"name": "add_resource", "category": "core", "group": "Node-Write"},
		{"name": "set_anchor_preset", "category": "core", "group": "Node-Write"},
		{"name": "connect_signal", "category": "core", "group": "Node-Write"},
		{"name": "disconnect_signal", "category": "core", "group": "Node-Write"},
		{"name": "get_node_groups", "category": "core", "group": "Node-Read"},
		{"name": "set_node_groups", "category": "core", "group": "Node-Write"},
		{"name": "find_nodes_in_group", "category": "core", "group": "Node-Read"},
		{"name": "list_project_scripts", "category": "core", "group": "Script"},
		{"name": "read_script", "category": "core", "group": "Script"},
		{"name": "create_script", "category": "core", "group": "Script"},
		{"name": "modify_script", "category": "core", "group": "Script"},
		{"name": "analyze_script", "category": "core", "group": "Script"},
		{"name": "get_current_script", "category": "core", "group": "Script"},
		{"name": "attach_script", "category": "core", "group": "Script"},
		{"name": "validate_script", "category": "core", "group": "Script"},
		{"name": "search_in_files", "category": "core", "group": "Script"},
		{"name": "create_scene", "category": "core", "group": "Scene"},
		{"name": "save_scene", "category": "core", "group": "Scene"},
		{"name": "open_scene", "category": "core", "group": "Scene"},
		{"name": "get_current_scene", "category": "core", "group": "Scene"},
		{"name": "get_scene_structure", "category": "core", "group": "Scene"},
		{"name": "list_project_scenes", "category": "core", "group": "Scene"},
		{"name": "get_editor_state", "category": "core", "group": "Editor"},
		{"name": "run_project", "category": "core", "group": "Editor"},
		{"name": "stop_project", "category": "core", "group": "Editor"},
		{"name": "get_selected_nodes", "category": "core", "group": "Editor"},
		{"name": "set_editor_setting", "category": "core", "group": "Editor"},
		{"name": "get_editor_screenshot", "category": "core", "group": "Editor"},
		{"name": "get_signals", "category": "core", "group": "Editor"},
		{"name": "reload_project", "category": "supplementary", "group": "Editor-Advanced"},
		{"name": "get_editor_logs", "category": "core", "group": "Debug"},
		{"name": "execute_script", "category": "supplementary", "group": "Debug-Advanced"},
		{"name": "get_performance_metrics", "category": "supplementary", "group": "Debug-Advanced"},
		{"name": "debug_print", "category": "core", "group": "Debug"},
		{"name": "execute_editor_script", "category": "supplementary", "group": "Editor-Advanced"},
		{"name": "clear_output", "category": "core", "group": "Debug"},
		{"name": "get_project_info", "category": "core", "group": "Project"},
		{"name": "get_project_settings", "category": "core", "group": "Project"},
		{"name": "list_project_resources", "category": "core", "group": "Project"},
		{"name": "create_resource", "category": "core", "group": "Project"},
		{"name": "get_project_structure", "category": "core", "group": "Project"},
	]

	for item in classifications:
		_tool_classifications[item["name"]] = {
			"category": item["category"],
			"group": item["group"]
		}

func get_tool_category(tool_name: String) -> String:
	if _tool_classifications.has(tool_name):
		return _tool_classifications[tool_name]["category"]
	return "core"

func get_tool_group(tool_name: String) -> String:
	if _tool_classifications.has(tool_name):
		return _tool_classifications[tool_name]["group"]
	return ""

func get_all_groups() -> Array[String]:
	var groups: Array[String] = []
	for tool_name in _tool_classifications:
		var group: String = _tool_classifications[tool_name]["group"]
		if not group in groups and not group.is_empty():
			groups.append(group)
	return groups

func get_group_tools(group_name: String) -> Array[String]:
	var tools: Array[String] = []
	for tool_name in _tool_classifications:
		if _tool_classifications[tool_name]["group"] == group_name:
			tools.append(tool_name)
	return tools

func get_core_tools() -> Array[String]:
	var tools: Array[String] = []
	for tool_name in _tool_classifications:
		if _tool_classifications[tool_name]["category"] == "core":
			tools.append(tool_name)
	return tools

func get_supplementary_tools() -> Array[String]:
	var tools: Array[String] = []
	for tool_name in _tool_classifications:
		if _tool_classifications[tool_name]["category"] == "supplementary":
			tools.append(tool_name)
	return tools

func get_core_max_count() -> int:
	return CORE_MAX_COUNT

func is_core_tool(tool_name: String) -> bool:
	return get_tool_category(tool_name) == "core"

func is_supplementary_tool(tool_name: String) -> bool:
	return get_tool_category(tool_name) == "supplementary"

func get_all_tools() -> Array:
	return _tool_classifications.keys()

func get_all_categories() -> Array[String]:
	var categories: Array[String] = []
	for tool_name in _tool_classifications:
		var cat: String = _tool_classifications[tool_name]["category"]
		if not cat in categories:
			categories.append(cat)
	return categories
