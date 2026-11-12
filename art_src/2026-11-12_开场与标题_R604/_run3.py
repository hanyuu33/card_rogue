# -*- coding: utf-8 -*-
"""R604 第三批：工作室徽记（优先）+ 标题主视觉。

上一批 _run.py 在中断时丢了进程（raw/ 空、codex 不在），这里重排并改后缀，
避免 run_one 的「同 suffix 已存在即 SKIP」把任务跳过。

徽记要纯黑底金线稿：回到本地后按亮度取 alpha 抠成透明 PNG
（tools/_compose_r604_art.py --mark），片头卡与启动 splash 共用同一张。
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

# suffix 必须是 _v1：run_one 会把「非 _v1 的后缀」拼进 prompt 文件名
# （9002_厂牌徽记_v2.txt），文件不存在就直接 MISS。raw/ 是空的，不会误 SKIP。
JOBS = [
    (9002, "厂牌徽记", None, "_v1"),
    (9001, "标题主视觉", REF_STYLE, "_v1"),
]


def main():
    os.makedirs(RAW, exist_ok=True)
    done, fail = [], []
    for cid, name, ref, suffix in JOBS:
        (done if m.run_one(cid, name, ref, suffix) else fail).append(cid)
    m.log("=== R604 第三批 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail)


if __name__ == "__main__":
    main()
