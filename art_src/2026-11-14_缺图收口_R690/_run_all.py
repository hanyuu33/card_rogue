# -*- coding: utf-8 -*-
"""R690 驱动：复用 R562 的 codex 图生图管线（代理 / stdin / 取图 / 重试），
只换批次目录、参考图和 JOBS。循环关在脚本里，一次调用跑完 2 张。

⚠️ 前置：代理必须可连（R562 注释：必须显式指定 http://127.0.0.1:7897，
   环境自带的 63248 沙箱代理连不上 chatgpt.com）。代理没开时 codex 报
   "workspace routing discovery failed"，本脚本两张都会 FAIL，不会留半成品。
"""
import importlib.util
import os
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-14_缺图收口_R690")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW                      # run_one / log 都读模块全局，改这里即可

P = os.path.join(ROOT, "assets", "pics")
REFS = {
    "treant":      os.path.join(P, "8003.png"),                    # 森林精魄物件/暖棕+叶绿
    "char_forest": os.path.join(ROOT, "assets", "ui", "class_cg_forest.png"),
    "goose":       os.path.join(P, "9187.png"),                    # 森林精魄鸟类盟友（鹅）
}

# (id, prompt 里的卡名, 参考桶)
JOBS = [
    (9248, "种子", "treant"),
    (9249, "被眷顾者", "char_forest"),
    (9250, "鸭妈妈", "goose"),
    (9251, "小鸭", "goose"),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, bucket in JOBS:
        if only and cid not in only:
            continue
        ok = m.run_one(cid, name, REFS[bucket], "_v1")
        (done if ok else fail).append(cid)
    m.log("=== R690 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))


if __name__ == "__main__":
    main()
