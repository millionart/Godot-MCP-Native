# Godot MCP Native (模型上下文协议)

[English Version](README.md)

![Godot 版本](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![许可证](https://img.shields.io/badge/License-MIT-green)
![版本](https://img.shields.io/badge/Version-1.0.0-orange)

一个强大的 Godot 引擎插件，通过模型上下文协议 (MCP) 集成 AI 助手（如 Claude 等）。让 AI 可以直接通过自然语言读取和修改您的 Godot 项目——场景、脚本、节点和资源。

## 🚀 功能特性

- **完整项目访问**：AI 助手可以读取和修改脚本、场景、节点和资源
- **原生实现**：无需 Node.js 依赖——完全在 Godot 中运行
- **实时编辑**：直接在编辑器中应用 AI 建议
- **全面的工具集**（43+ 工具）：
  - **节点工具**（16 个）：创建、修改、管理场景节点，复制、移动、重命名，信号连接，组管理
  - **脚本工具**（6 个）：编辑、分析和创建 GDScript 文件
  - **场景工具**（6 个）：操作场景结构并保存场景
  - **编辑器工具**（5 个）：控制编辑器功能和调试
  - **调试工具**（5 个）：调试和日志记录
  - **项目工具**（5 个）：访问项目设置和列出资源

## 📦 安装

### 方法 1：资源库（推荐）
1. 打开您的 Godot 项目
2. 进入编辑器中的 **AssetLib** 标签页
3. 搜索 "Godot MCP Native"
4. 点击 **下载** 然后 **安装**

### 方法 2：手动安装
1. 下载或克隆此仓库
2. 将 `addons/godot_mcp` 文件夹复制到项目的 `addons/` 目录
3. 在 Godot 中打开项目
4. 进入 **项目 > 项目设置 > 插件**
5. 启用 "Godot MCP Native" 插件

## 🔧 使用

### 启用插件
1. 打开 **项目 > 项目设置 > 插件**
2. 在列表中找到 "Godot MCP Native"
3. 将状态设置为 **启用**

### 配置 MCP 服务器
插件提供两种传输模式：

#### HTTP 模式（用于远程访问）
- 适用场景：基于网络的 AI 集成
- 配置：在插件设置中设置 `transport_mode = "http"` 并配置 `http_port`（默认：9080）
- 可选：启用 `auth_enabled` 并设置 `auth_token` 以保障安全

### 连接 Claude Desktop

#### HTTP 模式配置
编辑 Claude Desktop 配置文件（`claude_desktop_config.json`）：

```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

带身份验证：
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp",
      "headers": {
        "Authorization": "Bearer your-secret-token-here"
      }
    }
  }
}
```

## 💬 示例提示

连接后，您可以通过 Claude 与 Godot 项目交互：

```
@mcp godot-mcp read godot://script/current

我需要帮助优化我的玩家移动代码。能提出改进建议吗？
```

```
@mcp godot-mcp get-scene-tree

在场景中间添加一个立方体，并创建一个相机看向它。
```

```
创建一个主菜单，包含开始、选项和退出按钮
```

```
实现一个带有动态光照的昼夜循环系统
```

## 📚 可用命令

### 节点工具 (16)
- `get-scene-tree` - 获取场景树结构
- `get-node-properties` - 获取特定节点的属性
- `create-node` - 创建新节点
- `delete-node` - 删除节点
- `update-node-property` - 更新节点属性
- `list-nodes` - 列出父节点下的所有节点
- `duplicate-node` - 复制节点及子节点
- `move-node` - 移动节点到新父节点
- `rename-node` - 重命名节点
- `add-resource` - 向节点添加资源子节点（碰撞形状、网格等）
- `set-anchor-preset` - 设置 Control 节点锚点预设
- `connect-signal` - 连接节点间的信号
- `disconnect-signal` - 断开信号连接
- `get-node-groups` - 获取节点所属的组
- `set-node-groups` - 设置节点的组成员关系
- `find-nodes-in-group` - 查找组中的所有节点

### 脚本工具 (6)
- `list-project-scripts` - 列出所有脚本
- `read-script` - 读取特定脚本
- `modify-script` - 更新脚本内容
- `create-script` - 创建新脚本
- `analyze-script` - 分析脚本结构
- `get-current-script` - 获取当前正在编辑的脚本

### 场景工具 (6)
- `list-project-scenes` - 列出所有场景
- `read-scene` - 读取场景结构
- `create-scene` - 创建新场景
- `save-scene` - 保存当前场景
- `open-scene` - 打开场景
- `get-current-scene` - 获取当前场景信息

### 项目工具 (5)
- `get-project-info` - 获取项目信息
- `get-project-settings` - 获取项目设置
- `list-project-resources` - 列出项目资源
- `create-resource` - 创建新资源
- `get-project-structure` - 获取项目目录结构

### 编辑器工具 (5)
- `get-editor-state` - 获取当前编辑器状态
- `run-project` - 运行项目
- `stop-project` - 停止运行中的项目
- `get-selected-nodes` - 获取选中的节点
- `set-editor-setting` - 修改编辑器设置

### 调试工具 (5)
- `get-editor-logs` - 获取编辑器/运行时日志
- `execute-script` - 执行 GDScript 表达式
- `get-performance-metrics` - 获取性能数据
- `debug-print` - 打印调试信息
- `execute-editor-script` - 执行 GDScript 脚本

## 🔒 安全建议

- ✅ **生产环境**：始终启用身份验证（`auth_enabled = true`）
- ✅ **令牌**：使用强令牌（≥16 个字符，包含字母、数字、特殊字符）
- ✅ **存储**：不要将令牌提交到版本控制
- ⚠️ **远程访问**：使用 HTTPS（TLS/SSL）进行网络访问

## 📋 要求

- Godot Engine 4.x（推荐 4.5 或更高版本）
- 无额外依赖（原生实现）

## 📖 文档

详细文档请查看 `docs/current/` 文件夹：
- [快速开始指南](docs/current/quickstart.md)
- [架构设计](docs/current/architecture.md)
- [工具参考](docs/current/tools-reference.md)
- [测试指南](docs/current/testing-guide.md)

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 👤 作者

**yurineko73**

## 🙏 致谢

- Godot 引擎团队带来的出色游戏引擎
- 模型上下文协议 (MCP) 规范
- Anthropic 的 Claude AI 启发了此集成

---

**注意**：这是一个社区插件，与 Godot Engine 或 Anthropic 无官方关联。
