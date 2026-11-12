# -*- coding: utf-8 -*-
"""R601 · 故事档案 HTML 报告生成器（stories.json -> 单页 HTML）

只读 stories.json / cards.json / relics.json，不改任何游戏数据。
产物：_preview/story_report_r601/story_report.html
"""
import json
import io
import os
import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "_preview", "story_report_r601")


def load(name):
    with io.open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return json.load(f)


stories = load("stories.json")
cards = load("cards.json")
relics = load("relics.json")

CARD_NAME = {}
for c in cards.get("cards", []):
    CARD_NAME[int(c["id"])] = c.get("name", str(c["id"]))
RELIC_NAME = {}
for r in relics.get("relics", []):
    RELIC_NAME[int(r["id"])] = r.get("name", str(r["id"]))

episodes = stories.get("episodes", [])
profiles = stories.get("profiles", [])
achievements = stories.get("achievements", [])

# episode id -> achievement
ACH_BY_EP = {}
for a in achievements:
    for eid in a.get("episodes", []):
        ACH_BY_EP[eid] = a

STATE_ORDER = ["locked", "ready", "read"]


def esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def is_dialogue(line):
    s = line.strip()
    return s.startswith("\u201c") and s.endswith("\u201d")


def rewards_html(grants):
    items = []
    for cid in grants.get("cards", []) or []:
        nm = CARD_NAME.get(int(cid), "卡牌 " + str(cid))
        items.append('<span class="pill pill-card"><i>卡</i>' + esc(nm) + "</span>")
    for rid in grants.get("relics", []) or []:
        nm = RELIC_NAME.get(int(rid), "道具 " + str(rid))
        items.append('<span class="pill pill-relic"><i>器</i>' + esc(nm) + "</span>")
    if not items:
        return '<span class="pill pill-none">无（仅阅读）</span>'
    return "".join(items)


def ach_hint(eid):
    a = ACH_BY_EP.get(eid)
    if not a:
        return "—"
    return esc(a.get("hint", ""))


def body_html(text):
    out = []
    for line in text:
        cls = "line line-dlg" if is_dialogue(line) else "line line-nar"
        out.append('<p class="' + cls + '">' + esc(line) + "</p>")
    return "\n".join(out)


def entry_card(e, idx, kind):
    """kind: 'ep' 正篇 / 'pf' 档案"""
    no = "%02d" % idx
    tag = e.get("chapter", "")
    title = esc(e.get("title", ""))
    text = e.get("text", []) or []
    grants = e.get("grants", {}) or {}
    lines = len(text)
    sub = ""
    if kind == "pf":
        no = "A" + no
        sub = '<span class="tag tag-arc">ARCHIVE</span>'
    else:
        sub = '<span class="tag tag-ch">' + esc(tag) + "</span>"
    return """
    <article class="card %(cls)s">
      <div class="card-head">
        <div class="card-no">%(no)s</div>
        <div class="card-title-wrap">
          <div class="card-tags">%(sub)s<span class="tag tag-lines">%(lines)d 行</span></div>
          <h3 class="card-title">%(title)s</h3>
        </div>
      </div>
      <div class="card-body">
%(body)s
      </div>
      <div class="card-foot">
        <div class="foot-item"><span class="foot-k">解锁条件</span><span class="foot-v">%(hint)s</span></div>
        <div class="foot-item"><span class="foot-k">入池奖励</span><span class="foot-v">%(rw)s</span></div>
      </div>
    </article>""" % {
        "cls": "card-ep" if kind == "ep" else "card-pf",
        "no": no,
        "sub": sub,
        "lines": lines,
        "title": title,
        "body": body_html(text),
        "hint": ach_hint(e.get("id", "")),
        "rw": rewards_html(grants),
    }


ep_cards = "\n".join(entry_card(e, i + 1, "ep") for i, e in enumerate(episodes))
pf_cards = "\n".join(entry_card(e, i + 1, "pf") for i, e in enumerate(profiles))

ach_rows = []
for i, a in enumerate(achievements, 1):
    ach_rows.append(
        '<div class="ach-cell"><span class="ach-idx">%02d</span>'
        '<span class="ach-name">%s</span>'
        '<span class="ach-hint">%s</span></div>'
        % (i, esc(a.get("name", "")), esc(a.get("hint", "")))
    )
ach_html = "".join(ach_rows)
if len(achievements) % 2 == 1:
    ach_html += '<div class="ach-cell ach-empty"></div>'

now = datetime.datetime.now()
STAMP = now.strftime("%Y.%m.%d  %H:%M")
TOTAL = len(episodes) + len(profiles)
CH_WORDS = sum(len(e.get("text", []) or []) for e in episodes)
PF_WORDS = sum(len(e.get("text", []) or []) for e in profiles)

CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html { -webkit-font-smoothing:antialiased; }
body {
  width:1080px; background:#f2ebdd; color:#2c2521;
  font-family:"Songti SC","Noto Serif SC","Source Han Serif SC","STSong",serif;
  position:relative;
}
body::before {
  content:""; position:fixed; inset:0; z-index:0; pointer-events:none;
  background-image:radial-gradient(#c9b79a 0.5px, transparent 0.6px);
  background-size:5px 5px; opacity:.30;
}
.wrap { position:relative; z-index:1; padding:56px 64px 48px 64px; }

/* ---------- 页头 ---------- */
.masthead { border-bottom:2px solid #2c2521; padding-bottom:22px; }
.mast-row { display:flex; justify-content:space-between; align-items:baseline;
  font-family:"Helvetica Neue",Arial,sans-serif; letter-spacing:.22em;
  font-size:11px; color:#8a7454; text-transform:uppercase; }
.mast-title { display:flex; align-items:flex-end; gap:18px; margin-top:26px; }
.mast-title h1 { font-size:62px; font-weight:900; letter-spacing:.10em; line-height:1; }
.mast-title .lat { font-family:"Helvetica Neue",Arial,sans-serif; font-size:13px;
  letter-spacing:.34em; color:#a08a68; padding-bottom:9px; }
.mast-desc { margin-top:18px; font-size:15px; line-height:1.95; color:#5d5045; max-width:820px; }
.mast-desc b { color:#8c5a26; }
.mast-stat { display:flex; gap:0; margin-top:30px; border:1px solid #cdbca1;
  background:rgba(255,252,245,.68); }
.stat { flex:1; padding:16px 20px; border-right:1px solid #d9c9ae; }
.stat:last-child { border-right:0; }
.stat .n { font-family:"Helvetica Neue",Arial,sans-serif; font-size:30px;
  font-weight:700; color:#8c5a26; line-height:1; letter-spacing:.02em; }
.stat .l { font-size:12px; color:#7c6b58; margin-top:8px; letter-spacing:.14em; }

/* ---------- 分节 ---------- */
.sec-head { margin:52px 0 22px; display:flex; align-items:baseline; gap:16px; }
.sec-head .k { font-family:"Helvetica Neue",Arial,sans-serif; font-size:11px;
  letter-spacing:.3em; color:#a58a5f; }
.sec-head h2 { font-size:26px; font-weight:800; letter-spacing:.12em; }
.sec-head .rule { flex:1; height:1px; background:repeating-linear-gradient(
  90deg,#c9b79a 0 6px, transparent 6px 11px); margin-bottom:5px; }
.sec-note { font-size:13px; color:#7c6b58; line-height:1.9; margin:-8px 0 24px; }

/* ---------- 故事卡 ---------- */
.card { position:relative; background:#fdf9f1; border:1px solid #d8c8ad;
  box-shadow:0 2px 0 #e4d8c2, 0 14px 26px -22px rgba(70,50,20,.55);
  padding:26px 30px 22px 30px; margin-bottom:20px; }
.card::before { content:""; position:absolute; left:0; top:0; bottom:0; width:4px;
  background:#b98a4b; }
.card-pf { background:#f6f5f1; border-color:#c6c6bd; }
.card-pf::before { background:#5c6b7a; }

.card-head { display:flex; gap:20px; align-items:flex-start;
  border-bottom:1px solid #e6dbc6; padding-bottom:14px; }
.card-pf .card-head { border-bottom-color:#dcdcd4; }
.card-no { font-family:"Helvetica Neue",Arial,sans-serif; font-size:40px; font-weight:800;
  color:#cbb18a; line-height:.9; letter-spacing:-.02em; min-width:92px; }
.card-pf .card-no { color:#aab2ba; }
.card-title { font-size:27px; font-weight:800; letter-spacing:.08em; margin-top:9px; }
.card-tags { display:flex; gap:8px; }
.tag { font-family:"Helvetica Neue",Arial,sans-serif; font-size:10px; letter-spacing:.2em;
  padding:3px 8px; border:1px solid #cbb18a; color:#96682f; text-transform:uppercase; }
.tag-lines { border-color:#ddd0b8; color:#9d8d75; }
.card-pf .tag { border-color:#a9b3bc; color:#54626f; }
.card-pf .tag-lines { border-color:#d3d6d2; color:#8d959b; }

.card-body { padding:18px 0 4px 0; }
.line { font-size:17.5px; line-height:2.0; color:#332b25; }
.line-nar { text-indent:0; }
.line-dlg { color:#7d3f22; padding-left:16px; border-left:2px solid #e3c9a6;
  margin:2px 0; }
.card-pf .line-dlg { color:#3f5464; border-left-color:#c3ccd4; }

.card-foot { display:flex; flex-wrap:wrap; gap:10px 26px; margin-top:18px;
  border-top:1px dashed #ddd0b8; padding-top:14px; }
.card-pf .card-foot { border-top-color:#d8dad4; }
.foot-item { display:flex; align-items:baseline; gap:10px; }
.foot-k { font-size:11px; letter-spacing:.2em; color:#a08a68; white-space:nowrap; }
.foot-v { font-size:13px; color:#5d5045; line-height:1.7; }
.pill { display:inline-block; font-size:12.5px; padding:3px 10px 3px 8px; margin-right:6px;
  border:1px solid #d3c3a6; background:#fbf2df; color:#7b4a1e; }
.pill i { font-style:normal; font-family:"Helvetica Neue",Arial,sans-serif;
  font-size:9.5px; letter-spacing:.1em; border:1px solid #c9a86f; padding:0 4px;
  margin-right:6px; color:#9a6a2c; }
.pill-relic { background:#eef2ee; border-color:#bcc9bc; color:#3f5a44; }
.pill-relic i { border-color:#9db09d; color:#4c6b52; }
.pill-none { background:transparent; border-style:dashed; color:#a1907a; }

/* ---------- 成就 ---------- */
.ach-grid { display:grid; grid-template-columns:1fr 1fr; gap:1px;
  background:#d8c8ad; border:1px solid #d8c8ad; }
.ach-cell { background:#fdf9f1; padding:14px 18px; display:flex;
  align-items:baseline; gap:12px; }
.ach-idx { font-family:"Helvetica Neue",Arial,sans-serif; font-size:11px;
  color:#bd9f74; letter-spacing:.1em; }
.ach-name { font-size:14.5px; font-weight:700; letter-spacing:.06em; min-width:112px; }
.ach-hint { font-size:12.5px; color:#7c6b58; line-height:1.7; }
.ach-empty { background:#f7f2e8;
  background-image:repeating-linear-gradient(45deg,#efe6d6 0 1px,transparent 1px 9px); }

/* ---------- 页脚 ---------- */
.foot { margin-top:44px; border-top:2px solid #2c2521; padding-top:16px;
  display:flex; justify-content:space-between;
  font-family:"Helvetica Neue",Arial,sans-serif; font-size:11px;
  letter-spacing:.16em; color:#8a7454; }
"""

HTML = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>故事档案 · card_rogue</title>
<style>__CSS__</style>
</head>
<body>
<div class="wrap">

  <div class="masthead">
    <div class="mast-row"><span>card_rogue &nbsp;/&nbsp; story archive</span><span>__STAMP__</span></div>
    <div class="mast-title">
      <h1>故事档案</h1>
      <div class="lat">ALL STORIES</div>
    </div>
    <p class="mast-desc">游戏内全部剧情文本汇总 —— 六章正篇按推进顺序排列，其后是随击败条件解锁的五篇追加档案。
      每段附「解锁条件」与「入池奖励」：奖励指<b>看完之后加入奖励池</b>的卡牌与道具，并非直接发放。</p>
    <div class="mast-stat">
      <div class="stat"><div class="n">06</div><div class="l">正篇章节</div></div>
      <div class="stat"><div class="n">05</div><div class="l">追加档案</div></div>
      <div class="stat"><div class="n">__TOTAL__</div><div class="l">故事总数</div></div>
      <div class="stat"><div class="n">__ACH__</div><div class="l">成就条目</div></div>
    </div>
  </div>

  <div class="sec-head"><span class="k">PART I</span><h2>正篇</h2><span class="rule"></span></div>
  <p class="sec-note">按成就达成顺序解锁；达成条件只让条目亮起，点开阅读后才把奖励送进奖励池。</p>
  __EP__

  <div class="sec-head"><span class="k">PART II</span><h2>追加档案</h2><span class="rule"></span></div>
  <p class="sec-note">与主线并行的人物与设定补录，解锁条件多为击破特定 Boss 或精英。</p>
  __PF__

  <div class="sec-head"><span class="k">INDEX</span><h2>成就索引</h2><span class="rule"></span></div>
  <p class="sec-note">共 __ACH__ 条，每条对应一段故事。</p>
  <div class="ach-grid">__ACHROWS__</div>

  <div class="foot"><span>source: stories.json &nbsp;·&nbsp; __EPN__ 章 + __PFN__ 档案 &nbsp;·&nbsp; __LINES__ 行正文</span><span>generated __STAMP__</span></div>
</div>
</body>
</html>
"""

html = (HTML
        .replace("__CSS__", CSS)
        .replace("__STAMP__", STAMP)
        .replace("__TOTAL__", "%02d" % TOTAL)
        .replace("__ACH__", "%02d" % len(achievements))
        .replace("__EP__", ep_cards)
        .replace("__PF__", pf_cards)
        .replace("__ACHROWS__", ach_html)
        .replace("__EPN__", str(len(episodes)))
        .replace("__PFN__", str(len(profiles)))
        .replace("__LINES__", str(CH_WORDS + PF_WORDS)))

os.makedirs(OUT_DIR, exist_ok=True)
out = os.path.join(OUT_DIR, "story_report.html")
with io.open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print("HTML:", out, len(html), "chars")
print("episodes=%d profiles=%d achievements=%d lines=%d" % (len(episodes), len(profiles), len(achievements), CH_WORDS + PF_WORDS))
