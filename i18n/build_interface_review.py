# -*- coding: utf-8 -*-
"""R667：生成商店、奖励、地图、剧情界面与共享组件的可搜索中英日对照页。"""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "interface_zh_canonical.json").read_text(encoding="utf-8"))
EN = json.loads((I18N / "interface_en.json").read_text(encoding="utf-8"))
JA = json.loads((I18N / "interface_ja.json").read_text(encoding="utf-8"))
OUT = I18N / "interface_review.html"
SCOPES = (
    ("shop", "商店与附魔"),
    ("reward", "通用奖励"),
    ("map", "地图、卡组与图鉴"),
    ("shell", "剧情、鸣谢与界面骨架"),
    ("shared", "共享组件与禁卡表"),
)

CSS = """
:root{--bg:#f4f1ea;--paper:#fffdf8;--ink:#292b32;--muted:#6b6c73;--line:#ded8ca;--accent:#67508d;--soft:#eee8f4}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:"Segoe UI","Microsoft YaHei",sans-serif;line-height:1.55}
header{padding:30px max(22px,calc((100vw - 1560px)/2));background:#302a3c;color:#fff}header h1{margin:0 0 8px;font-size:27px}header p{margin:4px 0;color:#ddd5e7}
.toolbar{position:sticky;top:0;z-index:2;padding:12px max(18px,calc((100vw - 1560px)/2));background:rgba(244,241,234,.97);border-bottom:1px solid var(--line)}
input{width:min(650px,100%);padding:10px 14px;border:1px solid #bdb4c7;border-radius:8px;background:#fff;font-size:15px}nav{display:flex;gap:8px;margin-top:9px;flex-wrap:wrap}nav a{color:var(--accent);text-decoration:none;background:var(--soft);padding:3px 9px;border-radius:5px}
main{max-width:1560px;margin:auto;padding:12px 20px 48px}section{margin:22px 0;background:var(--paper);border:1px solid var(--line);border-radius:10px;overflow:hidden}h2{font-size:19px;margin:0;padding:14px 18px;background:#ece6da}h2 small{font-size:12px;color:var(--muted);font-weight:400;margin-left:8px}
table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{text-align:left;vertical-align:top;padding:10px 13px;border-top:1px solid #eee9df;overflow-wrap:anywhere;white-space:pre-line}th{font-size:12px;color:var(--muted);background:#faf7f0}th:nth-child(1){width:17%}th:nth-child(2){width:27.6%}th:nth-child(3){width:27.6%}th:nth-child(4){width:27.8%}
.id{font-weight:700;color:#544268}.source{display:block;color:var(--muted);font-size:11px;margin-top:5px}.hidden{display:none}section.all-hidden{display:none}footer{color:var(--muted);font-size:12px;padding:10px 4px}
@media(max-width:820px){th:nth-child(1){width:19%}th:nth-child(2),th:nth-child(3),th:nth-child(4){width:27%}th,td{padding:8px;font-size:12px}}
"""


def esc(value):
    return html.escape(str(value), quote=True)


def rows(scope):
    result = []
    for key, entry in ZH["scopes"][scope].items():
        label = ("<span class='id'>" + esc(key) + "</span><span class='source'>"
                 + esc(entry["source"]) + "</span>")
        result.append("<tr><td>" + label + "</td><td>" + esc(entry["zh"]) + "</td><td>"
                      + esc(EN["scopes"][scope][key]) + "</td><td>"
                      + esc(JA["scopes"][scope][key]) + "</td></tr>")
    return "".join(result)


header = "<thead><tr><th>ID / 源码</th><th>规范中文</th><th>English</th><th>日本語</th></tr></thead>"
body = ""
nav = ""
total = 0
for scope, title in SCOPES:
    count = len(ZH["scopes"][scope])
    total += count
    body += ("<section id='" + scope + "'><h2>" + title + " <small>" + str(count)
             + " 条</small></h2><table>" + header + "<tbody>" + rows(scope)
             + "</tbody></table></section>")
    nav += "<a href='#" + scope + "'>" + title + " " + str(count) + "</a>"

doc = (
    "<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>R667 界面与共享组件中英日对照</title><style>" + CSS + "</style></head><body>"
    "<header><h1>R667 界面与共享组件中英日对照</h1><p>共 " + str(total)
    + " 条：商店附魔、通用奖励、地图卡组、剧情鸣谢、共享组件与禁卡表。</p>"
    "<p>权威中文源码未改；明确规则漂移只修 canonical。卡名、道具名、房间名与既有界面译文统一复用。</p>"
    "<p>本页是翻译数据验收，不表示运行时接线已完成。</p></header>"
    "<div class='toolbar'><input id='q' type='search' placeholder='搜索 ID、源码、中文、英文或日文…'>"
    "<nav>" + nav + "</nav></div><main>" + body
    + "<footer>完整性校验：python i18n/validate_interface.py</footer></main>"
    "<script>document.getElementById('q').addEventListener('input',function(){"
    "const q=this.value.trim().toLowerCase();document.querySelectorAll('section').forEach(s=>{let visible=0;"
    "s.querySelectorAll('tbody tr').forEach(r=>{const show=!q||r.textContent.toLowerCase().includes(q);"
    "r.classList.toggle('hidden',!show);if(show)visible++});s.classList.toggle('all-hidden',visible===0)})});</script>"
    "</body></html>"
)
OUT.write_text(doc, encoding="utf-8", newline="\n")
print("wrote", OUT.name, "total", total, "bytes", OUT.stat().st_size)
