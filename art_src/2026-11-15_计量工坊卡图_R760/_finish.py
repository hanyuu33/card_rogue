# -*- coding: utf-8 -*-
"""R760 收尾：把 raw 裁成项目口径 448x404 写进 assets/pics/_pending/，并出验收页。

⚠️ 尺寸口径（R644 之后，**不要**再用旧 tools/cardart_prep.py 的 448x403）：
   素材统一 **448x404**；卡面按 CardFace.cover_region() 居中裁成 1.51:1
   （UiTheme.CARD_ART_RATIO = 0.662）→ 只显示第 53..350 行，上下各 53 行永远看不见。
   本脚本先裁 1.51:1 横带 → 448x297 → 上下补边 → 448x404。宽高都可被 4 整除。

⚠️ 本批是**插画**（有主体 + 暗背景），不能套 R759 的 clean_flat()（那是纯色底标志图用的，
   会把主体外的画面全部涂成底色）。补边用相邻行高斯模糊拉伸，接缝看不出来即可。

纪律 J：成品只落 _pending，**不自动覆盖主目录**、不 approve，等店长选版。

用法：
    python _finish.py            # 三张都裁进 _pending/ 并出验收页
    python _finish.py 9261       # 只处理指定卡
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_计量工坊卡图_R760")
RAW = os.path.join(D, "raw")
PEND = os.path.join(ROOT, "assets", "pics", "_pending")

RATIO = 1.0 / 0.662
W, H = 448, 404
BAND_H = round(W / RATIO)   # 297
PAD = (H - BAND_H) // 2     # 53
FONT = "C:/Windows/Fonts/msyh.ttc"

JOBS = [(9260, "常数测量员"), (9261, "精密计算者"), (9262, "负载增量员")]


SUBJ_GAP = 0.06   # head-safe：主体最高行在**可见带**内再往下留 6%
# ⚠️ 卡面 CardFace 只显示带内约 5%..95%，头尾各有一段隐藏区 —— 不把隐藏区
#    加进去，6% 的留白实际只剩 1%，头顶照样贴边（第一版就是这么错的）。
VIS_H = int(round(H * 0.662))          # 卡面真实可见高度 267
VIS_TOP = (H - VIS_H) // 2             # 可见带上边在 448x404 里的行号 68
HIDDEN_TOP = (VIS_TOP - PAD) / float(BAND_H)   # ≈ 0.0505


def subject_top(im):
    """主体最高行：亮黄铜 / 亮青 / 亮灰钢。背景是暗蓝模糊，三个条件都不满足。

    ⚠️ 不要按 alpha 判（图是不透明的）；也不要只按亮度判 —— 背景里有黄铜柜具和
    琥珀灯，亮度够但饱和度低。三个色相条件一起用才稳。
    """
    w, h = im.size
    px = im.load()

    def subj(r, g, b):
        if r > 150 and r > b + 55:
            return True          # 黄铜
        if b > 150 and b > r + 40:
            return True          # 青色发光缝 / 透镜
        if r > 120 and g > 120 and b > 120:
            return True          # 亮灰钢
        return False

    for y in range(0, h, 2):
        n = 0
        for x in range(0, w, 2):
            if subj(*px[x, y]):
                n += 1
                if n >= 6:       # 至少 6 个采样点，滤掉背景零散高光
                    return y
    return None


def cut(src, dst, head_safe=False):
    """1.51:1 横带 → 448x297 → 上下补边 → 448x404（RGBA）。

    head_safe=True → 裁切线按**主体最高行**定位、上方留 SUBJ_GAP；
    默认居中裁（老口径）。卡面只显示带内 5%..95%，所以居中裁会把
    「顶天立地」的构图切掉一截头顶 —— 需要保头时用 head_safe。
    """
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bw = int(round(h * RATIO))
    if bw <= w:
        left = (w - bw) // 2
        band = im.crop((left, 0, left + bw, h))
    else:
        bh = int(round(w / RATIO))
        top = (h - bh) // 2
        if head_safe:
            st = subject_top(im)
            if st is not None:
                top = max(0, min(h - bh, int(round(st - (HIDDEN_TOP + SUBJ_GAP) * bh))))
                print("   head-safe: 主体最高行=%d → 裁切 top=%d（居中口径 %d，上移 %d 行）"
                      % (st, top, (h - bh) // 2, (h - bh) // 2 - top))
        band = im.crop((0, top, w, top + bh))
    band = band.resize((W, BAND_H), Image.LANCZOS)

    full = Image.new("RGB", (W, H), (0, 0, 0))
    strip_t = band.crop((0, 0, W, 1)).resize((W, PAD)).filter(ImageFilter.GaussianBlur(3))
    strip_b = band.crop((0, BAND_H - 1, W, BAND_H)).resize(
        (W, H - BAND_H - PAD)).filter(ImageFilter.GaussianBlur(3))
    full.paste(strip_t, (0, 0))
    full.paste(band, (0, PAD))
    full.paste(strip_b, (0, PAD + BAND_H))

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    full.convert("RGBA").save(dst, optimize=True)
    return Image.open(dst).size


def sheet(items, out, cell_w=300):
    cell_h = int(round(cell_w * H / float(W)))
    padx, lb = 14, 28
    Wd = padx + len(items) * (cell_w + padx)
    Hd = padx + cell_h + lb + padx
    s = Image.new("RGB", (Wd, Hd), (20, 22, 28))
    d = ImageDraw.Draw(s)
    f = ImageFont.truetype(FONT, 17)
    for i, (label, p) in enumerate(items):
        x = padx + i * (cell_w + padx)
        im = Image.open(p).convert("RGB").resize((cell_w, cell_h), Image.LANCZOS)
        s.paste(im, (x, padx))
        top = padx + int(round(PAD * cell_h / float(H)))
        bot = padx + int(round((PAD + BAND_H) * cell_h / float(H)))
        d.rectangle([x, top, x + cell_w - 1, bot], outline=(90, 200, 130), width=2)
        d.text((x + 3, padx + cell_h + 5), label, fill=(235, 235, 240), font=f)
    s.save(os.path.join(D, out))
    print(out, s.size)


def main():
    args = sys.argv[1:]
    ver = "v2" if "--v2" in args else "v1"
    head_safe = "--head-safe" in args
    if head_safe:
        ver = "v2"          # 定稿取 v2；head-safe 只重裁 v2，不回头动 v1
    want = [int(a) for a in args if a.startswith("9")]
    items = []
    for cid, name in JOBS:
        if want and cid not in want:
            continue
        raw = os.path.join(RAW, "%d_%s_%s.png" % (cid, name, ver))
        if not os.path.exists(raw):
            print("缺 raw:", os.path.basename(raw))
            continue
        if head_safe:
            # R760b：用 v2 raw + 保头裁，这版才是要定稿的
            dst = os.path.join(PEND, "%d.png" % cid)
            print("cut %s(v2 head-safe) -> _pending/%d.png %s"
                  % (name, cid, cut(raw, dst, head_safe=True)))
        elif ver == "v1":
            # v1 才落 _pending（纪律 J：成品只落暂存区，等店长定版再 approve）
            dst = os.path.join(PEND, "%d.png" % cid)
            print("cut %s(v1) -> _pending/%d.png %s" % (name, cid, cut(raw, dst)))
        else:
            # v2 只出对照图，不动 _pending
            dst = os.path.join(D, "_R760_448x404_v2_%d.png" % cid)
            print("cut %s(v2) -> %s %s" % (name, os.path.basename(dst), cut(raw, dst)))
        items.append(("%d %s" % (cid, name), dst))
    if items:
        tag = "_定稿_保头" if head_safe else ("" if ver == "v1" else "_v2")
        sheet(items, "_R760_卡面验收%s.png" % tag)
        for _, p in items:
            im = Image.open(p)
            assert im.size == (W, H), (p, im.size)
        print("规格校验 OK：%d 张，全部 448x404（RGBA 见 .mode=%s）" % (
            len(items), Image.open(items[0][1]).mode))


if __name__ == "__main__":
    main()
