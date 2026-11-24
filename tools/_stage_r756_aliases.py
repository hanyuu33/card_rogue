# -*- coding: utf-8 -*-
"""R756: 单独为 i18n/source_aliases.json 构造一个干净的 index 版本。

这个文件被并行线也改过（「货物」术语：0 攻/6 血 → 0 力量/6 生命），而它的 diff 是
**一个连续 hunk**，行级剔除会留下「洞」导致 patch 无法 apply。所以这里改成：
拿 HEAD 版本 → 只做 R756 的两处改动 → 直接把 blob 写进 index。
"""
import io
import subprocess

P = "i18n/source_aliases.json"

head = subprocess.run(["git", "show", "HEAD:" + P], capture_output=True).stdout.decode("utf-8")
work = io.open(P, "r", encoding="utf-8", newline="").read()

# 1) 占卜那一行（工作区里已是最终形态）
div_line = None
for ln in work.split("\n"):
    if ln.startswith('  "屋里只点着一支蜡烛') and "占卜的代价" in ln:
        div_line = ln
        break
assert div_line is not None, "找不到占卜行"
print("div_line 前 60 字:", div_line[:60])

# 2) 苹果的 value：HEAD 里是「并回复至最大生命。」→ 改成 20%
OLD = "获得「苹果」：最大生命 +7，并回复至最大生命。"
NEW = "获得「苹果」：最大生命 +7，并回复 20% 最大生命值。"
assert head.count(OLD) == 1, "苹果锚点个数 %d" % head.count(OLD)
body = head.replace(OLD, NEW)

# 3) 在收尾的 } 前插入占卜行（给原来的最后一项补逗号）
lines = body.split("\n")
tail_empty = lines and lines[-1] == ""
if tail_empty:
    lines = lines[:-1]
assert lines[-1] == "}", "收尾不是 }：%r" % lines[-1]
if not lines[-2].rstrip().endswith(","):
    lines[-2] = lines[-2].rstrip() + ","
lines.insert(len(lines) - 1, div_line)
out = "\n".join(lines) + ("\n" if tail_empty else "")

# 4) 校验两边都是合法 JSON 且只差预期的两处
import json
h = json.loads(head)
o = json.loads(out)
assert len(o) == len(h) + 1, "条数 %d → %d" % (len(h), len(o))
diff_keys = [k for k in h if h[k] != o.get(k)]
print("变化的老 key 数:", len(diff_keys))
for k in diff_keys:
    print("  -", k[:40], "...")
added = [k for k in o if k not in h]
print("新增 key:", [k[:30] for k in added])

# 5) 写 blob 进 index
blob = subprocess.run(["git", "hash-object", "-w", "--path", P, "--stdin"],
                      input=out.encode("utf-8"), capture_output=True)
sha = blob.stdout.decode().strip()
print("blob:", sha)
r = subprocess.run(["git", "update-index", "--cacheinfo",
                    "100644,%s,%s" % (sha, P)], capture_output=True)
print("update-index rc=%d %s" % (r.returncode, r.stderr.decode()[:300]))
