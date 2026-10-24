#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""R360 单曲 mp3 续传器（比下 24MB 的整包 zip 快得多）。

PeriTune 新曲（2026 之后）页面上只给整包 zip，但服务器上**单曲 mp3 直链仍然存在**：
    https://peritune.com/music/PeriTune_<Name>.mp3
单连接被压到 ~25KB/s，所以照旧 curl -C - 反复续，多文件并行。
"""
import os
import subprocess
import sys
import threading
import time

DST = os.path.dirname(os.path.abspath(__file__)) + "/raw"
UA = "Mozilla/5.0"
JOBS = [
    ("PeriTune_Rituale_Machina", "https://peritune.com/music/PeriTune_Rituale_Machina.mp3"),
    ("PeriTune_Relentless", "https://peritune.com/music/PeriTune_Relentless.mp3"),
]


def head_total(url: str) -> int:
    r = subprocess.run(["curl", "-sS", "-o", os.devnull, "-D", "-", "-r", "0-0",
                        "--max-time", "40", "-A", UA, url],
                       capture_output=True, text=True)
    for line in (r.stdout or "").splitlines():
        if line.lower().startswith("content-range:"):
            return int(line.rsplit("/", 1)[-1].strip())
    return 0


def fetch(name: str, url: str, rounds: int = 16) -> None:
    path = os.path.join(DST, name + ".mp3")
    want = head_total(url)
    if not want:
        print("  !! 拿不到长度:", name, flush=True)
        return
    for _ in range(rounds):
        have = os.path.getsize(path) if os.path.exists(path) else 0
        if have >= want:
            print("  完成 %-30s %9d / %9d" % (name, have, want), flush=True)
            return
        subprocess.run(["curl", "-sSL", "-C", "-", "--max-time", "150", "-A", UA,
                        url, "-o", path], capture_output=True)
    have = os.path.getsize(path) if os.path.exists(path) else 0
    print("  未完成 %-28s %9d / %9d" % (name, have, want), flush=True)


def main() -> int:
    t0 = time.time()
    ts = [threading.Thread(target=fetch, args=(n, u)) for n, u in JOBS]
    for t in ts:
        t.start()
    for t in ts:
        t.join()
    print("耗时 %.1fs" % (time.time() - t0), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
