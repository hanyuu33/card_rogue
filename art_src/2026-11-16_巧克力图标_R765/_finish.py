# -*- coding: utf-8 -*-
"""R765 巧克力图标后期：codex 方图 → 透明 PNG（320×148）+ 新旧对比验收页。

去背：边缘 4-连通 flood-fill（与 R690 / R577b 同款）。
⚠️ 锡纸是银灰高光，贴近白底 —— 所以判据不用「亮度」，而是「与边缘背景色的 RGB 距离」，
   且只吃**连通到四边**的像素；锡纸被黑描边围住，内部反光不会被误吃。TOL 默认 30。

画布：内容等比装进 320×148（= 地图 HUD 的 52×24 框，比例 2.1667:1），居中留边。
      `map_scene._draw_choco_icon()` 用 `CardFace.fit_rect` 等比缩放，不拉伸。

用法：
    python _finish.py            # 干跑：处理 raw/ 里已存在的图，写 processed/ 与对比页
    python _finish.py --write    # 额外把 choco_a 落成 assets/ui/chocolate.png
    python _finish.py --pick choco_b --write   # 指定定稿候选
"""
import base64
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-16_巧克力图标_R765"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"

KEYS = ["choco_a", "choco_b"]
CANVAS = (320, 148)
TOL = 30
# 定稿调色（Brightness / Contrast / Color）：原样出图放在地图的深绿面板上偏灰 ——
# 锡纸是冷银灰、巧克力是暗棕，两头都不跳。只提一档，不改色相、不动 alpha。
TONE = (1.09, 1.07, 1.20)
OLD = UI / "chocolate.png"


def tune(im: Image.Image, b=1.0, c=1.0, s=1.0) -> Image.Image:
    """只调 RGB，alpha 原样保留。"""
    r, g, bl, a = im.split()
    rgb = Image.merge("RGB", (r, g, bl))
    rgb = ImageEnhance.Brightness(rgb).enhance(b)
    rgb = ImageEnhance.Contrast(rgb).enhance(c)
    rgb = ImageEnhance.Color(rgb).enhance(s)
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def bg_color(im):
    """四边取样中位数 → 背景色。"""
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
    """边缘 flood-fill 去背 → 返回 (RGBA 整图, 非透明覆盖率)。"""
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


def to_canvas(obj: Image.Image, size=CANVAS) -> Image.Image:
    """等比装进 size，居中留边（留 4% 边距）。"""
    bbox = obj.getbbox()
    if bbox is None:
        raise ValueError("全透明：去背把物体也吃掉了")
    body = obj.crop(bbox)
    cw, ch = size
    pad_x, pad_y = int(cw * 0.02), int(ch * 0.04)
    max_w, max_h = cw - pad_x * 2, ch - pad_y * 2
    s = min(max_w / float(body.width), max_h / float(body.height))
    nw, nh = max(1, round(body.width * s)), max(1, round(body.height * s))
    body = body.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(body, ((cw - nw) // 2, (ch - nh) // 2))
    return canvas


HTML_HEAD = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>R765 巧克力图标 · 验收</title>
<style>
body{margin:0;padding:26px;background:#f5f2ea;color:#2b2b33;font-family:"Microsoft YaHei",sans-serif}
.wrap{max-width:1180px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:15px;margin:26px 0 10px;color:#6a5a40}
p{font-size:14px;line-height:1.8;color:#555;margin:0 0 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:16px}
.card{background:#fff;border:1px solid #d8cdb6;border-radius:8px;padding:12px;text-align:center}
.chk{border-radius:6px;border:1px solid #cfc6b3;padding:10px;margin-bottom:8px;
 background-color:#d9d5cc;
 background-image:linear-gradient(45deg,#c8c3b8 25%,transparent 25%),linear-gradient(-45deg,#c8c3b8 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#c8c3b8 75%),linear-gradient(-45deg,transparent 75%,#c8c3b8 75%);
 background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0}
.chk img{display:block;margin:0 auto;image-rendering:auto}
.hud{margin-top:8px;background:#2a2118;border-radius:5px;padding:8px 10px;display:inline-flex;align-items:center;gap:6px}
.hud img{image-rendering:pixelated}
.hud span{color:#f4e3c8;font:700 13px "Microsoft YaHei",sans-serif}
.nm{font-size:13px;font-weight:700;color:#3b3226;line-height:1.5}
.id{font-size:11px;color:#8a8172;letter-spacing:.5px}
.warn{color:#b04a2f;font-size:11px;line-height:1.5;margin-top:4px}
.sum{font-size:13px;color:#6a5a40;margin:16px 0 0}
</style></head><body><div class="wrap">
<h1>R765 · 巧克力图标改版（锡纸包一半 + 咬一口）</h1>
<p>每张都放棋盘格看透明边；下面那条深色小条是<b>地图 HUD 里的真实尺寸</b>（图标 52×24 等比缩放 + 右侧 ×N），
用来判断「缩到这么小还看不看得出是巧克力」——这一轮的问题恰恰出在缩到 52×24 之后。</p>
__SECTIONS__
<p class="sum">__SUM__</p>
</div></body></html>"""


def card(title, sub, path: Path, note="", box_w=320, box_h=148):
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    warn = '<div class="warn">⚠ %s</div>' % note if note else ""
    return ("""<div class="card">
<div class="chk"><img src="data:image/png;base64,__B64__" width="__W__" height="__H__"></div>
<div class="nm">__T__</div><div class="id">__S__</div>__WARN__
<div class="hud"><img src="data:image/png;base64,__B64__" width="156" height="__HH__"><span>×3</span></div>
</div>""".replace("__B64__", b64).replace("__T__", title).replace("__S__", sub)
            .replace("__W__", str(box_w)).replace("__H__", str(box_h))
            .replace("__HH__", str(round(72 * box_h / float(box_w))))
            .replace("__WARN__", warn))


def main() -> int:
    PROC.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    write = "--write" in sys.argv
    pick = "choco_a"
    if "--pick" in sys.argv:
        pick = sys.argv[sys.argv.index("--pick") + 1]

    # ⚠️ 旧版必须在 --write 覆盖之前就读进内存，否则下面「旧版」那张卡展示的是刚落地的新图。
    old_img = Image.open(OLD).convert("RGBA") if OLD.exists() else None
    old_size = old_img.size if old_img is not None else (0, 0)

    cards, notes, done = [], [], []
    for key in KEYS:
        src = RAW / ("%s_codex.png" % key)
        if not src.exists():
            notes.append("%s 未出图" % key)
            continue
        rgba, cov = cutout(src)
        dst = PROC / ("%s.png" % key)
        dst_warm = PROC / ("%s_warm.png" % key)
        canvas = to_canvas(rgba)
        canvas.save(dst, "PNG")
        warm = tune(canvas, *TONE)
        warm.save(dst_warm, "PNG")
        done.append(key)
        note = ""
        if cov < 0.06:
            note = "非透明占比仅 %.1f%%，疑似去背吃掉了主体" % (cov * 100)
        elif cov > 0.80:
            note = "非透明占比 %.0f%%，疑似背景未去净" % (cov * 100)
        if note:
            notes.append("%s %s" % (key, note))
        cards.append(card("%s（%s）" % (key, "定稿" if key == pick else "候选"),
                          "choco/%s_codex.png · 覆盖率 %.0f%%%s" % (
                              key, cov * 100, " · 已调色" if key == pick else ""),
                          dst_warm, note))
        if write and key == pick:
            warm.save(UI / "chocolate.png", "PNG")

    old_cards = []
    if old_img is not None:
        # 落地时 OLD 会被覆盖 → 展示源优先用备份的那份。
        old_bak = PROC / "_old_chocolate_R128.png"
        if write and not old_bak.exists():
            old_img.save(old_bak, "PNG")
        old_src = old_bak if old_bak.exists() else OLD
        old_cards.append(card("旧版（改版前）", "%s · %d×%d" % (old_src.name, old_size[0], old_size[1]),
                              old_src, box_w=min(320, old_size[0]),
                              box_h=round(old_size[1] * min(320, old_size[0]) / old_size[0])))

    sums = "定稿 %s；候选 %s；未出图 %s" % (pick, ", ".join(k for k in done if k != pick) or "无",
                                       ", ".join(notes) or "无")
    html = (HTML_HEAD.replace("__SECTIONS__",
                              "<h2>旧版</h2>\n<div class=\"grid\">%s</div>" % "\n".join(old_cards)
                              + "<h2>本轮候选</h2>\n<div class=\"grid\">%s</div>" % "\n".join(cards))
            .replace("__SUM__", sums))
    (REVIEW / "r765_choco.html").write_text(html, encoding="utf-8")
    print("done=%s write=%s pick=%s" % (done, write, pick), flush=True)
    print("review:", REVIEW / "r765_choco.html", flush=True)
    for n in notes:
        print("NOTE", n, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
