# -*- coding: utf-8 -*-
"""R577f 离线高保真预览：P1 改版「单层转动 + 蓝色边缘光」。

不碰游戏代码，只用 assets/ui/relic_icon_*.png 真实素材合成右栏道具区，
把「现状」与「单层转动 + 蓝色边缘光」做成同基准 2.4s 的可播放对比。

产物（_preview/ 保持 untracked）：
  r577f_preview.html  两栏逐帧播放，PNG base64 内嵌
  r577f_still.png     三格拆解：原色 / 加蓝色边缘光 / 再加暖黄转动层
可重跑；生成 HTML 一律占位 + replace，不用 % 格式化（CSS 里的 % 会炸）。
"""
import os
import io
import base64
import math
import json
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

ROOT = r'E:/work/card_rogue'
ICON_DIR = os.path.join(ROOT, 'assets', 'ui')
OUT = os.path.join(ROOT, '_preview')
os.makedirs(OUT, exist_ok=True)

IDS = [6042, 6012, 6022, 6037, 6058, 6060,   # R577e --relichl 的 6 亮
       6006, 6044, 6041, 6009, 6043, 6052]   # 6 灭
LIT = set(range(6))

W, H = 370, 250
CELL = 44
STEP_X = min(104.0, (310.0 - CELL) / 5.0)   # R577d：一行 6 个时步距 53.2
ROW_STEP = 48.0
X0 = (W - (5.0 * STEP_X + CELL)) / 2.0
Y0 = 58.0
FRAMES = 24
CYCLE_S = 2.4

PAPER = (237, 227, 203, 255)
PAPER_EDGE = (138, 116, 72, 255)
TITLE_COL = (122, 98, 48, 255)
OLD_RING = (143, 235, 255)
BLUE_RIM = (86, 178, 255)
BLUE_HALO = (56, 138, 240)
# 店长口径 R577f-2：转动层换回上一轮 P1 的暖琥珀 #FFD89A；
# 蓝色边缘光保持不变（冷蓝 rim + 暖黄弧）。尾部压深一档，浅米底上才看得见。
SWEEP_HEAD = (255, 222, 150)
SWEEP_TAIL = (214, 140, 40)


def font(sz):
    for p in ('C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf'):
        if os.path.isfile(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()


def load_icon(rid):
    p = os.path.join(ICON_DIR, 'relic_icon_%d.png' % rid)
    im = Image.open(p).convert('RGBA')
    return im.resize((CELL, CELL), Image.LANCZOS)


def cells():
    out = []
    for row in (0, 1):
        for col in range(6):
            out.append((int(round(X0 + col * STEP_X)), int(round(Y0 + row * ROW_STEP))))
    return out


CELLS = cells()
ICONS = [load_icon(i) for i in IDS]


def old_modulate(im):
    """模拟 modulate >1 在 LDR 下被钳到 1：亮部爆白、整体泛青。"""
    r, g, b, a = im.split()
    r = r.point(lambda v: min(255, int(v * 1.10 + 8)))
    g = g.point(lambda v: min(255, int(v * 1.22 + 12)))
    b = b.point(lambda v: min(255, int(v * 1.34 + 16)))
    return Image.merge('RGBA', (r, g, b, a))


def new_tint(im):
    """新版：保留原色与暗部，只给极轻的冷蓝。"""
    r, g, b, a = im.split()
    g = g.point(lambda v: min(255, int(v + 2)))
    b = b.point(lambda v: min(255, int(v + 6)))
    return Image.merge('RGBA', (r, g, b, a))


def make_glow():
    """现状 fx_glow.png 的等价物：中心亮斑（中心 alpha 高、1/4 处已很低）。"""
    s = 70
    m = Image.new('L', (s, s), 0)
    d = ImageDraw.Draw(m)
    c = s / 2.0
    for i in range(int(c), 0, -1):
        v = int(249 * (1.0 - i / c) ** 2.6)
        d.ellipse([c - i, c - i, c + i, c + i], fill=v)
    g = Image.new('RGBA', (s, s), (255, 250, 240, 0))
    g.putalpha(m)
    return g


def rim_layers(icon):
    """蓝色边缘光：沿贴图 alpha 外缘做一圈贴边光 + 一圈极淡外扩。"""
    pad = 6
    big = Image.new('RGBA', (CELL + pad * 2, CELL + pad * 2), (0, 0, 0, 0))
    big.alpha_composite(icon, (pad, pad))
    a = big.getchannel('A')
    d1 = a.filter(ImageFilter.MaxFilter(5))
    r1 = ImageChops.subtract(d1, a)
    d2 = d1.filter(ImageFilter.MaxFilter(5))
    r2 = ImageChops.subtract(d2, d1)

    def tint(mask, col, strength):
        m = mask.point(lambda v: int(v * strength))
        out = Image.new('RGBA', big.size, (col[0], col[1], col[2], 0))
        out.putalpha(m)
        return out

    return big.size, tint(r2, BLUE_HALO, 0.24), tint(r1, BLUE_RIM, 0.88), pad


RIMS = {}
for _i in sorted(LIT):
    RIMS[_i] = rim_layers(ICONS[_i])


def sweep_layer(angle_deg):
    """唯一动态光效层：一段带渐隐拖尾的弧，绕图标缓慢转动。"""
    s = 76
    c = s / 2.0
    rad = 31.0
    layer = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    seg = 11.0
    for j in range(9):
        a1 = angle_deg - j * seg
        a0 = a1 - seg
        k = 1.0 - j / 9.0
        alpha = int(240 * (k ** 1.7))
        col = (int(SWEEP_TAIL[0] + (SWEEP_HEAD[0] - SWEEP_TAIL[0]) * k),
               int(SWEEP_TAIL[1] + (SWEEP_HEAD[1] - SWEEP_TAIL[1]) * k),
               int(SWEEP_TAIL[2] + (SWEEP_HEAD[2] - SWEEP_TAIL[2]) * k),
               alpha)
        pts = []
        for q in range(5):
            t = math.radians(a0 + (a1 - a0) * q / 4.0)
            pts.append((c + rad * math.cos(t), c + rad * math.sin(t)))
        d.line(pts, fill=col, width=3, joint='curve')
    return layer


def base_canvas():
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([8, 8, W - 8, H - 8], radius=10, fill=PAPER,
                        outline=PAPER_EDGE, width=2)
    f = font(14)
    t = '道具 12'
    tw = d.textlength(t, font=f)
    d.text(((W - tw) / 2.0, 18), t, font=f, fill=TITLE_COL)
    for i, (x, y) in enumerate(CELLS):
        im.alpha_composite(ICONS[i], (x, y))
    return im


BASE = base_canvas()
GLOW = make_glow()


def frame(k, mode):
    im = BASE.copy()
    d = ImageDraw.Draw(im)
    ph = 0.5 + 0.5 * math.sin(2.0 * math.pi * k / FRAMES)
    ang = 360.0 * k / FRAMES
    for i in sorted(LIT):
        x, y = CELLS[i]
        cx, cy = x + CELL / 2.0, y + CELL / 2.0
        if mode == 'old':
            g = GLOW.copy()
            ga = g.getchannel('A').point(lambda v: int(v * (0.30 + 0.22 * ph)))
            g.putalpha(ga)
            im.alpha_composite(g, (int(cx - 35), int(cy - 35)))
            im.alpha_composite(old_modulate(ICONS[i]), (x, y))
            d = ImageDraw.Draw(im)
            r = CELL * 0.66
            d.ellipse([cx - r, cy - r, cx + r, cy + r],
                      outline=OLD_RING + (int(255 * (0.72 + 0.24 * ph)),), width=3)
        else:
            size, halo, rim, pad = RIMS[i]
            im.alpha_composite(halo, (x - pad, y - pad))
            im.alpha_composite(rim, (x - pad, y - pad))
            im.alpha_composite(new_tint(ICONS[i]), (x, y))
            # 单层不变，但每格按格位错开一点相位：六条弧像一道光波扫过，
            # 而不是六条一模一样的弧一起转（齐转 = 齐闪，同样显廉价）。
            im.alpha_composite(sweep_layer(ang + float(i) * 22.0),
                               (int(cx - 38), int(cy - 38)))
    return im.convert('RGB')


def png_data_uri(im):
    buf = io.BytesIO()
    im.save(buf, format='PNG', optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


def single_tile(kind, k=6):
    """76x76 独立单格：不裁整栏，避免把相邻格的碎片带进拆解图。"""
    s = 76
    c = s / 2.0
    im = Image.new('RGBA', (s, s), PAPER)
    x, y = int(c - CELL / 2.0), int(c - CELL / 2.0)
    idx = 0
    if kind == 'plain':
        im.alpha_composite(ICONS[idx], (x, y))
        return im.convert('RGB')
    size, halo, rim, pad = RIMS[idx]
    im.alpha_composite(halo, (x - pad, y - pad))
    im.alpha_composite(rim, (x - pad, y - pad))
    im.alpha_composite(new_tint(ICONS[idx]), (x, y))
    if kind == 'full':
        im.alpha_composite(sweep_layer(360.0 * k / FRAMES), (0, 0))
    return im.convert('RGB')


def make_still():
    """三格拆解，放大 3 倍看边缘光与转动层的分工。"""
    tiles = [('原色', single_tile('plain')),
             ('＋蓝色边缘光', single_tile('rim')),
             ('＋暖黄转动层', single_tile('full'))]
    S = 3
    tw, th = 76 * S, 76 * S
    gap, top = 16, 34
    out = Image.new('RGB', (tw * 3 + gap * 4, th + top + 16), (250, 247, 238))
    d = ImageDraw.Draw(out)
    f = font(13)
    for j, (label, tile) in enumerate(tiles):
        ox = gap + j * (tw + gap)
        d.text((ox + 4, 10), label, font=f, fill=(90, 74, 46))
        out.paste(tile.resize((tw, th), Image.LANCZOS), (ox, top))
    p = os.path.join(OUT, 'r577f_still.png')
    out.save(p)
    return p


def make_bar_compare(k=6):
    """整栏同帧并排，看 6 亮 + 6 灭在真实排版里的观感。"""
    a = frame(k, 'old')
    b = frame(k, 'new')
    S = 2
    left = 12
    gap = 18
    out = Image.new('RGB', (left * 2 + W * S * 2 + gap, H * S + 46), (250, 247, 238))
    d = ImageDraw.Draw(out)
    f = font(14)
    d.text((left + 4, 10), '现状：中心亮斑 + 完整硬环 + 同相齐闪', font=f, fill=TITLE_COL[:3])
    d.text((left + W * S + gap + 4, 10),
           '新版：暖黄转动弧 + 蓝色边缘光', font=f, fill=TITLE_COL[:3])
    out.paste(a.resize((W * S, H * S), Image.LANCZOS), (left, 40))
    out.paste(b.resize((W * S, H * S), Image.LANCZOS), (left + W * S + gap, 40))
    p = os.path.join(OUT, 'r577f_bar_compare.png')
    out.save(p)
    return p


def make_yellow_tone():
    """暖黄弧在浅米 HUD 底上偏淡：并排三档深浅给店长挑，默认仍是 P1 原黄。"""
    global SWEEP_HEAD, SWEEP_TAIL
    presets = [
        ('P1 原黄 #FFD89A', (255, 222, 150), (214, 140, 40)),
        ('加深一档', (255, 208, 108), (196, 112, 24)),
        ('加深两档', (255, 194, 76), (168, 86, 14)),
    ]
    saved = (SWEEP_HEAD, SWEEP_TAIL)
    tiles = []
    try:
        for label, head, tail in presets:
            SWEEP_HEAD, SWEEP_TAIL = head, tail
            tiles.append((label, single_tile('full')))
    finally:
        SWEEP_HEAD, SWEEP_TAIL = saved
    S = 3
    tw = th = 76 * S
    gap, top = 16, 34
    out = Image.new('RGB', (tw * 3 + gap * 4, th + top + 16), (250, 247, 238))
    d = ImageDraw.Draw(out)
    f = font(13)
    for j, (label, tile) in enumerate(tiles):
        ox = gap + j * (tw + gap)
        d.text((ox + 4, 10), label, font=f, fill=(90, 74, 46))
        out.paste(tile.resize((tw, th), Image.LANCZOS), (ox, top))
    p = os.path.join(OUT, 'r577f_yellow_tone.png')
    out.save(p)
    return p


def make_html(a, b):
    tpl = '''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R577f · 暖黄转动弧 + 蓝色边缘光</title>
<style>
*{box-sizing:border-box}
body{margin:0;padding:20px;background:#faf7ef;color:#3b3226;font:14px/1.6 "Microsoft YaHei",sans-serif}
h1{font-size:18px;font-weight:500;margin:0 0 6px}
.note{color:#7a6d55;font-size:13px;margin:0 0 14px}
.bar{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-bottom:14px}
button{padding:5px 14px;border:1px solid #c9b98f;background:#fffdf6;border-radius:6px;cursor:pointer;color:#3b3226;font-size:13px}
input[type=range]{width:150px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:16px}
.card{background:#fffdf6;border:1px solid #d8cba9;border-radius:10px;padding:12px}
.card h2{font-size:15px;font-weight:500;margin:0 0 8px}
.card img{width:100%;display:block;image-rendering:auto;border-radius:6px}
.card p{font-size:12px;color:#8a7c60;margin:8px 0 0}
</style></head><body>
<h1>P1 改版 · 暖黄转动弧 + 蓝色边缘光</h1>
<p class="note">真实道具图标合成；两栏同基准 2.4s（游戏里现状实为 1.38s）。前 6 件亮、后 6 件灭。</p>
<div class="bar"><button id="play">暂停</button><span>帧间隔</span><input id="spd" type="range" min="40" max="220" value="100"><span id="lab">100 ms</span></div>
<div class="grid">
<div class="card"><h2>现状</h2><img id="ia" alt="现状"><p>中心亮斑柔光 + 图标整体泛青白 + 完整硬边青环，全部同相一起闪。</p></div>
<div class="card"><h2>暖黄转动弧 + 蓝色边缘光</h2><img id="ib" alt="新版"><p>删掉柔光底斑与完整硬环；只留一圈 P1 暖琥珀色的带拖尾弧缓慢转动，图标沿轮廓贴一圈冷蓝边（恒定，不呼吸）。</p></div>
</div>
<script>
var A=__A__,B=__B__,i=0,playing=true,ms=100,timer=null;
function step(){document.getElementById('ia').src=A[i];document.getElementById('ib').src=B[i];i=(i+1)%A.length;}
function loop(){if(!playing)return;step();timer=setTimeout(loop,ms);}
step();loop();
document.getElementById('play').onclick=function(){playing=!playing;this.textContent=playing?'暂停':'播放';if(playing){clearTimeout(timer);loop();}else{clearTimeout(timer);}};
document.getElementById('spd').oninput=function(){ms=Number(this.value);document.getElementById('lab').textContent=ms+' ms';};
</script></body></html>'''
    html = tpl.replace('__A__', json.dumps(a, separators=(',', ':')))
    html = html.replace('__B__', json.dumps(b, separators=(',', ':')))
    p = os.path.join(OUT, 'r577f_preview.html')
    with open(p, 'wb') as f:
        f.write(html.encode('utf-8'))
    return p


def main():
    a = [png_data_uri(frame(k, 'old')) for k in range(FRAMES)]
    b = [png_data_uri(frame(k, 'new')) for k in range(FRAMES)]
    hp = make_html(a, b)
    sp = make_still()
    bp = make_bar_compare()
    yp = make_yellow_tone()
    print('HTML', hp, os.path.getsize(hp) // 1024, 'KB')
    print('STILL', sp, os.path.getsize(sp) // 1024, 'KB')
    print('BAR', bp, os.path.getsize(bp) // 1024, 'KB')
    print('TONE', yp, os.path.getsize(yp) // 1024, 'KB')
    print('FRAMES', FRAMES, 'CELLS', len(CELLS), 'STEP_X', round(STEP_X, 1))


if __name__ == '__main__':
    main()
