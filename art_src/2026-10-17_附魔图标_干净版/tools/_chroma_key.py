"""R216：洋红底图标 → 干净透明 PNG（分片 / 单张两种模式）。

为什么重做：原来的 `shop_icon_*.png` 是「SD 贴纸风」生成图 —— 圆角板内是不透明米白
(242,242,238)，白色贴纸描边跟它同色，任何阈值抠图都会把描边啃成毛边。所以按用户口径
**只重做扣不干净的那几枚**（damage / dimension / save），`costdown` 本来是真透明，原样保留。

去背算法（确定性）：
  1. 洋红指数 m = min(r,b) - g —— 纯洋红 255；本批图案色（红/橙/绿/蓝/紫/白/灰）都 <= 0。
  2. **从边框泛洪**：m >= BG_T 的像素视为「洋红（含洋红压暗的投影）」，连通到边框的整块清 0。
     这一步专门吃掉模型偷偷加的投影 —— 投影是 (255k,0,255k)，m = 255k；不判它就会留下暗红方块。
  3. 剩下的边缘像素按混色比例反解：f = m/255，alpha = 1-f，C = (P - f·M)/(1-f)（M = 洋红）。
     这样抗锯齿边是「半透明前景」，不会留一圈粉边。

用法：
  python _chroma_key.py --sheet                     # 2×2 合集 → 四枚（象限对号入座）
  python _chroma_key.py --single <png> <icon_id>    # 单张 → 一枚
  追加 --dry 只报告不写文件。
"""
import sys
from PIL import Image

SHEET = "art_src/2026-10-17_附魔图标_干净版/Flat_game_UI_icon_sheet_on_a_s_2026-10-17T15-57-59.png"
OUT = "assets/ui/"
# 象限 → 附魔 id（与生成时排布一致：左上 费用 / 右上 伤害 / 左下 次元 / 右下 保存）
SLOTS = [("costdown", 0, 0), ("damage", 1, 0), ("dimension", 0, 1), ("save", 1, 1)]
SIZE = 64          # 成品画布（游戏里最大显示 44px，够了）
ART_MAX = 52       # 图案最长边（再大就会顶出卡面徽章的圆环）
BG_T = 40          # 洋红指数 >= 它 → 算背景（含压暗的投影）
MIN_AREA = 400     # 小于它的连通块当噪点丢掉


def chroma(im):
    """返回 (前景 RGBA 图, 前景掩码 0/1)。"""
    w, h = im.size
    px = im.load()
    mag = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            mag[y][x] = (min(r, b) - g) >= BG_T

    # 从边框泛洪：连到外面的洋红（+ 投影）全是背景
    bg = [[False] * w for _ in range(h)]
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if mag[y][x] and not bg[y][x]:
                bg[y][x] = True
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if mag[y][x] and not bg[y][x]:
                bg[y][x] = True
                stack.append((x, y))
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and mag[ny][nx] and not bg[ny][nx]:
                bg[ny][nx] = True
                stack.append((nx, ny))

    fg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = fg.load()
    mask = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                continue
            r, g, b = px[x, y]
            f = max(0.0, min(1.0, (min(r, b) - g) / 255.0))
            a = 1.0 - f
            if a <= 0.02:
                continue
            cr = (r - 255.0 * f) / a
            cg = g / a
            cb = (b - 255.0 * f) / a
            op[x, y] = (max(0, min(255, int(round(cr)))),
                        max(0, min(255, int(round(cg)))),
                        max(0, min(255, int(round(cb)))),
                        max(0, min(255, int(round(a * 255)))))
            mask[y][x] = a > 0.5
    return fg, mask


def components(mask, w, h):
    """8 连通块（面积从大到小）。"""
    seen = [[False] * w for _ in range(h)]
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if not mask[y0][x0] or seen[y0][x0]:
                continue
            stack = [(x0, y0)]
            seen[y0][x0] = True
            pts = []
            while stack:
                x, y = stack.pop()
                pts.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            if len(pts) < MIN_AREA:
                continue
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            out.append({"n": len(pts), "box": (min(xs), min(ys), max(xs) + 1, max(ys) + 1),
                        "cx": sum(xs) / len(xs), "cy": sum(ys) / len(ys)})
    out.sort(key=lambda d: -d["n"])
    return out


def emit(fg, box, name, dry=False):
    art = fg.crop(box)
    k = ART_MAX / float(max(art.size))
    art = art.resize((max(1, round(art.size[0] * k)), max(1, round(art.size[1] * k))),
                     Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(art, ((SIZE - art.size[0]) // 2, (SIZE - art.size[1]) // 2))
    if not dry:
        canvas.save(OUT + "shop_icon_%s.png" % name)
    print("%-10s <- %s → %s" % (name, box, art.size))
    return canvas


def sheet(path, dry=False):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    fg, mask = chroma(im)
    comps = components(mask, w, h)
    print("连通块：", [(c["n"], c["box"]) for c in comps])
    comps = comps[:4]          # 水印面积小、且排在最后 → 取前 4 大
    if len(comps) < 4:
        raise SystemExit("只找到 %d 个图案，生成图不合格" % len(comps))
    for name, qx, qy in SLOTS:
        want_x = qx * w / 2.0 + w / 4.0
        want_y = qy * h / 2.0 + h / 4.0
        best = min(comps, key=lambda c: (c["cx"] - want_x) ** 2 + (c["cy"] - want_y) ** 2)
        emit(fg, best["box"], name, dry)


def single(path, name, dry=False):
    im = Image.open(path).convert("RGB")
    fg, mask = chroma(im)
    comps = components(mask, im.size[0], im.size[1])
    if not comps:
        raise SystemExit("没有图案：%s" % path)
    emit(fg, comps[0]["box"], name, dry)


if __name__ == "__main__":
    dry = "--dry" in sys.argv
    if "--single" in sys.argv:
        i = sys.argv.index("--single")
        single(sys.argv[i + 1], sys.argv[i + 2], dry)
    else:
        sheet(SHEET, dry)
