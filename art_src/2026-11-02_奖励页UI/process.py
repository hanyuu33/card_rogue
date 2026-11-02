# -*- coding: utf-8 -*-
"""R501：从图生图的奖励界面里切素材。

输入：raw/Game_UI_reward_screen_mockup_i_2026-11-02T13-51-47.png（1536x1024）
输出：out/reward_card.png        卡片底（已抹掉纹章与按钮，九宫格可用）
      out/reward_btn_green.png   绿色斜切按钮（RGBA 透明底）
      out/reward_shield_frame.png 纹章金边框架（RGBA，内部掏空 -> 游戏内垫来源色）

只用 PIL（机器上没有 numpy / cv2）。
"""
import os
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ROOT, "raw", "Game_UI_reward_screen_mockup_i_2026-11-02T13-51-47.png")
OUT = os.path.join(ROOT, "out")
os.makedirs(OUT, exist_ok=True)

im = Image.open(RAW).convert("RGB")
W, H = im.size
SX, SY = W / 1080.0, H / 720.0


def C(box):
    return tuple(int(round(v * (SX if i % 2 == 0 else SY)))
                 for i, v in enumerate(box))


# ---------------------------------------------------------------- 卡片底
def make_card():
    card = im.crop(C((140, 78, 948, 252)))
    w, h = card.size
    px = card.load()
    # 纹章 / 按钮在卡片里的矩形（由裁切坐标反推，均在卡片内部、不碰圆角）
    holes = [
        (int(80 * w / 1149.0), int(4 * h / 248.0),
         int(248 * w / 1149.0), int(236 * h / 248.0)),
        (int(760 * w / 1149.0), int(36 * h / 248.0),
         int(1140 * w / 1149.0), int(238 * h / 248.0)),
    ]
    for (x0, y0, x1, y1) in holes:
        for y in range(y0, y1):
            # 该行的干净底色：取卡片中段（x 300~700）平均，底色本身均匀
            rs = gs = bs = n = 0
            for x in range(int(w * 0.30), int(w * 0.62)):
                r, g, b = px[x, y]
                rs += r
                gs += g
                bs += b
                n += 1
            col = (rs // n, gs // n, bs // n)
            for x in range(x0, x1):
                px[x, y] = col
    # 孔洞四周 3px 羽化，避免矩形边界在渐变上显形
    card = card.filter(ImageFilter.GaussianBlur(0.4))
    card.save(os.path.join(OUT, "reward_card.png"))
    print("card", card.size)


# ---------------------------------------------------------------- 绿按钮
def make_button():
    btn = im.crop(C((690, 120, 920, 218)))
    hsv = btn.convert("HSV")
    w, h = btn.size
    src = btn.load()
    hsp = hsv.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            hh, ss, vv = hsp[x, y]
            # 绿色（含高光处的黄绿）：H 45~120，够饱和、够亮
            if 45 <= hh <= 120 and ss > 45 and vv > 40:
                r, g, b = src[x, y]
                op[x, y] = (r, g, b, 255)
    a = out.getchannel("A").filter(ImageFilter.GaussianBlur(0.6))
    out.putalpha(a)
    bbox = out.getbbox()
    out = out.crop(bbox)
    out.save(os.path.join(OUT, "reward_btn_green.png"))
    print("button", out.size)


# ---------------------------------------------------------------- 纹章金边框架
def make_shield():
    sh = im.crop(C((196, 94, 308, 236)))
    hsv = sh.convert("HSV")
    w, h = sh.size
    src = sh.load()
    hsp = hsv.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            hh, ss, vv = hsp[x, y]
            # 金色描边与花纹：H 18~45、饱和够高；米白底 S 很低被排掉
            if 15 <= hh <= 48 and ss > 70 and vv > 70:
                r, g, b = src[x, y]
                op[x, y] = (r, g, b, 255)
    a = out.getchannel("A").filter(ImageFilter.GaussianBlur(0.5))
    out.putalpha(a)
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    out.save(os.path.join(OUT, "reward_shield_frame.png"))
    print("shield", out.size)


make_card()
make_button()
make_shield()


# ---------------------------------------------------------------- 导出到 assets/ui
def export():
    """缩到游戏实际用量，并补一张去饱和的禁用按钮（同形换灰，位置不跳）。"""
    dst = os.path.join(ROOT, "..", "..", "assets", "ui")
    card = Image.open(os.path.join(OUT, "reward_card.png"))
    card.resize((768, 165), Image.LANCZOS).save(os.path.join(dst, "reward_card.png"))
    btn = Image.open(os.path.join(OUT, "reward_btn_green.png"))
    btn = btn.resize((256, 108), Image.LANCZOS)
    btn.save(os.path.join(dst, "reward_btn_green.png"))
    # 禁用：去饱和后略提亮，仍保留斜切角与高光 -> 和绿色款完全同形
    lum = btn.convert("L")
    grey = Image.new("RGBA", btn.size, (0, 0, 0, 0))
    gp = grey.load()
    bp = btn.load()
    lp = lum.load()
    for y in range(btn.size[1]):
        for x in range(btn.size[0]):
            v = int(lp[x, y] * 0.55 + 105)
            gp[x, y] = (v, v, maxi(0, v - 6), bp[x, y][3])
    grey.save(os.path.join(dst, "reward_btn_disabled.png"))
    sh = Image.open(os.path.join(OUT, "reward_shield_frame.png"))
    sh.save(os.path.join(dst, "reward_shield_frame.png"))
    print("exported to", os.path.abspath(dst))


def maxi(a, b):
    return a if a > b else b


export()
