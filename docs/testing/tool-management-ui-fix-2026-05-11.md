# MCP 工具管理 UI 修复与实时通知修复报告

**日期**: 2026-05-11
**问题**: 工具启用状态不持久化、分组 toggle 不反映子工具状态、信号循环导致批量禁用、工具变更未实时通知 MCP 客户端
**影响文件**:
- `addons/godot_mcp/ui/mcp_tool_item.gd`
- `addons/godot_mcp/ui/mcp_tool_group_item.gd`
- `addons/godot_mcp/ui/mcp_panel_native.gd`
- `addons/godot_mcp/native_mcp/mcp_server_core.gd`
- `addons/godot_mcp/mcp_server_native.gd`

---

## 问题 A: Editor 解析错误 - class_name 缺失

### 描述

Godot Editor 加载插件时，`mcp_panel_native.gd` 报解析错误：
```
Parse Error: Could not find type "MCPToolGroupItem" in the current scope.
```

根因：`mcp_tool_group_item.gd` 和 `mcp_tool_item.gd` 未声明 `class_name`，导致 Godot Editor 无法在编译期解析这两个类型。

### 修复

在两个文件中分别添加 `class_name` 声明：

```gdscript
# addons/godot_mcp/ui/mcp_tool_item.gd
class_name MCPToolItem extends HBoxContainer

# addons/godot_mcp/ui/mcp_tool_group_item.gd
class_name MCPToolGroupItem extends VBoxContainer
```

---

## 问题 B: 工具启用状态不持久化

### 描述

Godot 重启后，所有工具的启用/禁用状态重置为默认状态。用户每次启动都需要重新配置工具开关。

### 根因

`mcp_server_native.gd` 的 `_enter_tree()` 启动顺序存在问题：

```
注册工具 → 创建UI → 启动Server → 加载状态    ← 状态加载太晚
                          ↑
                    UI 已读取默认状态
```

UI 在状态加载之前已创建完成，读取的是全量默认状态。

### 修复

在 `MCPServerCore` 中添加公开的 `load_tool_states()` 方法：

```gdscript
func load_tool_states() -> int:
    if _state_manager == null:
        _state_manager = load("res://addons/godot_mcp/native_mcp/tool_state_manager.gd").new()
    var saved_states: Dictionary = _state_manager.load_state()
    if not saved_states.is_empty():
        _state_manager.apply_states_to_server(self, saved_states)
        _log_info("Loaded saved tool states: " + str(saved_states.size()) + " tools")
    return saved_states.size()
```

并调整 `_enter_tree()` 启动顺序为：

```
注册工具 → 注册资源 → 加载状态 → 创建UI → 启动Server
                        ↑
                  UI 读取正确状态
```

---

## 问题 C: 分组 toggle 不反映子工具状态

### 描述

同一分组下所有工具都启用时，分组的 CheckBox 仍显示未启用状态。只有手动点击分组 CheckBox 才会显示启用。

### 根因

`MCPToolGroupItem._update_count()` 方法只更新了计数 Label 的文本（"Enabled: 5 / 5"），但**没有更新分组 CheckBox 的 `button_pressed` 属性**。

### 修复

在 `_update_count()` 中添加对 `_group_check.button_pressed` 的更新：

```gdscript
func _update_count() -> void:
    ...
    if _group_check:
        _group_check.set_block_signals(true)
        _group_check.button_pressed = (enabled == total and total > 0)
        _group_check.set_block_signals(false)
```

---

## 问题 D: 信号循环导致批量禁用

### 描述

禁用分组的其中一个工具时，当前分组下所有工具都会变成禁用状态。

### 根因

`_update_count()` 设置 `_group_check.button_pressed = false` 时，触发了 `CheckBox` 的 `toggled` 信号 → `_on_group_toggled` 被调用 → `set_group_enabled(false)` 禁用整个分组 → 所有工具被禁用。

这是一个典型的**信号循环**问题。

### 修复

使用 `set_block_signals(true/false)` 包裹对 `_group_check.button_pressed` 的修改：

```gdscript
_group_check.set_block_signals(true)
_group_check.button_pressed = (enabled == total and total > 0)
_group_check.set_block_signals(false)
```

---

## 问题 E: 工具变更未实时通知 MCP 客户端

### 描述

开启 MCP Server 后，在 UI 上启用或禁用工具，已连接的 MCP 客户端无法实时收到工具列表变更通知，必须手动刷新才能看到更新。

### 根因

在 `mcp_server_core.gd` 的 `_handle_tools_list()` 方法中，处理客户端 `tools/list` 请求时会**错误地清除** `_tool_list_dirty` 标志。

导致一个竞态条件：

```
1. 用户切换工具 → _tool_list_dirty = true → 0.5s debounce 定时器启动
2. MCP 客户端在 0.5s 窗口内请求 tools/list ← 常见（自动刷新/初始化）
3. _handle_tools_list() 返回正确列表，但同时也清除了 _tool_list_dirty = false
4. Debounce 定时器触发 → notify_tool_list_changed()
   → 检测到 _tool_list_dirty = false → 直接返回！通知被吞！
```

### 修复

移除 `_handle_tools_list()` 中的 `_tool_list_dirty = false`：

```gdscript
# 修复前 (mcp_server_core.gd:372):
func _handle_tools_list(message: Dictionary) -> Dictionary:
    ...
    _tool_list_dirty = false  # ← BUG
    ...

# 修复后:
func _handle_tools_list(message: Dictionary) -> Dictionary:
    ...
    # 已移除 _tool_list_dirty = false
    ...
```

现在 `_tool_list_dirty` 仅由 `notify_tool_list_changed()` 在**成功发送通知后**清除（第 682 行），确保通知永远不会被跳过。

---

## 修复文件清单

| 文件 | 修复项 | 严重级别 |
|------|--------|---------|
| `addons/godot_mcp/ui/mcp_tool_item.gd` | 问题 A | 严重 |
| `addons/godot_mcp/ui/mcp_tool_group_item.gd` | 问题 A, C, D | 严重 |
| `addons/godot_mcp/mcp_server_native.gd` | 问题 B | 严重 |
| `addons/godot_mcp/native_mcp/mcp_server_core.gd` | 问题 B, E | 严重 |

---

## 验证结果

### GUT 单元测试

全部 **335 个测试通过**，606 个断言，0 失败。

### 手动验证场景

| 场景 | 预期 | Cursor 结果 | Trae CN 结果 |
|------|------|:-----------:|:------------:|
| Godot 重启后工具状态保持 | 状态持久化 | ✅ | ✅ |
| 分组中所有工具启用 → 分组 CheckBox 显示启用 | UI 联动 | ✅ | ✅ |
| 禁用分组中一个工具 → 其他工具不变 | 无连锁反应 | ✅ | ✅ |
| 切换工具 → 已连接客户端收到 tools/list_changed 通知 | 实时通知 | ✅ | ❌* |

> **\*Trae CN 说明**: 修复后通知流程在 Cursor 验证成功（标准 MCP 客户端），但 Trae CN 客户端仍需要手动刷新才能看到变更。可能原因：
> 1. Trae CN 的 MCP 客户端实现可能不支持 `notifications/tools/list_changed` 标准通知协议
> 2. Trae CN 可能使用了不同的会话/连接管理策略，通知无法正确路由到连接
> 3. Trae CN 可能有自身的缓存策略，忽略服务端推送的变更通知

### 已知限制

- 通知机制依赖 MCP 客户端对 `notifications/tools/list_changed` 的支持（标准 MCP 协议）。如果客户端实现不遵循此规范，通知将无效。
- Trae CN 客户端的工具列表刷新行为仍需进一步调查。
