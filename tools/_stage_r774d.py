# -*- coding: utf-8 -*-
"""R774d：从 battle_scene.gd 的混合 diff 里只抽「_paint_dmg_number 瘦身」那个 hunk。

背景：工作区的 battle_scene.gd 同时含
  ① 并行线未提交的 anthem / organ 分支删除（@@ -14248,26 +14248,6 @@，删 20 行）
  ② 我这次的 _paint_dmg_number 转调 DmgNumber.paint（@@ -16681,39 +16661,10 @@）
只把 ② 送进 index：hunk1 的删除没发生 → hunk2 的 new_start 要 +20 回 16681。

⚠️ 行尾：battle_scene.gd 是 CRLF，patch 逐字节照抄 git diff 输出（里面本来就带 \r）。
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = "scripts/battle_scene.gd"
PATCH = os.path.join(ROOT, "_r774d_stage.patch")

raw = subprocess.run(["git", "diff", "-U3", "--", TARGET], cwd=ROOT,
                     capture_output=True, check=True).stdout
lines = raw.split(b"\n")
print("diff 总行数:", len(lines))

# 切 hunk
hunks = []
cur = None
head = []
for ln in lines:
    if ln.startswith(b"@@"):
        if cur is not None:
            hunks.append(cur)
        cur = [ln]
    elif cur is None:
        head.append(ln)
    else:
        cur.append(ln)
if cur is not None:
    hunks.append(cur)

print("hunk 数:", len(hunks))
for i, h in enumerate(hunks):
    print("  hunk%d: %s" % (i, h[0].decode("utf-8", "replace").strip()))

if len(hunks) != 2:
    print("期望 2 个 hunk，实际 %d，中止" % len(hunks))
    sys.exit(1)

mine = hunks[1]
old_hdr = mine[0]
# @@ -16681,39 +16661,10 @@ ... → new_start 16661 + 20 = 16681
marker = b"@@ -16681,39 +16661,10 @@"
if not old_hdr.startswith(marker):
    print("hunk2 头不符预期:", old_hdr)
    sys.exit(1)
mine[0] = b"@@ -16681,39 +16681,10 @@" + old_hdr[len(marker):]
print("改写后 hunk 头:", mine[0].decode("utf-8", "replace").strip())

out = head[:]
out.extend(mine)
# 原 raw 末尾可能带空行，保持结构：去掉尾部多余空行后补一个
while out and out[-1] == b"":
    out.pop()
data = b"\n".join(out) + b"\n"
with open(PATCH, "wb") as f:
    f.write(data)
print("patch 已写:", PATCH, len(data), "bytes")
