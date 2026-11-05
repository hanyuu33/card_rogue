"""生成商店货架的两张素材（R508）。

来源与理由
----------
* 层板 `shelf_board.png`：从现有 `assets/ui/shelf.png`（1420×972 手绘木货架）裁一条
  真实横板下来 —— 木纹、上沿高光、下沿厚度阴影全是原来那张图的，风格与 bg_shop 一致，
  不需要重新 AI 出图（也就绕开了"生成图带水印"和授权登记的问题）。
* 后挡板 `shelf_back.png`：程序化画竖直木纹。shelf.png 里板与板之间是纯暗区（亮度 28~31，
  没有可用的木纹），所以背板只能自己造；用 shelf.png 采样出来的木色做基调，保证同色系。
  背板刻意画得**比背景墙暗**（背光），这样摆上去的浅色图标才会跳出来。

两张都是**整张拉伸**使用（不走九宫格）：背板任意宽高、层板横向任意宽 —— 见
`shop_scene.gd::_draw_shelf_backs()` / `_draw_shelf_boards()`。

跑法（managed python 3.13，自带 Pillow）：
  python tools/gen_shelf_textures.py
"""

import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# R508：源图已从 assets/ui/ 归档到 art_src（游戏不再引用整张货架图，留着只会进发布包）。
SRC = os.path.join(ROOT, "art_src", "2026-11-05_商店货架", "source_shelf.png")
OUT_DIR = os.path.join(ROOT, "assets", "ui")


def make_board() -> Image.Image:
    """从 shelf.png 裁一条层板，重采样到最终显示尺寸（1070×32）。"""
    im = Image.open(SRC).convert("RGBA")
    # 第二层板：y 198..342 是整块板的上下沿（上沿高光 / 板面 / 下沿厚度阴影）。
    # x 取 180..1188：避开左边立柱（16..99）和右端板的斜面断口（1210 之后开始变暗）。
    crop = im.crop((180, 198, 1188, 342))
    # 目标高度 32px = 货架上真实的板厚；横向保持 1008 → 放到 1070 只是留点富余。
    board = crop.resize((1070, 32), Image.LANCZOS)
    # 两端 30px 做横向淡出：层板是"伸出柜体"的断口，拉伸到任意货架宽时不该有硬边。
    w, h = board.size
    fade = 30
    for x in range(fade):
        a = int(255 * (x + 1) / fade)
        for y in range(h):
            r, g, b, al = board.getpixel((x, y))
            board.putpixel((x, y), (r, g, b, min(al, a)))
            xr = w - 1 - x
            r, g, b, al = board.getpixel((xr, y))
            board.putpixel((xr, y), (r, g, b, min(al, a)))
    return board


def make_back() -> Image.Image:
    """程序化后挡板：竖木条 + 上沿内阴影 + 左右暗角，深暖棕（比背景墙暗一档）。"""
    w, h = 512, 176
    rnd = random.Random(20261105)
    base = (58, 39, 26)          # 采样自 shelf.png 板面暗部再压暗 —— 背光板
    img = Image.new("RGBA", (w, h), base + (255,))
    px = img.load()

    # ① 竖木条：宽 18~46px 不等（太整齐会像纸板），各自 ±6 明暗差，条缝压 1px 暗线。
    x = 0
    planks = []
    while x < w:
        pw = rnd.randint(18, 46)
        planks.append((x, min(w, x + pw), rnd.randint(-6, 6)))
        x += pw
    for (x0, x1, dv) in planks:
        for xx in range(x0, x1):
            for yy in range(h):
                px[xx, yy] = (base[0] + dv, base[1] + dv, base[2] + dv, 255)
        if x0 < w:
            for yy in range(h):
                r, g, b, a = px[x0, yy]
                px[x0, yy] = (max(0, r - 14), max(0, g - 12), max(0, b - 10), 255)

    # ② 木纹：沿竖向走的细长弯曲亮线，随机起点 + 缓慢横向漂移（像手绘木头的筋）。
    grain = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grain)
    for _ in range(22):
        gx = rnd.uniform(0, w)
        drift = rnd.uniform(-0.05, 0.05)
        alpha = rnd.randint(8, 22)      # 很淡：背板是"退到后面"的，纹理抢戏就假
        pts = []
        for yy in range(0, h + 8, 8):
            pts.append((gx, yy))
            gx += drift * 8 + rnd.uniform(-0.9, 0.9)
        gd.line(pts, fill=(255, 224, 182, alpha), width=1)
    grain = grain.filter(ImageFilter.GaussianBlur(0.6))
    img = Image.alpha_composite(img, grain)
    px = img.load()

    # ③ 竖向明暗：顶上 34px 压暗（贴着上一层的板底 → 柜格里最暗的地方）。
    for yy in range(h):
        k = 1.0
        if yy < 34:
            k = 1.0 - 0.26 * (1.0 - yy / 34.0) ** 1.5
        for xx in range(w):
            r, g, b, a = px[xx, yy]
            px[xx, yy] = (int(r * k), int(g * k), int(b * k), 255)

    # ④ 左右各 12px 压暗：暗示柜体侧板，商品区不会在边上"漏光"。
    for xx in range(w):
        edge = 0.0
        if xx < 12:
            edge = 1.0 - xx / 12.0
        elif xx > w - 13:
            edge = 1.0 - (w - 1 - xx) / 12.0
        if edge <= 0.0:
            continue
        k = 1.0 - 0.38 * edge ** 1.3
        for yy in range(h):
            r, g, b, a = px[xx, yy]
            px[xx, yy] = (int(r * k), int(g * k), int(b * k), 255)

    # ⑤ 左右各 10px alpha 淡出：背板是"退到后面"的东西，贴在背景墙上时边界该渐隐，
    #    不然就是一块带直角的深色矩形糊在墙上。层板两端另有自己的淡出（见 make_board）。
    for xx in range(w):
        a = 1.0
        if xx < 10:
            a = xx / 10.0
        elif xx > w - 11:
            a = (w - 1 - xx) / 10.0
        if a >= 1.0:
            continue
        for yy in range(h):
            r, g, b, al = px[xx, yy]
            px[xx, yy] = (r, g, b, int(al * a))

    return img


def main() -> None:
    board = make_board()
    board.save(os.path.join(OUT_DIR, "shelf_board.png"))
    back = make_back()
    back.save(os.path.join(OUT_DIR, "shelf_back.png"))
    print("shelf_board.png", board.size)
    print("shelf_back.png", back.size)


if __name__ == "__main__":
    main()
