# PR 审查与 Squash 合并规范

**文档版本：** v1.0
**更新日期：** 2026-05-12
**关联 Skill：** `.cursor/skills/pr-review-merge/SKILL.md`

---

## 1. 概述

本文档定义从 GitHub PR 获取代码、审查、测试、修复到 squash 合并到 `main` 的标准流程。适用于从其他分支或 fork 提交的 PR。

---

## 2. 流程总览

```
GitHub PR ──→ 获取 PR refs ──→ 创建集成分支 ──→ 合并 PR
                              │
                              ├──→ 审查代码 & 测试覆盖
                              ├──→ 运行 GUT 测试
                              ├──→ 修复问题
                              ├──→ 记录审查文档
                              │
               main ←── Squash 合并 ←── 验证通过
```

---

## 3. 详细步骤

### 3.1 获取 PR

```bash
git fetch origin 'refs/pull/*/head:refs/remotes/origin/pr/*'
```

查看未合并的 PR：
```bash
git for-each-ref refs/remotes/origin/pr --format='%(refname:short)'
```

### 3.2 创建集成分支

以 `main` 为基线创建分支，避免直接修改 main：

```bash
git checkout -b integration/pr-review origin/main
```

### 3.3 审查清单

#### A. 变更分析
- 使用 `git diff --stat origin/main...origin/pr/<N>` 了解影响范围
- 使用 `git log origin/main..origin/pr/<N> --oneline --no-merges` 获取 PR 独有 commits
- 逐个文件审查 diff

#### B. 测试覆盖
每个变更点必须满足以下之一：
- 有对应的 GUT 测试用例（优先）
- 有独立的 SceneTree 运行器（`quiet_mode_runner.gd` 模式）
- 有静态检查脚本（Python 模式）

#### C. 代码规范
必须检查：
- `_debounce_save()` 是否在 UI toggle handler 中调用
- `notify_property_list_changed()` 是否在 `@export` setter 中调用
- 错误信息是否包含具体参数名
- 是否有跨文件重复代码

#### D. 多语言适配（UI 变更必检）
涉及 UI 新增/修改文本时，必须检查：
- UI 控件的 `.text` 是否通过 `_tr(key)` 赋值，而非硬编码字符串
- 翻译文件 `addons/godot_mcp/translations/mcp_panel.csv` 是否新增了对应的 key 行
- `_refresh_translations()` 方法是否对新增控件做了翻译刷新
- 英文（en）和中文（zh）两列是否均有翻译内容
- 若仅面向 MCP 协议层（工具描述、schema）无 UI 面板文本，则无需此检查

### 3.4 GUT 测试验收

运行全量测试：
```bash
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

硬性要求：
- **0 failures**
- **0 errors**
- 新增测试必须通过

### 3.5 问题处理

| 严重级 | 定义 | 处理方式 |
|--------|------|----------|
| 🔴 阻断 | 功能错误、测试失败、持久化缺失 | 必须在集成分支修复，重新验证 |
| 🟡 优化 | 代码重复、缺少边界测试 | 建议修复；或记录到审查文档 |
| 📝 记录 | CI 缺失、测试工具未集成 | 记录到文档，后续迭代 |

### 3.6 审查文档

文档存放路径：`docs/debugging/pr<number>-<feature>-review-<date>.md`

必须包含：
1. GUT 测试结果表
2. 已修复的问题（含文件路径和行号）
3. 已记录的问题（待后续优化）
4. 测试覆盖率矩阵
5. 审查结论（分维度评分）

### 3.7 Squash 合并

```bash
# 准备 main
git checkout main
git pull origin main

# Squash 集成分支的所有 commits 为一个
git merge --squash integration/pr-review
git commit
```

#### 提交信息格式

```
<type>: <中文标题>

<详细变更说明，每项一行>

配套修改：
- <文档更新>
- <测试新增/修改>
- <问题修复>
```

| type | 含义 |
|------|------|
| feat | 新功能 |
| fix | 错误修复 |
| refactor | 重构 |
| docs | 文档 |
| test | 测试 |
| chore | 杂项 |

---

## 4. 测试覆盖验收标准

| 覆盖类型 | 最低要求 |
|----------|----------|
| 新增函数 | 正常路径 + 边界条件 |
| 原有函数修改 | 新增行为有对应断言 |
| 导出变量 | get_script_property_list() 断言 |
| Schema 新增参数 | input_schema.properties 包含该参数 |
| UI 变更 | 信号连接 + handler 存在 + 多语言适配（_tr 赋值 + CSV key + _refresh_translations 刷新） |
| 错误处理 | 缺参、空值、无效值每种至少一个 |

---

## 5. 快速命令参考

### Git 操作
```bash
# 查看 PR 独有 commits
git log origin/main..origin/pr/<N> --oneline --no-merges

# 查看 PR 完整 diff stat
git diff --stat origin/main...origin/pr/<N>

# 查看单个文件 diff
git diff origin/main...origin/pr/<N> -- <path>

# 检查是否已合并
git merge-base --is-ancestor origin/pr/<N> origin/main && echo merged || echo not merged

# 创建/重置集成分支
git checkout -b integration/pr-review origin/main
git branch -D integration/pr-review  # 删除

# Squash 合并
git merge --squash integration/pr-review

# 清理
git branch -D integration/pr-review
```

### 测试
```bash
# 全量 GUT 测试
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

---

## 6. 文档模板

审查文档模板见配套 Skill 文件 `.cursor/skills/pr-review-merge/SKILL.md`。
