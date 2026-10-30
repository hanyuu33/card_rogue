"""生成战斗特效贴图（assets/fx/*.png）。

为什么要程序化生成而不是出图：FX 需要**真透明通道 + 柔和衰减**，
扩散模型给不了（边缘必带一圈白边，448 卡面下很难看）；而纯 `draw_circle`
又只能画硬边。程序化生成两头都占：形状精确、alpha 平滑、可复现。

产物（RGBA8）：
  fx_meteor.png   192×192  流星（亮核在正中，尾迹朝上）
  fx_beam.png     128×256  激光柱横截面（由外到内 红→橙→黄→白）
  fx_laser.png    128×256  冷色激光柱（蓝→青→冰白，芯更硬/边更窄，R449 充能巨炮）
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


# ---------------------------------------------------------------- 冷色激光柱（R449）
def gen_laser():
    """充能巨炮（9139）的激光柱 —— 冷色（蓝 → 青 → 冰白）。

    和 `fx_beam` 的区别不是换个色就完事：舰炮那根是**火焰**柱（外晕宽、色温暖、
    衰减拖得很长），这边的读图诉求是**激光**——外晕窄一半、芯压到 5.5px、
    再插三道机械感的细丝，缩到 448 卡面才不像一团橙色雾气。
    """
    w, h = 128, 256
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    for y in range(h):
        # 纵向脉冲：不是匀速色带，读作「电容放电」
        vmod = 1.0 + 0.10 * math.sin(y * 0.16) + 0.05 * (hash2(11, y) - 0.5)
        for x in range(w):
            u = (x - 63.5) / 64.0
            layers = [
                (0.50, 0.42, (0.20, 0.42, 1.00)),   # 外晕：深蓝
                (0.30, 0.70, (0.32, 0.78, 1.00)),   # 中层：青蓝
                (0.135, 0.95, (0.78, 0.97, 1.00)),  # 内层：冰白
                (0.055, 1.00, (1.00, 1.00, 1.00)),  # 芯：纯白
            ]
            idx = y * w + x
            for sig, amp, col in layers:
                a = math.exp(-(u / sig) ** 2) * amp * vmod
                over(buf, idx, col, clamp(a))
            # 三道细丝：机械感（火焰柱没有这种东西）
            for fu in (0.19, 0.34, 0.52):
                over(buf, idx, (0.86, 0.99, 1.00),
                     clamp(math.exp(-((abs(u) - fu) / 0.028) ** 2) * 0.16))

    # 收边：同 gen_beam —— 外晕高斯在 u=±1 处还剩 alpha，不压就是一个看得见的矩形框
    for y in range(h):
        fy = 1.0
        if y > h * 0.95:
            fy = clamp((h - 1 - y) / (h * 0.05))
        elif y < h * 0.05:
            fy = clamp(y / (h * 0.05))
        for x in range(w):
            u = abs((x - 63.5) / 64.0)
            win = 1.0 - clamp((u - 0.40) / 0.60) ** 2.0
            buf[y * w + x][3] *= clamp(win) * fy
    save(buf, w, h, "fx_laser.png")


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


# ---------------------------------------------------------------- 火焰爆团（R434）
def gen_flame():
    """灰烬龙战吼 / 冲击波扫过每一格的**火焰**。

    结构 = 底部一团圆钝火球 + 从球顶窜出去的 3 条火舌。
    ⚠️ 第一版用「极坐标把上半圈半径拉长」做火舌 → 上半圈整个被拉成锥形，
    还超出 192×256 画布被平切（出图一看就是一块橙色扇形）。现在拆成两段画：
    球是球、舌是舌，各自有自己的轮廓与颜色走势，形状才立得住。
    """
    w, h = 192, 256
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    # ---------- ① 火球主体（椭圆径向衰减） ----------
    cx, cy = 96.0, 178.0
    rx, ry = 61.0, 64.0
    stops = [
        (0.00, (1.00, 1.00, 0.98), 1.00),
        (0.15, (1.00, 0.97, 0.76), 1.00),
        (0.33, (1.00, 0.84, 0.32), 0.97),
        (0.54, (1.00, 0.55, 0.12), 0.86),
        (0.76, (0.90, 0.25, 0.07), 0.50),
        (1.00, (0.55, 0.11, 0.04), 0.00),
    ]
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            if d >= 1.0:
                continue
            col, a = stops_eval(stops, d)
            a *= 0.84 + 0.30 * hash2(x // 3, y // 3)   # 低频斑块：火团内部别是干净渐变
            over(buf, y * w + x, col, clamp(a))

    # ---------- ② 火舌（3 条，从球顶窜出去） ----------
    # (底部 x, 顶 y, 底 y, 相位, 最大半宽)
    tongues = [
        (73.0, 44.0, 152.0, 0.0, 30.0),
        (97.0, 22.0, 168.0, 1.9, 37.0),
        (121.0, 50.0, 150.0, 3.4, 28.0),
    ]
    for x0, ytop, ybot, ph, hwmax in tongues:
        for y in range(int(ytop), int(ybot) + 1):
            t = (float(ybot) - y) / (float(ybot) - float(ytop))   # 0 = 底，1 = 尖
            # 收窄分两段：中段几乎不收（火舌是「柱」不是「锥」），最后 35% 才收尖
            body = 1.0 if t < 0.65 else ((1.0 - t) / 0.35) ** 0.85
            wid = hwmax * (1.0 - 0.16 * t) * body
            if wid < 0.8:
                continue
            xc = x0 + 8.5 * math.sin(t * 2.9 + ph) * (0.25 + 0.75 * t)
            col = (lerp(1.00, 0.78, t), lerp(0.87, 0.21, t), lerp(0.38, 0.05, t))
            for x in range(max(0, int(xc - wid - 2)), min(w, int(xc + wid + 2))):
                u = abs(x - xc) / wid
                if u >= 1.0:
                    continue
                # `1 - u²` 是个圆润的钟形：火舌两侧是「软」的，不是一刀切的三角边
                a = (1.0 - u * u) ** 1.25
                a *= 0.55 + 0.45 * (1.0 - t)          # 越往上越淡
                a *= 0.72 + 0.28 * hash2(x // 4, y // 5)   # 边缘抖一点，别是规整轮廓
                over(buf, y * w + x, col, clamp(a * 0.88))
                # 舌心更亮的细芯（黄白）—— 火焰不是一条单色带
                if u < 0.34:
                    over(buf, y * w + x, (1.00, 0.97, 0.70),
                         clamp((0.34 - u) / 0.34 * a * 0.60))

    # ---------- ③ 底部暖光（火焰脚下的地面反光） ----------
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - 96.0) / 76.0, (y - 212.0) / 18.0)
            if d < 1.0:
                # 强度压到 0.16：0.30 时缩放到 ~90px 会在棋盘上留一块边界可见的橙斑
                over(buf, y * w + x, (1.00, 0.46, 0.13), (1.0 - d) ** 2.3 * 0.16)

    save(buf, w, h, "fx_flame.png")


# ---------------------------------------------------------------- 火星（R434）
def gen_ember():
    """上升的火星粒子。小、亮、柔和 —— 缩放绘制时靠它补「火在烧」的动感。"""
    w = h = 32
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - 15.5, y - 15.5) / 15.5
            if d >= 1.0:
                continue
            over(buf, y * w + x, (1.00, 0.90, 0.52), (1.0 - d) ** 1.5)
            if d < 0.34:
                over(buf, y * w + x, (1.00, 1.00, 0.96), (0.34 - d) / 0.34)
    save(buf, w, h, "fx_ember.png")


# ---------------------------------------------------------------- 电磁护盾球（R434）
def gen_shield():
    """启示者阶段 2 的电磁屏障：一颗**带六边形网格的力场球**。

    三层叠加：① 极淡的球体填充（中心透明、边缘略厚）；② 小六边形网格（越靠边越亮
    —— 球面透视，中间正面看过去几乎是平的）；③ 外沿 rim 亮带。
    颜色淡蓝偏紫，与 9202 卡面那套「电磁」配色一致。
    """
    w = h = 192
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    R = 90.0
    hexr = 13.0                 # 六边形外接圆半径
    hw = hexr * 1.7320508       # 水平间距
    vh = hexr * 1.5             # 垂直间距
    apothem = hexr * 0.8660254

    for y in range(h):
        ny = (y - 95.5) / R
        for x in range(w):
            nx = (x - 95.5) / R
            r = math.hypot(nx, ny)
            if r > 1.02:
                continue
            z = math.sqrt(max(0.0, 1.0 - min(1.0, r * r)))   # 球面法线的 z 分量

            # ① 球体填充：中心 0.04、边缘 0.13（球面的「厚度感」）——
            #    第一版边缘 0.20 + rim 0.80，出图读成「一个白色足球」，把卡面压住了
            over(buf, y * w + x, (0.40, 0.70, 1.00), (1.0 - z) * 0.13 + 0.04 * z)

            # ② 六边形网格：先把像素投到「最近六边形中心」的局部坐标，再算到边的距离
            u, v = nx * R, ny * R
            row = int(round(v / vh))
            best = None
            for dr in (-1, 0, 1):
                rr = row + dr
                off = (rr % 2) * hw * 0.5
                col0 = int(round((u - off) / hw))
                for dc in (-1, 0, 1):
                    ccx = off + (col0 + dc) * hw
                    ccy = rr * vh
                    d2 = math.hypot(u - ccx, v - ccy)
                    if best is None or d2 < best[0]:
                        best = (d2, u - ccx, v - ccy)
            lx, ly = best[1], best[2]
            sd = -1e9
            for k in range(6):
                a = k * math.pi / 3.0
                sd = max(sd, lx * math.cos(a) + ly * math.sin(a))
            dist_edge = apothem - sd
            line = math.exp(-(dist_edge / 1.15) ** 2)
            if line > 0.02:
                gcol = (lerp(0.68, 0.60, r), lerp(0.90, 0.58, r), 1.00)
                over(buf, y * w + x, gcol, line * (0.18 + 0.58 * r) * 0.62)

            # ③ 外沿 rim：球壳最亮的一圈
            rim = math.exp(-(((r - 0.875) / 0.085) ** 2))
            if rim > 0.01:
                over(buf, y * w + x, (0.72, 0.94, 1.00), rim * 0.52)

            # ④ 左上一片高光（读成「有光源打过球面」）
            spec = math.exp(-(((r - 0.80) / 0.16) ** 2)
                            - ((math.atan2(ny, nx) - (-2.42)) / 0.55) ** 2)
            if spec > 0.01:
                over(buf, y * w + x, (0.90, 0.98, 1.00), spec * 0.38)

    save(buf, w, h, "fx_shield.png")


# ---------------------------------------------------------------- 电弧（R434）
def gen_arc(name="fx_arc.png", glow_col=(0.46, 0.52, 1.00),
            mid_col=(0.68, 0.88, 1.00), core_col=(1.00, 1.00, 1.00)):
    """一截**电弧**（128×64）。

    中心线 = 一层缓正弦（整体弧度）+ 一层粗锯齿（hash 分段抖动）
    + 一层细锯齿，三层叠起来才像「电」；只用纯正弦读出来是一根软面条。
    两端 alpha 收到 0，拼接不留硬边。

    配色靠参数分出两套（R436）：
      · `fx_arc.png` 蓝白 —— 电磁屏障把伤害弹回攻击者；
      · `fx_arc_elec.png` 金黄 —— 麻痹诅咒塞进弃牌区时的「卡组被电了一下」。
    ⚠️ 别想着用 `modulate` 把蓝白那张乘成黄色：蓝分量 (0.52,0.60,1.00) 乘暖黄
    → 读出来是脏橄榄绿，不是电。必须重出一张底色就暖的。
    """
    w, h = 128, 64
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    def center(xp):
        t = xp / float(w - 1)
        env = math.sin(t * math.pi)                     # 两端回到中轴
        return (32.0
                + 6.0 * math.sin(t * 6.2 + 0.8) * env
                + 13.0 * (hash2(xp // 9, 5) - 0.5) * env
                + 6.0 * (hash2(xp // 3, 11) - 0.5) * env)

    for x in range(w):
        cyy = center(x)
        win = min(1.0, x / 8.0) * min(1.0, (w - 1 - x) / 8.0)
        for y in range(h):
            d = abs(y - cyy)
            glow = math.exp(-((d / 9.5) ** 2))
            core = math.exp(-((d / 2.3) ** 2))
            over(buf, y * w + x, glow_col, clamp(0.40 * glow * win))
            over(buf, y * w + x, mid_col, clamp(0.72 * glow * win))
            over(buf, y * w + x, core_col, clamp(1.00 * core * win))

    save(buf, w, h, name)


# ---------------------------------------------------------------- 冲击波环（R434）
def gen_shockwave():
    """启示者进入第三阶段「清场」的那一圈冲击波。

    主环 + 内侧淡雾，白偏青。绘制侧只做**径向放大**（scale 从 0.2 长到铺满全场），
    alpha 随时间收掉 —— 一张贴图就能当扩散波用。
    """
    w = h = 256
    buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
    for y in range(h):
        for x in range(w):
            r = math.hypot(x - 127.5, y - 127.5) / 127.5
            if r > 1.0:
                continue
            ring = math.exp(-(((r - 0.855) / 0.052) ** 2))
            halo = math.exp(-(((r - 0.72) / 0.16) ** 2)) * 0.30
            smoke = math.exp(-(((r - 0.52) / 0.30) ** 2)) * 0.10
            a = clamp(ring * 0.95 + halo + smoke)
            if a <= 0.004:
                continue
            gcol = (lerp(1.00, 0.72, r), lerp(0.99, 0.94, r), lerp(0.92, 1.00, r))
            over(buf, y * w + x, gcol, a)
    save(buf, w, h, "fx_shockwave.png")


def main():
    if not os.path.isdir(OUT):
        os.makedirs(OUT)
    print("生成特效贴图 ->", OUT)
    gen_meteor()
    gen_beam()
    gen_laser()
    gen_shine()
    gen_glow()
    gen_knife()
    gen_flame()
    gen_ember()
    gen_shield()
    gen_arc()
    gen_arc("fx_arc_elec.png", (0.62, 0.44, 0.05), (1.00, 0.83, 0.24), (1.00, 0.99, 0.76))
    gen_shockwave()
    print("完成")


if __name__ == "__main__":
    main()
