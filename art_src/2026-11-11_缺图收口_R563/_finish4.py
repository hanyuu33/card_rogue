# -*- coding: utf-8 -*-
"""返工第四批验收页：v2→v3 前后对比 + 4 张成品总览 + 刷新 R563 全批次总览。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_缺图收口_R563")
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")

SMALL = [(9154, "破绽"), (9185, "麻痹"), (9168, "许愿")]
ALL4 = SMALL + [(9242, "普罗诺亚之影")]

F = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 17)
FS = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 15)
FT = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 21)
FSM = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 12)


def old_crop(cid, name):
    """v2 raw 按标准裁窗 (0,63,S,S-63) 等效成 448x403。"""
    p = os.path.join(RAW, "%d_%s_v2.png" % (cid, name))
    im = Image.open(p).convert("RGB")
    return im.crop((0, 63, im.width, im.height - 63)).resize((448, 403), Image.LANCZOS)


def card(cid):
    p = os.path.join(PEND, "%d.png" % cid)
    im = Image.open(p).convert("RGB")
    assert im.size == (448, 403), (cid, im.size)
    return im


# 1) 三张前后对比
CW = CH = 360
SIDE, PAD, TOP, LB = 158, 10, 62, 26
W = SIDE + 2 * CW + 3 * PAD
H = TOP + len(SMALL) * (CH + LB + PAD) + PAD
s = Image.new("RGB", (W, H), (20, 22, 28))
d = ImageDraw.Draw(s)
d.text((PAD, 7), "R563 返工第四批：修改前 v2  →  修改后 v3", fill=(240, 225, 200), font=FT)
d.text((SIDE, TOP - 20), "修改前", fill=(175, 180, 190), font=FS)
d.text((SIDE + CW + PAD, TOP - 20), "修改后", fill=(150, 225, 220), font=FS)
NOTES = {9154: "扁平路牌 · 冷青碎盾", 9185: "扁平路牌 · 明黄电弧", 9168: "改回 1:4 小孩体型"}
for r, (cid, name) in enumerate(SMALL):
    y = TOP + r * (CH + LB + PAD)
    d.text((PAD, y + CH // 2 - 12), str(cid), fill=(235, 235, 240), font=F)
    d.text((PAD, y + CH // 2 + 10), name, fill=(200, 205, 215), font=FS)
    d.text((PAD, y + CH // 2 + 32), NOTES[cid][:11], fill=(150, 155, 165), font=FSM)
    s.paste(old_crop(cid, name).resize((CW, CH), Image.LANCZOS), (SIDE, y))
    s.paste(card(cid).resize((CW, CH), Image.LANCZOS), (SIDE + CW + PAD, y))
    d.rectangle([SIDE - 1, y - 1, SIDE + CW, y + CH], outline=(80, 84, 92), width=1)
    d.rectangle([SIDE + CW + PAD - 1, y - 1, SIDE + 2 * CW + PAD, y + CH],
                outline=(70, 150, 145), width=1)
s.save(os.path.join(ROOT, "_R563_返工第四批_前后对比.png"))
print("前后对比页", s.size)

# 2) 四张成品总览
COLS = 4
CW2, CH2 = 448, 403
rows = (len(ALL4) + COLS - 1) // COLS
s2 = Image.new("RGB", (COLS * (CW2 + PAD) + PAD, rows * (CH2 + LB + PAD) + PAD), (20, 22, 28))
d2 = ImageDraw.Draw(s2)
for i, (cid, name) in enumerate(ALL4):
    r, c = divmod(i, COLS)
    x = PAD + c * (CW2 + PAD)
    y = PAD + r * (CH2 + LB + PAD)
    s2.paste(card(cid), (x, y))
    d2.text((x + 4, y + CH2 + 2), "%d %s  v3" % (cid, name), fill=(150, 225, 220), font=F)
s2.save(os.path.join(ROOT, "_R563_返工第四批_448卡面.png"))
print("4 张总览", s2.size)

# 3) 刷新全批次总览（27 格）
BATCH = [
    (8084, "传授"), (8085, "影缚"), (9149, "疲惫"), (9154, "破绽"), (9157, "罐子"), (9168, "许愿"),
    (9241, "激光巨炮"), (9242, "普罗诺亚之影"), (9243, "炮击构状体"), (9244, "护盾构状体"), (9245, "迅捷构状体"),
    (8020, "鲜血堡垒"), (9185, "麻痹"), (9015, "鸭子号角"), (9028, "龙裔"), (9029, "骷髅"), (9048, "发条鸭"),
    (9049, "齿轮升腾"), (9115, "使魔之力"), (9117, "恶魔使魔"), (9139, "充能巨炮"), (9147, "流水线装配"),
    (9201, "舰炮"), (9202, "电磁屏障"), (9203, "紧急呼叫"), (9209, "空袭"),
    (9014, "远古虚骨龙·额外重绘"),
]
MARKED = {9154, 9185, 9168, 9242, 9049, 9115, 9028, 9014}
COLS3 = 4
rows3 = (len(BATCH) + COLS3 - 1) // COLS3
s3 = Image.new("RGB", (COLS3 * (CW2 + PAD) + PAD, rows3 * (CH2 + LB + PAD) + PAD), (20, 22, 28))
d3 = ImageDraw.Draw(s3)
bad = []
for i, (cid, name) in enumerate(BATCH):
    r, c = divmod(i, COLS3)
    x = PAD + c * (CW2 + PAD)
    y = PAD + r * (CH2 + LB + PAD)
    im = Image.open(os.path.join(PEND, "%d.png" % cid)).convert("RGB")
    if im.size != (448, 403):
        bad.append((cid, im.size))
    s3.paste(im, (x, y))
    d3.text((x + 4, y + CH2 + 2), "%d %s" % (cid, name),
            fill=(150, 225, 220) if cid in MARKED else (235, 235, 240), font=F)
s3.save(os.path.join(ROOT, "_R563_全批次_448卡面.png"))
print("全批次总览", s3.size, "规格不符:", bad or "无")
