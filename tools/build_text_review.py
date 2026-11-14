# -*- coding: utf-8 -*-
"""R724 中文文案总览：把所有玩家可能看到的中文抽成一个可搜索单页。

只读项目数据，不改任何游戏文件。
用法：python tools/build_text_review.py
输出：_review/text_review.html
"""
import html
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
I18N = ROOT / "i18n"
OUT_DIR = ROOT / "_review"
OUT = OUT_DIR / "text_review.html"

CJK = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]")
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')

# ---------- 术语：硬性过时词（命中即算问题） ----------
RISK_WORDS = [
    ("登场", "R709 已改为「入场时」（关卡名「鸭子队长登场」除外）"),
    ("弃牌堆", "统一叫「弃牌区」"),
    ("弃牌库", "统一叫「弃牌区」"),
    ("抽牌堆", "统一叫「抽牌库」"),
    ("射击", "全局已改为「攻击」"),
]

# ---------- 术语：仅提示，可能合法（不计入问题数） ----------
SOFT_WORDS = [
    ("本局", "R701：本局＝本场战斗内"),
    ("永久", "R701：永久＝跨战斗保留"),
    ("攻击力", "另有 53 张卡写「力量」，两套写法并存"),
    ("陷阱", "R690 机制名已改「工具」，具体道具名保留"),
]

INVISIBLE = {
    0x200B: "零宽空格", 0x200C: "零宽非连接", 0x200D: "零宽连接",
    0xFEFF: "BOM/零宽无断点", 0x00A0: "不换行空格", 0x00AD: "软连字符",
    0x2028: "行分隔符", 0x2029: "段分隔符",
}


def load(name):
    p = I18N / name if (I18N / name).exists() else ROOT / name
    return json.loads(p.read_text(encoding="utf-8"))


def norm(s):
    """比对用归一：抹掉格式占位符、空白、标点差异。"""
    s = re.sub(r"%[-+ 0-9.#]*[dsf]", "", s)
    s = re.sub(r"\s+", "", s)
    return s.strip()


def visible_problems(text):
    """返回 [(code, label, detail)]。"""
    out = []
    bad = []
    for ch in text:
        cp = ord(ch)
        if cp in INVISIBLE:
            bad.append("%s(U+%04X)" % (INVISIBLE[cp], cp))
    if bad:
        out.append(("inv", "不可见字符", "、".join(sorted(set(bad)))))
    if text != text.strip():
        out.append(("pad", "首尾空白", "开头或结尾含空格/换行"))
    # 中文字旁边的半角标点
    half = []
    for i, ch in enumerate(text):
        if ch in ",;:!?()" and 0 < i < len(text) - 1:
            if CJK.match(text[i - 1]) or CJK.match(text[i + 1]):
                half.append(ch)
    if half:
        out.append(("punct", "半角标点", "中文旁出现 " + "".join(sorted(set(half)))))
    for word, note in RISK_WORDS:
        if word in text:
            out.append(("term", "过时词", word + "：" + note))
    return out


def soft_notes(text):
    """软提示：可能合法，只显示不计数。"""
    out = []
    for word, note in SOFT_WORDS:
        if word in text:
            out.append(word + (" · " + note if note else ""))
    return out


ZONES = [
    ("card", "卡牌"),
    ("relic", "道具"),
    ("trap", "工具"),
    ("story", "剧情"),
    ("event", "事件"),
    ("ui", "界面"),
    ("code", "代码内"),
]

entries = []          # dict(zone, loc, srcfile, text, note, extra)
covered = set()       # 已入翻译底本的中文（normalize 后）


def add(zone, loc, srcfile, text, note="", flags=None):
    text = str(text)
    if not text.strip():
        return
    entries.append({
        "zone": zone, "loc": loc, "src": srcfile,
        "text": text, "note": note, "flags": flags or [], "soft": [],
    })
    covered.add(norm(text))


# ---------- 1. 卡牌 ----------
cards_doc = load("cards.json")
cards = cards_doc["cards"] if isinstance(cards_doc, dict) else cards_doc
for c in cards:
    cid = c.get("id", "?")
    name = c.get("name", "")
    add("card", "cards.json#%s.name" % cid, "cards.json", name,
        note="%s · %s · %s费" % (c.get("class", ""), c.get("kind", ""), c.get("cost", "-")))
    for field, label in (("effect_text", "效果"), ("lower_effect", "下场"), ("upper_effect", "上场")):
        val = c.get(field)
        if val:
            add("card", "cards.json#%s.%s" % (cid, field), "cards.json", val,
                note="%s · %s" % (name, label))

# ---------- 2. 道具 ----------
for r in load("relics.json")["relics"]:
    rid = r.get("id", "?")
    add("relic", "relics.json#%s.name" % rid, "relics.json", r.get("name", ""),
        note="%s · %s · %s" % (r.get("kind", ""), r.get("tier", ""), r.get("source", "")))
    if r.get("desc"):
        add("relic", "relics.json#%s.desc" % rid, "relics.json", r["desc"],
            note=r.get("name", "") + " · 说明")

# ---------- 3. 工具（陷阱） ----------
for t in load("traps.json")["traps"]:
    tid = t.get("id", "?")
    add("trap", "traps.json#%s.name" % tid, "traps.json", t.get("name", ""),
        note="%s 金" % t.get("price", "-"))
    if t.get("desc"):
        add("trap", "traps.json#%s.desc" % tid, "traps.json", t["desc"])

# ---------- 4. 剧情 ----------
if (ROOT / "stories.json").exists():
    sd = load("stories.json")
    for key in ("episodes", "profiles"):
        for ep in sd.get(key, []):
            eid = ep.get("id", "?")
            base = "stories.json#%s.%s" % (key, eid)
            if ep.get("chapter"):
                add("story", base + ".chapter", "stories.json", ep["chapter"], note=eid)
            if ep.get("title"):
                add("story", base + ".title", "stories.json", ep["title"], note=ep.get("chapter", ""))
            for i, line in enumerate(ep.get("text", [])):
                add("story", "%s.text[%d]" % (base, i), "stories.json", line,
                    note="%s · 第 %d 句" % (ep.get("title", ""), i + 1))
    for a in sd.get("achievements", []):
        aid = a.get("id", "?")
        if a.get("name"):
            add("story", "stories.json#ach.%s.name" % aid, "stories.json", a["name"], note="成就名")
        if a.get("hint"):
            add("story", "stories.json#ach.%s.hint" % aid, "stories.json", a["hint"], note="成就条件")

# ---------- 5. 界面 / 事件 / 叙事底本 ----------
def walk_zh(node, path, zone, srcfile):
    if isinstance(node, dict):
        for k, v in node.items():
            walk_zh(v, path + "." + str(k), zone, srcfile)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk_zh(v, "%s[%d]" % (path, i), zone, srcfile)
    elif isinstance(node, str):
        if CJK.search(node):
            add(zone, "%s%s" % (srcfile, path), srcfile, node)


META = {"version", "updated", "purpose", "_note", "rules_applied", "changed_count",
        "zone_fix", "implementation_notes", "source_snapshots", "expected_counts",
        "l10n_reuse", "glossary_reuse", "glossary_contains", "canonical_overrides"}

iface = load("interface_zh_canonical.json")
for scope, items in iface.get("scopes", {}).items():
    for key, entry in items.items():
        zh = entry.get("zh", "") if isinstance(entry, dict) else str(entry)
        src = entry.get("source", "") if isinstance(entry, dict) else ""
        if zh and CJK.search(zh):
            add("ui", "%s:%s" % (src or "interface", key), "interface_zh_canonical.json", zh,
                note=scope + (" · " + src if src else ""))

for fname, zone in (("event_ui_zh_canonical.json", "event"), ("narrative_zh_canonical.json", "story")):
    doc = load(fname)
    for k, v in doc.items():
        if k in META:
            continue
        walk_zh(v, "." + k, zone, fname)

# ---------- 6. 脚本内中文字符串 ----------
# 排除：测试脚本（断言文案）、ai_bridge（自动化桥，玩家不可见）、控制台打印
SKIP_FILES = {"test_engine.gd", "test_smoke.gd", "test_assemble.gd", "test_traps.gd",
              "test_i18n.gd", "test_reward.gd", "test_bgm.gd", "test_trap_input.gd",
              "ai_bridge.gd"}
CONSOLE_CALL = re.compile(r"\b(print|print_debug|printerr|push_error|push_warning)\s*\(")
code_seen = {}
skipped = 0
for p in sorted((ROOT / "scripts").glob("*.gd")):
    if p.name in SKIP_FILES:
        continue
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    for n, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        # 抹掉行内注释（引号外的 # 之后）
        out, inq, i = [], False, 0
        while i < len(line):
            ch = line[i]
            if ch == '"' and (i == 0 or line[i - 1] != "\\"):
                inq = not inq
                out.append(ch)
            elif ch == "#" and not inq:
                break
            else:
                out.append(ch)
            i += 1
        code = "".join(out)
        is_console = bool(CONSOLE_CALL.search(code))
        for m in STR.finditer(code):
            val = m.group(1)
            if not CJK.search(val):
                continue
            if is_console:
                skipped += 1
                continue
            key = (p.name, val)
            if key in code_seen:
                code_seen[key]["count"] += 1
                continue
            code_seen[key] = {"line": n, "count": 1, "text": val, "file": p.name}

for (fname, val), info in code_seen.items():
    nz = norm(val)
    if nz in covered:
        continue  # 已入翻译底本的数据文本，不重复列
    add("code", "%s:%d" % (fname, info["line"]), fname, val,
        note="出现 %d 次" % info["count"] if info["count"] > 1 else "")

# ---------- 7. 交叉检查：canonical 与权威原文是否漂移 ----------
drift = {}
zc = (I18N / "zh_canonical.json")
if zc.exists():
    zcd = json.loads(zc.read_text(encoding="utf-8")).get("cards", {})
    for c in cards:
        cid = str(c.get("id", ""))
        canon = zcd.get(cid)
        if not canon:
            continue
        for field in ("name", "effect_text"):
            a = str(c.get(field, ""))
            b = str(canon.get(field, a))
            if a and b and norm(a) != norm(b):
                drift["cards.json#%s.%s" % (cid, field)] = b
for e in entries:
    if e["loc"] in drift:
        e["flags"].append("底本与原文不一致")

# ---------- 8. 重复文本标记 ----------
from collections import defaultdict
by_text = defaultdict(list)
for e in entries:
    by_text[e["text"]].append(e)
for text, group in by_text.items():
    if len(group) > 1 and len(text) > 3:
        for e in group:
            e["soft"].append("重复 ×%d" % len(group))

# ---------- 输出 ----------
counts = {z: 0 for z, _ in ZONES}
for e in entries:
    counts[e["zone"]] += 1
problem_total = 0


def esc(s):
    return html.escape(str(s), quote=True)


rows = []
for idx, e in enumerate(entries):
    probs = visible_problems(e["text"])
    hard = [p[1] for p in probs] + list(e["flags"])
    soft = soft_notes(e["text"]) + list(e["soft"])
    tip = "；".join(p[2] for p in probs if p[2])
    has_problem = bool(hard)
    if has_problem:
        problem_total += 1
    badge = "".join("<i class='f'>" + esc(f) + "</i>" for f in hard)
    badge += "".join("<i class='s'>" + esc(f) + "</i>" for f in soft)
    note = e["note"] + ("｜" + tip if tip else "")
    rows.append(
        "<div class='row%s' data-z='%s' data-p='%d'>"
        "<div class='hd'><code class='loc' title='点击复制定位'>%s</code>"
        "<span class='cnt'>%d 字</span></div>"
        "<div class='tx'>%s</div>"
        "<div class='ft'><span class='nt'>%s</span>%s</div></div>"
        % (" prob" if has_problem else "", e["zone"], 1 if has_problem else 0,
           esc(e["loc"]), len(e["text"]), esc(e["text"]),
           esc(note), badge)
    )

zone_chips = "".join(
    "<button class='chip on' data-z='%s'>%s <b>%s</b></button>" % (z, label, counts[z])
    for z, label in ZONES)

doc = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>中文文案总览 · card_rogue</title>
<style>
:root{--bg:#f5f2ec;--paper:#fffdf8;--ink:#24262d;--muted:#71727b;--line:#e2dbcc;--accent:#6a4f9c;--soft:#efe9f6;--warn:#b8562c;--warnbg:#fdf0e8}
body.dark{--bg:#191a20;--paper:#21232b;--ink:#e6e6ea;--muted:#8d8f9c;--line:#32343f;--accent:#b79cf0;--soft:#2b2740;--warn:#e8915f;--warnbg:#33241c}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:"Segoe UI","Microsoft YaHei",sans-serif;line-height:1.6;font-size:14px}
header{padding:28px max(20px,calc((100vw - 1180px)/2)) 22px;background:#2f2a3c;color:#fff}
body.dark header{background:#15161b}
header h1{margin:0 0 10px;font-size:26px;letter-spacing:.5px}
header p{margin:5px 0;color:#d8d2e4;font-size:13px}
.stats{display:flex;gap:10px;flex-wrap:wrap;margin-top:14px}
.stats div{background:rgba(255,255,255,.09);border-radius:8px;padding:7px 13px;font-size:12px;color:#e7e3f0}
.stats b{display:block;font-size:19px;color:#fff;font-weight:600}
.toolbar{position:sticky;top:0;z-index:5;background:var(--bg);border-bottom:1px solid var(--line);
  padding:11px max(16px,calc((100vw - 1180px)/2));box-shadow:0 4px 14px -10px rgba(0,0,0,.4)}
.line1{display:flex;gap:9px;align-items:center;flex-wrap:wrap}
input[type=search]{flex:1 1 320px;min-width:220px;padding:9px 13px;border:1px solid var(--line);border-radius:8px;
  background:var(--paper);color:var(--ink);font-size:15px;outline:none}
input[type=search]:focus{border-color:var(--accent)}
.chip{border:1px solid var(--line);background:var(--paper);color:var(--muted);border-radius:999px;
  padding:5px 12px;font-size:12px;cursor:pointer;transition:.12s}
.chip b{font-weight:600;color:var(--ink)}
.chip.on{background:var(--soft);border-color:var(--accent);color:var(--accent)}
.chip.on b{color:var(--accent)}
.line2{display:flex;gap:16px;align-items:center;margin-top:9px;flex-wrap:wrap;font-size:12px;color:var(--muted)}
.line2 label{display:flex;gap:6px;align-items:center;cursor:pointer;user-select:none}
#hits{font-weight:600;color:var(--accent)}
main{max-width:1180px;margin:0 auto;padding:16px 18px 60px}
.row{background:var(--paper);border:1px solid var(--line);border-radius:9px;padding:11px 14px;margin-bottom:8px}
.row.prob{border-left:3px solid var(--warn)}
.row.hide{display:none}
.hd{display:flex;justify-content:space-between;gap:10px;align-items:baseline;margin-bottom:5px}
.loc{font-family:ui-monospace,Consolas,monospace;font-size:11.5px;color:var(--accent);cursor:pointer;
  background:var(--soft);padding:1px 7px;border-radius:4px;overflow-wrap:anywhere}
.loc:hover{text-decoration:underline}
.cnt{font-size:11px;color:var(--muted);white-space:nowrap}
.tx{font-size:15px;white-space:pre-wrap;overflow-wrap:anywhere}
.ft{display:flex;gap:7px;flex-wrap:wrap;margin-top:6px;align-items:center}
.nt{font-size:11px;color:var(--muted)}
i.f{font-style:normal;font-size:10.5px;background:var(--warnbg);color:var(--warn);
  border-radius:4px;padding:1px 6px;white-space:nowrap}
i.s{font-style:normal;font-size:10.5px;background:var(--soft);color:var(--muted);
  border-radius:4px;padding:1px 6px;white-space:nowrap}
#more{display:none;margin:18px auto;padding:10px 22px;border:1px solid var(--accent);background:var(--paper);
  color:var(--accent);border-radius:8px;cursor:pointer;font-size:13px}
#more.on{display:block}
#toast{position:fixed;left:50%;bottom:26px;transform:translateX(-50%);background:#2f2a3c;color:#fff;
  padding:8px 18px;border-radius:8px;font-size:12.5px;opacity:0;transition:.2s;pointer-events:none;z-index:20}
#toast.on{opacity:1}
footer{text-align:center;color:var(--muted);font-size:11.5px;padding:10px 20px 40px}
@media(max-width:700px){.tx{font-size:14px}header h1{font-size:21px}}
</style></head><body>
<header>
  <h1>中文文案总览</h1>
  <p>把数据表、翻译底本与脚本里的中文字符串全部抽到一页，可直接搜索、筛选、复制定位。</p>
  <p>「代码内」指脚本里的字符串字面量且尚未进入翻译底本 —— 这些通常是最容易漏翻、也最难在游戏里找到的那批文字。</p>
  <p>已排除：测试脚本断言文案、<code>ai_bridge.gd</code>（自动化桥）、控制台 print 输出，共 __SKIP__ 条。</p>
  <div class="stats">
    <div><b>__TOTAL__</b>全部条目</div>
    <div><b>__PROB__</b>需确认</div>
    <div><b>__CODE__</b>代码内未收录</div>
    <div><b>__DRIFT__</b>底本不一致</div>
  </div>
</header>
<div class="toolbar">
  <div class="line1">
    <input id="q" type="search" placeholder="搜索中文、文件名、ID（空格分隔＝同时满足）…  按 / 聚焦">
    <button class="chip on" id="darkBtn">深色</button>
  </div>
  <div class="line1" style="margin-top:9px">__CHIPS__</div>
  <div class="line2">
    <label><input type="checkbox" id="onlyProb"> 只看带标记</label>
    <label><input type="checkbox" id="onlyCode"> 只看代码内未收录</label>
    <span>命中 <span id="hits">0</span> / __TOTAL__</span>
  </div>
</div>
<main>__ROWS__<button id="more">显示更多…</button></main>
<footer>由 <code>tools/build_text_review.py</code> 生成 · 只读项目数据 · 改完文案重跑一次即可刷新<br>
<b>力量 / 攻击力</b>：卡面 53 张写「力量」、14 张写「攻击力」，底本已统一为「力量」，原文未改 —— 需定一套。</footer>
<div id="toast"></div>
<script>
const rows=[...document.querySelectorAll('.row')];
rows.forEach(r=>{r._s=[r.querySelector('.loc').textContent,r.querySelector('.tx').textContent,
  r.querySelector('.nt').textContent].join(' ').toLowerCase();});
const q=document.getElementById('q'),hits=document.getElementById('hits'),
      onlyProb=document.getElementById('onlyProb'),onlyCode=document.getElementById('onlyCode'),
      more=document.getElementById('more');
const active={};document.querySelectorAll('.chip[data-z]').forEach(c=>active[c.dataset.z]=true);
document.querySelectorAll('.chip[data-z]').forEach(c=>{
  c.onclick=()=>{active[c.dataset.z]=!active[c.dataset.z];c.classList.toggle('on',active[c.dataset.z]);render();};});
let limit=250;
function match(r,terms){
  if(!active[r.dataset.z])return false;
  if(onlyProb.checked&&r.dataset.p!=='1')return false;
  if(onlyCode.checked&&!(r.dataset.z==='code'))return false;
  const t=r._s;
  for(const term of terms){if(!t.includes(term))return false;}
  return true;
}
function render(){
  const terms=q.value.trim().toLowerCase().split(/\\s+/).filter(Boolean);
  let shown=0,passed=0;
  for(const r of rows){
    if(match(r,terms)){passed++;if(passed<=limit){r.classList.remove('hide');shown++;}else r.classList.add('hide');}
    else r.classList.add('hide');
  }
  hits.textContent=passed;
  more.classList.toggle('on',passed>limit);
  more.textContent='显示更多（已显示 '+shown+' / '+passed+'）';
}
more.onclick=()=>{limit+=500;render();};
if('IntersectionObserver' in window){
  new IntersectionObserver(es=>{if(es[0].isIntersecting&&more.classList.contains('on')){limit+=500;render();}},
    {rootMargin:'600px'}).observe(more);
}
q.addEventListener('input',()=>{limit=250;render();});
onlyProb.onchange=()=>{limit=250;render();};
onlyCode.onchange=()=>{limit=250;render();};
document.getElementById('darkBtn').onclick=function(){
  document.body.classList.toggle('dark');
  this.textContent=document.body.classList.contains('dark')?'浅色':'深色';
  localStorage.setItem('tr-dark',document.body.classList.contains('dark')?'1':'0');
};
if(localStorage.getItem('tr-dark')==='1'||location.hash==='#dark'){document.body.classList.add('dark');
  document.getElementById('darkBtn').textContent='浅色';}
document.addEventListener('keydown',e=>{if(e.key==='/'&&document.activeElement!==q){e.preventDefault();q.focus();}});
const toast=document.getElementById('toast');
document.querySelectorAll('.loc').forEach(el=>el.onclick=()=>{
  const txt=el.textContent;
  navigator.clipboard&&navigator.clipboard.writeText(txt).then(
    ()=>{toast.textContent='已复制 '+txt;toast.classList.add('on');setTimeout(()=>toast.classList.remove('on'),1100);},
    ()=>{toast.textContent=txt;toast.classList.add('on');setTimeout(()=>toast.classList.remove('on'),1600);});
});
const sp=new URLSearchParams(location.search);
if(sp.get('q'))q.value=sp.get('q');
if(sp.get('z')){
  const zs=sp.get('z').split(',');
  Object.keys(active).forEach(k=>active[k]=zs.includes(k));
  document.querySelectorAll('.chip[data-z]').forEach(c=>c.classList.toggle('on',!!active[c.dataset.z]));
}
if(sp.get('p')==='1')onlyProb.checked=true;
render();
</script></body></html>"""

doc = (doc.replace("__TOTAL__", str(len(entries)))
          .replace("__PROB__", str(problem_total))
          .replace("__CODE__", str(counts["code"]))
          .replace("__DRIFT__", str(len(drift)))
          .replace("__SKIP__", str(skipped))
          .replace("__CHIPS__", zone_chips)
          .replace("__ROWS__", "".join(rows)))

OUT_DIR.mkdir(exist_ok=True)
OUT.write_text(doc, encoding="utf-8", newline="\n")
print("entries", len(entries), "problems", problem_total, "code", counts["code"], "drift", len(drift))
print("zones", counts)
print("wrote", OUT, "%.1f MB" % (OUT.stat().st_size / 1048576))
