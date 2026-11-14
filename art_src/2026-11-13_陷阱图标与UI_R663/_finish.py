# -*- coding: utf-8 -*-
"""R663 陷阱素材后期：codex 方图 → 透明 PNG + 增量验收页。

用法：
    python _finish.py            # 干跑：处理所有已存在的 raw，写 processed/ 与对比页
    python _finish.py --write    # 额外落地到 assets/ui/（文件名即契约）

两路去背：
  · 4 张图标：边缘 flood-fill（与 R577b 同款），保住物体内部的白色；
  · 3 张 UI：全局近白 → 透明（元件本身是深色，中心留白必须一起抠掉，
    flood-fill 会被封闭边框挡住，所以不能用）。

R667（店长口径）：地图竖栏底不再单独出图，战斗/地图共用 trap_bar_battle。
当初确实出过的 trap_bar_map 只留在 raw/ 与 _unused/ 作档案，不再落地 assets/ui。

增量交付：只按「当前已存在的 raw」拼页，可反复重跑，不等整批齐全。
"""
import base64
import json
import shutil
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-13_陷阱图标与UI_R663"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"

ICONS = ["7001", "7002", "7003", "7004"]
UIS = ["trap_slot", "trap_bar_battle", "trap_group_tag"]
JOBS = ICONS + UIS
SIZE_ICON = (128, 128)
SIZE_UI = {
    "trap_slot": (128, 128),
    "trap_bar_battle": (96, 256),
    "trap_group_tag": (256, 64),
}
TOL = 38

_traps = json.loads((ROOT / "traps.json").read_text(encoding="utf-8"))["traps"]
NAMES = {str(t["id"]): str(t["name"]) for t in _traps}
NAMES.update({
    "trap_slot": "通用槽框",
    "trap_bar_battle": "竖栏底（战斗/地图共用）",
    "trap_group_tag": "商店分组牌",
})


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


def cutout_icon(src: Path, dst: Path):
    """边缘 flood-fill：只吃连通到四边的近白像素。"""
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
    coverage = opaque / float(w * h)
    bbox = out.getbbox()
    if bbox is None:
        return False, coverage, "全透明（去背把物体也吃掉了）"
    obj = out.crop(bbox)
    ow, oh = obj.size
    side = max(ow, oh)
    pad = int(side * 0.06)
    canvas = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(obj, ((canvas.width - ow) // 2, (canvas.height - oh) // 2))
    PROC.mkdir(parents=True, exist_ok=True)
    canvas.resize(SIZE_ICON, Image.LANCZOS).save(dst, "PNG")
    note = "疑似背景未去净（非透明占比 %.0f%%）" % (coverage * 100) if coverage > 0.62 else ""
    return True, coverage, note


def cutout_ui(src: Path, dst: Path, size):
    """全局近白 → 透明：封闭边框内部的留白也要一起抠掉。"""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    b0, b1, b2 = bg_color(im)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    opaque = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            d = ((r - b0) ** 2 + (g - b1) ** 2 + (b - b2) ** 2) ** 0.5
            a = _alpha(d, TOL)
            if a > 8:
                opaque += 1
            op[x, y] = (r, g, b, a)
    coverage = opaque / float(w * h)
    bbox = out.getbbox()
    if bbox is None:
        return False, coverage, "全透明（去背把元件也吃掉了）"
    obj = out.crop(bbox)
    PROC.mkdir(parents=True, exist_ok=True)
    obj.resize(size, Image.LANCZOS).save(dst, "PNG")
    note = "非透明占比 %.0f%%" % (coverage * 100)
    if coverage > 0.80:
        note = "疑似背景未去净（非透明占比 %.0f%%）" % (coverage * 100)
    return True, coverage, note


def out_name(key):
    return "trap_icon_%s.png" % key if key in ICONS else "%s.png" % key


HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>R663 陷阱素材 · 增量验收</title>
<style>
body{margin:0;padding:26px;background:#f5f2ea;color:#2b2b33;font-family:"Microsoft YaHei",sans-serif}
.wrap{max-width:1180px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:15px;margin:22px 0 10px;color:#6a5a40}
p{font-size:14px;line-height:1.8;color:#555;margin:0 0 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(178px,1fr));gap:12px}
.card{background:#fff;border:1px solid #d8cdb6;border-radius:8px;padding:10px 8px 8px;text-align:center}
.chk{height:132px;margin:0 auto 8px;border-radius:6px;border:1px solid #cfc6b3;display:flex;align-items:center;justify-content:center;overflow:hidden}
.chk.icon{background-color:#d9d5cc;
 background-image:linear-gradient(45deg,#c8c3b8 25%,transparent 25%),linear-gradient(-45deg,#c8c3b8 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#c8c3b8 75%),linear-gradient(-45deg,transparent 75%,#c8c3b8 75%);
 background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0}
.chk.ui{background:#2a2f3c}
.chk img{max-width:128px;max-height:126px}
.nm{font-size:13px;font-weight:700;color:#3b3226;line-height:1.4}
.id{font-size:11px;color:#8a8172;letter-spacing:.5px}
.warn{color:#b04a2f;font-size:11px;line-height:1.4;margin-top:4px}
.sum{font-size:13px;color:#6a5a40;margin:14px 0 0}
</style></head><body><div class="wrap">
<h1>R663 · 陷阱图标与栏位 UI（增量验收 __N__ / __TOTAL__）</h1>
<p>图标放棋盘格看白毛边；UI 元件放深灰底看透明留白。已完成的会随时补进来，不用等整批跑完。R667：地图与战斗共用同一张竖栏底，停用版留档不计入交付。</p>
__SECTIONS__
<p class="sum">已完成 __N__ 张 / 共 __TOTAL__ 张；待补：__MISS__</p>
</div></body></html>"""


def card_html(key, path, note):
    b64 = base64.b64encode(path.read_bytes()).decode("ascii")
    cls = "chk icon" if key in ICONS else "chk ui"
    warn = '<div class="warn">⚠ __NOTE__</div>'.replace("__NOTE__", note) if note else ""
    return ('<div class="card"><div class="__CLS__"><img src="data:image/png;base64,__B64__"></div>'
            '<div class="nm">__NAME__</div><div class="id">__ID__</div>__WARN__</div>'
            .replace("__CLS__", cls).replace("__B64__", b64)
            .replace("__NAME__", NAMES.get(key, key)).replace("__ID__", path.name)
            .replace("__WARN__", warn))


def main() -> int:
    PROC.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    write = "--write" in sys.argv
    done, miss, warns = [], [], []
    groups = {"陷阱图标 · 128×128 透明": ICONS, "栏位 UI · 透明叠加": UIS}
    sections = []
    for title, keys in groups.items():
        cards = []
        for key in keys:
            src = RAW / ("%s_codex.png" % key)
            if not src.exists():
                miss.append(key)
                continue
            dst = PROC / out_name(key)
            if key in ICONS:
                ok, cov, note = cutout_icon(src, dst)
            else:
                ok, cov, note = cutout_ui(src, dst, SIZE_UI[key])
            if not ok:
                warns.append("%s %s" % (key, note))
                continue
            if "疑似" in note:
                warns.append("%s %s" % (key, note))
            cards.append(card_html(key, dst, note if "疑似" in note else ""))
            done.append(key)
            if write:
                shutil.copyfile(dst, UI / dst.name)
        if cards:
            sections.append("<h2>%s</h2>\n<div class=\"grid\">%s</div>" % (title, "\n".join(cards)))

    html = (HTML.replace("__SECTIONS__", "\n".join(sections) or "<p>还没有成品，等后台第一张落盘。</p>")
            .replace("__N__", str(len(done))).replace("__TOTAL__", str(len(JOBS)))
            .replace("__MISS__", ("%d 张" % len(miss)) if miss else "无"))
    (REVIEW / "r663_trap_art.html").write_text(html, encoding="utf-8")
    print("done=%d miss=%d write=%s" % (len(done), len(miss), write), flush=True)
    print("review:", REVIEW / "r663_trap_art.html", flush=True)
    for w in warns[:20]:
        print("WARN", w, flush=True)
    if write:
        print("landed %d files into assets/ui" % len(done), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
