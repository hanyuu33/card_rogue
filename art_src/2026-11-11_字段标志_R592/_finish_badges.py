# -*- coding: utf-8 -*-
"""R592 字段标志后期：codex 图 → 128x128 无背景 PNG → assets/ui/affix_<glyph>.png

复用 R577b 的**边缘 flood-fill** 去背（不是全局阈值）：
标志的圆底是深色、外圈白底，用「从四边连通到背景色」判定，圆内的亮色符号不会被啃掉。

用法：
    python _finish_badges.py            # 干跑：只处理已存在的 raw 并拼验收页
    python _finish_badges.py --write    # 额外落地到 assets/ui/
可反复重跑（增量交付：有几张处理几张）。
"""
import base64
import io
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_字段标志_R592"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"
SIZE = 128
TOL = 30

GLYPHS = ["run", "taunt", "death", "ghost", "shield", "portal", "overload", "swap", "save", "share"]
LABELS = {
    "run": "疾行", "taunt": "嘲讽", "death": "死亡", "ghost": "幻影", "shield": "护盾",
    "portal": "次元", "overload": "超负荷", "swap": "交换", "save": "保存", "share": "共享护盾",
}
COLORS = {
    "run": ("#0e2e1a", "#3fbf6f"), "taunt": ("#331c05", "#ffa41f"),
    "death": ("#330f14", "#ff7a7a"), "ghost": ("#1f1a38", "#b79cff"),
    "shield": ("#0f2a33", "#6ec6ff"), "portal": ("#2a0d33", "#e58cff"),
    "overload": ("#33120a", "#ff7a3c"), "swap": ("#0a2a2e", "#5fe0d0"),
    "save": ("#1a2a0a", "#b9e85a"), "share": ("#33161c", "#ff8fa8"),
}


def bg_color(im):
    w, h = im.size
    pts = []
    for x in range(0, w, max(1, w // 24)):
        pts.append(im.getpixel((x, 0)))
        pts.append(im.getpixel((x, h - 1)))
    for y in range(0, h, max(1, h // 24)):
        pts.append(im.getpixel((0, y)))
        pts.append(im.getpixel((w - 1, y)))
    ch = []
    for c in range(3):
        vals = sorted(p[c] for p in pts)
        ch.append(vals[len(vals) // 2])
    return tuple(ch)


def cutout(src, dst):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    b0, b1, b2 = bg_color(im)

    def dist(x, y):
        r, g, b = px[x, y]
        return ((r - b0) ** 2 + (g - b1) ** 2 + (b - b2) ** 2) ** 0.5

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if dist(x, y) <= TOL:
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            k = y * w + x
            if not seen[k] and dist(x, y) <= TOL:
                seen[k] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                k = ny * w + nx
                if not seen[k] and dist(nx, ny) <= TOL:
                    seen[k] = 1
                    q.append((nx, ny))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    opaque = 0
    for y in range(h):
        for x in range(w):
            if seen[y * w + x]:
                continue
            d = dist(x, y)
            a = 255 if d >= TOL * 1.6 else int(255 * (d - TOL) / (TOL * 0.6))
            a = max(0, min(255, a))
            if a > 8:
                opaque += 1
            r, g, b = px[x, y]
            op[x, y] = (r, g, b, a)
    coverage = opaque / float(w * h)
    bbox = out.getbbox()
    if bbox is None:
        return False, coverage, "全透明"
    obj = out.crop(bbox)
    ow, oh = obj.size
    side = max(ow, oh)
    pad = int(side * 0.04)
    canvas = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    canvas.paste(obj, ((canvas.width - ow) // 2, (canvas.height - oh) // 2))
    canvas.resize((SIZE, SIZE), Image.LANCZOS).save(dst)
    return True, coverage, "ok"


def main():
    write = "--write" in sys.argv
    PROC.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    done, miss = [], []
    rows = []
    for g in GLYPHS:
        src = RAW / ("%s_codex.png" % g)
        if not src.exists():
            miss.append(g)
            continue
        dst = PROC / ("affix_%s.png" % g)
        ok, cov, note = cutout(src, dst)
        if not ok:
            print("[FAIL] %s：%s（覆盖 %.1f%%）" % (g, note, cov * 100))
            continue
        if cov < 0.18 or cov > 0.92:
            print("[WARN] %s 覆盖率 %.1f%% —— 可能去背没干净或把徽章啃了" % (g, cov * 100))
        if write:
            UI.mkdir(parents=True, exist_ok=True)
            import shutil
            shutil.copyfile(dst, UI / ("affix_%s.png" % g))
        done.append(g)
        rows.append((g, cov))

    # ---- 验收页（读 processed 里的 128 图 + 放大预览）----
    cards = []
    for g, cov in rows:
        p = PROC / ("affix_%s.png" % g)
        b64 = base64.b64encode(p.read_bytes()).decode("ascii")
        bg, fg = COLORS[g]
        # 同时在卡图色（深绿）上预览一次，确认在真实卡面上不糊
        cards.append("""
    <div class="c">
      <div class="hd"><b>%s</b><span class="g">affix_%s.png</span><span class="cov">%.0f%%</span></div>
      <div class="row">
        <div class="onpaper"><img src="data:image/png;base64,%s"></div>
        <div class="onart"><img src="data:image/png;base64,%s"></div>
      </div>
      <div class="sz"><img src="data:image/png;base64,%s"><span>24px</span>
        <img class="s18" src="data:image/png;base64,%s"><span>18px</span></div>
    </div>""" % (LABELS[g], g, cov * 100, b64, b64, b64, b64))

    html = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>R592 字段标志 · 去背与尺寸验收</title>
<style>
 body{margin:0;padding:28px 22px 60px;background:#f4ecdc;color:#3a2e1e;
      font-family:"Noto Serif SC","SimSun",serif}
 h1{font-size:23px;margin:0 0 6px}
 .sub{color:#8a7a63;font-size:13px;margin-bottom:20px}
 .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
 .c{background:#fffdf7;border:1px solid #d8c8a8;border-radius:10px;overflow:hidden}
 .hd{display:flex;align-items:baseline;gap:8px;padding:9px 13px;border-bottom:1px dashed #d8c8a8;
     background:linear-gradient(#fffdf7,#faf3e3)}
 .hd b{font-size:15px} .g{font-family:ui-monospace,Consolas,monospace;font-size:11.5px;color:#8a7a63}
 .cov{margin-left:auto;font-size:11.5px;color:#8a7a63}
 .row{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:10px 13px 4px}
 .onpaper,.onart{display:flex;align-items:center;justify-content:center;height:96px;border-radius:8px}
 .onpaper{background:#efe6d0} .onart{background:#1d3a26}
 .row img{width:74px;height:74px;image-rendering:auto}
 .sz{display:flex;align-items:center;gap:6px;padding:6px 13px 12px;font-size:11px;color:#8a7a63}
 .sz img{width:24px;height:24px} .sz img.s18{width:18px;height:18px}
</style></head><body>
<h1>R592 · 字段标志：去背与尺寸</h1>
<div class="sub">左＝浅羊皮纸底，右＝卡图深绿底；下方是真实显示尺寸（24px / 18px）。
已处理 <b>%d</b>/10 张%s</div>
<div class="grid">%s</div></body></html>""" % (
        len(done), ("" if not miss else "（缺：%s）" % "、".join(LABELS[m] for m in miss)),
        "".join(cards))
    (REVIEW / "badges.html").write_text(html, encoding="utf-8")

    print("处理完成：%d 张 -> %s" % (len(done), PROC))
    if miss:
        print("还没出图：%s" % "、".join(miss))
    print("验收页：%s" % (REVIEW / "badges.html"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
