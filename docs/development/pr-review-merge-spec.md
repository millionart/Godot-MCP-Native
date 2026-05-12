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
GitHub PR ──→ 获取 PR refs ──→ 创建集成分支 ──→ 合并 PR 代码
                              │
                              ├──→ 审查代码 & 测试覆盖
                              ├──→ 运行 GUT 测试
                              │
                   ┌── 阻断问题 ──→ Request Changes 退回 PR 作者
                   │
              问题处理 ── 小修复 ──→ 直接推送到 PR head 分支
                   │
                   └── 无问题/已修复 ──→ GitHub Squash Merge（PR 自动关闭）
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

将 PR 代码合并到集成分支进行审查：

```bash
git merge origin/pr/<N>
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
| 🔴 阻断 | 功能错误、架构问题、测试失败 | 在 GitHub PR 上 Request Changes，附审查意见，退回 PR 作者自行修复 |
| 🟡 小修复 | 缺 `_debounce_save()`、硬编码字符串、缺少翻译 key 等 | 审查者直接推送到 PR head 分支修复，再重新验证 |
| 📝 记录 | CI 缺失、代码重复、测试工具未集成 | 记录到审查文档，后续迭代 |

#### 小修复推送流程

当审查发现小问题需要直接修复时：

```bash
# 1. 切到 PR 的 head 分支
git checkout origin/pr/<N>

# 2. 基于该分支创建本地修复分支（或直接在该分支上修改）
git checkout -b fix/pr<N>-review-fixes

# 3. 修改代码、运行测试验证

# 4. 推送到 PR 的 head 分支（需 collaborator 权限或 PR 作者授权）
git push origin fix/pr<N>-review-fixes:<PR_head_branch>

# 5. 回到集成分支重新合并验证
git checkout integration/pr-review
git merge origin/pr/<N>
```

#### 阻断问题退回流程

```bash
# 通过 GitHub API 提交 Review（Request Changes）
# 需使用 gh CLI 或 GitHub 网页操作：
gh pr review <N> --request-changes --body "审查意见..."

# PR 作者修复并 push 后，重新从 3.2 开始
```

### 3.6 审查文档

文档存放路径：`docs/debugging/pr<number>-<feature>-review-<date>.md`

必须包含：
1. GUT 测试结果表
2. 已修复的问题（含文件路径和行号）
3. 已记录的问题（待后续优化）
4. 测试覆盖率矩阵
5. 审查结论（分维度评分）

### 3.7 合并

**通过 GitHub PR 页面合并**，确保 PR 自动关闭并有合并记录。

#### 方式一：GitHub Squash Merge（推荐）

在 GitHub PR 页面点击 **Squash and merge**，或在命令行：

```bash
gh pr merge <N> --squash --subject "<type>: <中文标题>"
```

优点：
- PR 自动关闭并关联到合并记录
- 修复代码有 commit 归属（来自 PR head 分支）
- GitHub 保留完整的审查和合并历史

#### 方式二：GitHub Merge Commit

```bash
gh pr merge <N> --merge
```

保留 PR 的所有 commit 历史，适用于需要逐 commit 追踪的场景。

#### 方式三：本地 Squash（仅限无 GitHub 权限时）

```bash
git checkout main
git pull origin main
git merge --squash integration/pr-review
git commit
git push origin main
```

**注意**：此方式不会关闭 GitHub PR，需手动 Close 并说明合并 commit SHA。

#### 合并后清理

```bash
# 删除本地集成分支
git branch -D integration/pr-review

# 删除修复分支（如有）
git branch -D fix/pr<N>-review-fixes
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

# 合并 PR 到集成分支审查
git merge origin/pr/<N>

# 合并后清理
git branch -D integration/pr-review
```

### GitHub PR 操作
```bash
# Squash 合并 PR（推荐）
gh pr merge <N> --squash --subject "<type>: <中文标题>"

# Merge Commit 合并 PR
gh pr merge <N> --merge

# 提交审查意见（Request Changes）
gh pr review <N> --request-changes --body "审查意见..."

# 提交审查通过
gh pr review <N> --approve --body "审查通过"

# 推送小修复到 PR head 分支
git push origin fix/pr<N>-review-fixes:<PR_head_branch>
```

### 测试
```bash
# 全量 GUT 测试
& "f:/Godot/Godot_v4.6.1-stable_win64.exe" --headless --path "F:/gitProjects/Godot-MCP-Native" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/ -ginclude_subdirs -gexit
```

---

## 6. 文档模板

审查文档模板见配套 Skill 文件 `.cursor/skills/pr-review-merge/SKILL.md`。
