# -*- coding: utf-8 -*-
"""把 _preview/asset_audit.json 渲染成发布前素材体检报告（R595）。"""
import io
import json
import os

ROOT = "E:/work/card_rogue"
A = json.load(open(os.path.join(ROOT, "_preview", "asset_audit.json"), encoding="utf-8"))
CARDS = json.load(open(os.path.join(ROOT, "cards.json"), encoding="utf-8"))
ITEMS = CARDS["cards"] if isinstance(CARDS, dict) else CARDS
BY_ID = {c["id"]: c for c in ITEMS}

miss = A["cards"]["missing"]
# ── 优先级：P0 敌人单位 + 初始卡组常见低费 / P1 1 费以下玩家卡 + 诅咒 / P2 其余 ──
START_IDS = {8001, 8002, 8004, 8008, 9086, 8031, 8032}   # 初始卡组里的角色专属卡（见 player_class）
def prio(m):
    c = BY_ID.get(m["id"], {})
    if m["group"] == "enemy" and m["kind"] in ("盟友", "工事"):
        return 0
    if m["id"] in START_IDS:
        return 0
    if m["kind"] == "诅咒":
        return 1
    if int(c.get("cost", 9)) <= 1:
        return 1
    return 2

for m in miss:
    m["prio"] = prio(m)

P = {0: [], 1: [], 2: []}
for m in miss:
    P[m["prio"]].append(m)

rows_total = []
cats = [
    ("卡图（cards.json 316 张）", "缺 %d" % len(miss), "bad"),
    ("道具图标 + 边缘光（62 个）", "0 缺", "ok"),
    ("事件插图 / 竖版 / 背景", "按布局口径齐全", "ok"),
    ("职业素材（CG / 头像 / 徽章）", "3 职业全齐", "ok"),
    ("地图节点图标", "9 / 9", "ok"),
    ("BGM 槽位", "11 / 11", "ok"),
    ("代码引用的 UI 素材", "45 个全在", "ok"),
    ("应用图标 / 启动图", "4 件全在", "ok"),
    ("音效", "代码合成，无素材需求", "ok"),
]

def tbl(m_list):
    out = ["<table><tr><th>#</th><th>id</th><th>名称</th><th>种类</th><th>稀有度</th><th>费用</th><th>阵营</th></tr>"]
    for i, m in enumerate(m_list, 1):
        c = BY_ID.get(m["id"], {})
        rar = ["普通", "稀有", "史诗", "初始", "怪物", "事件", "诅咒"][min(int(m["rarity"]), 6)]
        out.append("<tr><td>%d</td><td><code>%d</code></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>"
                   % (i, m["id"], m["name"], m["kind"], rar, c.get("cost", "-"),
                      "敌方" if m["group"] == "enemy" else "玩家"))
    out.append("</table>")
    return "\n".join(out)

html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R595 · 发布前素材体检</title>
<style>
  :root{--bg:#151517;--panel:#1e1e22;--line:#33333a;--ink:#e8e6e1;--dim:#a09c94;
        --gold:#f0c060;--green:#7fe0a0;--red:#ff8f8f;--amber:#f0b860;}
  *{box-sizing:border-box}
  body{margin:0;padding:28px 30px 48px;background:var(--bg);color:var(--ink);
       font-family:"Microsoft YaHei","PingFang SC",system-ui,sans-serif;line-height:1.65}
  h1{font-size:21px;margin:0 0 4px}
  .sub{color:var(--dim);font-size:13px;margin-bottom:20px}
  h2{font-size:15px;color:var(--gold);margin:26px 0 10px;font-weight:600}
  h3{font-size:13.5px;color:var(--ink);margin:18px 0 6px}
  .hero{background:var(--panel);border:1px solid var(--line);border-radius:10px;
        padding:16px 18px;font-size:14px}
  .hero b{color:var(--red)}
  table{width:100%;border-collapse:collapse;font-size:13px;margin-top:8px}
  th,td{text-align:left;padding:6px 9px;border-bottom:1px solid var(--line)}
  th{color:var(--dim);font-weight:500;font-size:12px}
  code{background:#26262c;padding:1px 5px;border-radius:4px;font-size:12px}
  .ok{color:var(--green)} .bad{color:var(--red)} .warn{color:var(--amber)}
  .bar{display:flex;height:22px;border-radius:6px;overflow:hidden;margin:8px 0 4px;
       background:#2a2a30;font-size:11.5px;color:#151517;font-weight:600}
  .bar div{display:flex;align-items:center;justify-content:center;white-space:nowrap}
  .b0{background:#ff8f8f} .b1{background:#f0b860} .b2{background:#8fbfe0}
  ul{margin:6px 0 0 18px;padding:0;font-size:13.5px} li{margin:3px 0}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:18px}
  @media(max-width:820px){.cols{grid-template-columns:1fr}}
</style></head><body>

<h1>R595 · 发布前素材体检</h1>
<div class="sub">card_rogue / 2026-11-12 · 316 张卡 · 62 个道具 · 26 类事件 · 11 个 BGM 槽位 · 可重跑：<code>python tools/audit_release_assets.py</code></div>

<div class="hero">
结论：除<b>卡图</b>外全部齐全 —— 道具（图标 + 边缘光 62/62）、职业 CG·头像·徽章、地图节点图标 9/9、BGM 11/11、
事件图（4 个左右布局事件全有竖版图）、代码引用的 45 个 UI 素材、应用图标 4 件，一件不缺。
卡图缺 <b>__MISS__ / 316</b>（__PCT__%），其余全部是「有变体图可顶」或已排除。
</div>

<h2>一、类目总表</h2>
<table><tr><th>类目</th><th>状态</th></tr>
__CATS__
</table>

<h2>二、卡图缺口分布</h2>
<div class="bar">
  <div class="b0" style="width:__W0__%">P0 __N0__</div>
  <div class="b1" style="width:__W1__%">P1 __N1__</div>
  <div class="b2" style="width:__W2__%">P2 __N2__</div>
</div>
<div class="sub" style="margin:0 0 4px">P0 = 敌方单位 + 初始卡组里的角色专属卡（第一眼就看得到）／
P1 = 诅咒 + 1 费及以下的高频卡／P2 = 其余</div>

<div class="cols">
  <div>
    <h3 class="bad">按阵营 × 种类</h3>
    <table><tr><th>阵营</th><th>种类</th><th>张数</th></tr>__BYCAT__</table>
  </div>
  <div>
    <h3 class="warn">事件图为什么不算缺</h3>
    <ul>
      <li>只有 4 个事件走左右布局（<code>lake_lady / martial / rest / apple_doctor</code>），
          它们的 <code>side_*.png</code> <b class="ok">全部齐</b>。</li>
      <li>其余 22 个走居中布局，设计上就<b>不配插图</b> —— 用纹章 + 光晕 + 文案，
          代码里 <code>top_floor</code> 会按「有没有图」自适应（360 → 150）。</li>
      <li><code>event_gaze.png</code> 是居中布局里唯一配了插图的，也在。</li>
    </ul>
  </div>
</div>

<h2>三、P0 · 先补这些（__N0__ 张）</h2>
__T0__

<h2>四、P1 · 高频玩家卡（__N1__ 张）</h2>
__T1__

<h2>五、P2 · 其余（__N2__ 张）</h2>
__T2__

<h2>六、缺图时的表现</h2>
<ul>
  <li>卡面上半会<b>只剩纸底</b>（<code>CardFace.art_for()</code> 返回 null 时不画图，也不报错、不崩）；
      文字区、数值徽章、字段标志全部照常。</li>
  <li>所以这不是「跑不起来」的问题，是<b>完成度</b>问题：玩家会看到一批空白插画的卡。</li>
  <li>沉睡图 / 阶段图是可选件：现有 <code>9116_sleep</code>、<code>9200_p2/p3</code> 已经覆盖唯二有机制的两张，不缺。</li>
</ul>
</body></html>
"""

bycat = {}
for m in miss:
    bycat[(m["group"], m["kind"])] = bycat.get((m["group"], m["kind"]), 0) + 1
bycat_rows = "\n".join(
    "<tr><td>%s</td><td>%s</td><td>%d</td></tr>"
    % ("敌方" if g == "enemy" else "玩家", k, n)
    for (g, k), n in sorted(bycat.items(), key=lambda x: -x[1]))

n0, n1, n2 = len(P[0]), len(P[1]), len(P[2])
tot = max(1, n0 + n1 + n2)
html = (html
        .replace("__MISS__", str(len(miss)))
        .replace("__PCT__", "%.0f" % (100.0 * len(miss) / 316))
        .replace("__CATS__", "\n".join(
            '<tr><td>%s</td><td class="%s">%s</td></tr>' % (a, b, c) for a, c, b in cats))
        .replace("__N0__", str(n0)).replace("__N1__", str(n1)).replace("__N2__", str(n2))
        .replace("__W0__", "%.1f" % (100.0 * n0 / tot))
        .replace("__W1__", "%.1f" % (100.0 * n1 / tot))
        .replace("__W2__", "%.1f" % (100.0 * n2 / tot))
        .replace("__BYCAT__", bycat_rows)
        .replace("__T0__", tbl(P[0])).replace("__T1__", tbl(P[1])).replace("__T2__", tbl(P[2])))

out = os.path.join(ROOT, "_preview", "r595_asset_audit.html")
with io.open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print(out, os.path.getsize(out), "P0/P1/P2 =", n0, n1, n2)
