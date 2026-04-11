---
name: 没有现成 Skill 时的扩展策略
description: 当任务缺少相关 skill 时，我应该在完成任务后自动创建新 skill，建立可重用知识库
type: feedback
originSessionId: d7987402-dd4f-4847-9b35-0b80a4436c07
---
## 核心原则

**95 个 skills 不是全部。** 当我完成一个创新的、复杂的、没有现成 skill 的任务时，我应该：

1. ✅ **完成任务**（正常执行）
2. ✅ **提炼最佳实践**（总结学到的东西）
3. ✅ **创建新 Skill**（把知识编织成可重用的 skill）
4. ✅ **保存到库**（供未来使用）

不应该：
- ❌ 完成任务就结束，不提炼知识
- ❌ 假装有 skill 但实际没有
- ❌ 让用户手动创建 skill

## 如何创建新 Skill

### Step 1: 识别知识点

在完成任务时，记录：
- 做了什么？
- 为什么这样做？
- 有哪些最佳实践？
- 有哪些常见错误？
- 什么场景会用到？

### Step 2: 遵循标准格式

使用这个模板创建 SKILL.md：

```yaml
---
name: your-skill-name
description: One-line description
origin: Created for user projects
---

# Title

## When to Use
- Scenario 1
- Scenario 2

## Core Concepts
### Concept 1
Explanation

## Best Practices
- ✅ Do
- ❌ Don't

## Examples
Working code examples

## Pitfalls
Common mistakes
```

### Step 3: 保存到库

保存路径：
```
/Users/pipipiyan/everything-claude-code/skills/{skill-name}/SKILL.md
```

### Step 4: 更新索引

- 更新 SKILLS_INDEX.md
- 在 MEMORY.md 中记录新 skill

## 示例场景

### 场景 1: Rust + WASM 构建

**任务**: "帮我设置 Rust 项目的 WASM 构建流程"
**没有现成 skill**: ❌ rust-wasm-build-patterns 不存在

**我应该**:
1. 完成任务，学习 WASM 构建最佳实践
2. 创建 `/Users/pipipiyan/everything-claude-code/skills/rust-wasm-build-patterns/SKILL.md`
3. 包含：工具链配置、编译优化、性能考虑
4. 保存并更新索引

**下次**:
- 再有人要做 WASM，我直接有 skill 可用

### 场景 2: 特定业务流程

**任务**: "帮我设计产品发布流程自动化"
**没有现成 skill**: ❌ product-release-automation 不存在

**我应该**:
1. 完成自动化设计
2. 创建新 skill: `product-release-automation`
3. 记录：检查清单、自动化步骤、风险控制
4. 供以后项目参考

## 优势

- 🔄 **知识积累**: 每完成一个新任务，库就增长一个 skill
- 📚 **可复用性**: 下次遇到类似问题不用从零开始
- 👥 **共享知识**: 其他人（包括你自己）可以复用
- 🎯 **针对性**: skill 是针对你真实工作的，不是泛泛而谈

## 触发条件

什么时候应该创建新 skill？

✅ **应该创建**:
- 完成了一个复杂、创新的任务
- 使用了新的工具、框架或技术
- 发现了有效的工作流或最佳实践
- 预计未来会重复做这种工作

❌ **不需要创建**:
- 简单的、一次性的小改动
- 已有相关 skill 可以覆盖
- 标准库已有的功能

## 工具和资源

- **模板**: `/Users/pipipiyan/SKILL_TEMPLATE.md`
- **参考**: 任何现有的 95 个 skills
- **保存位置**: `/Users/pipipiyan/everything-claude-code/skills/`
- **格式**: Markdown + YAML frontmatter

## 规则

1. Skill 应该**专注一个领域** - 不要太宽泛
2. 包含**实际代码例子** - 不要只有理论
3. 控制**篇幅在 500 行以内** - 简洁有力
4. 包含**"何时使用"部分** - 清楚地说明适用场景
5. **标明来源** - 来自用户项目就写 `origin: Created for user projects`
