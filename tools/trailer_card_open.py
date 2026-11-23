# -*- coding: utf-8 -*-
"""开场「角色」段：用游戏内卡图做双卡特写，替换掉 AI 3D 渲染镜头。

python tools/trailer_card_open.py --out release/trailer/work_v8/card_open.mp4

理由：3D 鸭子镜头（Pixar 塑料质感）与卡图/标题页的手绘二次元完全两套画风，
      预告片前 5 秒就出现风格断层，观感上像「广告片和游戏不是同一个东西」。
      这里改用 9001 鸭子骑士 / 9017 鸭子弓手 的游戏内卡图，风格与本体一致。
"""
import argparse
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
FF = Path(r"C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Packages"
          r"\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
          r"\ffmpeg-9.0.2-full_build\bin\ffmpeg.exe")

W, H = 1280, 720
FPS = 30
DUR = 2.5
CARD_H = 600            # 单卡显示高度（原图 404 → 放大 1.49x）
GOLD = (222, 190, 112)
CARDS = ["assets/pics/9001.png", "assets/pics/9017.png"]


def cover(im, size):
    tw, th = size
    s = max(tw / im.width, th / im.height)
    im2 = im.resize((max(1, int(im.width * s + 0.5)), max(1, int(im.height * s + 0.5))),
                    Image.LANCZOS)
    x = (im2.width - tw) // 2
    y = (im2.height - th) // 2
    return im2.crop((x, y, x + tw, y + th))


def vignette(im, strength=0.55):
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    pad = 220
    d.ellipse((-pad, -pad, W + pad, H + pad), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(160))
    dark = Image.new("RGB", (W, H), (4, 7, 10))
    return Image.composite(im, Image.blend(im, dark, strength), mask)


def make_bg(path):
    im = cover(Image.open(path).convert("RGB"), (W, H))
    im = im.filter(ImageFilter.GaussianBlur(30))
    im = Image.blend(im, Image.new("RGB", (W, H), (0, 0, 0)), 0.38)
    return vignette(im)


def make_card(path):
    """带金边、内描边与投影的卡面图层（RGBA，尺寸 = CARD_H 高度）。"""
    src = Image.open(path).convert("RGB")
    cw = int(round(CARD_H * src.width / src.height))
    face = src.resize((cw, CARD_H), Image.LANCZOS)
    face = face.filter(ImageFilter.UnsharpMask(radius=1.4, percent=110, threshold=2))

    pad = 22                                   # 留给外发光/投影
    layer = Image.new("RGBA", (cw + pad * 2, CARD_H + pad * 2), (0, 0, 0, 0))

    # 投影
    shadow = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad - 2, pad + 10, pad + cw + 2, pad + CARD_H + 18), radius=12,
        fill=(0, 0, 0, 165))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    layer.alpha_composite(shadow)

    # 卡面
    mask = Image.new("L", (cw, CARD_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, cw - 1, CARD_H - 1), radius=14, fill=255)
    layer.paste(face, (pad, pad), mask)

    # 金边 + 深色外描边
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((pad, pad, pad + cw - 1, pad + CARD_H - 1), radius=14,
                        outline=GOLD + (255,), width=3)
    d.rounded_rectangle((pad - 3, pad - 3, pad + cw + 2, pad + CARD_H + 2), radius=16,
                        outline=(16, 22, 26, 210), width=2)
    return layer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "release" / "trailer" / "work_v8" / "card_open.mp4"))
    args = ap.parse_args()
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    bgs = [make_bg(ROOT / p) for p in CARDS]
    cards = [make_card(ROOT / p) for p in CARDS]

    cmd = [str(FF), "-y", "-hide_banner", "-loglevel", "error",
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
           "-r", str(FPS), "-i", "-",
           "-f", "lavfi", "-t", "%.2f" % DUR, "-i", "anullsrc=r=48000:cl=stereo",
           "-map", "0:v", "-map", "1:a",
           "-c:v", "libx264", "-crf", "16", "-preset", "medium", "-pix_fmt", "yuv420p",
           "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
           "-t", "%.2f" % DUR, str(out)]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)

    half = DUR / 2
    xf = 0.28                                   # 交叉淡变时长
    n = int(round(DUR * FPS))
    for i in range(n):
        t = i / FPS
        # 交叉淡变的权重
        if t < half - xf / 2:
            a = 0.0
        elif t > half + xf / 2:
            a = 1.0
        else:
            a = (t - (half - xf / 2)) / xf
            a = a * a * (3 - 2 * a)             # smoothstep

        bg = Image.blend(bgs[0], bgs[1], a) if a > 0 else bgs[0]
        if a < 1:
            idx, k = 0, t / half
        else:
            idx, k = 1, (t - half) / half
        k = max(0.0, min(1.0, k))
        scale = 1.0 + 0.045 * k
        layer = cards[idx]
        if abs(scale - 1.0) > 1e-4:
            layer = layer.resize((int(layer.width * scale), int(layer.height * scale)),
                                 Image.LANCZOS)
        alpha = 255 if (a in (0.0, 1.0)) else int(255 * (1 - a) if idx == 0 else 255 * a)
        if alpha < 255:
            layer = layer.copy()
            layer.putalpha(layer.getchannel("A").point(lambda v: v * alpha // 255))
        frame = bg.copy()
        frame.paste(layer, ((W - layer.width) // 2, (H - layer.height) // 2), layer)
        proc.stdin.write(frame.tobytes())

    proc.stdin.close()
    err = proc.stderr.read().decode("utf-8", "replace")
    if proc.wait() != 0:
        print("[FAIL]")
        print(err[-2000:])
        return 1
    print("OK:", out, out.stat().st_size)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
