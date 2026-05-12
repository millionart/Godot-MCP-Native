---
name: pr-review-merge
description: "PR 审查、测试、修复、Squash 合并全流程。从创建集成分支到最终合并到 main。使用场景：审查 PR 代码、运行 GUT 测试、修复问题、Squash 合并提交。"
---

# PR Review & Merge Workflow

审查从 GitHub 获取的 PR 分支，确认代码质量后 squash 合并到 main。

## 前置条件

- 已通过 `git fetch origin 'refs/pull/*/head:refs/remotes/origin/pr/*'` 获取 PR refs
- GUT 测试框架已安装（`addons/gut/`）
- 了解该 PR 的 GitHub 描述（通过 `gh` 或网页获取）

## 完整工作流

### Step 1：初始化集成分支

```bash
git checkout main
git checkout -b integration/pr-review
```

如果分支已存在：
```bash
git checkout main
git branch -D integration/pr-review
git checkout -b integration/pr-review
```

### Step 2：合并 PR 到集成分支

```bash
git merge origin/pr/<number> --no-edit
```

解决冲突后：
```bash
git add <resolved-files>
git commit --no-edit
```

### Step 3：全面审查代码

对每个变更文件逐项检查：

**3a. 功能完整性**
- 新增功能是否形成闭环（策略→工具→UI→文档）
- 参数校验是否完整（缺省值、边界值）
- 错误处理是否恰当

**3b. 测试覆盖**
对照变更文件逐项检查测试覆盖，使用矩阵记录：

| 变更文件 | 变更内容 | 对应测试文件 | 覆盖状态 |
|----------|----------|-------------|----------|
| `xxx.gd` | 具体变更 | `test_xxx.gd` | ✅/❌ |

检查要点：
- 新增函数 → 有对应测试用例
- 修改逻辑 → 边界条件测试
- 导出变量 → `get_script_property_list()` 断言
- Schema 变更 → 新参数在 input_schema 中可查

**3c. 代码规范**

检查清单：
- [ ] snake_case 变量/方法命名
- [ ] PascalCase 类名
- [ ] 类型提示完整
- [ ] `@export` 变量有 setter 时调用 `notify_property_list_changed()`
- [ ] UI toggle handler 调用 `_debounce_save()`（持久化）
- [ ] `extends "res://addons/gut/test.gd"`（GUT 测试）
- [ ] 无硬编码路径/Token
- [ ] 错误提示中包含具体参数名

**3d. 重复代码检查**
- 跨文件的重复函数 → 提取到共享模块
- 魔法字符串 → 定义为常量

### Step 4：运行 GUT 测试

```bash
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

验收标准：
- **0 failures**、**0 errors**
- 新增测试全部通过

### Step 5：修复发现的问题

记录问题分级：
- 🔴 **阻断级**：功能错误、测试失败——必须修复后才能合并
- 🟡 **优化级**：代码重复、缺少测试——建议修复或记录
- 📝 **记录级**：CI 集成缺失等——记录到文档待后续处理

修复流程：
1. 直接在 `integration/pr-review` 分支修改
2. 修改后重新运行 GUT 验证
3. 确认通过后提交修复 commit

### Step 6：记录审查文档

创建审查文档到 `docs/debugging/`：

```
docs/debugging/pr<number>-<feature>-review-<date>.md
```

文档模板：
```markdown
# PR #N <标题> 审查报告

**日期：** <yyyy-mm-dd>
**审查分支：** integration/pr-review

## 1. GUT 测试结果
| 指标 | 数值 |
## 2. 已修复的问题
### 问题 N：<描述> ✅
**文件：** 路径:行号
**修复：** 说明
## 3. 已记录的问题
### 问题 N：<描述> 🔶
## 4. 测试覆盖率矩阵
| 变更文件 | 测试覆盖 | 状态 |
## 5. 审查结论
```

### Step 7：Squash 合并到 main

```bash
# 切回 main 并更新
git checkout main
git pull origin main

# Squash 合并（保留集成分支上的修复 commits）
git merge --squash integration/pr-review

# 编写提交信息
git commit
```

提交信息规范：
- 第一行：`feat/fix/refactor: <概括>`
- 空一行
- 主体：逐项列出变更（中英文均可，保持项目一致）

示例：
```
feat: 新增 Vibe Coding 免打扰模式

新增功能：
- 新增 XXX 策略类
- N 个工具入口添加策略检查
- 插件导出新变量

配套修改：
- 文档更新
- 新增 GUT 测试 N 个
- 修复 XX 持久化问题
```

### Step 8：验证 main

```bash
# 重新运行全量 GUT 测试
# 运行命令同 Step 4，确认 0 failures

# 推送到远程
git push origin main
```

## 常用命令速查

| 操作 | 命令 |
|------|------|
| 获取 PR refs | `git fetch origin 'refs/pull/*/head:refs/remotes/origin/pr/*'` |
| 查看 PR diff stat | `git diff --stat origin/main...origin/pr/<N>` |
| 查看 PR unique commits | `git log origin/main..origin/pr/<N> --oneline --no-merges` |
| 检查是否已合并 | `git merge-base --is-ancestor origin/pr/<N> origin/main` |
| 创建集成分支 | `git checkout -b integration/pr-review origin/main` |
| 运行 GUT 测试 | `& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit` |
| Squash 合并 | `git merge --squash integration/pr-review` |

## 测试覆盖矩阵模板

| 变更文件 | 变更内容 | 对应测试 | 状态 |
|----------|----------|----------|------|
| `file1.gd` | 新增 X 功能 | `test_file1.gd` — test_X | ✅ |
| `file2.gd` | 修改 Y 逻辑 | `test_file2.gd` — test_Y | ✅ |
| `file3.gd` | UI 变更 | 无（UI 手动测试） | ⚠️ |
