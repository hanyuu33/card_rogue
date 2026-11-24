# -*- coding: utf-8 -*-
"""R778b：从 battle_scene.gd 的工作区 diff 里只抽出「构状体→构装体」那个 hunk，
写成独立 patch 供 git apply --cached 用（并行线删 anthem/organ 的 hunk 不提交）。

按字节搬运，不改任何行尾（该文件是 CRLF）。
"""
import io
import subprocess
import sys

REPO = r"E:/work/card_rogue"
TARGET = "scripts/battle_scene.gd"
OUT = REPO + "/_r778b_battle_hunk.patch"

raw = subprocess.check_output(["git", "-C", REPO, "diff", "--", TARGET])
text = raw.decode("utf-8")

lines = text.split("\n")
# 头部 = 第一行 @@ 之前（diff --git / index / --- / +++）
heads = []
hunks = []
cur = None
for ln in lines:
    if ln.startswith("@@"):
        cur = []
        hunks.append((ln, cur))
    elif cur is None:
        heads.append(ln)
    else:
        cur.append(ln)

print("hunk count =", len(hunks))
for i, (h, body) in enumerate(hunks):
    print(i, h, "lines=", len(body))

if len(hunks) != 2:
    sys.exit("预期 2 个 hunk，实际 %d，停手" % len(hunks))

# 第 0 个 hunk 必须是 -12359,13 那段（构状体改名）
h0, body0 = hunks[0]
if "-12359,13" not in h0:
    sys.exit("第 0 个 hunk 不是预期的改名段：%s" % h0)

for ln in body0:
    if "构状体" in ln or "构装体" in ln:
        print("  hit:", ln)

keep = heads + [h0] + body0
# body0 末尾因为 split("\n") 会带空串，重组时统一用 \n 连接再保证尾部换行
while keep and keep[-1] == "":
    keep.pop()

patch = "\n".join(keep) + "\n"
with io.open(OUT, "w", encoding="utf-8", newline="") as f:
    f.write(patch)
print("written", OUT, len(patch), "chars")
