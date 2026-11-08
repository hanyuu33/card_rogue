# -*- coding: utf-8 -*-
"""生成《关卡总览》md + html（R524）。

数据源链条（**不硬编码任何数值**）：
    scripts/game_levels.gd  →  tools/dump_levels.gd（Godot headless 导出）
    →  _levels_dump.json  →  本脚本  →  release/关卡总览_R<轮次>.md / .html

用法：
    godot --headless --script tools/dump_levels.gd --path .
    python _leveltable.py
"""
import collections
import json
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")

ROUND = "R524"
SRC_LEVELS = "_levels_dump.json"
SRC_CARDS = "cards.json"
OUT_MD = "release/关卡总览_%s.md" % ROUND
OUT_HTML = "release/关卡总览_%s.html" % ROUND

TIER_ORDER = ["普通敌人-简单", "普通敌人-困难", "精英敌人-简单", "精英敌人-困难", "Boss"]
TIER_COLOR = {
    "普通敌人-简单": "#7a9e6f",
    "普通敌人-困难": "#c08a3e",
    "精英敌人-简单": "#8a6fbf",
    "精英敌人-困难": "#b4534f",
    "Boss": "#4f5b66",
}
LAYER_NAME = {1: "第一层", 2: "第二层", 3: "第三层"}

d = json.load(open(SRC_LEVELS, encoding="utf-8"))
cards = {c["id"]: c["name"] for c in json.load(open(SRC_CARDS, encoding="utf-8"))["cards"]}
levels = d["levels"]
cave = d["cave"]
revenge = d["revenge"]
pools = d["pools"]
K = d["consts"]


def card_name(cid):
    return cards.get(cid, "未知卡 %s" % cid)


def units_text(lvl):
    """[id, 名, 力, 生, 程, 速, 格, (可选加成)] → 「名 力/生/程/速」+ 同款 ×N。"""
    rows = []
    seen = collections.OrderedDict()
    for u in lvl.get("enemy_units") or []:
        name, pw, hp, ar, ms = u[1], u[2], u[3], u[4], u[5]
        extra = ""
        if len(u) > 7 and isinstance(u[7], dict):
            rb = u[7].get("range_bonus")
            if rb:
                extra = "（程 +%d）" % rb
        key = "%s %s/%s/%s/%s%s" % (name, pw, hp, ar, ms, extra)
        seen[key] = seen.get(key, 0) + 1
    for key, n in seen.items():
        rows.append(key + ("×%d" % n if n > 1 else ""))
    return "、".join(rows) if rows else "—"


def effects_text(lvl):
    ids = lvl.get("enemy_effects") or []
    return "、".join("%d %s" % (i, card_name(i)) for i in ids) if ids else "—"


def note_text(lvl):
    parts = []
    if lvl.get("enemy_hp_infinite"):
        parts.append("敌方血条 ∞")
    if lvl.get("win_on_boss"):
        parts.append("击破本体 %s 才胜" % card_name(int(lvl["win_on_boss"])))
    g = lvl.get("enemy_growth") or {}
    if g:
        parts.append("敌方成长：从第 %d 回合起每 %d 回合攻 +%d，上限 +%d" % (
            g.get("start_turn", 2), g.get("period", 2), g.get("inc", 1), g.get("cap", 0)))
    if lvl.get("intro"):
        # 少数关卡（彩蛋 Boss）台词自己就带「」，这里统一只包一层
        q = str(lvl["intro"])
        if q.startswith("「") and q.endswith("」"):
            q = q[1:-1]
        parts.append("台词「%s」" % q)
    if lvl.get("event_only"):
        parts.append("事件专属")
    return "；".join(parts) if parts else "—"


def layer_rows(layer):
    sub = [l for l in levels if int(l.get("layer", 1)) == layer]
    sub.sort(key=lambda x: (TIER_ORDER.index(x["tier_name"]), x["index"]))
    return sub


def md_table(rows, labels=None):
    out = ["| # | 关卡 | 分级 | 敌方 HP | 敌方单位（力/生/程/速） | 敌方效果卡 | 备注 | key |",
           "|---|---|---|---|---|---|---|---|"]
    for i, l in enumerate(rows):
        num = labels[i] if labels else i + 1
        out.append("| %s | %s | %s | %d | %s | %s | %s | `%s` |" % (
            num, l["name"], l["tier_name"], l.get("enemy_hp_final", 0),
            units_text(l), effects_text(l), note_text(l).replace("|", "／"),
            l.get("key", "")))
    return out


# ────────────────────────── md ──────────────────────────
md = []
md.append("# 关卡总览（%s）" % ROUND)
md.append("")
md.append("数据源 `scripts/game_levels.gd`：由 `tools/dump_levels.gd` 导出 JSON，"
          "再由 `_leveltable.py` 排版——**本文件不含任何手写数值**，改关卡后重跑两步即可。")
md.append("")
md.append("`builtin_levels()` 共 **%d** 关；另有 **%d** 关定义在代码里但不进任何抽取池"
          "——事件专属「%s」、彩蛋 Boss「%s」（定义总数 %d）。"
          % (len(levels), 2, cave["name"], revenge["name"], len(levels) + 2))
md.append("")

md.append("## 通用设定")
md.append("")
md.append("%d 关完全一致的部分（逐关重复写没有信息量）：" % len(levels))
md.append("")
md.append("| 项 | 值 |")
md.append("|---|---|")
md.append("| 玩家生命 | **%d** |" % levels[0].get("player_hp", 20))
md.append("| 初始卡组 | `%s` |" % levels[0].get("deck_key", "starter"))
tl = levels[0].get("turn_limit", -1)
md.append("| 回合上限 | %s |" % ("无（`-1`，打到一方倒下为止）" if tl == -1 else tl))
md.append("| 抽牌堆洗牌 | %s |" % ("开局洗牌" if levels[0].get("shuffle") else "不洗"))
md.append("| 敌方 AI | %s |" % ("开启" if levels[0].get("enemy_ai") else "关闭"))
md.append("| 起手额外手牌 | %d 张 |" % levels[0].get("starting_hand", 0))
md.append("")
md.append("**敌方血条口径**：`(关卡基准 enemy_hp + 精英 %d / Boss %d) × %d`"
          "（`GameLevels.enemy_hp_of()`）——下表「敌方 HP」列是**结算后**的那条血条。"
          % (K["elite_hp_bonus"], K["boss_hp_bonus"], K["hp_multiplier"]))
md.append("")
md.append("**敌方单位写法**：`名称 力/生/程/速`，`×N` = 同款几只；格子坐标只在代码里用，表中省略。")
md.append("")

cnt = collections.Counter((l["layer"], l["tier_name"]) for l in levels)
md.append("## 分层总览")
md.append("")
md.append("| 层 | " + " | ".join(TIER_ORDER) + " | 合计 |")
md.append("|---" * (len(TIER_ORDER) + 2) + "|")
for layer in (1, 2, 3):
    row = [str(cnt.get((layer, t), 0) or "—") for t in TIER_ORDER]
    md.append("| %s | %s | **%d** |" % (LAYER_NAME[layer], " | ".join(row),
                                        sum(cnt.get((layer, t), 0) for t in TIER_ORDER)))
tot = [str(sum(cnt.get((ly, t), 0) for ly in (1, 2, 3))) for t in TIER_ORDER]
md.append("| **合计** | %s | **%d** |" % (" | ".join(tot), len(levels)))
md.append("")

for layer in (1, 2, 3):
    rows = layer_rows(layer)
    if not rows:
        continue
    md.append("## %s（%d 关）" % (LAYER_NAME[layer], len(rows)))
    md.append("")
    md += md_table(rows)
    md.append("")

md.append("## 不进抽取池的关（事件专属 / 彩蛋）")
md.append("")
md += md_table([cave, revenge], ["洞", "蛋"])
md.append("")
md.append("> **洞穴**（`cave_level()`，第 37 关）：只有「洞穴」事件选「探索」才进，"
          "地图的普通 / 精英 / Boss 池永远摇不到它；胜利后固定给传说卡「%s」。"
          % card_name(int(cave["reward_cards"][0])))
md.append("")
md.append("> **恶魔鸭（复仇）**（`revenge_boss()`，第 38 关）：刻意**不**进 `builtin_levels()`，"
          "所以它既不出现在调试关卡菜单，也不在 `boss_pool()` 里。触发链是——"
          "**第一层 Boss 摇中「恶魔鸭」→ 50% 置位 → 第二层 Boss 被顶替成这一只**"
          "（`RunState._roll_boss`，`REVENGE_TRIGGER_CHANCE = 0.5`）。"
          "地图上的 Boss 名牌与实际进入读的是同一份结果，所以顶替后地图会直接写「恶魔鸭（复仇）」。")
md.append("")

md.append("## 分层抽取池（地图节点真实会摇到的范围）")
md.append("")
def names(keys, with_key=True):
    by_key = {l.get("key"): l["name"] for l in levels}
    by_key[cave.get("key")] = cave["name"]
    by_key[revenge.get("key")] = revenge["name"]
    if not keys:
        return "—"
    if with_key:
        return "、".join("%s（%s）" % (by_key.get(k, k), k) for k in keys)
    return "、".join(by_key.get(k, k) for k in keys)


content = {1: "[1]", 2: "[2]", 3: "[2, 3]"}
for layer in (1, 2, 3):
    md.append("### %s（内容池 `%s`）" % (LAYER_NAME[layer], content[layer]))
    md.append("")
    if layer == 3:
        md.append("- **普通节点**：5 格直道**不生成普通格** —— `normal_pool(3)` 虽然会摊开第二层的 9 关，"
                  "实际用不到，只作兜底")
    else:
        md.append("- **普通节点**（%d 关）：%s" % (
            len(pools["normal_%d" % layer]), names(pools["normal_%d" % layer])))
    elite_keys = pools["third_elite"] if layer == 3 else pools["elite_%d" % layer]
    if layer == 3:
        md.append("- **精英节点**（%d 关，**固定困难档**）：%s" % (
            len(elite_keys), names(elite_keys)))
    else:
        md.append("- **精英节点**（%d 关）：%s —— 第 1 场精英抽「简单」档、第 2 场起抽「困难」档"
                  "（`elite_wins` 每次换层清零）" % (len(elite_keys), names(elite_keys)))
    boss_all = pools["boss_all_%d" % layer]
    boss_def = pools["boss_default_%d" % layer]
    if len(boss_all) > 1:
        md.append("- **Boss 节点**：共 %d 只，开局摇定 1 只 —— %s"
                  "（确定性兜底 = %s；地图名牌与实际进入都读摇定那份）"
                  % (len(boss_all), names(boss_all), names(boss_def, False)))
    else:
        md.append("- **Boss 节点**：只有 1 只 —— %s" % names(boss_all))
    md.append("")
md.append("> 第三层是 5 格直道：本层自己的关卡只有 Boss「启示者」，普通 / 精英**借第二层**"
          "（`content_layers = [2, 3]`）；精英节点只从第二层的**精英困难** 3 关里抽"
          "（`third_elite_pool()`），不参与 `elite_wins` 档位切换。")
md.append("")

md.append("## 特例清单")
md.append("")
inf = [l["name"] for l in levels if l.get("enemy_hp_infinite")]
win = [(l["name"], card_name(int(l["win_on_boss"]))) for l in levels if l.get("win_on_boss")]
grw = [l["name"] for l in levels if l.get("enemy_growth")]
bg = len([l for l in levels if l.get("key")])
md.append("- **敌方血条 ∞**：%s —— `enemy_hp_infinite`，界面显示 ∞/∞，" % "、".join(inf))
md.append("  「敌方 HP 归零」这条胜利条件失效，唯一胜法是击破本体（`win_on_boss`）：%s。"
          % "、".join("「%s」→ %s" % (n, c) for n, c in win))
md.append("- **敌方成长**（`enemy_growth`，开局从 0 层起、每 2 回合 +1 攻、上限 +4）：%s。"
          % "、".join(grw))
md.append("- **专属战斗背景**：%d/%d 关带 `key`（素材槽位 `assets/ui/battle_bg_<key>.png`），"
          "关卡改名不影响它。" % (bg, len(levels)))
md.append("- **开场台词**（`intro`）：%s。" % "、".join(
    "「%s」" % l["name"] for l in levels if l.get("intro")))

open(OUT_MD, "w", encoding="utf-8", newline="\n").write("\n".join(md) + "\n")
print("WROTE", OUT_MD, os.path.getsize(OUT_MD), "bytes")

# ────────────────────────── html ──────────────────────────
payload = []
for layer in (1, 2, 3):
    for n, l in enumerate(layer_rows(layer), 1):
        payload.append({
            "i": n, "n": l["name"], "ly": int(l.get("layer", 1)),
            "lyname": LAYER_NAME[int(l.get("layer", 1))],
            "t": l["tier_name"], "hp": l.get("enemy_hp_final", 0),
            "u": units_text(l), "e": effects_text(l), "note": note_text(l),
            "k": l.get("key", ""),
        })
cave_row = {
    "i": "洞", "n": cave["name"], "ly": int(cave.get("layer", 2)),
    "lyname": LAYER_NAME[int(cave.get("layer", 2))] + "（事件专属）",
    "t": cave["tier_name"], "hp": cave.get("enemy_hp_final", 0),
    "u": units_text(cave), "e": effects_text(cave), "note": note_text(cave),
    "k": cave.get("key", ""),
}
payload.append(cave_row)

revenge_row = {
    "i": "蛋", "n": revenge["name"], "ly": int(revenge.get("layer", 2)),
    "lyname": LAYER_NAME[int(revenge.get("layer", 2))] + "（彩蛋）",
    "t": revenge["tier_name"], "hp": revenge.get("enemy_hp_final", 0),
    "u": units_text(revenge), "e": effects_text(revenge), "note": note_text(revenge),
    "k": revenge.get("key", ""),
}
payload.append(revenge_row)

HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>关卡总览 · __ROUND__</title>
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
table{border-collapse:collapse;width:100%;min-width:1180px;background:#fffdfa}
th,td{border-bottom:1px solid #ece7de;padding:7px 9px;text-align:left;vertical-align:top}
thead th{position:sticky;top:0;background:#efeae1;z-index:3;font-weight:600;
 font-size:12px;color:#4a453f;white-space:nowrap;box-shadow:0 1px 0 #ddd6c9}
tbody td:nth-child(-n+4){white-space:nowrap}
tbody td:nth-child(2){font-weight:600}
td.num{text-align:center;font-variant-numeric:tabular-nums;white-space:nowrap}
td.id{color:#8d857c;font-variant-numeric:tabular-nums;white-space:nowrap}
td.u{min-width:250px}
td.e{color:#3b3733;min-width:150px}
td.note{color:#6d6660;font-size:12.5px;min-width:190px}
td.key{color:#8d857c;font-size:12px;font-family:Consolas,monospace;white-space:nowrap}
.tag{display:inline-block;padding:1px 7px;border-radius:9px;font-size:11.5px;
 line-height:1.7;color:#fff;white-space:nowrap}
tr.hide{display:none}
footer{padding:10px 26px;color:#8d857c;font-size:12px;background:#fffdfa;
 border-top:1px solid #e2ddd4;flex:none}
</style></head><body>
<header>
  <h1>关卡总览 · __ROUND__</h1>
  <div class="sub">数据源 <code>scripts/game_levels.gd</code> · 共 __N__ 关（含事件专属 1 关）·
    敌方 HP = (基准 + 精英 __EB__ / Boss __BB__) × __MUL__</div>
</header>
<div class="bar">
  <label>层</label><select id="fly"><option value="">全部</option>__LAYOPTS__</select>
  <label>分级</label><select id="ftr"><option value="">全部</option>__TIEROPTS__</select>
  <input id="q" placeholder="搜索关卡名 / 单位 / key">
  <button id="reset">重置</button>
  <span class="count" id="cnt"></span>
</div>
<div class="wrap">
<table>
<thead><tr>
<th>#</th><th>关卡</th><th>层</th><th>分级</th><th>敌方 HP</th>
<th>敌方单位（力/生/程/速）</th><th>敌方效果卡</th><th>备注</th><th>key</th>
</tr></thead>
<tbody id="tb"></tbody>
</table>
</div>
<footer>本文件由 <code>python _leveltable.py</code> 自动生成（先跑 <code>tools/dump_levels.gd</code> 导出 JSON），
请勿手改。</footer>
<script>
const DATA = __DATA__;
const TC = __TIERCOLOR__;
const tb = document.getElementById('tb');
const fly = document.getElementById('fly'), ftr = document.getElementById('ftr'),
      q = document.getElementById('q'), cnt = document.getElementById('cnt');
function esc(s){return String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
function rowIt(d){
  const tr=document.createElement('tr');
  tr.dataset.ly=d.ly; tr.dataset.tr=d.t;
  tr.dataset.search=(d.n+' '+d.u+' '+d.k+' '+d.e+' '+d.note).toLowerCase();
  tr.innerHTML='<td class="id">'+esc(d.i)+'</td>'
    +'<td>'+esc(d.n)+'</td>'
    +'<td>'+esc(d.lyname)+'</td>'
    +'<td><span class="tag" style="background:'+(TC[d.t]||'#888')+'">'+esc(d.t)+'</span></td>'
    +'<td class="num">'+esc(d.hp)+'</td>'
    +'<td class="u">'+esc(d.u)+'</td>'
    +'<td class="e">'+esc(d.e)+'</td>'
    +'<td class="note">'+esc(d.note)+'</td>'
    +'<td class="key">'+esc(d.k)+'</td>';
  return tr;
}
DATA.forEach(d=>tb.appendChild(rowIt(d)));
function apply(){
  const ly=fly.value, tr=ftr.value, kw=q.value.trim().toLowerCase();
  let n=0;
  [...tb.children].forEach(r=>{
    const ok = (!ly || r.dataset.ly===ly) && (!tr || r.dataset.tr===tr)
      && (!kw || r.dataset.search.includes(kw));
    r.classList.toggle('hide', !ok); if(ok) n++;
  });
  cnt.textContent = n + ' / ' + DATA.length + ' 关';
}
[fly,ftr,q].forEach(e=>e.addEventListener('input',apply));
document.getElementById('reset').onclick=()=>{fly.value='';ftr.value='';q.value='';apply();};
apply();
</script></body></html>
"""

layers_present = sorted({p["ly"] for p in payload})
layopts = "".join('<option value="%d">%s</option>' % (ly, LAYER_NAME[ly]) for ly in layers_present)
html = (HTML.replace("__ROUND__", ROUND)
            .replace("__N__", str(len(levels) + 1))
            .replace("__EB__", str(K["elite_hp_bonus"]))
            .replace("__BB__", str(K["boss_hp_bonus"]))
            .replace("__MUL__", str(K["hp_multiplier"]))
            .replace("__LAYOPTS__", layopts)
            .replace("__TIEROPTS__", "".join(
                '<option value="%s">%s</option>' % (t, t) for t in TIER_ORDER))
            .replace("__DATA__", json.dumps(payload, ensure_ascii=False))
            .replace("__TIERCOLOR__", json.dumps(TIER_COLOR, ensure_ascii=False)))

open(OUT_HTML, "w", encoding="utf-8", newline="\n").write(html)
print("WROTE", OUT_HTML, len(html.encode("utf-8")), "bytes")
print("关卡 %d（另有洞穴 / 彩蛋各 1，定义共 %d）· 层分布 %s" % (
    len(levels), len(levels) + 2,
    dict(collections.Counter(l["layer"] for l in levels))))
