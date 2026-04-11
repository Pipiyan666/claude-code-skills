# Skills 系统快速参考

> 你现在拥有一个全自动的 skills 系统。这个文件是快速查询指南。

## 📊 你的 Skills 库规模

| 库 | 数量 | 位置 | 说明 |
|----|------|------|------|
| 本地 ECC | 95 个 | `/Users/pipipiyan/everything-claude-code/skills/` | 专业级，本地可访问 |
| 在线 skills.sh | 91,666+ 个 | https://skills.sh/ | 海量库，按需查询 |
| 自创 skills | 动态 | `/Users/pipipiyan/everything-claude-code/skills/` | 每个新任务积累 |

---

## 🚀 使用方式（超简单）

### 你要做的：
```bash
cd /your/project
# 给我任务即可，我会自动查找 skills
```

### 我会自动做的：
1. ✅ 识别任务类型（Python？测试？设计？）
2. ✅ 查本地 95 个 skills
3. ✅ 若无，查在线 91,666+ skills
4. ✅ 应用最佳实践完成任务
5. ✅ 若有新知识，创建新 skill

---

## 🎯 常见任务 → 相关 Skills

| 任务 | 我会查看的 Skills |
|------|-----------------|
| 写 Python 代码 | `python-patterns` + `python-testing` |
| 前端开发（React） | `frontend-patterns` + `frontend-design` |
| API 设计 | `api-design` + `backend-patterns` |
| 端到端测试 | `e2e-testing` + `tdd-workflow` |
| 数据库工作 | `postgres-patterns` + `database-migrations` |
| 部署上线 | `deployment-patterns` + `docker-patterns` |
| 代码安全审查 | `security-review` + `security-scan` |
| 性能优化 | `cost-aware-llm-pipeline` + `optimization` |
| 架构设计 | `backend-patterns` + `frontend-patterns` |
| 其他语言 | `golang-patterns` / `kotlin-patterns` / `swift-concurrency` 等 |

---

## 📁 文件位置速查

| 文件 | 用途 | 路径 |
|------|------|------|
| 全局规范 | 所有会话都遵循 | `~/.claude/CLAUDE.md` |
| 本地库 | 95 个参考 skills | `~/everything-claude-code/skills/` |
| 自创库 | 你创建的 skills | `~/everything-claude-code/skills/` |
| 快速索引 | 所有 95 个 skills 列表 | `~/SKILLS_INDEX.md` |
| Skill 模板 | 创建新 skill 的模板 | `~/SKILL_TEMPLATE.md` |

---

## ⚙️ 系统工作流

```
任务到来
  ↓
我识别类型 (Python? 测试? 设计?)
  ↓
查本地库 (/Users/pipipiyan/everything-claude-code/skills/)
  ↓
有相关 skill?
  ├─ 是 → 读取 SKILL.md → 应用最佳实践
  └─ 否 → 查在线库 (skills.sh) → 应用 or 继续
  ↓
执行任务
  ↓
完成
  ↓
有新知识要提炼?
  ├─ 是 → 创建新 skill → 保存到库
  └─ 否 → 结束
```

---

## ✨ 三个核心原则

1. **你不管 skills，我管** 
   - 你只说需求，我找最佳实践
   - 不需要你手动查文档

2. **先本地后在线**
   - 本地 95 个是精选过的，质量高
   - 在线库是补充，数量大但质量参差

3. **持续积累**
   - 每个新任务都可能创建新 skill
   - Skills 库会越来越大、越来越好

---

## 🔧 配置状态

- ✅ 全局 CLAUDE.md 已创建
- ✅ Memory 系统已建立
- ✅ ECC 本地库可用
- ✅ skills.sh 在线库可查
- ✅ Skills 创建规范已定义

**状态：已就绪！** 现在可以正常使用了。

---

## 📞 需要帮助？

| 问题 | 答案 |
|------|------|
| 我 cd 到新项目，skills 还能用吗？ | ✅ 能，全局规范到处生效 |
| 是否需要安装什么？ | ❌ 不需要，已自动配置 |
| 能否看到 skills 列表？ | ✅ 能，`~/SKILLS_INDEX.md` |
| 如何创建新 skill？ | ✅ 我完成任务后自动创建 |
| 能否从 skills.sh 用 skills？ | ✅ 能，我会自动搜索 |

---

**现在你可以开始工作了！给我任何任务，我会自动查找和应用最佳实践。**
