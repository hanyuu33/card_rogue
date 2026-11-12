# -*- coding: utf-8 -*-
"""R606 标题字活泼版：把鸭子缝进字里的两个方案。

两版都走 9001 同一套画风锚（assets/ui/title_bg.png），只换字的画法：
  9011 鸭嘴版 —— 两个「嘎」的口字旁改成小鸭头，「杀」的捺收成脚蹼；
  9012 木牌版 —— 四个字刻在四块木牌上，鸭子坐在牌子与横梁上。
两版各自独立，跑完一张就能单独看，不必等整批。
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
    (9011, "标题字鸭嘴版", REF_STYLE, "_v1"),
    (9012, "标题字木牌版", REF_STYLE, "_v1"),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    done, fail = [], []
    for cid, name, ref, suffix in JOBS:
        (done if m.run_one(cid, name, ref, suffix) else fail).append(cid)
    m.log("=== R606 标题字 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
