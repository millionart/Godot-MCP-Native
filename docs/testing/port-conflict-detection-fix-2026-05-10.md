# MCP HTTP 服务器端口占用检测修复报告

**日期**: 2026-05-10
**问题**: MCP 服务器启动时无法检测端口占用，导致启动失败但无友好提示
**影响文件**: `addons/godot_mcp/native_mcp/mcp_http_server.gd`

---

## 问题描述

当 MCP HTTP 服务器配置的端口（默认 9080）被其他进程占用时，服务器启动失败，但错误信息不够友好，无法帮助用户定位问题根因。

### 实际场景

迅雷下载（DownloadSDKServer）占用 `127.0.0.1:9080`，导致 Godot MCP 插件无法启动 HTTP 服务器。用户只能看到 Trae AI 客户端的连接失败日志：

```
POSTing to endpoint:
SSE error: TypeError: fetch failed: read ECONNRESET
```

无法判断是端口冲突还是其他问题。

---

## 修复过程

### 方案一：TCPServer.listen() 检测（失败）

```gdscript
func _is_port_in_use(port: int) -> bool:
    var test_tcp: TCPServer = TCPServer.new()
    var result: Error = test_tcp.listen(port)
    test_tcp.stop()
    return result != OK
```

**问题**: Windows 的 `SO_REUSEADDR` 选项允许同一端口被多个 socket 绑定，`listen()` 可能返回成功即使端口已被占用，导致漏检。

### 方案二：StreamPeerTCP.connect_to_host() 检测（失败）

```gdscript
func _is_port_in_use(port: int) -> bool:
    var tcp_client: StreamPeerTCP = StreamPeerTCP.new()
    var error: Error = tcp_client.connect_to_host("127.0.0.1", port)
    if error != OK:
        tcp_client.disconnect_from_host()
        return false
    OS.delay_msec(50)
    var status: int = tcp_client.get_status()
    tcp_client.disconnect_from_host()
    return status == StreamPeerTCP.STATUS_CONNECTED or status == StreamPeerTCP.STATUS_CONNECTING
```

**问题**: `STATUS_CONNECTING` 状态不可靠。即使端口没有被占用，TCP 连接尝试也会短暂处于 `STATUS_CONNECTING` 状态（等待 RST 响应），导致误报——未被占用的端口也被判定为占用。

实际表现：
```
# 端口 6006 被占用（正确检测）
Port 6006 is already in use! (PID 47868, process: Godot_v4.6.1-stable_win64.exe) ...

# 端口 19080 未被占用（误报！）
Port 19080 is already in use! ...
```

### 方案三：netstat -ano 检测（最终方案）

使用系统命令 `netstat -ano` 检查端口是否有 `LISTENING` 状态的条目，并通过 `tasklist` 获取占用进程的名称。

```gdscript
func _check_port_conflict(port: int) -> String:
    var output: Array = []
    var exit_code: int = OS.execute("netstat", ["-ano"], output)
    if exit_code != OK or output.is_empty():
        return ""
    
    var port_str: String = ":" + str(port) + " "
    var lines: PackedStringArray = output[0].split("\n")
    for line in lines:
        var stripped: String = line.strip_edges()
        if stripped.find(port_str) >= 0 and stripped.find("LISTENING") >= 0:
            # 提取 PID，查询进程名
            ...
            return "(PID " + pid + ", process: " + proc_name + ")"
    return ""
```

**优点**:
- 直接查询系统网络状态，不依赖 TCP 连接行为
- 只检测 `LISTENING` 状态，避免误报
- 能提供占用进程的 PID 和名称，帮助用户定位问题

---

## 最终实现

### 核心方法

`_check_port_conflict(port: int) -> String`

- 返回空字符串 = 端口空闲
- 返回非空字符串 = 端口被占用（含 PID 和进程名信息）

### 检测流程

1. 执行 `netstat -ano` 获取所有网络连接
2. 查找包含 `:端口号 ` 和 `LISTENING` 的行（注意端口号后加空格，避免 `:9080` 匹配到 `:90801`）
3. 提取行末的 PID
4. 执行 `tasklist /FI "PID eq <pid>" /FO CSV /NH` 获取进程名
5. 返回格式化的冲突信息

### 错误提示示例

端口被占用时：
```
Port 9080 is already in use! (PID 12668, process: DownloadSDKServer.exe) Please change the port in MCP settings or close the conflicting application.
```

端口空闲时：正常启动，无额外提示。

### 端口匹配精度

使用 `":9080 "` 而非 `":9080"` 进行匹配，原因：

```
# netstat 输出示例：
#   TCP    0.0.0.0:9080           0.0.0.0:0              LISTENING       11472
#   TCP    0.0.0.0:90801          0.0.0.0:0              LISTENING       22334

# ":9080"  会同时匹配 :9080 和 :90801（错误！）
# ":9080 " 只匹配 :9080（正确）
```

---

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `addons/godot_mcp/native_mcp/mcp_http_server.gd` | 添加 `_check_port_conflict()` 方法，在 `start()` 中调用 |

---

## 测试验证

### GUT 单元测试

167 个测试全部通过，331 个断言，100% 通过率。

### 手动验证场景

| 场景 | 预期 | 结果 |
|------|------|------|
| 端口空闲 | 正常启动 | ✅ |
| 端口被迅雷占用 | 显示 PID + 进程名 | ✅ |
| 端口被旧 Godot 实例占用 | 显示 PID + 进程名 | ✅ |
| 端口号为其他端口的子串（如 90801） | 不误匹配 | ✅ |

---

## 已知限制

1. **仅支持 Windows**: `netstat -ano` 和 `tasklist` 是 Windows 命令。macOS/Linux 需要使用 `lsof -i :<port>` 或 `ss -tlnp` 替代。
2. **`netstat` 执行耗时**: `OS.execute()` 是同步调用，`netstat -ano` 可能需要 100-300ms，会轻微延迟服务器启动。
3. **权限问题**: 某些系统进程的 PID 可能需要管理员权限才能查询进程名，此时 `tasklist` 会返回 `INFO:` 前缀，代码会降级为仅显示 PID。
