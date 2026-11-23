# -*- coding: utf-8 -*-
"""R785 免伤力场：codex 黑底圆环图 → 两种透明贴图。

产物一（圆环版，`fx_cap_aura_0N.png`）：
    「黑底 → 亮度转 alpha」直接复用 R628 独行特效的 `black_to_alpha()`
    （同一套口径：黑=没光=全透明，亮金属=不透明，光晕自然半透）。

产物二（贴卡版，`fx_cap_aura_0N_card.png`）—— **实战用的是这一套**：
    卡牌是矩形，圆环套上去有两个硬伤（R785 首版实拍）：
      ① 环外径 138 > 格子宽 124，相邻两个满额度单位的环会互相咬在一起；
      ② 环与卡边之间留一圈空气，读起来是「卡牌漂在一个呼啦圈里」，不是「被罩住」。
    做法：**极坐标剖面 + 矩形距离场重映射** —— 先量出 AI 环带在每个角度上的
    内缘/外缘半径，再把目标画布上「到卡牌矩形的带距离 t / 方向 θ」映射回源图
    `r = rin(θ) + t * (rout(θ) - rin(θ))`。等于把那道圆环沿卡牌轮廓抻成圆角矩形框，
    纹理本身（六角晶格 / 符文 / 棱面）跟着流动，不会被切碎。

用法：python _finish_fx.py            # 两套都出
      python _finish_fx.py 01         # 只出 cap_aura_01
"""
import importlib.util
import math
import os
import sys

from PIL import Image

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-17_免伤力场素材_R785")
RAW = os.path.join(D, "raw")
PROC = os.path.join(D, "processed")
FX = os.path.join(ROOT, "assets", "fx")
R628 = os.path.join(ROOT, "art_src", "2026-11-12_独行特效_R628", "_finish_fx.py")

# ---- 圆环版参数 ----
RING_PX = 138      # 环外径（屏幕像素）：卡对角线 120.0 再放宽 18
RING_SCALE = 4
RING_PAD = 6
# alpha 曲线口径 = R628：亮度直接当不透明度，gamma 0.85 略微「放宽」弱光。
# ⚠️ 别把光晕收紧（试过 gain 1.18 + gamma 1.10）：素材缩到 11.5px 环带后只剩一根细线，
#    实战里被水面背景吃掉，读不出「罩住」（R785 第三版实拍）。
ALPHA_GAIN = 1.0
ALPHA_GAMMA = 0.85

# ---- 贴卡版参数（与 battle_scene.gd 的 CAP_AURA_BAND / CAP_AURA_PAD_PX 同源）----
CARD_W = 76.5      # 战场卡宽（屏幕像素）= 63 * 124/102
CARD_H = 92.5
BAND = 11.5        # 环带厚度：11.5px
GAP = 3.0          # 环带内缘与卡边之间的空气：**必须留** —— 严丝合缝地压上去会被
                   #   读成「卡牌边框加粗了」，而不是「多了个结界」（R780b 就踩过）。
                   #   总宽 = 76.5 + 2*(3+11.5+6) ≈ 117.5 < 格宽 124 → 相邻不咬。
PAD_S = 6.0        # 环带外留白
CARD_SCALE = 4
NA = 720           # 极坐标剖面角度数

JOBS = {
    "cap_aura_01": ("fx_cap_aura_01.png", "fx_cap_aura_01_card.png"),
    "cap_aura_02": ("fx_cap_aura_02.png", "fx_cap_aura_02_card.png"),
    "cap_aura_03": ("fx_cap_aura_03.png", "fx_cap_aura_03_card.png"),
}

spec = importlib.util.spec_from_file_location("r628fx", R628)
r628 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r628)


# --------------------------------------------------------------------------- 圆环版
def tight(im: Image.Image) -> Image.Image:
    """按 alpha 裁到环带外接框（正方形、中心对齐）—— bbox 就是环外径。"""
    bb = im.getbbox()
    if bb is None:
        return im
    cx, cy = (bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0
    half = max(bb[2] - bb[0], bb[3] - bb[1]) / 2.0
    return im.crop((int(round(cx - half)), int(round(cy - half)),
                    int(round(cx + half)), int(round(cy + half))))


def finish_ring(im: Image.Image) -> Image.Image:
    ring = RING_PX * RING_SCALE
    pad = RING_PAD * RING_SCALE
    im = tight(im).resize((ring, ring), Image.LANCZOS)
    canvas = Image.new("RGBA", (ring + pad * 2, ring + pad * 2), (0, 0, 0, 0))
    canvas.paste(im, (pad, pad))
    return canvas


# --------------------------------------------------------------------------- 贴卡版
def profile(im: Image.Image, lo: int = 58, hi: int = 22):
    """极坐标剖面：每个角度上环带的 内缘 / 外缘 半径。

    lo 取高一点（内缘要"实"，别把环内侧的薄雾当内缘）；
    hi 取低一点（外缘要带上淡光晕，否则从 t=1 切下去会出现一圈可见硬边）。
    """
    px = im.load()
    W, H = im.size
    cx, cy = W / 2.0, H / 2.0
    maxr = min(cx, cy) - 2.0
    ins, outs = [], []
    for i in range(NA):
        a = 2.0 * math.pi * i / NA
        ca, sa = math.cos(a), math.sin(a)
        rout = 0.0
        r = maxr
        while r > 2.0:
            x, y = int(cx + ca * r), int(cy + sa * r)
            if 0 <= x < W and 0 <= y < H and px[x, y][3] > hi:
                rout = r
                break
            r -= 2.0
        rin = 0.0
        r = 2.0
        while r < rout:
            x, y = int(cx + ca * r), int(cy + sa * r)
            if 0 <= x < W and 0 <= y < H and px[x, y][3] > lo:
                rin = r
                break
            r += 2.0
        if rout <= rin:
            rin, rout = 0.0, 0.0
        ins.append(rin)
        outs.append(rout)
    return ins, outs


def bilinear(px, W, H, x, y):
    if x < 0 or y < 0 or x >= W - 1 or y >= H - 1:
        return (0, 0, 0, 0)
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    p00 = px[x0, y0]
    p10 = px[x0 + 1, y0]
    p01 = px[x0, y0 + 1]
    p11 = px[x0 + 1, y0 + 1]
    out = []
    for k in range(4):
        top = p00[k] * (1 - fx) + p10[k] * fx
        bot = p01[k] * (1 - fx) + p11[k] * fx
        out.append(int(round(top * (1 - fy) + bot * fy)))
    return tuple(out)


def remap_card(src: Image.Image, ins, outs) -> Image.Image:
    """把圆环沿卡牌轮廓抻成圆角矩形框。"""
    sw, sh = src.size
    scx, scy = sw / 2.0, sh / 2.0
    srcp = src.load()

    cw = CARD_W * CARD_SCALE
    ch = CARD_H * CARD_SCALE
    band = BAND * CARD_SCALE
    gap = GAP * CARD_SCALE
    pad = PAD_S * CARD_SCALE
    W = int(round(cw + 2 * (gap + band + pad)))
    H = int(round(ch + 2 * (gap + band + pad)))
    a, b = cw / 2.0, ch / 2.0
    per = 2.0 * (cw + ch)          # 卡牌矩形周长（归一化切向坐标用）

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    op = out.load()

    cos_t = [math.cos(2 * math.pi * i / NA) for i in range(NA)]
    sin_t = [math.sin(2 * math.pi * i / NA) for i in range(NA)]

    for y in range(H):
        py_ = y + 0.5 - H / 2.0
        dy = abs(py_) - b
        for x in range(W):
            px_ = x + 0.5 - W / 2.0
            dx = abs(px_) - a
            if dx <= 0.0 and dy <= 0.0:
                continue                       # 卡内：全透明，卡面自己会画
            qx = dx if dx > 0.0 else 0.0
            qy = dy if dy > 0.0 else 0.0
            d = math.hypot(qx, qy)
            if d < gap or d > gap + band:
                continue          # 卡边到环带内缘之间的空气 / 环带之外：都透明
            t = (d - gap) / band
            # 切向坐标 = **沿矩形周长**的归一化位置 s，不是「方向角 θ」。
            # ⚠️ 用 θ 会踩大坑（R785 第二版实拍）：一条边上所有像素的方向角几乎相同，
            #    于是整条边都在源图同一条射线上取样，纹理被抹成横条纹 / 纯色块。
            #    换成周长位置后，纹理沿卡牌轮廓等距铺开，只有等向压缩，没有单向拉伸。
            if dy <= 0.0 and -a <= px_ <= a:
                s = (px_ + a) / per                     # 上边：左→右
            elif dy > 0.0 and -a <= px_ <= a:
                s = (2 * a + 2 * b + (a - px_)) / per   # 下边：右→左
            elif dx > 0.0 and -b <= py_ <= b:
                s = (2 * a + (py_ + b)) / per           # 右边：上→下
            elif dx <= 0.0 and -b <= py_ <= b:
                s = (4 * a + 2 * b + (b - py_)) / per   # 左边：下→上
            else:
                # 角部：最近点是角点，整块共用一个周长位置（径向靠 t 拉开）
                if px_ > 0.0 and py_ < 0.0:
                    s = (2 * a) / per
                elif px_ > 0.0:
                    s = (2 * a + 2 * b) / per
                elif py_ > 0.0:
                    s = (4 * a + 2 * b) / per
                else:
                    s = 0.0
            k = (s % 1.0) * NA
            i0 = int(k) % NA
            i1 = (i0 + 1) % NA
            f = k - int(k)
            rin = ins[i0] * (1 - f) + ins[i1] * f
            rout = outs[i0] * (1 - f) + outs[i1] * f
            if rout <= rin:
                continue
            r = rin + t * (rout - rin)
            sx = scx + cos_t[i0] * r
            sy = scy + sin_t[i0] * r
            op[x, y] = bilinear(srcp, sw, sh, sx, sy)
    return out


# --------------------------------------------------------------------------- 主流程
def main() -> int:
    os.makedirs(PROC, exist_ok=True)
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    done, miss = [], []
    for key, (name_ring, name_card) in JOBS.items():
        if only and key.split("_")[-1] not in only and key not in only:
            continue
        src = os.path.join(RAW, "%s.png" % key)
        if not os.path.exists(src):
            miss.append(key)
            print("MISS %s（还没出图）" % key)
            continue
        base = r628.black_to_alpha(src)
        a = base.split()[3].point(
            lambda x: int(round(255.0 * min(1.0, (x / 255.0) * ALPHA_GAIN) ** ALPHA_GAMMA)))
        base.putalpha(a)

        ring = finish_ring(base)
        ring.save(os.path.join(PROC, name_ring))
        ring.save(os.path.join(FX, name_ring))

        ins, outs = profile(base)
        card = remap_card(base, ins, outs)
        card.save(os.path.join(PROC, name_card))
        card.save(os.path.join(FX, name_card))

        def stat(im):
            ch = im.split()[3]
            nz = sum(1 for v in ch.tobytes() if v > 8)
            return (100.0 * nz / float(im.width * im.height),
                    im.width, im.height,
                    os.path.getsize(os.path.join(FX, im is ring and name_ring or name_card)) // 1024)

        r1, w1, h1, k1 = stat(ring)
        r2, w2, h2, k2 = stat(card)
        rin_mid = sorted(ins)[NA // 2]
        rout_mid = sorted(outs)[NA // 2]
        print("OK   %-12s 环 %dx%d(%.1f%%, %dKB)  贴卡 %dx%d(%.1f%%, %dKB)  剖面 r=%.0f→%.0f"
              % (key, w1, h1, r1, k1, w2, h2, r2, k2, rin_mid, rout_mid))
        done.append(key)
    print("DONE", len(done), "MISS", miss)
    return 0 if not miss else 2


if __name__ == "__main__":
    raise SystemExit(main())
