"""
灵感胶囊 V1 — Markdown 知识库 + CLI

设计哲学（参考 Karpathy LLM Wiki）：
- Markdown-as-DB：所有数据落地为 .md 文件，用户能用任何编辑器打开
- Local-First：数据默认在 ~/Library/IdeaCapsule/，不上云
- AI as Librarian：智谱 GLM-4 自动分析、打标签、写 frontmatter
"""

__version__ = "1.0.0"
