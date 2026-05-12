# PR #7 Vibe Coding 免打扰模式 审查报告

**日期：** 2026-05-12
**审查分支：** `integration/pr-review`
**PR：** #7 "Add default quiet vibe coding mode" + "Update tools reference"

---

## 1. GUT 测试结果

| 指标 | 数值 |
|------|------|
| 总脚本 | 27 |
| 总测试 | 458 |
| 通过 | 451 |
| 失败 | 0 |
| Pending (预存在) | 7 |

测试命令：
```
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

---

## 2. 已修复的问题

### 问题 1：`_on_vibe_coding_mode_toggled` 缺少持久化 ✅

**文件：** `addons/godot_mcp/ui/mcp_panel_native.gd:516-519`

**症状：** `_on_vibe_coding_mode_toggled` 没有调用 `_debounce_save()`，导致 `vibe_coding_mode` 设置无法持久化（重启编辑器后恢复默认值）。

**修复：** 在 `_plugin.vibe_coding_mode = button_pressed` 后添加 `_debounce_save()` 调用。

```gdscript
func _on_vibe_coding_mode_toggled(button_pressed: bool) -> void:
    if _plugin:
        _plugin.vibe_coding_mode = button_pressed
    _debounce_save()  # 新增
```

---

### 问题 4：缺少 GUT 测试覆盖 ✅

**文件：** 新增以下测试文件

| 文件 | 测试内容 |
|------|----------|
| `test/unit/tools/test_editor_tools.gd` | 8 个测试：run_project/stop_project/select_node/select_file 在 vibe mode 下的阻塞与绕过行为 |
| `test/unit/tools/test_scene_tools.gd` | 7 个测试：open_scene/close_scene_tab 在 vibe mode 下的阻塞与绕过行为 |

测试模式遵循项目规范：
- `extends "res://addons/gut/test.gd"`
- 用 `Engine.set_meta("GodotMCPPlugin", ...)` 模拟插件状态
- 缺失参数/错误路径覆盖（如空 scene_path）

---

## 3. 已记录的问题（待后续优化）

### 问题 2：`_is_vibe_coding_mode()` 代码重复 🔶

**文件：**
- `addons/godot_mcp/tools/editor_tools_native.gd:25-32`
- `addons/godot_mcp/tools/scene_tools_native.gd:26-33`
- `addons/godot_mcp/tools/script_tools_native.gd:24-31`

**描述：** 三个工具文件中定义了完全相同的 `_is_vibe_coding_mode()` 私有方法：

```gdscript
func _is_vibe_coding_mode() -> bool:
    if Engine.has_meta("GodotMCPPlugin"):
        var plugin = Engine.get_meta("GodotMCPPlugin")
        if plugin and plugin.get("vibe_coding_mode") != null:
            return bool(plugin.vibe_coding_mode)
    return true
```

**建议：** 将方法提取到 `vibe_coding_policy.gd` 作为静态方法，或创建一个工具基类共享该方法。

---

### 问题 3：`quiet_mode_runner.gd` 未集成到 CI 流程 🔶

**文件：** `test/unit/quiet_mode_runner.gd`

**描述：** 该文件直接继承 `SceneTree` 并通过 `quit()` 退出，不经过 GUT 框架。目前没有任何运行命令记录在 AGENTS.md 或 CI 脚本中。

**运行命令参考：**
```
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s test/unit/quiet_mode_runner.gd
```

Python 静态检查同样缺少运行命令：
```
python test/quiet_mode_static_check.py
```

**建议：** 在 AGENTS.md 或 CI 配置中添加上述命令，确保独立运行器在 CI 流程中自动执行。

---

## 4. 测试覆盖率矩阵

| 变更文件 | 变更内容 | 测试覆盖 | 状态 |
|----------|----------|----------|------|
| `vibe_coding_policy.gd` (新增) | 3 个静态策略方法 | `test_vibe_coding_policy.gd` (GUT) + `quiet_mode_runner.gd` | ✅ |
| `mcp_server_native.gd` | `vibe_coding_mode` 导出变量 | `test_mcp_server_native.gd` | ✅ |
| `editor_tools_native.gd` | 4 个工具策略检查 + schema | `test_editor_tools.gd` (新增) + `quiet_mode_runner.gd` | ✅ |
| `scene_tools_native.gd` | 2 个工具策略检查 + schema | `test_scene_tools.gd` (新增) + `quiet_mode_runner.gd` | ✅ |
| `script_tools_native.gd` | `open_script_at_line` 策略检查 | `quiet_mode_runner.gd` | ✅ |
| `mcp_panel_native.gd` | UI 复选框 + toggle handler | 无（UI 手动测试） | ⚠️ |
| `tools-reference.md` | 文档更新 | N/A | ✅ |
| `quiet_mode_static_check.py` (新增) | Python 静态检查 | N/A（测试工具自身） | ✅ |
| `quiet_mode_runner.gd` (新增) | 独立 SceneTree 运行器 | N/A（测试工具自身） | ✅ |

---

## 5. 审查结论

| 维度 | 评分 | 说明 |
|------|------|------|
| 功能完整性 | ⭐⭐⭐⭐⭐ | 策略→工具→UI→文档 全闭环 |
| 测试覆盖 | ⭐⭐⭐⭐ | 核心逻辑覆盖完整，新增文件覆盖完整 |
| GUT 通过率 | ⭐⭐⭐⭐⭐ | 0 failures / 0 errors / 0 risky |
| 代码规范 | ⭐⭐⭐⭐ | 已修复持久化 bug，2 个优化项已记录 |
