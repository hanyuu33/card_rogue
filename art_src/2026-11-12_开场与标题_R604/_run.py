# -*- coding: utf-8 -*-
"""R604 开场与标题：主界面关键视觉一张。

为什么只要一张：主界面标题不能是纯文字，需要一张带纹章横幅的 key art，
标题字事后再用衬线体叠上去（AI 写中文名必糊，字必须我们自己排）。

管线复用 R562（代理 7897 / stdin 喂 prompt / 取 generated_images / 重试 2 次）。
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
    m.log("=== R604 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
