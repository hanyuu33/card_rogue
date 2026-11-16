#!/usr/bin/env python3
"""批量渲染「正确字形」参考图：黑底 + 白色思源黑体字，交给 image-to-image 加质感。

状态词 2 字 → 1536x1024；数字/符号单字符 → 1024x1024。字形 100% 正确（内嵌字体），
AI 只负责质感，杜绝「错字」。
"""
from PIL import Image, ImageDraw, ImageFont

FONT = "assets/fonts/SourceHanSansCN-Bold.otf"
OUT_WORDS = "assets/fx/_ref_words"
OUT_DIGITS = "assets/fx/_ref_digits"

WORDS = ["燃烧", "中毒", "感电", "屏障", "治疗", "力量", "死亡", "能量", "眩晕", "嘲讽"]
DIGITS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
SIGNS = {"plus": "+", "minus": "-"}


def render(text: str, path: str, canvas=(1536, 1024), px=420) -> None:
    im = Image.new("RGBA", canvas, (0, 0, 0, 255))
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, px)
    # 用 textbbox 精确取字形包围盒（避免 getlength 的基线差异）
    bbox = d.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = (canvas[0] - tw) / 2 - bbox[0]
    y = (canvas[1] - th) / 2 - bbox[1]
    d.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    im.save(path)
    print(f"[ref] {path} '{text}' {canvas[0]}x{canvas[1]}")


def main() -> None:
    import os
    os.makedirs(OUT_WORDS, exist_ok=True)
    os.makedirs(OUT_DIGITS, exist_ok=True)
    for w in WORDS:
        render(w, f"{OUT_WORDS}/{w}.png")
    for d in DIGITS:
        render(d, f"{OUT_DIGITS}/digit_{d}.png", (1024, 1024), 620)
    for k, v in SIGNS.items():
        render(v, f"{OUT_DIGITS}/sign_{k}.png", (1024, 1024), 620)


if __name__ == "__main__":
    main()
