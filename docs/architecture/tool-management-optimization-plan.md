# 工具管理策略优化计划

**日期**: 2026-05-11\
**作者**: AI Assistant\
**目标**: 解决AI工具对MCP工具数量的限制问题，通过工具分类体系、UI组管理、列表同步机制三位一体的优化方案

***

## 1. 概述

### 1.1 背景

当前 Godot MCP Native 项目实现了 **50 个 MCP 工具**，分布在 6 大功能模块中：

| 类别            | 工具数量 | 源文件                       |
| ------------- | ---- | ------------------------- |
| Node Tools    | 16   | `node_tools_native.gd`    |
| Script Tools  | 9    | `script_tools_native.gd`  |
| Scene Tools   | 6    | `scene_tools_native.gd`   |
| Editor Tools  | 8    | `editor_tools_native.gd`  |
| Debug Tools   | 6    | `debug_tools_native.gd`   |
| Project Tools | 5    | `project_tools_native.gd` |

**核心问题**：

1. 部分AI客户端（如 Claude Desktop）对MCP Server注册的工具总数有上限限制（通常40个）
2. 当前50个工具已超出常见限制，导致部分工具不可用
3. 没有按组批量管理工具的启用/禁用功能
4. 工具启用状态无持久化存储，每次重启后恢复默认
5. 工具列表变更后不能主动通知MCP客户端

### 1.2 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                     MCP Server (Godot Plugin)                    │
├─────────────────────────────────────────────────────────────────┤
│                   Tool Management Layer (新增)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    ToolClassifier                          │  │
│  │  • 核心工具集 (Core) ≤ 40个                                │  │
│  │  • 补充工具集 (Supplementary)                              │  │
│  │  • 功能分组 (Node/Script/Scene/Editor/Debug/Project)       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           │                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    ToolStateManager                        │  │
│  │  • 组级别启用/禁用状态管理                                  │  │
│  │  • 持久化存储 (ConfigFile + 校验)                           │  │
│  │  • 状态变更事件推送                                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           │                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                ToolListSyncService                        │  │
│  │  • 工具列表变更检测                                        │  │
│  │  • MCP客户端同步推送 (通过 notifications/tools/list_changed)│  │
│  │  • 状态一致性校验                                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           │                                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              UI: Tool Manager Panel                        │  │
│  │  • 组级别启用/关闭 CheckBox                                 │  │
│  │  • 单个工具启用/关闭 CheckBox                                │  │
│  │  • 实时刷新与状态同步                                       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 设计原则

1. **非侵入式**：不改变现有工具的注册和调用逻辑
2. **向后兼容**：现有配置和客户端无需修改即可使用
3. **数据安全**：持久化数据需做校验保护，防止篡改
4. **实时反馈**：用户操作后界面立即响应，状态及时同步客户端

***

## 2. 工具分类体系

### 2.1 分类层级结构

```
工具总集 (50)
├── 核心工具 (Core) — ≤ 40个
│   ├── Node-Read (只读节点操作)
│   │   ├── list_nodes
│   │   ├── get_scene_tree
│   │   ├── get_node_properties
│   │   ├── get_node_groups
│   │   └── find_nodes_in_group
│   │
│   ├── Node-Write (写入节点操作)
│   │   ├── create_node
│   │   ├── delete_node
│   │   ├── update_node_property
│   │   ├── duplicate_node
│   │   ├── move_node
│   │   ├── rename_node
│   │   ├── add_resource
│   │   ├── set_anchor_preset
│   │   ├── connect_signal
│   │   ├── disconnect_signal
│   │   └── set_node_groups
│   │
│   ├── Script (脚本操作)
│   │   ├── list_project_scripts
│   │   ├── read_script
│   │   ├── create_script
│   │   ├── modify_script
│   │   ├── analyze_script
│   │   ├── get_current_script
│   │   ├── attach_script
│   │   ├── validate_script
│   │   └── search_in_files
│   │
│   ├── Scene (场景操作)
│   │   ├── create_scene
│   │   ├── save_scene
│   │   ├── open_scene
│   │   ├── get_current_scene
│   │   ├── get_scene_structure
│   │   └── list_project_scenes
│   │
│   ├── Editor (编辑器操作)
│   │   ├── get_editor_state
│   │   ├── run_project
│   │   ├── stop_project
│   │   ├── get_selected_nodes
│   │   ├── set_editor_setting
│   │   ├── get_editor_screenshot
│   │   └── get_signals
│   │
│   ├── Debug (调试操作)
│   │   ├── get_editor_logs
│   │   ├── debug_print
│   │   └── clear_output
│   │
│   └── Project (项目操作)
│       ├── get_project_info
│       ├── get_project_settings
│       ├── list_project_resources
│       ├── create_resource
│       └── get_project_structure
│
└── 补充工具 (Supplementary) — 按需启用
    ├── Editor-Advanced (高级编辑器操作)
    │   ├── reload_project
    │   └── execute_editor_script (含 openWorldHint)
    │
    └── Debug-Advanced (高级调试操作)
        ├── execute_script
        └── get_performance_metrics
```

### 2.2 核心/补充分类标准

| 分类                     | 判断标准                | 示例                                                   |
| ---------------------- | ------------------- | ---------------------------------------------------- |
| **核心 (Core)**          | 日常场景编辑必需的常用操作       | `create_node`, `update_node_property`, `read_script` |
| **补充 (Supplementary)** | 高级/特定场景需要的操作，或有潜在风险 | `execute_editor_script`, `reload_project`            |

**核心工具数量控制**：初始核心工具集为 **44 个**，需要精简到 ≤40 个。方案如下：

#### 方案A（推荐）：合并同类工具

| 待合并工具                                    | 合并方案                                               |
| ---------------------------------------- | -------------------------------------------------- |
| `get_scene_tree` + `get_scene_structure` | 保留 `get_scene_tree`，废弃 `get_scene_structure`（功能重叠） |
| `run_project` + `stop_project`           | 合并为 `toggle_project_run`，通过参数控制启动/停止               |

#### 方案B：将以下4个工具降级为补充工具 使用该方案

| 工具名                       | 降级理由                     |
| ------------------------- | ------------------------ |
| `get_editor_screenshot`   | 非常用操作，仅特定场景需要            |
| `reload_project`          | 高级维护操作，日常编辑不常用           |
| `execute_editor_script`   | 高风险操作，包含 `openWorldHint` |
| `get_performance_metrics` | 诊断专用，非日常编辑所需             |

### 2.3 MCPTool 类扩展

在 `mcp_types.gd` 的 `MCPTool` 类中新增分类字段：

```gdscript
class MCPTool:
    var name: String = ""
    var description: String = ""
    var input_schema: Dictionary = {}
    var output_schema: Dictionary = {}
    var annotations: Dictionary = {}
    var callable: Callable = Callable()
    var enabled: bool = true
    
    # === 新增字段（工具分类管理）===
    var category: String = "core"       # "core" | "supplementary"
    var group: String = ""              # "Node-Read" | "Node-Write" | "Script" | "Scene" | "Editor" | "Editor-Advanced" | "Debug" | "Debug-Advanced" | "Project"
    
    func to_dict() -> Dictionary:
        var result: Dictionary = {
            "name": name,
            "description": description,
            "inputSchema": input_schema
        }
        if not output_schema.is_empty():
            result["outputSchema"] = output_schema
        if not annotations.is_empty():
            result["annotations"] = annotations
        # 新增：可选暴露分类信息
        # result["x_category"] = category
        # result["x_group"] = group
        return result
```

### 2.4 需要修改的文件

| 文件                                               | 修改内容                               |
| ------------------------------------------------ | ---------------------------------- |
| `addons/godot_mcp/native_mcp/mcp_types.gd`       | MCPTool类新增 `category` 和 `group` 字段 |
| `addons/godot_mcp/tools/node_tools_native.gd`    | 每个 `register_tool` 调用中添加分类参数       |
| `addons/godot_mcp/tools/script_tools_native.gd`  | 同上                                 |
| `addons/godot_mcp/tools/scene_tools_native.gd`   | 同上                                 |
| `addons/godot_mcp/tools/editor_tools_native.gd`  | 同上                                 |
| `addons/godot_mcp/tools/debug_tools_native.gd`   | 同上                                 |
| `addons/godot_mcp/tools/project_tools_native.gd` | 同上                                 |
| `addons/godot_mcp/native_mcp/mcp_server_core.gd` | 新增分类注册API、tools/list过滤逻辑           |

***

## 3. 工具状态管理器 (ToolStateManager)

### 3.1 功能描述

集中管理所有工具的启用/禁用状态，支持：

- 组级别批量启用/禁用
- 单个工具启用/禁用
- 状态持久化（本地存储）
- 数据安全防护（校验和加密）
- 状态变更事件通知

### 3.2 持久化方案

#### 3.2.1 存储格式

使用 `ConfigFile` 格式存储，路径：`user://mcp_tool_state.cfg`

```ini
[tool_state]
version=1
checksum="a1b2c3d4..."

[core]
count=44
max_count=40

[supplementary]
count=6

[groups]
Node-Read=enabled
Node-Write=enabled
Script=enabled
Scene=enabled
Editor=enabled
Editor-Advanced=disabled
Debug=enabled
Debug-Advanced=disabled
Project=enabled

[tools]
create_node=enabled
delete_node=enabled
# ... 每个工具的状态

[meta]
last_modified=2026-05-11T10:30:00
godot_version=4.3
plugin_version=1.0.0
```

#### 3.2.2 数据安全防护

```gdscript
# === 安全校验机制 ===

# 1. 版本兼容性检查
const STORAGE_VERSION: int = 1

# 2. 校验和生成
func _generate_checksum(data: Dictionary) -> String:
    var data_str: String = JSON.stringify(data)
    return data_str.md5_text()

# 3. 结构完整性验证
func _validate_structure(config: ConfigFile) -> bool:
    # 检查必要section是否存在
    if not config.has_section("tool_state"):
        return false
    if not config.has_section_key("tool_state", "version"):
        return false
    # 检查版本兼容性
    var version: int = config.get_value("tool_state", "version", 0)
    if version > STORAGE_VERSION:
        return false  # 未知的更高版本
    # 检查校验和
    var stored_checksum: String = config.get_value("tool_state", "checksum", "")
    if stored_checksum.is_empty():
        return false
    # 重新计算校验和并比对
    var calculated: String = _recalculate_checksum(config)
    if calculated != stored_checksum:
        return false  # 数据被篡改或损坏
    return true

# 4. 字段白名单验证
func _validate_tool_name(name: String) -> bool:
    # 只允许注册过的工具名
    return _registered_tools.has(name)

func _validate_group_name(name: String) -> bool:
    # 只允许预定义的组名
    var valid_groups: Array = [
        "Node-Read", "Node-Write", "Script", "Scene",
        "Editor", "Editor-Advanced", "Debug", "Debug-Advanced", "Project"
    ]
    return name in valid_groups
```

#### 3.2.3 升级兼容性

```gdscript
# 版本升级路径
func _migrate_config(config: ConfigFile, from_version: int) -> ConfigFile:
    match from_version:
        0:
            # v0 → v1：初始迁移
            config.set_value("tool_state", "version", 1)
            config.set_value("tool_state", "checksum", _generate_checksum(...))
        1:
            # v1 → v2：预留（后续版本）
            pass
        _:
            push_error("Unknown storage version: " + str(from_version))
    return config
```

### 3.3 核心接口

```gdscript
# ToolStateManager.gd
class_name ToolStateManager
extends RefCounted

signal tool_state_changed(tool_name: String, enabled: bool)
signal group_state_changed(group_name: String, enabled: bool)
signal tool_list_updated()  # 工具列表整体变更

# === 组级别操作 ===
func set_group_enabled(group_name: String, enabled: bool) -> void
func is_group_enabled(group_name: String) -> bool
func get_group_tools(group_name: String) -> Array[String]
func get_all_groups() -> Array[String]

# === 单个工具操作 ===
func set_tool_enabled(tool_name: String, enabled: bool) -> void
func is_tool_enabled(tool_name: String) -> bool

# === 持久化 ===
func load_state() -> bool
func save_state() -> bool
func reset_to_defaults() -> void

# === 核心工具限制 ===
func get_core_tools_count() -> int
func is_core_limit_exceeded() -> bool
func validate_core_limit() -> Dictionary  # 返回合规报告
```

### 3.4 需要创建的文件

| 文件路径                                                    | 说明            |
| ------------------------------------------------------- | ------------- |
| `addons/godot_mcp/native_mcp/mcp_tool_state_manager.gd` | 工具状态管理器       |
| `addons/godot_mcp/native_mcp/mcp_tool_classifier.gd`    | 工具分类器（管理分类规则） |

### 3.5 需要修改的文件

| 文件                                               | 修改内容                                     |
| ------------------------------------------------ | ---------------------------------------- |
| `addons/godot_mcp/native_mcp/mcp_server_core.gd` | 集成ToolStateManager，修改 `set_tool_enabled` |
| `addons/godot_mcp/mcp_server_native.gd`          | 初始化时加载持久化状态                              |

***

## 4. UI: Tool Manager 面板优化

### 4.1 界面布局

```
┌─────────────────────────────────────────────────────────────┐
│ Tool Manager                                  [Refresh]     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 状态栏: Core: 44/40 (超出)   Supplementary: 6  总计: 50 │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │ 核心工具 (Core)                    [全部启用] [全部禁用]│ │ │
│ │ │                                                     │ │ │
│ │ │ ☑ Node-Read (5) ──── 展开 ▼                         │ │ │
│ │ │   ☑ list_nodes                                      │ │ │
│ │ │   ☑ get_scene_tree                                  │ │ │
│ │ │   ...                                               │ │ │
│ │ │                                                     │ │ │
│ │ │ ☑ Node-Write (11) ── 展开 ▼                         │ │ │
│ │ │   ☑ create_node                                     │ │ │
│ │ │   ☑ delete_node                                     │ │ │
│ │ │   ...                                               │ │ │
│ │ │                                                     │ │ │
│ │ │ ☑ Script (9) ────── 展开 ▼                          │ │ │
│ │ │ ☑ Scene (6) ─────── 展开 ▼                          │ │ │
│ │ │ ☑ Editor (7) ────── 展开 ▼                          │ │ │
│ │ │ ☑ Debug (3) ────── 展开 ▼                           │ │ │
│ │ │ ☑ Project (5) ───── 展开 ▼                          │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────────────┐ │ │
│ │ │ 补充工具 (Supplementary)            [全部启用] [全部禁用]│ │ │
│ │ │                                                     │ │ │
│ │ │ ☐ Editor-Advanced (2) ── 展开 ▼                     │ │ │
│ │ │ ☐ Debug-Advanced (2) ─── 展开 ▼                     │ │ │
│ │ └─────────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ [保存状态] [重置为默认]                                │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 UI 组件层次

```
ToolManagerTab (VBoxContainer)
├── StatusBar (HBoxContainer)
│   ├── StatusLabel ("Core: 44/40 | Supplementary: 6 | Total: 50")
│   ├── CoreCountLabel (红色警告：超出限制时)
│   └── RefreshButton
│
├── ScrollContainer
│   └── ToolGroupList (VBoxContainer)
│       ├── CoreCategorySection
│       │   ├── CategoryHeader (HBoxContainer)
│       │   │   ├── CategoryLabel ("核心工具 (Core)")
│       │   │   ├── EnableAllButton ("全部启用")
│       │   │   └── DisableAllButton ("全部禁用")
│       │   │
│       │   ├── GroupSection (Node-Read)
│       │   │   ├── GroupHeader (HBoxContainer)
│       │   │   │   ├── GroupCheckBox (组级别开关)
│       │   │   │   ├── GroupLabel ("Node-Read (5)")
│       │   │   │   └── ExpandButton (展开/折叠)
│       │   │   │
│       │   │   └── ToolList (VBoxContainer) [可折叠]
│       │   │       ├── ToolItem (HBoxContainer)
│       │   │       │   ├── ToolCheckBox
│       │   │       │   └── ToolDescription
│       │   │       └── ...
│       │   │
│       │   └── ...
│       │
│       └── SupplementaryCategorySection
│           └── (同上结构)
│
└── ActionBar (HBoxContainer)
    ├── SaveButton ("保存状态")
    └── ResetButton ("重置为默认")
```

### 4.3 核心交互逻辑

```gdscript
# === 组级别切换 ===
func _on_group_toggled(button_pressed: bool, group_name: String) -> void:
    # 1. 更新状态管理器
    _state_manager.set_group_enabled(group_name, button_pressed)
    
    # 2. 更新组内所有工具的CheckBox
    var tools: Array = _state_manager.get_group_tools(group_name)
    for tool_name in tools:
        var check: CheckBox = _get_tool_checkbox(tool_name)
        if check:
            check.button_pressed = button_pressed
    
    # 3. 更新计数
    _update_status_bar()
    
    # 4. 发送工具列表变更通知
    _request_tool_list_sync()

# === 单个工具切换 ===
func _on_tool_toggled(button_pressed: bool, tool_name: String) -> void:
    # 1. 更新状态管理器
    _state_manager.set_tool_enabled(tool_name, button_pressed)
    
    # 2. 同步更新所属组的CheckBox状态
    var group_name: String = _classifier.get_tool_group(tool_name)
    var group_all_enabled: bool = _state_manager.is_group_fully_enabled(group_name)
    var group_check: CheckBox = _get_group_checkbox(group_name)
    if group_check:
        group_check.button_pressed = group_all_enabled
    
    # 3. 检查核心工具限制
    if _classifier.get_tool_category(tool_name) == "core":
        var core_count: int = _state_manager.get_core_tools_count()
        if core_count > _classifier.get_core_max_count():
            _show_core_limit_warning()
    
    # 4. 更新计数
    _update_status_bar()
    
    # 5. 发送工具列表变更通知
    _request_tool_list_sync()
```

### 4.4 实时刷新机制

```gdscript
# === 刷新策略 ===
var _refresh_timer: Timer = null
var _pending_refresh: bool = false
var _debounce_msec: int = 100  # 100ms防抖

func _setup_refresh_timer() -> void:
    _refresh_timer = Timer.new()
    _refresh_timer.one_shot = true
    _refresh_timer.timeout.connect(_on_deferred_refresh)
    add_child(_refresh_timer)

func _request_tool_list_sync() -> void:
    # 防抖处理：避免频繁刷新
    if not _pending_refresh:
        _pending_refresh = true
        _refresh_timer.start(_debounce_msec / 1000.0)

func _on_deferred_refresh() -> void:
    _pending_refresh = false
    _refresh_ui()
    _push_tool_list_change()

func _refresh_ui() -> void:
    # 1. 从状态管理器重新读取所有状态
    # 2. 更新所有CheckBox
    # 3. 更新计数标签
    # 4. 更新核心限制警告
    _update_status_bar()
    _update_all_checkboxes()

func _push_tool_list_change() -> void:
    # 向服务器核心发送工具列表变更信号
    if _server_core and _server_core.has_method("notify_tool_list_changed"):
        _server_core.notify_tool_list_changed()
```

### 4.5 需要修改的文件

| 文件                                        | 修改内容                                |
| ----------------------------------------- | ----------------------------------- |
| `addons/godot_mcp/ui/mcp_panel_native.gd` | 重写Tool Manager tab，添加组级别管理、状态栏、刷新机制 |

### 4.6 需要创建的UI辅助资源

| 文件路径                                               | 说明                        |
| -------------------------------------------------- | ------------------------- |
| `addons/godot_mcp/ui/tool_manager_group_item.gd`   | 组项目UI组件（CheckBox + 展开/折叠） |
| `addons/godot_mcp/ui/tool_manager_group_item.tscn` | 组项目场景                     |
| `addons/godot_mcp/ui/tool_manager_tool_item.gd`    | 工具项UI组件                   |
| `addons/godot_mcp/ui/tool_manager_tool_item.tscn`  | 工具项场景                     |

***

## 5. 工具列表同步机制

### 5.1 变更推送流程

```
用户操作 (Toggle Tool/Group)
    │
    ▼
ToolStateManager.set_group_enabled() / set_tool_enabled()
    │
    ├──► 更新内存状态
    ├──► 写持久化存储 (防抖, 延迟1秒写入)
    │
    ▼
emit_signal("tool_state_changed") / ("group_state_changed")
    │
    ▼
MCPServerCore.on_tool_state_changed()
    │
    ├──► 更新_tools字典中对应工具的enabled状态
    │
    ▼
MCPServerCore.notify_tool_list_changed()
    │
    ├──► 记录变更标记 _tool_list_dirty = true
    │
    ▼ (当收到下一次 tools/list 请求时)
_handle_tools_list()
    │
    ├──► 读取最新的 _tools 状态
    ├──► 仅返回 enabled = true 的工具
    ├──► 重置 _tool_list_dirty = false
    │
    ▼
MCP Client 获取到最新的工具列表
```

### 5.2 主动通知机制

对于支持 `notifications` 的 MCP 客户端（如 Streamable HTTP 模式的客户端）：

```gdscript
# 在 MCPServerCore 中添加
var _tool_list_dirty: bool = false
var _send_tool_list_changed_notification: bool = false  # 是否启用变更推送

# 配置开关
func set_tool_list_change_notification(enabled: bool) -> void:
    _send_tool_list_changed_notification = enabled

# 标记工具列表已变更
func notify_tool_list_changed() -> void:
    _tool_list_dirty = true
    if _send_tool_list_changed_notification:
        _send_notification_tools_list_changed()

# 发送 tools/list_changed 通知 (JSON-RPC Notification)
func _send_notification_tools_list_changed() -> void:
    var notification: Dictionary = {
        "jsonrpc": "2.0",
        "method": "notifications/tools/list_changed",
        "params": {}
    }
    # 通过传输层发送（HTTP模式的SSE推送或stdio的stdout写入）
    _send_raw_message(notification)

# 在 _handle_tools_list 中检查脏标记
func _handle_tools_list(message: Dictionary) -> Dictionary:
    var id: Variant = message.get("id")
    var tools_list: Array[Dictionary] = []
    for tool_name in _tools:
        var tool: MCPTypes.MCPTool = _tools[tool_name]
        if tool and tool.is_valid() and tool.enabled:
            tools_list.append(tool.to_dict())
    _tool_list_dirty = false
    var result: Dictionary = {"tools": tools_list}
    return MCPTypes.create_response(id, result)
```

### 5.3 状态一致性校验

```gdscript
# 定期校验或手动触发
func validate_tool_state_consistency() -> Dictionary:
    var report: Dictionary = {
        "consistent": true,
        "issues": []
    }
    
    # 1. 校验状态管理器与服务器核心状态一致
    for tool_name in _state_manager.get_all_tools():
        var sm_enabled: bool = _state_manager.is_tool_enabled(tool_name)
        var core_tool = _server_core.get_tool(tool_name)
        if core_tool:
            if core_tool.enabled != sm_enabled:
                report.consistent = false
                report.issues.append({
                    "type": "mismatch",
                    "tool": tool_name,
                    "state_manager": sm_enabled,
                    "server_core": core_tool.enabled
                })
    
    # 2. 校验核心工具数量
    var core_count: int = _state_manager.get_core_tools_count()
    if core_count > _classifier.get_core_max_count():
        report.consistent = false
        report.issues.append({
            "type": "core_limit_exceeded",
            "current": core_count,
            "max": _classifier.get_core_max_count()
        })
    
    return report
```

### 5.4 需要修改的文件

| 文件                                                  | 修改内容                                   |
| --------------------------------------------------- | -------------------------------------- |
| `addons/godot_mcp/native_mcp/mcp_server_core.gd`    | 添加 `notify_tool_list_changed`、脏标记、通知发送 |
| `addons/godot_mcp/native_mcp/mcp_transport_base.gd` | 可选：添加 `send_raw` 虚方法                   |
| `addons/godot_mcp/native_mcp/mcp_http_server.gd`    | 实现 `_send_raw_message`（SSE推送）          |
| `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`   | 实现 `_send_raw_message`（stdout写入）       |

***

## 6. 详细实施步骤

### 阶段一：工具分类基础设施（1天）

#### 步骤 1.1：扩展 MCPTool 类

**文件**：`addons/godot_mcp/native_mcp/mcp_types.gd`

**修改内容**：

1. 在 `MCPTool` 类中添加 `category: String` 和 `group: String` 字段
2. 默认值：`category = "core"`, `group = ""`

**代码**：

```gdscript
class MCPTool:
    var name: String = ""
    var description: String = ""
    var input_schema: Dictionary = {}
    var output_schema: Dictionary = {}
    var annotations: Dictionary = {}
    var callable: Callable = Callable()
    var enabled: bool = true
    var category: String = "core"     # "core" | "supplementary"
    var group: String = ""            # 功能分组名称
```

#### 步骤 1.2：创建 ToolClassifier

**文件**：`addons/godot_mcp/native_mcp/mcp_tool_classifier.gd`

**功能**：

- 定义所有工具的分类和分组归属
- 提供分类查询接口
- 核心工具数量限制校验

#### 步骤 1.3：更新 tool register\_tool 接口

**文件**：`addons/godot_mcp/native_mcp/mcp_server_core.gd`

**修改**：

```gdscript
func register_tool(name: String, description: String, 
                   input_schema: Dictionary, callable: Callable,
                   output_schema: Dictionary = {}, 
                   annotations: Dictionary = {},
                   category: String = "core",       # 新增
                   group: String = "") -> void:     # 新增
    var tool: MCPTypes.MCPTool = MCPTypes.MCPTool.new()
    tool.name = name
    tool.description = description
    tool.input_schema = input_schema
    tool.output_schema = output_schema
    tool.annotations = annotations
    tool.callable = callable
    tool.category = category  # 新增
    tool.group = group        # 新增
    # ... 其余逻辑不变
```

#### 步骤 1.4：更新所有工具注册调用

在每个 `*_tools_native.gd` 文件的 `register_tools` 方法中，为每个工具添加 `category` 和 `group` 参数。

**示例**（`node_tools_native.gd`）：

```gdscript
server_core.register_tool(
    "list_nodes",
    "...",
    {...},                          # input_schema
    Callable(self, "_tool_list_nodes"),
    {...},                          # output_schema
    MCPTypes.MCPTool.create_annotations(true, false, true, false),  # annotations
    "core",                         # category
    "Node-Read"                     # group
)
```

***

### 阶段二：ToolStateManager 实现（1天）

#### 步骤 2.1：创建 ToolStateManager

**文件**：`addons/godot_mcp/native_mcp/mcp_tool_state_manager.gd`

**实现内容**：

1. 内存状态管理（Dictionary缓存）
2. 持久化存储（ConfigFile）
3. 校验和验证
4. 版本迁移
5. 信号通知
6. 核心工具数量限制检查

#### 步骤 2.2：集成到 MCPServerCore

**文件**：`addons/godot_mcp/native_mcp/mcp_server_core.gd`

**修改**：

1. `_init()` 中创建 ToolStateManager 实例
2. `register_tool()` 中同步注册到 ToolStateManager
3. `set_tool_enabled()` 委托给 ToolStateManager
4. 启动时自动加载持久化状态

#### 步骤 2.3：集成到插件入口

**文件**：`addons/godot_mcp/mcp_server_native.gd`

**修改**：

1. `_enter_tree()` 中加载持久化配置
2. `_exit_tree()` 中保存持久化配置
3. 重启服务器时应用存储的状态

***

### 阶段三：UI 面板改造（1.5天）

#### 步骤 3.1：创建组项目UI组件

**文件**：

- `addons/godot_mcp/ui/tool_manager_group_item.gd`
- `addons/godot_mcp/ui/tool_manager_group_item.tscn`

**功能**：

- 组级别 CheckBox（控制该组所有工具）
- 展开/折叠该组工具列表
- 显示组内工具数量

#### 步骤 3.2：创建工具项UI组件

**文件**：

- `addons/godot_mcp/ui/tool_manager_tool_item.gd`
- `addons/godot_mcp/ui/tool_manager_tool_item.tscn`

**功能**：

- 单个工具 CheckBox
- 工具名称和描述显示
- 悬停提示显示完整信息

#### 步骤 3.3：重写 Tool Manager Tab

**文件**：`addons/godot_mcp/ui/mcp_panel_native.gd`

**重写** **`_create_tools_tab()`** **方法**：

1. 顶部状态栏（核心工具计数、补充工具计数、总计）
2. 核心工具区域（Core Category Section）
   - 按组渲染所有核心工具
   - "全部启用" / "全部禁用" 按钮
3. 补充工具区域（Supplementary Category Section）
   - 按组渲染所有补充工具
   - "全部启用" / "全部禁用" 按钮
4. 底部分隔栏
   - "保存状态" 按钮
   - "重置为默认" 按钮

***

### 阶段四：同步机制实现（1天）

#### 步骤 4.1：工具列表变更标记

**文件**：`addons/godot_mcp/native_mcp/mcp_server_core.gd`

**添加**：

1. `_tool_list_dirty: bool` 标记
2. `notify_tool_list_changed()` 方法
3. `_handle_tools_list()` 中清理脏标记

#### 步骤 4.2：变更通知推送

**文件**：`addons/godot_mcp/native_mcp/mcp_server_core.gd`

**添加**：

1. `_send_notification_tools_list_changed()` 方法
2. JSON-RPC 通知格式：`{"jsonrpc": "2.0", "method": "notifications/tools/list_changed", "params": {}}`

#### 步骤 4.3：传输层支持

**文件**：

- `addons/godot_mcp/native_mcp/mcp_transport_base.gd`
- `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`
- `addons/godot_mcp/native_mcp/mcp_http_server.gd`

**添加**：

1. 基类添加 `send_raw_message(message: Dictionary) -> void` 虚方法
2. stdio 实现：`print(JSON.stringify(message))`
3. HTTP 实现：SSE 事件推送

***

### 阶段五：集成测试与验证（1天）

#### 步骤 5.1：核心工具限制验证

**测试脚本**：`test/tools/test_core_tool_limit.py`

**测试内容**：

1. 注册核心工具超过40个时触发警告
2. 核心工具计数精确性
3. 禁用核心工具后tools/list响应变化

#### 步骤 5.2：组管理功能测试

**测试内容**：

1. 启用/禁用整个组的所有工具
2. 组内部分启用时组CheckBox状态（部分选中状态）
3. 快速连续切换组状态（防抖测试）

#### 步骤 5.3：持久化测试

**测试内容**：

1. 保存状态后重启插件，状态是否正确恢复
2. 手动篡改配置文件，是否能检测到校验和变更
3. 旧版本配置文件的迁移兼容性

#### 步骤 5.4：同步机制测试

**测试内容**：

1. 变更工具状态后，tools/list 响应是否立即更新
2. notifications/tools/list\_changed 通知是否正确格式
3. HTTP模式下SSE推送是否正确

***

## 7. 回滚计划

### 7.1 备份清单

| 备份文件                      | 对应修改文件                                           |
| ------------------------- | ------------------------------------------------ |
| `mcp_types.gd.bak`        | `addons/godot_mcp/native_mcp/mcp_types.gd`       |
| `mcp_server_core.gd.bak`  | `addons/godot_mcp/native_mcp/mcp_server_core.gd` |
| `mcp_panel_native.gd.bak` | `addons/godot_mcp/ui/mcp_panel_native.gd`        |

### 7.2 回滚步骤

1. 停止 Godot Editor
2. 恢复备份文件
3. 删除新增文件：`mcp_tool_state_manager.gd`、`mcp_tool_classifier.gd`、`tool_manager_group_item.gd/tscn`、`tool_manager_tool_item.gd/tscn`
4. 删除持久化配置文件：`user://mcp_tool_state.cfg`
5. 重新启动 Godot Editor

***

## 8. 时间估算

| 阶段     | 任务                  | 时间        |
| ------ | ------------------- | --------- |
| 阶段一    | 工具分类基础设施            | 1 天       |
| 阶段二    | ToolStateManager 实现 | 1 天       |
| 阶段三    | UI 面板改造             | 1.5 天     |
| 阶段四    | 同步机制实现              | 1 天       |
| 阶段五    | 集成测试与验证             | 1 天       |
| **总计** | <br />              | **5.5 天** |

***

## 9. 文件清单

### 9.1 新建文件

| # | 文件路径                                                    | 说明      |
| - | ------------------------------------------------------- | ------- |
| 1 | `addons/godot_mcp/native_mcp/mcp_tool_classifier.gd`    | 工具分类器   |
| 2 | `addons/godot_mcp/native_mcp/mcp_tool_state_manager.gd` | 工具状态管理器 |
| 3 | `addons/godot_mcp/ui/tool_manager_group_item.gd`        | 组项目UI组件 |
| 4 | `addons/godot_mcp/ui/tool_manager_group_item.tscn`      | 组项目场景   |
| 5 | `addons/godot_mcp/ui/tool_manager_tool_item.gd`         | 工具项UI组件 |
| 6 | `addons/godot_mcp/ui/tool_manager_tool_item.tscn`       | 工具项场景   |

### 9.2 修改文件

| #  | 文件路径                                                | 修改内容                           |
| -- | --------------------------------------------------- | ------------------------------ |
| 1  | `addons/godot_mcp/native_mcp/mcp_types.gd`          | MCPTool新增category/group字段      |
| 2  | `addons/godot_mcp/native_mcp/mcp_server_core.gd`    | 注册API扩展、脏标记、ToolStateManager集成 |
| 3  | `addons/godot_mcp/native_mcp/mcp_transport_base.gd` | 新增send\_raw\_message虚方法        |
| 4  | `addons/godot_mcp/native_mcp/mcp_stdio_server.gd`   | 实现send\_raw\_message           |
| 5  | `addons/godot_mcp/native_mcp/mcp_http_server.gd`    | 实现send\_raw\_message(SSE)      |
| 6  | `addons/godot_mcp/mcp_server_native.gd`             | 加载/保存持久化状态                     |
| 7  | `addons/godot_mcp/ui/mcp_panel_native.gd`           | 重写Tool Manager Tab             |
| 8  | `addons/godot_mcp/tools/node_tools_native.gd`       | 注册调用添加分类参数                     |
| 9  | `addons/godot_mcp/tools/script_tools_native.gd`     | 注册调用添加分类参数                     |
| 10 | `addons/godot_mcp/tools/scene_tools_native.gd`      | 注册调用添加分类参数                     |
| 11 | `addons/godot_mcp/tools/editor_tools_native.gd`     | 注册调用添加分类参数                     |
| 12 | `addons/godot_mcp/tools/debug_tools_native.gd`      | 注册调用添加分类参数                     |
| 13 | `addons/godot_mcp/tools/project_tools_native.gd`    | 注册调用添加分类参数                     |

### 9.3 测试文件

| # | 文件路径                                 | 说明         |
| - | ------------------------------------ | ---------- |
| 1 | `test/tools/test_core_tool_limit.py` | 核心工具数量限制测试 |

***

## 10. 附录：工具分类映射表

| 工具名称                      | 功能模块    | 分类            | 分组              | 核心/补充  |
| ------------------------- | ------- | ------------- | --------------- | ------ |
| create\_node              | Node    | core          | Node-Write      | 核心     |
| delete\_node              | Node    | core          | Node-Write      | 核心     |
| update\_node\_property    | Node    | core          | Node-Write      | 核心     |
| get\_node\_properties     | Node    | core          | Node-Read       | 核心     |
| list\_nodes               | Node    | core          | Node-Read       | 核心     |
| get\_scene\_tree          | Node    | core          | Node-Read       | 核心     |
| duplicate\_node           | Node    | core          | Node-Write      | 核心     |
| move\_node                | Node    | core          | Node-Write      | 核心     |
| rename\_node              | Node    | core          | Node-Write      | 核心     |
| add\_resource             | Node    | core          | Node-Write      | 核心     |
| set\_anchor\_preset       | Node    | core          | Node-Write      | 核心     |
| connect\_signal           | Node    | core          | Node-Write      | 核心     |
| disconnect\_signal        | Node    | core          | Node-Write      | 核心     |
| get\_node\_groups         | Node    | core          | Node-Read       | 核心     |
| set\_node\_groups         | Node    | core          | Node-Write      | 核心     |
| find\_nodes\_in\_group    | Node    | core          | Node-Read       | 核心     |
| list\_project\_scripts    | Script  | core          | Script          | 核心     |
| read\_script              | Script  | core          | Script          | 核心     |
| create\_script            | Script  | core          | Script          | 核心     |
| modify\_script            | Script  | core          | Script          | 核心     |
| analyze\_script           | Script  | core          | Script          | 核心     |
| get\_current\_script      | Script  | core          | Script          | 核心     |
| attach\_script            | Script  | core          | Script          | 核心     |
| validate\_script          | Script  | core          | Script          | 核心     |
| search\_in\_files         | Script  | core          | Script          | 核心     |
| create\_scene             | Scene   | core          | Scene           | 核心     |
| save\_scene               | Scene   | core          | Scene           | 核心     |
| open\_scene               | Scene   | core          | Scene           | 核心     |
| get\_current\_scene       | Scene   | core          | Scene           | 核心     |
| get\_scene\_structure     | Scene   | core          | Scene           | 核心     |
| list\_project\_scenes     | Scene   | core          | Scene           | 核心     |
| get\_editor\_state        | Editor  | core          | Editor          | 核心     |
| run\_project              | Editor  | core          | Editor          | 核心     |
| stop\_project             | Editor  | core          | Editor          | 核心     |
| get\_selected\_nodes      | Editor  | core          | Editor          | 核心     |
| set\_editor\_setting      | Editor  | core          | Editor          | 核心     |
| get\_editor\_screenshot   | Editor  | core          | Editor          | 核心     |
| get\_signals              | Editor  | core          | Editor          | 核心     |
| reload\_project           | Editor  | supplementary | Editor-Advanced | **补充** |
| get\_editor\_logs         | Debug   | core          | Debug           | 核心     |
| execute\_script           | Debug   | supplementary | Debug-Advanced  | **补充** |
| get\_performance\_metrics | Debug   | supplementary | Debug-Advanced  | **补充** |
| debug\_print              | Debug   | core          | Debug           | 核心     |
| execute\_editor\_script   | Debug   | supplementary | Editor-Advanced | **补充** |
| clear\_output             | Debug   | core          | Debug           | 核心     |
| get\_project\_info        | Project | core          | Project         | 核心     |
| get\_project\_settings    | Project | core          | Project         | 核心     |
| list\_project\_resources  | Project | core          | Project         | 核心     |
| create\_resource          | Project | core          | Project         | 核心     |
| get\_project\_structure   | Project | core          | Project         | 核心     |

**核心工具计数**：44 个（4个补充工具降级后为 **40个核心**）
**补充工具计数**：6 个（包含4个降级工具 + 2个原有补充工具）

***

## 11. 总结

本计划通过三层优化解决AI工具对MCP工具数量限制问题：

1. **分类体系层**：将50个工具划分为"核心"(≤40)和"补充"两大类，在 `MCPTool` 类中新增 `category` 和 `group` 字段，为所有工具赋予清晰的分组归属。
2. **状态管理层**：创建 `ToolStateManager` 和 `ToolClassifier`，实现组级别启用/禁用、持久化存储（带校验安全防护）、版本迁移兼容、核心工具数量上限校验。
3. **UI与同步层**：重写Tool Manager面板，支持组级别批量操作、核心/补充分区展示、状态实时刷新；实现工具列表变更推送机制，确保MCP客户端能及时获取最新工具列表。

**预期成果**：

- 核心工具数量控制在40个以内，满足AI客户端限制
- 用户可按组批量管理工具，操作直观便捷
- 工具状态持久化保存，重启不丢失
- 工具变更实时同步到MCP客户端
- 数据存储具备安全防护能力，支持后续升级

***

**文档结束**
