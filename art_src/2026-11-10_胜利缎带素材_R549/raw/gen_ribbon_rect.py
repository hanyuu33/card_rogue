# -*- coding: utf-8 -*-
"""R549：只把「战斗胜利四个字 + 一圈绿缎带」从设计稿切下来，贴到空白底板上。

用户口径：「直接裁剪完整素材（带文字的缎带）不至于有这种问题吧」—— 对，问题不在裁剪，
在 R548 的抠图。它用三路遮罩（逐列绿段 + 金字补洞 + 连通域过滤）互相打架，
字内部的中暗调像素哪一路都不满足 → 被挖成小洞，贴上底板后透出底层绿色，看着像绿斑。

R549 的切法（不抠形状，只切矩形）：
  * 边界四边都落在**纯绿缎带内部**（实测字 bbox 各扩 8px），不碰金滚边、不碰盾徽；
  * 矩形内每个像素原样保留、完全不透明 —— 物理上不可能出现洞；
  * 矩形边只做 4px 柔化，因为边两侧本来就是同一块绿，色差在纹理起伏范围内，看不出来；
  * 盾徽、月桂、两端飘带翼全部留给空白底板原生那套 —— 少抠一块就少一处错位。

实测（设计稿 1536×1024 原图坐标）：
  字 bbox  x 555..983  y 152..237      （判据：min(r,g,b) >= 150 的亮米金）
  缎带绿在字两侧的竖直范围约 y 95..250（逐列采样，盾徽列会偏高，取保守值）

产出：
  assets/ui/battle_win_ribbon.png   游戏素材（显示尺寸的 2 倍）
  _preview/r549_cut.png             裁块本体（品红底）
  _preview/r549_comp580.png         合成验证（580 面板尺寸）
用法：python _r549_make.py
"""
import os
from PIL import Image, ImageFilter

SRC = 'C:/Users/Administrator/.codex/generated_images/01a1c0c6-07c7-7b60-8d80-942b79b88c8a/exec-f8dca5cb-4a57-4490-b679-e15858921429.png'
PLATE = 'art_src/2026-11-09_战斗结算UI_R546/raw/359ff0b3_胜利面板空白底板_原图.png'

# 设计稿里的字 bbox（实测）与向外扩的边距
TEXT_BBOX = (555, 152, 983, 237)
PAD = 8
FEATHER = 4                      # 矩形边柔化宽度（原图像素）

GREEN_A = (252, 88, 1276, 295)   # 设计稿缎带绿色外接框（对齐锚点）
GREEN_B = (107, 180, 1145, 385)  # 空白底板缎带绿色外接框

OUT = 'assets/ui/battle_win_ribbon.png'
PREVIEW = '_preview/r549_comp580.png'
CUT_PREVIEW = '_preview/r549_cut.png'


def rect_alpha(w, h, feather):
    a = Image.new('L', (w, h), 255)
    p = a.load()
    for y in range(h):
        for x in range(w):
            d = min(x, w - 1 - x, y, h - 1 - y)
            if d < feather:
                p[x, y] = int(255 * d / feather)
    return a


def main():
    x0, y0, x1, y1 = TEXT_BBOX
    box = (x0 - PAD, y0 - PAD, x1 + PAD + 1, y1 + PAD + 1)
    blk = Image.open(SRC).convert('RGBA').crop(box)
    w, h = blk.size
    blk.putalpha(rect_alpha(w, h, FEATHER))
    print('[cut] 矩形 %s  %dx%d' % (box, w, h))

    # 洞检查：矩形内除了边缘柔化，不该有任何透明像素
    ap = blk.split()[3].load()
    inner_holes = sum(1 for y in range(FEATHER, h - FEATHER)
                      for x in range(FEATHER, w - FEATHER) if ap[x, y] < 250)
    print('[cut] 内部透明像素 %d 处（应为 0）' % inner_holes)
    assert inner_holes == 0, '矩形内部出现透明像素，字会被咬穿'

    cut = Image.new('RGBA', (w, h), (255, 0, 255, 255))
    Image.alpha_composite(cut, blk).convert('RGB').save(CUT_PREVIEW)

    # ---- 对齐到空白底板 ----
    s = (GREEN_B[2] - GREEN_B[0]) / float(GREEN_A[2] - GREEN_A[0])   # 缎带宽度比
    cax = (GREEN_A[0] + GREEN_A[2]) / 2.0
    cay = (GREEN_A[1] + GREEN_A[3]) / 2.0
    cbx = (GREEN_B[0] + GREEN_B[2]) / 2.0
    cby = (GREEN_B[1] + GREEN_B[3]) / 2.0
    pxx = int(round(cbx + (box[0] - cax) * s))
    pyy = int(round(cby + (box[1] - cay) * s))
    tw, th = int(round(w * s)), int(round(h * s))

    K = 580.0 / 1254.0
    disp_w, disp_h = tw * K, th * K
    print('[game] 显示 %.1fx%.1f  @ (%.1f, %.1f)   缩放系数=1/%.4f'
          % (disp_w, disp_h, pxx * K, pyy * K, tw / disp_w))

    # 素材：按显示尺寸的 2 倍出图（和项目其它 UI 素材一致，游戏里 *0.5 贴）
    out_w = int(round(disp_w * 2))
    out_h = int(round(disp_h * 2))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    blk.resize((out_w, out_h), Image.LANCZOS).save(OUT, optimize=True)
    print('[out] %s %dx%d' % (OUT, out_w, out_h))

    # ---- 合成验证 ----
    comp = Image.open(PLATE).convert('RGBA').copy()
    comp.alpha_composite(blk.resize((tw, th), Image.LANCZOS), (pxx, pyy))
    comp.convert('RGB').resize((580, 580), Image.LANCZOS).save(PREVIEW)
    print('[preview] %s' % PREVIEW)


if __name__ == '__main__':
    main()
