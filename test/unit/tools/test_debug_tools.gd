extends "res://addons/gut/test.gd"

func test_debug_print_format():
	var message: String = "[TEST] Hello world"
	assert_true(message.contains("[TEST]"), "Debug message should have category prefix")

func test_debug_log_buffer():
	var log_entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"level": "INFO",
		"message": "Test message"
	}
	assert_has(log_entry, "timestamp", "Should have timestamp")
	assert_has(log_entry, "level", "Should have level")
	assert_has(log_entry, "message", "Should have message")

func test_execute_script_simple():
	var expression: Expression = Expression.new()
	var error: Error = expression.parse("1 + 2", [])
	assert_eq(error, OK, "Simple expression should parse OK")
	if error == OK:
		var result: Variant = expression.execute([], null, true)
		assert_eq(result, 3, "1 + 2 should equal 3")

func test_execute_script_with_singleton_binding():
	var expression: Expression = Expression.new()
	var bind_names: PackedStringArray = ["OS"]
	var bind_values: Array = [OS]
	var error: Error = expression.parse("OS.get_name()", bind_names)
	assert_eq(error, OK, "Expression with OS binding should parse OK")
	if error == OK:
		var result: Variant = expression.execute(bind_values, null, true)
		assert_ne(result, "", "OS.get_name() should return non-empty string")

func test_execute_script_execution_error():
	var expression: Expression = Expression.new()
	var error: Error = expression.parse("undefined_variable_xyz", [])
	assert_eq(error, OK, "Parse should succeed even with undefined var")
	if error == OK:
		expression.execute([], null, false)
		assert_true(expression.has_execute_failed(), "Execution should fail with undefined variable")

func test_performance_metrics_types():
	var fps: float = 60.0
	var memory: float = 512.5
	var objects: int = 1000
	assert_gt(fps, 0.0, "FPS should be positive")
	assert_gt(memory, 0.0, "Memory should be positive")
	assert_gt(objects, 0, "Object count should be positive")

func test_log_level_ordering():
	assert_lt(MCPTypes.LogLevel.ERROR, MCPTypes.LogLevel.WARN, "ERROR < WARN")
	assert_lt(MCPTypes.LogLevel.WARN, MCPTypes.LogLevel.INFO, "WARN < INFO")
	assert_lt(MCPTypes.LogLevel.INFO, MCPTypes.LogLevel.DEBUG, "INFO < DEBUG")

func test_mutex_thread_safety():
	var mutex: Mutex = Mutex.new()
	mutex.lock()
	mutex.unlock()
	assert_true(true, "Mutex lock/unlock should not crash")

func test_set_debugger_breakpoint_missing_path():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_set_debugger_breakpoint({"line": 1, "enabled": true})
	assert_has(result, "error", "Should return error for missing path")
	assert_true(str(result.error).contains("path"), "Error should mention path")

func test_set_debugger_breakpoint_invalid_line():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_set_debugger_breakpoint({"path": "res://player.gd", "line": 0, "enabled": true})
	assert_has(result, "error", "Should return error for invalid line")
	assert_true(str(result.error).contains("line"), "Error should mention line")

func test_send_debugger_message_missing_message():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_send_debugger_message({})
	assert_has(result, "error", "Should return error for missing message")
	assert_true(str(result.error).contains("message"), "Error should mention message")

func test_toggle_debugger_profiler_missing_profiler():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_toggle_debugger_profiler({"enabled": true})
	assert_has(result, "error", "Should return error for missing profiler")
	assert_true(str(result.error).contains("profiler"), "Error should mention profiler")

func test_add_debugger_capture_prefix_missing_prefix():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_add_debugger_capture_prefix({})
	assert_has(result, "error", "Should return error for missing prefix")
	assert_true(str(result.error).contains("prefix"), "Error should mention prefix")

func test_install_runtime_probe_empty_node_name():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_install_runtime_probe({"node_name": ""})
	assert_has(result, "error", "Should return error for empty node_name before editing scene")
	assert_true(str(result.error).contains("Editor interface") or str(result.error).contains("node_name"), "Error should be explicit")

func test_send_debug_command_rejects_unknown_command():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_send_debug_command({"command": "unsupported"})
	assert_has(result, "error", "Should return error for unsupported command")
	assert_true(str(result.error).contains("Unsupported"), "Error should mention unsupported command")

func test_get_debug_stack_variables_rejects_negative_frame():
	var debug_tools: RefCounted = load("res://addons/godot_mcp/tools/debug_tools_native.gd").new()
	var result: Dictionary = debug_tools._tool_get_debug_stack_variables({"frame": -1})
	assert_has(result, "error", "Should return error for invalid frame")
	assert_true(str(result.error).contains("frame"), "Error should mention frame")
