"""R872 卡框修补（预览模式）

病灶：
  1. `card_plate_<kind>.png` 的不透明区是一块**不规则斑块**（forest: bbox 170..565 × 42..167），
     乘上稀有度色后就是卡名条中间那块「黑色空区域」。它本该是**牌匾内部的纸面形状**。
  2. 卡图窗四角被框的内圆角 / 牌匾拱形压着，不是一个规整四边形。

修法：
  · 用 frame 素材自身的「牌匾内区」透明连通域做 mask，重出一张 plate（纯白 + 该 mask）；
  · 把 frame 在卡图窗 bbox 内的不透明像素清空 → 卡图窗 = 干净矩形。

用法（预览，不覆盖 assets）：
  python tools/_fix_r872_cardframe.py preview
用法（落地，覆盖 assets，原图备份到 art_src/2026-11-23_frames/_bak_r872/）：
  python tools/_fix_r872_cardframe.py apply
"""
import json
import os
import shutil
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "ui")
BOXES = json.load(open(os.path.join(ROOT, "art_src/2026-11-23_frames/title18/_plate_boxes.json")))
KINDS = ["forest", "shadow", "mech", "common", "enemy", "bard"]
W, H = 728, 878
SEED = (364, 100)


def passable(rgba) -> bool:
    """牌匾内部可通行像素：透明洞，或**米色纸面**。
    金边（高饱和金）/ 深绿装饰 / 深色阴影一律挡住 —— 漫水边界就是牌匾金边的内沿。"""
    r, g, b, a = int(rgba[0]), int(rgba[1]), int(rgba[2]), int(rgba[3])
    if a < 20:
        return True
    v = max(r, g, b)
    if v <= 0:
        return False
    s = (v - min(r, g, b)) / float(v)
    return s < 0.40 and v > 165


def flood_inside(fa: np.ndarray, seed, y_max: int) -> np.ndarray:
    """从牌匾中心向内漫水，收集「纸面 + 透明洞」的连通区（= 牌匾内区）。"""
    h, w = fa.shape[0], fa.shape[1]
    seen = np.zeros((h, w), bool)
    sx, sy = seed
    if not passable(fa[sy, sx]):
        raise RuntimeError("seed 落在金边/装饰上：%s" % str(seed))
    q = deque([(sx, sy)])
    seen[sy, sx] = True
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < y_max and not seen[ny, nx] and passable(fa[ny, nx]):
                seen[ny, nx] = True
                q.append((nx, ny))
    return seen


def build(kind: str, out_ui: str) -> None:
    frame_path = os.path.join(UI, "card_outer_frame_%s.png" % kind)
    plate_path = os.path.join(UI, "card_plate_%s.png" % kind)
    frame = Image.open(frame_path).convert("RGBA")
    fa = np.array(frame)

    art = BOXES["art"][kind]
    ax0, ay0 = int(round(art[0] * W)), int(round(art[1] * H))
    ax1, ay1 = int(round(art[2] * W)), int(round(art[3] * H))

    # ── 1) 新 plate：**规整四边形**（圆角矩形）──
    # 旧 plate 的不透明区是一块不规则斑块（边缘锯齿 + 局部挖空），乘上稀有度色就是
    # 店长说的「卡框上方黑色空区域」。这里取它的**外接框**当几何：那块 bbox 本来就在
    # 牌匾金边以内，换成圆角矩形后既不会溢出，也一次消掉毛刺与缺口。
    pa = np.array(Image.open(plate_path).convert("RGBA"))[:, :, 3]
    ys, xs = np.where(pa > 200)
    if len(xs) == 0:
        raise RuntimeError("%s: 旧 plate 没有不透明像素，无法取外接框" % kind)
    bx0, by0, bx1, by1 = int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())
    m_img = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m_img).rounded_rectangle(
        [bx0 + 8, by0 + 8, bx1 - 8, by1 - 8], radius=10, fill=255)
    m_img = m_img.filter(ImageFilter.GaussianBlur(1.0))
    m = np.array(m_img).astype(np.float32) / 255.0

    plate = np.zeros((H, W, 4), np.uint8)
    plate[:, :, 0:3] = 255
    plate[:, :, 3] = (m * 253.0).astype(np.uint8)
    Image.fromarray(plate).save(os.path.join(out_ui, "card_plate_%s.png" % kind))
    inside = int((bx1 - bx0) * (by1 - by0))

    # ── 2) 新 frame：卡图窗 bbox 内清空 ──
    fa2 = fa.copy()
    fa2[ay0:ay1 + 1, ax0:ax1 + 1, 3] = 0
    out_frame = Image.fromarray(fa2)
    out_frame.save(os.path.join(out_ui, "card_outer_frame_%s.png" % kind))
    # compact 版与普通版同源（md5 一致），两处必须一起换，否则详情层还是旧框
    out_frame.save(os.path.join(out_ui, "card_outer_frame_%s_compact.png" % kind))

    # 统计
    pass
    print("%-7s plate_mask=%6d px  art_win=(%d,%d)-(%d,%d)  cleared=%.1f%%"
          % (kind, inside, ax0, ay0, ax1, ay1,
             100.0 * (fa[ay0:ay1 + 1, ax0:ax1 + 1, 3] > 10).sum()
             / max(1, fa[ay0:ay1 + 1, ax0:ax1 + 1, 3].size)))


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    if mode == "apply":
        bak = os.path.join(ROOT, "art_src/2026-11-23_frames/_bak_r872")
        os.makedirs(bak, exist_ok=True)
        for k in KINDS:
            for n in ("card_outer_frame_%s.png" % k, "card_outer_frame_%s_compact.png" % k,
                      "card_plate_%s.png" % k):
                src = os.path.join(UI, n)
                if os.path.exists(src) and not os.path.exists(os.path.join(bak, n)):
                    shutil.copy2(src, os.path.join(bak, n))
        out_ui = UI
        print("[apply] 原图已备份到 %s" % bak)
    else:
        out_ui = os.path.join(ROOT, "_shots", "_fix_preview")
        os.makedirs(out_ui, exist_ok=True)
        print("[preview] 输出到 %s（assets 不动）" % out_ui)

    for k in KINDS:
        build(k, out_ui)


if __name__ == "__main__":
    main()
