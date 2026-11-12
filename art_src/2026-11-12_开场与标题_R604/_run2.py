# -*- coding: utf-8 -*-
"""R604 第二张：厂牌徽记。

纯黑底 + 金线稿，回到本地后按亮度取 alpha 抠成透明 PNG
（tools/_compose_r604_art.py --mark 负责），这样片头卡与启动 splash 共用同一张。
"""
import importlib.util
import os

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-12_开场与标题_R604")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

JOBS = [
    (9002, "厂牌徽记", None, "_v1"),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    done, fail = [], []
    for cid, name, ref, suffix in JOBS:
        (done if m.run_one(cid, name, ref, suffix) else fail).append(cid)
    m.log("=== R604 徽记 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
