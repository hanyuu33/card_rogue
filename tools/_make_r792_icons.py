# -*- coding: utf-8 -*-
"""R792 道具图标：板甲 / 兵 / 墙砖。

⚠️ `_make_r755_icons` 的构建代码写在**模块顶层**（没有 main 保护），import 就会
   顺带重跑它那两张旧图。这里在 import 前后对 md5，变了就 git checkout 还原 ——
   宁可多一步也不让别人的图被我的补丁顺手改掉。
"""
import hashlib
import io
import os
import subprocess
import sys

ROOT = 'E:/work/card_rogue/'
WATCH = ['assets/ui/trap_icon_7012.png', 'assets/ui/ui_tool_swap.png']


def md5(p):
    return hashlib.md5(open(ROOT + p, 'rb').read()).hexdigest()


before = {p: md5(p) for p in WATCH}

sys.path.insert(0, ROOT + 'tools')
import _make_r755_icons as R755   # noqa: E402

for p in WATCH:
    if md5(p) != before[p]:
        subprocess.run(['git', 'checkout', '--', p], cwd=ROOT, check=True)
        print('restored', p)

from PIL import Image, ImageDraw   # noqa: E402


def clean_watermark(path, out_tmp):
    """右下角水印涂白（生成图自带），主体不在这块。"""
    im = Image.open(path).convert('RGB')
    w, h = im.size
    d = ImageDraw.Draw(im)
    d.rectangle([int(w * 0.86), int(h * 0.93), w, h], fill=(255, 255, 255))
    im.save(out_tmp)
    return out_tmp


JOBS = [
    ('_art_wip_r792/A_cute_hand_drawn_cartoon_game_2026-11-18T06-45-04.png', '_clean_6070.png', 'assets/ui/relic_icon_6070.png'),
    ('_art_wip_r792/A_cute_hand_drawn_cartoon_game_2026-11-18T06-46-34.png', '_clean_6071.png', 'assets/ui/relic_icon_6071.png'),
    ('_art_wip_r792/A_cute_hand_drawn_cartoon_game_2026-11-18T06-46-46.png', '_clean_6072.png', 'assets/ui/relic_icon_6072.png'),
]

for src, tmp, out in JOBS:
    clean_watermark(ROOT + src, ROOT + '_art_wip_r792/' + tmp)
    R755.cut(ROOT + '_art_wip_r792/' + tmp, out, pad_pct=0.07)
