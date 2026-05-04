# Godot MCP (Model Context Protocol)

![Godot Version](https://img.shields.io/badge/Godot-4.6-blue?logo=godot-engine)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-orange)

A powerful Godot Engine plugin that integrates AI assistants (Claude, etc.) via the Model Context Protocol (MCP). Enable AI to directly read and modify your Godot projects - scenes, scripts, nodes, and resources - all through natural language.

## 🚀 Features

- **Full Project Access**: AI assistants can read and modify scripts, scenes, nodes, and project resources
- **Native Implementation**: No Node.js dependency required - runs entirely within Godot
- **Real-time Editing**: Apply AI suggestions directly in the editor
- **Comprehensive Tool Set**:
  - **Node Tools**: Create, modify, and manage scene nodes
  - **Script Tools**: Edit, analyze, and create GDScript files
  - **Scene Tools**: Manipulate scene structure and save scenes
  - **Project Tools**: Access project settings and list resources
  - **Editor Tools**: Control editor functionality and debug

## 📦 Installation

### Method 1: Asset Library (Recommended)
1. Open your Godot project
2. Go to **AssetLib** tab in the editor
3. Search for "Godot MCP"
4. Click **Download** and then **Install**

### Method 2: Manual Installation
1. Download or clone this repository
2. Copy the `addons/godot_mcp` folder to your project's `addons/` directory
3. Open your project in Godot
4. Go to **Project > Project Settings > Plugins**
5. Enable "Godot MCP" plugin

## 🔧 Usage

### Enabling the Plugin
1. Open **Project > Project Settings > Plugins**
2. Locate "Godot MCP" in the list
3. Set the status to **Enable**

### Configuring MCP Server
The plugin provides two transport modes:

#### stdio Mode (Default - for local AI assistants)
- Best for: Local development with Claude Desktop
- Configuration: Set `transport_mode = "stdio"` in plugin settings

#### HTTP Mode (for remote access)
- Best for: Network-based AI integration
- Configuration: Set `transport_mode = "http"` and configure `http_port` (default: 9080)
- Optional: Enable `auth_enabled` and set `auth_token` for security

### Connecting with Claude Desktop

#### stdio Mode Configuration
Edit Claude Desktop config file (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "path/to/godot.exe",
      "args": ["--headless", "--script", "res://addons/godot_mcp/mcp_server_native.gd"]
    }
  }
}
```

#### HTTP Mode Configuration
```json
{
  "mcpServers": {
    "godot-mcp": {
      "url": "http://localhost:9080/mcp"
    }
  }
}
```

With authentication:
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

## 💬 Example Prompts

Once connected, you can interact with your Godot project through Claude:

```
@mcp godot-mcp read godot://script/current

I need help optimizing my player movement code. Can you suggest improvements?
```

```
@mcp godot-mcp get-scene-tree

Add a cube in the middle of the scene and create a camera that looks at it.
```

```
Create a main menu with Play, Options, and Quit buttons
```

```
Implement a day/night cycle system with dynamic lighting
```

## 📚 Available Commands

### Node Commands
- `get-scene-tree` - Get scene tree structure
- `get-node-properties` - Get properties of a specific node
- `create-node` - Create a new node
- `delete-node` - Delete a node
- `modify-node` - Update node properties

### Script Commands
- `list-project-scripts` - List all scripts
- `read-script` - Read a specific script
- `modify-script` - Update script content
- `create-script` - Create a new script
- `analyze-script` - Analyze script structure

### Scene Commands
- `list-project-scenes` - List all scenes
- `read-scene` - Read scene structure
- `create-scene` - Create a new scene
- `save-scene` - Save current scene

### Project Commands
- `get-project-settings` - Get project settings
- `list-project-resources` - List project resources

### Editor Commands
- `get-editor-state` - Get current editor state
- `run-project` - Run the project
- `stop-project` - Stop the running project

## 🔒 Security Recommendations

- ✅ **Production**: Always enable authentication (`auth_enabled = true`)
- ✅ **Token**: Use a strong token (≥16 characters with letters, numbers, special characters)
- ✅ **Storage**: Don't commit tokens to version control
- ⚠️ **Remote Access**: Use HTTPS (TLS/SSL) for network access

## 📋 Requirements

- Godot Engine 4.6 or higher
- No additional dependencies (native implementation)

## 📖 Documentation

For detailed documentation, see the `docs/` folder:
- [Getting Started](docs/getting-started.md)
- [Installation Guide](docs/installation-guide.md)
- [Command Reference](docs/command-reference.md)
- [Architecture](docs/architecture.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**yurineko73**

## 🙏 Acknowledgments

- Godot Engine team for the amazing game engine
- Model Context Protocol (MCP) specification
- Claude AI by Anthropic for inspiring this integration

---

**Note**: This is a community plugin and is not officially affiliated with Godot Engine or Anthropic.
