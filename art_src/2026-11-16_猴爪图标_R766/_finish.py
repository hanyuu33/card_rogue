# -*- coding: utf-8 -*-
"""R766 猴爪图标后期：codex 方图 → 128×128 透明 PNG（`assets/ui/relic_icon_6066.png`）+ 同族对比页。

去背：边缘 4-连通 flood-fill（与 R765 / R690 同一套；判据是与边缘背景色的 RGB 距离，
**不是亮度**）。猴爪是干枯褐皮 + 暗金属环，接近白底的只有一点点高光，
而它被黑描边包住，泛洪吃不到内部。

用法：
    python _finish.py            # 干跑：切图 + 对比页
    python _finish.py --write    # 额外落地到 assets/ui/
"""
import base64
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-16_猴爪图标_R766"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"

# claw = 第一版（细长垂挂，128 里只占宽 37%，与同族图标并排明显偏小）
# claw_c = 定稿：爪子蜷成团，宽 76 / 高 122，视觉重量与 relic_icon_6065 / 6069 对齐
KEY = "claw_c"
TARGET_ID = 6066
SIZE = (128, 128)
TOL = 30


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


def _alpha(d, tol):
    if d <= tol:
        return 0
    a = 255 if d >= tol * 1.6 else int(255 * (d - tol) / (tol * 0.6))
    return max(0, min(255, a))


def cutout(src: Path):
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
            a = _alpha(dist(x, y), TOL)
            if a > 8:
                opaque += 1
            r, g, b = px[x, y]
            op[x, y] = (r, g, b, a)
    return out, opaque / float(w * h)


def to_icon(obj: Image.Image, size=SIZE) -> Image.Image:
    bbox = obj.getbbox()
    if bbox is None:
        raise ValueError("全透明：去背把主体也吃掉了")
    body = obj.crop(bbox)
    cw, ch = size
    pad = int(cw * 0.03)
    s = min((cw - pad * 2) / float(body.width), (ch - pad * 2) / float(body.height))
    nw, nh = max(1, round(body.width * s)), max(1, round(body.height * s))
    body = body.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(body, ((cw - nw) // 2, (ch - nh) // 2))
    return canvas


HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>R766 猴爪图标 · 验收</title>
<style>
body{margin:0;padding:26px;background:#f5f2ea;color:#2b2b33;font-family:"Microsoft YaHei",sans-serif}
.wrap{max-width:1100px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:15px;margin:24px 0 10px;color:#6a5a40}
p{font-size:14px;line-height:1.8;color:#555;margin:0 0 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:14px}
.card{background:#fff;border:1px solid #d8cdb6;border-radius:8px;padding:10px 8px 8px;text-align:center}
.chk{height:140px;margin:0 auto 8px;border-radius:6px;border:1px solid #cfc6b3;display:flex;
 align-items:center;justify-content:center;overflow:hidden;background-color:#d9d5cc;
 background-image:linear-gradient(45deg,#c8c3b8 25%,transparent 25%),linear-gradient(-45deg,#c8c3b8 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#c8c3b8 75%),linear-gradient(-45deg,transparent 75%,#c8c3b8 75%);
 background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0}
.chk img{max-width:128px;max-height:136px}
.nm{font-size:13px;font-weight:700;color:#3b3226}
.id{font-size:11px;color:#8a8172}
.warn{color:#b04a2f;font-size:11px;margin-top:4px}
</style></head><body><div class="wrap">
<h1>R766 · 猴爪图标（relic_icon_6066.png）</h1>
<p>棋盘格看透明边。<b>同族检查</b>：猴爪要和已有的 relic_icon_* 是同一套画风
（厚黑描边、两段 cel shading、无底盘、物体居中占 ~74%）。</p>
__SECTIONS__
</div></body></html>"""


def card_html(name, sub, path, warn=""):
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    w = '<div class="warn">⚠ %s</div>' % warn if warn else ""
    return ('<div class="card"><div class="chk"><img src="data:image/png;base64,%s"></div>'
            '<div class="nm">%s</div><div class="id">%s</div>%s</div>' % (b64, name, sub, w))


def main() -> int:
    PROC.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    write = "--write" in sys.argv
    src = RAW / ("%s_codex.png" % KEY)
    if not src.exists():
        print("还没有成品：", src)
        return 1

    rgba, cov = cutout(src)
    icon = to_icon(rgba)
    dst = PROC / ("relic_icon_%d.png" % TARGET_ID)
    icon.save(dst, "PNG")
    warn = ""
    if cov < 0.06:
        warn = "非透明占比仅 %.1f%%，疑似去背吃掉主体" % (cov * 100)
    elif cov > 0.80:
        warn = "非透明占比 %.0f%%，疑似背景未去净" % (cov * 100)

    new_cards = [card_html("猴爪 6066（本轮）", "relic_icon_6066.png · 覆盖率 %.0f%%" % (cov * 100),
                           dst, warn)]
    peers = []
    for pid, pname in ((6065, "机械臂"), (6069, "诗"), (6049, "鹿首标本"), (6052, "竖琴")):
        p = UI / ("relic_icon_%d.png" % pid)
        if p.exists():
            peers.append(card_html("%s %d" % (pname, pid), p.name, p))

    html = HTML.replace("__SECTIONS__",
                        "<h2>本轮</h2>\n<div class=\"grid\">%s</div>" % "\n".join(new_cards)
                        + "<h2>既有同族（对照画风）</h2>\n<div class=\"grid\">%s</div>" % "\n".join(peers))
    (REVIEW / "r766_claw_icon.html").write_text(html, encoding="utf-8")

    if write:
        icon.save(UI / ("relic_icon_%d.png" % TARGET_ID), "PNG")
        print("landed", UI / ("relic_icon_%d.png" % TARGET_ID))

    print("coverage %.1f%%  warn=%s" % (cov * 100, warn or "none"))
    print("review:", REVIEW / "r766_claw_icon.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
