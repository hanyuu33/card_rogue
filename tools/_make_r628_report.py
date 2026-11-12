# -*- coding: utf-8 -*-
"""R628 独行吞卡特效：素材 + 实机截图对比页（base64 内嵌，单文件可发）。"""
import base64
import io
import os

from PIL import Image

ROOT = r"E:\work\card_rogue"
PREV = os.path.join(ROOT, "_preview")
RAW = os.path.join(ROOT, "art_src", "2026-11-12_独行特效_R628", "raw")


def b64(path, max_w=760, bg=None):
    im = Image.open(path).convert("RGBA")
    if bg is not None:
        canvas = Image.new("RGBA", im.size, bg)
        canvas.alpha_composite(im)
        im = canvas
    if im.width > max_w:
        h = int(round(im.height * max_w / im.width))
        im = im.resize((max_w, h), Image.LANCZOS)
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "JPEG", quality=86)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def card(title, sub, img):
    return (
        '<figure class="shot"><figcaption><b>' + title + '</b><span>' + sub
        + '</span></figcaption><img src="' + img + '"></figure>'
    )


raw_col = b64(os.path.join(RAW, "column_codex.png"), 300)
raw_maw = b64(os.path.join(RAW, "maw_codex.png"), 300)
raw_ring = b64(os.path.join(RAW, "ring_codex.png"), 300)

fx_col = b64(os.path.join(ROOT, "assets", "fx", "fx_lone_column.png"), 240, (26, 22, 38))
fx_maw = b64(os.path.join(ROOT, "assets", "fx", "fx_lone_maw.png"), 240, (26, 22, 38))
fx_ring = b64(os.path.join(ROOT, "assets", "fx", "fx_lone_ring.png"), 240, (26, 22, 38))

shots = [
    card("① 110ms · 起手", "手牌处光环收束，能量沿路径升起的头一拍", b64(os.path.join(PREV, "r628_t110.png"))),
    card("② 300ms · 吸取", "紫色绞股光柱贯通到目标卡，头部漩涡前顶", b64(os.path.join(PREV, "r628_t300.png"))),
    card("③ 620ms · 吞噬", "虚空漩涡张开 + 冲击光环，命中数字同帧落地", b64(os.path.join(PREV, "r628_t620.png"))),
]

pairs = "".join(
    '<div class="pair"><div class="col"><img src="' + raw + '"><i>codex 原图（纯黑底）</i></div>'
    '<div class="arrow">→</div>'
    '<div class="col"><img src="' + cut + '"><i>成品（亮度转 alpha）</i></div></div>'
    for raw, cut in ((raw_col, fx_col), (raw_maw, fx_maw), (raw_ring, fx_ring))
)

html = """<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">
<title>R628 独行吞卡特效</title>
<style>
:root{--ink:#2b2118;--sub:#6b5b48;--line:#d8cbb4;--paper:#faf6ee;--accent:#6b3fb8}
*{box-sizing:border-box}
body{margin:0;padding:28px 32px 44px;background:var(--paper);color:var(--ink);
 font-family:"Microsoft YaHei","PingFang SC",system-ui,sans-serif;line-height:1.6}
h1{font-size:22px;margin:0 0 6px}
.lede{color:var(--sub);font-size:14px;margin:0 0 22px}
h2{font-size:16px;margin:26px 0 10px;padding-left:9px;border-left:4px solid var(--accent)}
.shot{margin:0 0 18px;border:1px solid var(--line);border-radius:10px;overflow:hidden;background:#fff}
.shot figcaption{display:flex;gap:10px;align-items:baseline;padding:8px 12px;font-size:13px;border-bottom:1px solid var(--line)}
.shot figcaption b{color:var(--accent)}
.shot figcaption span{color:var(--sub)}
.shot img{display:block;width:100%}
.pair{display:grid;grid-template-columns:1fr 34px 1fr;align-items:center;gap:8px;
 border:1px solid var(--line);border-radius:10px;background:#fff;padding:10px;margin-bottom:10px}
.pair .col{text-align:center}
.pair img{max-width:100%;border-radius:6px}
.pair i{display:block;margin-top:4px;font-size:12px;color:var(--sub);font-style:normal}
.pair .arrow{text-align:center;color:var(--accent);font-size:18px}
.note{font-size:13px;color:var(--sub);border:1px dashed var(--line);border-radius:8px;
 padding:10px 14px;background:#fffdf8}
code{background:#f0e9dc;padding:1px 5px;border-radius:4px;font-size:12px}
</style></head><body>
<h1>R628 独行（9189）吞卡特效 · 全素材化</h1>
<p class="lede">店长口径：「不要用这种文字特效，委托 codex 生成素材图，然后用素材图做特效」——
原来贴在目标卡上的「卡名 并入 +N」文字框已整段删除，改成三张 codex 出的法术贴图。</p>

<h2>素材：codex 纯文生图 → 黑底转透明</h2>
""" + pairs + """
<div class="note">三张都用纯黑底出图，<code>_finish_fx.py</code> 把<b>亮度当 alpha、色相归一化</b>——
发光法术不能走白底抠图，那会把边缘的辉光一起啃掉。光柱按真实柱体尺寸出（58×512），
不垫画布，否则代码里按画布宽拉伸就只剩一半粗。</div>

<h2>实机（同一场战斗的三个时点）</h2>
""" + "".join(shots) + """
<h2>实现要点</h2>
<div class="note">
· <b>吸取段（0~430ms）</b>：手牌处光环由外向内收 → 绞股光柱沿 from→to 铺满（只取纹理中段，两头渐隐会让柱子半路淡掉）
→ 头部虚空漩涡前推。<br>
· <b>吞噬段（430~850ms）</b>：漩涡张开收拢 + 收束光环向外炸 + 命中爆点，暗紫「独行 -15」26 号字与吞噬同帧落地。<br>
· 光柱用 <code>draw_set_transform</code> 旋到 from→to 方向，矩形必须从 0 起算——写成负值会把整根柱子甩到屏幕外。<br>
· 判定带 600ms 时间窗，同格后续挨的别的伤害不会被误标成独行；左栏仍不报最终伤害（R406 口径不动）。
</div>
</body></html>"""

out = os.path.join(PREV, "r628_lone_fx_report.html")
open(out, "w", encoding="utf-8", newline="\n").write(html)
print("written", out, os.path.getsize(out) // 1024, "KB")
