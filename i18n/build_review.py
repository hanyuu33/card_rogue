# -*- coding: utf-8 -*-
"""R653：由 i18n/glossary.json 生成可搜索的中英日对照页。

用法：python i18n/build_review.py
输出：i18n/glossary_review.html
只读术语表，不改任何游戏数据。
"""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "i18n/glossary.json"
OUT = ROOT / "i18n/glossary_review.html"
TITLE = "R653 术语中英日对照"

LABELS = {
    "brand": "品牌",
    "mechanics": "机制与通用词",
    "kinds": "卡牌种类",
    "classes": "角色与阵营",
    "colors": "颜色",
    "traits": "特性",
    "names": "专名",
    "rarities": "卡牌稀有度",
    "relic_kinds": "道具类型",
    "relic_sources": "道具来源",
    "relic_tiers": "道具品级",
    "key_relics": "信物",
    "difficulties": "难度档位",
    "difficulty_notes": "难度新增效果",
    "rooms": "地图与房间",
    "statuses": "战斗状态",
    "enchantments": "商店附魔",
    "zones": "卡牌区域",
    "rewards": "奖励界面",
    "ui": "通用界面",
    "relics": "道具名",
    "levels": "关卡名",
    "events": "事件名",
    "stories": "剧情名",
    "achievements": "成就名",
}

ORDER = [
    "brand", "mechanics", "kinds", "classes", "colors", "traits", "names",
    "rarities", "relic_kinds", "relic_sources", "relic_tiers", "key_relics",
    "difficulties", "difficulty_notes", "rooms", "statuses", "enchantments",
    "zones", "rewards", "ui", "relics", "levels", "events", "stories",
    "achievements",
]

CSS = """
:root{--bg:#f4f1ea;--paper:#fffdf8;--ink:#292b32;--muted:#6b6c73;--line:#ded8ca;--accent:#67508d;--soft:#eee8f4}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Segoe UI","Microsoft YaHei",sans-serif;line-height:1.55}
header{padding:32px max(24px,calc((100vw - 1280px)/2));background:#302a3c;color:#fff}
header h1{margin:0 0 8px;font-size:28px}
header p{margin:4px 0;color:#ddd5e7}
.toolbar{position:sticky;top:0;z-index:2;padding:12px max(18px,calc((100vw - 1280px)/2));background:rgba(244,241,234,.97);border-bottom:1px solid var(--line)}
input{width:min(520px,100%);padding:10px 14px;border:1px solid #bdb4c7;border-radius:8px;background:white;font-size:15px}
nav{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}
nav a{color:var(--accent);text-decoration:none;font-size:12px;background:var(--soft);padding:3px 8px;border-radius:5px}
nav span{color:var(--muted)}
main{max-width:1280px;margin:auto;padding:12px 20px 48px}
section{margin:22px 0;background:var(--paper);border:1px solid var(--line);border-radius:10px;overflow:hidden}
h2{font-size:19px;margin:0;padding:14px 18px;background:#ece6da}
h2 small{font-size:12px;color:var(--muted);font-weight:400;margin-left:8px}
table{width:100%;border-collapse:collapse;table-layout:fixed}
th,td{text-align:left;vertical-align:top;padding:8px 14px;border-top:1px solid #eee9df;overflow-wrap:anywhere}
th{font-size:12px;color:var(--muted);background:#faf7f0}
th:nth-child(1){width:20%}th:nth-child(2){width:27%}th:nth-child(3){width:25%}th:nth-child(4){width:28%}
.zh{font-weight:600}
.note{color:var(--muted);font-size:12px}
tr.hidden{display:none}
section.all-hidden{display:none}
footer{color:var(--muted);font-size:12px;padding:10px 4px}
@media(max-width:760px){
  th:nth-child(4),td:nth-child(4){display:none}
  th:nth-child(1){width:30%}th:nth-child(2){width:36%}th:nth-child(3){width:34%}
  th,td{padding:7px 8px;font-size:13px}
}
"""


def main() -> None:
    g = json.loads(SRC.read_text(encoding="utf-8"))
    sections = [k for k in ORDER if isinstance(g.get(k), dict)]
    for key, val in g.items():
        if isinstance(val, dict) and key not in sections:
            sections.append(key)

    nav = []
    body = []
    total = 0
    for sec in sections:
        data = g[sec]
        if sec == "brand":
            data = {"嘎嘎乱杀": data}
        label = LABELS.get(sec, sec)
        nav.append(
            '<a href="#%s">%s <span>%d</span></a>'
            % (sec, html.escape(label), len(data))
        )
        rows = []
        for zh, v in data.items():
            ident = v.get("id", v.get("key", ""))
            note = v.get("note", "")
            meta = " / ".join(str(x) for x in (ident, note) if x)
            rows.append(
                '<tr><td class="zh">%s</td><td>%s</td><td>%s</td><td class="note">%s</td></tr>'
                % (
                    html.escape(zh),
                    html.escape(v["en"]),
                    html.escape(v["ja"]),
                    html.escape(str(meta)),
                )
            )
            total += 1
        body.append(
            '<section id="%s"><h2>%s <small>%d 项</small></h2>'
            "<table><thead><tr><th>中文</th><th>English</th><th>日本語</th>"
            "<th>ID / 备注</th></tr></thead><tbody>%s</tbody></table></section>"
            % (sec, html.escape(label), len(data), "".join(rows))
        )

    doc = (
        '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        "<title>%s</title><style>%s</style></head><body>"
        "<header><h1>%s</h1>"
        "<p>真源：cards.json / relics.json / stories.json / GDScript 常量。"
        "卡牌权威中文原文未改动。</p>"
        "<p>道具 = Relic／レリック；信物 = Key Relic／キーレリック；"
        "组合 = Assemble／組み立てる；合体 = Merge／合体；"
        "「升级」8027 = Refit／改修。生成日期：2026-11-13。</p></header>"
        '<div class="toolbar"><input id="q" type="search" '
        'placeholder="搜索中文、英文、日文或备注…"><nav>%s</nav></div>'
        "<main>%s<footer>共 %d 条显示词条；覆盖校验由 "
        "i18n/validate_glossary.py 执行。</footer></main>"
        "<script>document.getElementById('q').addEventListener('input',function(){"
        "const q=this.value.trim().toLowerCase();"
        "document.querySelectorAll('section').forEach(s=>{let visible=0;"
        "s.querySelectorAll('tbody tr').forEach(r=>{"
        "const show=!q||r.textContent.toLowerCase().includes(q);"
        "r.classList.toggle('hidden',!show);if(show)visible++});"
        "s.classList.toggle('all-hidden',visible===0)})});</script>"
        "</body></html>"
        % (TITLE, CSS, TITLE, "".join(nav), "".join(body), total)
    )

    OUT.write_text(doc, encoding="utf-8", newline="\n")
    print("wrote %s | sections %d | entries %d | bytes %d"
          % (OUT.name, len(sections), total, OUT.stat().st_size))


if __name__ == "__main__":
    main()
