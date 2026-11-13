# -*- coding: utf-8 -*-
"""R664：生成事件、剧情与成就提示的可搜索中英日对照页。"""
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
ZH = json.loads((I18N / "narrative_zh_canonical.json").read_text(encoding="utf-8"))
EN = json.loads((I18N / "narrative_en.json").read_text(encoding="utf-8"))
JA = json.loads((I18N / "narrative_ja.json").read_text(encoding="utf-8"))
OUT = I18N / "narrative_review.html"

CSS = """
:root{--bg:#f4f1ea;--paper:#fffdf8;--ink:#292b32;--muted:#6b6c73;--line:#ded8ca;--accent:#67508d;--soft:#eee8f4}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:"Segoe UI","Microsoft YaHei",sans-serif;line-height:1.6}
header{padding:30px max(22px,calc((100vw - 1500px)/2));background:#302a3c;color:#fff}header h1{margin:0 0 8px;font-size:27px}header p{margin:4px 0;color:#ddd5e7}
.toolbar{position:sticky;top:0;z-index:2;padding:12px max(18px,calc((100vw - 1500px)/2));background:rgba(244,241,234,.97);border-bottom:1px solid var(--line)}
input{width:min(620px,100%);padding:10px 14px;border:1px solid #bdb4c7;border-radius:8px;background:#fff;font-size:15px}nav{display:flex;gap:8px;margin-top:9px;flex-wrap:wrap}nav a{color:var(--accent);text-decoration:none;background:var(--soft);padding:3px 9px;border-radius:5px}
main{max-width:1500px;margin:auto;padding:12px 20px 48px}section{margin:22px 0;background:var(--paper);border:1px solid var(--line);border-radius:10px;overflow:hidden}h2{font-size:19px;margin:0;padding:14px 18px;background:#ece6da}h2 small{font-size:12px;color:var(--muted);font-weight:400;margin-left:8px}
table{width:100%;border-collapse:collapse;table-layout:fixed}th,td{text-align:left;vertical-align:top;padding:10px 13px;border-top:1px solid #eee9df;overflow-wrap:anywhere;white-space:pre-line}th{font-size:12px;color:var(--muted);background:#faf7f0}th:nth-child(1){width:15%}th:nth-child(2){width:28.3%}th:nth-child(3){width:28.3%}th:nth-child(4){width:28.4%}
.name{font-weight:700;color:#544268}.id{color:var(--muted);font-size:12px}.hidden{display:none}section.all-hidden{display:none}footer{color:var(--muted);font-size:12px;padding:10px 4px}
@media(max-width:820px){th:nth-child(1){width:18%}th:nth-child(2),th:nth-child(3),th:nth-child(4){width:27.3%}th,td{padding:8px;font-size:12px}}
"""


def esc(value):
    return html.escape(str(value), quote=True)


def row(label, zh_text, en_text, ja_text):
    return ("<tr><td>" + label + "</td><td>" + esc(zh_text) + "</td><td>"
            + esc(en_text) + "</td><td>" + esc(ja_text) + "</td></tr>")


def event_rows():
    rows = []
    for event_key, zh in ZH["events"].items():
        en = EN["events"][event_key]
        ja = JA["events"][event_key]
        for key, zh_text in zh["texts"].items():
            label = ("<span class='name'>" + esc(zh["name"]) + "</span><br>"
                     "<span class='id'>" + esc(event_key) + "<br>" + esc(key) + "</span>")
            rows.append(row(label, zh_text, en["texts"][key], ja["texts"][key]))
    return "".join(rows)


def story_rows():
    rows = []
    for sid, zh in ZH["stories"].items():
        en = EN["stories"][sid]
        ja = JA["stories"][sid]
        label = ("<span class='name'>" + esc(zh["chapter"]) + " · " + esc(zh["title"])
                 + "</span><br><span class='id'>" + esc(sid) + "</span>")
        zh_text = zh["chapter"] + " · " + zh["title"] + "\n\n" + "\n".join(zh["text"])
        en_text = en["chapter"] + " · " + en["title"] + "\n\n" + "\n".join(en["text"])
        ja_text = ja["chapter"] + " · " + ja["title"] + "\n\n" + "\n".join(ja["text"])
        rows.append(row(label, zh_text, en_text, ja_text))
    return "".join(rows)


def achievement_rows():
    rows = []
    for aid, zh in ZH["achievements"].items():
        en = EN["achievements"][aid]
        ja = JA["achievements"][aid]
        label = "<span class='name'>" + esc(zh["name"]) + "</span><br><span class='id'>" + esc(aid) + "</span>"
        rows.append(row(label, zh["name"] + "\n" + zh["hint"],
                        en["name"] + "\n" + en["hint"], ja["name"] + "\n" + ja["hint"]))
    return "".join(rows)


header = "<thead><tr><th>ID / 名称</th><th>规范中文</th><th>English</th><th>日本語</th></tr></thead>"
body = (
    "<section id='events'><h2>事件正文 <small>26 组 / 61 段</small></h2><table>"
    + header + "<tbody>" + event_rows() + "</tbody></table></section>"
    + "<section id='stories'><h2>剧情正文 <small>11 段 / 54 行</small></h2><table>"
    + header + "<tbody>" + story_rows() + "</tbody></table></section>"
    + "<section id='achievements'><h2>剧情成就解锁提示 <small>11 条</small></h2><table>"
    + header + "<tbody>" + achievement_rows() + "</tbody></table></section>"
)
doc = (
    "<!doctype html><html lang='zh-CN'><head><meta charset='utf-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1'>"
    "<title>R664 事件与剧情中英日对照</title><style>" + CSS + "</style></head><body>"
    "<header><h1>R664 事件与剧情中英日对照</h1>"
    "<p>26 组事件 / 61 段正文；11 段剧情 / 54 行；11 条剧情成就提示。</p>"
    "<p>event_scene.gd 与 stories.json 权威中文未改；卡名、道具名与专名复用唯一术语表。</p></header>"
    "<div class='toolbar'><input id='q' type='search' placeholder='搜索 ID、常量名、中文、英文或日文…'>"
    "<nav><a href='#events'>事件 61</a><a href='#stories'>剧情 11</a><a href='#achievements'>提示 11</a></nav></div>"
    "<main>" + body + "<footer>完整性校验：python i18n/validate_narrative.py</footer></main>"
    "<script>document.getElementById('q').addEventListener('input',function(){"
    "const q=this.value.trim().toLowerCase();document.querySelectorAll('section').forEach(s=>{let visible=0;"
    "s.querySelectorAll('tbody tr').forEach(r=>{const show=!q||r.textContent.toLowerCase().includes(q);"
    "r.classList.toggle('hidden',!show);if(show)visible++});s.classList.toggle('all-hidden',visible===0)})});</script>"
    "</body></html>"
)
OUT.write_text(doc, encoding="utf-8", newline="\n")
print("wrote", OUT.name, "events", len(ZH["events"]), "event texts",
      sum(len(x["texts"]) for x in ZH["events"].values()), "stories", len(ZH["stories"]),
      "achievements", len(ZH["achievements"]), "bytes", OUT.stat().st_size)
