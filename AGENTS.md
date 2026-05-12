# AGENTS.md - Godot MCP Project Guidelines

## Build & Run Commands
- **Run Godot Project**: Open project.godot in Godot Editor

## Code Style Guidelines

### GDScript (Godot)
- Use snake_case for variables, methods, and function names
- Use PascalCase for classes
- Use type hints where possible: `var player: Player`
- Follow Godot singleton conventions (e.g., `Engine`, `OS`)
- Prefer signals for communication between nodes

### General
- Use descriptive names
- Keep functions small and focused
- Add comments for complex logic
- Error handling: use assertions in GDScript

## New Tool Workflow

When creating a new MCP tool, you MUST complete ALL of the following steps:

### Step 1: Implement the tool handler
In the appropriate `*_tools_native.gd` file under `addons/godot_mcp/tools/`:
- Create `_register_<tool_name>(server_core)` and `_tool_<tool_name>(params) -> Dictionary` functions
- Call `server_core.register_tool()` with **8 arguments** (including category and group):
  ```
  server_core.register_tool(
      "tool_name",                    # 1. name
      "Description...",               # 2. description
      input_schema,                   # 3. input schema dict
      Callable(self, "_tool_..."),    # 4. callable
      output_schema,                  # 5. output schema dict
      annotations_dict,               # 6. annotations
      "core"/"supplementary",         # 7. category
      "Group-Name"                    # 8. group (use "X-Advanced" for supplementary)
  )
  ```
  - **core** tools: used for basic operations, always visible
  - **supplementary** tools: advanced features, require opt-in via tool management panel

### Step 2: Register in tool classifier
Edit `addons/godot_mcp/native_mcp/mcp_tool_classifier.gd`:
- Add `{"name": "tool_name", "category": "core"/"supplementary", "group": "Group-Name"}` entry in `_build_classifications()` array
- Then update `test/unit/test_mcp_tool_classifier.gd`:
  - Update `test_all_154_tools_registered` with the new total count (increment by 1)
  - Update `test_core_tools_count_within_limit` or `test_supplementary_tools_count` accordingly
  - If supplementary, add `assert_true(_classifier.is_supplementary_tool("tool_name"), "...")` assertion

### Step 3: Add unit tests
In `test/unit/tools/` or `test/unit/`:
- Create or extend a test file following `extends "res://addons/gut/test.gd"`
- Use `load("res://addons/godot_mcp/tools/...").new()` instead of class_name (GUT CLI mode limitation)
- Cover: missing params → returns error, invalid params → returns error, edge cases
- Reference GUT patterns in `.trae/skills/gut-mcp-testing/SKILL.md`
- Run tests: `& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit`

### Step 4: Update tool documentation
Edit `docs/current/tools-reference.md`:
- Update the overview table with new tool count (adjust rows as needed)
- Add a new tool entry following the existing format:

### Step 4b: Update addon READMEs
Edit `addons/godot_mcp/README.md` and `addons/godot_mcp/README.zh.md`:
- Update the tool counts and descriptions in the overview section to match the new total
- If a new tool category group was added, add a corresponding section row in the feature table
- Ensure English and Chinese versions stay in sync

### Step 4c: Write the tool entry
  ```
  ### N. tool_name
  
  Description...
  
  **参数**：
  | 参数 | 类型 | 必需 | 描述 |
  ...
  
  **返回值**：
  | 字段 | 类型 | 描述 |
  ...
  
  **注解**：`readOnlyHint=...`, `destructiveHint=...`, `idempotentHint=...`, `openWorldHint=...`
  
  ---
  ```
- Update the summary line at the end with the correct total count

### Step 5: Verify
- Run full GUT test suite (command in Step 3)
- Verify 0 failures before committing

## PR 审查与合并流程

参见完整规范文档：
- **Skill 文件：** `.cursor/skills/pr-review-merge/SKILL.md`
- **规范文档：** `docs/development/pr-review-merge-spec.md`

核心步骤：
1. 创建集成分支 `integration/pr-review`
2. 合并目标 PR 到集成分支
3. 逐文件审查代码、测试覆盖、规范
4. 运行 GUT 全量测试（0 failures 为硬性要求）
5. 修复问题、记录审查文档
6. Squash 合并到 `main`

注意：`_debounce_save()` 必须在 UI toggle handler 中调用，否则设置无法持久化。
