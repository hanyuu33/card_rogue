# -*- coding: utf-8 -*-
"""生成 R592e 交付页（图片 base64 内嵌，单文件可离线打开）。"""
import base64
import io
import os

ROOT = "E:/work/card_rogue"
OUT = os.path.join(ROOT, "_preview", "r592e_affix_mirror.html")

IMGS = [
    ("hand", os.path.join(ROOT, "_preview", "r592e_hand_zoom.png"),
     "手牌真实尺寸 98.6×119（放大 5 倍）· 左上费用 / 右上字段，同尺寸对称"),
    ("cmp", os.path.join(ROOT, "_preview", "r592e_compare.png"),
     "位置对比：左 = R592c（让开缎带、落在卡图中间）　右 = R592e（骑在卡框右上角）"),
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
<title>R592e · 字段标志与费用徽章镜像对称</title>
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
  .ok { color:var(--green); } .hl { color:var(--pink); }
</style></head><body>

<h1>R592e · 字段标志 = 费用徽章的右上角镜像</h1>
<div class="sub">card_rogue / 2026-11-12 · 引擎回归 5732 项全通过</div>

<h2>一、口径</h2>
<div class="grid">
  <div class="card"><b>位置</b><br>
    费用圆心 <code>cost_badge_center()</code> = 卡片<b>左上角</b>；
    字段标志圆心 <code>affix_badge_center()</code> = 卡片<b>右上角</b>。
    两枚关于卡面竖直中轴对称，圆心都压在框线上、一半探出卡外。</div>
  <div class="card"><b>尺寸</b><br>
    不再用自定义常量：直径 = <code>2 × badge_radius(rect)</code>
    = <code>2 × CARD_BADGE_R × min(k, CARD_BADGE_SCALE_CAP)</code>，与费用徽章<b>完全同尺寸</b>，
    改大小只需改 <code>UiTheme.CARD_BADGE_R</code> 一处。</div>
  <div class="card"><b>层级</b><br>
    标志画在稀有度缎带之后 → 压在上层，旗子下半仍露出可辨稀有度
    （店长口径「略微遮挡旗子也无所谓」）。</div>
</div>

<h2>二、位置与尺寸</h2>
<table>
  <tr><th>项</th><th>R592c（旧）</th><th>R592e（现在）</th></tr>
  <tr><td>圆心</td><td>缎带左边线再往内 2k，落在卡图中段</td><td class="hl">卡框右上角（费用镜像）</td></tr>
  <tr><td>直径</td><td><code>20k</code>（自定义）</td><td class="hl"><code>2 × 9.2 × kc</code>（与费用一致）</td></tr>
  <tr><td>与卡框</td><td>整个在卡内</td><td>圆心压框线，一半探出（同费用）</td></tr>
  <tr><td>与缎带</td><td>完全让开</td><td>压在上层，燕尾仍可见</td></tr>
</table>

<h2>三、验收图</h2>
__IMGS__

<h2>四、回归</h2>
<ul>
  <li>engine <b class="ok">5732 ✓ / 0 ✗</b>（R592e 四条新锁：直径 = 费用 / 圆心 = 费用镜像 / 压框角 / 只探出一个半径）</li>
  <li>槽位唯一口仍是 <code>CardFace.affix_badge_rect()</code>，圆心唯一口 <code>affix_badge_center()</code></li>
  <li>交换 / 短暂(幻影) / 次元 三枚图标手卡上都在（R592d 恢复，未回退）</li>
</ul>
</body></html>
""".replace("__IMGS__", "\n".join(parts))

with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(html)
print(OUT, os.path.getsize(OUT))
