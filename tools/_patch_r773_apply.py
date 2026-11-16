# -*- coding: utf-8 -*-
"""R773：把 /e/tmp/r773_mine.patch 精确应用到 HEAD 版本的 test_engine.gd。

不依赖 git apply / GNU patch（两者都在 CRLF 上打转）—— 自己按行序列做替换：
  每个 hunk 的 old 侧（' ' 与 '-' 行，去掉行首标记、去掉尾随 CR）
  在 base（按 \\r\\n 切分）里唯一匹配 → 换成 new 侧（' ' 与 '+' 行）。
输出 E:/tmp/r773base/scripts/test_engine.gd = HEAD + R773（不含并行线 R774）。
"""
import io, os, sys

PATCH = r"E:/tmp/r773_mine.patch"
TARGET = r"E:/tmp/r773base/scripts/test_engine.gd"

lines = io.open(PATCH, "rb").read().decode("utf-8").split("\n")
i = 0
hunks = []
cur = None
for l in lines:
    if l.startswith("@@"):
        if cur:
            hunks.append(cur)
        cur = {"head": l, "old": [], "new": []}
    elif cur is not None:
        if l.startswith("\\"):
            continue
        if l.startswith(" "):
            cur["old"].append(l[1:].rstrip("\r"))
            cur["new"].append(l[1:].rstrip("\r"))
        elif l.startswith("-"):
            cur["old"].append(l[1:].rstrip("\r"))
        elif l.startswith("+"):
            cur["new"].append(l[1:].rstrip("\r"))
if cur:
    hunks.append(cur)

base = io.open(TARGET, "rb").read().decode("utf-8").split("\r\n")

applied = 0
for h in hunks:
    old = h["old"]
    if not old:
        print("空 hunk：", h["head"]); sys.exit(1)
    # 全文件唯一匹配
    hits = [k for k in range(len(base) - len(old) + 1)
            if base[k:k + len(old)] == old]
    assert len(hits) == 1, "%s 匹配 %d 处" % (h["head"], len(hits))
    k = hits[0]
    base[k:k + len(old)] = h["new"]
    applied += 1

out = "\r\n".join(base)
io.open(TARGET, "wb").write(out.encode("utf-8"))
print("应用 %d 个 hunk，输出 %d 行" % (applied, len(base)))

# 复核：R773 在、R774 不在
txt = io.open(TARGET, "rb").read().decode("utf-8")
assert "R773" in txt and "_test_r773" in txt
assert "R774" not in txt and "r774_" not in txt
assert "== 327" in txt and "r226_skills == 105" in txt
print("[ok] HEAD + R773（无 R774）")
