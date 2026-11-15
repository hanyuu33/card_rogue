# -*- coding: utf-8 -*-
"""R760b：给 _finish.py 加「头部安全裁」（宁可裁脚，不裁头）。

背景：raw 是 1254x1254，cut() 用**居中**裁出 1.51:1 横带（raw 第 212..1042 行），
再 resize 成 448x297、上下补边成 448x404。但卡面 CardFace 只显示中间 68..335 行
（= 真实带的 5.05%..94.9% = raw 的 254..1000 行）—— 所以 raw 的 212..254 这 42 行
虽然"裁进来了"，实机上**永远看不到**。

9261 的号筒顶端在 raw 第 211 行（刚好压在裁切线外 1 行）+ 可见区从 254 行起
→ 实机上号筒被切掉 43 行。改成按主体最高行定位裁切线（留 6% 空白）即可。

用法：
    python _finish.py --head-safe 9261        # 重裁并覆盖 _pending/9261.png
    python _finish.py --head-safe 9260 9262   # 同理
"""
import io
import os
import sys

P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_finish.py")
s = io.open(P, encoding="utf-8").read()

# ---------- ① 插入 subject_top() ----------
ANCHOR1 = '''def cut(src, dst):
    """1.51:1 居中横带 → 448x297 → 上下补边 → 448x404（RGBA）。"""
    im = Image.open(src).convert("RGB")
    w, h = im.size
    bw = int(round(h * RATIO))
    if bw <= w:
        left = (w - bw) // 2
        band = im.crop((left, 0, left + bw, h))
    else:
        bh = int(round(w / RATIO))
        top = (h - bh) // 2
        band = im.crop((0, top, w, top + bh))'''

NEW1 = '''SUBJ_GAP = 0.06   # head-safe：主体最高行上方留 6% 带高（约 raw 50 行）


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
                top = max(0, min(h - bh, int(round(st - SUBJ_GAP * bh))))
                print("   head-safe: 主体最高行=%d → 裁切 top=%d（居中口径 %d，上移 %d 行）"
                      % (st, top, (h - bh) // 2, (h - bh) // 2 - top))
        band = im.crop((0, top, w, top + bh))'''

assert s.count(ANCHOR1) == 1, "锚点① 命中 %d 次" % s.count(ANCHOR1)
s = s.replace(ANCHOR1, NEW1)

# ---------- ② main：支持 --head-safe ----------
ANCHOR2 = '''    ver = "v2" if "--v2" in args else "v1"'''
NEW2 = '''    ver = "v2" if "--v2" in args else "v1"
    head_safe = "--head-safe" in args
    if head_safe:
        ver = "v2"          # 定稿取 v2；head-safe 只重裁 v2，不回头动 v1'''
assert s.count(ANCHOR2) == 1, "锚点② 命中 %d 次" % s.count(ANCHOR2)
s = s.replace(ANCHOR2, NEW2)

ANCHOR3 = '''        if ver == "v1":
            # v1 才落 _pending（纪律 J：成品只落暂存区，等店长定版再 approve）
            dst = os.path.join(PEND, "%d.png" % cid)
            print("cut %s(v1) -> _pending/%d.png %s" % (name, cid, cut(raw, dst)))
        else:
            # v2 只出对照图，不动 _pending
            dst = os.path.join(D, "_R760_448x404_v2_%d.png" % cid)
            print("cut %s(v2) -> %s %s" % (name, os.path.basename(dst), cut(raw, dst)))'''
NEW3 = '''        if head_safe:
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
            print("cut %s(v2) -> %s %s" % (name, os.path.basename(dst), cut(raw, dst)))'''
assert s.count(ANCHOR3) == 1, "锚点③ 命中 %d 次" % s.count(ANCHOR3)
s = s.replace(ANCHOR3, NEW3)

ANCHOR4 = '''    if items:
        sheet(items, "_R760_卡面验收%s.png" % ("" if ver == "v1" else "_v2"))'''
NEW4 = '''    if items:
        tag = "_定稿_保头" if head_safe else ("" if ver == "v1" else "_v2")
        sheet(items, "_R760_卡面验收%s.png" % tag)'''
assert s.count(ANCHOR4) == 1, "锚点④ 命中 %d 次" % s.count(ANCHOR4)
s = s.replace(ANCHOR4, NEW4)

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("patched _finish.py, %d bytes" % len(s))
