# -*- coding: utf-8 -*-
"""生成 R592d 交付页（图片 base64 内嵌，单文件可离线打开）。"""
import base64
import io
import os

ROOT = "E:/work/card_rogue"
OUT = os.path.join(ROOT, "_preview", "r592d_affix_corner.html")

IMGS = [
    ("hand", os.path.join(ROOT, "_preview", "r592d_hand_zoom.png"),
     "手牌真实尺寸 98.6×119（放大 5 倍）· 交换 / 短暂(幻影) / 次元 三枚都在手卡上可见"),
    ("cmp", os.path.join(ROOT, "_preview", "r592d_compare.png"),
     "位置对比：上 = R592c（让开缎带、落在卡图中段）　下 = R592d（贴卡框右上角）"),
    ("all", os.path.join(ROOT, "art_src/2026-11-11_字段标志_R592/_review/cards.png"),
     "全字段组合 + 轮播 + 战场过滤（232×280 大卡）"),
]


def b64(path):
    with io.open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


parts = []
for key, path, cap in IMGS:
    assert os.path.exists(path), path
    parts.append(
        '<figure><img alt="%s" src="data:image/png;base64,%s"><figcaption>%s</figcaption></figure>'
        % (key, b64(path), cap))

html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R592d · 字段标志改角标 + 交换图标恢复</title>
<style>
  :root { --bg:#151517; --panel:#1e1e22; --line:#33333a; --ink:#e8e6e1;
          --dim:#a09c94; --gold:#f0c060; --green:#7fe0a0; --pink:#e58cff; }
  * { box-sizing:border-box; }
  body { margin:0; padding:28px 30px 46px; background:var(--bg); color:var(--ink);
         font-family:"Microsoft YaHei","PingFang SC",system-ui,sans-serif; line-height:1.7; }
  h1 { font-size:21px; margin:0 0 4px; letter-spacing:.4px; }
  .sub { color:var(--dim); font-size:13px; margin-bottom:22px; }
  h2 { font-size:15px; margin:26px 0 10px; color:var(--gold); font-weight:600; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:12px; }
  .card { background:var(--panel); border:1px solid var(--line); border-radius:10px; padding:13px 15px; }
  .card b { color:var(--green); font-weight:600; }
  table { width:100%; border-collapse:collapse; font-size:13.5px; margin-top:6px; }
  th,td { text-align:left; padding:7px 9px; border-bottom:1px solid var(--line); vertical-align:top; }
  th { color:var(--dim); font-weight:500; font-size:12.5px; }
  code { background:#26262c; padding:1px 5px; border-radius:4px; font-size:12.5px; color:#d9d5cd; }
  figure { margin:14px 0 0; background:var(--panel); border:1px solid var(--line);
           border-radius:10px; padding:12px; }
  figure img { width:100%; display:block; border-radius:6px; }
  figcaption { color:var(--dim); font-size:12.5px; margin-top:9px; }
  ul { margin:6px 0 0 18px; padding:0; font-size:13.5px; }
  li { margin:3px 0; }
  .ok { color:var(--green); } .no { color:#ff8f8f; } .hl { color:var(--pink); }
</style></head><body>

<h1>R592d · 字段标志：贴右上角标 + 交换图标恢复</h1>
<div class="sub">card_rogue / 2026-11-12 · 引擎回归 5731 项全通过 · 六套回归全通过</div>

<h2>一、这一版改了什么</h2>
<div class="grid">
  <div class="card"><b>① 槽位改角标</b><br>
    圆心从「卡框右上角」向内收 <code>AFFIX_BADGE_CORNER = 0.45d</code>，
    不再减稀有度缎带宽度，标志压在缎带<b>上层</b>（旗杆与燕尾仍露出来）。</div>
  <div class="card"><b>② 交换图标恢复</b><br>
    撤掉 <code>AFFIX_DEFS["交换"].badge = false</code>：交换 / 短暂(幻影) / 次元 三个字段
    现在在手卡上都能看到图标。<code>badge</code> 开关本身留着，当前无字段使用。</div>
  <div class="card"><b>③ 战场口径不变</b><br>
    <code>on_board</code> 仍滤掉交换 / 幻影 —— 那是「手牌里才有意义」的字段，
    落到格子上就不再标；次元留在场上照常显示。</div>
</div>

<h2>二、为什么没放「下面中间」</h2>
<table>
  <tr><th>项</th><th>数值</th><th>结论</th></tr>
  <tr><td>卡宽 / 卡高</td><td><code>63k × 76k</code>（k = 高/70）</td><td>宽高比固定 0.829</td></tr>
  <tr><td>底部数值徽章</td><td>半径 <code>9.2k</code>、<code>GAP = 0</code>、圆心压在左右框线上</td><td>四枚已相切</td></tr>
  <tr><td>中间剩下的缝</td><td><code>58k − 4 × 2 × 9.2k = 2.8k</code></td><td>手牌上约 <b>4.8px</b>，放不进可读标志</td></tr>
  <tr><td>要放下 20k 标志</td><td>数值徽章半径得缩到 ≈ <code>5k</code>（31px → 17px）</td><td class="no">数字会明显变小，不划算</td></tr>
</table>

<h2>三、验收图</h2>
__IMGS__

<h2>四、回归</h2>
<ul>
  <li>engine <b class="ok">5731 ✓ / 0 ✗</b>（新增 2 条：角标圆心锁、交换图标锁；改 3 条旧 R592c 口径）</li>
  <li>assemble / reward 26 / bgm 39 / smoke 68 / mana —— 全部通过</li>
  <li>source lock：<code>affix_badge_rect()</code> 仍是槽位唯一口，绘制与测试都读它</li>
</ul>
</body></html>
""".replace("__IMGS__", "\n".join(parts))

with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print(OUT, os.path.getsize(OUT))
