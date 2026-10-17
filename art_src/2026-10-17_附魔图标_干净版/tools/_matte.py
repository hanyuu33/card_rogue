"""R216：把商店图标里那层不透明的米白底（#F2F2EE 圆角板）抠掉，出干净的 64×64 PNG。

原因：这批 png 是「带底板的插画」——alpha 只在圆角板外面为 0，板内是不透明的
(242,242,238)。浅色/木架背景上看不出来，一贴到深色卡面（附魔徽章）就是一块白方块。

做法（确定性，不引入随机）：
  1. 采样底板色 B：取 alpha>200 像素的颜色中位数（这批图里就是 242,242,238）。
  2. 从图像边缘泛洪：可通行 = alpha<8 或 与 B 的色距 <= PASS_T。→ 得到「底板」区域。
  3. 底板 → alpha 0。
  4. 边缘去污：贴着底板 2px 内的像素，按 d = 与 B 的最大通道差 反推
     alpha = clamp(d / SOFT_T, 0, 1)，并反解 F = (P - (1-a)*B) / a。
     —— 只作用于紧邻边缘的一圈，内部的高光（剑刃、锁孔）不动，不会打洞。
  5. 裁 bbox → 等比缩到最长边 56 → 居中放进 64×64。

用法：python _matte.py            # 处理 ICONS
      python _matte.py --dry      # 只报告，不写文件
"""
import sys
from PIL import Image

ICONS = [
    "shop_icon_card", "shop_icon_costdown", "shop_icon_damage", "shop_icon_dimension",
    "shop_icon_maxhp", "shop_icon_remove", "shop_icon_save",
]
DIR = "assets/ui/"
PASS_T = 14      # 与底板的色距 <= 它 → 算底板（可通行）
SOFT_T = 46      # 边缘反推 alpha 的色距上限（d>=它 = 完全不透明）
EDGE_PX = 2      # 去污只作用于离底板这么近的一圈
OUT_SIZE = 64
ART_MAX = 56     # 成品里图案的最长边


def plate_color(px, w, h):
    """底板色 = 不透明像素的中位数（R,G,B 分别取中位数，抗噪）。"""
    rs, gs, bs = [], [], []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 200:
                rs.append(r); gs.append(g); bs.append(b)
    if not rs:
        return (255, 255, 255)
    rs.sort(); gs.sort(); bs.sort()
    n = len(rs) // 2
    return (rs[n], gs[n], bs[n])


def dist(c, b):
    return max(abs(c[0] - b[0]), abs(c[1] - b[1]), abs(c[2] - b[2]))


def matte(path, dry=False, outdir=None):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    B = plate_color(px, w, h)
    # 本来就没底板的图（如 costdown：中位色是蓝的）→ 跳过，别把图案当底板抠掉
    if min(B) < 200:
        print("%-26s 跳过：没有浅色底板（中位色 %s）" % (path.split("/")[-1], B))
        return im

    # ② 从边缘泛洪找底板
    passable = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8 or dist((r, g, b), B) <= PASS_T:
                passable[y][x] = True
    bg = [[False] * w for _ in range(h)]
    stack = []
    for x in range(w):
        for y in (0, h - 1):
            if passable[y][x] and not bg[y][x]:
                bg[y][x] = True
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if passable[y][x] and not bg[y][x]:
                bg[y][x] = True
                stack.append((x, y))
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and passable[ny][nx] and not bg[ny][nx]:
                bg[ny][nx] = True
                stack.append((nx, ny))

    n_bg = sum(1 for y in range(h) for x in range(w) if bg[y][x])

    # ③ + ④ 底板清 0，紧邻一圈去污
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if bg[y][x]:
                continue                      # 底板 → 全透明
            near = False
            for dy in range(-EDGE_PX, EDGE_PX + 1):
                for dx in range(-EDGE_PX, EDGE_PX + 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and bg[ny][nx]:
                        near = True
                        break
                if near:
                    break
            if near:
                d = dist((r, g, b), B)
                na = min(1.0, d / float(SOFT_T))
                if na <= 0.02:
                    continue                  # 还是底板色 → 丢掉
                # 反解前景色：P = na*F + (1-na)*B  →  F = (P - (1-na)*B) / na
                fr = (r - (1.0 - na) * B[0]) / na
                fg = (g - (1.0 - na) * B[1]) / na
                fb = (b - (1.0 - na) * B[2]) / na
                op[x, y] = (max(0, min(255, int(round(fr)))),
                            max(0, min(255, int(round(fg)))),
                            max(0, min(255, int(round(fb)))),
                            int(round(na * 255)))
            else:
                op[x, y] = (r, g, b, a)

    # ⑤ 裁 bbox → 等比 → 居中
    bb = out.getbbox()
    if bb is None:
        raise SystemExit("抠完是空的：%s" % path)
    art = out.crop(bb)
    k = ART_MAX / float(max(art.size))
    if abs(k - 1.0) > 0.01:
        art = art.resize((max(1, round(art.size[0] * k)), max(1, round(art.size[1] * k))),
                         Image.LANCZOS)
    canvas = Image.new("RGBA", (OUT_SIZE, OUT_SIZE), (0, 0, 0, 0))
    canvas.paste(art, ((OUT_SIZE - art.size[0]) // 2, (OUT_SIZE - art.size[1]) // 2))
    if not dry:
        canvas.save(path)
    if outdir:
        bg = Image.new("RGBA", (OUT_SIZE * 6, OUT_SIZE * 6), (26, 28, 34, 255))
        bg.alpha_composite(canvas.resize((OUT_SIZE * 6, OUT_SIZE * 6), Image.NEAREST))
        bg.convert("RGB").save(outdir + path.split("/")[-1])
    print("%-26s plate=%s bg=%d bbox=%s art=%s" % (path.split("/")[-1], B, n_bg, bb, art.size))
    return canvas


if __name__ == "__main__":
    dry = "--dry" in sys.argv
    for i, a in enumerate(sys.argv):
        if a == "--pass":
            PASS_T = int(sys.argv[i + 1])
        if a == "--soft":
            SOFT_T = int(sys.argv[i + 1])
    outdir = None
    for i, a in enumerate(sys.argv):
        if a == "--out" and i + 1 < len(sys.argv):
            outdir = sys.argv[i + 1]
    for name in ICONS:
        matte(DIR + name + ".png", dry, outdir)
