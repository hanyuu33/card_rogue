# -*- coding: utf-8 -*-
"""R844 原子提交：临时 index + commit-tree，只提交鸭子闹钟 8 个文件。"""
import os
import subprocess

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r844_commit.idx"
MSG = "_commit_r844.txt"
MY = [
    "relics.json",
    "i18n/noncard_zh_canonical.json",
    "i18n/noncard_en.json",
    "i18n/noncard_ja.json",
    "i18n/noncard_es.json",
    "scripts/game_engine.gd",
    "scripts/relic_repo.gd",
    "scripts/test_engine.gd",
]


def run(*args, env=None, binary=False):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(args), cwd=ROOT, capture_output=True, env=e)
    if r.returncode != 0:
        raise SystemExit("命令失败：%s\n%s" % (
            " ".join(args), (r.stdout + r.stderr).decode("utf-8", "replace")))
    return r.stdout if binary else r.stdout.decode("utf-8", "replace").strip()


if os.path.exists(TMPIDX):
    os.remove(TMPIDX)
env = {"GIT_INDEX_FILE": TMPIDX}
run("git", "read-tree", "HEAD", env=env)
for path in MY:
    blob = run("git", "hash-object", "-w", "--path", path, path)
    assert len(blob) == 40, (path, blob)
    run("git", "update-index", "--add", "--cacheinfo",
        "100644,%s,%s" % (blob, path), env=env)
tree = run("git", "write-tree", env=env)
head = run("git", "rev-parse", "HEAD")
commit = run("git", "commit-tree", tree, "-p", head, "-F", MSG)
run("git", "update-ref", "refs/heads/main", commit, head)
os.remove(TMPIDX)

names = run("git", "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").splitlines()
assert names == sorted(MY) or set(names) == set(MY), names
for path in MY:
    committed = run("git", "cat-file", "-p", "HEAD:" + path, binary=True)
    with open(ROOT + path, "rb") as f:
        working = f.read()
    assert committed == working, "提交与工作区逐字节不符：" + path

engine = run("git", "cat-file", "-p", "HEAD:scripts/game_engine.gd")
assert "const DUCK_ALARM_TURN:= 5" in engine
assert "const DUCK_ALARM_DMG:= 33" in engine
for old in ("DUCK_ALARM_ENERGY", "DUCK_ALARM_DRAW", "DUCK_ALARM_SPELL_FROM", "DUCK_ALARM_SPELL"):
    assert old not in engine, old
run("git", "read-tree", "HEAD")
print(run("git", "show", "--stat", "--oneline", "HEAD"))
print("COMMIT_OK", commit)
