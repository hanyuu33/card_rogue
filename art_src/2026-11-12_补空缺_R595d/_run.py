# -*- coding: utf-8 -*-
"""R595d 补空缺：只跑真正一张图都没有的两张卡。

9158 罐子（工事）不在任务表 —— `art_plan.json` 的 skip 里写着「永久不出图」，
店长 2026-11-11 已确认那是弃用的旧召唤物机制。

管线复用 R562（代理 7897 / stdin 喂 prompt / 取 generated_images / 重试 2 次）。
"""
import importlib.util
import os
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-12_补空缺_R595d")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

# 机械之心体系一律以 8025 作画风锚（深蓝灰装甲 + 青色能量缝），
# 只借材质与上色手法，不借人形本体 —— prompt 里已写死排除 robot body。
REF_MECH = os.path.join(ROOT, "assets", "pics", "8025.png")

JOBS = [
    (9192, "援护炮击", REF_MECH),
    (9193, "技术结合", REF_MECH),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, ref in JOBS:
        if only and cid not in only:
            continue
        (done if m.run_one(cid, name, ref) else fail).append(cid)
    m.log("=== R595d 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
