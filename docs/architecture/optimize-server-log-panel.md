# Server Log 面板性能优化方案

## 问题分析

当前 `mcp_panel_native.gd` 的 Server Log 面板使用单个 `TextEdit` (`_log_text_edit`) 显示所有日志。当日志量过大时，`TextEdit` 的文本会变得非常长，导致：

1. **文本拼接性能差**：`_log_text_edit.text += message + "\n"` 每次追加都会重新处理整个文本（Godot 4.x 已知性能问题，见 [godot#64350](https://github.com/godotengine/godot/issues/64350)）
2. **渲染卡顿**：超长文本导致 TextEdit 渲染和布局计算变慢
3. **内存持续增长**：无上限的日志累积

> 注意：原始代码中 `_log_text_edit.text += message + "\n"` 已被注释掉，说明开发者已经意识到此问题但尚未解决。

## 方案对比

### 方案 A：环形缓冲区 + TextEdit + 本地文件缓存（最终采用）

**思路**：维护一个固定大小的日志行数组（环形缓冲区），限制 TextEdit 显示行数，超出部分写入本地缓存文件。

**优点**：
- 实现简单，改动最小
- 内存有上限，TextEdit 最多显示 100 行
- 保持 TextEdit 的可选中/复制功能
- 日志不丢失，溢出部分自动写入本地文件

**缺点**：
- 超限时需要重建整个文本，有瞬间开销
- 本地文件 I/O 有轻微开销（每 50 条写入一次）

**关键优化**：
- 使用 `"\n".join()` 重建文本代替 `text +=`（避免逐行拼接的性能问题）
- 设置最大显示行数 100 行，超限自动裁剪
- 使用定时器合并高频日志更新（debounce 100ms），避免每条日志都触发刷新
- 每 50 条日志自动写入本地缓存文件 `user://mcp_server.log`
- 每次启动覆盖写入日志文件，旧文件超过 5MB 自动归档为 `.log.1`

### 方案 B：ItemList 替代 TextEdit

**思路**：用 `ItemList` 替代 `TextEdit`，每条日志作为列表的一个 item。

**优点**：
- ItemList 天然支持虚拟化（只渲染可见行），性能极佳
- 每行独立管理，无需处理整体文本

**缺点**：
- ItemList 不支持文本选中/复制
- 不支持自动换行，长日志行会被截断
- 失去 TextEdit 的语法高亮能力
- 改动较大

### 方案 C：RichTextLabel + 环形缓冲区

**思路**：用 `RichTextLabel` 替代 `TextEdit`，配合环形缓冲区，支持按日志级别着色。

**优点**：
- 支持按级别着色（ERROR 红色、WARN 黄色等）
- `append_text()` 比 TextEdit 的 `text +=` 性能更好（增量追加）
- 可读性更好

**缺点**：
- RichTextLabel 不可编辑/选中复制（只读场景可接受）
- 长文本仍有渲染压力，仍需环形缓冲区限制

## 最终采用方案：方案 A（环形缓冲区 + TextEdit + debounce + 本地文件缓存）

理由：
1. 改动最小，不改变 UI 组件类型
2. 环形缓冲区限制日志行数为 100 行，防止无限增长和渲染卡顿
3. debounce 机制合并高频日志，减少刷新次数
4. 本地文件缓存确保日志不丢失，每 50 条批量写入
5. 保留 TextEdit 的选中/复制能力

## 实现步骤

### Step 1：添加日志缓冲区变量

在 `mcp_panel_native.gd` 顶部添加：

```gdscript
var _log_buffer: Array[String] = []
var _max_log_lines: int = 100
var _log_flush_index: int = 0
var _log_debounce_timer: Timer = null
var _log_file_path: String = "user://mcp_server.log"
var _log_file_flush_count: int = 50
var _log_pending_write: Array[String] = []
var _log_file_initialized: bool = false
var _max_log_file_size: int = 5242880
```

变量说明：
- `_log_buffer`：显示用日志缓冲区，最多保留 100 行
- `_max_log_lines`：TextEdit 最大显示行数（100）
- `_log_flush_index`：已刷新到 TextEdit 的缓冲区索引，用于增量追加
- `_log_debounce_timer`：防抖定时器，100ms 合并刷新
- `_log_file_path`：本地缓存日志文件路径
- `_log_file_flush_count`：每累积 50 条待写入日志就写入文件
- `_log_pending_write`：待写入文件的日志队列
- `_log_file_initialized`：标记本次启动是否已初始化日志文件（覆盖写入）
- `_max_log_file_size`：日志文件最大大小 5MB，超过则归档

### Step 2：创建 debounce 定时器

在 `_create_log_tab()` 中创建定时器，用于合并高频日志更新：

```gdscript
_log_debounce_timer = Timer.new()
_log_debounce_timer.wait_time = 0.1
_log_debounce_timer.one_shot = true
_log_debounce_timer.timeout.connect(_flush_log_buffer)
add_child(_log_debounce_timer)
```

### Step 3：修改 `_append_log()` 方法

将直接操作 TextEdit 改为先写入缓冲区，累积到阈值时写入文件，再通过 debounce 刷新显示：

```gdscript
func _append_log(message: String) -> void:
    if not _log_text_edit:
        return
    _log_buffer.append(message)
    _log_pending_write.append(message)
    if _log_buffer.size() > _max_log_lines * 2:
        _log_buffer = _log_buffer.slice(_log_buffer.size() - _max_log_lines)
        _log_flush_index = 0
    if _log_pending_write.size() >= _log_file_flush_count:
        _flush_log_to_file()
    if _log_debounce_timer and _log_debounce_timer.is_stopped():
        _log_debounce_timer.start()
```

### Step 4：实现 `_flush_log_to_file()` 方法

每 50 条日志写入本地缓存文件，启动时覆盖写入：

```gdscript
func _flush_log_to_file() -> void:
    if _log_pending_write.is_empty():
        return
    if not _log_file_initialized:
        if FileAccess.file_exists(_log_file_path):
            var existing: FileAccess = FileAccess.open(_log_file_path, FileAccess.READ)
            if existing:
                var size: int = existing.get_length()
                existing.close()
                if size > _max_log_file_size:
                    var old_path: String = _log_file_path + ".1"
                    if FileAccess.file_exists(old_path):
                        DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
                    DirAccess.rename_absolute(ProjectSettings.globalize_path(_log_file_path), ProjectSettings.globalize_path(old_path))
        var file: FileAccess = FileAccess.open(_log_file_path, FileAccess.WRITE)
        if file:
            file.close()
        _log_file_initialized = true
    var file: FileAccess = FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
    if file:
        file.seek_end()
        for line in _log_pending_write:
            file.store_line(line)
        file.close()
    _log_pending_write.clear()
    _log_buffer.append("[MCP] Log flushed to %s" % _log_file_path)
    if _log_debounce_timer and _log_debounce_timer.is_stopped():
        _log_debounce_timer.start()
```

### Step 5：实现 `_flush_log_buffer()` 方法

使用 `"\n".join()` 重建文本（避免 `insert_line_at` 的索引越界问题）：

```gdscript
func _flush_log_buffer() -> void:
    if not _log_text_edit:
        return
    if _log_flush_index >= _log_buffer.size():
        return
    _log_flush_index = _log_buffer.size()
    var start_index: int = maxi(0, _log_buffer.size() - _max_log_lines)
    _log_text_edit.text = "\n".join(_log_buffer.slice(start_index))
    _log_text_edit.scroll_vertical = _log_text_edit.get_line_count()
```

### Step 6：修改 `clear_log()` 方法

清空缓冲区、文件写入队列和 TextEdit：

```gdscript
func clear_log() -> void:
    _log_buffer.clear()
    _log_flush_index = 0
    _log_pending_write.clear()
    if _log_text_edit:
        _log_text_edit.text = ""
```

## 实现过程中遇到的问题与修复

### 问题 1：`insert_line_at` 索引越界

**现象**：
```
ERROR: scene/gui/text_edit.cpp:4214 - Index p_line = 1 is out of bounds (text.size() = 1).
```

**原因**：`insert_line_at(get_line_count(), text)` 在 TextEdit 为空时越界。空 TextEdit 的 `get_line_count()` 返回 1（有一行空行），但有效插入索引最大为 0。

**修复**：放弃 `insert_line_at` 方案，改用 `"\n".join()` 从缓冲区重建文本。由于 debounce 已将刷新频率限制为 100ms 一次，重建开销可控，且完全避免了索引越界问题。

### 问题 2：日志文件无限增长

**现象**：日志文件使用 `seek_end()` 追加写入，不会在启动时清空，导致文件越来越大。

**修复**：
- 引入 `_log_file_initialized` 标志，首次写入时以 `WRITE` 模式打开文件（覆盖写入）
- 后续写入以 `READ_WRITE` 模式追加
- 启动时检查旧文件大小，超过 5MB 自动归档为 `.log.1`

### 问题 3：TextEdit 100 行仍然卡顿

**现象**：初始方案设置最大 500 行，在高频日志场景下仍有卡顿。

**修复**：
- 将 `_max_log_lines` 从 500 降至 100
- 增加本地文件缓存机制，每 50 条日志写入 `user://mcp_server.log`
- 写入后在面板显示提醒 `[MCP] Log flushed to user://mcp_server.log`

## 数据流

```
日志消息 → _log_buffer (显示用，最多100行)
         → _log_pending_write (文件写入队列)
              ↓ 累积50条
         _flush_log_to_file() → 追加写入 user://mcp_server.log
              ↓ 写入后
         面板显示 "[MCP] Log flushed to user://mcp_server.log"
              ↓ debounce 100ms
         _flush_log_buffer() → TextEdit 显示最近100行
```

## 涉及文件

- `addons/godot_mcp/ui/mcp_panel_native.gd`（主要修改）
