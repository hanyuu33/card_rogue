# -*- coding: utf-8 -*-
"""机械之心 CG 画风统一 —— 对比页生成（v2：聚焦构图保持版）。

主对比：现版机械之心（构图基准） vs v_keepcomp（构图保持 + 赛璐璐画风）。
参考：森林精魄 / 暗影刺客（画风锚）。
"""
import base64
import io
import os

from PIL import Image

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-12_机械之心CG画风统一")
RAW = os.path.join(D, "raw")

REF_FOREST = os.path.join(ROOT, "assets", "ui", "class_cg_forest.png")
REF_ROGUE = os.path.join(ROOT, "assets", "ui", "class_cg_rogue.png")
REF_MECH = os.path.join(ROOT, "assets", "ui", "class_cg_mech.png")

TH_MAIN = 500   # 主对比图高度
TH_REF = 320    # 画风锚图高度


def thumb(path, th):
    im = Image.open(path).convert("RGB")
    w = int(im.width * th / im.height)
    return im.resize((w, th), Image.LANCZOS)


def label(text, w):
    from PIL import ImageDraw
    img = Image.new("RGB", (w, 36), (28, 28, 34))
    d = ImageDraw.Draw(img)
    d.text((12, 10), text, fill=(255, 255, 255))
    return img


def row(items, th):
    cells = [(n, thumb(p, th)) for n, p in items]
    gap = 10
    W = sum(t.width for _, t in cells) + gap * (len(cells) - 1)
    canvas = Image.new("RGB", (W, th + 36), (16, 16, 20))
    x = 0
    for name, t in cells:
        canvas.paste(label(name, t.width), (x, 0))
        canvas.paste(t, (x, 36))
        x += t.width + gap
    return canvas


def main():
    main_items = [("现版·机械之心（构图基准）", REF_MECH)]
    kc = os.path.join(RAW, "v_keepcomp_codex.png")
    if os.path.exists(kc):
        main_items.append(("候选·构图保持+赛璐璐", kc))
    row1 = row(main_items, TH_MAIN)

    row2 = row([("画风锚·森林精魄", REF_FOREST), ("画风锚·暗影刺客", REF_ROGUE)], TH_REF)

    gap = 20
    W = max(row1.width, row2.width)
    H = row1.height + gap + row2.height
    canvas = Image.new("RGB", (W, H), (16, 16, 20))
    canvas.paste(row1, ((W - row1.width) // 2, 0))
    canvas.paste(row2, ((W - row2.width) // 2, row1.height + gap))

    out = os.path.join(D, "compare.png")
    canvas.save(out)
    print("saved", out, canvas.size)

    buf = io.BytesIO()
    canvas.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()
    css = ("body{background:#141419;color:#eee;font-family:sans-serif;padding:16px}"
           "h1{font-size:18px}p{color:#aaa;font-size:13px;line-height:1.6}"
           "img{max-width:100%;border:1px solid #333}")
    html = ("<!DOCTYPE html><html><head><meta charset='utf-8'>"
            "<title>机械之心CG画风统一</title><style>" + css + "</style></head><body>"
            "<h1>机械之心 CG 画风统一 · 构图保持版候选</h1>"
            "<p>上一行：现版机械之心（构图基准） 与 新候选（构图保持现版 + 画风赛璐璐化）并排，"
            "重点看<b>构图是否一致</b>（站姿双臂环抱 / 望左上全息屏 / 左下工作台心形核心 / 右上图纸屏 / 右中机械臂 / 右下示波器）。</p>"
            "<p>下一行：森林精魄 / 暗影刺客，是要对齐的赛璐璐画风锚（清晰描边 + 平涂 + 硬边分区阴影）。</p>"
            "<img src='data:image/png;base64," + b64 + "'></body></html>")
    hpath = os.path.join(D, "compare.html")
    with open(hpath, "w", encoding="utf-8") as f:
        f.write(html)
    print("saved", hpath)


if __name__ == "__main__":
    main()
