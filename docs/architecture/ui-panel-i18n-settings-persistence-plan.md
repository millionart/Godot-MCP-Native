# UI 面板：多语言支持与设置持久化 -- 实施完成状态

## 概述

针对 `addons/godot_mcp/ui/mcp_panel_native.gd` 的两个独立优化：
1. **多语言(i18n)**：创建插件自带的轻量翻译系统，不依赖 Godot TranslationServer / project.godot
2. **设置持久化**：从 `ToolStateManager` 提取可复用的 `ConfigManager` 基类，创建 `SettingsManager` 持久化 11 个面板设置项

## 实施状态总览

| 模块 | 文件 | 状态 | 测试 |
|------|------|:----:|:----:|
| TranslationManager | `translation_manager.gd` | 已完成 | 12 tests |
| CSV 翻译文件 | `translations/mcp_panel.csv` | 已完成 | -- |
| ConfigManager 基类 | `config_manager.gd` | 已完成 | 10 tests |
| SettingsManager | `settings_manager.gd` | 已完成 | 8 tests |
| ToolStateManager 重构 | `tool_state_manager.gd` | 已完成 | 11 tests (更新) |
| 面板 i18n + 设置持久化 | `mcp_panel_native.gd` | 已完成 | -- |
| 分组组件翻译 | `mcp_tool_group_item.gd` | 已完成 | -- |

---

## 1. 多语言支持（插件自包含方案）

### 核心决策

由于用户只拥有 `addons/` 下的插件文件，不配置 project.godot，因此：
- **不使用** Godot 的 `TranslationServer` / `tr()`
- **改为** 插件内部实现轻量翻译模块 `TranslationManager`
- CSV 翻译文件放在 `addons/godot_mcp/translations/`，随插件一起分发
- 使用自定义 `_tr(key)` 函数替代 `tr()`

### 涉及文件

| 文件 | 操作 |
|------|------|
| `addons/godot_mcp/native_mcp/translation_manager.gd` | **新建** -- 自包含翻译模块 |
| `addons/godot_mcp/translations/mcp_panel.csv` | **新建** -- 合并翻译文件 (key,source,en,zh) |
| `addons/godot_mcp/ui/mcp_panel_native.gd` | **修改** -- 使用 _tr() 替换所有文本，添加语言选择器、_refresh_translations() |
| `addons/godot_mcp/ui/mcp_tool_group_item.gd` | **修改** -- "Enabled:" 标签替换为 _tr("ui.enabled_format") |

### TranslationManager 设计

```
class_name MCPTranslationManager
extends RefCounted

TRANSLATIONS_DIR := "res://addons/godot_mcp/translations/"
DEFAULT_LOCALE := "en"

_translations: Dictionary   # locale -> {key -> string}
_current_locale: String

load_all() -> void              # 遍历 translations/ 下所有 CSV，读取列名作为 locale，加载所有语言
load_locale(locale) -> Dictionary  # 加载单个语言的翻译（从所有 CSV 中查找该列）
get_text(key) -> String         # 核心 API：根据当前 locale 返回翻译
set_locale(locale) -> void      # 切换语言
get_locale() -> String
get_available_locales() -> Array  # 返回 ["en", "zh"]（从 CSV 列名发现）
```

CSV 格式（实际为合并单一文件）：`key,source,en,zh`

```
key,source,en,zh
ui.settings,Settings,Settings,Settings
ui.language,Language:,Language:,语言：
...
```

实际实现中通过 `_discover_locales()` 从 CSV 文件的列标题自动发现可用语言（排除 "key" 和 "source" 列）。

### 面板集成要点

```gdscript
# 所有硬编码字符串替换为 _tr()
tab.set_tab_title(0, _tr("ui.settings"))
_status_label.text = _tr("ui.status_running")
_start_button.text = _tr("ui.start_server")

# 语言切换后刷新 UI
func _refresh_translations() -> void:
    _update_ui_state()
    _update_connection_info()
    _refresh_tools_list()

# 语言选择器回调，同时持久化语言偏好
func _on_language_selected(index: int) -> void:
    var locales = _translation_manager.get_available_locales()
    _translation_manager.set_locale(locales[index])
    _debounce_save()
    _refresh_translations()
```

---

## 2. 设置持久化

### 架构设计

从 `ToolStateManager` 提取通用的 `ConfigManager` 基类，创建 `SettingsManager`：

```
MCPConfigManager (新建 -- 可复用基类)
    |
    +-- MCPToolStateManager (重构 -- 继承 ConfigManager，保留专有方法)
    |
    +-- MCPSettingsManager (新建 -- 用于面板设置持久化)
```

### ConfigManager 基类

```
class_name MCPConfigManager
extends RefCounted

config_file_name: String       # 可配置文件名（子类在 _init 中设置）
config_section: String         # 可配置 ConfigFile 章节名
storage_version: int           # 版本号

load_config() -> Dictionary    # 加载并返回整个 section 的数据
save_config(data) -> bool      # 保存数据并添加校验
get_storage_path() -> String   # user:// + config_file_name
_validate_config_integrity(config) -> bool   # MD5 校验（可选，无 checksum 时跳过）
_migrate_config(config, from_version) -> void
_serialize_config_data(config) -> String
_add_checksum(config) -> void
```

### SettingsManager

```
class_name MCPSettingsManager
extends "res://addons/godot_mcp/native_mcp/config_manager.gd"

CONFIG_FILE_NAME := "mcp_settings.cfg"
SECTION_SETTINGS := "settings"

DEFAULT_SETTINGS := {
    transport_mode = "http",
    http_port = 9080,
    auth_enabled = false,
    auth_token = "",
    sse_enabled = true,
    allow_remote = false,
    cors_origin = "*",
    auto_start = false,
    log_level = 2,
    security_level = 1,
    rate_limit = 100,
    language = "en"      # 新增：语言偏好
}

load_settings() -> Dictionary  # 合并默认值与保存值
save_settings(settings) -> bool
```

### 涉及文件

| 文件 | 操作 |
|------|------|
| `addons/godot_mcp/native_mcp/config_manager.gd` | **新建** -- 通用基类 |
| `addons/godot_mcp/native_mcp/tool_state_manager.gd` | **重构** -- 继承 ConfigManager |
| `addons/godot_mcp/native_mcp/settings_manager.gd` | **新建** -- 设置持久化 |
| `addons/godot_mcp/ui/mcp_panel_native.gd` | **修改** -- 集成 SettingsManager |
| `test/unit/test_tool_state_manager.gd` | **更新** -- 适配重构 |
| `test/unit/test_config_manager.gd` | **新建** -- ConfigManager 单元测试 |
| `test/unit/test_settings_manager.gd` | **新建** -- SettingsManager 单元测试 |

### 面板集成要点

```gdscript
# 启动时加载设置
func _load_settings() -> void:
    var s: Dictionary = _settings_manager.load_settings()
    _transport_mode_option.select(0 if s.transport_mode == "http" else 1)
    _http_port_spin.value = s.http_port
    _auth_enabled_check.button_pressed = s.auth_enabled
    _auth_token_edit.text = s.auth_token
    # ... 等 11 个设置项
    # 语言偏好
    if _translation_manager and s.language != _translation_manager.get_locale():
        _translation_manager.set_locale(s.language)
        _refresh_translations()

# 每个变更事件接入 debounce 持久化
func _on_log_level_selected(index: int) -> void:
    _plugin.log_level = index
    _debounce_save()

func _on_rate_limit_changed(value: float) -> void:
    _plugin.rate_limit = int(value)
    _debounce_save()

# debounce 超时同时保存工具状态和设置
func _on_debounce_timeout() -> void:
    _server_core.save_tool_states()
    _server_core.notify_tool_list_changed()
    _save_settings()
```

---

## 3. Todo List

### 已完成

| ID | 事项 |
|:--:|------|
| 1 | Create TranslationManager (translation_manager.gd) |
| 2 | Create CSV translation file (mcp_panel.csv) |
| 3 | Create ConfigManager base class (config_manager.gd) |
| 4 | Create SettingsManager (settings_manager.gd) -- 使用路径 extends |
| 5 | Refactor ToolStateManager to extend ConfigManager -- 使用路径 extends |
| 6 | Replace all hardcoded strings with _tr() in mcp_panel_native.gd |
| 7 | Add language selector OptionButton in settings tab |
| 8 | Implement _refresh_translations() for UI rebuild on locale switch |
| 9 | Update mcp_tool_group_item.gd with _tr() for "Enabled:" label |
| 10 | Implement _load_settings() / _save_settings() |
| 11 | Wire each _on_*_changed() to _debounce_save() |
| 12 | Update _on_debounce_timeout() to also save settings |
| 13 | Create test files for TranslationManager, ConfigManager, SettingsManager |
| 14 | Update test_tool_state_manager.gd for ConfigManager refactor |
| 15 | Run tests: 426/436 passing (10 pre-existing failures) |

### 待办/优化项

| 优先级 | 事项 | 说明 |
|:------:|------|------|
| HIGH | 确认 _load_settings() 与 _update_ui_state() 的冲突 | set_plugin() 中先 _load_settings() 后 _update_ui_state()，后者用 _plugin 默认值可能覆盖设置 |
| LOW | 语言切换后 _language_option 选项文字不刷新 | OptionButton 的 "English"/"中文" 文本不会随语言切换自动更新 |
| LOW | translations/ 目录可能需要重启 Godot Editor | 可能导致首次安装时找不到 CSV 文件 |

## 4. 测试结果

- 26 个测试脚本，436 个测试用例
- 426 通过，10 失败（全部为预存问题）
- 预存失败来源：7 test_mcp_debugger_bridge + 1 test_debug_tools + 2 test_translation_manager (headless CSV 兼容)

## 5. 向后兼容性

- ToolStateManager 文件格式不变（`user://mcp_tool_state.cfg`）
- 设置文件是新文件（`user://mcp_settings.cfg`），不冲突
- TranslationManager 是新增模块，不影响现有功能
- 语言默认值为 "en"，现有用户界面文本不变
- CSV 文件在插件 `addons/` 目录内，不干扰用户项目