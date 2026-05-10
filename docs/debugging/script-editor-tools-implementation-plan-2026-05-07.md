# 脚本工具增强 & 编辑器工具增强 & 调试工具增强 实现计划

> 基于 Godot 4.x 最新 API 文档（Context7: /godotengine/godot-docs）
> 结合当前代码 `script_tools_native.gd`、`editor_tools_native.gd` 和 `debug_tools_native.gd` 分析

---

## 〇、工具调整说明

### 已移除工具（与 debug_tools_native.gd 功能重叠）

| 移除工具 | 重叠工具 | 重叠分析 |
|----------|----------|----------|
| `get_editor_errors` | `get_editor_logs` | `get_editor_logs` 支持 `type=["Error"]` 过滤，可精确获取所有错误日志，功能完全覆盖 |
| `get_output_log` | `get_editor_logs` | `get_editor_logs` 支持 `source="mcp"` 获取 MCP 日志缓冲区内容，支持分页、排序、类型过滤，功能完全覆盖 |

**详细分析**：

`debug_tools_native.gd` 中的 `get_editor_logs` 已实现以下完整功能：
- **双数据源**：`source="mcp"`（MCP 日志缓冲区，最大 1000 行）和 `source="runtime"`（`user://logs/godot.log` 运行时日志）
- **类型过滤**：`type` 参数支持 `["Error", "Warning", "Info", "Debug"]` 组合过滤
- **分页支持**：`count`（每页条数）+ `offset`（偏移量）
- **排序**：`order` 参数支持 `"desc"`（最新优先）和 `"asc"`（最旧优先）
- **结构化输出**：每条日志包含 `index`、`type`、`message` 字段

因此：
- `get_editor_errors` = `get_editor_logs(source="mcp", type=["Error"])` — 无需重复实现
- `get_output_log` = `get_editor_logs(source="mcp")` — 无需重复实现

### 暂不处理工具

| 工具 | 状态 | 原因 |
|------|------|------|
| `reload_plugin` | ⏸️ 暂不处理 | 高风险操作：禁用插件会导致 MCP 服务器断开，无法返回结果；需要架构层面的 `_reload()` 方法支持，当前不具备条件 |
| `get_game_screenshot` | ⏸️ 暂不处理 | 进程隔离限制：游戏运行在独立进程中，编辑器无法直接访问游戏视口；可行方案需在游戏脚本中添加截图逻辑并通过 `execute_script` 触发，实现复杂度高且不够可靠 |

---

## 一、脚本工具增强（3个）

### 当前状态分析

`script_tools_native.gd` 已实现 6 个工具：
- `list_project_scripts` / `read_script` / `create_script` / `modify_script` / `analyze_script` / `get_current_script`

其中 `create_script` 已支持 `attach_to_node` 参数（第 269 行），但缺少独立的附加工具。脚本验证和文件搜索完全缺失。

---

### 1. attach_script - 将脚本附加到节点

#### Godot 4.x API

```gdscript
# Object.set_script - 附加脚本到对象
func set_script(script: Variant) -> void

# 加载脚本资源
var script: Script = load("res://path/to/script.gd")

# EditorInterface.get_resource_filesystem().scan() - 刷新资源系统
func scan() -> void
```

#### 实现方案

```gdscript
func _register_attach_script(server_core: RefCounted) -> void:
    server_core.register_tool(
        "attach_script",
        "Attach an existing GDScript file to a node in the scene tree.",
        {
            "type": "object",
            "properties": {
                "node_path": {
                    "type": "string",
                    "description": "Path to the node to attach the script to (e.g. '/root/MainScene/Player')"
                },
                "script_path": {
                    "type": "string",
                    "description": "Path to the script file (e.g. 'res://scripts/player.gd')"
                }
            },
            "required": ["node_path", "script_path"]
        },
        Callable(self, "_tool_attach_script"),
        {
            "type": "object",
            "properties": {
                "status": {"type": "string"},
                "node_path": {"type": "string"},
                "script_path": {"type": "string"},
                "previous_script": {"type": "string"}
            }
        },
        {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
    )

func _tool_attach_script(params: Dictionary) -> Dictionary:
    var node_path: String = params.get("node_path", "")
    var script_path: String = params.get("script_path", "")

    if node_path.is_empty():
        return {"error": "Missing required parameter: node_path"}
    if script_path.is_empty():
        return {"error": "Missing required parameter: script_path"}

    var editor_interface: EditorInterface = _get_editor_interface()
    if not editor_interface:
        return {"error": "Editor interface not available"}

    # 验证脚本路径
    var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
    if not validation["valid"]:
        return {"error": "Invalid script path: " + validation["error"]}
    script_path = validation["sanitized"]

    if not FileAccess.file_exists(script_path):
        return {"error": "Script file not found: " + script_path}

    # 解析节点
    var target_node: Node = _resolve_node_path(editor_interface, node_path)
    if not target_node:
        return {"error": "Node not found: " + node_path}

    # 记录旧脚本
    var previous_script: String = ""
    var old_script: Variant = target_node.get_script()
    if old_script and old_script is Script:
        previous_script = old_script.resource_path

    # 加载并附加脚本
    var script_res: Script = load(script_path)
    if not script_res:
        return {"error": "Failed to load script: " + script_path}

    target_node.set_script(script_res)

    # 刷新资源系统
    editor_interface.get_resource_filesystem().scan()

    return {
        "status": "success",
        "node_path": node_path,
        "script_path": script_path,
        "previous_script": previous_script
    }
```

#### 关键设计点

| 设计点 | 说明 |
|--------|------|
| 独立于 create_script | `create_script` 的 `attach_to_node` 仅在创建时附加；此工具支持附加已存在的脚本 |
| 记录旧脚本 | 返回 `previous_script`，方便用户了解被替换的脚本 |
| PathValidator | 复用现有路径验证逻辑 |
| scan() | 附加后刷新资源文件系统 |

#### 实现难度：**低**（核心 API 仅 `set_script` + `load`）

---

### 2. validate_script - 验证 GDScript 语法

#### Godot 4.x API

```gdscript
# ScriptLanguageExtension._validate - 脚本验证
func _validate(
    script: String,
    path: String,
    validate_functions: bool,
    validate_errors: bool,
    validate_warnings: bool,
    validate_safe_lines: bool
) -> Dictionary

# 获取脚本语言实例
var script_languages: Array = Engine.get_singleton("ScriptServer").get_languages()
# 或通过 EditorInterface
var gdscript_lang: ScriptLanguage = GDScriptLanguage.get_singleton()
```

#### 实现方案

```gdscript
func _register_validate_script(server_core: RefCounted) -> void:
    server_core.register_tool(
        "validate_script",
        "Validate GDScript syntax without executing it. Checks for errors, warnings, and unsafe lines.",
        {
            "type": "object",
            "properties": {
                "script_path": {
                    "type": "string",
                    "description": "Path to the script file to validate (e.g. 'res://scripts/player.gd')"
                },
                "content": {
                    "type": "string",
                    "description": "Optional script content to validate directly (instead of reading from file)"
                },
                "check_warnings": {
                    "type": "boolean",
                    "description": "Whether to check for warnings. Default is true."
                }
            },
            "required": []
        },
        Callable(self, "_tool_validate_script"),
        {
            "type": "object",
            "properties": {
                "valid": {"type": "boolean"},
                "errors": {"type": "array"},
                "warnings": {"type": "array"},
                "error_count": {"type": "integer"},
                "warning_count": {"type": "integer"}
            }
        },
        {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
    )

func _tool_validate_script(params: Dictionary) -> Dictionary:
    var script_path: String = params.get("script_path", "")
    var content: String = params.get("content", "")
    var check_warnings: bool = params.get("check_warnings", true)

    if script_path.is_empty() and content.is_empty():
        return {"error": "Must provide either script_path or content"}

    # 获取脚本内容
    if content.is_empty():
        var validation: Dictionary = PathValidator.validate_file_path(script_path, [".gd"])
        if not validation["valid"]:
            return {"error": "Invalid path: " + validation["error"]}
        script_path = validation["sanitized"]

        var file: FileAccess = FileAccess.open(script_path, FileAccess.READ)
        if not file:
            return {"error": "Failed to open file: " + script_path}
        content = file.get_as_text()
        file.close()

    # 使用 GDScriptLanguage 验证
    var gdscript_lang: ScriptLanguage = GDScriptLanguage.get_singleton()
    if not gdscript_lang:
        return {"error": "GDScriptLanguage not available"}

    var validate_path: String = script_path if not script_path.is_empty() else "res://__validate__.gd"
    var result: Dictionary = gdscript_lang.validate(
        content,
        validate_path,
        true,   # validate_functions
        true,   # validate_errors
        check_warnings,  # validate_warnings
        false   # validate_safe_lines
    )

    var errors: Array = []
    var warnings: Array = []

    if result.has("errors"):
        for err in result["errors"]:
            errors.append({
                "line": err.get("line", -1),
                "column": err.get("column", -1),
                "message": err.get("message", "")
            })

    if check_warnings and result.has("warnings"):
        for warn in result["warnings"]:
            warnings.append({
                "line": warn.get("line", -1),
                "column": warn.get("column", -1),
                "message": warn.get("message", "")
            })

    return {
        "valid": errors.is_empty(),
        "errors": errors,
        "warnings": warnings,
        "error_count": errors.size(),
        "warning_count": warnings.size()
    }
```

#### 关键设计点

| 设计点 | 说明 |
|--------|------|
| 双模式验证 | 支持文件路径和直接内容验证 |
| GDScriptLanguage | 使用 `GDScriptLanguage.get_singleton().validate()` 进行原生验证 |
| 结构化错误 | 返回行号、列号、消息的结构化错误列表 |
| 可选警告 | `check_warnings` 参数控制是否检查警告 |

#### 实现难度：**中**（需要适配 `GDScriptLanguage.validate` 的返回格式）

#### ⚠️ 注意事项

`GDScriptLanguage.validate()` 是 Godot 4.x 的内部 API，其返回格式可能因版本而异。备选方案：

```gdscript
# 备选方案：使用 Expression 解析验证
var expr: Expression = Expression.new()
var parse_result: int = expr.parse(content)
if parse_result != OK:
    return {"valid": false, "error": expr.get_error_text()}
```

或者使用 `Script.new()` + `Script.reload()` 的方式间接验证：

```gdscript
# 备选方案2：通过加载脚本验证
var test_script: GDScript = GDScript.new()
test_script.source_code = content
var err: Error = test_script.reload()
if err != OK:
    return {"valid": false, "error": "Script has syntax errors"}
```

---

### 3. search_in_files - 在项目文件中搜索内容

#### Godot 4.x API

```gdscript
# FileAccess - 文件读取
var file: FileAccess = FileAccess.open(path, FileAccess.READ)
var content: String = file.get_as_text()

# DirAccess - 目录遍历
var dir: DirAccess = DirAccess.open(directory_path)
dir.list_dir_begin()
var file_name: String = dir.get_next()

# String 方法
func find(what: String, from: int = 0) -> int
func match(expr: String) -> bool
func regex_search(pattern: String) -> RegExMatch
```

#### 实现方案

```gdscript
func _register_search_in_files(server_core: RefCounted) -> void:
    server_core.register_tool(
        "search_in_files",
        "Search for text patterns in project files. Supports literal text and regex matching.",
        {
            "type": "object",
            "properties": {
                "pattern": {
                    "type": "string",
                    "description": "Search pattern (text or regex)"
                },
                "search_path": {
                    "type": "string",
                    "description": "Directory to search in. Default is 'res://'."
                },
                "file_extensions": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "File extensions to include (e.g. ['.gd', '.tscn']). Default is ['.gd']."
                },
                "use_regex": {
                    "type": "boolean",
                    "description": "Whether to use regex matching. Default is false (literal match)."
                },
                "case_sensitive": {
                    "type": "boolean",
                    "description": "Whether the search is case-sensitive. Default is true."
                },
                "max_results": {
                    "type": "integer",
                    "description": "Maximum number of results to return. Default is 50."
                }
            },
            "required": ["pattern"]
        },
        Callable(self, "_tool_search_in_files"),
        {
            "type": "object",
            "properties": {
                "pattern": {"type": "string"},
                "results": {"type": "array"},
                "total_matches": {"type": "integer"},
                "files_searched": {"type": "integer"}
            }
        },
        {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
    )

func _tool_search_in_files(params: Dictionary) -> Dictionary:
    var pattern: String = params.get("pattern", "")
    var search_path: String = params.get("search_path", "res://")
    var file_extensions: Array = params.get("file_extensions", [".gd"])
    var use_regex: bool = params.get("use_regex", false)
    var case_sensitive: bool = params.get("case_sensitive", true)
    var max_results: int = params.get("max_results", 50)

    if pattern.is_empty():
        return {"error": "Missing required parameter: pattern"}

    var validation: Dictionary = PathValidator.validate_directory_path(search_path)
    if not validation["valid"]:
        return {"error": "Invalid path: " + validation["error"]}
    search_path = validation["sanitized"]

    var regex: RegEx = null
    if use_regex:
        regex = RegEx.new()
        var compile_err: int = regex.compile(pattern)
        if compile_err != OK:
            return {"error": "Invalid regex pattern: " + pattern}

    var results: Array = []
    var files_searched: int = 0
    var total_matches: int = 0

    _search_recursive(search_path, pattern, file_extensions, use_regex,
        case_sensitive, max_results, regex, results, files_searched, total_matches)

    return {
        "pattern": pattern,
        "results": results,
        "total_matches": total_matches,
        "files_searched": files_searched
    }

func _search_recursive(
    dir_path: String, pattern: String, extensions: Array,
    use_regex: bool, case_sensitive: bool, max_results: int,
    regex: RegEx, results: Array, files_searched: int, total_matches: int
) -> void:
    var dir: DirAccess = DirAccess.open(dir_path)
    if not dir:
        return

    dir.list_dir_begin()
    var file_name: String = dir.get_next()

    while not file_name.is_empty():
        if total_matches >= max_results:
            break

        if file_name == "." or file_name == "..":
            file_name = dir.get_next()
            continue

        var full_path: String = dir_path.path_join(file_name)

        if dir.current_is_dir():
            _search_recursive(full_path, pattern, extensions, use_regex,
                case_sensitive, max_results, regex, results, files_searched, total_matches)
        else:
            var ext_match: bool = extensions.is_empty()
            for ext in extensions:
                if file_name.ends_with(ext):
                    ext_match = true
                    break

            if ext_match:
                files_searched += 1
                _search_file(full_path, pattern, use_regex, case_sensitive,
                    max_results, regex, results, total_matches)

        file_name = dir.get_next()

    dir.list_dir_end()

func _search_file(
    file_path: String, pattern: String, use_regex: bool,
    case_sensitive: bool, max_results: int, regex: RegEx,
    results: Array, total_matches: int
) -> void:
    var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        return

    var line_number: int = 0
    var file_matches: Array = []

    while not file.eof_reached() and total_matches < max_results:
        var line: String = file.get_line()
        line_number += 1

        var found: bool = false
        var match_text: String = ""

        if use_regex and regex:
            var match_result: RegExMatch = regex.search(line)
            if match_result:
                found = true
                match_text = match_result.get_string()
        else:
            var search_line: String = line if case_sensitive else line.to_lower()
            var search_pattern: String = pattern if case_sensitive else pattern.to_lower()
            var pos: int = search_line.find(search_pattern)
            if pos >= 0:
                found = true
                match_text = line.strip_edges()

        if found:
            file_matches.append({
                "line": line_number,
                "text": match_text
            })
            total_matches += 1

    file.close()

    if not file_matches.is_empty():
        results.append({
            "file": file_path,
            "matches": file_matches,
            "match_count": file_matches.size()
        })
```

#### 关键设计点

| 设计点 | 说明 |
|--------|------|
| 双模式搜索 | 支持字面量文本和正则表达式 |
| 递归搜索 | 使用 `_search_recursive` 递归遍历目录 |
| 文件类型过滤 | `file_extensions` 参数控制搜索范围 |
| 大小写敏感 | `case_sensitive` 参数 |
| 结果限制 | `max_results` 防止返回过多结果 |

#### 实现难度：**中**（核心逻辑为文件遍历 + 字符串匹配）

---

## 二、编辑器工具增强（3个）

### 当前状态分析

`editor_tools_native.gd` 已实现 5 个工具：
- `get_editor_state` / `run_project` / `stop_project` / `get_selected_nodes` / `set_editor_setting`

---

### 4. get_editor_screenshot - 截取编辑器视口

#### Godot 4.x API

```gdscript
# EditorInterface.get_editor_viewport_3d(idx) -> SubViewport
func get_editor_viewport_3d(idx: int = 0) -> SubViewport

# EditorInterface.get_editor_viewport_2d() -> SubViewport
func get_editor_viewport_2d() -> SubViewport

# SubViewport.get_texture() -> ViewportTexture
# ViewportTexture.get_image() -> Image
# Image.save_png(path) -> Error
# Image.save_jpg(path, quality) -> Error
```

#### 实现方案

```gdscript
func _register_get_editor_screenshot(server_core: RefCounted) -> void:
    server_core.register_tool(
        "get_editor_screenshot",
        "Capture a screenshot of the editor viewport and save it to a file.",
        {
            "type": "object",
            "properties": {
                "viewport_type": {
                    "type": "string",
                    "description": "Viewport type: '3d' or '2d'. Default is '3d'.",
                    "enum": ["3d", "2d"]
                },
                "viewport_index": {
                    "type": "integer",
                    "description": "3D viewport index (0-3). Default is 0."
                },
                "save_path": {
                    "type": "string",
                    "description": "Path to save the screenshot (e.g. 'res://screenshots/editor.png')."
                },
                "format": {
                    "type": "string",
                    "description": "Image format: 'png' or 'jpg'. Default is 'png'.",
                    "enum": ["png", "jpg"]
                }
            }
        },
        Callable(self, "_tool_get_editor_screenshot"),
        {
            "type": "object",
            "properties": {
                "status": {"type": "string"},
                "save_path": {"type": "string"},
                "size": {"type": "string"}
            }
        },
        {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false}
    )

func _tool_get_editor_screenshot(params: Dictionary) -> Dictionary:
    var viewport_type: String = params.get("viewport_type", "3d")
    var viewport_index: int = params.get("viewport_index", 0)
    var save_path: String = params.get("save_path", "res://screenshot_editor.png")
    var format: String = params.get("format", "png")

    var editor_interface: EditorInterface = _get_editor_interface()
    if not editor_interface:
        return {"error": "Editor interface not available"}

    var viewport: SubViewport = null
    if viewport_type == "3d":
        viewport = editor_interface.get_editor_viewport_3d(viewport_index)
    else:
        viewport = editor_interface.get_editor_viewport_2d()

    if not viewport:
        return {"error": "Failed to get editor viewport"}

    var texture: ViewportTexture = viewport.get_texture()
    if not texture:
        return {"error": "Failed to get viewport texture"}

    var image: Image = texture.get_image()
    if not image:
        return {"error": "Failed to capture viewport image"}

    var err: Error = OK
    if format == "jpg":
        err = image.save_jpg(save_path, 0.9)
    else:
        err = image.save_png(save_path)

    if err != OK:
        return {"error": "Failed to save screenshot: error " + str(err)}

    return {
        "status": "success",
        "save_path": save_path,
        "size": str(image.get_width()) + "x" + str(image.get_height())
    }
```

#### 实现难度：**中**（API 直接支持，但截图保存需要文件系统权限）

---

### 5. get_signals - 获取节点的所有信号及连接

#### Godot 4.x API

```gdscript
# Object.get_signal_list() -> Array[Dictionary]
# 返回所有可用信号，每个字典包含: name, args 等

# Object.get_signal_connection_list(signal: StringName) -> Array[Dictionary]
# 返回指定信号的连接列表

# Object.get_connections() -> Array[Dictionary]
# 返回所有连接
```

#### 实现方案

```gdscript
func _register_get_signals(server_core: RefCounted) -> void:
    server_core.register_tool(
        "get_signals",
        "Get all signals and their connections for a node.",
        {
            "type": "object",
            "properties": {
                "node_path": {
                    "type": "string",
                    "description": "Path to the node (e.g. '/root/MainScene/Player')"
                },
                "include_connections": {
                    "type": "boolean",
                    "description": "Whether to include connection details. Default is true."
                }
            },
            "required": ["node_path"]
        },
        Callable(self, "_tool_get_signals"),
        {
            "type": "object",
            "properties": {
                "node_path": {"type": "string"},
                "signals": {"type": "array"},
                "signal_count": {"type": "integer"},
                "connection_count": {"type": "integer"}
            }
        },
        {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false}
    )

func _tool_get_signals(params: Dictionary) -> Dictionary:
    var node_path: String = params.get("node_path", "")
    var include_connections: bool = params.get("include_connections", true)

    if node_path.is_empty():
        return {"error": "Missing required parameter: node_path"}

    var editor_interface: EditorInterface = _get_editor_interface()
    if not editor_interface:
        return {"error": "Editor interface not available"}

    var target_node: Node = _resolve_node_path(editor_interface, node_path)
    if not target_node:
        return {"error": "Node not found: " + node_path}

    var signal_list: Array = target_node.get_signal_list()
    var signals: Array = []
    var total_connections: int = 0

    for sig in signal_list:
        var signal_info: Dictionary = {
            "name": sig.get("name", ""),
            "arguments": sig.get("args", []).size()
        }

        if include_connections:
            var connections: Array = target_node.get_signal_connection_list(sig.get("name", ""))
            var connection_list: Array = []
            for conn in connections:
                connection_list.append({
                    "callable": str(conn.get("callable", "")),
                    "flags": conn.get("flags", 0)
                })
                total_connections += 1
            signal_info["connections"] = connection_list
            signal_info["connection_count"] = connection_list.size()

        signals.append(signal_info)

    return {
        "node_path": node_path,
        "signals": signals,
        "signal_count": signals.size(),
        "connection_count": total_connections
    }
```

#### 实现难度：**中**（API 直接支持，`get_signal_list` + `get_signal_connection_list`）

---

### 6. reload_project - 重新扫描文件系统并重新加载脚本

#### Godot 4.x API

```gdscript
# EditorFileSystem.scan() - 全量扫描
func scan() -> void

# EditorFileSystem.scan_sources() - 仅扫描源文件
func scan_sources() -> void

# EditorFileSystem.is_scanning() -> bool
# EditorFileSystem.get_scanning_progress() -> float

# EditorInterface.get_resource_filesystem() -> EditorFileSystem
```

#### 实现方案

```gdscript
func _register_reload_project(server_core: RefCounted) -> void:
    server_core.register_tool(
        "reload_project",
        "Rescan the project filesystem and reload scripts. Useful after external file changes.",
        {
            "type": "object",
            "properties": {
                "full_scan": {
                    "type": "boolean",
                    "description": "Whether to perform a full scan (true) or source-only scan (false). Default is false."
                }
            }
        },
        Callable(self, "_tool_reload_project"),
        {
            "type": "object",
            "properties": {
                "status": {"type": "string"},
                "scan_type": {"type": "string"}
            }
        },
        {"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false, "openWorldHint": false}
    )

func _tool_reload_project(params: Dictionary) -> Dictionary:
    var full_scan: bool = params.get("full_scan", false)

    var editor_interface: EditorInterface = _get_editor_interface()
    if not editor_interface:
        return {"error": "Editor interface not available"}

    var fs: EditorFileSystem = editor_interface.get_resource_filesystem()
    if not fs:
        return {"error": "Failed to get EditorFileSystem"}

    if fs.is_scanning():
        return {
            "status": "already_scanning",
            "progress": fs.get_scanning_progress(),
            "message": "Filesystem scan is already in progress"
        }

    if full_scan:
        fs.scan()
        return {"status": "success", "scan_type": "full"}
    else:
        fs.scan_sources()
        return {"status": "success", "scan_type": "sources_only"}
```

#### 实现难度：**中**（API 直接支持，`EditorFileSystem.scan()` / `scan_sources()`）

---

## 三、调试工具增强（1个）

### 当前状态分析

`debug_tools_native.gd` 已实现 5 个工具：
- `get_editor_logs` / `execute_script` / `get_performance_metrics` / `debug_print` / `execute_editor_script`

其中 `get_editor_logs` 已完整覆盖日志获取功能（MCP 日志缓冲区 + 运行时日志文件，支持类型过滤、分页、排序），因此原计划中的 `get_editor_errors` 和 `get_output_log` 已移除。

`clear_output` 逻辑上属于调试/日志管理范畴，从编辑器工具移至调试工具中实现。

---

### 7. clear_output - 清除输出面板和日志缓冲区

#### Godot 4.x API

```gdscript
# EditorInterface 没有直接的 clear_output API
# 替代方案1: 通过 EditorLog 面板清除
# 替代方案2: 清除 MCP 日志缓冲区 _log_buffer
```

#### 实现方案

```gdscript
func _register_clear_output(server_core: RefCounted) -> void:
    server_core.register_tool(
        "clear_output",
        "Clear the editor output panel and MCP log buffer.",
        {
            "type": "object",
            "properties": {
                "clear_mcp_buffer": {
                    "type": "boolean",
                    "description": "Whether to clear the MCP log buffer. Default is true."
                },
                "clear_editor_panel": {
                    "type": "boolean",
                    "description": "Whether to clear the editor output panel. Default is true."
                }
            }
        },
        Callable(self, "_tool_clear_output"),
        {
            "type": "object",
            "properties": {
                "status": {"type": "string"},
                "mcp_buffer_cleared": {"type": "boolean"},
                "editor_panel_cleared": {"type": "boolean"}
            }
        },
        {"readOnlyHint": false, "destructiveHint": true, "idempotentHint": true, "openWorldHint": false}
    )

func _tool_clear_output(params: Dictionary) -> Dictionary:
    var clear_mcp_buffer: bool = params.get("clear_mcp_buffer", true)
    var clear_editor_panel: bool = params.get("clear_editor_panel", true)

    var mcp_cleared: bool = false
    var panel_cleared: bool = false

    if clear_mcp_buffer:
        _log_mutex.lock()
        _log_buffer.clear()
        _log_mutex.unlock()
        mcp_cleared = true

    if clear_editor_panel:
        var editor_interface: EditorInterface = _get_editor_interface()
        if editor_interface:
            var base_control: Control = editor_interface.get_base_control()
            var log_panel: Node = _find_node_by_class(base_control, "EditorLog")
            if log_panel and log_panel.has_method("clear"):
                log_panel.call("clear")
                panel_cleared = true

    return {
        "status": "success",
        "mcp_buffer_cleared": mcp_cleared,
        "editor_panel_cleared": panel_cleared
    }

func _find_node_by_class(node: Node, target_class: String) -> Node:
    if node.get_class() == target_class:
        return node
    for child in node.get_children():
        var result: Node = _find_node_by_class(child, target_class)
        if result:
            return result
    return null
```

#### 关键设计点

| 设计点 | 说明 |
|--------|------|
| 双重清除 | 同时清除 MCP 日志缓冲区和编辑器输出面板 |
| 可选控制 | `clear_mcp_buffer` 和 `clear_editor_panel` 参数独立控制 |
| 线程安全 | MCP 缓冲区清除使用 `_log_mutex` 保护 |
| 归属调试模块 | 与 `get_editor_logs` 配套，形成日志获取+清除的完整闭环 |

#### 实现难度：**低**（MCP 缓冲区清除直接，编辑器面板需遍历节点树找 EditorLog）

---

## 四、实现难度与优先级总结

### 脚本工具增强

| 工具 | 难度 | 核心 API | 风险 |
|------|------|----------|------|
| `attach_script` | 低 | `set_script()` + `load()` | 无 |
| `validate_script` | 中 | `GDScriptLanguage.validate()` | API 返回格式可能变化 |
| `search_in_files` | 中 | `DirAccess` + `RegEx` | 无 |

### 编辑器工具增强

| 工具 | 难度 | 核心 API | 风险 |
|------|------|----------|------|
| `get_editor_screenshot` | 中 | `get_editor_viewport_3d()` + `get_image()` | 无 |
| `get_signals` | 中 | `get_signal_list()` + `get_signal_connection_list()` | 无 |
| `reload_project` | 中 | `EditorFileSystem.scan()` | 无 |

### 调试工具增强

| 工具 | 难度 | 核心 API | 风险 |
|------|------|----------|------|
| `clear_output` | 低 | `_log_buffer.clear()` + 遍历节点树找 EditorLog | API 不直接支持编辑器面板清除 |

### 总计

| 类别 | 工具数 | 实现模块 |
|------|--------|----------|
| 脚本工具增强 | 3 | `script_tools_native.gd` |
| 编辑器工具增强 | 3 | `editor_tools_native.gd` |
| 调试工具增强 | 1 | `debug_tools_native.gd` |
| **合计** | **7** | |

### 已移除（功能重叠）

| 工具 | 重叠工具 | 替代方式 |
|------|----------|----------|
| `get_editor_errors` | `get_editor_logs` | `get_editor_logs(source="mcp", type=["Error"])` |
| `get_output_log` | `get_editor_logs` | `get_editor_logs(source="mcp")` |

### 暂不处理

| 工具 | 原因 |
|------|------|
| `reload_plugin` | 高风险操作，禁用插件会导致 MCP 服务器断开，需架构层面支持 |
| `get_game_screenshot` | 进程隔离限制，编辑器无法直接访问游戏视口，实现复杂度高 |

---

## 五、实现建议

### 推荐实现顺序

1. **第一批（低风险，API 直接支持）**：
   - `attach_script` → `reload_project` → `get_signals`

2. **第二批（中风险，需要适配）**：
   - `search_in_files` → `validate_script` → `get_editor_screenshot`

3. **第三批（调试工具增强）**：
   - `clear_output`

### 公共工具方法

编辑器工具和调试工具中有多个工具需要遍历编辑器节点树（`_find_node_by_class`），建议提取为公共方法：

```gdscript
# 在 debug_tools_native.gd 中添加（clear_output 使用）
static func _find_node_by_class(node: Node, target_class: String) -> Node:
    if node.get_class() == target_class:
        return node
    for child in node.get_children():
        var result: Node = _find_node_by_class(child, target_class)
        if result:
            return result
    return null
```

---

*文档更新时间：2026-05-10*
*基于 Godot 4.x API 文档（Context7: /godotengine/godot-docs）*
*结合代码：`script_tools_native.gd`（6 工具）+ `editor_tools_native.gd`（5 工具）+ `debug_tools_native.gd`（5 工具）*
*变更：移除 2 个重叠工具，移动 1 个工具到调试模块，标记 2 个工具暂不处理*
