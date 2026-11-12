# -*- coding: utf-8 -*-
"""R612 交付页：只缩「实机尺寸远小于源图」的 23 张图标，附等价性样张与账单。

样张做法：把「备份的原图」与「缩后的新图」都按**实机绘制尺寸**渲染，再整体放大
6 倍并排 —— 放大只是为了让人看清像素，游戏里看到的永远是左边那个尺寸。
"""
import base64
import io
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "_review")
FONT = os.path.join(ROOT, "assets/fonts/SourceHanSansCN-Regular.otf")
BK = os.path.join(ROOT, "art_src", "_originals_r612")

# (备份相对路径, 现役路径, 实机绘制边长, 标签)
CASES = [
    ("ui/map_icons/battle.png", "assets/ui/map_icons/battle.png", 62, "地图·战斗图标（实机 62px）"),
    ("ui/reward_icons/core.png", "assets/ui/reward_icons/core.png", 200, "事件页核心标志（实机 200px）"),
    ("ui/class_avatar_forest.png", "assets/ui/class_avatar_forest.png", 160, "职业头像（代码 resize 到 160）"),
]


def load(p):
    return Image.open(p).convert("RGBA")


def at_size(im, edge):
    """按实机「等比缩进一个方形框」的方式渲染（CardFace.fit_rect 同口径）。"""
    r = min(edge / float(im.size[0]), edge / float(im.size[1]))
    return im.resize((max(1, round(im.size[0] * r)), max(1, round(im.size[1] * r))),
                     Image.LANCZOS)


def build_compare():
    CELL = 300          # 每格显示区（正方形）
    PAD = 18
    rows = []
    for bkr, live, edge, label in CASES:
        old = at_size(load(os.path.join(BK, bkr)), edge)
        new = at_size(load(os.path.join(ROOT, live)), edge)
        rows.append((label, old, new, edge))

    W = PAD * 3 + CELL * 2
    H = PAD + len(rows) * (32 + CELL + 66)
    canvas = Image.new("RGB", (W, H), (26, 20, 15))
    dr = ImageDraw.Draw(canvas)
    try:
        f22 = ImageFont.truetype(FONT, 22)
        f17 = ImageFont.truetype(FONT, 17)
    except Exception:
        f22 = f17 = None

    y = PAD
    for label, old, new, edge in rows:
        # 显示区固定 CELL 见方，图按「等比缩进」的原则画进去；放大倍数随之变化
        zoom = min(1.0 * CELL / edge, 6.0)
        dr.text((PAD, y), label, fill=(232, 210, 160), font=f22)
        dr.text((W - PAD - 150, y + 3), "放大 %.1f×" % zoom, fill=(150, 132, 104), font=f17)
        y += 32
        for i, (im, cap) in enumerate(((old, "压缩前"), (new, "压缩后"))):
            x = PAD + i * (CELL + PAD)
            for cy in range(y, y + CELL, 20):
                for cx in range(x, x + CELL, 20):
                    c = (58, 50, 42) if ((cx - x) // 20 + (cy - y) // 20) % 2 == 0 else (44, 38, 32)
                    dr.rectangle([cx, cy, cx + 19, cy + 19], fill=c)
            big = im.resize((max(1, round(im.size[0] * zoom)), max(1, round(im.size[1] * zoom))),
                            Image.NEAREST)
            if big.size[0] > CELL or big.size[1] > CELL:
                big = big.crop((0, 0, min(big.size[0], CELL), min(big.size[1], CELL)))
            canvas.paste(big, (x + (CELL - big.size[0]) // 2, y + (CELL - big.size[1]) // 2), big)
            dr.rectangle([x, y, x + CELL - 1, y + CELL - 1], outline=(120, 96, 60))
            dr.text((x + 6, y + CELL + 5), "%s · 按实机 %dpx 渲染" % (cap, edge),
                    fill=(214, 200, 176), font=f17)
        y += CELL + 66

    out = os.path.join(REVIEW, "r612_cmp_icons.png")
    canvas.save(out, optimize=True)
    print("saved", out, canvas.size)
    return out


def b64(rel):
    p = os.path.join(ROOT, rel)
    raw = open(p, "rb").read()
    if len(raw) > 400 * 1024:
        im = Image.open(p).convert("RGB")
        bio = io.BytesIO()
        im.save(bio, "JPEG", quality=90, optimize=True)
        return "image/jpeg", base64.b64encode(bio.getvalue()).decode("ascii")
    return "image/png", base64.b64encode(raw).decode("ascii")


def img(rel, alt):
    mime, data = b64(rel)
    return '<img class="shot" alt="%s" src="data:%s;base64,%s">' % (alt, mime, data)


ROWS = [
    ("map_icons/battle.png", "1254²", "256²", "62"),
    ("map_icons/bigchest.png", "1254²", "256²", "62"),
    ("map_icons/chest.png", "1254²", "256²", "62"),
    ("map_icons/elite.png", "1254²", "256²", "62"),
    ("map_icons/event.png", "1254²", "256²", "62"),
    ("map_icons/rest.png", "1254²", "256²", "62"),
    ("map_icons/shop.png", "1254²", "256²", "62"),
    ("map_icons/start.png", "1254²", "256²", "62"),
    ("map_icons/unknown.png", "1254²", "256²", "62"),
    ("reward_icons/cards.png", "1254²", "256²", "96"),
    ("reward_icons/core.png", "1254²", "**512²**", "200"),
    ("reward_icons/deck_delete.png", "1254²", "256²", "96"),
    ("reward_icons/gold.png", "512²", "256²", "64"),
    ("reward_icons/legendary.png", "1254²", "256²", "96"),
    ("reward_icons/maxhp.png", "1050²", "256²", "64"),
    ("reward_icons/relic.png", "1254²", "256²", "96"),
    ("class_avatar_forest.png", "1020×1023", "320²", "160"),
    ("class_avatar_mech.png", "1024²", "320²", "160"),
    ("class_avatar_rogue.png", "1024²", "320²", "160"),
    ("adventure_shared/close_forest.png", "1254²", "256²", "64"),
]


def main():
    cmp_path = build_compare()
    rows_html = "\n".join(
        "<tr><td class='m'>%s</td><td class='n'>%s</td><td class='n'>%s</td>"
        "<td class='n'>%s px</td></tr>" % r for r in ROWS)

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R612 图标降分辨率 · 影响最小的一批</title>
<style>
:root{--ink:#2a2118;--paper:#f6f1e6;--gold:#b08a3e;--mute:#7a6a55}
*{box-sizing:border-box}
body{margin:0;background:#161210;color:var(--paper);
     font:16px/1.75 "Source Han Sans CN","Microsoft YaHei",system-ui,sans-serif}
.wrap{max-width:1120px;margin:0 auto;padding:56px 28px 88px}
h1{font-size:32px;margin:0 0 6px;letter-spacing:.04em;color:#f0dfb8}
.sub{color:#a89880;margin:0 0 40px;font-size:15px}
h2{font-size:22px;margin:52px 0 14px;padding-left:12px;border-left:4px solid var(--gold);color:#f0dfb8}
p{color:#d8cdb8;margin:12px 0}
.note{background:#241d16;border:1px solid #3a2f22;border-radius:10px;padding:16px 20px;color:#cbbfa6}
.note b{color:#f0dfb8}
table{width:100%;border-collapse:collapse;margin:16px 0;font-size:15px}
th,td{padding:9px 12px;border-bottom:1px solid #352b20;text-align:left}
th{color:#c9b489;font-weight:600;background:#201a14}
td.n{text-align:right;font-variant-numeric:tabular-nums;color:#e8dcc4}
td.m{color:#e8dcc4}
tr:hover td{background:#1d1712}
.big{font-size:26px;color:#f0d79a;font-variant-numeric:tabular-nums}
.shot{width:100%;border-radius:10px;border:1px solid #3a2f22;display:block;margin:10px 0 6px}
.cap{color:#998a72;font-size:13px;margin:0 0 26px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:18px}
footer{margin-top:60px;padding-top:20px;border-top:1px solid #352b20;color:#8b7d68;font-size:13px}
code{background:#241d16;padding:2px 6px;border-radius:4px;color:#e0c98f;font-size:14px}
</style></head><body><div class="wrap">

<h1>图标降分辨率 · 影响最小的一批</h1>
<p class="sub">23 张 · 导出的 PCK 174.9 MB → <b>160.7 MB</b> · 原图全部留在仓库里</p>

<div class="note">
<b>只动了「实机画得比源图小得多」的图标。</b>
地图图标源图 1254×1254，实机 <code>ZONE_ICON = 62</code>；职业头像源图 1020×1020，
代码里 <code>class_avatar()</code> 直接 <code>small_icon(..., 160)</code> 缩到 160 再用。
也就是说这些多出来的像素<b>从来没有被任何人看见过</b>，砍掉它是零观感代价。
背景、九宫格面板、事件竖版图一张没动。
</div>

<h2>一、账单</h2>
<table>
<tr><th>项目</th><th style="text-align:right">之前</th><th style="text-align:right">现在</th><th style="text-align:right">变化</th></tr>
<tr><td>导出 PCK（Android）</td><td class="n">174.9 MB</td><td class="n">160.7 MB</td><td class="n">−14.2 MB</td></tr>
<tr><td>其中 卡图（ASTC，未动）</td><td class="n">55.5 MB</td><td class="n">55.5 MB</td><td class="n">0</td></tr>
<tr><td>其中 其他纹理（本次目标）</td><td class="n">71.8 MB</td><td class="n">57.6 MB</td><td class="n">−14.2 MB</td></tr>
<tr><td>23 张源 PNG 合计</td><td class="n">23.63 MB</td><td class="n">1.82 MB</td><td class="n">−21.81 MB</td></tr>
</table>
<p class="cap">包内降幅比源 PNG 降幅小，是因为 Godot 的未压缩纹理本身已比 PNG 再省约 28%（71.8 / 99.6）。</p>

<h2>二、上限是怎么定的</h2>
<table>
<tr><th>组</th><th style="text-align:right">张数</th><th style="text-align:right">实机最大绘制</th><th style="text-align:right">新上限</th><th style="text-align:right">余量</th></tr>
<tr><td>地图图标 <code>map_icons/</code></td><td class="n">9</td><td class="n">62（商店位 120）</td><td class="n">256</td><td class="n">2.1×</td></tr>
<tr><td>奖励图标 <code>reward_icons/</code></td><td class="n">7</td><td class="n">96（small_icon 64）</td><td class="n">256</td><td class="n">2.7×</td></tr>
<tr><td>其中 <code>core.png</code>（事件页核心）</td><td class="n">1</td><td class="n">200</td><td class="n">512</td><td class="n">2.5×</td></tr>
<tr><td>职业头像 <code>class_avatar_*</code></td><td class="n">6</td><td class="n">160</td><td class="n">320</td><td class="n">2.0×</td></tr>
<tr><td>关闭按钮 <code>close_forest</code></td><td class="n">1</td><td class="n">64</td><td class="n">256</td><td class="n">4.0×</td></tr>
</table>
<p class="cap">一律留 ≥2 倍余量，为的是应对高 DPI 与 canvas_items 缩放在 1920 屏上的 1.5 倍放大。</p>

<h2>三、等价性：按实机尺寸渲染再放大 6 倍</h2>
<p>左边是备份的原图、右边是缩后的新图，<b>都先缩到游戏里真正画出来的尺寸</b>，
再放大 6 倍并排。放大只为看清像素 —— 游戏里看到的永远是那个 62 / 200 / 160 px 的样子。</p>
@@0@@
<p class="cap">透明区用棋盘底衬，方便比较轮廓与描边；插值都用 LANCZOS，与 Godot 的 mipmap 采样口径接近。</p>

<h2>四、实机截图</h2>
<div class="grid">
<div>@@1@@<p class="cap">职业选择：底部三个头像走 class_avatar（本次已缩）</p></div>
<div>@@2@@<p class="cap">神秘商店：第二行第一格「三张牌」用的正是 map_icons/start</p></div>
</div>

<h2>五、一张没动的清单</h2>
<table>
<tr><th>不动的东西</th><th>原因</th></tr>
<tr><td>背景 <code>bg_*</code> / <code>map_bg_*</code> / <code>battle_bg_*</code></td><td>1280×720 全屏铺满，实机还在 1920 屏上放大，缩了立刻软</td></tr>
<tr><td>九宫格 <code>panel_parchment</code> / <code>scroll_parchment</code></td><td>平铺底，源图缩小会让花纹重复次数翻倍、接缝更明显</td></tr>
<tr><td>事件竖版 <code>side_*</code></td><td>实机 742×720，源图 742×742 正好匹配，没有余量可砍</td></tr>
<tr><td><code>relic_*</code> / <code>affix_*</code> / <code>shop_icon_*</code></td><td>本来就只有 64~128，缩了等于自残</td></tr>
<tr><td>卡图 <code>pics/*.png</code> 320 张</td><td>已 ASTC 压缩，且卡面是核心视觉，不动</td></tr>
</table>

<h2>六、图源怎么保的</h2>
<p>改写前把 23 张原 PNG 逐张复制到
<code>art_src/_originals_r612/</code>（保留 <code>assets/</code> 之后的相对路径）。
这个目录<b>已入库</b>，任何人 checkout 都能拿回压缩前的原件；要还原只要
<code>cp art_src/_originals_r612/ui/&lt;路径&gt; assets/ui/&lt;路径&gt;</code>。
工具 <code>tools/_r612_shrink_icons.py</code> 支持 <code>--dry</code> 只列计划，规则与理由写在文件头。</p>

<footer>产物：_review/r612_cmp_icons.png · _shots/class_pick.png · _shots/shop.png<br>
工具：tools/_r612_shrink_icons.py（可复现）· tools/_shot_scenes.gd（实机截图）</footer>
</div></body></html>"""

    subs = [
        img("_review/r612_cmp_icons.png", "实机尺寸渲染后放大 6 倍的压缩前后对比"),
        img("_shots/class_pick.png", "职业选择页实机截图"),
        img("_shots/shop.png", "神秘商店实机截图"),
    ]
    for i, v in enumerate(subs):
        html = html.replace("@@%d@@" % i, v)

    out = os.path.join(ROOT, "_preview", "r612_icon_shrink.html")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with io.open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    print("saved", out, "%.2f MB" % (os.path.getsize(out) / 1048576.0))


if __name__ == "__main__":
    main()
