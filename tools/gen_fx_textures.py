"""生成战斗特效贴图（assets/fx/*.png）。

为什么要程序化生成而不是出图：FX 需要**真透明通道 + 柔和衰减**，
扩散模型给不了（边缘必带一圈白边，448 卡面下很难看）；而纯 `draw_circle`
又只能画硬边。程序化生成两头都占：形状精确、alpha 平滑、可复现。

产物（RGBA8）：
  fx_meteor.png   192×192  流星（亮核在正中，尾迹朝上）
  fx_beam.png     128×256  激光柱横截面（由外到内 红→橙→黄→白）
  fx_shine.png     96×24   柱身流动亮带
  fx_knife.png     96×160  飞刀（刀尖朝上）
  fx_glow.png     128×128  通用柔光（落地亮斑 / 拖尾 / 枪口光）

用法：python tools/gen_fx_textures.py
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fx")


def clamp(v, a=0.0, b=1.0):
    return a if v < a else (b if v > b else v)


def lerp(a, b, t):
    return a + (b - a) * t


def hash2(x, y):
    """便宜的确定性噪声（不引入 numpy）。"""
    n = (int(x) * 374761393 + int(y) * 668265263) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def stops_eval(stops, t):
    """按 (位置, RGB[, alpha]) 的档位插值；省略 alpha 视作 1。"""
    if len(stops[0]) == 2:
        stops = [(p, c, 1.0) for p, c in stops]
    if t <= stops[0][0]:
        return stops[0][1], stops[0][2]
    if t >= stops[-1][0]:
        return stops[-1][1], stops[-1][2]
    for i in range(len(stops) - 1):
        p0, c0, a0 = stops[i]
        p1, c1, a1 = stops[i + 1]
        if p0 <= t <= p1:
            k = 0.0 if p1 <= p0 else (t - p0) / (p1 - p0)
            return ((lerp(c0[0], c1[0], k), lerp(c0[1], c1[1], k),
                     lerp(c0[2], c1[2], k)), lerp(a0, a1, k))
    return stops[-1][1], stops[-1][2]


def over(buf, idx, col, a):
    """标准 source-over（直通 alpha，不预乘）。"""
    a = clamp(a)
    if a <= 0.0:
        return
    da = buf[idx][3]
    oa = a + da * (1.0 - a)
    if oa <= 0.0:
        buf[idx] = [0.0, 0.0, 0.0, 0.0]
        return
    for c in range(3):
        buf[idx][c] = (col[c] * a + buf[idx][c] * da * (1.0 - a)) / oa
    buf[idx][3] = oa


def save(buf, w, h, name):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            p = buf[y * w + x]
            px[x, y] = (int(clamp(p[0]) * 255 + 0.5), int(clamp(p[1]) * 255 + 0.5),
                        int(clamp(p[2]) * 255 + 0.5), int(clamp(p[3]) * 255 + 0.5))
    path = os.path.join(OUT, name)
    img.save(path)
    print("  %-16s %dx%d  %.1f KB" % (name, w, h, os.path.getsize(path) / 1024.0))


# ---------------------------------------------------------------- 流星
def gen_meteor():
    # 头部在 (80, 176)、尾迹朝上 176px —— 尾巴要够长，缩到 448 才像「拖着火飞下来」。
    # 旋转时以头部为轴心，所以绘制侧用 Rect2(-80, -176, 160, 256) 就正好对齐。
    w, h = 160, 256
    cx, cy = 80, 176
    rad = 42.0
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    # 尾迹：从头部（t=0）向上拉到 t=1，宽度收窄、偏冷变暗，带一点摆动与碎纹
    tail = [
        (0.00, (1.00, 0.94, 0.64)),
        (0.18, (1.00, 0.79, 0.28)),
        (0.42, (1.00, 0.47, 0.13)),
        (0.70, (0.92, 0.24, 0.09)),
        (1.00, (0.62, 0.10, 0.05)),
    ]
    for y in range(0, cy + 1):
        t = (cy - y) / float(cy)
        if t > 1.0:
            continue
        half = 29.0 * (1.0 - t) ** 0.52 + 2.0
        wob = 3.2 * math.sin(t * 5.4)         # 火舌似的轻微左右摆
        col, _ = stops_eval(tail, t)
        for x in range(w):
            hx = 1.0 - abs(x - cx - wob) / half
            if hx <= 0.0:
                continue
            a = 0.98 * (1.0 - t) ** 0.95 * (hx ** 1.35)
            a *= 0.84 + 0.30 * hash2(x, y)     # 碎纹：别是一块干净的锥子
            over(buf, y * w + x, col, a)

    # 亮核：由外到内 红 → 橙 → 黄 → 白（与游戏里那套色阶同一口径）
    head = [
        (0.00, (1.00, 1.00, 0.99), 1.00),
        (0.12, (1.00, 0.98, 0.80), 1.00),
        (0.26, (1.00, 0.88, 0.42), 0.99),
        (0.42, (1.00, 0.66, 0.18), 0.95),
        (0.62, (1.00, 0.40, 0.11), 0.78),
        (0.82, (0.88, 0.20, 0.08), 0.34),
        (1.00, (0.60, 0.10, 0.05), 0.00),
    ]
    for y in range(h):
        for x in range(w):
            r = math.hypot(x - cx, y - cy) / rad
            if r > 1.0:
                continue
            col, a = stops_eval(head, r)
            over(buf, y * w + x, col, a * (0.95 + 0.08 * hash2(x * 3, y * 3)))

    save(buf, w, h, "fx_meteor.png")


# ---------------------------------------------------------------- 激光柱
def gen_beam():
    w, h = 128, 256
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    for y in range(h):
        # 纵向一点点明暗起伏（拉长后就是流动的条纹感）
        vmod = 1.0 + 0.09 * math.sin(y * 0.09) + 0.06 * (hash2(7, y) - 0.5)
        for x in range(w):
            u = (x - 63.5) / 64.0
            layers = [
                (0.62, 0.58, (1.00, 0.24, 0.09)),   # 外晕：红
                (0.40, 0.78, (1.00, 0.52, 0.13)),   # 中层：橙
                (0.20, 0.94, (1.00, 0.84, 0.32)),   # 内层：黄
                (0.075, 1.00, (1.00, 1.00, 0.96)),  # 芯：白
            ]
            idx = y * w + x
            for sig, amp, col in layers:
                a = math.exp(-(u / sig) ** 2) * amp * vmod
                over(buf, idx, col, clamp(a))
            # 两道细丝：让柱身不是一块均匀的渐变
            for fu in (0.26, 0.47):
                over(buf, idx, (1.00, 0.92, 0.62),
                     clamp(math.exp(-((abs(u) - fu) / 0.045) ** 2) * 0.13))

    # ⚠️ 收边：外晕的高斯在 u=±1 处还剩 4% alpha → 画出来是一圈**看得见的矩形边**。
    # 这里乘一个横向窗把两侧压到 0，底部 5% 也收到 0（不然和地面交界是一条刀切）。
    for y in range(h):
        fy = 1.0
        if y > h * 0.95:
            fy = clamp((h - 1 - y) / (h * 0.05))
        elif y < h * 0.05:
            fy = clamp(y / (h * 0.05))
        for x in range(w):
            u = abs((x - 63.5) / 64.0)
            win = 1.0 - clamp((u - 0.42) / 0.58) ** 2.0
            idx = y * w + x
            buf[idx][3] *= clamp(win) * fy
    save(buf, w, h, "fx_beam.png")


# ---------------------------------------------------------------- 柱身流动亮带
def gen_shine():
    w, h = 96, 24
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    for y in range(h):
        for x in range(w):
            a = math.exp(-((x - 47.5) / 34.0) ** 2 - ((y - 11.5) / 5.6) ** 2)
            over(buf, y * w + x, (1.00, 0.97, 0.84), clamp(a))
    save(buf, w, h, "fx_shine.png")


# ---------------------------------------------------------------- 通用柔光
def gen_glow():
    w = h = 128
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - 63.5, y - 63.5) / 63.5
            if d >= 1.0:
                continue
            a = (1.0 - d) ** 2.2
            over(buf, y * w + x, (1.0, 0.98, 0.94), a)
    save(buf, w, h, "fx_glow.png")


# ---------------------------------------------------------------- 飞刀
def gen_knife():
    w, h = 96, 160
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    # ① 背后一层紫晕（暗影刺客的职业色）—— 让刀在浅色棋盘上立得住
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - 48) / 26.0, (y - 78) / 62.0)
            if d < 1.0:
                over(buf, y * w + x, (0.58, 0.32, 1.00), (1.0 - d) ** 2.2 * 0.46)

    # ② 刀身：刀尖在 (48,4)，向下展宽，护手在 y≈94
    tip_y, base_y = 4.0, 94.0
    for y in range(int(tip_y), int(base_y) + 1):
        p = (y - tip_y) / (base_y - tip_y)
        half = 15.0 * (p ** 0.55) * (1.0 - 0.22 * p) + 0.6
        for x in range(w):
            dx = x - 48.0
            if abs(dx) > half + 0.8:
                continue
            t = clamp((dx + half) / (2.0 * half))      # 0=左缘 1=右缘
            if t < 0.40:
                k = t / 0.40
                col = (lerp(0.66, 0.82, k), lerp(0.74, 0.88, k), lerp(0.90, 0.99, k))
            else:
                k = (t - 0.40) / 0.60
                col = (lerp(0.82, 0.24, k), lerp(0.88, 0.29, k), lerp(0.99, 0.44, k))
            # 中脊高光（很窄的一条纯白，别整片发白）
            if 0.31 < t < 0.375:
                col = (1.0, 1.0, 1.0)
            edge = clamp((half + 0.8 - abs(dx)) / 1.4)   # 1.4px 抗锯齿
            over(buf, y * w + x, col, edge)

    # ③ 护手
    for y in range(94, 105):
        for x in range(w):
            if abs(x - 48) > 22.5:
                continue
            k = (y - 94) / 11.0
            col = (lerp(0.52, 0.30, k), lerp(0.42, 0.24, k), lerp(0.32, 0.18, k))
            if y < 96:
                col = (0.72, 0.60, 0.40)
            over(buf, y * w + x, col, clamp(22.5 - abs(x - 48)) if abs(x - 48) > 21.5 else 1.0)

    # ④ 握柄 + 缠绳
    for y in range(105, 142):
        for x in range(w):
            dx = abs(x - 48)
            if dx > 7.5:
                continue
            wrap = 0.16 if (y % 7) < 3 else 0.00
            col = (0.24 + wrap, 0.19 + wrap, 0.17 + wrap)
            if dx < 2.0:
                col = (col[0] + 0.10, col[1] + 0.08, col[2] + 0.07)
            over(buf, y * w + x, col, clamp((7.5 - dx) / 1.2))

    # ⑤ 柄头
    for y in range(140, 152):
        for x in range(w):
            d = math.hypot(x - 48, y - 145.5)
            if d > 6.5:
                continue
            k = clamp(d / 6.5)
            col = (lerp(0.66, 0.34, k), lerp(0.56, 0.28, k), lerp(0.36, 0.18, k))
            over(buf, y * w + x, col, clamp((6.5 - d) / 1.1))

    # ⑥ 描边：沿**实心轮廓**内侧压一圈暗边（赛璐璐口径）。
    #    阈值取 0.55 =「实心」—— 紫色柔光本身是半透明的，不能让它参与定轮廓，
    #    否则暗边会跑到光晕外沿去，刀就成了个黑洞。
    solid = [buf[i][3] > 0.55 for i in range(w * h)]
    dark = [row[:] for row in buf]
    for y in range(h):
        for x in range(w):
            idx = y * w + x
            if not solid[idx]:
                continue
            rim = False
            for oy in (-2, -1, 0, 1, 2):
                for ox in (-2, -1, 0, 1, 2):
                    nx, ny = x + ox, y + oy
                    if 0 <= nx < w and 0 <= ny < h and not solid[ny * w + nx]:
                        rim = True
                        break
                if rim:
                    break
            if rim:
                k = 0.90
                dark[idx] = [lerp(buf[idx][0], 0.09, k),
                             lerp(buf[idx][1], 0.07, k),
                             lerp(buf[idx][2], 0.12, k),
                             buf[idx][3]]
    buf = dark

    save(buf, w, h, "fx_knife.png")


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    print("生成特效贴图 ->", OUT)
    gen_meteor()
    gen_beam()
    gen_shine()
    gen_glow()
    gen_knife()
    print("完成")


if __name__ == "__main__":
    main()
