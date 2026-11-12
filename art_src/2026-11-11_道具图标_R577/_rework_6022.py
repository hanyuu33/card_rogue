# -*- coding: utf-8 -*-
"""6022 荒野形态图标返工：灰狼皮兜帽 → 银金色毛的山猫头像。

店长 2026-11-11 16:01：「修改荒野形态的图标：改成一个银金色毛的山猫头像」

复用 R577b 契约：纯白底 codex 文生图 → 边缘 flood-fill 去背 → 128x128 RGBA；
`assets/ui/relic_rim_6022.png` 是按图标 alpha 轮廓预生成的蓝色边缘光，
头像一换必须按新图重算，否则光环还是旧兜帽形状。

用法（三段，出图委托 codex 在中间）：
    python _rework_6022.py prepare   # 备份旧图 / 旧 prompt / 旧索引，移走旧 raw
    python tools/_gen_prompts.py 6022  # 生成新 prompt + 刷 ICON_INDEX.md
    python _run_codex.py 6022          # 后台委托 codex
    python _rework_6022.py finish      # 去背 + 自适应容差 + 前后对比页
    python _rework_6022.py land        # 落地 icon + rim，带像素级断言

可重复执行；所有旧文件留在 rework_6022/，不删不覆盖。
"""
import importlib.util
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(r"E:\work\card_rogue")
D = ROOT / "art_src" / "2026-11-11_道具图标_R577"
RAW = D / "raw"
PROC = D / "processed"
PROMPTS = D / "prompts"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"
REWORK = D / "rework_6022"          # 旧版留档 + 容差候选 + 对比页

ICON = UI / "relic_icon_6022.png"
RIM = UI / "relic_rim_6022.png"
OLD_ICON = REWORK / "relic_icon_6022_v1.png"
NEW_RAW = RAW / "6022_codex.png"
NEW_PROC = PROC / "relic_icon_6022.png"
OUT_CMP = REVIEW / "6022_compare.png"
FONT = "C:/Windows/Fonts/msyh.ttc"

# 载入 R577b 的后期算法与 rim 算法（两个模块都有 __main__ 保护，import 不跑全量）
def _load(name, path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


FIN = _load("r577_finish", D / "tools" / "_finish.py")
RIMMOD = _load("r577_rims", ROOT / "tools" / "_make_r577f_rims.py")


def center_opacity(path):
    """中心 40x40 的不透明率：用来抓『浅色毛被 flood-fill 吃穿』（6018 白蛋坑）。"""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    box = ((w - 40) // 2, (h - 40) // 2, (w + 40) // 2, (h + 40) // 2)
    a = im.crop(box).getchannel("A")
    return sum(1 for v in a.getdata() if v > 128) / float(40 * 40)


def checker(size, cell=16):
    im = Image.new("RGB", (size, size), (220, 216, 208))
    d = ImageDraw.Draw(im)
    for y in range(0, size, cell):
        for x in range(0, size, cell):
            if (x // cell + y // cell) % 2:
                d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(196, 192, 184))
    return im


def prepare():
    REWORK.mkdir(parents=True, exist_ok=True)
    pairs = [
        (ICON, "relic_icon_6022_v1.png"),
        (RIM, "relic_rim_6022_v1.png"),
        (NEW_PROC, "processed_relic_icon_6022_v1.png"),
        (PROMPTS / "6022.txt", "prompt_6022_v1.txt"),
        (D / "ICON_INDEX.md", "ICON_INDEX_before.md"),
    ]
    for src, name in pairs:
        assert src.exists(), "待备份文件缺失: %s" % src
        dst = REWORK / name
        if not dst.exists():
            shutil.copy2(src, dst)
        assert dst.stat().st_size > 0, dst
        print("  backup:", name, dst.stat().st_size, "B")
    # raw 用 move（不是删除）：_run_codex.py 见到已有 raw 会 SKIP
    assert NEW_RAW.exists(), "旧 raw 缺失"
    dst = REWORK / "raw_6022_codex_v1.png"
    if not dst.exists():
        shutil.move(str(NEW_RAW), str(dst))
    elif NEW_RAW.exists():
        os.remove(NEW_RAW)
    assert not NEW_RAW.exists(), "旧 raw 仍在，出图会被 SKIP"
    print("[prepare] 旧版留档完成，raw/ 已腾空，可以委托 codex")


def finish():
    assert NEW_RAW.exists() and NEW_RAW.stat().st_size > 50000, "新 raw 还没出图"
    assert OLD_ICON.exists(), "缺旧版备份（先跑 prepare）"
    REWORK.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)

    # 容差自适应：默认 38 优先；浅银毛若被吃穿就收紧到 20 / 10
    best = fallback = None
    for tol in (38, 20, 10):
        cand = REWORK / ("candidate_tol%d.png" % tol)
        ok, cov, note = FIN.cutout(NEW_RAW, cand, tol)
        c = center_opacity(cand) if ok else 0.0
        print("  tol=%-2d ok=%s coverage=%.1f%% center=%.1f%% %s" %
              (tol, ok, cov * 100, c * 100, note))
        if not ok:
            continue
        if fallback is None or c > fallback[3]:
            fallback = (tol, cand, cov, c)
        if c >= 0.90:                 # 默认容差够用就停，别为了抠更狠留白边
            best = (tol, cand, cov, c)
            break
    if best is None:
        best = fallback
    assert best is not None, "三种容差都去背失败"
    tol, cand, cov, c = best
    shutil.copyfile(cand, NEW_PROC)
    assert Image.open(NEW_PROC).size == (128, 128) and Image.open(NEW_PROC).mode == "RGBA"
    print("[finish] 采用 tol=%d，center=%.1f%%，coverage=%.1f%%" % (tol, c * 100, cov * 100))

    # ---- 四格对比页 -------------------------------------------------------
    S, pad, lb = 256, 12, 30
    im = Image.new("RGB", (4 * S + 5 * pad, S + lb + 2 * pad + 34), (24, 26, 32))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 16)
    ft = ImageFont.truetype(FONT, 20)
    d.text((pad, 8), "6022 荒野形态 · 灰狼皮兜帽 → 银金色毛山猫头像", fill=(240, 226, 190), font=ft)

    new = Image.open(NEW_PROC).convert("RGBA")
    old = Image.open(OLD_ICON).convert("RGBA")
    raw_im = Image.open(NEW_RAW).convert("RGB")
    # 四格：旧图 / 新 raw / 新透明成品 / 44x44 实机尺寸放大
    for i, label in enumerate(("旧版 v1 · 灰狼皮兜帽", "新 raw · 纯白底出图",
                               "新成品 · 128×128 透明", "实机尺寸 · 44×44 放大")):
        x = pad + i * (S + pad)
        y = 42 + pad
        if i == 0:
            tile = checker(S).convert("RGBA")
            tile.alpha_composite(old.resize((S, S), Image.LANCZOS))
        elif i == 1:
            tile = raw_im.resize((S, S), Image.LANCZOS).convert("RGBA")
        elif i == 2:
            tile = checker(S).convert("RGBA")
            tile.alpha_composite(new.resize((S, S), Image.LANCZOS))
        else:
            small = new.resize((44, 44), Image.LANCZOS).resize((S, S), Image.NEAREST)
            tile = checker(S).convert("RGBA")
            tile.alpha_composite(small)
        im.paste(tile.convert("RGB"), (x, y))
        d.text((x + 4, y + S + 4), label, fill=(232, 232, 238), font=f)
        d.rectangle((x, y, x + S - 1, y + S - 1), outline=(90, 92, 100), width=1)
    im.save(OUT_CMP)
    print("[finish] 对比页:", OUT_CMP, im.size)


def land():
    assert NEW_PROC.exists() and Image.open(NEW_PROC).size == (128, 128)
    assert OLD_ICON.exists(), "缺旧版备份"
    old_rim = Image.open(REWORK / "relic_rim_6022_v1.png").convert("RGBA")
    shutil.copyfile(NEW_PROC, ICON)
    assert Image.open(ICON).size == (128, 128) and Image.open(ICON).mode == "RGBA"

    ok, size = RIMMOD.make_rim(str(ICON), str(RIM))
    assert ok and size == (128, 128), "rim 生成失败 %s %s" % (ok, size)
    new_rim = Image.open(RIM).convert("RGBA")
    assert new_rim.getchannel("A").getbbox() is not None, "rim 全透明"
    diff = ImageChops.difference(old_rim, new_rim).getbbox()
    assert diff is not None, "rim 没跟着头像变化（还是旧兜帽轮廓）"
    assert ImageChops.difference(Image.open(OLD_ICON).convert("RGBA"),
                                 Image.open(ICON).convert("RGBA")).getbbox() is not None, \
        "icon 没变"
    print("[land] icon + rim 已落地；rim 随新轮廓重算（diff bbox=%s）" % (diff,))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    {"prepare": prepare, "finish": finish, "land": land}.get(
        cmd, lambda: (_ for _ in ()).throw(SystemExit("用法: prepare | finish | land")))()
