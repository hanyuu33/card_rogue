# -*- coding: utf-8 -*-
"""R756: 打印指定文件某个 hunk 的全部 +/- 行（长行截断），用于判定归属。"""
import re
import subprocess
import sys

f = sys.argv[1]
want = [int(x) for x in sys.argv[2].split(",")]

r = subprocess.run(["git", "diff", "--", f], capture_output=True)
t = r.stdout.decode("utf-8", "replace")
parts = re.split(r"(?m)^(@@[^\n]*@@[^\n]*)$", t)

idx = 0
for i in range(1, len(parts), 2):
    if idx in want:
        print("---- HUNK %02d %s" % (idx, parts[i]))
        for ln in parts[i + 1].splitlines():
            s = ln.rstrip()
            if s.startswith("+") or s.startswith("-"):
                print("  " + s[:220])
    idx += 1
