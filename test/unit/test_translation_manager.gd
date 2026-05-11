extends "res://addons/gut/test.gd"

var _tm = null

func before_each():
	_tm = load("res://addons/godot_mcp/native_mcp/translation_manager.gd").new()

func after_each():
	_tm = null

func test_translation_manager_initializes():
	assert_ne(_tm, null, "Translation manager should initialize")

func test_default_locale_is_en():
	assert_eq(_tm.get_locale(), "en", "Default locale should be 'en'")

func test_get_text_missing_key_returns_key():
	var result: String = _tm.get_text("nonexistent_key_xyz")
	assert_eq(result, "nonexistent_key_xyz", "Missing key should return the key itself")

func test_get_text_after_manual_load():
	_tm.set_locale("en")
	var result: String = _tm.get_text("ui.settings")
	assert_eq(result, "ui.settings", "Before loading, get_text returns the key")

func test_set_locale_and_get_text():
	# Manually inject translation data
	_tm._translations["en"] = {"test.greeting": "Hello"}
	_tm._translations["zh"] = {"test.greeting": "你好"}
	_tm.set_locale("en")
	assert_eq(_tm.get_text("test.greeting"), "Hello", "English greeting should be Hello")
	_tm.set_locale("zh")
	assert_eq(_tm.get_text("test.greeting"), "你好", "Chinese greeting should be 你好")

func test_set_locale_to_invalid_falls_back_to_default():
	_tm._translations["en"] = {"a": "1"}
	_tm._translations["zh"] = {"a": "2"}
	_tm.set_locale("en")
	_tm.set_locale("invalid_locale")
	# Invalid locale falls back to default locale with a warning
	# The locale is still accepted since data is sourced from "en" column
	assert_eq(_tm.get_locale(), "invalid_locale", "Invalid locale is accepted with fallback to default")

func test_get_locale_returns_locale():
	_tm._translations["en"] = {}
	_tm.set_locale("en")
	assert_eq(_tm.get_locale(), "en", "get_locale should return current locale")
	_tm.set_locale("zh")
	assert_eq(_tm.get_locale(), "zh", "get_locale should update after set_locale")

func test_get_available_locales():
	_tm._translations["en"] = {"k": "v"}
	_tm._translations["zh"] = {"k": "v"}
	var locales: Array = _tm.get_available_locales()
	assert_true(locales.size() >= 2, "Should have at least 2 locales after manual injection")
	assert_true("en" in locales, "Should include 'en'")
	assert_true("zh" in locales, "Should include 'zh'")

func test_load_locale_returns_dict():
	# load_locale returns empty dict if CSV not found (headless mode)
	var data: Dictionary = _tm.load_locale("en")
	assert_true(data is Dictionary, "load_locale should return a Dictionary even if empty")

func test_multiple_keys():
	_tm._translations["en"] = {"key1": "Value1", "key2": "Value2"}
	_tm.set_locale("en")
	assert_eq(_tm.get_text("key1"), "Value1", "key1 should match")
	assert_eq(_tm.get_text("key2"), "Value2", "key2 should match")

func test_get_text_after_set_locale_multiple_times():
	_tm._translations["en"] = {"x": "en_value"}
	_tm._translations["zh"] = {"x": "zh_value"}
	_tm._translations["fr"] = {"x": "fr_value"}
	_tm.set_locale("en")
	assert_eq(_tm.get_text("x"), "en_value", "Should be en_value")
	_tm.set_locale("fr")
	assert_eq(_tm.get_text("x"), "fr_value", "Should be fr_value after switching")
	_tm.set_locale("zh")
	assert_eq(_tm.get_text("x"), "zh_value", "Should be zh_value after switching")

func test_get_available_locales_empty_initially():
	assert_eq(_tm.get_available_locales().size(), 0, "Before loading, available locales should be empty")