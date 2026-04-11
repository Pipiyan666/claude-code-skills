# capsule — V1-V4 Python 实现

> 灵感胶囊的 V1-V4 完整 Python 实现。
> V0+ Web Demo 在 `../hackathon_demo/`。
> 完整的设计理念见 `../TECH_ARCHITECTURE.md`。

## 快速上手

```bash
# 在项目根目录
cd ~/Projects/hellocase

# 用 hackathon_demo 的 venv（已经装好所有依赖）
PYTHON=hackathon_demo/.venv/bin/python

# V1: CLI
$PYTHON -m capsule.cli stats
$PYTHON -m capsule.cli list 5
$PYTHON -m capsule.cli add "深度工作的核心是仪式感"
$PYTHON -m capsule.cli add-image ~/Desktop/note.png
$PYTHON -m capsule.cli search 留存
```

## 模块结构

```
capsule/
├── __init__.py
├── config.py              # 全局配置（路径 + 智谱 API）
├── storage.py             # V1: Markdown 文件读写
├── agent.py               # V1: 单 LLM 调用（被 V2-V4 复用）
├── cli.py                 # V1: CLI 入口
│
├── agents/                # V2: 多 Agent 模块
│   ├── __init__.py
│   ├── base.py            # Agent 基类（统一计时 + 日志 + 异常处理）
│   ├── ocr.py             # ScreenshotAgent（GLM-4V）
│   ├── classify.py        # ClassifyAgent
│   ├── tag.py             # TagAgent
│   ├── summary.py         # SummaryAgent
│   ├── insight.py         # InsightAgent
│   └── cluster.py         # ClusterAgent（定时任务）
├── workflow.py            # V2: CaptureWorkflow 编排器
│
├── tools/                 # V3: Agent 工具集
│   ├── __init__.py
│   ├── kb_tools.py        # read_kb / write_kb_report
│   ├── web_tools.py       # web_search / fetch_url
│   └── schemas.py         # OpenAI function calling schema
├── research_agent.py      # V3: ResearchAgent + ReAct 循环
│
├── events.py              # V4: 极简事件总线
├── librarian.py           # V4: LibrarianAgent（核心 Agent，模拟 claude_code preset）
└── harness.py             # V4: CapsuleHarness 主调度器
```

## V1-V4 编程接口

### V1 — 直接调用
```python
from capsule.agent import analyze_text
from capsule.storage import save_insight

ins = analyze_text("你的灵感内容")
path = save_insight(ins)
print(f"已保存到 {path}")
```

### V2 — Workflow 编排
```python
from capsule.workflow import CaptureWorkflow

workflow = CaptureWorkflow()
ins, results = workflow.run_text("你的灵感")
# results 是每个 Agent 的执行结果（含耗时、成功/失败、输出）
for r in results:
    print(f"{r.agent}: {r.duration_ms}ms → {list(r.output.keys())}")
```

### V3 — Tool Use Agent
```python
from capsule.research_agent import ResearchAgent

agent = ResearchAgent(max_iterations=8)
result = agent.run("调研一下深度工作这个主题")
print(result["final_response"])
print(f"用了 {result['iterations']} 次工具调用")
for step in result["trace"]:
    print(step)
```

### V4 — Multi-Agent Harness
```python
from capsule.harness import CapsuleHarness

h = CapsuleHarness()

# 捕获灵感（自动走 V2 workflow）
h.capture("灵感1")
h.capture("灵感2")
h.capture("灵感3")  # 第3条触发 LibrarianAgent 自主整理

# 强制运行 librarian
result = h.force_librarian("分析最近一周的灵感主题")

# 查看完整事件流
for event in h.get_event_log():
    print(event)
```

## 数据目录

```
~/Library/IdeaCapsule/
├── inbox/                 # Hot: 7 天内
│   └── 2026-04-12/
│       └── 030122-{slug}.md
├── processed/             # Warm: 30 天内（V2 用）
├── wiki/                  # Cold: 主题文章
│   └── topics/
│       └── 20260412-030144-{title}.md
├── index.md               # 全局索引（V4 重建）
└── .session_state.json    # V4 Harness 状态
```

## 设计原则（一句话回顾）

1. **Markdown-as-DB** — 用户能用任何编辑器打开自己的数据
2. **Agent 单一职责** — 每个 Agent 只关心一件事
3. **Tool Use** — LLM 自主决策，不是我们写编排代码
4. **Local-First** — 所有数据默认在本地
5. **事件松耦合** — Agent 之间通过事件通信，不直接调用

完整设计文档：`../TECH_ARCHITECTURE.md`
完整实现细节：`../DEMO_SHOWCASE.md`
