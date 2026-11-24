# -*- coding: utf-8 -*-
"""R836 后一次性产物：把当前全部「传奇」道具拼成一张总览图（不入库，仅查看用）。"""
import io
import json
import os

from PIL import Image, ImageDraw, ImageFont

REPO = "E:/work/card_rogue"
FONT_B = os.path.join(REPO, "assets/fonts/SourceHanSansCN-Bold.otf")
FONT_R = os.path.join(REPO, "assets/fonts/SourceHanSansCN-Regular.otf")

BG = (30, 26, 22)
CARD = (44, 38, 31)
EDGE = (96, 78, 54)
GOLD = (226, 190, 118)
CREAM = (238, 228, 208)
DIM = (168, 154, 132)

fb = lambda s: ImageFont.truetype(FONT_B, s)
fr = lambda s: ImageFont.truetype(FONT_R, s)


def wrap(draw, text, font, max_w):
    lines, cur = [], ""
    for ch in text:
        if ch == "\n":
            lines.append(cur)
            cur = ""
            continue
        if draw.textlength(cur + ch, font=font) > max_w and cur:
            lines.append(cur)
            cur = ch
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def main():
    relics = json.load(io.open(os.path.join(REPO, "relics.json"), encoding="utf-8"))
    pool_ids = [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024, 6026, 6028, 6029,
                6040, 6041, 6042, 6043, 6044, 6045, 6046, 6050, 6051, 6052, 6053,
                6054, 6060, 6064, 6065, 6066, 6070, 6071, 6072, 6073, 6074, 6076,
                6077, 6078, 6079, 6080, 6081, 6082, 6083, 6084]
    all_relics = {}

    def walk(node):
        if isinstance(node, list):
            for x in node:
                walk(x)
        elif isinstance(node, dict):
            if "id" in node and "name" in node and "tier" in node:
                all_relics[int(node["id"])] = node
                return
            for v in node.values():
                walk(v)

    walk(relics)
    legs = [all_relics[i] for i in pool_ids
            if i in all_relics and all_relics[i].get("tier") == "传奇"]

    W, H = 1200, 60 + 96 + len(legs) // 2 * 232 + 26
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([8, 8, W - 9, H - 9], outline=EDGE, width=2)

    d.text((34, 30), "传奇道具 · 当前全部 %d 件" % len(legs), font=fb(34), fill=GOLD)
    d.text((36, 78), "掉落：先摇 5%×层数（大宝箱 ×2 / Boss ×3）命中，才从这张表里取一件",
           font=fr(19), fill=DIM)

    cw, ch = 566, 218
    x0, y0 = 26, 60 + 96
    for i, r in enumerate(legs):
        cx = x0 + (i % 2) * (cw + 16)
        cy = y0 + (i // 2) * (ch + 14)
        d.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=12, fill=CARD, outline=EDGE)

        icon_path = os.path.join(REPO, "assets/ui/relic_icon_%d.png" % r["id"])
        if os.path.exists(icon_path):
            ic = Image.open(icon_path).convert("RGBA").resize((116, 116), Image.LANCZOS)
            d.rounded_rectangle([cx + 18, cy + 24, cx + 18 + 116, cy + 24 + 116],
                                radius=10, fill=(28, 24, 19), outline=EDGE)
            img.paste(ic, (cx + 18, cy + 24), ic)

        tx = cx + 152
        d.text((tx, cy + 22), r["name"], font=fb(27), fill=CREAM)
        name_w = d.textlength(r["name"], font=fb(27))
        tag = "传奇 · %s" % r.get("kind", "")
        d.text((tx + name_w + 12, cy + 30), tag, font=fr(17), fill=GOLD)
        d.text((tx, cy + 58), "#%d" % r["id"], font=fr(15), fill=DIM)

        body = wrap(d, r.get("desc", ""), fr(17), cw - 152 - 22)
        for j, line in enumerate(body[:6]):
            d.text((tx, cy + 82 + j * 22), line, font=fr(17), fill=CREAM)

    d.text((36, H - 40), "池内一般 30 + 传奇 6 ＝ 36 件（另 5 件剧情锁未解锁时不出）",
           font=fr(16), fill=DIM)

    out = os.path.join(REPO, "_shots/legendary_relics.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    print("saved", out, img.size, "件数", len(legs))


if __name__ == "__main__":
    main()
