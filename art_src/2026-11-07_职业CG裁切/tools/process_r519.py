# -*- coding: utf-8 -*-
"""R519 暗影刺客 CG 重新裁切：顶部不再切掉头部。

背景
----
`assets/ui/class_cg_rogue.png` 是从
`art_src/cg_retouch/A_highly_detailed_anime_style_2026-11-05T16-11-30.png`（1536×1024）
里裁 y=80..944 得到的 —— 上边少给了 80px，兜帽顶部被削平。
后来「只改表情」的那次编辑（`CHANGE_ONLY_her_facial_express_2026-11-06T02-20-16.png`）
模型直接返回了 1280×720，被切的头部就这样定格进了成品。

做法
----
1. 清掉原图左上角那三枚 HUD 图标（x 0..215 / y 0..72）—— 从正下方取样、上下翻转贴回再羽化；
2. 裁 `(0, 0, 1536, 864)` → 1280×720：**上边从 0 起**，兜帽顶部完整；
3. 把现用图里那小块「笑嘴」羽化贴回（同一张画，只是表情不同；实测整体对齐偏移 dy=66、dx=0）。

用法
----
    python tools/process_r519.py            # 干跑：只打印指标并写到 _review
    python tools/process_r519.py --write    # 落盘到 assets/ui/class_cg_rogue.png（先备份 .bak_r519）
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'art_src', 'cg_retouch',
                   'A_highly_detailed_anime_style__2026-11-05T16-11-30.png')
CUR = os.path.join(ROOT, 'assets', 'ui', 'class_cg_rogue.png')
DST = CUR
REVIEW = os.path.join(ROOT, 'art_src', '2026-11-07_职业CG裁切', '_review')

# 左上角 HUD 覆盖区（原图坐标）：那一块是**参考截图带进来的三枚图标 + 细边框**。
# 上一版为了躲它直接从 y=80 起裁，结果把兜帽顶部一起削平了 —— 现在改成「盖掉它」。
HUD_BOX = (0, 0, 400, 96)
DELINE = (5, 11)        # 那条从 HUD 带上来的「顶边亮线」：整幅宽度上抹掉
HUD_SRC_DY = 92         # 从正下方取同样高的暗天空，上下翻转贴回

# 表情补丁：现用图坐标 → 新图坐标要 +CROP_DY
CROP_DY = 66            # 现用图 y = 新图 y - 66（实测最佳对齐）
MOUTH_BOX = (828, 180, 952, 244)   # 现用图坐标，罩住嘴与下巴左上的笑纹
FEATHER = 14


def remove_top_line(src: Image.Image) -> None:
    """把 y=5..11 那条贯穿整幅的细亮线抹掉：按上下两侧线性插值。

    HUD 那条顶边线是从左上角一路拖到画面右侧的（截图上带进来的），
    只补左上角会留下一条横贯的细线 —— 单独按列插值最干净，月面本来也是平滑渐变。
    """
    y0, y1 = DELINE
    w, h = src.size
    px = src.load()
    for x in range(w):
        a = px[x, y0 - 2]
        b = px[x, y1 + 2]
        n = y1 - y0 + 1
        for i in range(n):
            t = (i + 1) / float(n + 1)
            px[x, y0 + i] = (
                int(a[0] + (b[0] - a[0]) * t),
                int(a[1] + (b[1] - a[1]) * t),
                int(a[2] + (b[2] - a[2]) * t))


def clean_hud(src: Image.Image) -> None:
    """把左上角那块 HUD（三枚图标 + 边框）**原地重度模糊**掉。

    试过三种更"聪明"的做法，都不如这一条：
      · 直接裁掉 —— 上一版就是这么做，兜帽顶部跟着没了；
      · 从下方取样贴回 —— 会把塔尖/云边一起搬上来，接缝处出现横线；
      · 按列色带重建 —— 月光那块被抹平，和真实月面之间留下竖直硬边。
    原地模糊的优点：颜色、月光走势、明暗全是原图自己的，只有结构被化开；
    这块本来就是深色夜空 + 月光，糊开之后读起来就是一片夜雾，看不出补的。
    """
    x0, y0, x1, y1 = HUD_BOX
    w, h = x1 - x0, y1 - y0
    soft = src.crop(HUD_BOX).filter(ImageFilter.GaussianBlur(40)).filter(
        ImageFilter.GaussianBlur(20))
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rectangle((0, 0, w - 1, h - 1), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(24))
    src.paste(soft, (x0, y0), mask)


def paste_mouth(dst: Image.Image, cur: Image.Image) -> None:
    """把现用图的「笑嘴」小块羽化贴到新图上。"""
    x0, y0, x1, y1 = MOUTH_BOX
    patch = cur.crop((x0, y0, x1, y1))
    w, h = patch.size
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(FEATHER))
    dst.paste(patch, (x0, y0 + CROP_DY), mask)


def main() -> None:
    write = '--write' in sys.argv
    src = Image.open(SRC).convert('RGB')
    cur = Image.open(CUR).convert('RGB')
    print('source', SRC, src.size)
    print('current', CUR, cur.size)

    work = src.copy()
    remove_top_line(work)
    clean_hud(work)
    out = work.crop((0, 0, 1536, 864)).resize((1280, 720), Image.LANCZOS)
    paste_mouth(out, cur)

    os.makedirs(REVIEW, exist_ok=True)
    preview = os.path.join(REVIEW, 'r519_rogue_new.png')
    out.save(preview)
    print('dry-run ->', preview)
    if write:
        bak = DST + '.bak_r519'
        if not os.path.exists(bak):
            shutil.copy2(DST, bak)
            print('backup ->', bak)
        out.save(DST)
        print('written ->', DST)


if __name__ == '__main__':
    main()
