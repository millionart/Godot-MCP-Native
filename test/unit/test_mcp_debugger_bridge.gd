extends "res://addons/gut/test.gd"

var _bridge: MCPDebuggerBridge = null

func before_each():
	_bridge = load("res://addons/godot_mcp/native_mcp/mcp_debugger_bridge.gd").new()

func after_each():
	_bridge = null

func test_get_sessions_info_empty_before_registered_with_editor():
	var sessions: Array = _bridge.get_sessions_info()
	assert_eq(sessions.size(), 0, "Unregistered bridge should have no debugger sessions")

func test_for_each_session_returns_no_sessions_when_unregistered():
	var result: Dictionary = _bridge.set_breakpoint("res://player.gd", 1, true)
	assert_eq(result.status, "no_sessions", "Unregistered bridge should report no sessions")
	assert_eq(result.sessions_updated, 0, "No sessions should be updated")

func test_capture_prefix_defaults_to_mcp():
	assert_true(_bridge._has_capture("mcp"), "Bridge should capture mcp-prefixed debugger messages by default")
	assert_false(_bridge._has_capture("other"), "Bridge should ignore unrelated prefixes by default")

func test_add_capture_prefix():
	_bridge.add_capture_prefix("ai")
	assert_true(_bridge._has_capture("ai"), "Added prefix should be captured")

func test_capture_stores_messages():
	var captured: bool = _bridge._capture("mcp:test", ["hello"], 2)
	assert_true(captured, "Capture should report handled")
	var result: Dictionary = _bridge.get_captured_messages(10, 0, "asc")
	assert_eq(result.count, 1, "Should return one captured message")
	assert_eq(result.messages[0].session_id, 2, "Should preserve session id")
	assert_eq(result.messages[0].message, "mcp:test", "Should preserve message name")

func test_stack_dump_signal_updates_latest_frames():
	var frames: Array = [{"frame": 0, "file": "res://player.gd", "function": "_ready", "line": 12}]
	_bridge._on_stack_dump(frames)
	assert_eq(_bridge.get_latest_stack_dump().size(), 1, "Should store latest stack frames")
	assert_eq(_bridge.get_latest_stack_dump()[0].file, "res://player.gd", "Should preserve stack frame data")

func test_stack_frame_var_decodes_variable_payload():
	_bridge._on_stack_frame_vars(1)
	_bridge._on_stack_frame_var(["speed", 0, TYPE_FLOAT, 12.5])
	var variables: Array = _bridge.get_latest_stack_variables(0)
	assert_eq(variables.size(), 1, "Should store latest stack variable")
	assert_eq(variables[0].name, "speed", "Should decode variable name")
	assert_eq(variables[0].scope, "local", "Should decode variable scope")
	assert_eq(variables[0].type, "float", "Should decode variable type")
	assert_eq(variables[0].value, 12.5, "Should preserve variable value")
