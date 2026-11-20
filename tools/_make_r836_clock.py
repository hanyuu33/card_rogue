# -*- coding: utf-8 -*-
"""R836：钟面 1024 → 512×512 真透明 PNG（落 assets/fx/clock_face.png）。

为什么复用 R755 的 `_bg_mask`：表盘是**米白 #EFE6D2**，跟白底只差一点点亮度 ——
按亮度抠会把整个表盘吃掉。`_bg_mask` 是从四边向内泛洪「亮且不饱和」的**连通区**，
米白盘面被深褐描边围住、从边界走不进去，天然安全（R755 石头高光同款理由）。

⚠️ 输出**内切正方形**（pad_pct = 0）：battle_scene 按 CLOCK_FX_D 正方形贴图，
   纹理里的圆必须刚好内切，否则表盘会被画成椭圆 / 指针比例对不上。
"""
import sys

sys.path.insert(0, "E:/work/card_rogue/tools")
from PIL import Image, ImageChops, ImageFilter  # noqa: E402
from _make_r755_icons import _bg_mask, ROOT  # noqa: E402

SRC = ROOT + "art_src/2026-11-20_缺陷时钟时针_R836/raw/clock_face_v1.png"
OUT = ROOT + "assets/fx/clock_face.png"
EDGE = 512
EDGE_COL = (42, 33, 24)     # 背景替换色 = 物体描边的深褐，降采样时不会渗白


def main():
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    bg = _bg_mask(im)
    fg = ImageChops.invert(bg)
    # 收 2px：描边外侧的抗锯齿像素「亮且不饱和」，不收会被当成前景 → 圆外多一圈亮边
    for _ in range(2):
        fg = fg.filter(ImageFilter.MinFilter(3))

    rgb = Image.composite(im, Image.new("RGB", (w, h), EDGE_COL), fg)
    alpha = fg.resize((EDGE, EDGE), Image.LANCZOS)
    rgb = rgb.resize((EDGE, EDGE), Image.LANCZOS)

    bb = alpha.point(lambda v: 255 if v >= 8 else 0).getbbox()
    side = max(bb[2] - bb[0], bb[3] - bb[1])
    cx = (bb[0] + bb[2]) // 2
    cy = (bb[1] + bb[3]) // 2
    print("bbox", bb, "side", side, "center", (cx, cy), "img", (w, h))

    half = side // 2
    box = (cx - half, cy - half, cx - half + side, cy - half + side)
    # 贴图必须完整切出来（内切正方形不能越界）
    assert box[0] >= 0 and box[1] >= 0 and box[2] <= EDGE and box[3] <= EDGE, box
    rgb = rgb.crop(box).resize((EDGE, EDGE), Image.LANCZOS)
    alpha = alpha.crop(box).resize((EDGE, EDGE), Image.LANCZOS)

    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    out.save(OUT)
    print("wrote", OUT, out.size)

    # 圆心校验：正圆的外接框中心应当就是圆心（±2px）；顺便存一张暗底预览供人眼验收
    prev = Image.new("RGBA", (EDGE + 40, EDGE + 40), (26, 26, 32, 255))
    prev.paste(out, (20, 20), out)
    prev.save(ROOT + "art_src/2026-11-20_缺陷时钟时针_R836/processed_preview_512.png")
    print("preview written")


if __name__ == "__main__":
    main()
