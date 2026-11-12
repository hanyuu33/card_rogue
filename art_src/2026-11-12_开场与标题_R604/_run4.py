# -*- coding: utf-8 -*-
"""R604 第四批：只补标题主视觉 9001。

_run3 在 11:07:40 起了 9001，随后驱动进程消失（raw/ 里只有 9002），
本文件只跑这一张，不动已完成的徽记。
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

REF_STYLE = os.path.join(ROOT, "assets", "ui", "title_bg.png")   # 画风锚（只借上色与光影）

JOBS = [
    (9001, "标题主视觉", REF_STYLE, "_v1"),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    done, fail = [], []
    for cid, name, ref, suffix in JOBS:
        (done if m.run_one(cid, name, ref, suffix) else fail).append(cid)
    m.log("=== R604 第四批 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
