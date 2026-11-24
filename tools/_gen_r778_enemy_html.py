# -*- coding: utf-8 -*-
"""R778：把关卡 dump + cards.json 渲染成单文件 HTML 怪物配置表。

排序：层(L1→L3) → 难度(普通简单→普通困难→精英简单→精英困难→Boss) → builtin 顺序。
"""
import io
import json

ROOT = "E:/work/card_rogue/"
cards = {int(c["id"]): c for c in json.load(io.open(ROOT + "cards.json", encoding="utf-8"))["cards"]}

TIER_ORDER = ["普通敌人-简单", "普通敌人-困难", "精英敌人-简单", "精英敌人-困难", "Boss"]
TIER_CLS = {"普通敌人-简单": "t-ne", "普通敌人-困难": "t-nh",
            "精英敌人-简单": "t-ee", "精英敌人-困难": "t-eh", "Boss": "t-boss"}
LAYER_NAME = {"L1": "第一层", "L2": "第二层", "L3": "第三层"}

# 启示者（boss_revelator）：关卡表 `enemy_effects` 只登记第一阶段的「舰炮 9201」，
# 9202 / 9203 由 GameEngine._revelator_enter_phase() 在血量落到 2/3、1/3 时换上。
# 只按关卡表渲染的话，三张阶段卡只能看到一张 —— 所以这张表单独把三段都列出来。
REVELATOR_PHASES = [9201, 9202, 9203]

levels = []
cur = None
for line in io.open(ROOT + "_r778_levels.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("LVL\t"):
        p = line.split("\t")
        cur = {"key": p[1], "name": p[2], "tier": p[3], "layer": p[4],
               "pp": p[5], "ehp": p[6], "turn": p[7], "shuffle": p[8],
               "ai": p[9], "hand": p[10], "effects": p[11], "reward": p[12], "units": []}
        levels.append(cur)
    elif line.startswith("  UNIT\t") and cur is not None:
        p = line.split("\t")
        cur["units"].append({"id": int(p[1]), "name": p[2], "atk": int(p[3]), "hp": int(p[4]),
                             "rng": int(p[5]), "mv": int(p[6]), "cell": p[7]})

assert len(levels) == 41, len(levels)


def num(s):
    return s.split("=", 1)[1] if "=" in s else s


def esc(t):
    return (t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def rich(t):
    """卡面效果文本：** 加粗 → strong，换行 → br。"""
    t = esc(t or "")
    t = t.replace("**", "\u0001")
    parts = t.split("\u0001")
    out = []
    for i, seg in enumerate(parts):
        out.append("<strong>%s</strong>" % seg if i % 2 else seg)
    return "<br>".join("".join(out).split("\n"))


def eff_of(i):
    c = cards.get(i)
    if not c:
        return "(缺卡 %d)" % i
    return rich(c.get("effect_text") or "")


def traits_of(i):
    c = cards.get(i) or {}
    return [t for t in (c.get("traits") or []) if t]


def ids_of(field):
    s = field.replace("effects=", "").replace("reward=", "").strip()
    s = s.strip("[]")
    return [int(x) for x in s.split(",") if x.strip()]


def group_units(units):
    """同名 + 同数值的重复单位合并成一行（坐标全列出来，信息不丢）。"""
    order, mp = [], {}
    for u in units:
        k = (u["id"], u["atk"], u["hp"], u["rng"], u["mv"])
        if k not in mp:
            mp[k] = {"u": u, "cells": []}
            order.append(k)
        mp[k]["cells"].append(u["cell"])
    return [(mp[k]["u"], mp[k]["cells"]) for k in order]


# 按层 → 难度 → 原顺序
by_layer = {}
for lv in levels:
    by_layer.setdefault(lv["layer"], {}).setdefault(lv["tier"], []).append(lv)

uniq_units = len({u["id"] for lv in levels for u in lv["units"]})

H = []
w = H.append
w("""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>怪物配置总表 · R780b</title>
<style>
:root{
  --bg:#120f18; --bg2:#1a1522; --panel:#211a2b; --panel2:#2a2236;
  --line:#3b3149; --line2:#4d4160;
  --text:#ece6f5; --muted:#a294b8; --dim:#7d7090;
  --gold:#e2bc74; --gold-dim:#8d7444;
  --ne:#7fb069; --nh:#d9953f; --ee:#57a8e0; --eh:#b96fd6; --boss:#e05a6b;
}
*{box-sizing:border-box}
body{margin:0;background:
  radial-gradient(1200px 600px at 12% -8%, #2a1f38 0%, transparent 60%),
  radial-gradient(900px 500px at 96% 0%, #241a2e 0%, transparent 55%),
  var(--bg);
  color:var(--text);font:15px/1.65 "Microsoft YaHei","Noto Sans SC",system-ui,sans-serif;
  -webkit-font-smoothing:antialiased}
.wrap{max-width:1240px;margin:0 auto;padding:34px 22px 90px}
header.top{border-bottom:1px solid var(--line);padding-bottom:20px;margin-bottom:22px}
h1{margin:0 0 6px;font-size:27px;letter-spacing:.5px}
h1 .tag{font-size:13px;color:var(--gold);border:1px solid var(--gold-dim);border-radius:999px;
  padding:2px 10px;margin-left:10px;vertical-align:middle;letter-spacing:0}
.sub{color:var(--muted);font-size:13.5px}
.sub code{background:#241c2f;border:1px solid var(--line);border-radius:4px;padding:1px 5px;
  color:#d8cbe8;font-size:12.5px}
.stats{display:flex;flex-wrap:wrap;gap:10px;margin-top:16px}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:8px 14px;
  font-size:13px;color:var(--muted)}
.stat b{color:var(--gold);font-size:16px;margin-right:5px}
.toolbar{position:sticky;top:0;z-index:20;background:rgba(18,15,24,.93);
  backdrop-filter:blur(9px);border-bottom:1px solid var(--line);margin:0 -22px 26px;padding:12px 22px;
  display:flex;flex-wrap:wrap;gap:18px;align-items:center}
.fgroup{display:flex;gap:7px;align-items:center;flex-wrap:wrap}
.fgroup .lb{font-size:12px;color:var(--dim);letter-spacing:1px;margin-right:2px}
button.f{background:transparent;border:1px solid var(--line2);color:var(--muted);border-radius:999px;
  padding:4px 12px;font-size:12.5px;cursor:pointer;font-family:inherit;transition:.15s}
button.f:hover{border-color:var(--gold-dim);color:var(--text)}
button.f.on{background:#33283f;border-color:var(--gold);color:var(--gold)}
.layer-sec{margin:0 0 12px}
h2.layer{font-size:20px;margin:34px 0 4px;padding-left:12px;border-left:3px solid var(--gold);
  letter-spacing:1px}
h2.layer small{color:var(--dim);font-size:12.5px;font-weight:400;margin-left:10px;letter-spacing:0}
h3.tier{font-size:14px;margin:22px 0 10px;color:var(--muted);letter-spacing:2px;
  display:flex;align-items:center;gap:10px}
h3.tier::after{content:"";flex:1;height:1px;background:linear-gradient(90deg,var(--line),transparent)}
h3.tier .dot{width:8px;height:8px;border-radius:50%;display:inline-block}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(560px,1fr));gap:16px;align-items:start}
@media(max-width:680px){.grid{grid-template-columns:1fr}}
.lv{background:linear-gradient(180deg,var(--panel2),var(--panel));border:1px solid var(--line);
  border-radius:13px;overflow:hidden;display:flex;flex-direction:column}
.lv-head{padding:13px 16px 10px;border-bottom:1px solid var(--line);
  background:linear-gradient(180deg,rgba(255,255,255,.03),transparent)}
.lv-title{display:flex;align-items:baseline;gap:9px;flex-wrap:wrap}
.lv-name{font-size:16.5px;font-weight:600;letter-spacing:.5px}
.lv-key{font-family:ui-monospace,Consolas,monospace;font-size:11.5px;color:var(--dim)}
.badge{font-size:11px;padding:1px 8px;border-radius:999px;border:1px solid currentColor;opacity:.95}
.b-layer{color:var(--gold)}
.b-ne{color:var(--ne)}.b-nh{color:var(--nh)}.b-ee{color:var(--ee)}.b-eh{color:var(--eh)}.b-boss{color:var(--boss)}
.b-event{color:#c9a0e8;border-style:dashed}
.b-count{color:#9a8fae}
.lv-meta{display:flex;flex-wrap:wrap;gap:5px 14px;margin-top:9px;font-size:12.5px;color:var(--muted)}
.lv-meta span b{color:#cfc2e0;font-weight:600}
.lv-body{padding:12px 16px 15px}
.effbox{background:#1b1524;border:1px solid var(--line);border-left:2px solid var(--gold);
  border-radius:8px;padding:9px 12px;margin-bottom:12px;font-size:13px}
.effbox .eh{color:var(--gold);font-size:12px;letter-spacing:1px;margin-bottom:4px}
.effbox .ename{color:#f0e2c4;font-weight:600}
.effbox .ename em{font-style:normal;color:var(--dim);font-size:11.5px;font-family:ui-monospace,monospace;
  margin-left:5px}
.effbox p{margin:4px 0 0;color:#c8bdd8}
.note{margin:10px 0 0;padding:7px 10px;border:1px dashed var(--line2);border-radius:6px;
  color:var(--muted);font-size:12px;line-height:1.75}
.note b{color:#cfc2e0}
.units{display:flex;flex-direction:column;gap:9px}
.unit{background:#1c1626;border:1px solid #2f2640;border-radius:9px;padding:9px 11px}
.u-head{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap}
.u-name{font-weight:600;color:#f2ecfa;font-size:14px}
.u-id{font-family:ui-monospace,Consolas,monospace;font-size:11px;color:var(--dim)}
.u-cell{font-family:ui-monospace,Consolas,monospace;font-size:10.5px;color:#8f83a4;
  border:1px solid #352c45;border-radius:4px;padding:0 4px;margin-right:3px}
.u-mul{font-size:11.5px;color:var(--gold);font-weight:600;margin-right:3px}
.chips{display:flex;gap:5px;margin-left:auto}
.chip{font-size:11.5px;padding:0 7px;border-radius:5px;background:#251d32;border:1px solid #382d48;
  color:#b9abc9}
.chip b{color:#efe4ff;font-weight:600}
.chip.atk b{color:#f0a0a8}
.chip.hp b{color:#9fd8a8}
.u-traits{display:flex;gap:5px;flex-wrap:wrap;margin-top:6px}
.tr{font-size:11px;color:#c4b0dd;background:#2a2038;border:1px solid #3b2f4d;border-radius:4px;
  padding:0 6px}
.u-eff{margin-top:6px;font-size:13px;color:#c6bad6}
.u-eff.empty{color:var(--dim);font-style:italic}
.u-eff strong{color:#f4d79a}
footer{margin-top:50px;padding-top:18px;border-top:1px solid var(--line);color:var(--dim);font-size:12.5px}
.hide{display:none !important}
</style>
</head>
<body>
<div class="wrap">
<header class="top">
  <h1>怪物配置总表<span class="tag">R780b</span></h1>
  <div class="sub">数据源：<code>scripts/game_levels.gd</code> 的 <code>enemy_units</code>
   ＋ <code>cards.json</code> 卡面效果。数值为<b>入场实际值</b>，格为 <code>(列, 行)</code>：
   列 0~2 横向三列，行 0 = 敌方最深排、行 2 = 敌方前排（<code>FieldState.OPPONENT_ROWS = 3</code>）。</div>
  <div class="stats">
    <div class="stat"><b>41</b>战斗关卡</div>
    <div class="stat"><b>@@UNIQ@@</b>种怪物 id</div>
    <div class="stat"><b>3</b>层</div>
    <div class="stat"><b>5</b>个难度档</div>
    <div class="stat"><b>敌方血条</b>=（基准+精英10/Boss20）×2</div>
  </div>
</header>
<div class="toolbar">
  <div class="fgroup"><span class="lb">层</span>
    <button class="f on" data-layer="all">全部</button>
    <button class="f" data-layer="L1">第一层</button>
    <button class="f" data-layer="L2">第二层</button>
    <button class="f" data-layer="L3">第三层</button>
  </div>
  <div class="fgroup"><span class="lb">难度</span>
    <button class="f on" data-tier="all">全部</button>
    <button class="f" data-tier="0">普通简单</button>
    <button class="f" data-tier="1">普通困难</button>
    <button class="f" data-tier="2">精英简单</button>
    <button class="f" data-tier="3">精英困难</button>
    <button class="f" data-tier="4">Boss</button>
  </div>
</div>
<main>""".replace("@@UNIQ@@", str(uniq_units)))

for layer in ["L1", "L2", "L3"]:
    if layer not in by_layer:
        continue
    tmap = by_layer[layer]
    total = sum(len(v) for v in tmap.values())
    w('<section class="layer-sec" data-layer="%s">' % layer)
    w('<h2 class="layer">%s<small>%d 关</small></h2>' % (LAYER_NAME[layer], total))
    for ti, tier in enumerate(TIER_ORDER):
        grp = tmap.get(tier)
        if not grp:
            continue
        w('<div class="tierblock" data-tier="%d">' % ti)
        color = {"0": "var(--ne)", "1": "var(--nh)", "2": "var(--ee)", "3": "var(--eh)", "4": "var(--boss)"}[str(ti)]
        w('<h3 class="tier"><span class="dot" style="background:%s"></span>%s'
          '<span style="color:var(--dim);letter-spacing:0">%d 关</span></h3>' % (color, tier, len(grp)))
        w('<div class="grid">')
        for lv in grp:
            tcls = TIER_CLS[lv["tier"]]
            ehp = num(lv["ehp"])
            base = ehp.split("(")[1].rstrip(")").replace("base ", "") if "(" in ehp else "?"
            ehp_val = ehp.split("(")[0]
            w('<article class="lv">')
            w('<div class="lv-head"><div class="lv-title"><span class="lv-name">%s</span>'
              '<span class="lv-key">%s</span>'
              '<span class="badge b-layer">%s</span>'
              '<span class="badge %s">%s</span>'
              '<span class="badge b-count">敌 %d</span>%s</div>'
              % (esc(lv["name"]), esc(lv["key"]), layer,
                 "b-" + tcls.replace("t-", ""), lv["tier"], len(lv["units"]),
                 '<span class="badge b-event">事件专属</span>' if lv["key"] == "cave_owlbear" else ""))
            w('<div class="lv-meta">'
              '<span>玩家HP <b>%s</b></span>'
              '<span>敌方血 <b>%s</b><span style="color:var(--dim)">(基准%s)</span></span>'
              '<span>回合 <b>%s</b></span>'
              '<span>洗牌 <b>%s</b></span>'
              '<span>AI <b>%s</b></span>'
              '<span>起手 <b>%s</b></span></div></div>'
              % (num(lv["pp"]), ehp_val, base,
                 "∞" if num(lv["turn"]) == "-1" else num(lv["turn"]),
                 "是" if num(lv["shuffle"]) == "true" else "否",
                 "是" if num(lv["ai"]) == "true" else "否",
                 num(lv["hand"])))
            w('<div class="lv-body">')
            if lv["key"] == "boss_revelator":
                for k, peid in enumerate(REVELATOR_PHASES):
                    c = cards.get(peid) or {}
                    w('<div class="effbox"><div class="eh">阶段效果卡 · 第 %d 阶段</div>'
                      '<div class="ename">%s<em>%d</em></div><p>%s</p></div>'
                      % (k + 1, esc(c.get("name", "?")), peid, eff_of(peid) or "—"))
            else:
                for eid in ids_of(lv["effects"]):
                    c = cards.get(eid) or {}
                    w('<div class="effbox"><div class="eh">关卡效果卡</div>'
                      '<div class="ename">%s<em>%d</em></div><p>%s</p></div>'
                      % (esc(c.get("name", "?")), eid, eff_of(eid) or "—"))
            for rid in ids_of(lv["reward"]):
                c = cards.get(rid) or {}
                w('<div class="effbox"><div class="eh">固定奖励卡</div>'
                  '<div class="ename">%s<em>%d</em></div><p>%s</p></div>'
                  % (esc(c.get("name", "?")), rid, eff_of(rid) or "—"))
            w('<div class="units">')
            for u, cells in group_units(lv["units"]):
                traits = traits_of(u["id"])
                cellhtml = "".join('<span class="u-cell">%s</span>' % c for c in cells)
                w('<div class="unit"><div class="u-head"><span class="u-name">%s</span>'
                  '<span class="u-id">%d</span>%s%s'
                  '<span class="chips">'
                  '<span class="chip atk">攻 <b>%d</b></span>'
                  '<span class="chip hp">血 <b>%d</b></span>'
                  '<span class="chip">程 <b>%d</b></span>'
                  '<span class="chip">移 <b>%d</b></span></span></div>'
                  % (esc(u["name"]), u["id"],
                     '<span class="u-mul">×%d</span>' % len(cells) if len(cells) > 1 else "",
                     cellhtml, u["atk"], u["hp"], u["rng"], u["mv"]))
                if traits:
                    w('<div class="u-traits">%s</div>' % "".join(
                        '<span class="tr">%s</span>' % esc(t) for t in traits))
                eff = eff_of(u["id"])
                w('<div class="u-eff%s">%s</div>' % ("" if eff else " empty", eff or "（无特殊效果）"))
                w('</div>')
            if lv["key"] == "boss_revelator":
                w('<div class="note">启示者本体的数值<b>随阶段实时变化</b>（不是卡面上的固定值）：'
                  '移动速度 <b>2 → 1 → 0</b>，攻击距离 <b>2 → 2 → 4</b>，每回合行动 <b>1 → 2 → 2</b>；'
                  '第一阶段每回合力量 +1。血量 300，阶段血线 = 最大生命的 2/3、1/3（200 / 100），'
                  '唯一口 <code>revelator_gate_hp()</code> —— 难度上调血量时比例不变。</div>')
            w('</div></div></article>')
        w('</div></div>')
    w('</section>')

w("""</main>
<footer>
  共 41 个战斗关卡（含事件专属「洞穴」）。同一 id 的多套入场值只有「量产型赫利俄斯 9137」
  在<code>hecaton</code> 里射程为 2（其余三关为 1）；其余怪物入场值与卡面完全一致。<br>
  生成脚本：<code>tools/_gen_r778_enemy_html.py</code>（数据 dump：<code>tools/_dump_r778_levels.gd</code>）。
</footer>
</div>
<script>
(function(){
  var layer='all', tier='all';
  var secs=[].slice.call(document.querySelectorAll('.layer-sec'));
  function apply(){
    secs.forEach(function(sec){
      var lOk = layer==='all' || sec.dataset.layer===layer;
      sec.classList.toggle('hide', !lOk);
      [].slice.call(sec.querySelectorAll('.tierblock')).forEach(function(tb){
        var tOk = tier==='all' || tb.dataset.tier===tier;
        tb.classList.toggle('hide', !tOk);
      });
    });
  }
  document.querySelectorAll('button.f').forEach(function(b){
    b.addEventListener('click', function(){
      if(b.dataset.layer!==undefined){
        layer=b.dataset.layer;
        document.querySelectorAll('button[data-layer]').forEach(function(x){
          x.classList.toggle('on', x===b);});
      } else {
        tier=b.dataset.tier;
        document.querySelectorAll('button[data-tier]').forEach(function(x){
          x.classList.toggle('on', x===b);});
      }
      apply();
    });
  });
})();
</script>
</body>
</html>""")

out = "\n".join(H) + "\n"
io.open(ROOT + "_preview/r778_enemy_config.html", "w", encoding="utf-8", newline="\n").write(out)
print("WROTE html chars=%d levels=%d units=%d" % (len(out), len(levels), uniq_units))
