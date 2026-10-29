# -*- coding: utf-8 -*-
"""R428 生成《卡牌总表》：按 职业 → 稀有度 两级分组，带数值与效果。
唯一数据源 = cards.json（不硬编码任何数值/名字）。
输出 = release/卡牌总表_R428.md（UTF-8 无 BOM，LF）。
"""
import json
import sys
import collections

sys.stdout.reconfigure(encoding="utf-8")

SRC = "cards.json"
OUT = "release/卡牌总表_R429.md"

RARITY = ["普通", "稀有", "史诗", "初始", "怪物", "事件", "诅咒"]

CLASS_ORDER = ["森林精魄", "暗影刺客", "机械之心", "", "敌人"]
CLASS_TITLE = {
    "森林精魄": "森林精魄",
    "暗影刺客": "暗影刺客",
    "机械之心": "机械之心",
    "": "公用卡（无职业归属）",
    "敌人": "敌方单位",
}
CLASS_NOTE = {
    "森林精魄": "自然之力：工事与厚血盟友，靠成长与恢复拖进自己的节奏。",
    "暗影刺客": "暗影潜行：低费技能与持续削弱，靠爆发在对方站稳前结束战斗。",
    "机械之心": "拆解重组：0 费素体攒在手里，靠改造养成难以击破的硬块。",
    "": "三职业共用：初始卡、剧情/事件产物、诅咒等，不在任何职业奖励池里单独归属。",
    "敌人": "关卡编成用的敌方单位，玩家不可获取。",
}

d = json.load(open(SRC, encoding="utf-8"))
cards = d["cards"]


def num(v):
    v = v or 0
    return str(v) if v else "—"


def body(c, key):
    """盟友/工事是场上实体：0 也照写 0（0 攻 = 打不了，是信息）；
    技能/效果/场地/诅咒没有这套数值，统一划 —。"""
    if c["kind"] not in ("盟友", "工事"):
        return "—"
    return str(c.get(key) or 0)


def affix_text(c):
    ts = list(c.get("traits") or [])
    af = [a for a in (c.get("affixes") or []) if a not in ts]
    parts = list(ts) + af
    return "、".join(parts) if parts else "—"


def effect_text(c):
    t = (c.get("effect_text") or "").strip()
    if not t:
        return "—"
    return t.replace("\n", " ").replace("|", "／")


lines = []
lines.append("# 卡牌总表（R429）")
lines.append("")
lines.append("数据源 `cards.json`（version %s，共 %d 张）。按**职业 → 稀有度**两级分组，"
             "数值列只对盟友/工事有意义，其余卡留 `—`。" % (d.get("version", "?"), len(cards)))
lines.append("")
lines.append("- **费** = `cost`（打出费用）　**攻/血** = `power` / `health`　"
             "**射程/移速** = `attack_range` / `move_speed`")
lines.append("- **词缀** = `traits` + `affixes` 合并去重；**效果** 原样取 `effect_text`")
lines.append("")
lines.append("## 总览")
lines.append("")
lines.append("| 职业 | 普通 | 稀有 | 史诗 | 初始 | 怪物 | 事件 | 诅咒 | 合计 |")
lines.append("|---|---|---|---|---|---|---|---|---|")
pos = {
    "森林精魄": "森林精魄",
    "暗影刺客": "暗影刺客",
    "机械之心": "机械之心",
    "": "公用",
    "敌人": "敌方",
}
grand = collections.Counter()
for cls in CLASS_ORDER:
    sub = [c for c in cards if (c.get("class") or "") == cls]
    cnt = collections.Counter(c["rarity"] for c in sub)
    grand.update(cnt)
    row = [str(cnt.get(i, 0)) for i in range(7)]
    lines.append("| %s | %s | **%d** |" % (pos[cls], " | ".join(row), len(sub)))
lines.append("| **合计** | %s | **%d** |" % (
    " | ".join(str(grand.get(i, 0)) for i in range(7)), len(cards)))
lines.append("")

for cls in CLASS_ORDER:
    sub = [c for c in cards if (c.get("class") or "") == cls]
    if not sub:
        continue
    lines.append("---")
    lines.append("")
    lines.append("## %s（%d 张）" % (CLASS_TITLE[cls], len(sub)))
    lines.append("")
    lines.append("> " + CLASS_NOTE[cls])
    lines.append("")
    for r in range(7):
        grp = [c for c in sub if c["rarity"] == r]
        if not grp:
            continue
        kinds = collections.Counter(c["kind"] for c in grp)
        ktxt = "、".join("%s %d" % (k, n) for k, n in kinds.most_common())
        lines.append("### %s · %d 张（%s）" % (RARITY[r], len(grp), ktxt))
        lines.append("")
        lines.append("| ID | 名称 | 种类 | 费 | 攻 | 血 | 射程 | 移速 | 词缀 | 效果 |")
        lines.append("|---|---|---|---|---|---|---|---|---|---|")
        for c in sorted(grp, key=lambda x: (x["kind"], x["cost"], x["id"])):
            lines.append("| %d | %s | %s | %d | %s | %s | %s | %s | %s | %s |" % (
                c["id"], c["name"], c["kind"], c.get("cost") or 0,
                body(c, "power"), body(c, "health"),
                body(c, "attack_range"), body(c, "move_speed"),
                affix_text(c), effect_text(c)))
        lines.append("")

text = "\n".join(lines).rstrip() + "\n"
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)

print("WROTE", OUT)
print("cards", len(cards), "lines", text.count("\n"))
print("rarity dist", dict(collections.Counter(c["rarity"] for c in cards)))
print("class dist", dict(collections.Counter((c.get("class") or "<none>") for c in cards)))

# ── 网页版：同一份数据，加筛选/搜索，方便 282 张逐条查 ──
OUT_HTML = "release/卡牌总表_R429.html"
RC = ["#2c2c2a", "#1f5fbf", "#8a30b8", "#1d7a4f", "#7a1f1f", "#a44ad0", "#4e4560"]

payload = []
for c in sorted(cards, key=lambda x: (CLASS_ORDER.index(x.get("class") or ""),
                                      x["rarity"], x["kind"], x["cost"], x["id"])):
    payload.append({
        "id": c["id"], "name": c["name"], "kind": c["kind"],
        "cost": c.get("cost") or 0,
        "p": body(c, "power"), "h": body(c, "health"),
        "r": body(c, "attack_range"), "m": body(c, "move_speed"),
        "rar": c["rarity"], "cls": c.get("class") or "",
        "affix": affix_text(c), "eff": c.get("effect_text") or "",
    })

HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>卡牌总表 · R429</title>
<style>
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:#f5f3ef;color:#232220;display:flex;flex-direction:column;
 height:100vh;overflow:hidden;
 font:14px/1.6 "Microsoft YaHei","PingFang SC",system-ui,sans-serif}
header{padding:22px 26px 14px;background:#fffdfa;border-bottom:1px solid #e2ddd4}
h1{margin:0 0 6px;font-size:20px;letter-spacing:.5px}
.sub{color:#6d6660;font-size:13px}
.bar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;
 padding:12px 26px;background:#fffdfa;border-bottom:1px solid #e2ddd4;flex:none}
label{color:#6d6660;font-size:12px}
select,input{font:inherit;padding:5px 8px;border:1px solid #d6d0c6;border-radius:6px;
 background:#fff;color:#232220}
input{width:190px}
button{font:inherit;padding:5px 12px;border:1px solid #d6d0c6;border-radius:6px;
 background:#fff;cursor:pointer}
button:hover{background:#f2efe9}
.count{margin-left:auto;color:#6d6660;font-size:12px}
.wrap{flex:1;min-height:0;overflow:auto;padding:0 26px 40px}
table{border-collapse:collapse;width:100%;min-width:1240px;background:#fffdfa}
th,td{border-bottom:1px solid #ece7de;padding:7px 9px;text-align:left;vertical-align:top}
thead th{position:sticky;top:0;background:#efeae1;z-index:3;font-weight:600;
 font-size:12px;color:#4a453f;white-space:nowrap;box-shadow:0 1px 0 #ddd6c9}
/* 前 5 列（ID/名称/职业/稀有度/种类）一律不折行，否则「场地」会被压成竖排 */
tbody td:nth-child(-n+5){white-space:nowrap}
tbody td:nth-child(2){font-weight:600}
td.num{text-align:center;font-variant-numeric:tabular-nums;white-space:nowrap}
td.id{color:#8d857c;font-variant-numeric:tabular-nums;white-space:nowrap}
td.eff{color:#3b3733;min-width:380px}
td.aff{color:#6d6660;font-size:12.5px;min-width:130px}
.tag{display:inline-block;padding:1px 7px;border-radius:9px;font-size:11.5px;
 line-height:1.7;color:#fff;white-space:nowrap}
tfoot td{background:#efeae1;font-weight:600}
</style></head><body>
<header>
<h1>卡牌总表 · R429</h1>
<div class="sub">数据源 cards.json　共 __N__ 张　按职业 → 稀有度排序　
数值列仅盟友/工事有实体数值，其余为 —</div>
</header>
<div class="bar">
 <label>职业</label>
 <select id="fcls"><option value="">全部</option>__CLSOPTS__</select>
 <label>稀有度</label>
 <select id="frar"><option value="">全部</option>__RAROPTS__</select>
 <label>种类</label>
 <select id="fkind"><option value="">全部</option>__KINDOPTS__</select>
 <input id="q" placeholder="搜名称 / ID / 效果关键词">
 <button id="reset">重置</button>
 <span class="count" id="cnt"></span>
</div>
<div class="wrap">
<table><thead><tr>
<th>ID</th><th>名称</th><th>职业</th><th>稀有度</th><th>种类</th>
<th>费</th><th>攻</th><th>血</th><th>射程</th><th>移速</th><th>词缀</th><th>效果</th>
</tr></thead><tbody id="tb"></tbody><tfoot><tr>
<td colspan="12" id="foot"></td></tr></tfoot></table>
</div>
<script>
const DATA = __DATA__;
const RARN = __RARN__;
const RC = __RC__;
const CLSN = {"":"公用","森林精魄":"森林精魄","暗影刺客":"暗影刺客","机械之心":"机械之心","敌人":"敌方"};
const tb = document.getElementById('tb');
function esc(s){return String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
function rich(s){ // 效果原文里的 **强调** 转粗体，其余转义
 return esc(s).replace(/\\*\\*(.+?)\\*\\*/g,'<b>$1</b>');
}
function row(c){
 const t=document.createElement('tr');
 t.dataset.cls=c.cls; t.dataset.rar=c.rar; t.dataset.kind=c.kind;
 t.dataset.s=(c.name+' '+c.id+' '+c.eff+' '+c.affix).toLowerCase();
 t.innerHTML='<td class="id">'+c.id+'</td>'
 +'<td><b>'+esc(c.name)+'</b></td>'
 +'<td>'+(CLSN[c.cls]||'公用')+'</td>'
 +'<td><span class="tag" style="background:'+RC[c.rar]+'">'+RARN[c.rar]+'</span></td>'
 +'<td>'+esc(c.kind)+'</td>'
 +'<td class="num">'+c.cost+'</td>'
 +'<td class="num">'+c.p+'</td><td class="num">'+c.h+'</td>'
 +'<td class="num">'+c.r+'</td><td class="num">'+c.m+'</td>'
 +'<td class="aff">'+esc(c.affix)+'</td>'
 +'<td class="eff">'+rich(c.eff || '—')+'</td>';
 return t;
}
DATA.forEach(c=>tb.appendChild(row(c)));
const fcls=document.getElementById('fcls'), frar=document.getElementById('frar'),
      fkind=document.getElementById('fkind'), q=document.getElementById('q'),
      cnt=document.getElementById('cnt'), foot=document.getElementById('foot');
function apply(){
 const vc=fcls.value, vr=frar.value, vk=fkind.value, s=q.value.trim().toLowerCase();
 let n=0;
 for(const tr of tb.children){
  const ok = (!vc||tr.dataset.cls===vc) && (!vr||tr.dataset.rar===vr)
          && (!vk||tr.dataset.kind===vk) && (!s||tr.dataset.s.includes(s));
  tr.style.display = ok?'':'none';
  if(ok) n++;
 }
 cnt.textContent='显示 '+n+' / '+DATA.length+' 张';
 foot.textContent='当前筛选：'+n+' 张　（总计 '+DATA.length+' 张）';
}
[fcls,frar,fkind].forEach(e=>e.addEventListener('change',apply));
q.addEventListener('input',apply);
document.getElementById('reset').onclick=()=>{fcls.value='';frar.value='';fkind.value='';q.value='';apply();};
apply();
</script></body></html>
"""

cls_opts = "".join('<option value="%s">%s</option>' % (k, pos[k])
                   for k in CLASS_ORDER if k)
rar_opts = "".join('<option value="%d">%d · %s</option>' % (i, i, RARITY[i])
                   for i in range(7))
kinds = sorted({c["kind"] for c in cards})
kind_opts = "".join('<option value="%s">%s</option>' % (k, k) for k in kinds)

html = (HTML.replace("__N__", str(len(cards)))
            .replace("__CLSOPTS__", cls_opts)
            .replace("__RAROPTS__", rar_opts)
            .replace("__KINDOPTS__", kind_opts)
            .replace("__DATA__", json.dumps(payload, ensure_ascii=False))
            .replace("__RARN__", json.dumps(RARITY, ensure_ascii=False))
            .replace("__RC__", json.dumps(RC)))

with open(OUT_HTML, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print("WROTE", OUT_HTML, len(html.encode("utf-8")), "bytes")

