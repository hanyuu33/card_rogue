# -*- coding: utf-8 -*-
"""9246 宝石兽：店长 2026-11-11 15:11 点名 v2a → 转正为 _pending 成品。

「候选不覆盖」纪律的例外是「点名即转正」：只覆盖 9246 自己的成品位。
v1 成品 + v1 prompt 备份到 backup_9246/；v2b 保留为候选，一个字节不动；
主目录 assets/pics/ 不动（整批 approve 需另行指示）；不 commit、不打包。

可重复执行：备份已存在就跳过，成品始终对齐 v2a。
"""
import hashlib
import importlib.util
import os
import shutil
import subprocess
import sys

from PIL import Image

ROOT = r"E:\work\card_rogue"
D = os.path.dirname(os.path.abspath(__file__))
PEND = os.path.join(ROOT, "assets", "pics", "_pending")
BAK = os.path.join(D, "backup_9246")
V2A = os.path.join(D, "候选_9246_宝石兽_v2a.png")
V2B = os.path.join(D, "候选_9246_宝石兽_v2b.png")
DST = os.path.join(PEND, "9246.png")
BAK_IMG = os.path.join(BAK, "9246_v1_几何矿石兽_448.png")
OFFICIAL = os.path.join(D, "正式_9246_宝石兽_v2a_448.png")


def md5(path):
    with open(path, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def main():
    # ---- 0. 前置断言：源与旧成品都必须是裁好的 448x403 --------------------
    assert Image.open(V2A).size == (448, 403), "v2a 不是 448x403"
    assert Image.open(DST).size == (448, 403), "旧成品不是 448x403"
    v2b_before = md5(V2B)
    old_before = md5(DST)
    assert v2b_before != md5(V2A), "v2a / v2b 竟是同一张"

    # ---- 1. 旧版留档（成品 + 已弃用 prompt） ------------------------------
    os.makedirs(BAK, exist_ok=True)
    if not os.path.exists(BAK_IMG):
        shutil.copy2(DST, BAK_IMG)
    v1_prompt = os.path.join(D, "9246_宝石兽.txt")
    if os.path.exists(v1_prompt):
        shutil.copy2(v1_prompt, os.path.join(BAK, "9246_宝石兽_v1_prompt_弃用.txt"))

    # ---- 2. 二进制覆盖：v2a 逐字节成为正式成品 ----------------------------
    shutil.copy2(V2A, DST)
    shutil.copy2(V2A, OFFICIAL)
    assert md5(DST) == md5(V2A) == md5(OFFICIAL), "转正字节不一致"
    assert md5(V2B) == v2b_before, "v2b 候选被误改"
    assert md5(BAK_IMG) == old_before and md5(BAK_IMG) != md5(DST), "v1 备份异常"

    # ---- 3. 刷新三格对比页（只调 sheet，不重跑 codex） ---------------------
    spec = importlib.util.spec_from_file_location(
        "retry9246", os.path.join(D, "_retry_9246.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    m.sheet()

    # ---- 4. 刷新全批 4/4 页 + 联系表（_preview 已存在成品则跳过裁切） -----
    r = subprocess.run([sys.executable, os.path.join(D, "_preview.py")],
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    print(r.stdout.strip())
    if r.stderr.strip():
        print("stderr:", r.stderr.strip()[:400])
    assert r.returncode == 0, "_preview.py 失败"

    # ---- 5. 收口校验 ------------------------------------------------------
    for cid in (9246, 9247, 9190, 9191):
        p = os.path.join(PEND, "%d.png" % cid)
        assert os.path.exists(p) and Image.open(p).size == (448, 403), p
    assert not os.path.exists(os.path.join(ROOT, "assets", "pics", "9246.png")), \
        "主目录被误写（本轮不 approve）"
    print("[promote] 9246 正式版 = v2a | v1 已备份 | v2b 候选保留 | 4 张 448x403 OK")


if __name__ == "__main__":
    main()
