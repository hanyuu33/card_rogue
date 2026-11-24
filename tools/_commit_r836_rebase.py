# -*- coding: utf-8 -*-
"""R836 追上远端：把 12d41d5（我的提交）重放到 b070369b（R835）之上。

为什么不用 `git rebase`：工作区里压着并行线**下一轮**的未提交改动（relics.json / i18n /
run_save.gd 等），rebase 要求 working tree clean；而 `git stash` 是明令禁止的。
所以照 R780b 的做法用临时索引手工重放：

  · battle_scene.gd / ui_assets.gd / test_smoke.gd —— R835 **没碰**（已核对 --stat），
    直接复用 12d41d5 里那三个 blob。
  · run_state.gd / test_engine.gd —— R835 改过（+51 / +127 行），取 b070369b 的版本再
    重放我的精确替换；锚点若不唯一/不存在会当场 assert，那就是真冲突，别硬来。
  · 新素材 / art_src / 工具脚本 —— 直接复用 12d41d5 的 blob。
"""
import os
import subprocess
import sys

sys.path.insert(0, "E:/work/card_rogue/tools")
from _commit_r836 import PATCHERS, cat_head  # noqa: E402

ROOT = "E:/work/card_rogue/"
TMPIDX = "E:/tmp/r836_rebase.idx"
MSG = "_commit_r836.txt"
OLD = "12d41d50"      # 我的提交
NEWBASE = "b070369b"  # origin/main（R835）

COPY_FROM_OLD = [
    "scripts/battle_scene.gd",
    "scripts/ui_assets.gd",
    "scripts/test_smoke.gd",
]
REPATCH = ["scripts/run_state.gd", "scripts/test_engine.gd"]
NEW_FILES = [
    "assets/fx/clock_face.png",
    "assets/fx/clock_face.png.import",
    "assets/ui/图片命名说明.txt",
    "tools/_make_r836_clock.py",
]


def run(*a, env=None, check=True):
    e = dict(os.environ)
    if env:
        e.update(env)
    r = subprocess.run(list(a), cwd=ROOT, capture_output=True, env=e)
    out = (r.stdout + r.stderr).decode("utf-8", "replace")
    if check and r.returncode != 0:
        sys.exit("命令失败：%s\n%s" % (" ".join(a), out))
    return out


def blob_of(rev, rel):
    return run("git", "rev-parse", "%s:%s" % (rev, rel)).strip()


def cat(rev, rel):
    return subprocess.run(["git", "cat-file", "blob", "%s:%s" % (rev, rel)], cwd=ROOT,
                          capture_output=True).stdout


def main():
    if os.path.exists(TMPIDX):
        os.remove(TMPIDX)
    if run("git", "diff", "--cached", "--name-only").strip():
        sys.exit("真实 index 里已有暂存内容，先确认归属")
    print("old =", run("git", "rev-parse", "--short", OLD).strip(),
          " newbase =", run("git", "rev-parse", "--short", NEWBASE).strip())

    tienv = {"GIT_INDEX_FILE": TMPIDX}
    run("git", "read-tree", NEWBASE, env=tienv)

    placed = []
    # ① 三个 R835 没碰的文件：直接搬我的 blob
    for f in COPY_FROM_OLD:
        h = blob_of(OLD, f)
        run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
        placed.append(f)
        print("  copy  ", h[:10], f)

    # ② 两个冲突面文件：新基底 + 重放我的替换
    for f in REPATCH:
        base = cat(NEWBASE, f)
        got = PATCHERS[f](base)
        # 反向自检：新基底里不该还有「旧口径」的痕迹
        if f.endswith("run_state.gd"):
            assert b"clock_left >= 0" in base, "基底里没有旧分支，锚点可能已被改"
            assert b"clock_left > 0" in got, "重放后没有新分支"
        tmp = "E:/tmp/_r836_rb_" + os.path.basename(f)
        with open(tmp, "wb") as fh:
            fh.write(got)
        h = run("git", "hash-object", "-w", "--", tmp).strip()
        run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
        placed.append(f)
        print("  patch ", h[:10], f, len(got), "bytes")

    # ③ 新文件 / art_src：搬我的 blob
    art = run("git", "-c", "core.quotepath=false", "diff", "--name-only", "--diff-filter=A",
              OLD + "~1", OLD).split("\n")
    art = [a for a in art if a.strip()]
    for f in NEW_FILES + art:
        h = blob_of(OLD, f)
        run("git", "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (h, f), env=tienv)
        placed.append(f)
    print("  moved", len(NEW_FILES) + len(art), "new/art files")

    tree = run("git", "write-tree", env=tienv).strip()
    commit = subprocess.run(["git", "commit-tree", tree, "-p", NEWBASE, "-F", os.path.join(ROOT, MSG)],
                            cwd=ROOT, capture_output=True)
    if commit.returncode != 0:
        sys.exit("commit-tree 失败：" + commit.stderr.decode("utf-8", "replace"))
    csha = commit.stdout.decode().strip()
    run("git", "update-ref", "HEAD", csha, OLD)
    print("new commit =", csha)

    # ④ 校验：三个搬运文件必须与 12d41d5 逐字节相同；两个重放文件含我的标记
    bad = []
    for f in COPY_FROM_OLD:
        if cat("HEAD", f) != cat(OLD, f):
            bad.append(f + "(copy)")
    for f in REPATCH:
        b = cat("HEAD", f)
        if f.endswith("run_state.gd"):
            if b"clock_left > 0" not in b or "R836（用户口径）".encode() not in b:
                bad.append(f + "(patch)")
            if b"R835" not in b:
                bad.append(f + "(丢了 R835 内容!)")
        else:
            if "R836 角标：触发后本场**不画**".encode() not in b:
                bad.append(f + "(patch)")
            if b"R835" not in b:
                bad.append(f + "(丢了 R835 内容!)")
    print("VERIFY", "OK" if not bad else "MISMATCH " + str(bad))

    names = [n for n in run("git", "show", "--name-only", "--pretty=format:", "HEAD").split("\n") if n.strip()]
    print("files in commit:", len(names))
    for n in names:
        print("   ", n)
    if bad:
        sys.exit("校验失败")
    print("R836 已重放到 R835 之上（未 push）")


if __name__ == "__main__":
    main()
