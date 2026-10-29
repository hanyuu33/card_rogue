# -*- coding: utf-8 -*-
"""R412 卡图批次：raw → assets/pics/<id>.png

流程（与 ART.md「出图链」一致）：
  ① 切底部 11%（去右下角「AI生成」水印）
  ② 按 448×403（1.1117）cover 裁切（居中，只裁多出来的那一边）
  ③ LANCZOS 缩到 448×403、RGB 存 png

⚠️ 只在用户点头后才跑（ART.md「每张图出完必须给用户过目，他点头才入库」）。

用法：python process.py            # 全跑
      python process.py 9022 9080  # 只跑指定 id
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
OUT = os.path.join(HERE, "..", "..", "assets", "pics")

W, H = 448, 403
RATIO = W / H
WATERMARK_CUT = 0.11   # 底部按比例切掉
NO_WM_CUT = set()      # 本批暂无手工处理过边的图

# 采用稿（被弃的版本不在这里，留在 raw/ 存档）
ADOPT = {
    "9022": "9022_鸭蛋_v1_候选.png",
    "9080": "9080_魔像_v2_仰视动势.png",          # v1 构图平、显矮呆板（用户否）
    "8018": "8018_活体栅栏_v2_非树干.png",        # v1 底部木桩读成树干（用户否）
    "8025": "8025_素体_v3_不切脚强化半成品.png",  # v1 太 Q 版（否）→ v2 比例对但切脚 → v3 采纳（12:28 用户指定）；v4 脚完整但头反弹成 4.5 头身，弃
    "9009": "9009_使魔鸭子_v1_候选.png",           # 白鸭 + 青色召唤阵，对齐 9017
    "9027": "9027_夜鸭_v1_候选.png",               # 冷蓝月光蹲伏，无紫无暖光
    "9161": "9161_失控要塞_v1_候选.png",           # 四管各朝一方，冷灰钢 + 青色能量，对齐 8042
    "1031": "1031_冰冻术士_v5_满幅硬边.png",       # v1~v2 写实（否）→ v3 退成剪影+白边 → v4 风格对但白边 200px → v5 采纳
    "9177": "9177_宠物鸭_v1_候选.png",             # 破壳小鸭、张翅挡前，与 9022 鸭蛋成对
    "8010": "8010_荧光草_v2_洞窟.png",             # v1 背景是遗迹石板砖（否）→ v2 天然洞窟
    "8059": "8059_机器鸟_v2_完好.png",             # v1 故意做破旧（否，时序错：改造是玩家后续操作）→ v2 全新组装
    "8023": "8023_黑暗祭坛_v1_候选.png",           # 黑玄武岩 + 紫色光刃，对齐 8005 黑紫基调
    "9069": "9069_鸭窝_v1_候选.png",               # 三枚白蛋 + 白绒内衬，与 9022/9177 成链
    "9079": "9079_魔像术_v2_非人体块状.png",      # R415：v1 块状太像人体（否）→ v2 泥岩堆叠
    "8076": "8076_改装者_v1_候选.png",            # R415：齿轮工匠，与 8059 同色系
    "1014": "1014_幼龙_v2_幼体比例.png",          # 10-29 补入：v1 头身比偏大（弃）→ v2 幼体比例
    "1061": "1061_爆裂机甲_v1_候选.png",          # 10-29 补入
    "8021": "8021_黑暗领主_v1_候选.png",          # 10-29 补入：黑影 + 血阵，与 8023 黑紫基调一致
}


def cover(im: Image.Image, ratio: float) -> Image.Image:
    w, h = im.size
    if w / h > ratio:                       # 太宽 → 裁宽
        nw = int(round(h * ratio))
        x = (w - nw) // 2
        return im.crop((x, 0, x + nw, h))
    nh = int(round(w / ratio))              # 太高 → 裁高（上下各半）
    y = (h - nh) // 2
    return im.crop((0, y, w, y + nh))


def main() -> None:
    want = [a for a in sys.argv[1:] if a.strip()]
    todo = {k: v for k, v in ADOPT.items() if (not want or k in want)}
    missing = [k for k in want if k not in ADOPT]
    if missing:
        raise SystemExit("ADOPT 里没有这些 id: %s" % ", ".join(missing))
    if not todo:
        raise SystemExit("没有要处理的 id")
    os.makedirs(OUT, exist_ok=True)
    for cid, name in sorted(todo.items()):
        src = os.path.join(RAW, name)
        im = Image.open(src).convert("RGB")
        w, h = im.size
        cut = 0 if cid in NO_WM_CUT else int(round(h * WATERMARK_CUT))
        im = im.crop((0, 0, w, h - cut))    # ① 去水印
        im = cover(im, RATIO)               # ② cover
        im = im.resize((W, H), Image.LANCZOS)   # ③ 定稿尺寸
        dst = os.path.join(OUT, cid + ".png")
        im.save(dst, "PNG", optimize=True)
        print("%s  %s -> %s (%dx%d)" % (cid, name, dst, im.size[0], im.size[1]))


if __name__ == "__main__":
    main()
