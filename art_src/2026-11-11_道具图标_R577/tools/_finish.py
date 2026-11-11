# -*- coding: utf-8 -*-
"""R577b 后期：codex 宽图 → 128x128 无背景 RGBA 图标 + 增量验收页。

用法：
    python _finish.py              # 干跑：处理所有已存在的 raw，写 processed/ 与对比页
    python _finish.py --write      # 额外把 processed 落地到 assets/ui/relic_icon_<id>.png

增量交付：只按「当前已存在的 raw」拼页，不要求整批齐全；可反复重跑。
去背用**边缘 flood-fill**（不是全局阈值），避免把物体内部的白色（鸭绒 / 牛奶 / 绷带）
一起抠掉；物体轮廓是粗黑描边，天然封闭。
"""
import base64
import json
import shutil
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_道具图标_R577"
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"
SIZE = 128
TOL_DEFAULT = 38  # 与背景色的欧氏距离容差（cutout 里可用 tol_override 覆盖）
# ⚠️ 6018 白蛋：蛋壳 RGB(253,248,238) 与纯白底 (254,254,254) 只差约 17；
#   TOL>=14 会穿过抗锯齿描边把蛋壳 flood 成透明（只剩一圈黑轮廓，中心不透明率 2%）。
#   实测 TOL=6/10 都保住完整白蛋且背景干净，取 10 留一点噪点余量。
TOL_BY_ID = {6018: 10}
# 6013 是满幅方形木箱，非透明占比 62% 属正常构图，不是「背景没去净」。
COVERAGE_OK_IDS = {6013}
# 60 件道具；6061~6063 三样信物已有 key_icon_*.png（R543），不重出。
IDS = list(range(6001, 6061))

relics = json.loads((ROOT / "relics.json").read_text(encoding="utf-8"))["relics"]
NAMES = {int(r["id"]): str(r["name"]) for r in relics}


def bg_color(im: Image.Image):
    """四边采样取中位数当背景色（模型可能给米白而不是纯白）。"""
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


def cutout(src: Path, dst: Path, tol_override=None):
    tol = TOL_DEFAULT if tol_override is None else tol_override
    """返回 (ok, coverage, note)。coverage = 非透明像素占比，用来抓「背景没去干净」。"""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    bg = bg_color(im)
    b0, b1, b2 = bg

    def dist(x, y):
        r, g, b = px[x, y]
        return ((r - b0) ** 2 + (g - b1) ** 2 + (b - b2) ** 2) ** 0.5

    # 从四边出发的 flood fill：只有「与背景色相近」且**连通到边缘**的才算背景
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if dist(x, y) <= tol:
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            k = y * w + x
            if not seen[k] and dist(x, y) <= tol:
                seen[k] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                k = ny * w + nx
                if not seen[k] and dist(nx, ny) <= tol:
                    seen[k] = 1
                    q.append((nx, ny))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    opaque = 0
    for y in range(h):
        for x in range(w):
            k = y * w + x
            if seen[k]:
                continue
            d = dist(x, y)
            # 抗锯齿边缘：靠背景色的那一圈给半透明，别留白毛边
            a = 255 if d >= tol * 1.6 else int(255 * (d - tol) / (tol * 0.6))
            a = max(0, min(255, a))
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
    # 等比收进带 6% 内边距的正方形画布
    side = max(ow, oh)
    pad = int(side * 0.06)
    canvas = Image.new("RGBA", (side + pad * 2, side + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(obj, ((canvas.width - ow) // 2, (canvas.height - oh) // 2))
    icon = canvas.resize((SIZE, SIZE), Image.LANCZOS)
    PROC.mkdir(parents=True, exist_ok=True)
    icon.save(dst, "PNG")
    return True, coverage, ""


HTML = """<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><title>R577b 道具图标 · 增量验收</title>
<style>
body{margin:0;padding:26px;background:#f5f2ea;color:#2b2b33;font-family:"Microsoft YaHei",sans-serif}
.wrap{max-width:1280px;margin:0 auto}
h1{font-size:20px;margin:0 0 4px}
p{font-size:14px;line-height:1.8;color:#555;margin:0 0 18px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(148px,1fr));gap:12px}
.card{background:#fff;border:1px solid #d8cdb6;border-radius:8px;padding:10px 8px 8px;text-align:center}
.chk{width:104px;height:104px;margin:0 auto 8px;border-radius:6px;border:1px solid #cfc6b3;
 background-color:#d9d5cc;
 background-image:linear-gradient(45deg,#c8c3b8 25%,transparent 25%),linear-gradient(-45deg,#c8c3b8 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#c8c3b8 75%),linear-gradient(-45deg,transparent 75%,#c8c3b8 75%);
 background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0;display:flex;align-items:center;justify-content:center}
.chk img{width:96px;height:96px;image-rendering:auto}
.nm{font-size:13px;font-weight:700;color:#3b3226;line-height:1.4}
.id{font-size:11px;color:#8a8172;letter-spacing:.5px}
.warn{color:#b04a2f;font-size:11px;line-height:1.4;margin-top:4px}
.sum{font-size:13px;color:#6a5a40;margin:14px 0 0}
</style></head><body><div class="wrap">
<h1>R577b · 道具图标（增量验收 __N__ / __TOTAL__）</h1>
<p>透明底图标放在棋盘格上，方便看无背景效果与边缘白毛。已完成的会随时补进来，不用等整批跑完。</p>
<div class="grid">__CARDS__</div>
<p class="sum">已完成 __N__ 张 / 共 __TOTAL__ 张；待补：__MISS__</p>
</div></body></html>"""


def main() -> int:
    PROC.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    write = "--write" in sys.argv
    cards, done, miss, warns = [], [], [], []
    for cid in IDS:
        src = RAW / ("%d_codex.png" % cid)
        dst = PROC / ("relic_icon_%d.png" % cid)
        if not src.exists():
            miss.append(cid)
            continue
        ok, cov, note = cutout(src, dst, TOL_BY_ID.get(cid))
        if cov > 0.62 and cid not in COVERAGE_OK_IDS:
            note = "疑似背景未去净（非透明占比 %.0f%%）" % (cov * 100)
        if not ok:
            warns.append("%d %s" % (cid, note))
            continue
        if note:
            warns.append("%d %s" % (cid, note))
        b64 = base64.b64encode(dst.read_bytes()).decode("ascii")
        cards.append(
            '<div class="card"><div class="chk"><img src="data:image/png;base64,__B64__" alt="__ID__"></div>'
            '<div class="nm">__NAME__</div><div class="id">__ID__</div>'
            '__WARN__</div>'.replace("__B64__", b64)
            .replace("__NAME__", NAMES.get(cid, "?"))
            .replace("__ID__", str(cid))
            .replace("__WARN__", '<div class="warn">⚠ __NOTE__</div>'.replace("__NOTE__", note) if note else ""))
        done.append(cid)
        if write:
            shutil.copyfile(dst, UI / dst.name)

    html = (HTML.replace("__CARDS__", "\n".join(cards))
            .replace("__N__", str(len(done)))
            .replace("__TOTAL__", str(len(IDS)))
            .replace("__MISS__", ("%d 张" % len(miss)) if miss else "无"))
    (REVIEW / "r577_icons.html").write_text(html, encoding="utf-8")
    print("done=%d miss=%d write=%s" % (len(done), len(miss), write), flush=True)
    print("review:", REVIEW / "r577_icons.html", flush=True)
    for w in warns[:20]:
        print("WARN", w, flush=True)
    if write:
        # .import 由 Godot --import 生成，这里不手写
        print("landed %d files into assets/ui" % len(done), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
