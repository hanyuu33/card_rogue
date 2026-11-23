# -*- coding: utf-8 -*-
"""R821 原子提交：临时 index + commit-tree。

⚠️ scripts/test_engine.gd 正被并行线改动（R819 探针已 staged）。本轮只改了一行
文案断言，不能把工作区版本整体提交（会带上他的 100 行）。
做法：取 HEAD 版本 → 应用同一处替换 → 单独 hash 成 blob 塞进临时索引。
"""
import io
import os
import subprocess
import sys

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r821_commit.idx"
MSG = "E:/work/card_rogue/tools/_commit_r821.txt"
MY = [
    "relics.json",
    "i18n/noncard_zh_canonical.json",
    "i18n/noncard_en.json",
    "i18n/noncard_ja.json",
    "i18n/noncard_es.json",
    "tools/_patch_r821_arm_text.py",
    "tools/_probe_r821_relic_desc.gd",
    "tools/_commit_r821.py",
    "tools/_commit_r821.txt",
]
OLD_TXT = "每次战斗开始，把一张随机盟友加入你的手卡，本回合费用-1。"
NEW_TXT = "每次战斗开始，将一张随机盟友加入手牌，本回合费用-1。"
TEST = "scripts/test_engine.gd"


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out.strip()


head = run("git", "rev-parse", "HEAD")
env = {"GIT_INDEX_FILE": TMPIDX}
if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
run("git", "read-tree", "HEAD", env=env)

for p in MY:
    h = run("git", "hash-object", "-w", p)
    run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, p), env=env)
    print("[blob] %s %s" % (h[:10], p))

# test_engine.gd：HEAD 版本 + 单行替换
base = subprocess.run(["git", "cat-file", "-p", "HEAD:" + TEST], cwd=ROOT,
                      capture_output=True).stdout.decode("utf-8")
assert base.count(OLD_TXT) == 1, "HEAD 版本里锚点命中 %d 次" % base.count(OLD_TXT)
patched = base.replace(OLD_TXT, NEW_TXT)
tmp = "E:/tmp/r821_test_engine.gd"
io.open(tmp, "wb").write(patched.encode("utf-8"))
h = run("git", "hash-object", "-w", tmp)
run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, TEST), env=env)
print("[blob] %s %s (HEAD 版 + 单行替换)" % (h[:10], TEST))

tree = run("git", "write-tree", env=env)
commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG)
print("[tree]", tree)
print("[commit]", commit)
run("git", "update-ref", "refs/heads/main", commit)
os.remove(TMPIDX)

# 提交里的 test_engine 必须只有这一行差异
diff = run("git", "diff", head, "HEAD", "--", TEST)
added = [l for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
removed = [l for l in diff.splitlines() if l.startswith("-") and not l.startswith("---")]
assert len(added) == 1 and len(removed) == 1, "test_engine 差异不止一行：\n%s" % diff
print("[verify] %s 只差 1 行 ✓" % TEST)

for p in MY:
    got = subprocess.run(["git", "cat-file", "-p", "HEAD:" + p], cwd=ROOT,
                         capture_output=True).stdout
    want = open(os.path.join(ROOT, p), "rb").read()
    assert got == want, "内容不一致：%s" % p
print("R821 commit done:", commit[:10])
