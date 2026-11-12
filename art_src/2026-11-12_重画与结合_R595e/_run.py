# -*- coding: utf-8 -*-
"""R595e 重画与结合：两张。

9192 援护炮击 —— 上一版是「炮弹安静地立在坑中央 + 一圈均匀青色细环」，读起来像摆件和
魔法阵，没有炮击的动能。重画为命中瞬间：弹体斜插、后半截与尾翼仍露在外、甲板沿裂纹翻起。
9193 技术结合 —— 店长给的思路：把构装体核心放进构装体。造型不许自己臆造，
参考图锁定 8026「构装体」（黄铜装甲 + 深灰关节 + 铆钉 + 圆肩 + 尖顶方头 + 胸口圆形核心）。

管线复用 R562（代理 7897 / stdin 喂 prompt / 取 generated_images / 重试 2 次）。
"""
import importlib.util
import os
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-12_重画与结合_R595e")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

REF_MECH = os.path.join(ROOT, "assets", "pics", "8025.png")   # 画风锚
REF_CONSTRUCT = os.path.join(ROOT, "assets", "pics", "8026.png")  # 造型锚：构装体本体

JOBS = [
    (9192, "援护炮击", REF_MECH, "_v2"),
    (9193, "技术结合", REF_CONSTRUCT, "_v2"),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, ref, suffix in JOBS:
        if only and cid not in only:
            continue
        (done if m.run_one(cid, name, ref, suffix) else fail).append(cid)
    m.log("=== R595e 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
