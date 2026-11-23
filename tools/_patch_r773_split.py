# -*- coding: utf-8 -*-
"""R773 提交准备：从 test_engine.gd 的完整 diff 里剔掉并行线（R774）的 hunk。

判据：按 hunk 内容归属 —— 我的 hunk 记号是 R773 / 327 / 249 / 吟游诗人 3 / r226_skills == 105 /
「隐藏职业卡（吟游诗人）也**不进**随机池」/ _test_r773；R774 那个 hunk 只有状态素材。
输出 /tmp/r773_mine.patch（路径仍是 a/scripts/test_engine.gd，用 patch -p1 应用）。
"""
import io, os, re, subprocess

ROOT = r"E:\work\card_rogue"
os.chdir(ROOT)

diff = subprocess.run(["git", "diff", "-U3", "scripts/test_engine.gd"],
                      capture_output=True).stdout.decode("utf-8")
lines = diff.split("\n")

# 头部（到第一个 @@ 之前）
head_idx = next(i for i, l in enumerate(lines) if l.startswith("@@"))
header = lines[:head_idx]
hunks = []
cur = None
for l in lines[head_idx:]:
    if l.startswith("@@"):
        if cur is not None:
            hunks.append(cur)
        cur = [l]
    elif cur is not None:
        cur.append(l)
if cur is not None:
    hunks.append(cur)

MINE = ["R773", "== 327", "== 249", "BARD, 0)) == 3", "吟游诗人 3", "r226_skills == 105",
        "隐藏职业卡（吟游诗人）也", "_test_r773", "is_hidden_class(c0.card_class)",
        "include_hidden 里也不许混进"]
keep, drop = [], []
for h in hunks:
    body = "\n".join(h)
    (keep if any(m in body for m in MINE) else drop).append(h)

print("hunk 总数 %d，保留 %d，剔除 %d" % (len(hunks), len(keep), len(drop)))
for h in drop:
    print("  剔除:", h[0])
    print("    首行:", [x for x in h[1:] if x[:1] in "+-"][:2])

out = "\n".join(header + [l for h in keep for l in h])
if not out.endswith("\n"):
    out += "\n"
io.open("/tmp/r773_mine.patch", "w", encoding="utf-8", newline="\n").write(out)
print("已写 /tmp/r773_mine.patch，%d 行" % out.count("\n"))
