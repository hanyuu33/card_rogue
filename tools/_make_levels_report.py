#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 tools/_levels_report.json 渲染成一份自包含 HTML 报告。

数据来源（只读）：
  tools/_dump_levels_report.gd  →  tools/_levels_report.json
本脚本不改游戏数据，只产出 reports/ 下的报告文件。
"""
import io
import json
import os
import html
from collections import OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "_levels_report.json")
OUT_DIR = os.path.join(ROOT, "reports")
OUT = os.path.join(OUT_DIR, "战斗关卡分布报告_R855.html")

TIER_ORDER = [0, 1, 2, 3, 4]
TIER_LABEL = {0: "普通敌人 · 简单", 1: "普通敌人 · 困难",
              2: "精英敌人 · 简单", 3: "精英敌人 · 困难", 4: "Boss"}
TIER_SHORT = {0: "普通简单", 1: "普通困难", 2: "精英简单", 3: "精英困难", 4: "Boss"}
TIER_KEY = {0: "t0", 1: "t1", 2: "t2", 3: "t3", 4: "t4"}

AFFIX_DESC = OrderedDict([
    ("疾行", "一回合可以行动两次。"),
    ("嘲讽", "可以攻击到这张卡的单位只能攻击这张卡。"),
    ("死亡", "被破坏时生效（具体内容看卡面）。"),
    ("幻影", "打出后手牌里多一张自身的短暂复制，回合结束消失。"),
    ("护盾", "第一次受到的伤害为 0（一次性）。"),
    ("次元", "使用后 / 离开战场即消失，不进弃牌区。"),
    ("超负荷", "生命降到 0 以下不会立即死亡，以负血继续存活。"),
    ("交换", "可放置在已有友方单位的格子上，把原单位顶回手。"),
])


def esc(s):
    return html.escape(str(s if s is not None else ""))


def load():
    with io.open(SRC, encoding="utf-8") as f:
        return json.load(f)


def unit_totals(lv):
    return sum(int(u["atk"]) for u in lv["units"]), sum(int(u["hp"]) for u in lv["units"])


def agg(pool):
    if not pool:
        return None
    atk = [sum(int(u["atk"]) for u in l["units"]) for l in pool]
    hp = [sum(int(u["hp"]) for u in l["units"]) for l in pool]
    return {
        "n": len(pool),
        "atk_min": min(atk), "atk_max": max(atk), "atk_avg": sum(atk) / len(atk),
        "hp_min": min(hp), "hp_max": max(hp), "hp_avg": sum(hp) / len(hp),
        "enemy_hp": sorted({int(l["enemy_hp"]) for l in pool}),
        "turn_limit": sorted({int(l["turn_limit"]) for l in pool}),
    }


def badge(tier):
    return '<span class="badge %s">%s</span>' % (TIER_KEY[tier], esc(TIER_SHORT[tier]))


def card_chips(card):
    out = []
    for t in (card.get("traits") or []):
        out.append('<span class="chip">%s</span>' % esc(t))
    for a in (card.get("affixes") or []):
        out.append('<span class="chip affix" title="%s">%s</span>'
                   % (esc(AFFIX_DESC.get(a, "")), esc(a)))
    return "".join(out)


def unit_rows(lv):
    rows = []
    for u in lv["units"]:
        c = u.get("card") or {}
        missing = c.get("missing")
        name = c.get("name") if not missing else u["name"]
        atk, hp = int(u["atk"]), int(u["hp"])
        rng, spd = int(u["range"]), int(u["speed"])
        note = ""
        if not missing:
            if int(c.get("attack_range", rng)) != rng:
                note = '<span class="note">本关程 %d（卡库 %d）</span>' % (rng, int(c["attack_range"]))
            if int(c.get("power", atk)) != atk:
                note += '<span class="note">本关攻 %d（卡库 %d）</span>' % (atk, int(c["power"]))
            if int(c.get("health", hp)) != hp:
                note += '<span class="note">本关血 %d（卡库 %d）</span>' % (hp, int(c["health"]))
        fx = esc(c.get("effect_text", "")).replace("\n", "<br>")
        if not fx:
            fx = '<span class="muted">（无额外效果文本）</span>'
        rows.append(
            '<tr class="u-main"><td class="mono">(%d,%d)</td>'
            '<td><b>%s</b> <span class="cid mono">#%d</span>%s<br>%s</td>'
            '<td class="num">%d</td><td class="num">%d</td>'
            '<td class="num">%d</td><td class="num">%d</td></tr>'
            '<tr class="u-fx"><td></td><td colspan="5">%s</td></tr>'
            % (u["pos"][0], u["pos"][1], esc(name), int(u["id"]), note,
               card_chips(c) if not missing else "", atk, hp, rng, spd, fx)
        )
    return "".join(rows)


def effect_block(title, cards, cls):
    if not cards:
        return ""
    items = []
    for c in cards:
        fx = esc(c.get("effect_text", "")).replace("\n", "<br>") or '<span class="muted">（无效果文本）</span>'
        meta = "%s · %s" % (esc(c.get("kind", "")), esc(c.get("rarity_name", "")))
        items.append(
            '<div class="fx-item"><div class="fx-head"><b>%s</b> '
            '<span class="cid mono">#%d</span> <span class="muted">%s</span></div>'
            '<div class="fx-text">%s</div></div>'
            % (esc(c.get("name", "")), int(c.get("id", 0)), meta, fx)
        )
    return ('<div class="fx %s"><div class="fx-title">%s</div>%s</div>'
            % (cls, esc(title), "".join(items)))


def rng_text(lo, hi, avg):
    if lo == hi:
        return "%d" % lo
    return "%d~%d <span class='muted'>均 %.1f</span>" % (lo, hi, avg)


def level_card(lv, extra=False):
    atk, hp = unit_totals(lv)
    meta = [
        ("敌总血条", "%d <span class='muted'>（基础 %d）</span>" % (lv["enemy_hp"], lv["enemy_hp_base"])),
        ("玩家生命", str(lv["player_hp"])),
        ("回合限制", "不限" if lv["turn_limit"] < 0 else str(lv["turn_limit"])),
        ("起始手牌", str(lv["starting_hand"])),
        ("敌方 AI", "是" if lv["enemy_ai"] else "否"),
        ("洗牌", "是" if lv["shuffle"] else "否"),
        ("单位数", str(len(lv["units"]))),
        ("攻击合计", str(atk)),
        ("生命合计", str(hp)),
    ]
    meta_html = "".join(
        '<div class="m"><span class="mk">%s</span><span class="mv">%s</span></div>' % (esc(k), v)
        for k, v in meta)
    return (
        '<article class="lv" data-layer="%d" data-tier="%d" data-name="%s %s">'
        '<div class="lv-head"><div class="lv-title">%s<code>%s</code></div>'
        '<div class="lv-tags">%s<span class="tag">第 %d 层</span>%s</div></div>'
        '<div class="meta">%s</div>'
        '<table class="units"><thead><tr><th>格位</th><th>单位 / 卡牌</th>'
        '<th>攻</th><th>血</th><th>程</th><th>速</th></tr></thead><tbody>%s</tbody></table>'
        '%s%s</article>'
        % (lv["layer"], lv["tier"], esc(lv["name"]), esc(lv["key"]),
           esc(lv["name"]), esc(lv["key"]), badge(lv["tier"]), lv["layer"],
           ('<span class="tag event">仅事件</span>' if (extra or lv.get("event_only")) else ""),
           meta_html, unit_rows(lv),
           effect_block("关卡效果卡（整场生效）", lv["effects"], "fx-level"),
           effect_block("胜利奖励卡", lv["rewards"], "fx-reward"))
    )


def layer_section(layer, levels, title, subtitle):
    parts = ['<section id="layer%d" class="layer">' % layer,
             '<div class="sec-head"><h2>%s</h2><p>%s</p></div>' % (esc(title), subtitle)]
    for tier in TIER_ORDER:
        pool = [l for l in levels if l["layer"] == layer and l["tier"] == tier]
        if not pool:
            continue
        a = agg(pool)
        summary = "×%d 关 · 单位攻击合计 %s · 单位生命合计 %s" % (
            a["n"], rng_text(a["atk_min"], a["atk_max"], a["atk_avg"]),
            rng_text(a["hp_min"], a["hp_max"], a["hp_avg"]))
        parts.append(
            '<div class="tier-group" data-tier="%d"><div class="tier-head">%s'
            '<span class="tier-sub">%s</span></div>' % (tier, badge(tier), summary))
        for lv in pool:
            parts.append(level_card(lv))
        parts.append("</div>")
    parts.append("</section>")
    return "".join(parts)


def overview_table(levels):
    head = ('<table class="ov"><thead><tr><th>层</th><th>档位</th><th>关数</th>'
            '<th>敌总血条</th><th>单位攻击合计</th><th>单位生命合计</th></tr></thead><tbody>')
    rows = []
    for layer in (1, 2, 3):
        for tier in TIER_ORDER:
            pool = [l for l in levels if l["layer"] == layer and l["tier"] == tier]
            if not pool:
                continue
            a = agg(pool)
            hp_rng = ("%d" % a["enemy_hp"][0] if len(a["enemy_hp"]) == 1
                      else "%d~%d" % (a["enemy_hp"][0], a["enemy_hp"][-1]))
            rows.append(
                '<tr><td class="mono">L%d</td><td>%s</td><td class="num">%d</td>'
                '<td class="num">%s</td>'
                '<td class="num">%s</td><td class="num">%s</td></tr>'
                % (layer, badge(tier), a["n"], hp_rng,
                   rng_text(a["atk_min"], a["atk_max"], a["atk_avg"]),
                   rng_text(a["hp_min"], a["hp_max"], a["hp_avg"])))
    return head + "".join(rows) + "</tbody></table>"


def gallery(levels):
    seen = OrderedDict()
    for lv in levels:
        for u in lv["units"]:
            c = u.get("card") or {}
            key = int(u["id"])
            if key not in seen:
                seen[key] = {"card": c, "lv": [], "atk": int(u["atk"]), "hp": int(u["hp"]),
                             "rng": int(u["range"]), "spd": int(u["speed"])}
            if lv["name"] not in seen[key]["lv"]:
                seen[key]["lv"].append(lv["name"])
    items = []
    for cid, info in sorted(seen.items(), key=lambda kv: (-len(kv[1]["lv"]), kv[0])):
        c = info["card"]
        fx = esc(c.get("effect_text", "")).replace("\n", "<br>") or '<span class="muted">（无额外效果文本）</span>'
        items.append(
            '<div class="gcard" data-name="%s">'
            '<div class="g-head"><b>%s</b><span class="cid mono">#%d</span></div>'
            '<div class="g-meta">%s · %s · %s</div>'
            '<div class="g-stats"><span>攻 <b>%d</b></span><span>血 <b>%d</b></span>'
            '<span>程 <b>%d</b></span><span>速 <b>%d</b></span></div>'
            '<div class="g-fx">%s</div>'
            '<div class="g-chips">%s</div>'
            '<div class="g-where muted">出场 %d 关：%s</div></div>'
            % (esc(c.get("name", "")), esc(c.get("name", "")), cid,
               esc(c.get("kind", "")), esc(c.get("class", "")),
               esc(c.get("rarity_name", "")),
               info["atk"], info["hp"], info["rng"], info["spd"], fx,
               card_chips(c), len(info["lv"]), esc("、".join(info["lv"])))
        )
    return "".join(items), len(seen)


CSS = """
:root{
  --bg:#f6f1e6; --paper:#fffdf9; --ink:#2e2620; --ink2:#6f5f4e; --line:#e4d9c6;
  --gold:#a8763e; --deep:#241d17; --t0:#6b8f71; --t0b:#eaf1ea;
  --t1:#4a4a48; --t1b:#ecebe8; --t2:#b8791f; --t2b:#fbf0dc;
  --t3:#9c3b22; --t3b:#f8e6df; --t4:#6b3f8f; --t4b:#f1e9f7;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font:14px/1.65 "Microsoft YaHei","Segoe UI",system-ui,sans-serif;}
code,.mono{font-family:"Cascadia Mono",Consolas,monospace}
header{background:var(--deep);color:#f3e9d8;padding:36px 28px 28px}
header .wrap{max-width:1120px;margin:0 auto}
header h1{margin:0 0 6px;font:500 27px/1.3 Georgia,"Songti SC",serif;letter-spacing:.5px}
header .sub{color:#c8b393;font-size:13px}
header .sub b{color:#e8c98d;font-weight:500}
.stat-row{display:flex;flex-wrap:wrap;gap:10px;margin-top:22px}
.stat{background:#312820;border:1px solid #4a3d31;border-radius:10px;padding:10px 16px;min-width:120px}
.stat .k{font-size:11px;color:#a38f76;letter-spacing:.4px}
.stat .v{font-size:21px;font-weight:500;color:#f0dfc2;line-height:1.2}
nav{position:sticky;top:0;z-index:9;background:rgba(246,241,230,.96);
  border-bottom:1px solid var(--line);backdrop-filter:blur(4px)}
nav .wrap{max-width:1120px;margin:0 auto;display:flex;gap:4px;flex-wrap:wrap;padding:8px 28px}
nav a{color:var(--ink2);text-decoration:none;font-size:13px;padding:6px 10px;border-radius:6px}
nav a:hover{background:#ece3d3;color:var(--ink)}
main{max-width:1120px;margin:0 auto;padding:8px 28px 60px}
section{margin-top:44px}
.sec-head h2{font:500 21px/1.3 Georgia,"Songti SC",serif;margin:0 0 4px}
.sec-head p{margin:0 0 18px;color:var(--ink2);font-size:13px}
h3{font:500 16px/1.4 Georgia,"Songti SC",serif;margin:26px 0 10px}
.card{background:var(--paper);border:1px solid var(--line);border-radius:12px;padding:16px 18px}
.badge{display:inline-block;padding:1px 8px;border-radius:20px;font-size:11.5px;
  font-weight:500;white-space:nowrap;border:1px solid transparent}
.badge.t0{background:var(--t0b);color:var(--t0);border-color:#cfe0d1}
.badge.t1{background:var(--t1b);color:var(--t1);border-color:#d8d6d0}
.badge.t2{background:var(--t2b);color:var(--t2);border-color:#efd9b4}
.badge.t3{background:var(--t3b);color:var(--t3);border-color:#eec8bc}
.badge.t4{background:var(--t4b);color:var(--t4);border-color:#ddcdea}
table{width:100%;border-collapse:collapse;font-size:13px}
th{text-align:left;font-weight:500;color:var(--ink2);font-size:12px;
  border-bottom:1px solid var(--line);padding:7px 8px;background:#faf6ee}
td{padding:7px 8px;border-bottom:1px solid #f0e8da;vertical-align:top}
td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}
.ov th:nth-child(n+3),.ov td:nth-child(n+3){text-align:right}
.muted{color:#a2947f}
.note{display:inline-block;margin-left:6px;font-size:11px;color:var(--t3);
  background:var(--t3b);padding:0 6px;border-radius:4px}
.toolbar{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:8px 0 18px}
input[type=search]{flex:1 1 240px;min-width:200px;padding:8px 12px;border:1px solid var(--line);
  border-radius:8px;background:var(--paper);color:var(--ink);font-size:13px}
.chips{display:flex;gap:6px;flex-wrap:wrap}
.chipbtn{border:1px solid var(--line);background:var(--paper);color:var(--ink2);
  font-size:12px;padding:5px 11px;border-radius:20px;cursor:pointer}
.chipbtn[aria-pressed=true]{background:var(--deep);color:#f0dfc2;border-color:var(--deep)}
.btn{border:1px solid var(--line);background:var(--paper);color:var(--ink2);
  font-size:12px;padding:6px 12px;border-radius:8px;cursor:pointer}
.layer{scroll-margin-top:56px}
.tier-group{margin:14px 0 30px}
.tier-head{display:flex;align-items:baseline;gap:10px;margin:0 0 10px;
  border-left:3px solid var(--gold);padding-left:10px}
.tier-sub{font-size:12px;color:var(--ink2)}
.lv{background:var(--paper);border:1px solid var(--line);border-radius:12px;
  padding:16px 18px;margin-bottom:14px}
.lv-head{display:flex;justify-content:space-between;align-items:flex-start;gap:12px;flex-wrap:wrap}
.lv-title{font:500 17px/1.3 Georgia,"Songti SC",serif}
.lv-title code{font-size:11.5px;color:#a2947f;margin-left:8px;font-weight:400}
.lv-tags{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.tag{font-size:11px;color:var(--ink2);background:#f0e9dc;border-radius:4px;padding:1px 7px}
.tag.event{background:#eae4f5;color:#6b3f8f}
.meta{display:flex;flex-wrap:wrap;gap:6px 18px;margin:12px 0 14px;
  padding:10px 12px;background:#faf6ee;border-radius:8px}
.m{display:flex;gap:6px;align-items:baseline;font-size:12.5px}
.mk{color:var(--ink2)}
.mv{font-weight:500;font-variant-numeric:tabular-nums}
.units{margin-top:4px}
.units th{background:transparent;border-bottom:1px solid var(--line)}
.units th:first-child,.units td:first-child{width:76px}
.units th:nth-child(n+3),.units td:nth-child(n+3){width:58px;text-align:right}
.u-main td{border-bottom:none;padding-bottom:2px}
.u-fx td{border-bottom:1px solid #f0e8da;padding-top:0;padding-bottom:9px;font-size:12.5px;color:#5d5040}
.cid{font-size:11px;color:#ad9f8b}
.chip{display:inline-block;font-size:11px;padding:0 6px;margin:1px 4px 1px 0;
  border-radius:4px;background:#efe8da;color:#6f5f4e}
.chip.affix{background:#2e2620;color:#f0dfc2}
.fx{margin-top:14px;padding:12px 14px;border-radius:10px;border-left:3px solid var(--gold);
  background:#fdf8ef}
.fx-reward{border-left-color:#4f7a4a;background:#f4f8f1}
.fx-title{font-size:12px;color:var(--ink2);letter-spacing:.5px;margin-bottom:8px}
.fx-item+.fx-item{margin-top:10px;padding-top:10px;border-top:1px dashed var(--line)}
.fx-text{margin-top:3px;font-size:13px}
.gal{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}
.gcard{background:var(--paper);border:1px solid var(--line);border-radius:10px;padding:12px 14px}
.g-head{display:flex;justify-content:space-between;gap:8px;align-items:baseline}
.g-meta{font-size:11.5px;color:var(--ink2);margin:2px 0 8px}
.g-stats{display:flex;gap:14px;font-size:12.5px;font-variant-numeric:tabular-nums;
  padding:6px 0;border-top:1px solid #f0e8da;border-bottom:1px solid #f0e8da}
.g-fx{font-size:12.5px;margin:8px 0 6px;color:#4b4034}
.g-chips{margin-bottom:6px}
.g-where{font-size:11px;line-height:1.5}
footer{max-width:1120px;margin:0 auto;padding:24px 28px 60px;color:var(--ink2);font-size:12px;
  border-top:1px solid var(--line)}
.hidden{display:none!important}
@media (max-width:640px){
  header,main,nav .wrap,footer{padding-left:16px;padding-right:16px}
  .meta{gap:6px 12px}
}
"""

JS = """
const lvs=[...document.querySelectorAll('.lv')];
const q=document.getElementById('q');
const btns=[...document.querySelectorAll('.chipbtn[data-tier]')];
const active=new Set();
function apply(){
  const s=(q.value||'').trim().toLowerCase();
  lvs.forEach(el=>{
    const okT=active.size===0||active.has(el.dataset.tier);
    const okS=!s||el.dataset.name.toLowerCase().includes(s)||el.textContent.toLowerCase().includes(s);
    el.classList.toggle('hidden',!(okT&&okS));
  });
  document.querySelectorAll('.tier-group').forEach(g=>{
    const any=[...g.querySelectorAll('.lv')].some(e=>!e.classList.contains('hidden'));
    g.classList.toggle('hidden',!any);
  });
}
btns.forEach(b=>b.addEventListener('click',()=>{
  const t=b.dataset.tier;
  if(active.has(t)){active.delete(t);b.setAttribute('aria-pressed','false');}
  else{active.add(t);b.setAttribute('aria-pressed','true');}
  apply();
}));
q.addEventListener('input',apply);
document.getElementById('collapse').addEventListener('click',()=>{
  const on=document.body.classList.toggle('compact');
  document.querySelectorAll('.units,.fx').forEach(e=>e.classList.toggle('hidden',on));
  document.getElementById('collapse').textContent=on?'展开单位与效果':'收起单位与效果';
});
"""


def main():
    data = load()
    levels = data["levels"]
    extra = data["extra_levels"]
    all_lv = levels + extra
    gal_html, gal_n = gallery(all_lv)
    total_units = sum(len(l["units"]) for l in levels)
    fx_levels = sum(1 for l in levels if l["effects"])

    stats = [
        ("关卡总数", "%d <span style='font-size:13px;color:#c8b393'>+1 事件关</span>" % len(levels)),
        ("敌方单位卡", str(gal_n)),
        ("有关卡效果卡", "%d 关" % fx_levels),
        ("地图层数", "3"),
    ]
    stat_html = "".join(
        '<div class="stat"><div class="k">%s</div><div class="v">%s</div></div>' % (esc(k), v)
        for k, v in stats)

    rules = """
<div class="card">
<h3 style="margin-top:0">玩家遇到哪一档，由两条进度判据决定</h3>
<table><thead><tr><th>节点</th><th>取哪一档</th><th>判据</th></tr></thead><tbody>
<tr><td>普通战斗</td><td>普通简单 / 普通困难</td>
<td>本局累计胜场 <b>&lt; 2</b> → 简单；<b>≥ 2</b> → 困难。跨层累计，所以只有第一层开头两场是简单，第二层起全困难</td></tr>
<tr><td>精英战斗</td><td>精英简单 / 精英困难</td>
<td>进房<b>扣完巧克力后</b> ≤ 5 → 困难（强）；&gt; 5 → 简单（弱）。即本层走到第 7 个房间起才会遇到强精英（难度 8 档 11 块 → 第 6 个起）</td></tr>
<tr><td>Boss</td><td>本层 Boss 池</td>
<td>开局摇一次并写入存档，地图名牌与实际进入是同一只</td></tr>
<tr><td>第三层精英</td><td>固定抽第二层「精英困难」5 关</td>
<td>直道那一格是 Boss 前最后一战，不吃巧克力强弱判定</td></tr>
</tbody></table>
<p class="muted" style="margin:12px 0 0;font-size:12.5px">
敌总血条恒定为「普通 60 / 精英 80 / Boss 100」（<code>enemy_hp_of()</code>：基础 30 + 精英 10 / Boss 20，整体 ×2）；真正的层间强度爬升在<b>场上单位</b>的生命上。</p>
</div>
"""

    diff_table = """
<table class="ov"><thead><tr><th>难度档</th><th>战斗侧影响</th></tr></thead><tbody>
<tr><td class="mono">≥3</td><td>敌人生命 +10%（向上取整）</td></tr>
<tr><td class="mono">≥6</td><td>敌人攻击 +1</td></tr>
<tr><td class="mono">≥8</td><td>每层巧克力 12 → 11：强精英门槛从第 7 格提前到第 6 格</td></tr>
<tr><td class="mono">≥9</td><td>玩家最大生命 ×80%</td></tr>
<tr><td class="mono">≥10</td><td>精英出现概率 ×1.3（战斗场次里精英占比升高）</td></tr>
</tbody></table>
"""

    affix_table = "".join(
        '<tr><td><span class="chip affix">%s</span></td><td>%s</td></tr>' % (esc(k), esc(v))
        for k, v in AFFIX_DESC.items())

    l1 = [l for l in levels if l["layer"] == 1]
    l2 = [l for l in levels if l["layer"] == 2]
    l3 = [l for l in levels if l["layer"] == 3]

    body = []
    body.append("""<header><div class="wrap">
<h1>战斗关卡分布报告</h1>
<div class="sub">card_rogue · DuckCardsRogue · 基线 <b>R855b</b> · 数据由引擎导出 ·
生成于 <b>%s</b></div>
<div class="stat-row">%s</div>
</div></header>""" % (esc(data.get("generated_at", "")), stat_html))

    body.append("""<nav><div class="wrap">
<a href="#rules">取档规则</a><a href="#overview">总览</a><a href="#layer1">第一层</a>
<a href="#layer2">第二层</a><a href="#layer3">第三层</a><a href="#gallery">敌方卡图鉴</a>
<a href="#appendix">附录</a></div></nav>""")

    body.append('<main>')
    body.append('<section id="rules"><div class="sec-head"><h2>取档规则</h2>'
                '<p>战斗难度不是按「层」切，而是按本局进度切 —— 下面的表决定了每一次进战斗到底打哪一档。</p></div>'
                + rules + '</section>')

    body.append('<section id="overview"><div class="sec-head"><h2>分层 × 分档总览</h2>'
                '<p>共 %d 关。单位攻击 / 生命合计是「场上单位」的加总，不含敌总血条。</p></div>%s</section>'
                % (len(levels), overview_table(levels)))

    body.append('<section id="detail"><div class="sec-head"><h2>详细编成</h2>'
                '<p>下面逐关列出敌方单位、卡面效果与关卡效果卡。可用搜索框按关名 / 卡名 / 效果文本过滤，'
                '也可按档位筛选。</p></div>'
                '<div class="toolbar"><input id="q" type="search" '
                'placeholder="搜索关卡名 / 卡名 / 效果文本…" aria-label="搜索关卡">'
                '<div class="chips">'
                '<button class="chipbtn" data-tier="0" aria-pressed="false">普通简单</button>'
                '<button class="chipbtn" data-tier="1" aria-pressed="false">普通困难</button>'
                '<button class="chipbtn" data-tier="2" aria-pressed="false">精英简单</button>'
                '<button class="chipbtn" data-tier="3" aria-pressed="false">精英困难</button>'
                '<button class="chipbtn" data-tier="4" aria-pressed="false">Boss</button>'
                '</div><button class="btn" id="collapse">收起单位与效果</button></div></section>')

    body.append(layer_section(1, levels, "第一层",
                              "18 关：普通简单 4 / 普通困难 4 / 精英简单 4 / 精英困难 3 / Boss 3。"
                              "鸭子骑士团的入门战场，单位血量整体在 51~180 之间。"))
    body.append(layer_section(2, levels, "第二层",
                              "21 关：普通简单 4 / 普通困难 6 / 精英简单 3 / 精英困难 5 / Boss 3。"
                              "同一档位的单位血量约为第一层的 1.5~2 倍，是真正的强度台阶。"))
    body.append(layer_section(3, levels, "第三层",
                              "地图是一字直道：起点 → 精英 → 商店 → 篝火 → Boss。"
                              "本层唯一的自有 Boss 是「启示者」；直道上的精英固定从第二层「精英困难」池中抽。"))
    body.append('<div class="tier-group"><div class="tier-head"><span class="badge t2">事件专属</span>'
                '<span class="tier-sub">「洞穴」事件选「探索」才进入，不在地图任何池子里</span></div>'
                + level_card(extra[0], extra=True) + '</div>')

    body.append('<section id="gallery"><div class="sec-head"><h2>敌方单位卡图鉴</h2>'
                '<p>去重后共 %d 张，按出场关卡数排序。卡面数值取自卡库；「本关改写」指编成给了单独加成。</p>'
                '</div><div class="gal">%s</div></section>' % (gal_n, gal_html))

    body.append('<section id="appendix"><div class="sec-head"><h2>附录</h2>'
                '<p>难度档位对战斗的影响、字段含义、数据口径。</p></div>')
    body.append('<h3>难度档位（0~12）的加成</h3>' + diff_table)
    body.append('<h3>字段（affix）含义</h3><div class="card"><table><tbody>%s</tbody></table></div>' % affix_table)
    body.append("""<h3>数据口径</h3><div class="card">
<p style="margin:0 0 8px">· 关卡编成、档位、层归属实时取自 <code>GameLevels.builtin_levels()</code>，导出于
<code>tools/_dump_levels_report.gd</code>。</p>
<p style="margin:0 0 8px">· 敌方单位 / 效果卡 / 奖励卡的卡面与效果文本取自 <code>cards.json</code> 的卡库
（<code>CardRepo.get_card()</code>），不是编成元组里的兜底数值。</p>
<p style="margin:0 0 8px">· 敌总血条 = (基础 + 精英 10 / Boss 20) × 2，即
<code>GameLevels.enemy_hp_of()</code>；「叛逃机械」等个别关的单位生命合计远高于血条，是因为打场上单位不扣血条。</p>
<p style="margin:0">· 本报告共 %d 关、%d 次单位出场、%d 张去重单位卡；事件专属关单独列出，不计入地图池统计。</p>
</div>""" % (len(levels), total_units, gal_n))
    body.append('</section></main>')

    doc = ('<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">'
           '<meta name="viewport" content="width=device-width,initial-scale=1">'
           '<title>card_rogue 战斗关卡分布报告</title><style>%s</style></head><body>%s'
           '<footer>card_rogue · 战斗关卡分布报告 · 数据由引擎探针导出，仅供设计核对使用。'
           '</footer><script>%s</script></body></html>'
           % (CSS, "".join(body), JS))

    if not os.path.isdir(OUT_DIR):
        os.makedirs(OUT_DIR)
    with io.open(OUT, "w", encoding="utf-8") as f:
        f.write(doc)
    print("wrote %s (%d bytes, %d levels, %d unit cards)" % (OUT, len(doc), len(levels), gal_n))


if __name__ == "__main__":
    main()
