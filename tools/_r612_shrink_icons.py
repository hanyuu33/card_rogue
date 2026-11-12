# -*- coding: utf-8 -*-
"""R612：只缩「实机绘制尺寸远小于源图」的图标类素材（影响最小的一批）。

## 为什么只动这几类

R611 实测：给 UI/背景开 ASTC 全量压缩会让包**变大** 20MB（PNG 平涂+透明本来就更省），
真正的空间在**分辨率**——地图图标源图 1254²，实机 `ZONE_ICON = 62`；职业头像源图
1020²，`UiAssets.class_avatar()` 内部直接 `small_icon(..., 160)` 缩到 160 再用。
多出来的像素从来没被任何人看见过，砍掉它是零观感代价。

## 上限怎么定的（一律留 ≥2 倍余量，应对高 DPI / canvas_items 缩放）

| 组 | 实机最大绘制 | 上限 | 余量 | 依据 |
|---|---|---|---|---|
| `ui/map_icons/*`        | 62（商店图标位 120） | 256 | 2.1× | `battle_scene.ZONE_ICON`、`shop_scene._goods_icon_box` |
| `ui/reward_icons/core`  | 200 | 512 | 2.5× | `event_scene.CORE_ICON_SIZE` |
| `ui/reward_icons/*`     | 96（small_icon 64） | 256 | 2.7× | `reward_panel` 的 96×96 图标框 |
| `ui/class_avatar_*`     | 160 | 320 | 2.0× | `UiAssets.class_avatar()` 内置 resize |
| `ui/adventure_shared/close_forest` | 64 | 256 | 4.0× | `small_icon(..., 64)` |

**明确不动的**：背景 `bg_*`、`map_bg_*`、`battle_bg_*`、`title_art/bg`、九宫格
`panel_parchment` / `scroll_parchment`（平铺底，缩了花纹重复感变强）、事件竖版
`side_*`（实机 742×720 正好等于源图）、`relic_*` / `affix_*`（本来就 128²）。

## 图源保留

改写前把原 PNG 逐张复制到 `art_src/_originals_r612/`（入库），保留 `assets/`
之后的相对路径。checkout 后随时能拿回压缩前的原件。

用法：
    python tools/_r612_shrink_icons.py --dry     # 只列计划
    python tools/_r612_shrink_icons.py           # 执行
"""
import glob
import io
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUP = os.path.join(ROOT, "art_src", "_originals_r612")

# (glob 模式, 上限边长, 理由)
RULES = [
    ("assets/ui/map_icons/*.png", 256, "地图图标 实机 62 / 商店位 120"),
    ("assets/ui/reward_icons/*.png", 256, "奖励图标 实机 96、small_icon 64"),
    ("assets/ui/class_avatar_*.png", 320, "职业头像 代码已 resize 到 160"),
    ("assets/ui/adventure_shared/close_forest.png", 256, "关闭按钮 实机 64"),
]

# 单张覆写：事件页核心标志实机画 200px，给它留更大余量
OVERRIDE = {"assets/ui/reward_icons/core.png": 512}


def build_plan():
    plan = []
    seen = set()
    for pat, cap, why in RULES:
        for f in sorted(glob.glob(os.path.join(ROOT, pat))):
            rel = os.path.relpath(f, ROOT).replace("\\", "/")
            if rel in seen:
                continue
            seen.add(rel)
            im = Image.open(f)
            w, h = im.size
            cap2 = OVERRIDE.get(rel, cap)
            if max(w, h) <= cap2:
                continue
            ratio = cap2 / float(max(w, h))
            plan.append({
                "src": rel,
                "size": (w, h),
                "cap": cap2,
                "dst_size": (max(1, round(w * ratio)), max(1, round(h * ratio))),
                "bytes": os.path.getsize(f),
                "why": why,
            })
    return plan


def backup(src_rel):
    dst = os.path.join(BACKUP, src_rel.replace("assets/", "", 1))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if not os.path.exists(dst):
        shutil.copy2(os.path.join(ROOT, src_rel), dst)
    return dst


def run(dry):
    plan = build_plan()
    if not plan:
        print("没有需要处理的图。")
        return 0
    print("%-46s %11s %8s %11s %8s" % ("文件", "源尺寸", "源MB", "目标", "预计MB"))
    before = after = 0
    for it in plan:
        im = Image.open(os.path.join(ROOT, it["src"])).convert("RGBA")
        im2 = im.resize(it["dst_size"], Image.LANCZOS)
        bio = io.BytesIO()
        im2.save(bio, "PNG", optimize=True)
        nb = bio.tell()
        before += it["bytes"]
        after += nb
        print("%-46s %5dx%-5d %7.2f %5dx%-5d %8.2f" % (
            os.path.basename(it["src"]), it["size"][0], it["size"][1],
            it["bytes"] / 1048576.0, it["dst_size"][0], it["dst_size"][1],
            nb / 1048576.0))
        if dry:
            continue
        bk = backup(it["src"])
        with open(os.path.join(ROOT, it["src"]), "wb") as f:
            f.write(bio.getvalue())
        it["backup"] = os.path.relpath(bk, ROOT).replace("\\", "/")
    print()
    print("%s %d 张，源 PNG %.2f MB → %.2f MB（省 %.2f MB）" % (
        "[DRY]" if dry else "[DONE]", len(plan),
        before / 1048576.0, after / 1048576.0, (before - after) / 1048576.0))
    if not dry:
        print("原图备份：%s" % os.path.relpath(BACKUP, ROOT).replace("\\", "/"))
    return 0


if __name__ == "__main__":
    sys.exit(run("--dry" in sys.argv))
