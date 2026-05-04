# HTTP Server Bug 修复记录

## 概述

本文档记录了 `McpHttpServer` 在 2026-05-04 发现并修复的三个 Bug：

1. **HTTP Body 长度计算错误** — UTF-8 多字节字符导致工具调用超时
2. **线程安全 — 连接数组并发修改** — 启动时 `Parameter "_fp" is null` 和 `get_ticks_msec on a null value`
3. **线程安全 — stop() 清理顺序错误** — 关闭时 `Thread object destroyed without wait_to_finish()`

---

## Bug 1：HTTP Body 长度计算错误（UTF-8 多字节字符）

### 问题描述

MCP 工具 `debug_print`、`execute_script`、`execute_editor_script` 在参数包含 **非 ASCII 字符**（中文、emoji 等多字节 UTF-8 字符）时，HTTP 请求超时（30秒后返回 `408 Request timeout`），工具无法正常执行。

### 受影响工具

- `debug_print` — 中文 message/category 参数导致超时
- `execute_script` — 包含中文的表达式导致超时
- `execute_editor_script` — 包含中文的代码导致超时

### 具体表现

| 工具 | 纯 ASCII 参数 | 包含中文/emoji 参数 |
|------|---------------|---------------------|
| `debug_print` | 正常返回 `{"status":"success"}` | 返回 `[]`，30秒超时 |
| `execute_script` | 正常返回 `{"status":"success"}` | 30秒超时 |
| `execute_editor_script` | 正常返回 `{"success":true}` | 30秒超时 |

### 根因分析

#### 代码位置

`addons/godot_mcp/native_mcp/mcp_http_server.gd` 第 271 行

#### 错误代码（修复前）

```gdscript
if headers_complete:
    var header_end: int = request.find("\r\n\r\n")
    var body_received: int = request.length() - header_end - 4
    
    if content_length >= 0:
        if body_received >= content_length:
            break
```

#### 错误原因

`request.length()` 返回的是 **Unicode 字符数**（code point 数量），而 HTTP `Content-Length` 头声明的是 **UTF-8 字节数**。

对于纯 ASCII 文本，一个字符 = 一个字节，两者相等，所以没问题。

但对于多字节 UTF-8 字符：
- 中文字符：UTF-8 编码占 3 字节 → `request.length()` 算 1 字符
- emoji 字符：UTF-8 编码占 4 字节 → `request.length()` 算 1 字符

**示例**：请求 body 为 `{"message":"你好"}`
- `Content-Length`: 22 字节（UTF-8 编码的 JSON）
- `request.length()`: 16 字符（Unicode 字符数）
- `body_received`: `16 - header_end - 4` → 远小于 22

结果：`body_received` 永远达不到 `content_length` → 循环永不退出 → 30 秒后超时 → 返回 `408 Request timeout`

### 修复方案

#### 正确代码（修复后）

```gdscript
if headers_complete:
    var header_end: int = request.find("\r\n\r\n")
    var body: String = request.substr(header_end + 4)
    var body_received: int = body.to_utf8_buffer().size()
    
    if content_length >= 0:
        if body_received >= content_length:
            break
```

#### 修复说明

1. 先用 `request.substr(header_end + 4)` 提取 body 部分
2. 再用 `body.to_utf8_buffer().size()` 获取 body 的 **UTF-8 字节数**
3. 用字节数 `body_received` 与 HTTP `Content-Length` 比较

这样 `body_received` 和 `content_length` 的计算单位一致（都是字节数），多字节 UTF-8 字符也能正确匹配。

---

## Bug 2：线程安全 — 连接数组与 TCP Server 并发修改

### 问题描述

MCP 服务器启动后，Godot 输出面板出现以下两个错误：

```
ERROR: core/variant/array.cpp:59 - Parameter "_fp" is null.
ERROR: res://addons/godot_mcp/native_mcp/mcp_http_server.gd:187 - Cannot call method 'get_ticks_msec' on a null value.
```

### 根因分析

`McpHttpServer` 的 HTTP 服务运行在**独立线程**中（`_http_server_loop` 在 `Thread` 中运行），而 `stop()` 方法由**主线程**调用。两个线程同时访问以下共享数据：

1. **`_connections` 数组** — 主线程在 `stop()` 中遍历并清理 `_connections`，同时 HTTP 线程也在遍历 `_connections` 处理请求，导致 `Array` 内部迭代器失效 → `Parameter "_fp" is null`
2. **`_tcp_server` 对象** — 主线程在 `stop()` 中将 `_tcp_server` 设为 `null`，但 HTTP 线程仍在调用 `_tcp_server.is_connection_available()` 和 `_tcp_server.take_connection()` → `Cannot call method on a null value`
3. **`Time.get_ticks_msec()` 调用** — 在 `_tcp_server` 被置 null 后，`_http_server_loop` 继续运行到 `var current_time: int = Time.get_ticks_msec()` 时，虽然 `Time` 是全局 API 通常可用，但线程上下文切换可能导致内部状态异常

#### 代码位置

`addons/godot_mcp/native_mcp/mcp_http_server.gd`

- `_http_server_loop()` — HTTP 线程（约 120-210 行）
- `stop()` — 主线程（约 220-250 行）

### 修复方案

#### 1. 在 `_http_server_loop` 中添加空值保护

在每次使用 `_tcp_server` 前检查是否为 `null`：

```gdscript
func _http_server_loop() -> void:
    if _log_callback.is_valid():
        _log_callback.call("INFO", "Server loop started")
    
    var last_keepalive: int = Time.get_ticks_msec()
    
    while _active:
        if not _tcp_server:          # 空值保护
            break
        
        var peer: StreamPeerTCP = null
        if _tcp_server.is_connection_available():
            peer = _tcp_server.take_connection()
        ...
```

#### 2. 使用 `_connections.duplicate()` 安全遍历

遍历连接时创建副本，避免主线程同时修改原数组：

```gdscript
# 修复前：直接遍历共享数组
for p in _connections:

# 修复后：遍历副本，避免并发修改
var current_connections: Array[StreamPeerTCP] = _connections.duplicate()
for p in current_connections:
    if not _active:      # 额外空值保护
        break
```

---

## Bug 3：线程安全 — stop() 清理顺序错误

### 问题描述

关闭 MCP 服务器时，Godot 输出面板出现以下警告：

```
WARNING: core/os/thread.cpp:102 - A Thread object is being destroyed without its completion having been realized.
WARNING: Please call wait_to_finish() on it to ensure correct cleanup.
```

### 根因分析

#### 错误代码（修复前）

```gdscript
func stop() -> void:
    _active = false
    
    # ❌ 先清理连接（HTTP 线程还在运行）
    for peer in _connections:
        if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            peer.disconnect_from_host()
    _connections.clear()
    
    # ❌ 再等待线程结束（顺序反了）
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    _thread = null
    
    # ❌ 最后关闭 TCP 服务器
    if _tcp_server:
        _tcp_server.stop()
        _tcp_server = null
    
    server_stopped.emit()
```

#### 错误原因

1. **清理顺序错误**：`stop()` 先清理了 `_connections` 和 `_tcp_server`，但此时 HTTP 线程还在运行。线程在下次循环迭代时发现 `_connections` 已被清空、`_tcp_server` 已被设为 `null`，导致 Bug 2 中的错误
2. **线程生命周期管理错误**：Godot 的 `Thread` 对象析构时，如果线程尚未通过 `wait_to_finish()` 完成，会触发警告。修复前的代码先清理数据再等线程，但线程可能在等待期间因数据已被清理而崩溃，导致 `wait_to_finish()` 无法正常返回
3. **TCP 服务器未及时停止**：修复前 `_tcp_server.stop()` 在最后才调用，HTTP 线程在此期间仍在接受新连接，增加了竞争条件窗口

### 修复方案

#### 正确代码（修复后）

```gdscript
func stop() -> void:
    _active = false
    
    # ✅ 先停止 TCP 服务器（不再接受新连接）
    if _tcp_server:
        _tcp_server.stop()
        _tcp_server = null
    
    # ✅ 再等待线程结束（线程会在下次循环检测到 _active=false 后退出）
    if _thread and _thread.is_alive():
        _thread.wait_to_finish()
    _thread = null
    
    # ✅ 线程已退出，安全清理连接
    for peer in _connections:
        if peer and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
            peer.disconnect_from_host()
    
    _connections.clear()
    
    server_stopped.emit()
    if _log_callback.is_valid():
        _log_callback.call("INFO", "Server stopped")
```

#### 修复原则

正确的清理顺序应该是 **逆序**：

| 顺序 | 操作 | 说明 |
|------|------|------|
| 1 | `_active = false` | 通知线程退出循环 |
| 2 | `_tcp_server.stop()` | 停止接受新连接 |
| 3 | `_thread.wait_to_finish()` | **等待线程完全退出** |
| 4 | 清理 `_connections` | 线程已退出，安全修改 |
| 5 | 发射 `server_stopped` | 通知主线程清理完成 |

---

## 测试结果

| 测试项 | 修复前 | 修复后 |
|--------|--------|--------|
| `debug_print` 中文参数 | `[]` + 30s 超时 | `{"status":"success","printed_message":"[测试] 中文消息测试！🎉"}` ✅ |
| `debug_print` emoji 参数 | `[]` + 30s 超时 | `{"status":"success","printed_message":"[验证] test with emoji 🎉"}` ✅ |
| `execute_editor_script` 中文代码 | 30s 超时 | `{"output":["结果: 你好世界","中文测试成功！🎉"],"success":true}` ✅ |
| `execute_script` 中文表达式 | 30s 超时 | `{"result":"中文测试成功！🎉 - 2","status":"success"}` ✅ |
| 启动时 `Parameter "_fp" is null` | 出现 ❌ | 消失 ✅ |
| 启动时 `get_ticks_msec on null` | 出现 ❌ | 消失 ✅ |
| 关闭时 Thread 未 wait_to_finish | 出现 ⚠️ | 消失 ✅ |
| GUT 单元测试 | — | 231/231 全部通过 ✅ |
| 纯 ASCII 参数调用 | 正常 ✅ | 正常 ✅ |

## 影响范围

- **Bug 1**：所有通过 HTTP POST 发送的 MCP 工具调用都可能受影响，只要参数中包含多字节 UTF-8 字符。实际受影响最频繁的工具是：`debug_print`、`execute_script`、`execute_editor_script`
- **Bug 2 & 3**：每次 MCP 服务器启动/关闭都会触发，影响服务器生命周期管理的稳定性

## 相关文件

- 修复文件：`addons/godot_mcp/native_mcp/mcp_http_server.gd`
- 修复日期：2026-05-04
- 文档：`docs/debugging/http-server-bug-fixes-2026-05-04.md`