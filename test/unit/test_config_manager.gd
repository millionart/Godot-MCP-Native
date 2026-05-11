extends "res://addons/gut/test.gd"

var _cm = null

func before_each():
	_cm = load("res://addons/godot_mcp/native_mcp/config_manager.gd").new()

func after_each():
	if _cm:
		var path: String = _cm.get_storage_path()
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_cm = null

func test_config_manager_initializes():
	assert_ne(_cm, null, "Config manager should initialize")

func test_default_properties():
	assert_eq(_cm.config_file_name, "mcp_config.cfg", "Default file name should be mcp_config.cfg")
	assert_eq(_cm.config_section, "config", "Default section should be 'config'")
	assert_eq(_cm.storage_version, 1, "Default storage version should be 1")

func test_save_and_load_config():
	var test_data: Dictionary = {"test_key": "test_value", "number_key": 42}
	var saved: bool = _cm.save_config(test_data)
	assert_true(saved, "Save should succeed")

	var loaded: Dictionary = _cm.load_config()
	assert_eq(loaded.size(), 2, "Should load 2 keys")
	assert_eq(loaded["test_key"], "test_value", "test_key should match")
	assert_eq(loaded["number_key"], 42, "number_key should match")

func test_save_and_load_with_checksum():
	var test_data: Dictionary = {"keep_me": true}
	_cm.save_config(test_data)
	var loaded: Dictionary = _cm.load_config()
	assert_eq(loaded["keep_me"], true, "Data should persist with checksum verification")

func test_validate_config_integrity_no_meta():
	var config: ConfigFile = ConfigFile.new()
	config.set_value("tools", "test", true)
	var result: bool = _cm._validate_config_integrity(config)
	assert_false(result, "Config without meta section should be invalid")

func test_get_storage_path():
	var path: String = _cm.get_storage_path()
	assert_true(path.ends_with("mcp_config.cfg"), "Path should end with mcp_config.cfg")

func test_empty_config_returns_empty():
	var result: Dictionary = _cm.load_config()
	assert_true(result is Dictionary, "Result should be a Dictionary")


func test_config_file_name_settable():
	_cm.config_file_name = "custom_test.cfg"
	assert_eq(_cm.config_file_name, "custom_test.cfg", "File name should be settable")

func test_config_section_settable():
	_cm.config_section = "custom_section"
	assert_eq(_cm.config_section, "custom_section", "Section should be settable")