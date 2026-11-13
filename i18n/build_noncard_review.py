# -*- coding: utf-8 -*-
"""R659：生成道具与角色长文的可搜索中英日对照页。"""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "noncard_zh_canonical.json").read_text(encoding="utf-8"))
EN = json.loads((I18N / "noncard_en.json").read_text(encoding="utf-8"))
JA = json.loads((I18N / "noncard_ja.json").read_text(encoding="utf-8"))
OUT = I18N / "noncard_review.html"

CSS = """
:root{--bg:#f4f1ea;--paper:#fffdf8;--ink:#292b32;--muted:#6b6c73;--line:#ded8ca;--accent:#67508d;--soft:#eee8f4}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:"Segoe UI","Microsoft YaHei",sans-serif;line-height:1.55}
header{padding:30px max(22px,calc((100vw - 1440px)/2));background:#302a3c;color:#fff}header h1{margin:0 0 8px;font-size:27px}header p{margin:4px 0;color:#ddd5e7}
.toolbar{position:sticky;top:0;z-index:2;padding:12px max(18px,calc((100vw - 1440px)/2));background:rgba(244,241,234,.97);border-bottom:1px solid var(--line)}
input{width:min(560px,100%);padding:10px 14px;border:1px solid #bdb4c7;border-radius:8px;background:#fff;font-size:15px}nav{display:flex;gap:8px;margin-top:9px}nav a{color:var(--accent);text-decoration:none;background:var(--soft);padding:3px 9px;border-radius:5px}
main{max-width:1440px;margin:auto;padding:12px 20px 48px}section{margin:22px 0;background:var(--paper);border:1px solid var(--line);border-radius:10px;overflow:hidden}h2{font-size:19px;margin:0;padding:14px 18px;background:#ece6da}h2 small{font-size:12px;color:var(--muted);font-weight:400;margin-left:8px}
table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{text-align:left;vertical-align:top;padding:10px 13px;border-top:1px solid #eee9df;overflow-wrap:anywhere;white-space:pre-line}th{font-size:12px;color:var(--muted);background:#faf7f0}th:nth-child(1){width:9%}th:nth-child(2){width:30.3%}th:nth-child(3){width:30.3%}th:nth-child(4){width:30.4%}
.name{font-weight:700;color:#544268}.id{color:var(--muted);font-size:12px}.hidden{display:none}section.all-hidden{display:none}footer{color:var(--muted);font-size:12px;padding:10px 4px}
@media(max-width:820px){th:nth-child(1){width:15%}th:nth-child(2),th:nth-child(3),th:nth-child(4){width:28.3%}th,td{padding:8px;font-size:12px}}
"""


def cell_text(value):
    return html.escape(value, quote=True)


def relic_rows():
    rows = []
    for rid, zh in ZH["relics"].items():
        en = EN["relics"][rid]
        ja = JA["relics"][rid]
        rows.append(
            "<tr><td><span class='id'>" + cell_text(rid) + "</span><br><span class='name'>"
            + cell_text(zh["name"]) + "</span></td><td><b>" + cell_text(zh["name"])
            + "</b>\n" + cell_text(zh["desc"]) + "</td><td><b>" + cell_text(en["name"])
            + "</b>\n" + cell_text(en["desc"]) + "</td><td><b>" + cell_text(ja["name"])
            + "</b>\n" + cell_text(ja["desc"]) + "</td></tr>"
        )
    return "".join(rows)


def class_rows():
    rows = []
    for cid, zh in ZH["classes"].items():
        en = EN["classes"][cid]
        ja = JA["classes"][cid]
        zh_text = zh["subtitle"] + "\n" + zh["desc"]
        en_text = en["subtitle"] + "\n" + en["desc"]
        ja_text = ja["subtitle"] + "\n" + ja["desc"]
        rows.append(
            "<tr><td><span class='name'>" + cell_text(cid) + "</span></td><td><b>"
            + cell_text(cid) + "</b>\n" + cell_text(zh_text) + "</td><td><b>"
            + cell_text(en["name"]) + "</b>\n" + cell_text(en_text) + "</td><td><b>"
            + cell_text(ja["name"]) + "</b>\n" + cell_text(ja_text) + "</td></tr>"
        )
    return "".join(rows)


header = "<thead><tr><th>ID / 名称</th><th>规范中文</th><th>English</th><th>日本語</th></tr></thead>"
body = (
    "<section id='relics'><h2>道具长描述 <small>62 件</small></h2><table>"
    + header + "<tbody>" + relic_rows() + "</tbody></table></section>"
    + "<section id='classes'><h2>角色副标题与介绍 <small>3 名</small></h2><table>"
    + header + "<tbody>" + class_rows() + "</tbody></table></section>"
)
doc = (
    "<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>R659 非卡牌长文中英日对照</title><style>" + CSS + "</style></head><body>"
    "<header><h1>R659 非卡牌长文中英日对照</h1>"
    "<p>62 件道具 + 3 名角色；规范中文来自 noncard_zh_canonical.json。</p>"
    "<p>权威 relics.json / player_class.gd 未改；即时 = On pickup／入手時，不虚构消耗规则。</p></header>"
    "<div class='toolbar'><input id='q' type='search' placeholder='搜索 ID、中文、英文或日文…'>"
    "<nav><a href='#relics'>道具 62</a><a href='#classes'>角色 3</a></nav></div>"
    "<main>" + body + "<footer>完整性校验：python i18n/validate_noncard.py</footer></main>"
    "<script>document.getElementById('q').addEventListener('input',function(){"
    "const q=this.value.trim().toLowerCase();document.querySelectorAll('section').forEach(s=>{let visible=0;"
    "s.querySelectorAll('tbody tr').forEach(r=>{const show=!q||r.textContent.toLowerCase().includes(q);"
    "r.classList.toggle('hidden',!show);if(show)visible++});s.classList.toggle('all-hidden',visible===0)})});</script>"
    "</body></html>"
)
OUT.write_text(doc, encoding="utf-8", newline="\n")
print("wrote", OUT.name, "relics", len(ZH["relics"]), "classes", len(ZH["classes"]), "bytes", OUT.stat().st_size)
