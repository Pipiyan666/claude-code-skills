---
name: Skills 工作流指南
description: 如何在项目工作中有效地查找和使用 Claude Code skills
type: feedback
originSessionId: d7987402-dd4f-4847-9b35-0b80a4436c07
---
## 两个库的用途分工

**本地 Claude 环境 (~/.claude/plugins/):**
- 系统基础设施，不需要关注

**Everything Claude Code 库 (/Users/pipipiyan/everything-claude-code/):**
- 你的参考库，包含 95 个专业级 skills
- 可随时查询，不需要导入或集成到 Claude 环境

## 推荐工作流

1. **不需要导入整个库** - 保持现状即可
2. **使用 SKILLS_INDEX.md** - 快速按领域查找需要的 skill
3. **按需参考** - 当项目需要某个工作流时，打开对应 skill 的 SKILL.md
4. **复制适配** - 把 skill 中的示例和流程复制到你的项目

## 快速查询方式

### 打开索引文档
```bash
open ~/SKILLS_INDEX.md
```

### 直接打开某个 skill
```bash
open /Users/pipipiyan/everything-claude-code/skills/{skill-name}/SKILL.md
```

### 示例
需要 Python 最佳实践？→ 打开 `python-patterns` 的 SKILL.md
需要测试框架？→ 打开 `python-testing` 或 `e2e-testing`

## 为什么不需要导入？

- 95 个 skills 足够全面覆盖各种场景
- 你本地有完整的 git 仓库副本，随时可访问
- 复制粘贴具体内容 > 盲目导入整个系统
- 保持 Claude 环境轻量和专注

## 关键认识

**核心原则**: 把 everything-claude-code 当作**查询工具**，而不是**系统集成**。
你需要的是快速访问和参考能力，而不是环境集成复杂度。
