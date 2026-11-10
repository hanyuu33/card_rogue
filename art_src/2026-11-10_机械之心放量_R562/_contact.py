# -*- coding: utf-8 -*-
"""R562 联系表：把 raw/ 下的成品拼成带卡号卡名的总览图，一眼验收。"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")
RAW = os.path.join(D, "raw")

NAMES = {
    8031: "集体改造", 8032: "侦察塔", 8034: "堡垒", 8037: "改造工厂",
    8044: "加厚装甲", 8045: "自主升级", 8048: "生产订单", 8051: "重组",
    8056: "救援构装体", 8068: "轻量化", 8083: "拼装原型", 8086: "重构",
    9143: "发明专家", 9162: "集中突破", 9164: "辅助刃", 9167: "合体",
    9219: "压感地雷", 9220: "阵地保卫者", 9221: "结合者", 9222: "忒修斯奇械",
}

CELL = 300
COLS = 5
PAD = 8
LABEL = 26


def main():
    items = []
    for f in sorted(os.listdir(RAW)):
        if not f.endswith(".png"):
            continue
        cid = int(f.split("_")[0])
        items.append((cid, os.path.join(RAW, f)))
    if not items:
        print("raw/ 里没有图")
        return
    rows = (len(items) + COLS - 1) // COLS
    W = COLS * (CELL + PAD) + PAD
    H = rows * (CELL + LABEL + PAD) + PAD
    sheet = Image.new("RGB", (W, H), (18, 20, 26))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
    except Exception:                                            # noqa: BLE001
        font = ImageFont.load_default()
    for i, (cid, p) in enumerate(items):
        r, c = divmod(i, COLS)
        x = PAD + c * (CELL + PAD)
        y = PAD + r * (CELL + LABEL + PAD)
        im = Image.open(p).convert("RGB").resize((CELL, CELL), Image.LANCZOS)
        sheet.paste(im, (x, y))
        draw.text((x + 4, y + CELL + 3), "%d %s" % (cid, NAMES.get(cid, "")),
                  fill=(235, 235, 240), font=font)
    out = os.path.join(ROOT, "_R562_机械之心_联系表.png")
    sheet.save(out)
    print(out, sheet.size, "%d 张" % len(items))


if __name__ == "__main__":
    main()
