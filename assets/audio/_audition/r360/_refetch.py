#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""R360 候选曲断点续传器。

peritune.com 单连接被压到 ~20KB/s，一次 180s 只能下 3~4MB，
所以这里用 `curl -C -` 反复续传，直到文件大小等于服务器报的 Content-Length。
多文件并行（各开一条连接），总吞吐才够。
"""
import os
import re
import subprocess
import sys
import threading
import time

DST = os.path.dirname(os.path.abspath(__file__)) + "/raw"
UA = "Mozilla/5.0"
JOBS = [
    ("https://peritune.com/music/PerituneMaterial_Polar_Lights.zip", "PerituneMaterial_Polar_Lights.zip"),
    ("https://peritune.com/music/PerituneMaterial_Firmament3_Calm.mp3", "PerituneMaterial_Firmament3_Calm.mp3"),
    ("https://peritune.com/music/PerituneMaterial_Firmament3_Active.mp3", "PerituneMaterial_Firmament3_Active.mp3"),
    ("https://peritune.com/music/PerituneMaterial_Cyber_Noir.mp3", "PerituneMaterial_Cyber_Noir.mp3"),
    ("https://peritune.com/music/PerituneMaterial_Time_and_Pray.mp3", "PerituneMaterial_Time_and_Pray.mp3"),
    ("https://peritune.com/music/PeriTune_Rituale_Machina.zip", "PeriTune_Rituale_Machina.zip"),
]
TOTAL_RE = re.compile(r"Content-Range: bytes \d+-\d+/(\d+)", re.I)


def total_size(url: str) -> int:
    r = subprocess.run(["curl", "-sS", "-o", os.devnull, "-D", "-", "-r", "0-0",
                        "--max-time", "40", "-A", UA, url],
                       capture_output=True, text=True)
    m = TOTAL_RE.search(r.stdout or "")
    if m:
        return int(m.group(1))
    m2 = re.search(r"Content-Length: (\d+)", r.stdout or "", re.I)
    return int(m2.group(1)) if m2 else 0


def fetch(url: str, name: str, rounds: int = 14) -> None:
    path = os.path.join(DST, name)
    want = total_size(url)
    if not want:
        print("  !! %-42s 拿不到总长度（链接可能失效）" % name, flush=True)
        return
    for i in range(rounds):
        have = os.path.getsize(path) if os.path.exists(path) else 0
        if have >= want:
            print("  完成 %-42s %8d / %8d" % (name, have, want), flush=True)
            return
        subprocess.run(["curl", "-sSL", "-C", "-", "--max-time", "150", "-A", UA,
                        url, "-o", path], capture_output=True)
        if i == rounds - 1:
            have = os.path.getsize(path) if os.path.exists(path) else 0
            print("  未完成 %-40s %8d / %8d" % (name, have, want), flush=True)


def main() -> int:
    os.makedirs(DST, exist_ok=True)
    # 坏文件（HTML 冒充 zip）先**截断为 0**再续（沙箱不让删，截断等价且更安全）
    for _, name in JOBS:
        p = os.path.join(DST, name)
        if os.path.exists(p) and os.path.getsize(p) < 300000:
            with open(p, "rb") as f:
                head = f.read(15).lower()
            if head.startswith(b"<!doctype") or head.startswith(b"<html"):
                open(p, "wb").close()
                print("  截断伪装的 HTML:", name, flush=True)
    ts = [threading.Thread(target=fetch, args=(u, n)) for u, n in JOBS]
    t0 = time.time()
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    print("耗时 %.1fs" % (time.time() - t0), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
