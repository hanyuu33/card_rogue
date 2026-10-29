# -*- coding: utf-8 -*-
"""R438 卡图批次：raw → assets/pics/<id>.png

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
NO_WM_CUT = set()      # 本批无水印需手工修补的图

# 采用稿（被弃的版本不在这里，留在 raw/ 存档）
ADOPT = {
    "9026": "9026_陶瓷鸭_v1_候选.png",          # 青釉冰裂瓷鸭，裂纹漏橙光
    "8007": "8007_影魔_v1_候选.png",            # 四臂黑影 + 三块紫色卡形光片
    "8009": "8009_潜影者_v1_候选.png",          # 贴地墨影 + 紫边轮廓 + 反手短刃
    "8024": "8024_契约签订者_v1_候选.png",      # 兜帽掮客 + 空白长卷轴 + 费用光点
    "8015": "8015_机关工坊_v1_候选.png",        # 工坊场景，画面无人物
    "8050": "8050_旧式机兵_v1_候选.png",        # 锈甲掉板 + 暗红炉栅 + 膝部接线
    "8060": "8060_代达罗斯_v1_候选.png",        # 双塔盾交叠 + 肩炮 + 青核（8074 量产型复用）
    "8072": "8072_谟涅摩叙涅_v1_候选.png",      # 半张无面罩板 + 齿轮光环（8075 量产型复用）
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
