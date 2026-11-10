# -*- coding: utf-8 -*-
"""R563 返工第四批（店长 2026-11-11 01:32 反馈，共 3 张）：

  9154 破绽  → 交通标识式「彩色抽象标志」：扁平米字路牌 + 冷青碎盾符号，去实物感
  9185 麻痹  → 同一套路牌 + 明黄电弧符号，去实物感（两张不挂参考图，纯文字出图）
  9168 许愿  → 体型改回森林 CG 的 1:4 小女孩比例（v2 误写成成年少女）

复用 R562 的 codex 图生图管线；suffix=_v3，prompt 为 <id>_<name>_v3.txt。
9154/9185 的 ref=None：_run_batch.py 已补可选分支，命令里不带 -i。
"""
import importlib.util
import os
import subprocess
import sys

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_缺图收口_R563")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")
PREP = os.path.join(ROOT, "tools", "cardart_prep.py")
UI = os.path.join(ROOT, "assets", "ui")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

# (id, 卡名, 参考图绝对路径；None = 纯文字出图)
JOBS = [
    (9154, "破绽", None),
    (9185, "麻痹", None),
    (9168, "许愿", os.path.join(UI, "class_cg_forest.png")),
]


def cut(path, cid):
    r = subprocess.run([sys.executable, PREP, path, str(cid)],
                       capture_output=True, text=True, encoding="utf-8")
    print("   ", r.stdout.strip() or ("cut %d FAIL %s" % (cid, r.stderr.strip()[:160])), flush=True)


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, ref in JOBS:
        if only and cid not in only:
            continue
        prompt = os.path.join(D, "%d_%s_v3.txt" % (cid, name))
        assert os.path.exists(prompt), "prompt 缺失: " + prompt
        assert ref is None or os.path.exists(ref), "参考图缺失: " + str(ref)
        print("RUN  %d %s  <- %s" % (cid, name, os.path.basename(ref) if ref else "纯文字"),
              flush=True)
        ok = m.run_one(cid, name, ref, "_v3")
        if ok:
            cut(os.path.join(RAW, "%d_%s_v3.png" % (cid, name)), cid)
            done.append(cid)
        else:
            fail.append(cid)
        print("DONE %d %s %s" % (cid, name, "OK" if ok else "FAIL"), flush=True)
    print("=== 返工第四批 成功%d / 失败%d %s" % (len(done), len(fail), fail), flush=True)


if __name__ == "__main__":
    main()
