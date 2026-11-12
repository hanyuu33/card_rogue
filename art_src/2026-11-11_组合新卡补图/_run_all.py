# -*- coding: utf-8 -*-
"""组合新卡 4 张的后台驱动：复用 R562 的 codex 图生图管线。

循环关在脚本内部，一次调用跑完 4 张；每成功一张立刻调 _preview.py 裁切并
刷新增量验收页（纪律 N：拿到一张就处理，不等整批）。代理固定 127.0.0.1:7897。

用法：
  python art_src/2026-11-11_组合新卡补图/_run_all.py              # 全跑
  python art_src/2026-11-11_组合新卡补图/_run_all.py 9190 9191     # 只跑返工的两张
"""
import importlib.util
import os
import subprocess
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW                       # run_one / log 读模块全局，改这里即可

sys.path.insert(0, D)
from _gen_prompts import CARDS  # noqa: E402

P = os.path.join(ROOT, "assets", "pics")
REFS = {
    "treant":       8003,          # 森林精魄风格桶
    "mech":         8025,          # 机械之心风格桶
    "shadow_beast": 8006,          # 暗影刺客风格桶
}
JOBS = [(cid, name, bucket) for cid, name, bucket, _full, _card, _body in CARDS]


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, bucket in JOBS:
        if only and cid not in only:
            continue
        ref = os.path.join(P, "%d.png" % REFS[bucket])
        ok = m.run_one(cid, name, ref, "_v1")
        if ok:
            done.append(cid)
            try:
                r = subprocess.run([sys.executable, os.path.join(D, "_preview.py")],
                                   cwd=ROOT, capture_output=True, text=True,
                                   encoding="utf-8", timeout=180)
                print(r.stdout.strip(), flush=True)
                if r.stderr.strip():
                    print("  preview stderr:", r.stderr.strip()[:300], flush=True)
            except Exception as e:                                # noqa: BLE001
                print("  preview ERROR %r" % (e,), flush=True)
        else:
            fail.append(cid)
    m.log("=== 组合新卡补图 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail, flush=True)


if __name__ == "__main__":
    main()
