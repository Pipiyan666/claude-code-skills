---
name: 执行任务时主动查看 Skills 库
description: 当用户给任务时，我应该主动查看 Everything Claude Code 的 skills 文档，应用最佳实践
type: feedback
originSessionId: d7987402-dd4f-4847-9b35-0b80a4436c07
---
## 规则

当用户给我任何编码、设计、测试、架构等任务时，我应该：

1. **识别任务类型** - 是 Python？测试？架构设计？还是什么？
2. **查看相关 skills** - 主动打开 `/Users/pipipiyan/everything-claude-code/skills/` 中的相关文档
3. **应用最佳实践** - 参考 skill 文档中的模式、例子和流程
4. **融入到工作** - 把 skill 中的最佳实践应用到任务执行中
5. **不让用户手动查** - 我主动查，用户不用管

## Why

Everything Claude Code 中的 95 个 skills 都是专业级、生产级的最佳实践。当我忽视这些就是在没有参考的情况下做事，容易造成：
- 重新发明轮子
- 错过已验证的最佳实践
- 代码质量下降

## How to Apply

**例子 1**: 用户说 "帮我写 Python 代码处理数据"
```
1. 我识别：Python 任务
2. 查看: /Users/pipipiyan/everything-claude-code/skills/python-patterns/SKILL.md
3. 查看: /Users/pipipiyan/everything-claude-code/skills/python-testing/SKILL.md
4. 应用这些 patterns 到代码
5. 执行任务
```

**例子 2**: 用户说 "帮我写端到端测试"
```
1. 我识别：测试任务
2. 查看: /Users/pipipiyan/everything-claude-code/skills/e2e-testing/SKILL.md
3. 查看: /Users/pipipiyan/everything-claude-code/skills/verification-loop/SKILL.md
4. 应用这些测试模式
5. 执行任务
```

## 前提条件

- Skills 库位置: `/Users/pipipiyan/everything-claude-code/skills/`
- 每个 skill 都有 `SKILL.md` 文件
- 我可以随时用 Read 工具查看这些文件

## 不要

❌ 问用户 "你想用哪个 skill?"
❌ 让用户去查 skills 文档
❌ 忽视相关的 skills 就开始做任务
❌ 假装没有 skills 库存在

## 要

✅ 主动查看相关 skills
✅ 在任务开始前应用最佳实践
✅ 在执行过程中参考 skill 指导
✅ 把 skill 中的模式融入工作
