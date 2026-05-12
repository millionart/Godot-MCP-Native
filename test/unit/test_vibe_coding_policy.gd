extends "res://addons/gut/test.gd"

var _policy_script: GDScript = null

func before_each():
	_policy_script = load("res://addons/godot_mcp/utils/vibe_coding_policy.gd")

func after_each():
	_policy_script = null

func test_quiet_mode_blocks_editor_focus_without_override():
	var result: Dictionary = _policy_script.evaluate_editor_focus(true, {})
	assert_true(result["blocked"], "Quiet mode should block editor focus by default")
	assert_eq(result["reason"], "vibe_coding_mode", "Blocked result should identify vibe coding mode")

func test_editor_focus_override_allows_focus():
	var result: Dictionary = _policy_script.evaluate_editor_focus(true, {"allow_ui_focus": true})
	assert_false(result["blocked"], "Explicit allow_ui_focus should bypass quiet mode")

func test_quiet_mode_forces_script_open_without_focus():
	assert_false(_policy_script.should_grab_focus(true, {}), "Quiet mode should not grab script editor focus")
	assert_true(_policy_script.should_grab_focus(false, {"grab_focus": true}), "Normal mode should preserve requested focus")

func test_quiet_mode_blocks_runtime_window_without_override():
	var result: Dictionary = _policy_script.evaluate_runtime_window(true, {})
	assert_true(result["blocked"], "Quiet mode should block project run windows by default")
	assert_false(_policy_script.evaluate_runtime_window(true, {"allow_window": true})["blocked"], "Explicit allow_window should bypass quiet mode")
