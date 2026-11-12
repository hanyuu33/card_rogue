"""R611 UI/背景纹理瘦身可行性样张。

只读 assets/ 与导出 PCK，不写工程文件；产物全部落 _review/。
三件事：
  1. 从 PCK 里反查 328 张未压缩纹理的真实占用（Godot 用 PNG 存 lossless）
  2. 对代表性图做「实机尺寸观感」与「像素级」两组对比
  3. 结论只有一条：体积在分辨率，不在压缩算法
"""
import io
import os
import re
import struct
import sys
from collections import defaultdict

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REVIEW = os.path.join(ROOT, "_review")
PCK = sys.argv[1] if len(sys.argv) > 1 else None


def parse_pck(path):
    buf = open(path, "rb").read()
    assert buf[:4] == b"GDPC"
    pos = 4 + 16 + 4 + 8 + 64
    cnt = struct.unpack_from("<I", buf, pos)[0]
    pos += 4
    out = {}
    for _ in range(cnt):
        ln = struct.unpack_from("<I", buf, pos)[0]
        pos += 4
        p = buf[pos:pos + ln].decode("utf-8").rstrip("\x00")
        pos += ln
        off, sz = struct.unpack_from("<QQ", buf, pos)
        pos += 16 + 16 + 4
        out[p] = sz
    return out, len(buf)


def map_sources(sizes):
    by_base = {}
    for dirpath, _, files in os.walk(os.path.join(ROOT, "assets")):
        for f in files:
            if f.lower().endswith(".png"):
                by_base.setdefault(f.lower(), []).append(os.path.join(dirpath, f))
    rows = []
    for p, s in sizes.items():
        if ".ctex" not in p or ".astc." in p:
            continue
        b = re.sub(r"-[0-9a-f]{32}\.ctex$", "", os.path.basename(p))
        cand = by_base.get(b.lower())
        if cand:
            rows.append((s, cand[0]))
    rows.sort(reverse=True)
    return rows


def dim(p):
    d = open(p, "rb").read(33)
    return struct.unpack(">II", d[16:24])


def shrink(path, cap):
    """最长边限制到 cap，LANCZOS；返回 (Image, 字节数)。"""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    if max(w, h) > cap:
        r = cap / float(max(w, h))
        im = im.resize((max(1, round(w * r)), max(1, round(h * r))), Image.LANCZOS)
    bio = io.BytesIO()
    im.save(bio, "PNG", optimize=True)
    return im, bio.tell()


FONT = os.path.join(ROOT, "assets/fonts/SourceHanSansCN-Regular.otf")


def sheet(items, out, label_h=54, scale=6):
    """items: [(标题, Image, 绘制边长)] —— 都按实机尺寸贴、再整体放大。"""
    pad = 26
    cols = len(items)
    cell = max(it[2] for it in items) * scale + pad * 2
    W = cell * cols
    H = label_h + cell + pad
    canvas = Image.new("RGB", (W, H), (22, 20, 24))
    dr = ImageDraw.Draw(canvas)
    try:
        from PIL import ImageFont
        fnt = ImageFont.truetype(FONT, 22)
    except Exception:
        fnt = None
    for i, (title, im, show) in enumerate(items):
        x0 = i * cell + pad
        y0 = label_h
        big = im.resize((show * scale, show * scale), Image.NEAREST)
        canvas.paste(big, (x0, y0))
        dr.rectangle([x0 - 1, y0 - 1, x0 + show * scale, y0 + show * scale],
                     outline=(198, 156, 74))
        dr.text((x0, 16), title, fill=(232, 210, 160), font=fnt)
    canvas.save(out)
    print("sheet", out, canvas.size)


def main():
    if not PCK or not os.path.isfile(PCK):
        print("need pck path")
        return
    sizes, total = parse_pck(PCK)
    rows = map_sources(sizes)
    cur = sum(r[0] for r in rows)
    print("未压缩纹理 %d 张  %.2f MB  (PCK %.1f MB)" % (len(rows), cur / 1048576.0, total / 1048576.0))

    # ---- 分组账单 ----
    g = defaultdict(lambda: [0, 0])
    for s, src in rows:
        d = os.path.dirname(os.path.relpath(src, ROOT)).replace("\\", "/")
        g[d][0] += 1
        g[d][1] += s
    print("\n按目录：")
    for k, (n, s) in sorted(g.items(), key=lambda x: -x[1][1]):
        print("  %-32s %4d 张 %7.2f MB" % (k, n, s / 1048576.0))

    # ---- 各档体积 ----
    print("\n各档实测（Pillow 重存，与 Godot lossless 同量级）：")
    for tag, cap_fn in (
        ("不动", lambda w, h: None),
        ("512 / 横图 1600", lambda w, h: 1600 if (w >= 1600 and w > h) else 512),
        ("256 / 横图 1920", lambda w, h: 1920 if (w >= 1600 and w > h) else 256),
    ):
        tot = 0
        nch = 0
        for s, src in rows:
            w, h = dim(src)
            cap = cap_fn(w, h)
            if cap is None or max(w, h) <= cap:
                tot += s
                continue
            nch += 1
            tot += shrink(src, cap)[1]
        print("  %-18s 改 %3d 张  %6.2f MB  (省 %5.2f)" % (tag, nch, tot / 1048576.0, (cur - tot) / 1048576.0))

    # ---- 样张 1：地图图标实机尺寸 ----
    icon = os.path.join(ROOT, "assets/ui/map_icons/battle.png")
    a = Image.open(icon).convert("RGBA")
    b, _ = shrink(icon, 256)
    c, _ = shrink(icon, 128)
    print("\nmap_icons/battle 原图", a.size, "→256", b.size, "→128", c.size)
    sheet([("原图 %dx%d" % a.size, a, 62),
           ("缩到 256", b, 62),
           ("缩到 128", c, 62)],
          os.path.join(REVIEW, "r611_icon_real.png"), scale=5)
    # 像素级（1:1 裁 160px 再看）
    def crop(im):
        w, h = im.size
        cx, cy = w // 2, h // 2
        s = min(w, h, 320)
        return im.crop((cx - s // 2, cy - s // 2, cx + s // 2, cy + s // 2))
    sheet([("原图 1:1", crop(a), 150), ("缩到 256 的 1:1", crop(b), 150)],
          os.path.join(REVIEW, "r611_icon_pixel.png"), scale=4)

    # ---- 样张 2：九宫格面板 ----
    pan = os.path.join(ROOT, "assets/ui/panel_parchment.png")
    pa = Image.open(pan).convert("RGBA")
    pb, nb = shrink(pan, 512)
    print("panel_parchment 原图", pa.size, "→512", pb.size, "体积 %.2f MB" % (nb / 1048576.0))

    def panel_view(im):
        """模拟实机：从 1536/512 拉伸到 900×520 面板再用九宫格，这里直接拉满。"""
        return im.resize((300, 173), Image.LANCZOS)
    sheet([("原图拉伸到 900×520", panel_view(pa), 300),
           ("缩到 512 后拉伸", panel_view(pb), 300)],
          os.path.join(REVIEW, "r611_panel.png"), scale=2)

    # ---- 样张 3：全屏背景（最该谨慎的一类）----
    bg = os.path.join(ROOT, "assets/ui/bg_curtain.png")
    ba = Image.open(bg).convert("RGBA")
    print("bg_curtain 原图", ba.size)
    for cap in (1600, 1280):
        bb, nb2 = shrink(bg, cap)
        print("  →%d %s  %.2f MB" % (cap, bb.size, nb2 / 1048576.0))
        # 按实机 1280 宽显示，再取中心 400×225 放大 2.6 倍看细节
        def view(im):
            r = 1280.0 / im.size[0]
            return im.resize((1280, max(1, round(im.size[1] * r))), Image.LANCZOS)
        va = view(ba)
        vb = view(bb)
        cy = va.size[1] // 2
        ca = va.crop((440, cy - 112, 840, cy + 112))
        cb = vb.crop((440, cy - 112, 840, cy + 112))
        sheet([("原图 %dx%d" % ba.size, ca, 400), ("缩到 %d" % cap, cb, 400)],
              os.path.join(REVIEW, "r611_bg_%d.png" % cap), scale=3)


if __name__ == "__main__":
    main()
