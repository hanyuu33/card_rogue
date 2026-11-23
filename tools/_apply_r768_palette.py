# -*- coding: utf-8 -*-
"""R768 落地：把某一档配色写入 assets/pics/<卡号>.png。

店长定档 I（#D5C2EE，比 H 再回升一档亮度）。

规则：
  - 已有卡图（9154 / 9185 / 9252）先备份到 processed/_bk_pics/，可反悔；
  - 9265 原本没有卡图，直接新建；
  - 落地前校验尺寸必须 448×404 —— 卡图是按文件名自动匹配的，
    尺寸错了 CardFace 不会报错，只会静默变形。

用法：
    python tools/_apply_r768_palette.py I            # 预览，不写
    python tools/_apply_r768_palette.py I --write    # 真写
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(r"E:\work\card_rogue")
REC = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768" / "recolor"
PROC = ROOT / "art_src" / "2026-11-16_诅咒火柴人_R768" / "processed"
PICS = ROOT / "assets" / "pics"

CARD_W, CARD_H = 448, 404
BAND_TOP, BAND_BOT = 68, 335

JOBS = [("regret_v2", 9265, "懊悔"), ("flaw", 9154, "破绽"),
        ("paralysis", 9185, "麻痹"), ("compensation", 9252, "代偿")]


def main(argv):
    code = argv[0] if argv else "I"
    do_write = "--write" in argv
    bk = PROC / "_bk_pics"
    ok = True

    for key, cid, name in JOBS:
        src = REC / ("%s_%s.png" % (key, code))
        if not src.exists():
            print("缺 %s" % src.name)
            ok = False
            continue
        im = Image.open(src)
        if im.size != (CARD_W, CARD_H):
            print("%s 尺寸 %s != %s" % (src.name, im.size, (CARD_W, CARD_H)))
            ok = False
            continue
        # 主体必须收在可见带内，否则卡面上会被裁掉。
        # 注意：_recolor.py 出的是**不透明实心图**（底色铺满），所以不能拿 alpha 算 bbox
        # （那样永远是全图）。改成「离角落底色够远的像素」才是真正的主体范围。
        rgb = im.convert("RGB")
        bg = rgb.getpixel((2, 2))
        px = rgb.load()
        xs, ys = [], []
        for yy in range(CARD_H):
            for xx in range(CARD_W):
                r, g, b = px[xx, yy]
                if abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2]) > 24:
                    xs.append(xx)
                    ys.append(yy)
        if not xs:
            print("%s 没有主体（整张都是底色）" % src.name)
            ok = False
            continue
        bbox = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
        if bbox[1] < BAND_TOP or bbox[3] - 1 > BAND_BOT:
            print("%s 主体越界 %s（可见带 %d..%d）" % (src.name, bbox, BAND_TOP, BAND_BOT))
            ok = False
            continue

        dst = PICS / ("%d.png" % cid)
        existed = dst.exists()
        print("%-6s %d %s  %s -> %s  bbox=%s%s" % (
            name, cid, code, src.name, dst.name, bbox, "" if existed else "  (新建)"))
        if do_write:
            if existed:
                bk.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dst, bk / dst.name)
            shutil.copy2(src, dst)
            print("        写入 %s（%d bytes）%s" % (
                dst, dst.stat().st_size, "，旧图已备份到 _bk_pics/" if existed else ""))

    if do_write and ok:
        print("\n备份目录：", bk)
    elif not do_write:
        print("\n（预览模式，未写文件；加 --write 落地）")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
