extends "res://addons/gut/test.gd"

var _classifier = null

func before_each():
	_classifier = load("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd").new()

func after_each():
	_classifier = null

func test_classifier_initializes():
	assert_ne(_classifier, null, "Classifier should initialize")

func test_all_50_tools_registered():
	var all_tools: Array = _classifier.get_all_tools()
	assert_eq(all_tools.size(), 50, "Should have exactly 50 tools registered")

func test_core_tools_count_within_limit():
	var core_tools: Array = _classifier.get_core_tools()
	assert_eq(core_tools.size(), 46, "Should have exactly 46 core tools")

func test_supplementary_tools_count():
	var supp_tools: Array = _classifier.get_supplementary_tools()
	assert_eq(supp_tools.size(), 4, "Should have 4 supplementary tools")

func test_get_tool_category_create_node():
	var cat: String = _classifier.get_tool_category("create_node")
	assert_eq(cat, "core", "create_node should be core")

func test_get_tool_category_execute_editor_script():
	var cat: String = _classifier.get_tool_category("execute_editor_script")
	assert_eq(cat, "supplementary", "execute_editor_script should be supplementary")

func test_get_tool_category_unknown():
	var cat: String = _classifier.get_tool_category("non_existent_tool")
	assert_eq(cat, "core", "Unknown tool should default to core")

func test_get_tool_group_create_node():
	var group: String = _classifier.get_tool_group("create_node")
	assert_eq(group, "Node-Write", "create_node should be in Node-Write group")

func test_get_tool_group_read_script():
	var group: String = _classifier.get_tool_group("read_script")
	assert_eq(group, "Script", "read_script should be in Script group")

func test_get_tool_group_reload_project():
	var group: String = _classifier.get_tool_group("reload_project")
	assert_eq(group, "Editor-Advanced", "reload_project should be in Editor-Advanced group")

func test_get_tool_group_unknown():
	var group: String = _classifier.get_tool_group("non_existent_tool")
	assert_eq(group, "", "Unknown tool should return empty group")

func test_get_all_groups_contains_core_groups():
	var groups: Array = _classifier.get_all_groups()
	assert_true("Node-Read" in groups, "Should contain Node-Read group")
	assert_true("Node-Write" in groups, "Should contain Node-Write group")
	assert_true("Script" in groups, "Should contain Script group")
	assert_true("Scene" in groups, "Should contain Scene group")
	assert_true("Editor" in groups, "Should contain Editor group")

func test_get_all_groups_contains_supplementary_groups():
	var groups: Array = _classifier.get_all_groups()
	assert_true("Editor-Advanced" in groups, "Should contain Editor-Advanced group")
	assert_true("Debug-Advanced" in groups, "Should contain Debug-Advanced group")

func test_get_group_tools_node_write():
	var tools: Array = _classifier.get_group_tools("Node-Write")
	assert_true(tools.size() >= 10, "Node-Write should have 10+ tools")
	assert_true("create_node" in tools, "Node-Write should contain create_node")
	assert_true("delete_node" in tools, "Node-Write should contain delete_node")
	assert_true("update_node_property" in tools, "Node-Write should contain update_node_property")

func test_get_group_tools_script():
	var tools: Array = _classifier.get_group_tools("Script")
	assert_true(tools.size() >= 9, "Script should have 9 tools")
	assert_true("read_script" in tools, "Script should contain read_script")
	assert_true("create_script" in tools, "Script should contain create_script")
	assert_true("modify_script" in tools, "Script should contain modify_script")

func test_is_core_tool():
	assert_true(_classifier.is_core_tool("create_node"), "create_node should be core")
	assert_false(_classifier.is_core_tool("execute_editor_script"), "execute_editor_script should not be core")

func test_is_supplementary_tool():
	assert_true(_classifier.is_supplementary_tool("execute_editor_script"), "execute_editor_script should be supplementary")
	assert_true(_classifier.is_supplementary_tool("reload_project"), "reload_project should be supplementary")
	assert_true(_classifier.is_supplementary_tool("execute_script"), "execute_script should be supplementary")
	assert_true(_classifier.is_supplementary_tool("get_performance_metrics"), "get_performance_metrics should be supplementary")

func test_get_core_max_count():
	assert_eq(_classifier.get_core_max_count(), 40, "Core max count should be 40")

func test_get_all_categories():
	var cats: Array = _classifier.get_all_categories()
	assert_true("core" in cats, "Should contain core category")
	assert_true("supplementary" in cats, "Should contain supplementary category")

func test_classifier_no_duplicate_groups():
	var groups: Array = _classifier.get_all_groups()
	var unique: Array = []
	for g in groups:
		if not g in unique:
			unique.append(g)
	assert_eq(groups.size(), unique.size(), "Groups should not contain duplicates")

func test_classifier_no_duplicate_tools():
	var tools: Array = _classifier.get_all_tools()
	var unique: Array = []
	for t in tools:
		if not t in unique:
			unique.append(t)
	assert_eq(tools.size(), unique.size(), "Tools should not contain duplicates")