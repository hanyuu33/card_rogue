# -*- coding: utf-8 -*-
## R532：把出图的白底两张奖励图标（金币 / 最大生命）抠成透明软边 PNG。
## 口径对齐已有的 assets/ui/reward_icons/*.png（alpha 有大量中间值 = 软边，不留白边）。
## 做法：① 按「近中性白」判背景（不用四角 floodfill —— 环洞里的白与外部不连通，会被漏掉）；
##       ② 背景 mask 轻微膨胀吃掉白边；③ 对 mask 做高斯羽化；
##       ④ 半透明像素按 (C_obs - 255*(1-a))/a 去白（despill），避免缩放后出现白描边。
import os
from PIL import Image, ImageFilter

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
SRC = {
    # R532b（用户口径「金币只需要金币袋，不需要外框」）：金币换成无线框的单体钱袋
    "gold": "Take_ONLY_the_subject_from_the_2026-11-08T14-54-40.png",
    "maxhp": "Match_the_exact_art_style_of_t_2026-11-08T14-35-54.png",
}
## 抠完再居中放到正方形画布，四周留白 —— 按主体类型分开：
## 无框的单个物件要留得多一点，否则 64px 下会比旁边「金环里的小主体」显大。
PAD = {"gold": 0.14, "maxhp": 0.045}
MIN_BLOB = 0.02            # 保留面积 ≥ 最大连通域 2% 的块（散落的金币别被当噪点丢掉）
TH_WHITE = 238             # 亮度阈值
TH_SAT = 0.22              # 饱和度上限（低于它才算「中性白」）
OPEN = 9                   # 白区开运算核：吃掉「小面积白岛」（主体的高光保留到前景）
FEATHER = 0.9              # 羽化半径


def is_bg(r, g, b):
    mx = max(r, g, b)
    mn = min(r, g, b)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    sat = 0.0 if mx == 0 else (mx - mn) / float(mx)
    return lum >= TH_WHITE and sat <= TH_SAT


def cut(name):
    im = Image.open(os.path.join(RAW, SRC[name])).convert("RGB")
    w, h = im.size
    src = im.load()
    mask = Image.new("L", (w, h), 0)
    mpx = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b = src[x, y]
            mpx[x, y] = 0 if is_bg(r, g, b) else 255
    # 背景膨胀 1px：把主体边缘那圈「白得发灰」的像素并进背景，抠得更干净
    mask = mask.filter(ImageFilter.MinFilter(3))
    # 面积过滤：白区先腐蚀再膨胀（开运算）—— 成片的背景保留，
    # 主体内部的小块高光（面积小于核）会被复原成前景，不会被抠成洞。
    # ⚠️ R532 maxhp：心形周围那圈「发光」在白底上看着无害，抠完会变成一块
    #    不透明的浅色圆片 —— 它正是大面积近白，靠这一步才能干净吃掉。
    bg = Image.eval(mask, lambda v: 255 - v)
    bg = bg.filter(ImageFilter.MinFilter(OPEN)).filter(ImageFilter.MaxFilter(OPEN))
    mask = Image.eval(bg, lambda v: 255 - v)
    # 最大连通域（丢掉零散噪点），保留主体
    mask = _keep_largest(mask)
    soft = mask.filter(ImageFilter.GaussianBlur(FEATHER))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    spx = soft.load()
    for y in range(h):
        for x in range(w):
            a = spx[x, y]
            if a == 0:
                continue
            r, g, b = src[x, y]
            if a < 250:                       # 去白：把背景白从观测色里减掉再归一
                k = a / 255.0
                r = max(0, min(255, int(round((r - 255.0 * (1.0 - k)) / k))))
                g = max(0, min(255, int(round((g - 255.0 * (1.0 - k)) / k))))
                b = max(0, min(255, int(round((b - 255.0 * (1.0 - k)) / k))))
            opx[x, y] = (r, g, b, a)

    bbox = out.getbbox()
    out = out.crop(bbox)
    side = int(max(out.size) * (1.0 + 2.0 * PAD[name]))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(out, ((side - out.width) // 2, (side - out.height) // 2), out)
    dst = os.path.join(BASE, name + ".png")
    canvas.save(dst)
    hist = canvas.getchannel("A").histogram()
    print("%-6s %s  alpha0=%d a255=%d mid=%d" % (
        name, canvas.size, hist[0], hist[255], sum(hist[1:255])))


def _keep_largest(mask):
    """保留面积够的前景连通域：最大的那块 + 所有 ≥ MIN_BLOB 倍它的块。

    只留「最大一块」会丢掉体外的散落金币（单体钱袋场景尤其常见），
    所以按面积比留，同时仍然丢掉细碎噪点。
    """
    w, h = mask.size
    px = mask.load()
    seen = [[False] * w for _ in range(h)]
    blobs = []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if px[x, y] == 0 or seen[y][x]:
                continue
            stack = [(x, y)]
            seen[y][x] = True
            pix = []
            while stack:
                cx, cy = stack.pop()
                pix.append((cx, cy))
                for nx, ny in ((cx + 2, cy), (cx - 2, cy), (cx, cy + 2), (cx, cy - 2)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and px[nx, ny] > 0:
                        seen[ny][nx] = True
                        stack.append((nx, ny))
            blobs.append(pix)
    if not blobs:
        return mask
    biggest = max(len(b) for b in blobs)
    out = Image.new("L", (w, h), 0)
    opx = out.load()
    for pix in blobs:
        if len(pix) < biggest * MIN_BLOB:
            continue
        for x, y in pix:
            for dy in (0, 1):
                for dx in (0, 1):
                    if x + dx < w and y + dy < h:
                        opx[x + dx, y + dy] = 255
    return out


for k in SRC:
    cut(k)
print("DONE")
