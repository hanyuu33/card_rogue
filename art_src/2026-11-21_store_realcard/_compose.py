# -*- coding: utf-8 -*-
"""真实卡牌 + codex 背景 → 商店页主胶囊。

背景：raw/bg_capsule_a.png（codex，鸭子压境 + 发光棋盘，左下留空）。
卡牌：cards/<id>.png（实机 CardFace 渲染，1460×1724 透明底，含 90px 边距）。
输出：capsule_616.png（616×353）、capsule_231_big.png（231×87 放大 4 倍验收）、preview.png。
禁止跨比例直接拉伸：先裁到 1.745，再等比缩放。
"""
import math
import os
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
CARDS = os.path.join(D, "cards")
BG = os.path.join(D, "raw", "bg_capsule_a.png")

# 手牌扇形：左下三张真实玩家卡（中间正、两侧微斜）。
FAN = [9038, 9040, 8005]   # 左 / 中 / 右
TARGET_RATIO = 616.0 / 353.0


def load_card(cid):
    im = Image.open(os.path.join(CARDS, "%d.png" % cid)).convert("RGBA")
    return im


def paste_card(base, card_im, center_x, bottom_y, height, angle):
    # 按目标高度等比缩放（整图含透明边距）。
    scale = height / card_im.height
    w = max(1, round(card_im.width * scale))
    h = max(1, round(card_im.height * scale))
    c = card_im.resize((w, h), Image.LANCZOS)
    if angle:
        c = c.rotate(angle, expand=True, resample=Image.BICUBIC)
    x = round(center_x - c.width / 2)
    y = round(bottom_y - c.height)
    base.alpha_composite(c, (x, y))


def main():
    bg = Image.open(BG).convert("RGBA")
    # 裁到 1.745（居中裁宽），禁止直接拉伸。
    bw, bh = bg.size
    cur = bw / bh
    if cur > TARGET_RATIO:
        nw = round(bh * TARGET_RATIO)
        bg = bg.crop(((bw - nw) // 2, 0, (bw - nw) // 2 + nw, bh))
    else:
        nh = round(bw / TARGET_RATIO)
        bg = bg.crop((0, (bh - nh) // 2, bw, (bh - nh) // 2 + nh))
    W, H = bg.size
    canvas = bg.copy()

    # 卡牌高度占画面约 56%，扇形排在左下空地，底部留边让属性行可读。
    ch = H * 0.56
    cx = W * 0.235
    base_y = H * 0.985         # 手牌下沿贴底但不出框，属性行完整
    offsets = [(-W * 0.118, H * 0.035, 12), (0.0, 0.0, 0), (W * 0.118, H * 0.035, -12)]
    for cid, (dx, dy, ang) in zip(FAN, offsets):
        paste_card(canvas, load_card(cid), cx + dx, base_y + dy, ch, ang)

    canvas.save(os.path.join(D, "preview.png"))

    main616 = canvas.resize((616, 353), Image.LANCZOS)
    main616.save(os.path.join(D, "capsule_616.png"))
    small = canvas.resize((231, 87), Image.LANCZOS)
    small.save(os.path.join(D, "capsule_231.png"))
    small.resize((231 * 4, 87 * 4), Image.NEAREST).save(os.path.join(D, "capsule_231_big.png"))
    print("OK preview=%dx%d  capsule_616=616x353  capsule_231=231x87" % (W, H))


if __name__ == "__main__":
    main()
