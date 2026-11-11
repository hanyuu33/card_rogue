# -*- coding: utf-8 -*-
"""R577f：为 60 张道具图标预生成「蓝色边缘光」叠加图。

与 tools/make_r577f_preview.py::rim_layers 同一算法：
  alpha 膨胀差分 → 内圈 r1（贴轮廓，冷蓝）/ 外圈 r2（极淡外晕）。
差异只在尺度：预览跑 44x44（MaxFilter 5），这里跑 128x128（MaxFilter 9），
按 128/44 比例放大膨胀半径；输出与源图同尺寸，绘制时用同一个 rect，零几何变化。

产物：assets/ui/relic_rim_<id>.png（6001~6060，128x128 RGBA，除光边外全透明）。
信物 6061~6063 不参与高亮判定，不生成 rim，取图口返回 null。
可重跑；不覆盖已有文件（要重出请加 --force）。
"""
import os
import sys
from PIL import Image, ImageFilter, ImageChops

ROOT = r'E:/work/card_rogue'
ICON_DIR = os.path.join(ROOT, 'assets', 'ui')
IDS = list(range(6001, 6061))

BLUE_RIM = (86, 178, 255)      # 预览 BLUE_RIM，贴图标轮廓的冷蓝
BLUE_HALO = (56, 138, 240)     # 预览 BLUE_HALO，外扩一圈极淡晕
RIM_STRENGTH = 0.88
HALO_STRENGTH = 0.24
DILATE = 9                     # MaxFilter(9) → 半径 4px，两圈共 8px（44 格上约 2.75px）


def make_rim(src_path, dst_path):
    src = Image.open(src_path).convert('RGBA')
    a = src.getchannel('A')
    d1 = a.filter(ImageFilter.MaxFilter(DILATE))
    r1 = ImageChops.subtract(d1, a)
    d2 = d1.filter(ImageFilter.MaxFilter(DILATE))
    r2 = ImageChops.subtract(d2, d1)

    halo = Image.new('RGBA', src.size, BLUE_HALO + (0,))
    halo.putalpha(r2.point(lambda v: int(v * HALO_STRENGTH)))
    rim = Image.new('RGBA', src.size, BLUE_RIM + (0,))
    rim.putalpha(r1.point(lambda v: int(v * RIM_STRENGTH)))
    halo.alpha_composite(rim)
    halo.save(dst_path, optimize=True)
    return halo.getchannel('A').getbbox() is not None, halo.size


def main():
    force = '--force' in sys.argv
    made = skipped = empty = 0
    for rid in IDS:
        src = os.path.join(ICON_DIR, 'relic_icon_%d.png' % rid)
        dst = os.path.join(ICON_DIR, 'relic_rim_%d.png' % rid)
        if not os.path.isfile(src):
            print('MISSING SOURCE', rid)
            empty += 1
            continue
        if os.path.isfile(dst) and not force:
            skipped += 1
            continue
        ok, size = make_rim(src, dst)
        assert size == (128, 128), '%d 尺寸不对 %s' % (rid, size)
        if not ok:
            print('EMPTY RIM', rid)
            empty += 1
        made += 1
    print('RIMS made=%d skipped=%d empty=%d total=%d' % (made, skipped, empty, len(IDS)))
    return 0 if empty == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
