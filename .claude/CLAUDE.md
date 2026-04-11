# 全局 Claude Code 工作规范

> 此文件在所有会话中自动加载，规定了 Skills 查找、应用和创建的工作流。

**系统版本**: v1.0.0 (2026-04-12)
**最后更新**: Git commit 5e54b32
**状态**: ✅ 生产就绪

## 🎯 执行任务前：Skills 三步查找法

每次执行任务，我都会按这个顺序查找相关 skills：

### Step 1️⃣ 识别任务类型
在开始前，我会问自己：
- **语言**: Python / Go / Swift / Rust / TypeScript / 等？
- **领域**: 测试 / 部署 / 安全 / 设计 / 架构 / 等？
- **框架**: React / Django / Spring / 等？
- **工作流**: TDD / CI/CD / 性能优化 / 等？

### Step 2️⃣ 查本地 ECC Skills 库（优先）
```
路径: /Users/pipipiyan/everything-claude-code/skills/
```
- 列出库中所有 skills
- 找到相关的 skill
- 用 Read 工具打开 SKILL.md
- 应用其中的最佳实践、代码模式、常见陷阱

**本地 Skills 检查表**：
- Python 代码？→ `python-patterns` + `python-testing`
- TypeScript？→ `frontend-patterns` + `typescript-lsp` 风格
- 测试？→ `tdd-workflow` + `e2e-testing`
- API 设计？→ `api-design`
- 部署？→ `deployment-patterns` + `docker-patterns`
- 安全？→ `security-review` + `security-scan`
- 架构？→ `backend-patterns` + `frontend-patterns`
- 数据库？→ `postgres-patterns` + `database-migrations`
- 其他语言？→ 查找对应语言的 skill（golang-patterns, kotlin-patterns 等）

### Step 3️⃣ 若本地无匹配，查在线 skills.sh
```
URL: https://skills.sh/
规模: 91,666+ skills
```
- 用 WebFetch 访问 skills.sh
- 搜索相关的 skill 名称或关键词
- 若找到有价值的 skill，应用其指导原则

---

## 📝 完成任务后：Skills 创建规则

当我完成一个**新的、复杂的、无现成 skill**的任务时：

### 何时创建新 Skill？
✅ **应该创建**：
- 学到了新的最佳实践
- 完成了创新或复杂的任务
- 预计将来会重复做这种工作
- 有明确的流程或模式可以提炼

❌ **不需要创建**：
- 简单的、一次性的修改
- 已有相关 skill 能覆盖
- 标准库或文档已有的功能

### 如何创建新 Skill？

1. **总结学到的东西**：
   - 做了什么？
   - 为什么这样做？
   - 最佳实践是什么？
   - 常见错误有哪些？

2. **按标准格式创建 SKILL.md**：
```markdown
---
name: your-skill-name
description: Brief one-line description
origin: Created for user projects
---

# Skill Title

## When to Use
- Scenario 1
- Scenario 2

## Core Concepts
### Concept 1
Explanation

## Best Practices
- ✅ Do this
- ❌ Avoid that

## Code Example
\`\`\`python
# Working example
\`\`\`

## Common Pitfalls
1. Pitfall and how to avoid
```

3. **保存到本地库**：
```
/Users/pipipiyan/everything-claude-code/skills/{skill-name}/SKILL.md
```

4. **更新索引**：
   - 更新 `/Users/pipipiyan/SKILLS_INDEX.md`
   - 在 memory 中记录新 skill

---

## 🔄 工作流概览

```
用户 cd 到某个项目
      ↓
用户给任务
      ↓
我识别任务类型
      ↓
查本地 ECC Skills
      ↓
   有相关 skill？
   /            \
 是              否
 ↓              ↓
应用 skill      查 skills.sh
 ↓              ↓
执行任务←────────┘
 ↓
完成
 ↓
有新知识要提炼吗？
   /            \
 是              否
 ↓              ↓
创建新 skill    结束
 ↓
保存到库
```

---

## 📋 记忆补充信息

更多背景和详细规则见：
- `/Users/pipipiyan/.claude/projects/-Users-pipipiyan/memory/MEMORY.md`
- 内含：Skills 库位置、创建规范、工作流指南

---

## ✨ 核心原则

1. **Skills 我查，你不查** - 你只管给任务，我负责找最佳实践
2. **先本地后在线** - 优先用经验丰富的本地库
3. **持续积累** - 每个新任务都是积累知识的机会
4. **标准化** - 所有 skill 都遵循一致的格式和质量标准
5. **透明化** - 执行任务时，我会告诉你用了哪个 skill

---

## 📚 系统演进历史

### v1.0.0 (2026-04-12) - 初始版本
- ✅ 建立全局 CLAUDE.md 规范
- ✅ 完成五层递进策略设计
- ✅ 建立 Memory 持久化系统
- ✅ 创建参考文档和模板
- ✅ 对标市场主流解决方案
- ✅ Git commit: 5e54b32

**能力**: 自动查找本地/在线 skills，组合应用，深度研究，自动创建新 skills

**覆盖范围**: 
- 本地库: 95 个 skills
- 在线库: 91,666+ skills
- 自创库: 动态增长

---

## 🔗 相关文档

- **Memory 文件**: `~/.claude/projects/-Users-pipipiyan/memory/MEMORY.md`
- **快速参考**: `~/SKILLS_QUICK_REFERENCE.md`
- **Skills 索引**: `~/SKILLS_INDEX.md`
- **创建模板**: `~/SKILL_TEMPLATE.md`

---

## 💬 反馈和改进

遇到问题或有改进建议？
- 在 memory 中记录
- 创建新的 skill
- 更新 CLAUDE.md
- 执行 git commit

系统会持续演进！
