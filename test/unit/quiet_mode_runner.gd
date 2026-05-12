extends SceneTree

var _failures: Array[String] = []

func _init() -> void:
	_test_policy_defaults()
	_test_disruptive_tools_are_blocked_by_default()
	_test_overrides_bypass_quiet_mode_gate()
	_test_disruptive_tool_schemas_expose_overrides()
	_test_plugin_exports_vibe_coding_mode()
	if _failures.is_empty():
		print("quiet_mode_runner: all checks passed")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	if value:
		_failures.append(message)

func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s expected=%s actual=%s" % [message, str(expected), str(actual)])

func _assert_blocked(result: Dictionary, tool_name: String) -> void:
	_assert_true(bool(result.get("blocked", false)), tool_name + " should be blocked in Vibe Coding mode")
	_assert_eq(str(result.get("reason", "")), "vibe_coding_mode", tool_name + " should report vibe_coding_mode")
	_assert_true(str(result.get("error", "")).contains("Vibe Coding mode"), tool_name + " should explain the quiet-mode block")

func _assert_not_quiet_block(result: Dictionary, tool_name: String) -> void:
	_assert_false(bool(result.get("blocked", false)), tool_name + " override should bypass quiet-mode block")
	_assert_false(str(result.get("reason", "")) == "vibe_coding_mode", tool_name + " override should not report vibe_coding_mode")

func _assert_tool_schema_has_property(server_core: MCPServerCore, tool_name: String, property_name: String) -> void:
	_assert_true(server_core.has_tool(tool_name), tool_name + " should be registered")
	if not server_core.has_tool(tool_name):
		return
	var tool: MCPTypes.MCPTool = server_core.get_tool(tool_name)
	var input_schema: Dictionary = tool.input_schema
	var properties: Dictionary = input_schema.get("properties", {})
	_assert_true(properties.has(property_name), tool_name + " schema should expose " + property_name)

func _test_policy_defaults() -> void:
	var policy: GDScript = load("res://addons/godot_mcp/utils/vibe_coding_policy.gd")
	_assert_blocked(policy.evaluate_editor_focus(true, {}), "policy editor focus")
	_assert_blocked(policy.evaluate_runtime_window(true, {}), "policy runtime window")
	_assert_not_quiet_block(policy.evaluate_editor_focus(true, {"allow_ui_focus": true}), "policy editor focus")
	_assert_not_quiet_block(policy.evaluate_runtime_window(true, {"allow_window": true}), "policy runtime window")
	_assert_false(policy.should_grab_focus(true, {}), "script focus should be disabled by quiet mode")
	_assert_true(policy.should_grab_focus(true, {"allow_ui_focus": true, "grab_focus": true}), "allow_ui_focus should preserve requested script focus")
	_assert_true(policy.should_grab_focus(false, {"grab_focus": true}), "normal mode should preserve requested script focus")

func _test_disruptive_tools_are_blocked_by_default() -> void:
	var editor_tools: RefCounted = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()
	_assert_blocked(editor_tools._tool_run_project({}), "run_project")
	_assert_blocked(editor_tools._tool_stop_project({}), "stop_project")
	_assert_blocked(editor_tools._tool_select_node({"node_path": "/root/Main"}), "select_node")
	_assert_blocked(editor_tools._tool_select_file({"file_path": "res://project.godot"}), "select_file")

	var scene_tools: RefCounted = load("res://addons/godot_mcp/tools/scene_tools_native.gd").new()
	_assert_blocked(scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn"}), "open_scene")
	_assert_blocked(scene_tools._tool_close_scene_tab({}), "close_scene_tab")

func _test_overrides_bypass_quiet_mode_gate() -> void:
	var editor_tools: RefCounted = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()
	_assert_not_quiet_block(editor_tools._tool_run_project({"allow_window": true}), "run_project")
	_assert_not_quiet_block(editor_tools._tool_stop_project({"allow_window": true}), "stop_project")
	_assert_not_quiet_block(editor_tools._tool_select_node({"node_path": "/root/Main", "allow_ui_focus": true}), "select_node")
	_assert_not_quiet_block(editor_tools._tool_select_file({"file_path": "res://project.godot", "allow_ui_focus": true}), "select_file")

	var scene_tools: RefCounted = load("res://addons/godot_mcp/tools/scene_tools_native.gd").new()
	_assert_not_quiet_block(scene_tools._tool_open_scene({"scene_path": "res://TestScene.tscn", "allow_ui_focus": true}), "open_scene")
	_assert_not_quiet_block(scene_tools._tool_close_scene_tab({"allow_ui_focus": true}), "close_scene_tab")

func _test_disruptive_tool_schemas_expose_overrides() -> void:
	var editor_capture: MCPServerCore = MCPServerCore.new()
	var editor_tools: RefCounted = load("res://addons/godot_mcp/tools/editor_tools_native.gd").new()
	editor_tools._register_get_editor_state(editor_capture)
	editor_tools._register_run_project(editor_capture)
	editor_tools._register_stop_project(editor_capture)
	editor_tools._register_select_node(editor_capture)
	editor_tools._register_select_file(editor_capture)
	var editor_state_tool: MCPTypes.MCPTool = editor_capture.get_tool("get_editor_state")
	_assert_false(editor_state_tool.input_schema.get("properties", {}).has("allow_window"), "get_editor_state should remain read-only and not expose allow_window")
	_assert_tool_schema_has_property(editor_capture, "run_project", "allow_window")
	_assert_tool_schema_has_property(editor_capture, "stop_project", "allow_window")
	_assert_tool_schema_has_property(editor_capture, "select_node", "allow_ui_focus")
	_assert_tool_schema_has_property(editor_capture, "select_file", "allow_ui_focus")

	var scene_capture: MCPServerCore = MCPServerCore.new()
	var scene_tools: RefCounted = load("res://addons/godot_mcp/tools/scene_tools_native.gd").new()
	scene_tools._register_open_scene(scene_capture)
	scene_tools._register_close_scene_tab(scene_capture)
	_assert_tool_schema_has_property(scene_capture, "open_scene", "allow_ui_focus")
	_assert_tool_schema_has_property(scene_capture, "close_scene_tab", "allow_ui_focus")

	var script_capture: MCPServerCore = MCPServerCore.new()
	var script_tools: RefCounted = load("res://addons/godot_mcp/tools/script_tools_native.gd").new()
	script_tools._register_open_script_at_line(script_capture)
	_assert_tool_schema_has_property(script_capture, "open_script_at_line", "allow_ui_focus")

func _test_plugin_exports_vibe_coding_mode() -> void:
	var plugin_script: GDScript = load("res://addons/godot_mcp/mcp_server_native.gd")
	var property_names: Array[String] = []
	for property in plugin_script.get_script_property_list():
		property_names.append(str(property.get("name", "")))
	_assert_true(property_names.has("vibe_coding_mode"), "plugin should export vibe_coding_mode")
