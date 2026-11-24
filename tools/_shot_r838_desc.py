# -*- coding: utf-8 -*-
"""R838 交付图：暗动力描述 旧/新 对照 + lucky 7 原文核对（仅查看，不入库）。"""
import os

from PIL import Image, ImageDraw, ImageFont

REPO = "E:/work/card_rogue"
FB = os.path.join(REPO, "assets/fonts/SourceHanSansCN-Bold.otf")
FR = os.path.join(REPO, "assets/fonts/SourceHanSansCN-Regular.otf")
fb = lambda s: ImageFont.truetype(FB, s)
fr = lambda s: ImageFont.truetype(FR, s)

BG = (28, 24, 20)
CARD = (44, 38, 31)
EDGE = (96, 78, 54)
GOLD = (226, 190, 118)
CREAM = (238, 228, 208)
DIM = (162, 148, 126)
RED = (214, 122, 100)
GREEN = (150, 200, 140)

OLD = "你无法再跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面，也不能把卡牌奖励留到以后领取。你也无法在商店删除卡牌。每回合开始时多抽一张牌。"
NEW = "每回合开始时多抽一张牌。你无法跳过卡牌奖励：必须当场拿取一张卡才能关闭奖励界面。商店里同样无法删除卡牌。"
LUCKY = "每 7 个我方回合（跨战斗累计），从该回合开始至下个我方回合开始，免疫所有生命伤害，且你的技能伤害 +7。"


# 避头尾：这些标点不许落在行首（挤在前一行末尾，允许轻微出血）
NO_LINE_START = "：，。；、）」』！？%,.;:"


def wrap(d, text, font, max_w):
    out, cur = [], ""
    for ch in text:
        if d.textlength(cur + ch, font=font) > max_w and cur:
            if ch in NO_LINE_START:
                out.append(cur + ch)   # 标点跟着上一行走
                cur = ""
                continue
            out.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        out.append(cur)
    return out


def panel(d, img, x, y, w, h, label, label_col, rid, text, icon_col):
    d.rounded_rectangle([x, y, x + w, y + h], radius=12, fill=CARD, outline=EDGE)
    d.rounded_rectangle([x + 14, y + 14, x + 32, y + 32], radius=5, fill=icon_col)
    d.text((x + 40, y + 12), label, font=fb(19), fill=label_col)

    ip = os.path.join(REPO, "assets/ui/relic_icon_%d.png" % rid)
    ic = Image.open(ip).convert("RGBA").resize((88, 88), Image.LANCZOS)
    img.paste(ic, (x + 22, y + 50), ic)
    d.text((x + 124, y + 50), "暗动力", font=fb(26), fill=CREAM)
    d.text((x + 124, y + 86), "传奇 · 持续   #6054", font=fr(16), fill=GOLD)
    for i, line in enumerate(wrap(d, text, fr(18), w - 136)):
        d.text((x + 124, y + 116 + i * 25), line, font=fr(18), fill=CREAM)


def main():
    W, H = 1140, 620
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([8, 8, W - 9, H - 9], outline=EDGE, width=2)

    d.text((34, 26), "暗动力 6054 · 去转折词 · 删重复句（R838c）", font=fb(30), fill=GOLD)
    d.text((36, 68), "改后：收益在第一句；去掉「代价是」，删掉与「跳过奖励」重复的那半句",
           font=fr(18), fill=DIM)

    panel(d, img, 26, 106, 530, 230, "旧（R440 原文 · 68 字）", RED, 6054, OLD, RED)
    panel(d, img, 584, 106, 530, 230, "新（R838c · 52 字）", GREEN, 6054, NEW, GREEN)

    y = 360
    d.rounded_rectangle([26, y, W - 26, y + 190], radius=12, fill=(36, 32, 26), outline=EDGE)
    d.text((44, y + 14), "lucky 7 6045 · 原文核对：已经是「免疫」，不用改", font=fb(20), fill=GOLD)
    d.text((44, y + 46), "上一条回复里我把它写成「免」是复述时的手误，数据一直是对的：",
           font=fr(17), fill=DIM)
    ip = os.path.join(REPO, "assets/ui/relic_icon_6045.png")
    ic = Image.open(ip).convert("RGBA").resize((84, 84), Image.LANCZOS)
    img.paste(ic, (44, y + 80), ic)
    for i, line in enumerate(wrap(d, LUCKY, fr(18), 900)):
        d.text((146, y + 86 + i * 25), line, font=fr(18), fill=CREAM)
    seg = "免疫所有生命伤害"
    d.text((146, y + 86), "", font=fr(18), fill=CREAM)
    xoff = 146 + d.textlength(LUCKY.split("，免疫")[0] + "，", font=fr(18))
    d.line([xoff, y + 130, xoff + d.textlength(seg, font=fr(18)), y + 130], fill=GREEN, width=2)

    out = os.path.join(REPO, "_shots/r838_relic_desc.png")
    img.save(out)
    print("saved", out, img.size)


if __name__ == "__main__":
    main()
