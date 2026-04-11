"""
CLI 入口 — `python -m capsule.cli <command>`

支持的命令：
  add <text>           - 添加一条文字灵感
  add-image <path>     - 添加一张截图灵感
  list [N]             - 列出最近 N 条灵感（默认 10）
  search <keyword>     - 搜索灵感
  show <id>            - 查看一条灵感的完整内容
  stats                - 知识库统计
  path                 - 显示知识库根路径

例子：
  python -m capsule.cli add "深度工作的核心是仪式感而不是意志力"
  python -m capsule.cli add-image ~/Desktop/note.png
  python -m capsule.cli list 5
  python -m capsule.cli search 穿搭
"""

import argparse
import sys

from . import agent, config, storage


def cmd_add(args):
    """添加文字灵感"""
    print(f"📝 正在分析（{config.ZHIPU_MODEL}）...")
    ins = agent.analyze_text(args.text)
    path = storage.save_insight(ins)

    print(f"\n✅ 已保存到 {path.relative_to(config.KB_ROOT)}")
    print(f"\n📋 摘要：{ins.summary}")
    print(f"📂 分类：{ins.category}")
    print(f"🏷️  标签：{', '.join(ins.tags)}")
    print(f"🔑 关键词：{', '.join(ins.keywords)}")
    print(f"💡 洞察：{ins.insight}")


def cmd_add_image(args):
    """添加截图灵感（OCR + 分析）"""
    print(f"📸 正在视觉分析（{config.ZHIPU_VISION_MODEL}）...")
    ins = agent.analyze_image(args.path)
    path = storage.save_insight(ins)

    print(f"\n✅ 已保存到 {path.relative_to(config.KB_ROOT)}")
    print(f"\n📄 OCR 原文：\n  {ins.raw_text[:200]}...")
    print(f"\n📋 摘要：{ins.summary}")
    print(f"📂 分类：{ins.category}")
    print(f"🏷️  标签：{', '.join(ins.tags)}")
    print(f"🔑 关键词：{', '.join(ins.keywords)}")
    print(f"💡 洞察：{ins.insight}")


def cmd_list(args):
    """列出最近 N 条灵感"""
    items = storage.list_insights(limit=args.n)
    if not items:
        print("（知识库还是空的，用 `add` 添加第一条吧）")
        return

    print(f"📚 最近 {len(items)} 条灵感：\n")
    for path, ins in items:
        print(f"  💡 [{ins.category}] {ins.summary}")
        print(f"     📅 {ins.timestamp[:16]}  📂 {path.relative_to(config.KB_ROOT)}")
        print(f"     🏷️  {', '.join(ins.tags)}")
        print()


def cmd_search(args):
    """搜索灵感"""
    items = storage.search_insights(args.keyword)
    if not items:
        print(f"（没有找到包含『{args.keyword}』的灵感）")
        return

    print(f"🔍 找到 {len(items)} 条相关灵感：\n")
    for path, ins in items:
        print(f"  💡 [{ins.category}] {ins.summary}")
        print(f"     📂 {path.relative_to(config.KB_ROOT)}")
        print(f"     🏷️  {', '.join(ins.tags)}")
        print()


def cmd_show(args):
    """查看一条灵感的完整内容"""
    items = storage.list_insights()
    for path, ins in items:
        if ins.id == args.id or args.id in str(path):
            print(path.read_text(encoding="utf-8"))
            return
    print(f"❌ 没找到 id 包含『{args.id}』的灵感")


def cmd_stats(args):
    """知识库统计"""
    s = storage.get_stats()
    print(f"📚 知识库统计")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"📂 路径：{s['kb_path']}")
    print(f"📊 总灵感数：{s['total']}")
    print()
    print(f"📋 分类分布：")
    for cat, cnt in sorted(s["by_category"].items(), key=lambda x: -x[1]):
        print(f"  {cat}: {cnt}")
    print()
    print(f"🏷️  Top 10 标签：")
    for tag, cnt in list(s["by_tag"].items())[:10]:
        print(f"  {tag}: {cnt}")


def cmd_path(args):
    """显示知识库根路径"""
    print(config.KB_ROOT)


def main():
    parser = argparse.ArgumentParser(
        prog="capsule",
        description="灵感胶囊 CLI — Markdown 知识库 + 智谱 GLM-4 分析",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_add = sub.add_parser("add", help="添加一条文字灵感")
    p_add.add_argument("text", help="灵感内容")
    p_add.set_defaults(func=cmd_add)

    p_addimg = sub.add_parser("add-image", help="添加一张截图灵感")
    p_addimg.add_argument("path", help="截图文件路径")
    p_addimg.set_defaults(func=cmd_add_image)

    p_list = sub.add_parser("list", help="列出最近灵感")
    p_list.add_argument("n", nargs="?", type=int, default=10, help="数量（默认 10）")
    p_list.set_defaults(func=cmd_list)

    p_search = sub.add_parser("search", help="搜索灵感")
    p_search.add_argument("keyword", help="搜索关键词")
    p_search.set_defaults(func=cmd_search)

    p_show = sub.add_parser("show", help="查看一条灵感的完整内容")
    p_show.add_argument("id", help="灵感 id 或文件名片段")
    p_show.set_defaults(func=cmd_show)

    p_stats = sub.add_parser("stats", help="知识库统计")
    p_stats.set_defaults(func=cmd_stats)

    p_path = sub.add_parser("path", help="显示知识库根路径")
    p_path.set_defaults(func=cmd_path)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
