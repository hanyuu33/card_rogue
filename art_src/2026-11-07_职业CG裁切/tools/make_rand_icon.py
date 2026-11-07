# -*- coding: utf-8 -*-
"""R519c：把生成的黑底问号图处理成游戏内可用的「随机」图标。

生成的原图右下角带模型水印、外面是一圈自带的金框。这两样都不能进游戏，所以：
  ① 只抠中间的问号（含它自带的暖光晕），自动躲开水印与外框；
  ② 黑底方块和金边**自己画** —— 半径、描边宽度、颜色都能跟 `UiTheme` 的
     ADVENTURE_BRASS 对上，也保证 88px 显示时描边还有 1px 以上；
  ③ 合成用 `ImageChops.lighter`（逐通道取亮）：底色是黑，等于把问号原样叠上去，
     外圈那点深灰光晕会自然融进黑底，不会出现一个方块补丁。

用法：python make_rand_icon.py [--write]
      不带 --write 只打印测量结果（哪块是问号、裁了多大），不落盘。
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]                     # /e/work/card_rogue
SRC_DIR = HERE.parent / "rand_icon"
DST = ROOT / "assets" / "ui" / "icon_random.png"

OUT = 256                # 成品边长（游戏里画 88px，2.9x 余量足够锐）
RADIUS = 40              # 圆角半径（=> 88px 下约 14px）
BORDER = 4               # 金边宽度（=> 88px 下约 1.4px）
BG = (13, 13, 16)        # 黑底（比 SCREEN_BG #1a1c22 更深一档，压得住金色）
BRASS = (165, 140, 88)   # = UiTheme.ADVENTURE_BRASS "a58c58"

# 原图里要避开的区域：外框一圈 + 右下角水印
SAFE = (44, 44, 900, 916)     # 找问号时的搜索窗（左, 上, 右, 下）
LUM_MIN = 52                  # 亮度阈值：低于它的当黑底，不参与 bbox
DARK_FLOOR = 46               # 色阶下限：原图底色（~#2a2a2a）及其噪点归零
BRIGHT_CAP = 168              # 色阶上限：问号本体与金边保持满亮


def pick_src() -> Path:
    files = sorted(SRC_DIR.glob("*.png"), key=lambda p: p.stat().st_mtime)
    if not files:
        raise SystemExit("没找到原图：%s" % SRC_DIR)
    return files[-1]


def content_box(im: Image.Image) -> tuple[int, int, int, int]:
    """在搜索窗内找问号的 bbox（含暖光晕）。

    先腐蚀一遍再取 bbox：原图黑底上有压缩噪点和金框内壁的微光，单独几个亮像素
    就能把 bbox 撑满整个搜索窗。腐蚀掉孤立小点之后，剩下的才是成片的问号。
    """
    lum = im.convert("L")
    mask = lum.point(lambda v: 255 if v >= LUM_MIN else 0)
    # 把搜索窗以外的全清掉，避免外框/水印被算进来
    clip = Image.new("L", im.size, 0)
    ImageDraw.Draw(clip).rectangle(SAFE, fill=255)
    mask = ImageChops.multiply(mask, clip)
    core = mask.filter(ImageFilter.MinFilter(15))     # 腐蚀 7px：孤立噪点会整块消失
    box = core.getbbox()
    if box is None:
        raise SystemExit("搜索窗内没找到亮部，阈值可能太高")
    # 腐蚀会把外轮廓往里收 7px，这里补回来（光晕本来也该带上）
    return (max(SAFE[0], box[0] - 8), max(SAFE[1], box[1] - 8),
            min(SAFE[2], box[2] + 8), min(SAFE[3], box[3] + 8))


def flatten_bg(patch: Image.Image) -> Image.Image:
    """把原图那块「深灰底」压成纯黑，只留问号和它的光晕。

    ⚠️ 不做这一步会露馅：生成图的底色是 ~#2a2a2a 的深灰（不是纯黑），
    直接 `lighter` 叠到我们的黑底上，问号四周会浮出一个**矩形亮块**。
    做法是按亮度做一次线性色阶：LO 以下归零（吃掉底色与噪点），HI 以上保持满亮，
    中间线性过渡 —— 光晕的渐变能留住，不是硬切。
    """
    lo, hi = DARK_FLOOR, BRIGHT_CAP
    lut = [0 if v <= lo else 255 if v >= hi else round((v - lo) * 255 / (hi - lo))
           for v in range(256)]
    return patch.point(lut * 3)


def rounded_mask(edge: int, radius: int, inset: int = 0) -> Image.Image:
    """圆角矩形蒙版：inset 是向内收的像素（描边用外圈减内圈）。"""
    m = Image.new("L", (edge, edge), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (inset, inset, edge - 1 - inset, edge - 1 - inset),
        radius=max(1, radius - inset), fill=255)
    return m


def main() -> None:
    src = pick_src()
    im = Image.open(src).convert("RGB")
    print("原图  :", src.name, im.size)

    box = content_box(im)
    print("问号框:", box, " 尺寸", (box[2] - box[0], box[3] - box[1]))
    if box[2] > 860 or box[3] > 920:
        raise SystemExit("问号框吃到了水印/外框，检查 SAFE 与阈值")

    glow = flatten_bg(im.crop(box))
    # 竖向占成品的 78%，水平按原比例（不拉伸字形）
    target_h = int(OUT * 0.78)
    target_w = max(1, round(glow.width * target_h / glow.height))
    glow = glow.resize((target_w, target_h), Image.LANCZOS)

    # ---- 画黑底 + 金边 ----
    plate = Image.new("RGB", (OUT, OUT), (0, 0, 0))
    draw = ImageDraw.Draw(plate)
    outer = rounded_mask(OUT, RADIUS, 0)
    inner = rounded_mask(OUT, RADIUS, BORDER)
    ring = ImageChops.subtract(outer, inner)          # 金边 = 外圈 − 内圈
    plate.paste(Image.new("RGB", (OUT, OUT), BG), (0, 0), inner)
    plate.paste(Image.new("RGB", (OUT, OUT), BRASS), (0, 0), ring)

    # ---- 叠问号（逐通道取亮 = 黑底上的一次「加光」）----
    layer = Image.new("RGB", (OUT, OUT), (0, 0, 0))
    ox = (OUT - target_w) // 2
    oy = (OUT - target_h) // 2
    layer.paste(glow, (ox, oy))
    merged = ImageChops.lighter(plate, layer)

    # 圆角外全部清成透明，贴到卡面/头像行旁边时不带方角
    rgba = merged.convert("RGBA")
    rgba.putalpha(outer)

    if "--write" not in sys.argv:
        rgba.resize((OUT * 2, OUT * 2), Image.NEAREST).save(
            HERE.parent / "_review" / "_rand_icon_preview.png")
        print("干跑（加 --write 才落盘）；预览已写入 _review/_rand_icon_preview.png")
        return

    if DST.exists():
        bak = DST.with_suffix(".png.bak_r519c")
        bak.write_bytes(DST.read_bytes())
        print("备份  :", bak.name)
    rgba.save(DST)
    # 88px 实际观感预览（2x 放大便于看图）
    rgba.resize((88, 88), Image.LANCZOS).resize((352, 352), Image.NEAREST).save(
        HERE.parent / "_review" / "_rand_icon_88.png")
    print("落盘  :", DST.relative_to(ROOT))


if __name__ == "__main__":
    main()
