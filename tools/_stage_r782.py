# -*- coding: utf-8 -*-
"""R782 提交准备：从工作区 diff 里剔掉并行线的 hunk（anthem/organ 删除），只把
「工具说明面板」这 8 个 hunk 放进 index。剔完要按被删行数回加后续 hunk 的 new_start。

用法：
  python tools/_stage_r782.py            # 打印报告 + 写 /e/tmp/r782_bs.patch
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "E:/tmp/r782_bs.patch"

diff = subprocess.run(["git", "diff", "--", "scripts/battle_scene.gd"],
                      cwd=ROOT, capture_output=True).stdout.decode("utf-8")
lines = diff.split("\n")

first = next(i for i, l in enumerate(lines) if l.startswith("@@"))
header = lines[:first]

hunks = []
cur = None
for l in lines[first:]:
    if l.startswith("@@ "):
        if cur is not None:
            hunks.append(cur)
        cur = [l]
    elif cur is not None:
        cur.append(l)
if cur is not None:
    hunks.append(cur)

DROP_MARK = '-\t\t"anthem":'
kept = []
dropped = []
shift = 0
HUNK_RE = re.compile(r"^@@ -(\d+),(\d+) \+(\d+),(\d+) @@(.*)$")
for h in hunks:
    # CRLF 文件：diff 行内容尾部带 \r，比较前必须剥掉
    if any(l.rstrip("\r") == DROP_MARK for l in h):
        dropped.append(h[0])
        old_n = int(HUNK_RE.match(h[0]).group(2))
        new_n = int(HUNK_RE.match(h[0]).group(4))
        shift += new_n - old_n          # 负数 = 后面整体前移
        continue
    m = HUNK_RE.match(h[0])
    if shift != 0:
        new_start = int(m.group(3)) + shift
        h[0] = "@@ -%s,%s +%d,%s @@%s" % (m.group(1), m.group(2), new_start,
                                          m.group(4), m.group(5))
    kept.append(h)

print("丢弃 hunk：", dropped, " 净行差：", shift)
for h in kept:
    print("  保留", h[0])

body = "\n".join(header)
for h in kept:
    body += "\n" + "\n".join(h)
if not body.endswith("\n"):
    body += "\n"
os.makedirs("E:/tmp", exist_ok=True)
open(OUT, "w", encoding="utf-8", newline="").write(body)
print("写入", OUT, len(body), "字节")
