# -*- coding: utf-8 -*-
"""R724 底本差异专版：把 cards.json（原文）与 i18n/zh_canonical.json（翻译底本）
的每一处不一致分类列出来，并标注哪些是术语规范化、哪些是待决策、哪些已修。

用法：python tools/build_drift_report.py
输出：_review/text_drift_report.html
只读，不改任何数据。
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_review/text_drift_report.html"

cards = json.loads((ROOT / "cards.json").read_text(encoding="utf-8"))["cards"]
zcards = json.loads((ROOT / "i18n/zh_canonical.json").read_text(encoding="utf-8"))["cards"]
en = json.loads((ROOT / "i18n/cards_en.json").read_text(encoding="utf-8"))["cards"]
ja = json.loads((ROOT / "i18n/cards_ja.json").read_text(encoding="utf-8"))["cards"]
es = json.loads((ROOT / "i18n/cards_es.json").read_text(encoding="utf-8"))["cards"]

# ---- 术语规范化表：直接从 card_text.gd 的 PHRASE_FIXES 解析，避免两处漂移 ----
src = (ROOT / "scripts/card_text.gd").read_text(encoding="utf-8")
block = src.split("const PHRASE_FIXES := [", 1)[1].split("\n]", 1)[0]
FIXES = re.findall(r'\["([^"]*)",\s*"([^"]*)"\]', block)
assert len(FIXES) > 30, len(FIXES)


# PHRASE_FIXES 里有「返回手卡」→「收回手牌」这种整句换词，底本写的是「返回手牌」，
# 两边过完规则后一个变「收回手牌」一个还是「返回手牌」，会被误判成内容差异。
# 这里补一层「显示层同义」归类，只用于本报告判定，不改数据。
DISPLAY_ALIAS = [("收回手牌", "返回手牌")]


def normalize_terms(s):
    out = s
    for a, b in FIXES:
        out = out.replace(a, b)
    for a, b in DISPLAY_ALIAS:
        out = out.replace(a, b)
    out = re.sub(r"(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])", "", out)
    return out


def norm(s):
    return re.sub(r"\s+", "", s).strip()


rows = []
for c in cards:
    cid = str(c["id"])
    canon = zcards.get(cid)
    if not canon:
        continue
    for field in ("name", "effect_text"):
        a = str(c.get(field, ""))
        b = str(canon.get(field, ""))
        if norm(a) == norm(b):
            continue
        # 两边都过一遍术语规则：底本常常只是没跟上新规则，不算内容差异。
        if norm(normalize_terms(a)) == norm(normalize_terms(b)):
            kind = "term"
        elif ("攻击力" in a or "攻击 +" in a) and "力量" in b:
            kind = "power"
        else:
            kind = "content"
        rows.append({"id": cid, "name": c["name"], "field": field,
                     "raw": a, "canon": b, "kind": kind})

term_rows = [r for r in rows if r["kind"] == "term"]
content_rows = [r for r in rows if r["kind"] == "content"]
power_rows = [r for r in rows if r["kind"] == "power"]
other_rows = content_rows

FIXED = [
    ("9055", "狂暴", "费用 -1（底本）→ 费用 -2",
     "game_engine.gd 的 FRENZY_DISCOUNT := 2（R663 用户口径由 -1 改 -2）；"
     "原文与英日西译文都是 -2，只有底本没跟上。已把底本改成 -2。"),
    ("9037", "森林守护", "底本漏了「死亡：抽一张卡。」",
     "原文与 en/ja/es 都有这半句，底本缺；译文会丢掉一个抽牌效果。已补回底本。"),
    ("9005", "智慧", "底本漏了「自己效果卡区有至少 2 张卡时，回复 1 点费用。」",
     "同上：原文与译文都完整，底本只剩「抽 2 张牌。」。已补回底本。"),
    ("8056", "救援构装体", "底本多出一整句「交换：…」",
     "「交换」是 affixes 字段（卡面走角标），原文 effect_text 本来就是空；"
     "底本那句是字段解释，译文的 Swap/交換句子也跟着它跑。四语一起清掉。"),
]

TRANS_FIXED = [
    ("9135", "赫菲斯托斯", "本局被译成永久",
     "中文写「本局累计」，en 是 permanently、ja 是「永続累積」、es 是 permanentemente —— "
     "按 R701，「本局」只在本场战斗保留，和「永久」是两回事。三语已改成 this battle / この戦闘中 / esta batalla。"),
    ("8048", "生产订单", "同一个词写了两遍",
     "数据原文是「卡组（抽牌堆）」，直译后变成 en「Draw Pile (draw pile)」、ja「山札（山札）」。"
     "已按术语统一为抽牌库，译文只剩一遍。"),
    ("1011 / 1013 / 1051 / 1055 / 1071", "二层小怪", "译文多写了中文没有的说明",
     "英文多了「Taunt: enemy units must attack it first.」「May act twice per turn.」，"
     "中文没有 —— 这两件事由 traits 角标表达。已随本轮一起删掉。"),
]


def esc(s):
    return html.escape(str(s), quote=True)


def row_html(r):
    return ("<tr><td><code>%s</code><br><span class=n>%s</span></td>"
            "<td class=raw>%s</td><td class=canon>%s</td></tr>"
            % (esc(r["id"]), esc(r["name"]), esc(r["raw"]) or "<i>（空）</i>",
               esc(r["canon"]) or "<i>（空）</i>"))


th = "<thead><tr><th>卡号 / 名称</th><th>cards.json 原文</th><th>zh_canonical 底本</th></tr></thead>"

power_body = "".join(row_html(r) for r in power_rows) if power_rows else "<tr><td colspan=3>无</td></tr>"
term_body = "".join(row_html(r) for r in term_rows)
other_body = "".join(row_html(r) for r in other_rows) if other_rows else "<tr><td colspan=3>无</td></tr>"

# 显示层只把「攻击力」换成「力量」，写成「攻击 +1」的漏过去了 —— 玩家会看到「攻击 +1」，
# 而译文说 Strength / 攻撃力 / fuerza。底本与原文在这两句上是一致的，所以上面查不出漂移。
leak_re = re.compile(r"攻击\s*[+\-]\s*\d")
leak_rows = [c for c in cards if leak_re.search(str(c.get("effect_text", "")))]
leak_lead = ("另外原文里还有 <b>%d</b> 处写成「攻击 +N」（不是「攻击力」三字），显示层只替换「攻击力」，"
             "所以玩家会真的看到「攻击 +1」，而英日西译文说的是力量 ——"
             "这一条是实打实的不一致，不是报告口径问题。其中 9038 同时属于上面的漂移，"
             "8045 则是原文与底本都这么写、只靠比对查不出来。" % len(leak_rows))
leak_body = "".join(
    "<tr><td><code>%s</code><br><span class=n>%s</span></td><td class=raw>%s</td><td class=canon>%s</td></tr>"
    % (esc(c["id"]), esc(c["name"]), esc(c.get("effect_text", "")),
       esc(zcards.get(str(c["id"]), {}).get("effect_text", "")))
    for c in leak_rows) or "<tr><td colspan=3>无</td></tr>"

fixed_body = "".join(
    "<tr><td><code>%s</code><br><span class=n>%s</span></td><td><b>%s</b></td><td class=why>%s</td></tr>"
    % (esc(a), esc(b), esc(c), esc(d)) for a, b, c, d in FIXED)
trans_body = "".join(
    "<tr><td><code>%s</code><br><span class=n>%s</span></td><td><b>%s</b></td><td class=why>%s</td></tr>"
    % (esc(a), esc(b), esc(c), esc(d)) for a, b, c, d in TRANS_FIXED)

doc = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>底本与原文差异专版 · card_rogue R725</title>
<style>
:root{--bg:#f5f2ec;--paper:#fffdf8;--ink:#24262d;--muted:#71727b;--line:#e2dbcc;--accent:#6a4f9c;
--soft:#efe9f6;--warn:#b8562c;--warnbg:#fdf0e8;--ok:#2f6b4f;--okbg:#eaf4ee}
body.dark{--bg:#191a20;--paper:#21232b;--ink:#e6e6ea;--muted:#8d8f9c;--line:#32343f;--accent:#b79cf0;
--soft:#2b2740;--warn:#e8915f;--warnbg:#33241c;--ok:#7fc09b;--okbg:#1d2b24}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);
font-family:"Segoe UI","Microsoft YaHei",sans-serif;line-height:1.65;font-size:14px}
header{padding:30px max(20px,calc((100vw - 1120px)/2)) 24px;background:#2f2a3c;color:#fff}
body.dark header{background:#15161b}
header h1{margin:0 0 10px;font-size:25px}header p{margin:5px 0;color:#d8d2e4;font-size:13px}
.stats{display:flex;gap:10px;flex-wrap:wrap;margin-top:14px}
.stats div{background:rgba(255,255,255,.09);border-radius:8px;padding:7px 13px;font-size:12px;color:#e7e3f0}
.stats b{display:block;font-size:19px;color:#fff;font-weight:600}
main{max-width:1120px;margin:0 auto;padding:20px 18px 70px}
section{margin:24px 0;background:var(--paper);border:1px solid var(--line);border-radius:10px;overflow:hidden}
h2{margin:0;padding:13px 18px;font-size:17px;background:var(--soft);border-bottom:1px solid var(--line)}
h2 small{font-size:12px;color:var(--muted);font-weight:400;margin-left:8px}
.lead{padding:12px 18px;font-size:13px;color:var(--muted);border-bottom:1px solid var(--line)}
table{width:100%;border-collapse:collapse;table-layout:fixed}
th,td{text-align:left;vertical-align:top;padding:9px 13px;border-top:1px solid var(--line);
overflow-wrap:anywhere;white-space:pre-wrap;font-size:13px}
th{font-size:11.5px;color:var(--muted);background:var(--bg)}
th:nth-child(1){width:15%}th:nth-child(2){width:42%}th:nth-child(3){width:43%}
code{font-family:ui-monospace,Consolas,monospace;font-size:11.5px;color:var(--accent)}
.n{font-size:11px;color:var(--muted)}
.raw{color:var(--muted)}.canon{color:var(--ink)}
.why{font-size:12.5px;color:var(--muted)}
.tag{display:inline-block;font-size:10.5px;border-radius:4px;padding:1px 7px;margin-left:6px}
.t-ok{background:var(--okbg);color:var(--ok)}.t-warn{background:var(--warnbg);color:var(--warn)}
footer{text-align:center;color:var(--muted);font-size:11.5px;padding:8px 20px 40px}
</style></head><body>
<header>
  <h1>底本与原文差异专版</h1>
  <p>对比 <code>cards.json</code>（运行时权威原文）与 <code>i18n/zh_canonical.json</code>（翻译底本）。</p>
  <p>底本是译文唯一来源，它和原文不一致时，玩家看到的中文与译文说的就不是一回事。</p>
  <div class="stats">
    <div><b>__TOTAL__</b>剩余差异</div>
    <div><b>__TERM__</b>纯术语规范化</div>
    <div><b>__POWER__</b>力量/攻击力待定</div>
    <div><b>__OTHER__</b>其他内容差异</div>
    <div><b>__FIXED__</b>本轮已修</div>
  </div>
</header>
<main>

<section>
  <h2>① 本轮已修：底本落后于原文的四条<span class="tag t-ok">已处理</span></h2>
  <div class="lead">这四条不是风格问题，是底本真的缺了内容或写错了数值 —— 译文会跟着错。</div>
  <table><thead><tr><th>卡号 / 名称</th><th>问题</th><th>依据与处理</th></tr></thead>
  <tbody>__FIXEDBODY__</tbody></table>
</section>

<section>
  <h2>② 本轮顺手修掉的译文问题</h2>
  <div class="lead">都是在同一批卡上顺手发现的，属于「译文和中文说的不是一件事」。</div>
  <table><thead><tr><th>卡号 / 名称</th><th>问题</th><th>说明</th></tr></thead>
  <tbody>__TRANSBODY__</tbody></table>
</section>

<section>
  <h2>③ 力量 / 攻击力 两套写法<span class="tag t-warn">需你定</span></h2>
  <div class="lead">原文写「攻击力」，底本已统一成「力量」。日文两边都译「攻撃力」，所以日文侧永远发现不了这个分歧 ——
  只有中文玩家会看到同一个数值两个名字。要统一成哪一套，你定，我照改。</div>
  <table>__TH__<tbody>__POWERBODY__</tbody></table>
  <div class="lead">__LEAKLEAD__</div>
  <table>__TH__<tbody>__LEAKBODY__</tbody></table>
</section>

<section>
  <h2>④ 其他内容差异</h2>
  <div class="lead">除去术语替换后仍不一致的条目。<b>现在是 0</b>：原先被算进来的 9095 / 9102 / 9127
  只是「返回手卡 → 收回手牌」这条显示规则的两头写法不同，已归入⑤。</div>
  <table>__TH__<tbody>__OTHERBODY__</tbody></table>
</section>

<section>
  <h2>⑤ 纯术语规范化<span class="tag t-ok">设计如此</span></h2>
  <div class="lead">这一类是底本按规则把旧写法统一成了新写法（手卡→手牌、弃牌堆→弃牌区、卡组→抽牌库、
  生命值→生命、卡牌→卡…）。<b>显示层 PHRASE_FIXES 对玩家也会做同样的替换</b>，所以玩家看到的是一致的，
  不需要逐条改数据；列在这里只是让差异可追溯。共 __TERM__ 条。</div>
  <table>__TH__<tbody>__TERMBODY__</tbody></table>
</section>

<footer>由 <code>tools/build_drift_report.py</code> 生成 · 只读 · 术语规则直接从 card_text.gd 的 PHRASE_FIXES 解析</footer>
</main>
<script>
document.addEventListener('keydown',e=>{if(e.key==='d'){document.body.classList.toggle('dark');}});
if(location.hash==='#dark')document.body.classList.add('dark');
</script>
</body></html>"""

doc = (doc.replace("__TOTAL__", str(len(rows)))
          .replace("__TERM__", str(len(term_rows)))
          .replace("__POWER__", str(len(power_rows)))
          .replace("__OTHER__", str(len(other_rows)))
          .replace("__FIXED__", str(len(FIXED)))
          .replace("__FIXEDBODY__", fixed_body)
          .replace("__TRANSBODY__", trans_body)
          .replace("__POWERBODY__", power_body)
          .replace("__LEAKBODY__", leak_body)
          .replace("__LEAKLEAD__", leak_lead)
          .replace("__OTHERBODY__", other_body)
          .replace("__TERMBODY__", term_body)
          .replace("__TH__", th))

OUT.parent.mkdir(exist_ok=True)
OUT.write_text(doc, encoding="utf-8", newline="\n")
print("差异 %d：术语 %d / 力量-攻击力 %d / 其他 %d"
      % (len(rows), len(term_rows), len(power_rows), len(other_rows)))
print("wrote", OUT, "%.0f KB" % (OUT.stat().st_size / 1024))
