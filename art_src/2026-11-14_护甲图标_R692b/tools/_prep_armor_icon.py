# -*- coding: utf-8 -*-
"""R692b 护甲图标后处理：codex 原图（1254²）→ 与现有 affix_*.png **同一构图口径**的 128²。

口径是怎么定死的：现有 `assets/ui/affix_shield.png` / `affix_taunt.png` 的 alpha 包围盒
都是 `(2,2,126,126)` —— 也就是「非透明内容缩到 124²，居中放进 128²，四周各留 2px」。
新建材如果按原始 bbox 铺满，卡面上会比旁边那几颗徽章大一圈，所以这里照抄 124 / 2px。

用法：python art_src/2026-11-14_护甲图标_R692b/tools/_prep_armor_icon.py [raw文件名]
"""
import os
import sys

from PIL import Image

D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(D))
RAW = os.path.join(D, "raw")
OUT = os.path.join(ROOT, "assets", "ui", "affix_armor.png")
SIDE = 128
INNER = 124          # 与 affix_shield.png 的 bbox (2,2,126,126) 对齐
MARGIN = (SIDE - INNER) // 2


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "affix_armor_v1.png"
    src = os.path.join(RAW, name)
    im = Image.open(src).convert("RGBA")
    bb = im.getbbox()
    if bb is None:
        sys.exit("原图全透明：%s" % src)
    body = im.crop(bb)
    # 只缩不放：等比塞进 124²（非正方时按长边算，短边居中留白）
    scale = float(INNER) / float(max(body.size))
    new_size = (max(1, round(body.size[0] * scale)), max(1, round(body.size[1] * scale)))
    body = body.resize(new_size, Image.LANCZOS)
    canvas = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    canvas.alpha_composite(body, (MARGIN + (INNER - new_size[0]) // 2,
                                 MARGIN + (INNER - new_size[1]) // 2))
    canvas.save(OUT)
    print("[r692] %s -> %s  bbox=%s  内容 %s" % (
        os.path.basename(src), os.path.relpath(OUT, ROOT).replace("\\", "/"),
        str(canvas.getbbox()), str(new_size)))


if __name__ == "__main__":
    main()
