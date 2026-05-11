class_name MCPToolStateManager
extends RefCounted

const STORAGE_VERSION: int = 1
const CONFIG_FILE_NAME: String = "mcp_tool_state.cfg"
const SECTION_TOOLS: String = "tools"
const SECTION_META: String = "meta"

var _classifier = null  # MCPToolClassifier (lazy-loaded for GUT CLI compat)

func _init() -> void:
	_classifier = load("res://addons/godot_mcp/native_mcp/mcp_tool_classifier.gd").new()

func load_state() -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(get_storage_path())
	if err != OK:
		return {}

	if not _validate_config_integrity(config):
		return {}

	var stored_version: int = config.get_value(SECTION_META, "version", 0)
	if stored_version < STORAGE_VERSION:
		_migrate_config(config, stored_version)

	var states: Dictionary = {}
	if config.has_section(SECTION_TOOLS):
		for tool_name in config.get_section_keys(SECTION_TOOLS):
			var enabled: bool = config.get_value(SECTION_TOOLS, tool_name, true)
			states[tool_name] = enabled
	return states

func save_state(enabled_states: Dictionary) -> bool:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_META, "version", STORAGE_VERSION)

	for tool_name in enabled_states:
		config.set_value(SECTION_TOOLS, tool_name, enabled_states[tool_name])

	_add_checksum(config)
	var err: Error = config.save(get_storage_path())
	return err == OK

func apply_states_to_server(server_core: MCPServerCore, states: Dictionary) -> void:
	var applied_count: int = 0
	for tool_name in states:
		if server_core.has_tool(tool_name):
			var enabled: bool = states[tool_name]
			server_core.set_tool_enabled(tool_name, enabled)
			applied_count += 1

func capture_states_from_server(server_core: MCPServerCore) -> Dictionary:
	var states: Dictionary = {}
	var tools = server_core.get_registered_tools()
	for tool_info in tools:
		states[tool_info["name"]] = tool_info["enabled"]
	return states

func validate_core_tool_limit(states: Dictionary) -> Dictionary:
	var core_tools: Array[String] = _classifier.get_core_tools()
	var enabled_core_count: int = 0
	var disabled_core: Array[String] = []
	var core_limit: int = _classifier.get_core_max_count()

	for tool_name in core_tools:
		var is_enabled: bool = states.get(tool_name, true)
		if is_enabled:
			enabled_core_count += 1

	var over_limit: bool = enabled_core_count > core_limit
	return {
		"over_limit": over_limit,
		"enabled_core_count": enabled_core_count,
		"core_limit": core_limit,
		"message": "Core tools enabled: %d/%d" % [enabled_core_count, core_limit]
	}

func get_storage_path() -> String:
	return "user://" + CONFIG_FILE_NAME

func _validate_config_integrity(config: ConfigFile) -> bool:
	if not config.has_section(SECTION_META):
		return false
	if not config.has_section_key(SECTION_META, "checksum"):
		return true

	var stored_checksum: String = config.get_value(SECTION_META, "checksum", "")
	var raw: String = _serialize_config_data(config)
	var computed: String = raw.md5_text()
	return stored_checksum == computed

func _add_checksum(config: ConfigFile) -> void:
	var raw: String = _serialize_config_data(config)
	var checksum: String = raw.md5_text()
	config.set_value(SECTION_META, "checksum", checksum)

func _serialize_config_data(config: ConfigFile) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if config.has_section(SECTION_TOOLS):
		for key in config.get_section_keys(SECTION_TOOLS):
			var val = config.get_value(SECTION_TOOLS, key)
			lines.append("tools/" + key + "=" + str(val))
	return "\n".join(lines)

func _migrate_config(config: ConfigFile, from_version: int) -> void:
	if from_version < 1:
		config.set_value(SECTION_META, "version", 1)
