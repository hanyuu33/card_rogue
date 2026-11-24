# -*- coding: utf-8 -*-
# R774c：从 battle_scene.gd 的 diff 里筛掉并行线的 anthem/organ 删除，
# 只保留我的 5 处 word_of hunk，重算 new_start 后转 CRLF 写成 patch。
import subprocess
import re
import io
import sys


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")


diff = run(["git", "diff", "--", "scripts/battle_scene.gd"]).stdout
if not diff.strip():
    print("no diff in battle_scene.gd")
    sys.exit(0)

lines = diff.split("\n")
header = []
hunks = []
cur = None
for ln in lines:
    if ln.startswith("@@"):
        if cur is not None:
            hunks.append(cur)
        cur = [ln]
    elif cur is None:
        header.append(ln)
    else:
        cur.append(ln)
if cur is not None:
    hunks.append(cur)

out = []
new_off = 0
for h in hunks:
    body = "\n".join(h)
    m = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$", h[0])
    assert m, "bad hunk header: %r" % h[0]
    old_start = int(m.group(1))
    old_cnt = int(m.group(2)) if m.group(2) else 1
    new_start = int(m.group(3))
    new_cnt = int(m.group(4)) if m.group(4) else 1
    tail = m.group(5)
    drop = ('"anthem":' in body) or ('"organ":' in body)
    if drop:
        new_off += old_cnt - new_cnt
        print("DROP %s (net new %+d)" % (h[0].strip(), new_cnt - old_cnt))
        continue
    if new_off != 0:
        new_start += new_off
        h[0] = "@@ -%d,%d +%d,%d @@%s" % (old_start, old_cnt, new_start, new_cnt, tail)
        print("ADJUST -> %s" % h[0].strip())
    else:
        print("KEEP   %s" % h[0].strip())
    out.append(h)

patch_lines = list(header)
for h in out:
    patch_lines.extend(h)
patch = "\n".join(patch_lines)

# 目标文件 battle_scene.gd 是 CRLF，patch 统一转 CRLF
patch_crlf = patch.replace("\n", "\r\n")

with io.open("_r774c_stage.patch", "w", encoding="utf-8", newline="") as f:
    f.write(patch_crlf)
print("wrote _r774c_stage.patch with %d hunks (dropped %d)" % (len(out), len(hunks) - len(out)))
